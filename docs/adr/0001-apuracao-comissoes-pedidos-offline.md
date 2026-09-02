# ADR 0001: Apuração Híbrida de Comissões e Vendas em Campo (Offline-First)

## Contexto
No sistema legado de Força de Vendas (C++/Qt), a apuração de comissões e venda líquida considerava prioritariamente os campos faturados pela retaguarda (`dig01_fatqtd` e `dig00_fattot`), que são recebidos via arquivo de retorno FTP (`.ret` com `sttenv = 3`).

Em campo, no entanto, o representante comercial emite dezenas de pedidos ao longo do dia que permanecem em estado de rascunho local (`sttenv = 0`) ou aguardando envio/processamento no ERP (`sttenv = 1, 2`). Se o relatório de comissões considerasse apenas os pedidos faturados, o vendedor veria suas comissões zeradas ou defasadas durante a sua jornada de trabalho até a sincronização noturna.

## Decisão
Adotar uma **estratégia híbrida de cálculo de comissões e faturamento em tempo real**:
1. **Pedidos Faturados (`sttenv = 3`):** Utilizam a base homologada pelo ERP (`dig01_fatqtd * dig01_fatpco * (pro00_commax / 100)`), refletindo cortes e devoluções reais.
2. **Pedidos Locais / Em Trânsito (`sttenv < 3`):** Utilizam a base digitada (`dig01_digqtd * dig01_digpco * (pro00_commax / 100)`) como **"Comissão Projetada/Prevista"**, atualizando-se automaticamente para o valor homologado assim que o retorno `.ret` for processado.
3. **Itens Bonificados (`bontyp > 0`):** Comissão estritamente zerada (0%) em qualquer estágio.

## Consequências
- **Positivas:** O vendedor obtém visibilidade instantânea de sua remuneração e produtividade diária sem depender de conectividade imediata com a retaguarda.
- **Transparência:** A interface diferencia claramente os pedidos homologados pelo ERP dos pedidos que ainda estão pendentes de faturamento.
