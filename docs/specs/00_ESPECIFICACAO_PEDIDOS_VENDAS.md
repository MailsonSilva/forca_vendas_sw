# ESPECIFICAÇÃO TÉCNICA E DE REGRAS DE NEGÓCIO: MÓDULO DE PEDIDOS E EMISSÃO DE VENDAS

Este documento estabelece a especificação funcional e técnica completa do **Módulo de Pedidos e Emissão de Vendas** do sistema de Força de Vendas (FV) móvel, mapeando as regras de negócio, o ciclo de vida de faturamento, a persistência relacional local (SQLite) e os algoritmos financeiros contidos no motor C++/Qt para guiar uma migração limpa e reativa para o Flutter.

---

## 1. Ciclo de Vida do Pedido (Máquina de Estados)

A situação comercial e o fluxo de transmissão de cada pedido de venda gravado no celular são regidos por uma máquina de estados dupla, controlada pelos campos **`dig00_sttdig`** (status de digitação) e **`dig00_sttenv`** (status de envio) na tabela local de cabeçalhos **`dig00`**.

```
              [Início da Digitação]
                        │
                        v
         ┌──────────────────────────────┐
         │ RASCUNHO (pvddsEDITANDO)     │ <─── (Itens sendo inseridos/removidos)
         │ sttdig = 0 | sttenv = 0      │
         └──────────────┬───────────────┘
                        │
             (doPEDPost() / cpost())
                        │
                        v
         ┌──────────────────────────────┐
         │ CONCLUÍDO (pvddsDIGITADO)    │ ───> [Ação Excluir] ──> Expurgo Físico
         │ sttdig = 1 | sttenv = 0      │
         └──────────────┬───────────────┘
                        │
            (Empacotamento ffrmdiggerpac)
                        │
                        v
         ┌──────────────────────────────┐
         │ EMPACOTADO (pvddeEMPACOTE)   │ (Travado para edições no grid)
         │ sttdig = 1 | sttenv = 1      │
         └──────────────┬───────────────┘
                        │
             (Confirmação Upload FTP)
                        │
                        v
         ┌──────────────────────────────┐
         │ TRANSMITIDO (pvddeENVIADOS)  │ (Integrado na Retaguarda/ERP)
         │ sttdig = 1 | sttenv = 2      │
         └──────────────────────────────┘
```

### Estados Lógicos e Transições:

*   **Rascunho / Em Digitação (`pvddsEDITANDO` | `sttdig = 0`, `sttenv = 0`):**
    *   *Definição:* O pedido está sendo ativamente manipulado pelo vendedor. Os itens são inseridos, alterados ou removidos em memória e gravados de forma provisória no SQLite.
    *   *Transição de Saída:* Avança para "Concluído" via clique em salvar na tela de fechamento ou reverte via descarte (`doPEDAbort()`), limpando buffers e expurgando as linhas locais sem deixar resíduos.
*   **Concluído / Fechado (`pvddsDIGITADO` | `sttdig = 1`, `sttenv = 0`):**
    *   *Definição:* O pedido foi validado e fechado pelo motor de faturamento comercial. Seus valores são congelados e o pedido entra na fila pendente de envio.
    *   *Transição de Saída:* Avança para "Empacotado" durante o processo de geração automática de lotes na sincronização. Permite exclusão física ou reabertura para edição (mudando o status de volta para Rascunho).
*   **Empacotado (`pvddeEMPACOTE` | `sttdig = 1`, `sttenv = 1`):**
    *   *Definição:* O pedido foi selecionado pelo empacotador, serializado em formato XML e inserido dentro do arquivo compactado `.pac` correspondente ao lote.
    *   *Regra de Negócio:* Fica bloqueado de forma estrita contra qualquer alteração ou exclusão física no dispositivo móvel.
*   **Transmitido (`pvddeENVIADOS` | `sttdig = 1`, `sttenv = 2`):**
    *   *Definição:* O cliente FTP do aparelho transmitiu com sucesso absoluto o pacote `.pac` para o servidor central e recebeu a confirmação de upload íntegro.
    *   *Regra de Negócio:* Fica disponível exclusivamente para consulta histórica, visualização detalhada ou replicação para outros clientes.
*   **Bloqueado / Retido:**
    *   *Definição:* Estado lógico que ocorre se o cliente possuir restrição financeira ou limite de crédito estourado e o vendedor não possuir permissão parametrizada para liberação automática (`ven00_ignlimfis = 0`). O pedido permanece no dispositivo aguardando inserção local da senha de supervisor (`ven00_passet`).

---

## 2. Cabeçalho e Itens (Persistência e Snapshots Fiscais)

O pedido é dividido em duas tabelas relacionais de movimentação local presentes no banco de digitação **`dbforcadig001.db`**: **`dig00`** (Cabeçalho do Pedido) e **`dig01`** (Itens do Pedido).

### A. Tabela de Cabeçalho: `dig00`

Armazena as informações consolidadas da venda, os identificadores de regras financeiras aplicadas e os totais acumulados calculados no dispositivo.

| Coluna SQLite | Tipo de Dado | Restrição | Descrição e Finalidade Comercial (Snapshot) |
| :--- | :--- | :--- | :--- |
| `dig00_digfil` | `INTEGER` | PK, FK | Código da filial responsável pelo faturamento do pedido. |
| `dig00_digcod` | `INTEGER` | PK | Número incremental sequencial do pedido gerado localmente. |
| `dig00_clicod` | `INTEGER` | FK | Código identificador exclusivo do cliente faturado. |
| `dig00_clides` | `TEXT` | - | Razão Social do cliente (congelada no ato para histórico). |
| `dig00_placod` | `INTEGER` | FK | Código do plano / condição de faturamento aplicado à venda. |
| `dig00_digagt` | `INTEGER` | FK | Código do Agente Cobrador financeiro que receberá o boleto. |
| `dig00_digtot` | `REAL` | - | Valor total líquido final do pedido (líquido de descontos). |
| `dig00_bontot` | `REAL` | - | Valor total correspondente a produtos distribuídos como bonificação. |
| `dig00_subtot` | `REAL` | - | Valor consolidado do imposto de Substituição Tributária (ICMS-ST). |
| `dig00_sttdig` | `INTEGER` | - | Código numérico de status de digitação (`0` = Rascunho, `1` = Concluído). |
| `dig00_sttenv` | `INTEGER` | - | Código numérico de status de envio (`0` = Pendente, `1` = Empacotado, `2` = Enviado). |
| `dig00_datsys` | `TEXT` | - | Timestamp de fechamento do pedido no dispositivo (`YYYY-MM-DD HH:MM:SS`). |

### B. Tabela de Itens: `dig01`

Armazena os registros filhos que compõem o corpo de mercadorias faturadas no pedido, gravando um instantâneo de preços e custos para evitar fraudes ou alterações retroativas de tabelas.

| Coluna SQLite | Tipo de Dado | Restrição | Descrição e Finalidade Comercial (Snapshot) |
| :--- | :--- | :--- | :--- |
| `dig01_digfil` | `INTEGER` | PK, FK | Código da filial de faturamento (herdado do cabeçalho). |
| `dig01_digcod` | `INTEGER` | PK, FK | ID do pedido de cabeçalho correspondente. |
| `dig01_digitm` | `INTEGER` | PK | Sequencial numérico do produto no carrinho (Item 1, 2, 3...). |
| `dig01_digpro` | `INTEGER` | FK | Código único de identificação do produto no catálogo. |
| `dig01_digqtd` | `REAL` | - | Quantidade física vendida (inteira ou decimal/fracionada). |
| `dig01_digpco` | `REAL` | - | Preço unitário final praticado (já com descontos/acréscimos aplicados). |
| `dig01_subtot` | `REAL` | - | Valor de Substituição Tributária (ICMS-ST) calculado para esta linha. |
| `dig01_destot` | `REAL` | - | Valor nominal absoluto correspondente ao desconto aplicado ao item. |

---

## 3. Motor de Cálculo Financeiro Local

Para garantir a igualdade matemática absoluta entre o faturamento calculado localmente pelo vendedor offline e a homologação fiscal no ERP central, o motor financeiro executa rotinas aritméticas padronizadas em nível de item e de totais de cabeçalho.

### A. Fórmulas de Cálculo por Linha de Item (`dig01`)

1.  **Valor Bruto do Item:**
    O totalizador inicial do produto sem deduções financeiras:
    \\[ \text{Valor Bruto} = \text{dig01\_digqtd} \times \text{Preço Tabela (Original)} \\]
2.  **Cálculo do Desconto Nominal por Item (`dig01_destot`):**
    O desconto pode ser informado pelo vendedor em porcentagem (**`%`**) ou em valor absoluto (**`$`**). O motor normaliza o desconto para valor absoluto por unidade física vendida:
    *   *Se informado em Porcentagem (%):*
        \\[ \text{dig01\_destot} = \text{Preço Tabela} \times \left( \frac{\text{Percentual Desconto}}{100} \right) \\]
    *   *Se informado em Valor Absoluto ($):*
        \\[ \text{dig01\_destot} = \text{Valor Desconto Unitário Digitado} \\]
3.  **Preço Unitário Praticado (`dig01_digpco`):**
    É o preço final efetivo de faturamento da mercadoria:
    \\[ \text{dig01\_digpco} = \text{Preço Tabela} - \text{dig01\_destot} + \text{Fator Plano (Acréscimo/Desconto Financeiro)} \\]
4.  **Cálculo da Substituição Tributária (ICMS-ST) Local:**
    Executada pelo motor fiscal da classe **`Tsysfis00ICMSSubst`**. O imposto é calculado localmente se o cliente possuir perfil contribuinte de ICMS e o produto pertencer à categoria de ST:
    \\[ \text{Base de Cálculo ICMS-ST} = (\text{dig01\_digpco} \times \text{dig01\_digqtd}) \times \left(1 + \frac{\text{MVA Parametrizado}}{100}\right) \\]
    \\[ \text{dig01\_subtot (Imposto ST)} = \left(\text{Base de Cálculo ICMS-ST} \times \frac{\text{Alíquota Interna UF}}{100}\right) - \text{ICMS Próprio Deduzido} \\]

### B. Fórmulas de Consolidação do Cabeçalho (`dig00`)

O fechamento do cabeçalho soma reativamente as linhas filhas consolidadas:

1.  **Valor Líquido Comercial (Faturamento do Pedido - `dig00_digtot`):**
    \\[ \text{dig00\_digtot} = \sum_{i=1}^{n} \left( \text{dig01\_digqtd}_i \times \text{dig01\_digpco}_i \right) \\]
2.  **Consolidação Geral do Imposto ST (`dig00_subtot`):**
    \\[ \text{dig00\_subtot} = \sum_{i=1}^{n} \text{dig01\_subtot}_i \\]
3.  **Valor Total Financeiro de Encerramento (Total a Cobrar):**
    \\[ \text{Total Geral Financeiro} = \text{dig00\_digtot} + \text{dig00\_subtot} + \text{Despesas de Frete/Seguro} \\]

### C. Regras de Arredondamento e Casas Decimais
*   **Precisão do Estoque e Quantidade:** Armazenado e processado com **3 casas decimais** para dar suporte integral a produtos comercializados por peso ou frações físicas (ex: `12.450 KG`).
*   **Precisão Monetária e Preços:** Todos os cálculos intermediários de descontos e impostos de Substituição Tributária utilizam **4 casas decimais** de precisão aritmética em variáveis ponto flutuante do tipo `double`.
*   **Apresentação e Persistência Final:** O valor final gravado em `dig00_digtot` e `dig01_digpco` é truncado e arredondado para exatamente **2 casas decimais** utilizando a regra de arredondamento comercial da ABNT (arredonda para o par mais próximo caso o dígito seguinte seja exatamente 5).

---

## 4. Condições de Pagamento e Cobrança

O plano financeiro selecionado dita os prazos, o número de parcelas, o cálculo de juros e o Agente Cobrador autorizado a emitir as duplicatas do pedido.

### A. Seleção do Plano de Pagamento (`cadpla00` | `pla00`)
*   Ao abrir o pedido, o vendedor seleciona a condição comercial (ex: "30/60 DIAS"). O plano possui um multiplicador financeiro de acréscimo ou desconto (**`pla00_fator`**) que é herdado e embutido automaticamente no cálculo do preço praticado de cada item (`dig01_digpco`).

### B. Cálculo de Parcelamento e Vencimentos Offline
Com base na data do sistema gravada no fechamento do pedido (**`dig00_datsys`**), o motor financeiro executa o desdobramento de duplicatas locais para projetar o fluxo de caixa do cliente:
*   O sistema lê a regra de intervalos de parcelas cadastrada no plano (ex: "30, 60, 90").
*   Para cada parcela cadastrada, calcula a data teórica de vencimento adicionando os dias correspondentes:
    \\[ \text{Data Vencimento Parcela } n = \text{dig00\_datsys} + \text{Dias Prazo } n \\]
*   Se o dia resultante cair em finais de semana ou feriados nacionais cadastrados na tabela **`cadfer00`**, a data é postergada automaticamente para o primeiro dia útil subsequente.

### C. Regras do Agente Cobrador (`codage00` | `cob00`)
*   O campo **`dig00_digagt`** armazena o agente financeiro faturador da venda. 
*   **Seleção Padrão:** O sistema realiza uma pré-seleção inteligente lendo o código de cobrança padrão associado ao cadastro do cliente (**`cli00_codage`**).
*   **Consistência de Cobrança:** Se o representante alterar a forma de pagamento para dinheiro ou carteira própria, o motor comercial limpa a seleção do banco emissor e define o agente padrão correspondente a faturamento interno do vendedor.

---

## 5. Pipeline de Fechamento (`doPEDPost` / `cpost`)

Ao clicar para concluir e gravar a venda na interface móvel, o sistema dispara a rotina central **`Tpckvendig00::cpost(bool checkFIS)`**, executando um pipeline impeditivo de integridade técnica e de regras de negócios antes de consolidar o commit das tabelas no banco de dados local SQLite.

```
                  [Clique em Concluir Venda]
                              │
                              v
             [Fase 1: Validações de Integridade]
       - Possui itens adicionados no carrinho? (QTD > 0)
       - O cliente selecionado está ativo? (cli00_active = 1)
                              │
                              v
               [Fase 2: Validações Financeiras]
       - Possui duplicatas vencidas? (Inadimplência crônica)
       - Ultrapassa limite de crédito atualizado? (cli00_creatu)
       - Exige Agente Cobrador cadastrado? (ven00_chkage)
                              │
                              v
                [Fase 3: Validações de Estoque]
       - chkest = 1? Verifica saldo físico vs. outros rascunhos
                              │
                              v
             [Fase 4: Abertura de Transação SQL]
                       BEGIN TRANSACTION;
                              │
                              v
               [Fase 5: Persistência Física (Commit)]
       - Inserção/Atualização do cabeçalho em dig00
       - Inserção em lote (bulk insert) dos itens em dig01
       - Baixa do estoque físico local (pro00_qtdest)
       - COMMIT TRANSACTION;
                              │
                              v
                  [Fila de Transmissão .pac]
```

### Detalhamento das Etapas de Validação:

1.  **Validação de Itens do Carrinho:**
    *   *Regra:* O vetor de objetos em memória do carrinho de compras não pode estar vazio (`children.count() > 0`). Itens com quantidade digitada zerada ou negativa são excluídos da lista antes da gravação.
2.  **Validação de Cadastro do Cliente:**
    *   *Regra:* O sistema relê a tabela `cadcli00` para garantir que o cliente selecionado não foi inativado (`cli00_active = 0`) por outra carga de sincronização em segundo plano enquanto o vendedor digitava o pedido.
3.  **Auditoria de Crédito e Inadimplência:**
    *   *Regra:* Confronta o saldo totalizado do pedido contra o limite rotativo disponível (`cli00_creatu`). Se ultrapassar e a flag `ven00_ignlimfis` for desativada, interrompe o pipeline e impede o salvamento. Se o cliente possuir títulos vencidos em atraso acima do teto de tolerância, exige a inserção física da senha do supervisor (`ven00_passet`).
4.  **Validação de Agente Cobrador:**
    *   *Regra:* Se o plano exigir banco faturador (`ven00_chkage = 1`), o sistema valida se o campo `dig00_digagt` possui um ID válido e ativo cadastrado na tabela de cobradores.
5.  **Validação de Disponibilidade de Estoque:**
    *   *Regra:* Se a validação de estoque estiver ativa (`ven00_chkest = 1`), o sistema executa o método **`Tsysvenfun00::estoqueCheck()`**. O saldo físico do produto na tabela `cadpro00` é confrontado contra as quantidades vendidas, somando reativamente as reservas presas em outros carrinhos locais em edição concorrente no celular. Havendo insuficiência de saldo, o sistema cancela a gravação física e exibe o alerta de erro `"Estoque insuficiente para o produto X"`.
6.  **Persistência Relacional em lote (Commit):**
    *   Uma vez superadas todas as fases de integridade e validações, a rotina de persistência física inicia uma transação exclusiva no banco **`dbforcadig001.db`**:
        ```sql
        BEGIN TRANSACTION;
        ```
    *   **Passo A:** Realiza a inserção do registro pai de cabeçalho na tabela **`dig00`** com todos os dados monetários finais calculados e carimbo de data atual do dispositivo.
    *   **Passo B:** Realiza a gravação física sequencial de todos os itens do carrinho na tabela de linhas filhas **`dig01`**, aplicando o snapshot final de preços.
    *   **Passo C:** Atualiza o saldo físico na tabela de catálogo do produto de forma local, deduzindo a quantidade vendida para garantir a consistência das próximas vendas.
    *   **Passo D:** Executa o commit transacional:
        ```sql
        COMMIT TRANSACTION;
        ```
    *   Se ocorrer qualquer erro de escrita em disco ou violação de restrição do SQLite, o sistema executa automaticamente um **`ROLLBACK`**, mantém o carrinho intacto em memória de edição (`EDITANDO`) e notifica o vendedor sobre a falha para evitar corrupção física do banco de dados local do smartphone.
