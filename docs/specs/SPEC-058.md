# SPEC-058: Motor de Precificação (pcomax/pcomin), Vínculo de Filial e Tratamento de Estoque/Preço Zero

| Metadado | Detalhe |
| :--- | :--- |
| **Módulos Afetados** | Catálogo de Produtos, Ações de Venda e Digitação de Pedidos (`pckvendig000`, `pckvendig010`) |
| **Bancos de Dados** | `dbforcacad001.db` (Carga/Tabelas de Preço/Estoque) e `dbforcadig001.db` (Digitação Local) |
| **Tabelas Envolvidas** | `cadpro00`, `estpcopro00`, `estpcoreg00`, `estpro00`, `cadrep00`, `cadcli00`, `pckvendig010` |
| **Status** | Pronto para Execução via Antigravity |

---

## 1. Visão Geral e Contexto de Negócio

No sistema legado de Força de Vendas, a precificação e a disponibilidade física de um item **não são propriedades estáticas** da tabela base de cadastro (`cadpro00`). Elas dependem da filial onde a operação é faturada, da região do cliente, da tabela de preços e das regras de margem comercial do vendedor.

Esta especificação padroniza:
1. A resolução do preço unitário de venda, preço máximo (`pcomax`) e preço mínimo com desconto (`pcomin`).
2. A segmentação e isolamento de saldos por filial faturadora.
3. O comportamento do catálogo e do carrinho frente a saldos zerados (`estoque = 0`).
4. As regras de apresentação e restrições de venda para itens sem precificação cadastrada (`preco = 0`).

---

## 2. Arquitetura e Modelagem de Dados de Preços

### 2.1. Estrutura Física das Tabelas no SQLite

#### A. Cadastro Base de Produtos (`cadpro00`)
* Não armazena preços de venda. Armazena unicamente os atributos fiscais e cadastrais (`pro00_codigo`, `pro00_descri`, `pro00_unidad`, `pro00_codbar`, etc.).

#### B. Matriz de Relacionamento Comercial e Regional (`estpcoreg00`)
```sql
CREATE TABLE estpcoreg00 (
  pro00_codkey tinyint,
  pro00_typpco tinyint, -- Tipo de preço do cliente (cadcli00.cli00_typpco)
  pro00_codmod tinyint, -- Modalidade da venda / plano
  pro00_codpro int,     -- Código do produto (cadpro00.pro00_codigo)
  pro00_codreg tinyint, -- Região do cliente (cadcli00.cli00_codreg)
  pro00_codtab tinyint, -- Tabela de preços ativa
  pro00_codpco int,     -- Código/Ponteiro para a classe de preço em estpcopro00
  pro00_codcom int      -- Código da regra de comissionamento
);
```

#### C. Tabela de Valores Físicos e Substituição Tributária (`estpcopro00`)
```sql
CREATE TABLE estpcopro00 (
  pro00_codcls tinyint,        -- Código da Classe de Preço (apontado por pro00_codpco ou cli00_typpco)
  pro00_codpro int,            -- Código do produto
  pro00_pcocus decimal (6, 3), -- Custo base de reposição
  pro00_pcosub decimal (6, 3), -- Preço de venda praticado (com ST/promocional)
  pro00_altdat datetime,
  pro00_altflg int
);
```

#### D. Item Gravado na Digitação (`pckvendig010`)
* `dig01_pcomax`: Preço máximo permitido (tabela base).
* `dig01_pcomin`: Preço mínimo permitido (piso de desconto para o vendedor).
* `dig01_digpco`: Preço unitário efetivamente digitado/aplicado pelo vendedor.

---

## 3. Hierarquia de Apuração de Preços e Margens (`pcomax` e `pcomin`)

### 3.1. Resolução do Preço Base de Venda (`pcomax`)
Para calcular o valor de tabela exibido na tela do operador, o sistema adota a cascata:

1. **Preço Regionalizado (Matriz `estpcoreg00` + `estpcopro00`):**
   * Ocorre quando o cliente selecionado possui região comercial (`cadcli00.cli00_codreg > 0`) e a tabela de preços está parametrizada.
   * A busca localiza `pro00_codpco` em `estpcoreg00` para o produto e cruza com `estpcopro00.pro00_codcls`.
2. **Preço por Classe Direta (`estpcopro00`):**
   * Caso não haja entrada regional em `estpcoreg00`, utiliza a classe de preço padrão vinculada ao cliente (`cadcli00.cli00_typpco`) ou classe padrão da filial:
     ```sql
     SELECT COALESCE(pro00_pcosub, 0.0) 
     FROM estpcopro00 
     WHERE pro00_codpro = :codProduto 
       AND (pro00_codcls = :codClasse OR :codClasse = 0)
     LIMIT 1;
     ```
3. **Fallback Canônico:**
   * Se nenhuma correspondência for encontrada, o valor retornado é estritamente `0.0`.

### 3.2. Resolução do Preço Mínimo (`pcomin`)
* **Regra Matemática:**  
  $$pcomin = \max\left(pro00\_pcocus, \; pcomax \times (1 - \frac{descontoMaximo}{100})\right)$$
* Se a base não possuir percentual específico de desconto por vendedor (`cadrep00.ven00_perdes`), o piso é fixado pelo custo do produto (`pro00_pcocus`). Na ausência deste, $pcomin = pcomax$.

### 3.3. Validação Durante a Digitação do Item
Ao alterar o preço unitário do item (`dig01_digpco`), o sistema valida:
```dart
if (digpco < pcomin) {
  throw ValidationException("Preço abaixo do mínimo permitido (R\$ ${pcomin.toStringAsFixed(2)})");
}
if (digpco > pcomax && !permiteAcrescimo) {
  throw ValidationException("Preço acima do valor de tabela (R\$ ${pcomax.toStringAsFixed(2)})");
}
```

---

## 4. Regras de Isolamento por Filial

### 4.1. Definição da Filial Ativa
* **Mono-filial (`ven00_selfil == 0`):** A filial é fixada compulsoriamente a partir de `cadrep00.ven00_codfil`.
* **Multi-filial (`ven00_selfil == 1`):** O operador seleciona a filial no primeiro acesso ou menu de filial. A filial selecionada governa todo o ciclo de vida da sessão (`AppState.codFilialAtiva`).

### 4.2. Estoque e Saldo Físico por Filial (`estpro00`)
* O saldo disponível **não** é unificado entre filiais. A consulta deve filtrar estritamente a filial ativa:
  ```sql
  SELECT COALESCE(e.pro00_qtdest - e.pro00_qtdpen, e.pro00_qtdest, 0.0) AS saldo_disponivel
  FROM estpro00 e
  WHERE e.pro00_codpro = :codProduto
    AND e.pro00_codfil = :filialAtiva
  LIMIT 1;
  ```
* **Integridade do Pedido:** Um pedido pertence a uma única filial faturadora (`dig00_digfil`). Todos os itens (`dig01_digfil`) devem herdar essa mesma filial, sendo proibida a inclusão cruzada de itens de filiais distintas na mesma transação.

---

## 5. Regras Operacionais para Estoque Zero

### 5.1. No Catálogo de Produtos e Pesquisa
| Condição / Filtro | Comportamento na Interface |
| :--- | :--- |
| **`apenasEstoque == false` (Padrão)** | **Exibe normalmente o produto.** O card deve indicar o saldo numérico `0.0` com badge neutro/cinza indicando *"Sem saldo em estoque"*. |
| **`apenasEstoque == true`** | **Oculta o produto.** O `WHERE` da query adiciona: `AND (COALESCE(e.pro00_qtdest - e.pro00_qtdpen, 0) > 0)`. |

### 5.2. Na Tentativa de Inclusão no Pedido
* Se o saldo for $\le 0$:
  * **Se `cadrep00.ven00_ignlimfis == 1`:** Permite a venda normalmente (gera pendência para faturamento posterior).
  * **Se `cadrep00.ven00_ignlimfis == 0`:** Bloqueia a inserção e exibe: *"Produto sem estoque disponível na filial ativa"*.

---

## 6. Regras Operacionais para Preço Zero (`preco == 0`)

### 6.1. No Catálogo de Produtos e Pesquisa
* Itens com preço apurado igual a `0.0` **permanecem visíveis** no catálogo geral para consulta cadastral, leitura de código de barras ou especificações.
* **Formatação Visual:** O card exibe o texto *"Sob Consulta"* ou *"Sem Tabela"* em vez de `R$ 0,00`.

### 6.2. Na Tentativa de Inclusão no Pedido
1. **Regra Geral de Venda Normal:**
   * **Bloqueio Obrigatório:** É expressamente proibida a inclusão no pedido de itens com preço zerado (`dig01_digpco <= 0` ou `pcomax <= 0`). O botão de confirmar inclusão fica desabilitado.
2. **Exceção de Bonificação (`isBonificacao == true`):**
   * É permitida a inclusão com preço `0.0` **exclusivamente** se o item for selecionado como bonificação/brinde e estiver com autorização cadastral ativa:
     * `cadpro00.pro00_defbon == 1` OU `cadpro00.pro00_defbonven == 1`.
   * O total do item é computado em `dig00_bontot` e não afeta o valor financeiro a faturar (`dig00_digtot`).

---

## 7. Critérios de Aceitação e Testes

- [ ] A consulta de catálogo retorna o preço praticado (`pro00_pcosub`) da tabela `estpcopro00` correspondente à classe/região ativa.
- [ ] Quando o vendedor digita um preço menor que `pcomin` ou maior que `pcomax`, o sistema emite validação imediata e não grava o item.
- [ ] O saldo em estoque reflete estritamente a filial vinculada (`cadrep00.ven00_codfil` ou filial selecionada).
- [ ] O catálogo exibe produtos com estoque zero por padrão, ocultando-os apenas quando o switch `apenasEstoque` for ativado pelo usuário.
- [ ] Produtos com preço `0.0` são bloqueados para inserção em pedidos de venda normal, permitindo apenas se marcados como bonificação autorizada.
- [ ] Execução dos testes automatizados em `test/services/preco_service_test.dart` e `flutter analyze` sem advertências.