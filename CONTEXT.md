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

## Padrões Transversais de Interface e Apresentação

### 1. Padrão Arquitetural de Modais (Bottom Sheets) e Correção de SafeArea
- **Uso Exclusivo de `showAppModalBottomSheet` e `AppBottomSheet`**:
  - Todo e qualquer novo modal ou painel deslizante do aplicativo **DEVE** ser aberto utilizando `showAppModalBottomSheet<T>()` e estruturado internamente com o widget `AppBottomSheet` (`lib/core/app_bottom_sheet.dart`).
  - **Proibido**: Usar `showModalBottomSheet` cru do Flutter sem envelopamento em `SafeArea`.
- **Garantia de Não-Sobreposição com Barra Virtual de Navegação (SafeArea)**:
  - Todo modal é configurado com `useSafeArea: true` e encapsulado em `SafeArea(bottom: true)` com padding dinâmico via `MediaQuery.of(context).padding.bottom`.
  - **Regra Rígida**: Nenhum botão, ação, campo de texto ou rodapé de modal pode ficar oculto atrás dos botões virtuais ou gestos nativos do Android/iOS.
- **Identidade Visual Padronizada**:
  - Barra de arraste centralizada no topo (`drag handle` 40x4px arredondado).
  - Cabeçalho padronizado com ícone do contexto, título em negrito e botão de fechar `X` estilizado com `AppIconButton`.
  - Cantos superiores com raio de 24px e contenção de largura máxima responsiva (`maxWidth: 600.0`) para renderização ideal em tablets e telas largas.

### 2. Convenção Global de Formatação Monetária Brasileira (R$)
- **Formatação Centralizada (`lib/core/formatters/currency_formatter.dart`)**:
  - Todo e qualquer valor monetário apresentado para o usuário na interface (listagens de produtos, resumos de pedidos, rascunhos, extrato de clientes, limites e faturamentos) deve utilizar a biblioteca central `formatMoeda()` ou a extensão `.toMoeda()`.
  - Utiliza `NumberFormat.currency(locale: 'pt_BR', symbol: 'R$')` com normalização de espaços, garantindo apresentação rigorosa: **`R$ 1.250,50`** (ponto para milhar e vírgula para centavos).
  - **Proibido**: Exibir valores numéricos crus ou concatenados manualmente com ponto (ex: `10.5` ou `1250.50`).
  - **Exceção**: Formatos de baixo nível para geração de pacotes e arquivos de integração com o ERP (ex: `fmtCurrencyPac`), que exigem ponto decimal sem símbolo monetário.

### 3. Visualizador de Imagens de Produtos com Zoom e Compartilhamento
- **Ativação Transparente via `ImagemLocalWidget` (`lib/widget/imagem_local_widget.dart`)**:
  - O componente base de imagem de produtos possui `enablePreview: true` por padrão. O toque em qualquer imagem (em listas, detalhes ou itens do pedido) aciona automaticamente o `ImagemPreviewDialog`.
- **Recursos do Diálogo Interativo (`lib/widgets/imagem_preview_dialog.dart`)**:
  - **Zoom e Pan Fluido**: Utiliza `InteractiveViewer` permitindo escala de 0.8x a 5.0x com suporte a duplo toque para restauração rápida de zoom.
  - **Compartilhamento Direto**: Botão de ação que utiliza `share_plus` (`Share.shareXFiles`) para enviar o arquivo da imagem diretamente para WhatsApp, Telegram ou outros apps do cliente.
  - **Área de Transferência**: Botão de cópia rápida dos dados/caminho da imagem via `Clipboard.setData` com feedback visual imediato.

## Módulo: Geração e Impressão de PDF do Pedido (Espelho de Venda)

### 1. Arquitetura e Templates (`lib/modules/pdf/`)
- **Contrato de Template (`IPdfOrderTemplate`)**: Interface extensível para geração de espelhos de venda. Permite implementar layouts customizados sem alterar a lógica de negócio ou de persistência.
- **Template Padrão (`StandardPdfOrderTemplate`)**: Renderização estruturada em folha A4 contendo:
  - Cabeçalho com identificação da empresa, logomarca dinâmica ou fallback institucional, dados do pedido e vendedor.
  - Foto do cliente (`clienteFotoBytes`), dados cadastrais (Razão Social, Nome Fantasia, CNPJ/CPF, Inscrição Estadual, Endereço completo).
  - Grade analítica de itens com Código, EAN, Descrição, Marca, Quantidades, Preço Unitário, Desconto(%) e Total.
  - Agrupamento de itens bonificados (`isBonificacao = true`).
  - Quadro de previsão financeira com duplicatas/parcelas (vencimentos e valores).
  - Resumo de fechamento com total bruto, descontos, bonificações, substituição tributária (ST) e valor total líquido.
- **Filtros de Itens (`FiltroItensPdf`)**:
  - `todos`: Lista completa de itens do pedido.
  - `apenasCortes`: Itens com corte total ou parcial no faturamento do ERP (`fatqtd < digqtd`).
  - `semCortes`: Itens faturados integralmente (`fatqtd == digqtd`).
  - `apenasBonificados`: Itens registrados com bonificação (`isBonificacao == true`).
- **Segurança e Compartilhamento Nativo (`PdfGeneratorService`)**:
  - Eliminação de dependência de caminhos estáticos em disco. Os bytes do PDF são gerados em memória (`Uint8List`) e salvos sob demanda no diretório de cache (`getTemporaryDirectory()`), compartilhados com segurança via `share_plus` (`XFile`) ou impressos diretamente via `Printing.layoutPdf`.

## Módulo: Identidade Visual e Logomarca Dinâmica (CADACE00)

### 1. Gerenciamento e Cache (`EmpresaLogoService`)
- **Origem do Binário (`cadace00.srv00_imglog`)**: Logotipo da distribuidora importado via sincronização/carga do ERP no SQLite local.
- **Cache Otimizado em Disco**: O binário extraído é mantido em cache local (`empresa_logo.png`) no diretório de documentos do app (`getApplicationDocumentsDirectory()`), evitando overhead de consultas SQL a cada inicialização de tela.
- **Fallback Automático**: Caso o registro em `cadace00` esteja nulo ou a imagem não seja fornecida, o sistema utiliza o asset padrão institucional (`assets/images/logo.png`).
- **Preferência de Impressão no PDF**:
  - Chave `config_exibir_logo_pdf` em `SharedPreferences` (padrão: `true`). Permite ao representante desativar a impressão do logotipo nos espelhos de pedido quando necessário via menu de Configurações.

## Módulo: Pesquisa de Produtos e Identificação Comercial

### 1. Atributos Comerciais de Produto
- **Código de Barras / EAN (`pro00_codbar`)**: Código universal do item, permitindo localização rápida por leitor de código de barras ou digitação.
- **Marca do Produto (`cadmar00.mar00_descri` / `pro00_codmar`)**: Nome da marca vinculada ao item via relacionamento com a tabela de marcas.
- **Referências de Fabricante (`pro00_ref001`, `pro00_ref002`)**: Códigos de fábrica do fabricante/fornecedor (`cadfor00`), essenciais para vendas de peças, insumos e produtos com códigos industriais.
- **Exibição Padronizada (`ItemPedidoCardWidget`)**: Apresentação ostensiva em badges e tipografia secundária na lista de produtos (`BuscaProdutoPageWidget`) e na grade de itens do carrinho (`PedidoItensListaWidget`).



