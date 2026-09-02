# ESPECIFICAÇÃO TÉCNICA: RELATÓRIO DE RESUMO DE VENDAS DIÁRIO E APURAÇÃO DE COMISSÕES
## Módulo de Prestação de Contas, Produtividade e Cálculo de Comissões em Campo (`ffrmrelresven00`)

Esta especificação técnica detalha todas as regras de negócio, estrutura relacional de dados, fórmulas de consolidação financeira e fluxos de navegação que regem o **Relatório de Resumo de Vendas Diário e Apuração de Comissões** da aplicação de Força de Vendas (FV). O objetivo é orientar a migração segura e reativa deste módulo do legado C++/Qt para o Flutter/Dart.

---

## 1. Visão Geral do Módulo e Propósito Comercial

O relatório de Resumo de Vendas (`ffrmrelresven00`) é o instrumento oficial de prestação de contas diária do representante em campo. Ele consolida o faturamento bruto, as devoluções de mercadorias lançadas pela retaguarda, apura a venda líquida real do período selecionado e calcula as comissões estimadas por produto/item comercializado.

### Objetivos Principais:
1. **Transparência de Desempenho:** Permitir ao vendedor auditar seu faturamento diário consolidado por período sem depender de ligações ou relatórios manuais da retaguarda.
2. **Apuração de Ganhos:** Estimar em tempo real o valor das comissões geradas com base na venda líquida, considerando o percentual parametrizado por produto e as flexibilizações comerciais aplicadas.
3. **Controle de Devoluções (Ruptura):** Confrontar os valores digitados em campo com as mercadorias devolvidas ou canceladas pelos clientes na retaguarda, fornecendo a real liquidez do faturamento do vendedor.

---

## 2. Lógica Operacional e Fluxo de Telas (UX Legado)

O módulo legado está estruturado em uma máquina de estados visual composta por três frames de controle principais dentro do mesmo formulário (`ffrmrelresven00.cpp`):

```
                   MÁQUINA DE ESTADOS VISUAL (ffrmrelresven00):

             ┌─────────────────────────────────────────────────────┐
             │            frmfilter (Filtro por Período)           │
             └──────────────┬────────────────────────▲─────────────┘
                            │                        │
       (on_btnshwcal_clicked)                        │ (on_btnselect_clicked / Calendário)
                            ▼                        │
             ┌───────────────────────────────────────┴─────────────┐
             │               frmcalend (Seleção de Data)           │
             └─────────────────────────────────────────────────────┘
                            │
                            │ (on_btcarregar_clicked / dogridload)
                            ▼
             ┌─────────────────────────────────────────────────────┐
             │              frmresult (Grade de Resultados)        │
             │   Exibe: Ven/Bruta  ➔  Devolução  ➔  Ven/Liq. ➔  Comiss.│
             └─────────────────────────────────────────────────────┘
```

### 2.1 Passos de Navegação:
1. **Definição do Período (`frmfilter`):**
   * O formulário inicia exibindo os campos de data inicial (`txtdatini`) e data final (`txtdatfim`). O foco inicial é direcionado para `txtdatini` (`doPageFilterShow()`).
2. **Seleção por Calendário (`frmcalend`):**
   * Ao acionar os botões de atalho de calendário (`btnshwcal00` ou `btnshwcal01`), o aplicativo exibe o frame de calendário (`frmcalend`) utilizando o componente `txtseldat`.
   * Ao clicar em selecionar (`btnselect`), o valor de data escolhido alimenta a variável do filtro correspondente (`datini` ou `datfim`) e o app retorna para o frame de filtros.
3. **Carga dos Dados (`frmresult`):**
   * Ao clicar no botão Carregar (`btcarregar`), o método **`dogridload()`** executa o processamento relacional dos pedidos do SQLite local no período definido e altera a exibição da tela para o frame de resultados (`frmresult`).

---

## 3. Regras de Negócio e Fórmulas de Cálculo

A grade de resultados consolida as informações financeiras em quatro colunas de faturamento acumulado, representadas pelas constantes de coluna legado:

| Constante Legada | Coluna Exibida | Origem de Dados / Regra de Cálculo |
| :--- | :--- | :--- |
| **`c2_venval = 0`** | **Ven/Bruta** *(Venda Bruta)* | Somatório dos totais líquidos digitados de todos os pedidos gravados no período selecionado. |
| **`c2_devval = 1`** | **Devolução** *(Abatimentos)* | Somatório de pedidos cancelados, devoluções de mercadorias no faturamento e devoluções físicas lançadas pela retaguarda. |
| **`c2_totval = 2`** | **Ven/Liq.** *(Venda Líquida)* | Venda Líquida Real do vendedor no período. Corresponde à Venda Bruta deduzida das Devoluções do período. |
| **`c2_comval = 3`** | **Comissão** *(Ganhos)* | Somatório da comissão apurada item por item, aplicando o percentual de comissão associado a cada produto. |

---

### 3.1 Fórmula da Venda Bruta (Gross Sales)
A Venda Bruta compreende o valor acumulado de faturamento de pedidos ativos no período, desconsiderando bonificações sem valor comercial e cancelamentos locais imediatos:

$$\text{Venda Bruta (Ven/Bruta)} = \sum_{p \in \text{Pedidos}} \text{dig00\_digtot}(p)$$

*   **Filtro Relacional:** Pedidos cujo status de sincronização (`dig00_sttenv`) seja diferente de cancelado/abortado, e a data de digitação (`dig00_datsys`) esteja contida no intervalo: 
    $$\text{datini} \le \text{dig00\_datsys} \le \text{datfim}$$

---

### 3.2 Fórmula das Devoluções e Abatimentos (Returns)
O valor de devoluções consolida as perdas de faturamento ocorridas após o empacotamento ou no processamento logístico da central, apuradas no retorno do lote de pacotes (`.ret`) ou em tabelas de faturamento delta:

$$\text{Total Devoluções (Devolução)} = \sum_{p \in \text{Pedidos}} \left( \text{dig00\_digtot}(p) - \text{dig00\_fattot}(p) \right) + \sum_{d \in \text{Devoluções}} \text{vlr\_devolucao}(d)$$

*   **Regra de Cálculo:**
    1. **Cortes de Faturamento:** Diferença entre o valor digitado pelo vendedor no smartphone (`dig00_digtot`) e o valor efetivamente faturado homologado pelo ERP no arquivo de retorno (`dig00_fattot`).
    2. **Devoluções Físicas de Notas Fiscais:** Valores de duplicatas que sofreram devoluções parciais ou totais de mercadorias na entrega ao cliente (valores atualizados delta no retorno do faturamento).

---

### 3.3 Fórmula da Venda Líquida (Net Sales)
Representa a base de faturamento real de direito do vendedor sobre a qual as metas e comissões corporativas são oficialmente apuradas:

$$\text{Venda Líquida (Ven/Liq.)} = \text{Venda Bruta} - \text{Total Devoluções}$$

---

### 3.4 Fórmula da Comissão Estimada do Representante
Diferente dos sistemas que aplicam uma taxa única de comissão sobre a venda líquida total, o sistema legado calcula a comissão **item a item (no nível de produto)**, o que garante a precisão do comissionamento em mix de produtos com margens variadas:

$$\text{Comissão Acumulada (Comissão)} = \sum_{i \in \text{Itens vendidos}} \left( \text{dig01\_fatqtd}(i) \times \text{dig01\_fatpco}(i) \times \frac{\text{pro00\_commax}(i)}{100} \right)$$

*   **Regra de Consistência Comercial:**
    1. Se o item do pedido foi bonificado pelo vendedor (`dig01_bontyp > 0`), o percentual de comissão é **zerado** para esta linha, visto que se trata de uma doação/brinde.
    2. A base de cálculo da comissão utiliza a **Quantidade Efetivamente Faturada (`dig01_fatqtd`)** em vez da digitada (`dig01_digqtd`), garantindo que o vendedor não receba comissão sobre itens que foram cortados por ruptura de estoque na retaguarda.
    3. O preço considerado é o preço líquido faturado final (`dig01_fatpco`), já deduzidos os descontos comerciais e o uso de saldo flex de conta-corrente.

---

## 4. Estrutura Relacional de Dados (Tabelas Envolvidas)

As consultas de consolidação do relatório diário do vendedor cruzam tabelas locais do banco de cadastros (`dbforcacad001.db`) e do banco de digitação (`dbforcadig001.db`):

```
       ┌────────────────────────┐             ┌────────────────────────┐
       │     dig00 (Vendas)     │             │     dig01 (Itens)      │
       │────────────────────────│             │────────────────────────│
       │ PK: dig00_digcod       │◄───(1:N)───►│ FK: dig01_digcod       │
       │     dig00_datsys       │             │     dig01_digpro       ├──────┐
       │     dig00_digtot       │             │     dig01_fatqtd       │      │
       │     dig00_fattot       │             │     dig01_fatpco       │      │ (N:1)
       └───────────▲────────────┘             └────────────────────────┘      │
                   │                                                          ▼
                   │ (N:1)                                        ┌────────────────────────┐
       ┌───────────┴────────────┐                                 │   cadpro00 (Produtos)  │
       │  cadrep00 (Vendedores) │                                 │────────────────────────│
       │────────────────────────│                                 │ PK: pro00_codigo       │
       │ PK: ven00_codigo       │                                 │     pro00_commax       │
       └────────────────────────┘                                 └────────────────────────┘
```

### Dicionário de Dados de Consolidação

#### Tabela: `dig00` (Cabeçalho de Pedidos)
* **Finalidade:** Fornece os totais brutos, faturados e datas de faturamento para cálculo diário.

| Campo | Tipo | Descrição / Regra de Negócio |
| :--- | :--- | :--- |
| `dig00_digcod` | INTEGER | Identificador único do pedido no dispositivo. |
| `dig00_datsys` | DATE | Data do lançamento do pedido pelo vendedor (Base dos filtros diários). |
| `dig00_digtot` | REAL | Total líquido do carrinho (Base para cálculo de **Venda Bruta**). |
| `dig00_fattot` | REAL | Total efetivamente faturado recebido via arquivo `.ret` (Base para **Venda Líquida**). |
| `dig00_sttenv` | INTEGER | Status de envio (`3` = `pvddeRECEBIDO` indica lote faturado na central). |

#### Tabela: `dig01` (Itens de Pedidos)
* **Finalidade:** Fornece as quantidades faturadas para apuração analítica da comissão por produto.

| Campo | Tipo | Descrição / Regra de Negócio |
| :--- | :--- | :--- |
| `dig01_digcod` | INTEGER | FK de relacionamento com `dig00_digcod`. |
| `dig01_digpro` | INTEGER | FK de relacionamento com o produto (`cadpro00_codigo`). |
| `dig01_fatqtd` | REAL | Quantidade física faturada e despachada (Base do cálculo de comissão). |
| `dig01_fatpco` | REAL | Preço unitário faturado após as negociações comerciais. |
| `dig01_bontyp` | INTEGER | Tipo de bonificação. Se `> 0`, zera a comissão daquela linha. |

#### Tabela: `cadpro00` (Cadastro de Produtos)
* **Finalidade:** Fornece as regras de comissionamento padrão de cada produto cadastrado.

| Campo | Tipo | Descrição / Regra de Negócio |
| :--- | :--- | :--- |
| `pro00_codigo` | INTEGER | Código do produto. |
| `pro00_commax` | REAL | Percentual de comissão padrão atribuído a este item (ex: `5.50` para 5.5%). |

---

## 5. Exibição Analítica de Vendas (Layout & UX no Flutter)

A interface no Flutter deve modernizar a experiência de visualização, abandonando a antiga troca de frames de layout fixo em C++ por um fluxo fluido e de rolagem contínua.

### Elementos Recomendados de UI/UX em Flutter:

1. **Filtro Rápido com Calendário Flutuante:**
   * Utilizar um **`DateRangePicker`** flutuante em substituição à navegação complexa de telas de calendário do legado. O filtro deve conter atalhos rápidos como: *"Hoje"*, *"Últimos 7 Dias"*, *"Este Mês"*.
2. **Cards de Resumo Consolidado (Painel Top):**
   * Exibir o resumo consolidado do período de forma destacada utilizando cards estilizados com cores associativas:
     * **Ven/Bruta:** Card azul (Faturamento captado).
     * **Devolução:** Card vermelho (Cortes e estornos).
     * **Ven/Liq.:** Card verde (Faturamento real de direito).
     * **Comissão:** Card dourado ou verde escuro (Ganhos do vendedor).
3. **Lista de Detalhamento Diário (Scroll Infinito):**
   * Abaixo dos cards consolidados, apresentar uma lista sanfonada agrupada por **Data**. Ao expandir uma data, exibe-se a listagem analítica dos pedidos faturados naquele dia com seus respectivos totais e as comissões calculadas.
4. **Exportação e Compartilhamento de PDF:**
   * Botão de ação rápida no cabeçalho para gerar o extrato consolidado em PDF e disparar o compartilhamento nativo para visualização externa (via WhatsApp ou e-mail).

---

### Exemplo de Design de Visualização em Flutter

```
┌──────────────────────────────────────────────────────────┐
│ 📅  01/09/2026 a 02/09/2026                     [Export] │
├──────────────────────────────────────────────────────────┤
│                                                          │
│  VENDA BRUTA (R$)               DEVOLUÇÕES/CORTES (R$)   │
│  ┌─────────────────────────┐   ┌──────────────────────┐  │
│  │ R$ 1.759,18             │   │ R$ 258,68            │  │
│  └─────────────────────────┘   └──────────────────────┘  │
│                                                          │
│  VENDA LÍQUIDA (R$)             COMISSÃO ESTIMADA (R$)   │
│  ┌─────────────────────────┐   ┌──────────────────────┐  │
│  │ R$ 1.500,50             │   │ R$ 82,52             │  │
│  └─────────────────────────┘   └──────────────────────┘  │
│                                                          │
├──────────────────────────────────────────────────────────┤
│ DETALHAMENTO DIÁRIO                                      │
│                                                          │
│ ▼ [01/09/2026]                                           │
│   Pedido #12 - MERCADO CENTRAL LTDA                      │
│   Venda: R$ 191,16 | Faturado: R$ 191,16 | Comis: R$ 9,55│
│                                                          │
│   Pedido #13 - PADARIA ESTRELA DA MANHA                  │
│   Venda: R$ 23,88  | Faturado: R$ 23,88  | Comis: R$ 1,19│
│                                                          │
│ ▼ [02/09/2026]                                           │
│   Pedido #10 - COMERCIAL SILVA LTDA                      │
│   Venda: R$ 258,68 | Faturado: R$ 0,00   | Comis: R$ 0,00│
│   (Corte total por falta de estoque físico)              │
│                                                          │
└──────────────────────────────────────────────────────────┘
```

---

## 6. Implementação Técnica e Diretrizes para o Flutter

### 6.1 Query SQL Recomendada para a Camada Data (Drift / Sqflite)
Para obter os totais em uma única chamada de banco de dados local de forma otimizada por período, a camada de repositório deve executar a seguinte consulta agregadora:

```sql
SELECT 
    SUM(d00.dig00_digtot) AS venda_bruta,
    SUM(d00.dig00_digtot - d00.dig00_fattot) AS total_cortes,
    SUM(d00.dig00_fattot) AS venda_liquida,
    SUM(
        -- Aplica o cálculo individual de comissão por linha de item
        SELECT SUM(
            CASE 
                WHEN d01.dig01_bontyp > 0 THEN 0.0 -- Zera comissão se item for bonificado
                ELSE d01.dig01_fatqtd * d01.dig01_fatpco * (p00.pro00_commax / 100.0)
            END
        )
        FROM dig01 d01
        INNER JOIN cadpro00 p00 ON p00.pro00_codigo = d01.dig01_digpro
        WHERE d01.dig01_digcod = d00.dig00_digcod
    ) AS comissao_total
FROM dig00 d00
WHERE d00.dig00_sttenv = 3 -- Apenas pedidos finalizados e retornados do faturamento
  AND d00.dig00_datsys BETWEEN :dataInicial AND :dataFinal;
```

### 6.2 Gerência de Estado Reativa com Cubit/BLoC
O carregamento deste relatório deve ser assíncrono e gerido por estado:

1. **`SalesSummaryLoading`:** Estado inicial quando a query SQL está sendo processada no banco local SQLite. Exibe um indicador de progresso circular (`CircularProgressIndicator`).
2. **`SalesSummaryLoaded`:** Estado ativo com a passagem dos modelos de dados contendo venda bruta, devoluções, venda líquida e comissão estimada. Alimenta reativamente os cards e a listagem analítica.
3. **`SalesSummaryError`:** Estado de falha caso ocorra inconsistência no acesso aos bancos locais de dados.

### 6.3 Garantia de Execução Offline-First
*   O relatório deve funcionar **100% de forma offline**. Toda a apuração de vendas e comissões baseia-se nos registros locais armazenados no aparelho (`dig00`, `dig01` e `cadpro00`).
*   O relatório não faz requisições Web/HTTP para a central no momento de seu carregamento. O saldo atualizado das devoluções e do faturamento real é garantido pela sincronização prévia feita pelo processamento do arquivo de retorno `.ret` via FTP.
