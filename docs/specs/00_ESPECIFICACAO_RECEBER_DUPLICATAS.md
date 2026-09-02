# ESPECIFICAÇÃO TÉCNICA E REGRAS DE NEGÓCIO: MÓDULO DE CONTAS A RECEBER (RECEBER)

Este documento especifica o funcionamento, o mapeamento de tabelas locais (SQLite), as regras de negócio e os fluxos de telas associados ao menu **"Receber"** (Contas a Receber / Gestão de Duplicatas) do sistema de Força de Vendas (FV) legado, fornecendo diretrizes precisas para sua migração e modernização em Flutter.

---

## 1. Visão Geral do Módulo

O menu **"Receber"** (representado pelo ícone `B_Receber.png` no menu principal `ffrmmenpri00`) é o hub de auditoria financeira offline do vendedor. Ele serve para acompanhar a adimplência da carteira de clientes, auditar títulos em aberto, calcular juros de mora acumulados de forma offline e atuar como barreira crítica de segurança no fluxo de digitação de novos pedidos.

O sistema divide esse módulo em três visões complementares:
1. **Consulta Consolidada Geral (`ffrmrelrecdup00`):** Visão geral por cliente, mostrando saldo devedor e vencido.
2. **Extrato Detalhado do Cliente (`ffrmrelrecdup01`):** Visão detalhada de todos os títulos de um cliente, exibindo datas, valores devedores, pagamentos parciais, juros e limites de crédito.
3. **Barreira de Checkout na Digitação (`ffrmrelrecdup02`):** Tela acionada de forma transparente durante a abertura do pedido (`ffrmdigvenmov00`) para forçar o vendedor a auditar os débitos de clientes inadimplentes.

---

## 2. O que o Módulo "FAZ" vs. "NÃO FAZ" (Escopo de Negócio)

Para blindar o escopo durante o desenvolvimento em Flutter, é crucial estabelecer os limites da aplicação FV em campo:

### O que o Sistema FAZ:
*   **Consulta Offline de Títulos:** Carrega de forma instantânea e 100% offline o saldo financeiro histórico enviado pelo ERP na tabela local `dup00` (ou `cadrecdup00`).
*   **Classificação Automática de Títulos:** Divide os títulos em aberto em três categorias reativas: *Geral* (todos), *Apenas Vencidos* (em atraso) e *A Vencer* (no prazo).
*   **Cálculo Offline de Dias de Atraso:** Apura em tempo real os dias de atraso comparando o vencimento do título (`dup00_datven`) com a data atual do smartphone (`QDate::currentDate()`).
*   **Cálculo Ponderado de Juros:** Aplica taxas de juros de mora parametrizadas por dia de atraso sobre o saldo devedor de cada título em aberto.
*   **Vínculo com Limite de Crédito:** Cruza o saldo devedor total do cliente (`cli00_titven`) com o seu limite atualizado de crédito disponível (`cli00_creatu`) e limite original (`cli00_crelim`).
*   **Barreira de Bloqueio de Pedidos:** Impede a abertura de novos pedidos para clientes com títulos em atraso ou limite estourado, exibindo a tela de duplicatas como justificativa de bloqueio.

### O que o Sistema NÃO FAZ (Impedimentos do FV):
*   **NÃO Faz Baixa de Títulos Offline:** O vendedor **não pode dar quitação real**, registrar pagamentos em dinheiro/cheque ou emitir recibos de quitação de duplicatas pelo aplicativo FV. A liquidação física e financeira ocorre estritamente na retaguarda (ERP).
*   **NÃO Gera Boletos ou Pix no App:** O aplicativo não emite segundas vias de boletos ou códigos de Pix de forma local. Ele apenas expõe a situação do título.
*   **NÃO Altera Dados Financeiros:** O vendedor não pode prorrogar datas de vencimento, conceder descontos sobre títulos ou abonar juros localmente.

---

## 3. Mapeamento de Banco de Dados Local (SQLite)

Os dados financeiros são alimentados a partir do arquivo de Carga de Cadastros (`dbforcacad001.db`) enviado pelo ERP.

### A. Tabela de Títulos / Duplicatas (`dup00` ou `cadrecdup00`)
Armazena os registros individuais de títulos financeiros.

| Campo SQLite | Tipo | Descrição / Regra de Negócio |
| :--- | :--- | :--- |
| **`dup00_codigo`** | `INTEGER (PK)`| Número do título físico / duplicata emitida pelo ERP. |
| **`dup00_codcli`** | `INTEGER (FK)`| Vínculo com o código do cliente (`cli00_codigo`). |
| **`dup00_datemi`** | `DATE` | Data de emissão original do título. |
| **`dup00_datven`** | `DATE` | Data limite de vencimento para o pagamento. |
| **`dup00_valori`** | `REAL` | Valor nominal bruto original da duplicata. |
| **`dup00_valdev`** | `REAL` | **Saldo Devedor:** Valor líquido que resta pagar (bruto menos pagamentos parciais). |
| **`dup00_valpag`** | `REAL` | Valor total já amortizado/recebido pela retaguarda. |
| **`dup00_codven`** | `INTEGER` | Código do vendedor responsável pela venda originária. |
| **`dup00_codagt`** | `INTEGER` | Agente cobrador associado ao título (banco, carteira, etc.). |
| **`dup00_codcob`** | `INTEGER` | Tipo de cobrança padrão parametrizado no título. |

### B. Campos Financeiros Acoplados no Cliente (`cadcli00` ou `cli00`)
O cadastro de clientes mantém colunas calculadas na retaguarda para agilizar consultas em grids:

| Campo SQLite | Tipo | Descrição / Regra de Negócio |
| :--- | :--- | :--- |
| **`cli00_crelim`** | `REAL` | Limite de crédito máximo original aprovado no cadastro. |
| **`cli00_creatu`** | `REAL` | Limite de crédito disponível líquido real no momento (deduzido de compras recentes). |
| **`cli00_titven`** | `REAL` | **Total Vencido:** Soma consolidada de juros + saldo devedor de títulos já vencidos. |
| **`cli00_titave`** | `REAL` | **Total A Vencer:** Soma consolidada de títulos no prazo de vencimento. |

---

## 4. Detalhamento de Fluxos e Telas

### Fluxo 1: Consulta Consolidada Geral (`ffrmrelrecdup00`)
Quando o vendedor acessa o menu principal e clica em **"Receber"**, o sistema abre a tela no modo Filtro (`ui->frmFilter`).

```
    [Menu principal] ➔ Clique "Receber"
           │
           ▼
    ┌──────────────────────────────────────────────┐
    │          FILTROS DE SELEÇÃO (frmFilter)      │
    │  [Botão 1: Geral]    ➔ dogridload(0)         │
    │  [Botão 2: Vencidos] ➔ dogridload(1)         │
    │  [Botão 3: A Vencer] ➔ dogridload(2)         │
    └──────────────────────┬───────────────────────┘
                           │ (dogridload / dodataload)
                           ▼
    ┌──────────────────────────────────────────────┐
    │          GRADE DE CLIENTES (frmResult)       │
    │  - Grid agrupa clientes com débitos ativos.  │
    │  - Exibe Código, Nome, Fantasia, Vencido,    │
    │    A Vencer e Total de Devedor por Cliente.   │
    └──────────────────────┬───────────────────────┘
                           │ (Double Click / btnextract)
                           ▼
    [Abre Extrato Detalhado do Cliente ffrmrelrecdup01]
```

#### Regras de Filtro em `ffrmrelrecdup00`:
1.  **Geral (`type = 0`):** Carrega todos os clientes que possuem qualquer saldo devedor (`dup00_valdev > 0`), independente de estarem vencidos ou a vencer.
2.  **Vencidos (`type = 1`):** Filtra e exibe apenas clientes que possuem títulos com vencimento anterior à data atual do sistema (`dup00_datven < CURRENT_DATE` e `dup00_valdev > 0`).
3.  **A Vencer (`type = 2`):** Filtra e exibe apenas clientes cujos títulos vencerão a partir do dia atual (`dup00_datven >= CURRENT_DATE` e `dup00_valdev > 0`).

---

### Fluxo 2: Extrato Detalhado do Cliente (`ffrmrelrecdup01`)
Esta tela exibe a ficha financeira analítica de todas as duplicatas (`dup00`) vinculadas ao cliente selecionado.

```
+-----------------------------------------------------------------------------+
| Cliente: (1542) MERCADO CENTRAL LTDA                                        |
| Obs: ENTREGAR BOLETOS COM A MERCADORIA                                       |
+-----------------------------------------------------------------------------+
| Titulo  | Emissão    | Vencimento | Dias/At | Juros     | Devedor | Receb.  |
+---------+------------+------------+---------+-----------+---------+---------+
| 4677834 | 2026-08-01 | 2026-08-15 | 32      | 15.200    | 191.160 | 0.000   | (Vermelho)
| 4677835 | 2026-08-10 | 2026-09-10 | 0       | 0.000     | 23.880  | 0.000   | (Normal)
+---------+------------+------------+---------+-----------+---------+---------+
| Totais Financeiros:                                                         |
| Limite Original: R$ 2.000,00                  Saldo Devedor: R$ 215,04      |
| Limite Atual:    R$ 1.784,96                  Total Vencido: R$ 206,36      |
+-----------------------------------------------------------------------------+
|                                  [ FECHAR ]                                 |
+-----------------------------------------------------------------------------+
```

#### Algoritmo de Cálculo de Dias de Atraso e Juros Acumulados:
Durante o carregamento do grid, o método **`diasAtrasado()`** calcula os dias de atraso de forma dinâmica para cada registro:

```cpp
int ffrmrelrecdup01::diasAtrasado(QDate dtVencimento) 
{
    if (!dtVencimento.isValid() || dtVencimento >= QDate::currentDate()) {
        return 0;
    }
    
    int dias = 0;
    QDate tempDate = dtVencimento;
    while (tempDate < QDate::currentDate()) {
        dias++;
        tempDate = tempDate.addDays(1); // Incrementa linearmente apurando a diferença
    }
    return dias;
}
```

*   **Regra de Destaque Visual (Cores de Alerta):**
    *   Títulos com **`diasAtrasado > 0`** são pintados em **Vermelho** no grid, indicando perigo imediato e inadimplência ativa.
    *   Títulos com vencimento futuro permanecem na cor padrão (preto/cinza).
*   **Cálculo de Juros de Mora Local:**
    *   Se `diasAtrasado > 0`, o sistema multiplica os dias em atraso pelo percentual diário de juros do representante (`ven00_txajur` na tabela `cadrep00`) sobre o saldo devedor (`dup00_valdev`):
        $$\text{Juros} = \text{dup00\_valdev} \times \left( \frac{\text{ven00\_txajur}}{100} \right) \times \text{diasAtrasado}$$

---

### Fluxo 3: Barreira de Checkout na Digitação (`ffrmrelrecdup02`)
Durante o processo de seleção de clientes para um novo pedido (`ffrmdigvenmov00`), o sistema FV executa um fluxo defensivo de análise de crédito em tempo real.

1.  **Gatilho do Bloqueio:**
    *   Ao selecionar o cliente no grid e clicar em "Avançar" (`doCLISelect()`), o sistema aciona o método **`doTITdataload(codcli)`**.
    *   Ele analisa os saldos: se **`cli00_titven > 0`** (possui títulos vencidos) ou **`cli00_creatu < 0`** (limite estourado), o sistema aborta a digitação e **abre compulsoriamente a tela `ffrmrelrecdup02`**.
2.  **Ação do Vendedor na Barreira (`ffrmrelrecdup02`):**
    *   O vendedor visualiza as duplicatas vencidas em atraso que estão bloqueando a compra daquele cliente.
    *   Ele deve auditar os títulos com o cliente e clicar no botão de confirmação/seleção (**`btnlinselect`** disparando `on_btnlinselect_clicked()`).
    *   **O Handshake do Checkout:** Ao clicar em confirmar, a tela emite o sinal `doNextSignal()` e fecha. Isso serve como um "termo de responsabilidade visual" offline do vendedor, que está ciente de que está vendendo para um cliente inadimplente. O pedido herda a marcação financeira de liberação e transita para as telas de seleção de linha (`fspLIN`) e prazo (`fspPLA`).

---

## 5. Diretrizes para Implementação em Flutter (Modernização)

Para migrar essa arquitetura obsoleta baseada em frames ocultos e grids pesados para uma UI/UX fluida e reativa no Flutter, siga as seguintes diretrizes:

### A. Estrutura de Consultas no Drift (SQLite)

Implemente uma única query consolidada para o extrato detalhado do cliente, otimizando o cálculo de títulos vencidos e a vencer diretamente no banco de dados local:

```dart
// Exemplo de Query utilizando o Drift no Flutter
Stream<ClienteFichaFinanceira> watchFichaFinanceira(int clienteCodigo) {
  final currentDateStr = DateTime.now().toIsofString().substring(0, 10);
  
  return (select(dup00)
    ..where((t) => t.dup00_codcli.equals(clienteCodigo)))
    .watch()
    .map((titulos) {
      double totalVencido = 0.0;
      double totalAVencer = 0.0;
      double saldoDevedor = 0.0;
      
      final listdet = titulos.map((t) {
        final isVencido = t.dup00_datven.isBefore(DateTime.now());
        final diasAtraso = isVencido 
            ? DateTime.now().difference(t.dup00_datven).inDays 
            : 0;
            
        final valorDevedor = t.dup00_valdev ?? 0.0;
        saldoDevedor += valorDevedor;
        
        if (isVencido) {
          totalVencido += valorDevedor;
        } else {
          totalAVencer += valorDevedor;
        }
        
        return TituloFicha(
          titulo: t.dup00_codigo,
          emissao: t.dup00_datemi,
          vencimento: t.dup00_datven,
          diasAtraso: diasAtraso,
          valorDevedor: valorDevedor,
          valorOriginal: t.dup00_valori ?? 0.0,
          valorPago: t.dup00_valpag ?? 0.0,
          isVencido: isVencido,
        );
      }).toList();
      
      return ClienteFichaFinanceira(
        titulos: listdet,
        saldoDevedorTotal: saldoDevedor,
        totalVencido: totalVencido,
        totalAVencer: totalAVencer,
      );
    });
}
```

### B. Proposta de UI/UX Moderna no Flutter (Checkout reativo)

1.  **Menu "Receber" Geral:**
    *   Substitua o fluxo de duas telas com clique por uma tela de **Lista de Clientes com Filtros Dinâmicos (Chips)** na parte superior: `[Todos]`, `[Apenas Vencidos]` e `[A Vencer]`.
    *   Ao arrastar para o lado (gesto *Swipe*) ou clicar em um cliente, abra uma **Ficha Deslizante inferior (Sliding Bottom Sheet)** exibindo o extrato reativo de títulos daquele cliente sem tirar o vendedor do foco de sua rota diária.
2.  **O Bloqueio do Checkout com Alerta Inteligente:**
    *   Durante a seleção de clientes para iniciar um pedido, em vez de interromper o fluxo bruscamente abrindo outra tela inteira, exiba um **Modal de Alerta Financeiro (BottomSheet de Erro/Aviso)** contendo:
        *   Um indicador visual chamativo do status de débito do cliente (*"Este cliente possui R$ 206,36 em atraso!"*).
        *   A lista resumida dos títulos vencidos.
        *   Um botão proeminente de ação: **"Auditar Títulos e Liberar Venda"** (que executa o handshake e destrava o fluxo para o carrinho) e o botão **"Cancelar Venda"** para retornar à carteira de forma segura.
