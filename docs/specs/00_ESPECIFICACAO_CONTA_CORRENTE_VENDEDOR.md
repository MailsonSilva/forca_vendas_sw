# ESPECIFICAÇÃO TÉCNICA E REGRAS DE NEGÓCIO
## MÓDULO DE CONTA-CORRENTE DO VENDEDOR (CCV / SALDO FLEX)

Esta especificação técnica detalha o funcionamento, as regras de faturamento, a persistência relacional local (SQLite), o fluxo de telas e as integrações do **Módulo de Conta-Corrente do Vendedor (CCV)**, também conhecido comercialmente como **"Saldo Flex"**. O objetivo deste documento é orientar a migração reativa, reescrevendo de forma nativa a lógica offline do sistema legado C++/Qt para a nova arquitetura em Flutter.

---

## 1. VISÃO GERAL DO MÓDULO

No sistema de força de vendas (FV), o **Conta-Corrente do Vendedor (CCV)** atua como uma "carteira virtual de flexibilidade de preço". Ele registra a diferença monetária entre o **Preço de Tabela Homologado** de um item e o **Preço Efetivo Praticado** pelo representante em campo.

*   **Venda Acima da Tabela:** Gera um **Crédito** para o vendedor, aumentando seu saldo CCV.
*   **Venda com Desconto (Abaixo da Tabela):** Gera um **Débito** para o vendedor, consumindo seu saldo CCV.
*   **Finalidade Comercial:** Permitir que o vendedor conceda descontos agressivos para fechar uma venda difícil, desde que ele possua "saldo de margem" (CCV positivo) acumulado de transações anteriores.

---

## 2. REGRAS DE NEGÓCIO: "O QUE FAZ" vs. "O QUE NÃO FAZ"

### O que o Módulo FAZ:
1.  **Cálculo Unitário por Item:** Monitora em tempo real a diferença de margem de cada produto adicionado ao carrinho, multiplicando a variação unitária pela quantidade digitada.
2.  **Validação de Limite "Flex" no Checkout:** Bloqueia vendas com descontos excessivos caso o vendedor não tenha saldo CCV suficiente e o parâmetro de checagem do representante esteja ativo (`ven00_chkccv = true`).
3.  **Provisão de Saldo em Digitação (`vlrusedig`):** Deduz temporariamente o CCV dos pedidos salvos no aparelho que ainda estão em fase de digitação/rascunho para evitar o estouro de saldo por faturamento paralelo.
4.  **Sincronização Delta de Margens:** Recebe as atualizações de faturamento homologadas pela retaguarda através da leitura do XML de retorno (`.ret`), atualizando o saldo líquido oficial.
5.  **Histórico Analítico de Lançamentos:** Exibe detalhadamente cada movimentação (créditos por vendas com margem alta, débitos por descontos, estornos por cortes de estoque ou cancelamentos).

### O que o Módulo NÃO FAZ:
1.  **NÃO se confunde com o Limite de Crédito do Cliente:** O limite de crédito do cliente (`cli00_crelim` / `cli00_creatu`) é um controle financeiro do CNPJ/CPF do comprador. O CCV é um saldo exclusivo do **Vendedor** (representante comercial).
2.  **NÃO registra Lançamentos Financeiros de Caixa:** O CCV não controla pagamentos de boletos, depósitos bancários, comissões de folha de pagamento ou vales em dinheiro. Ele restringe-se puramente à **flutuação de margem de preço**.
3.  **NÃO permite Ajuste Manual no Aparelho:** O vendedor não pode alterar, zerar ou inflar seu saldo CCV diretamente na interface. Lançamentos manuais de bônus ou descontos administrativos de CCV devem ser realizados exclusivamente pelo ERP central e transmitidos ao celular via sincronização FTP.

---

## 3. DICIONÁRIO DE DADOS (PERSISTÊNCIA SQLITE)

### Tabela: `fincaiccv01` (Saldo Consolidado de CCV do Vendedor)
*   **Finalidade:** Armazena os saldos totais acumulados, provisórios e disponíveis do representante comercial logado no smartphone.
*   **Banco de Dados Local:** `dbforcadig001.db` (Banco transacional local).
*   **Chave Primária Composta:** `ccv01_codfil`, `ccv01_codven`

| Coluna | Tipo | Descrição / Regra de Negócio |
| :--- | :--- | :--- |
| `ccv01_codfil` | INTEGER (PK) | Código da Filial de faturamento vinculada ao representante. |
| `ccv01_codven` | INTEGER (PK) | Código identificador único do Vendedor/Representante logado (`cadrep00`). |
| `ccv01_vlrsal` | REAL | Saldo base inicial homologado e enviado pela retaguarda. |
| `ccv01_vlrusedig` | REAL | Saldo provisório consumido por pedidos que estão salvos localmente em digitação/rascunho. |
| `ccv01_vlrusepck` | REAL | Saldo provisório consumido por pedidos já empacotados em lote `.pac`, mas não processados. |
| `ccv01_vlrsalatu` | REAL | **Saldo Líquido Atualizado/Disponível.** É o valor final utilizado pelas travas do checkout. |

---

### Tabela: `fincaimovccv00` (Histórico Analítico de Movimentações de CCV)
*   **Finalidade:** Grava os lançamentos individuais de crédito e débito na conta do vendedor, servindo de fonte para o extrato.
*   **Banco de Dados Local:** `dbforcadig001.db`
*   **Chave Primária:** Auto-incremental ou combinada.

| Coluna | Tipo | Descrição / Regra de Negócio |
| :--- | :--- | :--- |
| `ccv00_datmov` | DATE | Data exata em que o lançamento ocorreu (ou data fiscal do processamento). |
| `ccv00_typmov` | TEXT (1) | Tipo de movimentação: **`C`** (Crédito / Entrada de Saldo) ou **`D`** (Débito / Saída de Saldo). |
| `ccv00_vlrmov` | REAL | Valor nominal do lançamento (sempre gravado com valor absoluto positivo). |
| `ccv00_vlrsal` | REAL | Saldo acumulado na conta-corrente imediatamente após este lançamento. |
| `ccv00_observ` | TEXT | Histórico / Descrição detalhada da movimentação (ex: *"Corte de Pedido N° 12"*, *"Desconto Venda Pedido N° 13"*). |

---

## 4. FÓRMULAS E REGRAS DE CÁLCULO FINANCEIRO

### 4.1 Cálculo do CCV por Item de Pedido (`dig01_ccvtot` / `TPROItem::ccvtot`)
O valor de conta-corrente gerado ou consumido por uma linha de produto é calculado a partir do desvio do preço unitário praticado em relação ao preço máximo cadastrado na tabela de preços (`pcomax`):

$$\text{Diferença Unitária} = \text{Preço Praticado (dig01\_digpco)} - \text{Preço Máximo Tabela (dig01\_pcomax)}$$

$$\text{CCV do Item (dig01\_ccvtot)} = \text{Diferença Unitária} \times \text{Quantidade Praticada (dig01\_digqtd)}$$

*   Se $\text{dig01\_digpco} < \text{dig01\_pcomax}$: O valor resultante será **negativo** (Consumo / Débito de Saldo Flex).
*   Se $\text{dig01\_digpco} \ge \text{dig01\_pcomax}$: O valor resultante será **positivo/zero** (Sem consumo ou gerando Crédito comercial).

### 4.2 Cálculo do CCV Total do Pedido (`dig00_ccvtot`)
O somatório do CCV de todos os itens do carrinho define o impacto total do pedido na conta-corrente do vendedor:

$$\text{dig00\_ccvtot} = \sum_{i=1}^{n} \text{dig01\_ccvtot}_{i}$$

### 4.3 Cálculo do Saldo Disponível Reativo (`ccv01_vlrsalatu`)
O saldo líquido reativo de conta-corrente é computado dinamicamente considerando os saldos consolidados e as provisões de rascunhos:

$$\text{ccv01\_vlrsalatu} = \text{ccv01\_vlrsal (Saldo Base)} + \text{ccv01\_vlrusedig (Provisão Digitação)} + \text{ccv01\_vlrusepck (Provisão Envio)}$$

*   *Nota:* Como os descontos em digitação e pacotes são consumos (valores negativos), eles reduzem o Saldo Base recebido do ERP.

---

## 5. INTEGRAÇÃO COM FLUXOS OPERACIONAIS E CHECKOUT

```
  ┌────────────────────────────────────────────────────────┐
  │              DIGITAÇÃO DO ITEM (ffrmdigvenmov07)       │
  │  Calcula ccvtot por item: (digpco - pcomax) * digqtd   │
  └───────────────────────────┬────────────────────────────┘
                              │
                              v
  ┌────────────────────────────────────────────────────────┐
  │                 CHECKOUT DO PEDIDO (doPEDPost)         │
  │  Soma ccvtot de todos os itens ativos (dig00_ccvtot)   │
  └───────────────────────────┬────────────────────────────┘
                              │
                              v
             SE ven00_chkccv == true?
              /                    \
            SIM                     NÃO
            /                         \
  [Valida Saldo CCV]               [Ignora trava CCV]
  Saldo Atual + ccvtot >= 0?               │
        /             \                    │
      SIM             NÃO                  │
      /                 \                  │
[Grava Pedido]    [BLOQUEIA CHECKOUT]      │
      │           "Saldo CCV insuficiente" │
      │                                    │
      └─────────────────◄──────────────────┘
                        │
                        v
  ┌────────────────────────────────────────────────────────┐
  │              GRAVAÇÃO / PROVISÃO NO SQLITE             │
  │  - Salva pedido dig00 e itens dig01                    │
  │  - Deduz dig00_ccvtot do saldo ccv01_vlrusedig         │
  │  - Atualiza ccv01_vlrsalatu                            │
  └────────────────────────────────────────────────────────┘
```

### 5.1 O Gatilho de Validação no Checkout (`doPEDPost`)
Se o vendedor estiver parametrizado com a trava ativada (**`ven00_chkccv = true`** na tabela `cadrep00`), no momento de fechar a venda o sistema executa a checagem impeditiva:

1.  Calcula-se o CCV acumulado do carrinho (`dig00_ccvtot`).
2.  Testa-se a equação de saldo:
    $$\text{ccv01\_vlrsalatu} + \text{dig00\_ccvtot} \ge 0$$
3.  **Resultado Negativo:** Se a verba não for suficiente, o faturamento do pedido é abortado localmente e o aplicativo exibe o alerta literal: **`"Saldo de conta-corrente insuficiente para cobrir o desconto concedido!"`**. O item ou desconto deve ser revisado.
4.  **Resultado Positivo:** A gravação é liberada.

### 5.2 Ação de Provisão ao Salvar Pedido
Ao persistir o pedido com sucesso:
*   O valor de `dig00_ccvtot` (que é negativo em caso de descontos) é adicionado ao acumulador de provisão local **`ccv01_vlrusedig`** da tabela `fincaiccv01`.
*   O saldo líquido `ccv01_vlrsalatu` é imediatamente recalculado de forma reativa.

---

## 6. SINCRONIZAÇÃO E PROCESSAMENTO DO RETORNO FTP (`.ret`)

A tabela consolidada de saldos `fincaiccv01` e o histórico de lançamentos `fincaimovccv00` são atualizados compulsoriamente através do arquivo de retorno (**`.ret`**) baixado via FTP (`fcfGETRET = 6`).

### 6.1 Processamento do XML de Retorno (Tag `<ccv00>`)
Ao executar o método `importReturn(filename)`, o parser local varre o nó `<ccv00>` do XML e executa as seguintes transações:

1.  **Limpeza de Provisões Locais:** O ERP central recalcula e consolida os saldos totais de conta-corrente baseando-se em todos os pedidos que foram importados e faturados com sucesso no servidor. Dessa forma, as provisões locais de digitação (`vlrusedig`) e pacotes (`vlrusepck`) do lote processado são zeradas no aparelho.
2.  **Atualização de Saldo Oficial (`ccv01_vlrsal`):** Sobrescreve o saldo com os valores processados na central:
    ```sql
    UPDATE fincaiccv01 SET
        ccv01_vlrsal      = 84.84,    -- Saldo base oficial calculado na retaguarda
        ccv01_vlrusedig   = -98.02,   -- Mantém apenas provisões de rascunhos que NÃO estavam no .pac enviado
        ccv01_vlrusepck   = 0.00,     -- Zera a provisão do lote enviado que foi processado
        ccv01_vlrsalatu   = -13.18    -- Novo saldo líquido disponível calculado
    WHERE ccv01_codven = 71;
    ```
3.  **Inserção de Lançamentos de Histórico:** O nó `<fincaimovccv00>` (se enviado pelo ERP) gera registros analíticos na tabela local `fincaimovccv00` para documentar créditos de comissões, estornos de faturamento, cancelamentos de Notas Fiscais ou débitos consolidados de vendas.

---

## 7. ROTEIRO DE TELA E INTERFACE DO USUÁRIO (`ffrmrelccv00`)

A tela de visualização do Conta-Corrente (**`ffrmrelccv00`**) apresenta duas estruturas visuais principais ao vendedor em campo:

### 7.1 Painel de Resumo / Consolidação (Grid Superior / Grid 2)
Exibe de forma sintética os saldos vigentes do vendedor extraídos da tabela `fincaiccv01`:

| Campo Comercial | Origem no SQLite | Descrição de Negócio |
| :--- | :--- | :--- |
| **Saldo Base** | `ccv01_vlrsal` | Saldo oficial recebido na última sincronização com o ERP. |
| **Em Digitação** | `ccv01_vlrusedig` | Provisão consumida por pedidos de rascunho salvos localmente. |
| **Em Trânsito** | `ccv01_vlrusepck` | Provisão consumida por pacotes enviados aguardando retorno. |
| **Saldo Disponível** | `ccv01_vlrsalatu` | **Saldo líquido real.** Determina a verba livre para novos descontos. |

### 7.2 Grade Analítica de Lançamentos (Grid Principal / Grid 1)
Exibe a listagem cronológica das movimentações ocorridas na conta, extraída de `fincaimovccv00`:

| Coluna | Campo no SQLite | Alinhamento / Formato | Descrição do Lançamento |
| :--- | :--- | :--- | :--- |
| **Data** | `ccv00_datmov` | Centralizado (DD/MM/AAAA) | Data do registro da movimentação. |
| **Tipo** | `ccv00_typmov` | Centralizado (`C` / `D`) | Tipo de lançamento (Crédito ou Débito). |
| **Valor** | `ccv00_vlrmov` | À Direita (REAL - R\$ X,XX) | Valor absoluto do lançamento monetário. |
| **Saldo** | `ccv00_vlrsal` | À Direita (REAL - R\$ X,XX) | Saldo residual da conta-corrente após a movimentação. |
| **Observação** | `ccv00_observ` | À Esquerda (TEXT) | Histórico contendo a origem ou motivo do lançamento. |

---

## 8. REQUISITOS DE DESIGN E IMPLEMENTAÇÃO EM FLUTTER (RECOMENDAÇÕES)

A reescrita deste módulo no Flutter deve modernizar a experiência de usuário (UX) aproveitando as facilidades de gerenciamento de estado reativo e banco de dados local robusto:

1.  **Gerenciamento de Estado Reativo (BLoC / Cubit):**
    *   O checkout deve escutar reativamente as alterações no carrinho de compras.
    *   Toda vez que a quantidade ou o preço de um item for alterado, o Cubit de Checkout deve recalcular instantaneamente o impacto de CCV (`ccvtot`) e atualizar um indicador visual na barra superior do aplicativo.
2.  **Sinalização Visual de Saldo Flex:**
    *   Utilizar um componente de medidor ou barra de progresso colorida na tela do carrinho:
        *   **Verde:** Saldo CCV amplamente positivo (margem comercial saudável).
        *   **Amarelo:** Saldo CCV aproximando-se de zero.
        *   **Vermelho:** Saldo CCV negativo ou próximo do limite de bloqueio.
3.  **Persistência Reativa (Drift / SQLite):**
    *   Utilizar streams do Drift para observar alterações na tabela `fincaiccv01`. 
    *   Toda vez que o processo de sincronização ler um `.ret` e atualizar o banco de dados, as telas de Extrato de CCV e Carrinho de Compras devem se auto-atualizar imediatamente em tempo real, sem necessidade de recarga manual pelo usuário.
4.  **UI de Extrato Moderna:**
    *   Transformar o layout antigo de grades duplas do Qt em uma interface moderna baseada em um cabeçalho sintético de cartões (*Cards*) dinâmicos e uma lista de transações infinita (*SliverList*), dividindo as movimentações analíticas com ícones representativos para créditos (seta verde para cima) e débitos (seta vermelha para baixo).

---

## 9. RASTREABILIDADE DOS FONTES LEGADOS

*   **`ffrmrelccv00.h` / `ffrmrelccv00.cpp`:** Interface de visualização do extrato e carga dos grids analíticos e de resumo (`dodataloadgrid1`).
*   **`usysvendig00.h` / `usysvendig00.cpp`:** Classes de modelo de venda, acumuladores de verba `dig01_ccvtot` e `dig00_ccvtot()`.
*   **`usysvenfun00.h` / `usysvenfun00.cpp`:** Métodos de validação comercial, incluindo o cheque de margens `getPEDTOTCCVcheck`.
*   **`usysctr00.h`:** Estrutura das tabelas cadastrais e parâmetros de checagem do vendedor (`ven00_chkccv`).
*   **`usysvenpac00.cpp`:** Rotina de importação de arquivos de retorno (`importReturn`) e parse dos nós XML de conta-corrente.
