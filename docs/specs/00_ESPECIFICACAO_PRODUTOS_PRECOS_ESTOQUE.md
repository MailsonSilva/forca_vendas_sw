# ESPECIFICAÇÃO TÉCNICA E DE REGRAS DE NEGÓCIO: MÓDULO DE PRODUTOS, TABELAS DE PREÇO E ESTOQUE

Este documento detalha as especificações técnicas, regras de faturamento offline, rotinas de validação financeira e gestão de estoques do aplicativo de Força de Vendas (FV), baseado na engenharia reversa das regras contidas nas classes C++/Qt e nas tabelas SQLite do banco local.

---

## 1. Catálogo e Unidades de Venda

O catálogo de produtos local é representado em memória pelo modelo **`Tcadpro00`** (declarado em `usysctr00.h` e implementado em `usysctr00.cpp`) e persistido na tabela de banco de dados **`cadpro00`** (banco local estático `dbforcacad001.db`). As regras de embalagens e conversão utilizam a tabela secundária **`cadproemb02`** (modelo **`Tcadproemb02`**).

### A. Estrutura e Atributos da Entidade Produto (`cadpro00`)

Os campos fundamentais para faturamento, unidades e controle de estoque são mapeados abaixo:

| Coluna SQLite | Tipo de Dado | Atributo C++ | Descrição / Regra de Negócio |
| :--- | :--- | :--- | :--- |
| `pro00_codigo` | `INTEGER` | `pro00_codigo` | Chave Primária (PK) de identificação do produto. |
| `pro00_descri` | `TEXT` | `pro00_descri` | Nome comercial de exibição na UI móvel. |
| `pro00_unidad` | `TEXT` | `pro00_unidad` | Sigla da unidade de faturamento mínima (ex: UN, KG, CX). |
| `pro00_indfra` | `INTEGER` | `pro00_indfra` | Sinalizador de unidade fracionada (0 = Inteiro, 1 = Aceita decimais). |
| `pro00_peso` | `INTEGER` | `pro00_peso` | Indica se a venda é baseada em pesagem e balança comercial. |
| `pro00_pesbru` | `REAL` | `pro00_pesbru` | Peso bruto físico unitário do produto. |
| `pro00_pesliq` | `REAL` | `pro00_pesliq` | Peso líquido unitário de faturamento. |
| `pro00_qtdest` | `REAL` | `pro00_qtdest` | Saldo físico de estoque local sincronizado da retaguarda. |
| `pro00_prifil` | `INTEGER` | `pro00_prifil` | Código da filial detentora e faturadora do estoque. |
| `pro02_mulemb` | `INTEGER` | `pro02_mulemb` | Fator multiplicador de embalagem de venda fechada (caixa master). |
| `pro02_mulven` | `REAL` | `pro02_mulven` | Fator de unidade padrão de faturamento (`mulver`). |

---

### B. Regra de Frações vs. Inteiros (`pro00_indfra`)

O sistema legado impede de forma impeditiva que unidades inteiras sejam faturadas com valores decimais:

1. **Unidades Inteiras (ex: UN, CX, PC):**
   * Se o campo **`pro00_indfra`** for igual a **`0`** (ou desmarcado em C++), a quantidade inserida é submetida ao método de validação **`Tsysvenfun00::ValideQTDValues()`**.
   * A quantidade digitada é convertida obrigatoriamente para inteiro. Qualquer tentativa de inserir frações decimais (ex: `1.50`) é arredondada ou rejeitada na digitação rápida da janela **`ffrmdigvenmov07.cpp`**.
2. **Unidades Fracionadas/Peso (ex: KG, MT, LT):**
   * Se **`pro00_indfra`** ou **`pro00_peso`** for igual a **`1`** (ou marcado como `true`), o motor de faturamento habilita a digitação com até **3 casas decimais** padrão de balança.
   * A exibição dessas quantidades no catálogo (`ffrmdigvenliv00.cpp`) utiliza o utilitário de formatação de float **`sysfun.SFlt(quantidade)`**.

---

### C. Fator de Conversão e Multiplicador de Embalagem

O faturamento móvel aceita digitação em caixas/fardos fechados ou em unidades físicas mínimas. Essa paridade comercial é gerida pelo fator multiplicador **`mulver`** (`pro02_mulven` em `cadpro00` ou `emb02_mulemb` da tabela `cadproemb02` carregado pela classe `Tcadproemb02List`):

* **Fórmula de Conversão para Unidade Mínima (Faturamento Físico):**
  Quando o vendedor vende uma quantidade de caixas ou fardos, o sistema realiza a baixa no estoque e o cálculo do preço com base no multiplicador físico de embalagem:
  \\[\text{Quantidade de Venda} = \text{Quantidade Digitada (Caixas)} \times \text{mulver}\\]
* **Arredondamento e Embalagem Fechada:**
  Se o multiplicador de embalagem fechada do item estiver ativo, a digitação de quantidades é validada na classe de negócio **`usysvenfun00.cpp`** para garantir que o pedido obedeça a múltiplos exatos da embalagem, prevenindo fracionamentos de caixas não autorizados na retaguarda.

---

## 2. Políticas de Preço e Descontos

As políticas comerciais são aplicadas de forma dinâmica offline com base nas características fiscais da sessão e restrições comerciais de cada mercadoria.

### A. Lógica de Seleção de Múltiplas Tabelas de Preço

Ao abrir o catálogo de produtos (**`ffrmdigvenliv00.cpp`**), as informações de preço do produto (**`propco`** em `TPROItem`) são filtradas por uma matriz reativa configurada pelas seguintes chaves do cabeçalho do pedido:

1. **Filial Ativa (`filter->digfil`):** Filtra os preços autorizados para o faturamento da filial logada (`ven00_codfil`).
2. **Tabela de Venda (`filter->digtab`):** O código da tabela de faturamento ativa do pedido (`dig00_digtab`) herda a tabela configurada para o cliente selecionado (`cli00_codtab`) ou para o vendedor.
3. **Prazo / Condição de Pagamento (`filter->platyp`):** Acréscimos ou descontos são reajustados de forma percentual no preço base baseado no tipo e parcelamento do plano selecionado da tabela **`cadpla00`** (Ex: Venda a Prazo aplica juros/acréscimo financeiro, Venda à Vista concede desconto percentual automático).

---

### B. Regras de Margem e Segurança Comercial (Preços Mínimo e Máximo)

Toda alteração de preços praticada manualmente pelo vendedor no formulário de inserção rápida de itens (**`ffrmdigvenmov07.cpp`**) é submetida de forma impeditiva ao método **`Tsysvenfun00::ValidePCOValues()`**:

\\[\text{ValidePCOValues}(\text{Proqtd}, \text{Prmqtd}, \text{PcoDig}, \text{PcoMax}, \text{PcoMin}, \text{PcoPrm}, \dots)\\]

* **Preço Mínimo (`pro00_pcomin` / `pcomin`):**
  O preço digitado pelo vendedor (**`PcoDig`**) não pode ser inferior ao preço mínimo de faturamento estabelecido pela retaguarda. Se for menor, a transação local retorna erro de validação e o sistema impede o fechamento do formulário de lançamento.
* **Preço Máximo (`pro00_pcomax` / `pcomax`):**
  Estabelece o teto de preço recomendado para tabela.
* **Teto de Desconto do Vendedor (`pro00_commax` / `commax`):**
  O percentual máximo de desconto praticado pelo vendedor na linha não pode exceder o teto parametrizado em `pro00_commax`. Caso o desconto inserido fure o limite de flexibilidade comercial, o sistema reduz proporcionalmente a comissão de faturamento do representante (**`prp00_comper`**) ou exige liberação administrativa por senha de supervisor.

---

### C. Regras de Combos, Kits e Bonificações Automáticas

#### 1. Módulo de Combos e Kits (tabela `estdefcmb00` e classe `TGerCMB`)
* O vendedor visualiza os combos disponíveis na tela **`ffrmdigvencmb00.cpp`** (motor gerenciado em `usysvencmb.cpp`).
* **Validação de Estoque de Combo:** Antes de incluir os produtos do kit no carrinho, o método **`ffrmdigvencmb00::doCMBInsert`** realiza uma verificação física em lote na tabela `cadpro00`:
  * Varre todas as linhas componentes do combo (`cmb01_codpro`).
  * Executa a validação de disponibilidade e se qualquer componente estiver zerado, exibe o aviso `"Estoque insuficiente"` e nega a inserção do lote.
* **Validação de Multiplicadores:** Garante que a quantidade selecionada do combo respeite o intervalo entre a quantidade mínima e a quantidade máxima permitida (`cmb00_qtdmul <= cmb00_qtdmax`).

#### 2. Bonificações Automáticas (tabela `estdefbon00` e classe `usysvenbon00.cpp`)
* Gerido pelas classes de faturamento baseadas em regras de incentivo e distribuição de brindes:
  * **Tipos de Bonificação (`Testdefbon00TypBon`):** `edtbMIXPRD` (Bonifica por mix de produtos adicionados), `edtbQTDFIX` (Garante brinde por volume atingido de um item), `edtbVENVLR` (Garante bônus por valor total financeiro faturado), `edtbVENFAB` (Por metas de volume de marcas de fabricantes específicos).
  * **Modos de Auditoria Comercial (`Testdefbon00TypCal`):** O sistema roda de forma reativa validações do tipo `edtcCheckALL` (verifica mix, quantidades e valores de faturamento) ou `edtcCheckVLR` (somente valor de fechamento).
  * Quando a regra é cumprida, o sistema insere automaticamente os itens bonificados no pedido faturando-os a preço zero e acumulando seus valores de custo na coluna fiscal **`dig00_bontot`** do cabeçalho da venda.

---

## 3. Gestão e Checagem de Estoque Local

O sistema móvel FV é projetado para operar offline-first, mantendo regras estritas de proteção de estoque para evitar faturamentos duplicados sem saldo em trânsito.

### A. Algoritmo de Cálculo de Estoque Disponível

A disponibilidade de estoque para venda no catálogo de produtos não se limita ao saldo físico gravado estaticamente na tabela de cadastro de produtos (`cadpro00`). Ela é calculada dinamicamente pelo método **`Tsysvenfun00::estoqueCheck()`** no arquivo **`usysvenfun00.cpp`**:

#### Fórmula de Estoque Disponível Offline
\\[\text{Estoque Disponível} = \text{pro00\_qtdest} - \sum (\text{dig01\_digqtd})\\]

* Onde a somatória de **`dig01_digqtd`** considera as reservas de rascunhos de pedidos locais em andamento de digitação de todas as filiais ativas do aparelho:
  ```sql
  SELECT IFNULL(SUM(i.dig01_digqtd), 0)
  FROM dig01 i
  INNER JOIN dig00 c ON c.dig00_digcod = i.dig01_digcod AND c.dig00_digfil = i.dig01_digfil
  WHERE i.dig01_digpro = :id_produto
    AND c.dig00_sttdig = 0; -- 0 = pvddsEDITANDO (rascunho ativo local)
  ```

---

### B. Comportamento em Caso de Estoque Insuficiente (Aviso vs. Bloqueio Rígido)

O comportamento do sistema ao deparar-se com saldo indisponível ou estoque zerado no momento do lançamento do produto na tela de digitação rápida (`ffrmdigvenmov07.cpp`) é determinado pelo parâmetro do perfil do representante **`ven00_chkest`** (Verifica Estoque, tipo `INTEGER` / `bool`):

#### 1. Bloqueio Rígido (`ven00_chkest = 1` ou ativo)
* Ao digitar a quantidade e clicar em confirmar, o slot **`doKeyEnterClicked()`** dispara o validador **`validaEstoque()`**.
* Se a quantidade digitada exceder o saldo da fórmula de estoque disponível:
  * O aplicativo exibe uma caixa de diálogo impeditiva com a mensagem: **`"Estoque insuficiente"`**.
  * O sistema **bloqueia** o lançamento e retém o foco físico do cursor no campo de digitação de quantidade (`txtqtd`), impedindo que o vendedor avance para a tela de preços ou finalize o faturamento da linha.

#### 2. Aviso Apenas / Faturamento Negativo (`ven00_chkest = 0` ou inativo)
* O validador local de estoque é ignorado.
* O sistema permite faturar o produto normalmente, gerando saldo negativo local temporário. O vendedor recebe apenas avisos visuais informativos sobre a falta de saldo físico, mas o sistema permite a conclusão física e transacional local (`cpost()`) do pedido de fenda.

---

## 4. Recomendações de Migração para Flutter

### A. Repositório Reativo de Estoque (BLoC / Cubit)
* No Flutter, para garantir o cálculo reativo em tempo real do estoque sem lentidão visual na listagem de produtos, implemente um **StockStreamObserver** usando Drift ou Sqflite. 
* Este repositório deve escutar ativamente qualquer modificação na tabela de itens de rascunho (`dig01`) e emitir automaticamente o novo saldo disponível de estoque calculado para os cards do catálogo em milissegundos à medida que o carrinho é atualizado.

### B. Arquitetura de Validação Baseada em Regras de Negócio
* Centralize as validações financeiras de preço mínimo (`pcomin`), desconto máximo (`commax`) e limites de combos em um único serviço reativo de validação de checkout (**`CheckoutValidatorService`**).
* Isole o comportamento visual de bloqueio usando estratégias de injeção de parâmetros que herdem o perfil do representante de forma que a mudança de comportamento ("Bloqueio Rígido" para "Aviso Apenas") seja meramente uma configuração dinâmica de estados reativos na UI do Flutter.
