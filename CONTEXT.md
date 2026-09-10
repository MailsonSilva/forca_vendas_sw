# Domain Context & Glossary

## Módulo: Relatórios Comerciais e Produtividade

### 1. Conta-Corrente do Vendedor (CCV / Saldo Flex)
- **Saldo Base (`ccv01_vlrsal`)**: Saldo oficial de margem homologado pela retaguarda (ERP) e transmitido via retorno `.ret`.
- **Saldo em Digitação (`ccv01_vlrusedig`)**: Provisão monetária consumida por pedidos salvos localmente em digitação/rascunho.
- **Saldo em Trânsito (`ccv01_vlrusepck`)**: Provisão consumida por pedidos já empacotados em lote `.pac` aguardando retorno.
- **Saldo Disponível (`ccv01_vlrsalatu`)**: Saldo líquido real (`Saldo Base + Provisão Digitação + Provisão Envio`), utilizado para travas de desconto no checkout.
- **Trava de CCV (`ven00_chkccv`)**: Parâmetro do vendedor que bloqueia pedidos cujo desconto concedido (`ccvtot`) ultrapasse o saldo disponível.

### 2. Faturamento e Acompanhamento de Metas (`ffrmrelfatcvd00`)
- **Cota de Vendas (`fat00_vlrcalven`)**: Meta financeira mensal atribuída ao vendedor pelo ERP.
- **Faturamento ERP (`fat00_vlrfatven`)**: Valor de pedidos já faturados e processados pela retaguarda no mês.
- **Sintetização Local (`ett_sintetize_ESTFATCVD00`)**: Consolidação matemática de `Faturamento ERP + Pedidos em Trânsito + Rascunhos Locais`.
- **Limite de Pessoa Física (`fat00_vlrtotlib`)**: Teto mensal máximo autorizado para vendas destinadas a clientes Pessoa Física (`cli00_typpes = 1`).
- **Validação PF (`getPEDTOTPessoaFisicaCheck`)**: Validação que bloqueia novas vendas PF quando o total projetado excede `fat00_vlrtotlib`.

### 3. Resumo de Vendas Diário e Comissões (`ffrmrelresven00`)
- **Venda Bruta (`c2_venval`)**: Somatório do valor digitado (`dig00_digtot`) de todos os pedidos ativos emitidos no período selecionado.
- **Devolução e Cortes (`c2_devval`)**: Total de cortes por falta de estoque (`dig00_digtot - dig00_fattot`) e devoluções homologadas pela retaguarda.
- **Venda Líquida (`c2_totval`)**: Valor líquido real (`Venda Bruta - Devoluções/Cortes` ou `dig00_fattot`).
- **Comissão Acumulada (`c2_comval`)**: Somatório da comissão apurada item por item com base na alíquota do produto (`cadpro00.pro00_commax`).
- **Item Bonificado (`dig01_bontyp > 0`)**: Linha de produto doada como bonificação/brinde, com percentual de comissão compulsoriamente zerado (0%).
- **Comissão Prevista vs. Homologada**: Pedidos pendentes de retorno (`sttenv < 3`) utilizam quantidade e preço digitados para projetar a comissão em tempo real; pedidos faturados (`sttenv = 3`) utilizam `fatqtd` e `fatpco`.

### 4. Carteira de Clientes e Roteirização (`ffrmrelclirot00`)
- **Dia de Visita / Rota (`cli00_flgven`)**: Dia da semana programado para atendimento comercial do cliente (1=Segunda, 2=Terça, 3=Quarta, 4=Quinta, 5=Sexta, 6=Sábado, 7=Domingo, 0=Sem Rota, -1=Todos).
- **Alerta de Inadimplência / Vermelho**: Cliente com títulos vencidos em aberto (`cli00_titven > 0.00`), exigindo atenção na cobrança ou liberação de crédito.
- **Alerta de Vencimento Próximo / Amarelo**: Cliente com títulos a vencer (`cli00_titave > 0.00`) e sem títulos vencidos.
- **Crédito Regular / Verde**: Cliente com histórico financeiro em dia (`titven == 0` e `titave == 0`).
- **Margem de Limite Disponível (`cli00_creatu`)**: Saldo financeiro disponível para novos faturamentos a prazo.
- **Georreferenciamento (`cli16_codlat`, `cli16_codlon`)**: Coordenadas geográficas para traçar rota e auditoria de visitas presenciais.

## Módulo: Contas a Receber e Gestão de Duplicatas (Receber)

### 1. Duplicata / Título (`dup00`)
- **Registro Financeiro**: Título individual emitido pelo ERP (`dup00_codigo`), vinculado ao cliente (`dup00_codcli`), com valor original (`dup00_valori`), saldo devedor (`dup00_valdev`), valor pago (`dup00_valpag`), data de emissão (`dup00_datemi`) e vencimento (`dup00_datven`).
- **Escopo Negativo Estrito**: O aplicativo móvel opera em modo 100% consulta/auditoria. O vendedor **não** realiza baixa, **não** gera segundas vias ou Pix locais e **não** altera prazos ou juros.

### 2. Apuração de Atraso e Juros de Mora
- **Dias de Atraso (`diasAtrasado`)**: Diferença em dias corridos calculada offline entre `dup00_datven` e a data corrente do dispositivo (`hoje - datven`), quando `datven < hoje`.
- **Taxa de Juros do Representante (`ven00_txajur`)**: Parâmetro percentual diário cadastrado em `cadrep00`. Se nulo ou zero, juros apurados são R$ 0,00 (sem inventar alíquotas não parametrizadas pelo ERP).
- **Cálculo de Juros**: $\text{Juros} = \text{dup00\_valdev} \times (\text{ven00\_txajur} / 100) \times \text{diasAtrasado}$.

### 3. Classificação e Saldos do Cliente
- **Total Vencido (`cli00_titven`)**: Soma consolidada de `dup00_valdev + Juros` dos títulos com vencimento anterior à data atual.
- **Total A Vencer (`cli00_titave`)**: Soma de `dup00_valdev` de títulos com vencimento igual ou posterior à data atual.
- **Filtros Operacionais**: *Todos com Débito* (`valdev > 0`), *Apenas Vencidos* (`valdev > 0 AND datven < hoje`), *A Vencer* (`valdev > 0 AND datven >= hoje`).

### 4. Extrato Analítico e Cobrança Amigável
- **Extrato em Sliding BottomSheet**: Apresentação analítica reativa deslizante por cliente, mantendo a posição de scroll da lista macro.
- **Destaque Visual de Inadimplência**: Títulos vencidos evidenciados em vermelho com badge de dias de atraso.
- **Compartilhamento Textual**: Exportação formatada das pendências para canal de mensagens (WhatsApp / Clipboard) para cobrança amigável direta.
- **Ordenação por Aging (Tempo de Atraso)**: Ordenação prioritária da carteira pelo título com vencimento mais antigo, antecipando o risco de crédito e bloqueio comercial.
- **Barreira de Checkout / Termo de Responsabilidade**: Validação integrada que exige auditoria e termo de consentimento ao abrir pedido para cliente com títulos em atraso (`totalVencido > 0`).

