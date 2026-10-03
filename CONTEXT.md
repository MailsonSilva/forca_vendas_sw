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

### 1. Duplicata / Título (`finrecdup00` / `dup00`)
- **Registro Financeiro**: Título individual emitido pelo ERP (`dup00_codigo`), vinculado ao cliente (`dup00_codcli`), com valor original (`dup00_valori`), saldo devedor (`dup00_valdev`), valor pago (`dup00_valpag`), data de emissão (`dup00_datemi`) e vencimento (`dup00_datven`).
- **Taxa de Juros Diária Nativa (`dup00_pctjurday`)**: Na tabela física local `finrecdup00`, a taxa de juros diária por título reside na coluna física `dup00_pctjurday` (e não em uma coluna estática de montante como `dup00_valjur`).
- **Escopo Negativo Estrito**: O aplicativo móvel opera em modo 100% consulta/auditoria. O vendedor **não** realiza baixa, **não** gera segundas vias ou Pix locais e **não** altera prazos ou juros.

### 2. Apuração de Atraso e Juros de Mora (Fórmula Canônica)
- **Hierarquia de Resolução da Taxa Diária**:
  $$\text{taxaDiaria} = \text{COALESCE}(\text{dup00\_pctjurday}, \text{cadrep00.ven00\_txajur}, 0.0)$$
- **Dias de Atraso (`diasAtraso`)**:
  $$\text{diasAtraso} = \max(0, \text{Hoje} - \text{Vencimento})$$
  Tratamento robusto de datas no Dart aceitando tanto `DD/MM/AAAA` quanto `AAAA-MM-DD`, normalizando horas para apuração por datas cheias.
- **Cálculo de Juros em Memória**:
  $$\text{valorJuros} = \text{dup00\_valdev} \times (\text{taxaDiaria} / 100.0) \times \text{diasAtraso}$$
- **Totalizadores do Extrato**:
  - `vlrTotJuros`: Soma consolidada de juros apurados de todos os títulos vencidos.
  - `Dias de atraso`: Exibe o acumulado total de dias em atraso (soma de dias de todas as duplicatas vencidas).

### 3. Classificação e Abas do Extrato do Cliente
- **Aba Padrão de Abertura**: Índice 1 ("Vencidos"), abrindo diretamente as pendências críticas do cliente.
- **Aba "Todos"**: Exibe a totalidade de títulos (vencidos e a vencer) com botão de rodapé "Copiar Texto" (sem rodapé/quadro de totais).
- **Classificação de Débitos**: *Todos com Débito* (`valdev > 0`), *Apenas Vencidos* (`valdev > 0 AND datven < hoje`), *A Vencer* (`valdev > 0 AND datven >= hoje`).

### 4. Extrato Analítico e Cobrança Amigável
- **Extrato em Sliding BottomSheet**: Apresentação analítica reativa deslizante por cliente, mantendo a posição de scroll da lista macro.
- **Destaque Visual de Inadimplência**: Títulos vencidos evidenciados em vermelho com badge de dias de atraso.
- **Compartilhamento Textual**: Exportação formatada das pendências para cópia direta (Clipboard) para cobrança amigável.
- **Ordenação por Aging (Tempo de Atraso)**: Ordenação prioritária da carteira pelo título com vencimento mais antigo, antecipando o risco de crédito e bloqueio comercial.
- **Barreira de Checkout / Termo de Responsabilidade**: Validação integrada que exige auditoria e termo de consentimento ao abrir pedido para cliente com títulos em atraso (`totalVencido > 0`).

## Módulo: Sincronização, Carga e Comunicação FTP

### 1. Nomenclatura e Arquivamento Remoto no FTP
- **Renomeação de Arquivo de Carga**: Padrão mandatório de renomeação no servidor FTP após processamento:
  `ven[codVendedor].[YYYY-MM-DD] [HH-mm-ss]` (estritamente sem extensão).
- **Tratamento Defensivo de Ausência de Carga**: Tratamento resiliente quando não houver nova carga disponível no servidor FTP, evitando exceções não tratadas (tela vermelha) e apresentando feedback amigável ao usuário.
- **Dinamismo da Razão da Distribuidora**: Nome da empresa no card de Ferramentas e cabeçalhos extraído dinamicamente da sessão/login (`cadace00`/`cadrep00`), substituindo hardcodes (ex: `'sw'`).
- **Sincronização Compulsória de Imagens**: Disparo automático da sincronização incremental/parcial de fotos de produtos logo após a conclusão bem-sucedida da carga de dados.

## Módulo: Pedidos, Filial Ativa e Navegação Segura

### 1. Propagação de Filial Ativa
- **Vinculação de Filial no Pedido**: Propagação compulsória da filial selecionada na sessão (`AppState.codFilialAtiva` / `cadrep00.ven00_codfil`) para o cabeçalho do pedido `pckvendig000.dig00_digfil` (ou `ped00_codfil`).

### 2. Navegação e Interceptação com PopScope
- **Prevenção de Fechamento Acidental do App**: Uso de `PopScope(canPop: false)` no menu de Configurações e rotas raiz para interceptar o botão voltar do sistema operacional e retornar à tela inicial (`/homePage`), impedindo encerramento involuntário da aplicação.

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

## Módulo: Otimização de Alta Performance das Pesquisas Locais (SPEC-053 & SPEC-054)

### 1. Diretrizes de Ciclo de Vida da Conexão SQLite
- **Proibição Estrita de `db.close()`**: É terminantemente proibido invocar `db.close()` em custom actions, repositórios, DAOs ou blocos `finally` de consultas locais (`dbforcacad001.db` ou `dbforcadig001.db`).
- **Pool de Conexão Singleton / Instância Ativa**: O SQLite em ambiente Flutter móvel compartilha descritores de arquivo. Fechar a conexão em rotinas intermediárias quebra o pool de conexões, invalidando acessos paralelos e causando o bloqueio perpétuo do aplicativo (spinner infinito).

### 2. Mapeamento de Esquema em Cache em Memória (`ProductDbMetadata`)
- **Descoberta Única de Esquema**: O mapeamento da existência de tabelas (`cadpro00`/`pro00`, `estpro00`, `estpcopro00`/`pcopro00`, `cadmar00`, `cadfor00`) e de suas respectivas colunas deve ser executado uma única vez por sessão e mantido em memória estática.
- **Eliminação de Overhead de I/O**: Fica vedada a execução de consultas a `sqlite_master` ou `PRAGMA table_info` a cada caractere digitado pelo usuário na caixa de pesquisa.
- **Introspecção Resiliente de Colunas**: Seleciona colunas existentes (`pro00_ref001`, `pro00_ref002`, `pro00_reffor`, `pro00_codimg`) e projeta literais padrão (`''` ou `0`) caso a coluna não exista no banco legado ativo, prevenindo exceções de SQL.

### 3. Extração Canônica de Preço, Marca e Estoque
- **Preço de Venda**: Extraído preferencialmente da tabela de preços `estpcopro00` (ou `pcopro00`) através das colunas `pro00_preco` ou `pro00_pcosub`, respeitando o código da tabela do cliente/pedido (`pro00_codtab`). Fallback para `pro00_preco`/`pro00_pcomax` de `cadpro00` quando ausente na tabela.
- **Marca**: Extraída via `LEFT JOIN` indexado na tabela `cadmar00` (ou `mar00`) através do campo `pro00_codmar`, retornando `mar00_descri` com fallback para `'SEM MARCA'`.
- **Estoque Particionado**: Extraído via `LEFT JOIN` indexado na tabela `estpro00` filtrando pela filial ativa (`pro00_codfil`), com fallback para `cadpro00.pro00_qtdest`.

## Módulo: Clientes — Visualização Segura e Novos Cadastros

### 1. Bloqueio Rígido de Edição de Clientes da Carga
- **Imutabilidade de Cadastros Homologados**: Clientes originários da carga (`cadcli00` com `cli00_codigo > 0` e `isNovoCliente == false`) são exclusivamente para visualização.
- **Experiência Visual e Sem Edição**: Todos os campos no formulário operam com `readOnly: true` (e `enabled: true`), permitindo alta nitidez e contraste de texto, seleção e rolagem, sem acionar o teclado ou cursor de edição.
- **Ocultação de Ações de Escrita**: O botão "SALVAR CADASTRO", seletores de tipo de pessoa (Física/Jurídica) e dropdowns de UF são travados/ocultados.

### 2. Cadastro de Novo Cliente e Subida FTP (`fcfPUTCAD = 10`)
- **Novo Cliente Local**: Formulário editável acionado pelo botão de novo cadastro (`isNovoCliente == true`).
- **Geração de XML e Fila de Envio**: Ao salvar, o app gera o arquivo `c<codRep>-<retornaMil(codCliente)>.xml`, grava em `cadcli00` com `cli00_sttenv = 0` e enfileira na Central de Transmissão para upload FTP na rotina de sincronização.

## Módulo: Preço do Produto, Faixas Comerciais e Paridade de Telas (SPEC-058)

### 1. Variável Canônica e Hierarquia de Preço de Venda
- **Preço Regionalizado Direto via Sequencial (`estpcoregpco00`)**: A variável oficial prioritária que determina o preço base de venda e limites é a relação `estpcoreg00` (`pro00_codkey = 1`) com `estpcoregpco00` (`pro00_codseq = reg.pro00_codpco`), provendo `pro00_pcomax` (preço praticado) e `pro00_pcomin` (piso de desconto).
- **Preço por Classe Direta (`estpcopro00.pro00_pcosub`)**: Fallback canônico quando a matriz regionalizada de sequenciais não estiver presente.
- **Proibição de `cadpro00.pro00_preco`**: O campo `cadpro00.pro00_preco` não reflete o preço comercial praticado para o cliente e não deve ser utilizado como preço de venda na falta de tabela.
- **Filial Dinâmica Selecionada**: O saldo em estoque e faturamento utilizam estritamente o código da filial ativa selecionada na sessão: `(codFilial != null && codFilial > 0) ? codFilial : (AppState().codFilialAtiva > 0 ? AppState().codFilialAtiva : 1)`. Proibido uso de filial hardcoded.
- **Fator do Plano de Pagamento (`cadpla00.pla00_fator`)**: Multiplicador aplicado sobre o preço base: $\text{precoFinal} = \text{precoBase} \times \text{pla00\_fator}$, com arredondamento monetário de duas casas decimais.

### 2. Faixas de Negociação (`pcomax` e `pcomin`)
- **Resolução via `ValidePcoService.obterFaixasPreco`**: Determina o teto (`pcomax`) e o piso (`pcomin`) aceitos para o produto, priorizando a matriz regional `estpcoreg00` + `estpcoregpco00` com desambiguação por região/tabela e ordenação decrescente por maior preço praticado (`pcomax DESC`).
- **Aplicação do Fator de Plano**: O fator financeiro do plano de pagamento (`cadpla00.pla00_fator`) incide sobre o teto e o piso comercial, garantindo coerência monetária nos modais e na digitação.
- **Validação Imediata na Digitação**: O vendedor não pode digitar ou confirmar um preço fora da faixa $[\text{pcomin}, \text{pcomax}]$ (exceto em bonificações autorizadas).

### 3. Paridade Unificada entre Telas
- **Catálogo / Busca de Produtos (`BuscaProdutoPageWidget`)**: Query de alta performance (< 100ms) isolando a busca em subquery de `cadpro00`, agregando `MAX(pco.pro00_pcomax)` e `MAX(pco.pro00_pcomin)` via `GROUP BY`, com metadados em cache estático (`ProdutoMetadataCache`). Preserva o preço de venda e margens oficiais no modal de inclusão ao pedido.
- **Detalhes do Produto (`DetalheProdutoPageWidget`)**: Apura via `obterDetalhesProduto` e `carregarProdutoDetalhe` integrados a `estpcoregpco00` via subquery agrupada `MAX`, refletindo exatamente o preço praticado (`56.65`) e piso comercial (`48.00`).
- **Digitação e Itens do Pedido (`PedidoItensListaWidget`)**: Lê as colunas canônicas `ped10_digpco` / `dig01_digpco`, sincroniza automaticamente itens com as faixas comerciais oficiais e exibe no diálogo de edição rápida de preço o Preço Mínimo e Preço Máximo oficiais do produto.
- **Bloqueio de Itens com Preço Zerado**: Impede a inserção de produtos com preço zero no carrinho para vendas normais, preservando a permissão para bonificações (`bontyp = 1`).

### 4. Resolução Tripla de Estoque (Atual, Pendente e Disponível)
- **Definição dos Três Saldos Oficiais**:
  - **Estoque Físico Atual (`pro00_qtdest`)**: Quantidade física real existente na filial em `estpro00`.
  - **Estoque Pendente (`pro00_qtdped`)**: Quantidade retida ou comprometida em pedidos/reservas em `estpro00`.
  - **Saldo Disponível (`saldo_estoque`)**: Saldo líquido para comercialização imediata: $\text{saldo} = \max(0, \text{Atual} - \text{Pendente})$.
- **Resiliência de Pareamento e Coerção de Tipagem (SQLite)**: Em bases reais migradas do ERP, `pro00_codpro` (na tabela `estpro00`) e `pro00_codigo` (em `cadpro00`) podem divergir de tipo (`TEXT` com zeros à esquerda vs `INTEGER`). O pareamento realiza coerção explícita:
  `ON (est.pro00_codpro = sel.pro00_codigo OR CAST(est.pro00_codpro AS TEXT) = CAST(sel.pro00_codigo AS TEXT) OR CAST(est.pro00_codpro AS INTEGER) = CAST(sel.pro00_codigo AS INTEGER))`.
- **Hierarquia de Resolução por Filial e Fallback**:
  1. Busca saldo específico para a filial ativa selecionada (`estpro00.pro00_codfil = :filialAtiva`).
  2. Recuo para filial global ou principal (`pro00_codfil = 0` ou `pro00_codfil = 1`).
  3. Fallback canônico final para `cadpro00.pro00_qtdest` caso não exista particionamento cadastrado em `estpro00`.
- **Propagação Unificada via DTO (`ProdutoDetalheDto`)**:
  O repositório e as actions de carregamento de produto (`CarregarProdutoDetalhe`, `BuscaProduto`) mapeiam e transmitem integralmente `estoqueAtual`, `estoquePendente` e `saldoEstoque` para a estrutura de dados `ProdutoResultStruct`, garantindo que tanto a lista do catálogo quanto o modal de detalhes exibam os três saldos de forma idêntica e sem falsos zeros.

### 5. Gestão de Ciclo de Vida do Banco de Vendas (`LocalSalesDatabaseService`)
- **Singleton com Reutilização de Conexão Ativa (`_activeDb`)**: Evita criação concorrente de instâncias do SQLite e descritores órfãos de arquivo, reusando a mesma referência aberta durante toda a sessão.
- **Execução Única de Migrações e Índices**: As rotinas de criação condicional de índices (`idx_cadpro00_codpro`, `idx_estpro00_fil_pro`, `idx_cadcli00_pesquisa`, etc.) rodam apenas uma vez por inicialização da aplicação, eliminando custos repetidos de I/O em consultas de catálogo e clientes.
- **Busca Multi-Token e Sanitização de Documentos (`pesquisa_cliente.dart`)**:
  Suporta pesquisas simultâneas por múltiplos tokens (ex: "Silva João" ou números de documento), sanitizando pontuações de CPF/CNPJ e eliminando inconsistências de cache estático que geravam erros de coluna não encontrada (`no such column`).
