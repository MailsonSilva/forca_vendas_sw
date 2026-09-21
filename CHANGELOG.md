# Changelog

Todas as alterações notáveis deste projeto serão documentadas neste arquivo.

O formato é baseado em [Keep a Changelog](https://keepachangelog.com/pt-BR/1.0.0/),
e este projeto adere ao [Versionamento Semântico](https://semver.org/lang/pt-BR/).

---

## [5.4.1] - 2026-09-21

### 🌟 Adicionado & Aprimorado (Novas Funcionalidades e Correções de Negócio)

#### 1. Extrato e Compartilhamento de Pedidos
- **Remoção de WhatsApp Direto**: O botão de envio direto pelo WhatsApp foi removido do extrato.
- **Resumo em PDF Consolidado**: Geração e consolidação do resumo de pedidos em PDF para compartilhamento utilizando mecanismos nativos de compartilhamento do dispositivo (`share_plus`).

#### 2. Otimização de Performance (Catálogo)
- **Keyset Pagination**: Substituição da paginação tradicional baseada em `OFFSET` por cursor (*keyset pagination*), eliminando gargalos de performance e travamentos da interface no scroll infinito.
- **Índices Cobridores**: Criação de índices no banco local (SQLite) otimizados para junção e ordenação de buscas do catálogo.
- **PRAGMAs de Tuning**: Aplicação de cache em memória mitigando chamadas de I/O em listagens grandes.

---

## [5.4.0] - 2026-09-16

### 🌟 Adicionado & Aprimorado (Novas Funcionalidades e Correções de Negócio)

#### 1. Fluxo de Digitação de Pedidos e Seleção de Cliente (SPEC-042 & SPEC-044)
- **Card de Identificação Completa do Cliente (`PedidoNovoInicioWidget`)**:
  - Exibição de Razão Social, Nome Fantasia, Código do Cliente, CPF/CNPJ formatado com máscara (`AppUtil`), Endereço, Bairro, Cidade/UF e Rota.
  - Indicadores em badges da Tabela de Preço padrão, Prazo Padrão, Limite de Crédito concedido e Limite Disponível calculado.
  - Badge dinâmico de status financeiro: *"Em Dia"* (verde) ou *"Inadimplência Ativa"* (vermelho).
- **Remoção de Agente Prematuro (SPEC-044)**:
  - Removida a exibição do campo `Agente: 501` (`cli00_codage`) na seleção de cliente da tela de Novo Pedido. O vínculo com o agente cobrador é atribuído exclusivamente no fechamento de totais (`ffrmdigvenmov04`).
- **Observações do Pedido (`dig00_obs`)**:
  - Implementação do modal desacoplado `ModalObservacaoPedidoWidget` acessível no cabeçalho do pedido.
  - Campo expansível de texto livre de até 500 caracteres, sincronizado com o estado global e persistido no banco de digitação `dbforcadig001.db`.

#### 2. Validação de Inadimplência e Bloqueio Financeiro (`BloqueioFinanceiroService`)
- **Regras Oficiais de Bloqueio**:
  - Bloqueio imediato quando o cliente possui títulos vencidos (`cli00_titven > 0`) ou limite de crédito estourado (`cli00_creatu <= 0`).
  - Disparo compulsório do Extrato Financeiro do Cliente em `modoBloqueio: true`.
- **Botão "Liberar Pedido" Padronizado**:
  - Posicionamento em `Scaffold.bottomNavigationBar`, ocupando 100% da largura da tela com fundo branco e sombra superior.
  - Altura ergonômica de 48px e rótulo claro **"Liberar Pedido"** com retorno de confirmação de ciência para desbloqueio da digitação.

#### 3. Extrato do Cliente, Títulos e Redesign da Aba Faturamento (SPEC-043, SPEC-044 & SPEC-045)
- **Motor de Busca Multi-Bancos e Sanitização de Dados (`ReceberDuplicatasService`)**:
  - Busca inteligente por densidade de registros (`COUNT(*) > 0`) entre os arquivos `dbforcadig001.db` e `dbforcacad001.db`, cobrindo as tabelas `finrecdup00`, `dup00` e `caddup00`.
  - Tratamento da chave de ligação do cliente com `COALESCE(dup00_codcli, dup00_clicod)`.
  - Remoção de filtros indevidos por vendedor logado ou data menor que hoje, garantindo o carregamento de todos os títulos em aberto (vencidos e vincendos).
  - Sanitização de valores monetários com formatação brasileira contendo vírgula (`"310,00"`, `"620,53"`).
  - Algoritmo em Dart para apuração de dias de atraso e juros de mora (`saldoDevedor * (taxaRep / 100) * diasAtraso`), com parsing resiliente para formatos `DD/MM/AAAA` e ISO.
- **Unificação do Extrato e Redesign Responsivo da Aba Faturamento**:
  - Descontinuação do antigo `ExtratoDuplicatasWidget` e consolidação definitiva na aba **Faturamento** do `ExtratoClientePageWidget`.
  - Cards detalhados e responsivos (`/flutter-build-responsive-layout` & `/flutter-best-practices`):
    - Cabeçalho com `TÍTULO: <numeroDocumento>` e pill de status (`VENCIDO (Xd)` / `EM DIA`).
    - Grade alinhada em 2 colunas: `EMISSÃO`, `VENCIMENTO`, `% JUROS/DIA`, `DIAS/ATRASO`, `VALOR TÍTULO`, `VALOR JUROS`.
    - Faixa destacada para `SALDO DEVEDOR:` com o valor consolidado em vermelho vivo (`Color(0xFFDC2626)`).
  - Tabela inferior fixa de totais 2x4 (Tot.Vencido, Total Juros, Dias/Atraso, Valor Devedor).
  - Ações de cobrança com compartilhamento direto via WhatsApp e cópia para a área de transferência.

#### 4. Experiência de Usuário e Usabilidade
- **Tela de Login (`LoginPageWidget`)**:
  - Configuração do campo de senha com `TextInputAction.done` / `TextInputAction.go` e callback `onSubmitted`, disparando a autenticação diretamente ao pressionar a tecla IR / Enter / Next no teclado virtual.

### 🛡️ Testes e Garantia de Qualidade
- **Suíte de Testes Automatizados**:
  - `test/spec_043_extrato_titulos_test.dart`: Cobertura de queries multi-banco, `finrecdup00`, cálculo de juros, layout da aba Faturamento e botão "Liberar Pedido" em `modoBloqueio`.
  - `test/spec_042_calculo_juros_extrato_test.dart`: Testes de cálculo de dias de atraso, juros de mora e bloqueio por inadimplência.
  - `test/spec_042_card_cliente_test.dart`: Testes de renderização dos dados cadastrais e financeiros do cliente.
  - `test/spec_042_observacao_pedido_test.dart`: Testes do modal e persistência de observação.
  - `test/receber_page_widget_test.dart`: Validação dos widgets de contas a receber e extrato.
- **Análise Estática**: `flutter analyze` finalizado com **0 erros e 0 warnings**.
- **Build Release do APK**: `flutter build apk --split-per-abi` gerado com sucesso (armeabi-v7a, arm64-v8a e x86_64).

### 📚 Documentação
- Registradas [`SPEC-044.md`](docs/specs/SPEC-044.md), [`SPEC-045.md`](docs/specs/SPEC-045.md), [`SPEC-046.md`](docs/specs/SPEC-046.md) e [`042_Melhorias_no_Fluxo_de_Digitacao_de_Pedidos_Selecao_de_Cliente_e_Extrato_Financeiro`](docs/specs/042_Melhorias_no_Fluxo_de_Digitacao_de_Pedidos_Selecao_de_Cliente_e_Extrato_Financeiro).

---

## [5.3.0] - 2026-09-12

### 🌟 Adicionado (Novas Funcionalidades e Recursos Visuais)

#### 1. Módulo de Geração, Visualização e Compartilhamento de PDF do Pedido (Espelho de Venda)
- **Arquitetura Desacoplada e Modular (`lib/modules/pdf/`)**:
  - Implementação do contrato de interface `IPdfOrderTemplate` e template padrão em folha A4 `StandardPdfOrderTemplate`.
  - Serviço de geração `PdfGeneratorService` e composição gráfica com os pacotes `pdf` e `printing`, com suporte a tipografia internacional, acentuação gráfica UTF-8 e glifo da moeda brasileira (R$).
  - Substituição definitiva do mecanismo legado em C++/Qt (`QPrinter` / `QPainter`), eliminando restrições de permissões no Android (`Scoped Storage` / `FileUriExposedException`) através de compartilhamento nativo seguro com `share_plus` em cache temporário.
- **Extração Completa de Dados do Pedido (`CarregarEspelhoPedidoService`)**:
  - Consulta relacional agregada com dados do pedido (`dig00`), itens (`dig01`), cliente (`cadcli00`), vendedor (`cadrep00`), agente cobrador, condição de pagamento e duplicatas/parcelas geradas.
  - Suporte a filtros de itens no espelho: `Todos os Itens`, `Apenas Cortes`, `Sem Cortes` e `Apenas Bonificados` (`FiltroItensPdf`).
  - Apuração de totais de venda, bonificações, descontos comerciais e substituição tributária (ST).
- **Integração na Interface (`PedidoResumoWidget`)**:
  - Ações dedicadas para visualização imediata do PDF, compartilhamento direto via WhatsApp e outros canais, e envio para impressoras compatíveis.

#### 2. Logomarca Dinâmica da Empresa e Central de Configurações
- **Gerenciador de Identidade Visual (`EmpresaLogoService`)**:
  - Persistência e recuperação do logotipo da distribuidora a partir da tabela de parâmetros `cadace00.srv00_imglog` (BLOB / Base64).
  - Cache local da imagem (`empresa_logo.png`) no diretório da aplicação (`getApplicationDocumentsDirectory()`) para carregamento instantâneo sem overhead de queries.
  - Fallback elegante para o logotipo padrão da Suportware (`assets/images/logo.png`) quando a empresa não possuir logotipo cadastrado.
  - Aplicação na tela de login/acesso e no cabeçalho do espelho de pedidos em PDF.
- **Tela de Configurações do Aplicativo (`ConfiguracaoPageWidget`)**:
  - Seção de Impressão com controle reativo: *"Exibir logotipo da empresa no PDF do pedido"* (`config_exibir_logo_pdf`), persistido em `SharedPreferences`.
  - Seção de Ajuda e Atendimento com atalho *"Falar com o Suporte Técnico"*, acionando atendimento via WhatsApp (+55 98 8128-3380) através de `url_launcher`.
- **Integridade e Proteção do Banco SQLite (`LocalSalesDatabaseProtection`)**:
  - Rotinas de proteção e sanitização na inicialização do banco para suportar campos binários e garantir compatibilidade entre versões de carga.

#### 3. Pesquisa e Exibição de Produtos com Código EAN, Marca e Referências
- **Busca Multicritério Reativa (`BuscaProdutoPageWidget`)**:
  - Otimização da busca para permitir localização instantânea de produtos por Código de Barras / EAN (`pro00_codbar`), Nome da Marca (`cadmar00.mar00_descri`) e Referências de Fábrica (`pro00_ref001`, `pro00_ref002`), além da tradicional descrição do produto (`pro00_descri`).
- **Enriquecimento dos Cards de Produto e Carrinho de Compras**:
  - Implementação do card modular `ItemPedidoCardWidget` e atualização da lista de produtos e itens do pedido (`PedidoItensListaWidget`).
  - Apresentação organizada em badges e rótulos de fácil leitura: Marca, Referência 1/2 e Código EAN diretamente na listagem e no resumo da digitação.
- **Camada de Dados e Modelos**:
  - Criação do DTO `ProdutoLookupDto` e enriquecimento das structs `ItemPedidoStruct` e `ProdutoResultStruct`.
  - Consultas com joins e índices otimizados no repositório `ProdutoRepository`.

### 🛡️ Testes e Garantia de Qualidade
- **Suíte de Testes Unitários e de Widgets**:
  - Cobertura do módulo de PDF: `test/modules/pdf/` (`espelho_pedido_dto_test.dart`, `pdf_filtro_itens_test.dart`, `pdf_generator_service_test.dart`, `standard_pdf_order_template_test.dart`, `carregar_espelho_pedido_service_test.dart`).
  - Cobertura de Logotipo e Configuração: `test/core/services/empresa_logo_service_test.dart`, `test/pages/configuracao_page_test.dart` e `test/database/local_sales_database_protection_test.dart`.
  - Cobertura da Pesquisa de Produtos: `test/data/repositories/produto_repository_test.dart`, `test/domain/models/produto_lookup_dto_test.dart`, `test/busca_produto_test.dart` e `test/pedido_itens_lista_card_test.dart`.

### 📚 Documentação e Especificações
- Registrada [`00_ESPECIFICACAO_GERACAO_PDF_PEDIDO.md`](docs/specs/00_ESPECIFICACAO_GERACAO_PDF_PEDIDO.md).
- Registrada [`ESPECIFICACAO_TECNICA_LOGOMARCA DINÂMICA (CADACE00), CONFIGURACAO_DE_EXIBICAO_E_SUPORTE.md`](docs/specs/ESPECIFICACAO_TECNICA_LOGOMARCA%20DIN%C3%82MICA%20(CADACE00),%20CONFIGURACAO_DE_EXIBICAO_E_SUPORTE.md).
- Registrada [`00_ESPECIFICACAO_PESQUISA_PRODUTOS_EAN_MARCA_REFERENCIA.md`](docs/specs/00_ESPECIFICACAO_PESQUISA_PRODUTOS_EAN_MARCA_REFERENCIA.md).

---

## [5.2.0] - 2026-09-10

### 🌟 Adicionado (Novas Funcionalidades e Padronizações)

#### 1. Padronização Visual e Responsiva de Modais (Bottom Sheets) com SafeArea
- **Componente e Helper Centralizado (`lib/core/app_bottom_sheet.dart`)**:
  - Implementação de `AppBottomSheet` e função helper `showAppModalBottomSheet<T>()` baseados no design de referência do Menu de Relatórios.
  - Recursos visuais: Barra de arraste superior (`drag handle`), cabeçalho com ícone, título em negrito, botão de fechar padronizado (`AppIconButton`), cantos superiores arredondados (24px) e contenção de largura para tablets (`ConstrainedBox(maxWidth: 600.0)`).
  - **Correção Estrita de SafeArea**: Configuração obrigatória de `useSafeArea: true` e `SafeArea(bottom: true)` com padding dinâmico via `MediaQuery.of(context).padding.bottom`, garantindo que nenhum elemento ou botão fique sobreposto ou oculto atrás da barra de navegação virtual do Android/iOS.
- **Refatoração Global de Modais**:
  - Migração de todos os bottom sheets do aplicativo: Pedidos (`ModalPedidosWidget`), Clientes (`ModalClienteWidget`), Agente Cobrador (`ModalAgenteCobradorWidget`), Seleção de Filial (`ModalSelecaoFilialWidget`), Combos (`BottomSheetCombosWidget`), Bonificações (`BottomSheetSelecaoBonificacaoWidget`), Extrato de Duplicatas e Compartilhamento (`ExtratoDuplicatasWidget`), Início e Ações do Pedido (`PedidoNovoInicioWidget`, `PedidoItensListaWidget`) e Adição ao Carrinho (`BuscaProdutoPageWidget`).

#### 2. Centralização e Formatação Monetária Brasileira Padrão R$ (pt_BR)
- **Utilitário Global (`lib/core/formatters/currency_formatter.dart`)**:
  - Criação da função central `formatMoeda(num? valor, {bool incluirSimbolo = true})` e extensões diretas `num?.toMoeda()`, `num?.toMoedaSemSimbolo()` e `String?.toMoeda()`.
  - Formatação com `intl` (`NumberFormat.currency(locale: 'pt_BR', symbol: 'R$')`) com normalização de espaços, garantindo apresentação consistente no formato `R$ 1.250,50` (milhar com ponto, decimal com vírgula).
- **Unificação nos Serviços e Telas**:
  - Centralização de `formatPreco` e dos serviços de relatórios (`FaturamentoMetasService`, `ResumoVendasService`, `ReceberDuplicatasService`).
  - Varredura e padronização em listagens de produtos, rascunhos, resumos de pedidos, extratos de clientes, avisos de bloqueio por limite de crédito e central de pacotes.

#### 3. Visualizador de Imagens com Zoom Interativo e Compartilhamento
- **Integração com `share_plus`**: Adicionado `share_plus: ^12.0.2` para envio de mídias e dados para aplicativos terceiros (WhatsApp, Telegram, etc.).
- **Diálogo Interativo (`lib/widgets/imagem_preview_dialog.dart`)**:
  - Visualização em tela cheia com fundo escuro e zoom fluido via `InteractiveViewer` (0.8x a 5.0x) com suporte a duplo toque para reset.
  - Ação de **Compartilhar**: Envio nativo do arquivo local de imagem via `Share.shareXFiles` (ou texto descritivo via `Share.share`).
  - Ação de **Copiar**: Cópia de informações/caminho para a área de transferência via `Clipboard.setData`.
- **Ativação Global em `ImagemLocalWidget`**:
  - Habilitado por padrão (`enablePreview: true`), envolvendo qualquer imagem de produto em listas, detalhes e itens de pedidos com toque interativo para abertura imediata do preview.

### 🛡️ Testes e Garantia de Qualidade
- **Testes Automatizados**: Suíte completa de testes executada com 100% de sucesso (**151/151 testes aprovados**).
- **Análise Estática**: `flutter analyze` executado com zero erros e zero avisos (`No issues found!`).

---

## [5.1.0] - 2026-09-02

### 🌟 Adicionado (Novas Funcionalidades)

#### 1. Módulo de Contas a Receber (Receber / Gestão de Duplicatas)
- **Consulta Consolidada Geral (`ReceberPageWidget`)**:
  - Hub financeiro 100% offline para acompanhamento da inadimplência da carteira.
  - Card de resumo financeiro superior: Montante Total Devedor, Total Vencido e Total A Vencer.
  - Filtros operacionais reativos por chips: `Todos com Débito`, `Apenas Vencidos` e `A Vencer`.
  - Ordenação dinâmica com foco em mitigação de risco: **Aging / Maior Tempo de Atraso** (padrão), Maior Valor Devedor e Ordem Alfabética.
  - Barra de busca instantânea por Código, Razão Social ou Nome Fantasia.
- **Extrato Analítico em Sliding BottomSheet (`ExtratoDuplicatasWidget`)**:
  - Abertura suave e modal que preserva a posição de rolagem da lista macro de clientes.
  - Badges coloridos de alerta: destaque em vermelho para títulos vencidos (`X dias de atraso`) com juros acumulados; verde para títulos no prazo.
  - Auditoria de limites de crédito: Limite Total (`cli00_crelim`) e Limite Disponível (`cli00_creatu`).
  - **Cobrança Amigável**: Ação de compartilhamento com formatação limpa e emojis para envio direto via WhatsApp ou cópia para Clipboard.
  - **Atalho de Novo Pedido**: Abertura direta do carrinho de digitação com validação de barreira de bloqueio e termo de responsabilidade para clientes com débitos vencidos.
- **Pontos de Entrada no Sistema**:
  - Novo botão **"Receber"** no menu principal (`HomePageWidget`) ao lado de "Relatórios", completando a grade 2x3.
  - Atalho de consulta rápida no modal de clientes (`ModalClienteWidget`).
  - Botão de auditoria de duplicatas na AppBar da ficha do cliente (`ExtratoClientePageWidget`).

#### 2. Módulo de Relatórios Comerciais e Produtividade
- **Conta-Corrente do Vendedor (CCV / Saldo Flex)**:
  - Apuração em tempo real do Saldo Base oficial (`ccv01_vlrsal`) + Provisão de Digitação (`ccv01_vlrusedig`) + Pedidos em Trânsito (`ccv01_vlrusepck`).
  - Validação da trava de desconto `ven00_chkccv`.
- **Faturamento e Acompanhamento de Metas (`FaturamentoMetasPageWidget`)**:
  - Cota mensal (`fat00_vlrcalven`) vs. Faturamento ERP (`fat00_vlrfatven`).
  - Sintetização local considerando rascunhos e lotes em trânsito.
  - Controle e validação de teto de faturamento para Pessoa Física (`fat00_vlrtotlib` e `cli00_typpes = 1`).
- **Resumo de Vendas Diário e Comissões (`ResumoVendasPageWidget`)**:
  - Totalizadores de Venda Bruta, Devoluções/Cortes e Venda Líquida.
  - Cálculo de comissão acumulada item por item conforme alíquota do cadastro de produtos (`cadpro00.pro00_commax`).
  - Tratamento de itens bonificados (`bontyp > 0`) com comissão zerada (0%).
  - Diferenciação entre comissão projetada (pedidos locais) e homologada (pedidos faturados via `.ret`).
- **Carteira de Clientes e Roteirização (`CarteiraRoteirizacaoPageWidget`)**:
  - Segmentação de visitas por dia da semana (`cli00_flgven`).
  - Semáforo financeiro: Vermelho (Inadimplente), Amarelo (Vencimento Próximo) e Verde (Crédito em dia).
  - Consulta de limites de crédito e coordenadas de georreferenciamento (`cli16_codlat`, `cli16_codlon`).

### ⚙️ Melhorias e Refatorações (DRY)
- **Serviço Centralizado [`ReceberDuplicatasService`]**:
  - Unificação do motor de cálculo de duplicatas (`dup00`) para relatórios e checkout.
  - Resolução dinâmica de nomes de tabelas e colunas via `PRAGMA table_info`, garantindo imunidade a variações de esquemas de banco (PRD, legados e testes).
  - Cálculo offline fiel de juros de mora utilizando rigorosamente a taxa `ven00_txajur` do representante (`cadrep00`). Se ausente ou zero, o juro apurado é mantido em R$ 0,00 sem taxas inventadas.
- **Refatoração do [`BloqueioFinanceiroService`]**:
  - Eliminação de duplicidade de código SQL (DRY), passando a consumir o `ReceberDuplicatasService` para validação de títulos vencidos na abertura e fechamento de pedidos.
- **Banco de Dados Local (`LocalSalesDatabaseService`)**:
  - Migração automática para garantir a tabela `dup00`, coluna `cadrep00.ven00_txajur`, índices de alta performance em `dup00_codcli` e `dup00_datven`, e views de compatibilidade `findup00` e `cadrecdup00`.

### 🛡️ Testes e Garantia de Qualidade
- **Testes Unitários e de Integração**:
  - Criação de `test/receber_duplicatas_service_test.dart` com validação de apuração de dias de atraso, juros ponderados, parse de datas, geração de texto de WhatsApp, filtros de status e ordenação por Aging.
- **Testes de Widgets**:
  - Criação de `test/receber_page_widget_test.dart` validando renderização de cabeçalho, filtros, botões de ação e Sliding BottomSheet.
  - 100% dos testes passando com sucesso.
- **Análise Estática**:
  - Execução de `flutter analyze` sem nenhum erro ou aviso (`No issues found!`).

### 📚 Documentação e Governança
- Registrada [`ADR 0002: Arquitetura do Módulo de Contas a Receber e Gestão de Duplicatas Offline`](docs/adr/0002-modulo-receber-duplicatas-offline.md).
- Atualizado o glossário de domínio e regras de negócio em [`CONTEXT.md`](CONTEXT.md).
