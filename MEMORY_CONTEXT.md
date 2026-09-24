# MEMORY CONTEXT — FORÇA DE VENDAS (FLUTTER & SQLITE)
> **Versão:** 2.5.0  
> **Status:** 100% Homologado, Testado e Protegido (Alta Performance SQLite - SPEC-053/SPEC-054)  
> **Escopo:** Aplicativo Mobile Força de Vendas Offline-First (Flutter / SQLite / XML-PAC / FTP)

---

## 1. Visão Geral e Arquitetura do Aplicativo

### 1.1 Padrão Arquitetural
O aplicativo adota uma arquitetura modular por camadas e orientada a casos de uso (**Clean Architecture / Feature-First**), separando estritamente:
- **Presentation Layer (`lib/pages/`, `lib/components/`, `lib/core/`):** Widgets Flutter reativos, modais padronizados via `AppBottomSheet` / `showAppModalBottomSheet` com `SafeArea`, visualizador interativo de imagens (`ImagemPreviewDialog` via `ImagemLocalWidget`), formatação monetária global centralizada (`lib/core/formatters/currency_formatter.dart`), formulários com `InputDecorationTheme` global e gerenciamento de estado via `AppModel` com métodos `safeSetState`, `initState` e `dispose`.
- **Domain Layer (`lib/domain/models/`, `lib/domain/services/`):** Modelos de negócio puros (`PedidoVenda`, `ItemPedidoVenda`, `ParcelaVenda`, `AgenteCobrador`, `StatusEnvio`, `ContaCorrenteSaldo`, `ContaCorrenteMovimentacao`), regras fiscais (`IcmsStService`) e validações financeiras (`BloqueioFinanceiroService`).
- **Data & Infrastructure Layer (`lib/data/`, `lib/services/`, `lib/backend/`):** Acesso a banco local (`LocalSalesDatabaseService`), gerador de pacotes comprimidos (`PacXmlGeneratorService`), registro e manifesto de arquivos (`CargaRegistryService`), serviço de conta-corrente (`ContaCorrenteService`) e cliente FTP (`FtpUploadService`, `FtpClient`).
- **Action Code Layer (`lib/action_code/`):** Orquestradores de casos de uso e regras de transição (ex: `concluirVendaProcess`, `salvarCarrinhoPedido`, `salvarClienteOffline`, `listarClientesPendentes`, `carregarAgentesCobrador`, `carregarClienteOffline`, `enviarArquivosPendentesFtp`).

### 1.2 Gerenciamento de Estado Global (`AppState`)
O estado global da aplicação reside no singleton reativo `AppState` (`lib/app_state.dart`) com sincronização em `SharedPreferences`:
- **Sessão do Representante:** `vendedor_codigo`, `vendedor_nome`, `vendedor_equipe`, `empresa_codigo`.
- **Sessão de Filial:** `codFilialAtiva`, `filialAtivaDes` — assegura isolamento multi-filial na digitação de pedidos e consulta de estoque.
- **Parâmetros Comerciais (`cadrep00`):**
  - `ven_chkest`: Controle/bloqueio de estoque (1 = Rígido; 0 = Informativo/Permissivo).
  - `ven_gerbonfor`: Permissão de bonificações de força de vendas.
  - `ven_chkage`: Exigência de agente cobrador no fechamento da venda.
  - `ven_ignlimfis`: Tratamento de limite de crédito (1 = Ignora; 0 = Alerta/Validação).
  - `ven_maxitmdig`: Quantidade máxima de itens permitida por pedido.
  - `ven_passet`: Senha de supervisor para liberação comercial.

---

## 2. Módulos Concluídos e Validados (STATUS: 100% FUNCIONAL / PROTEGIDO)

### 2.1 Autenticação & Sessão
- **Login Offline e Validação de Credenciais:** Validação do código do vendedor e senha contra a tabela `cadrep00`.
- **Seleção e Persistência de Filial Ativa:** Suporte a múltiplas filiais configuradas em `cadfil00`. A filial escolhida fica gravada no `AppState` (`codFilialAtiva`) e é propagada para todas as consultas de estoque e cabeçalho dos pedidos (`ped00_codfil`).
- **Isolamento de Dados:** Cada representante e filial operam de forma particionada no banco de dados local.

### 2.2 Clientes & Análise Financeira
- **Busca Rápida de Clientes:** Filtro instantâneo por código, razão social, nome fantasia e CNPJ/CPF em `cadcli00` / View `cli00`.
- **Consulta de Títulos em Aberto e Vencidos (`dup00`):** Consulta das duplicatas do cliente com detalhamento de parcelas, valores, vencimentos e dias de atraso.
- **Modal Informativo de Títulos Vencidos:** Exibição prévia das pendências financeiras antes do início da digitação do pedido.
- **Limite de Crédito Informativo:** O limite de crédito e o saldo disponível são informados de forma transparente, não bloqueando a abertura do carrinho, mas alertando o vendedor conforme o perfil comercial (`ven_ignlimfis`).

### 2.3 Catálogo de Produtos & Estoque
- **Tabela de Preço Ativa (`digtab` / `cadtab00`):** Aplicação de preços conforme a tabela do cliente/pedido.
- **Estoque Dinâmico por Filial (`estpro00`):** Exibição do saldo disponível considerando a filial ativa selecionada na sessão.
- **Formatação de Unidades:** Formatação inteligente que exibe inteiros para unidades fechadas (ex: `10 UN`, `5 CX`) e 3 casas decimais para unidades fracionadas (ex: `1.250 KG`).
- **Multiplicador de Venda / Embalagem (`mulver` / `mulemb`):** Cálculo automático de quantidades e valores baseado no multiplicador de venda do produto.
- **Combos e Bonificações:** Suporte a itens bonificados com valor unitário a **R$ 0,00**, gravando flags `bontyp = 1` e totalizadores em `ped00_bontot` sem afetar o faturamento líquido.

### 2.4 Digitação & Fechamento de Pedidos (Crítico)
- **Persistência Relacional Atômica:**
  - Cabeçalho em `pckvendig000` (View `dig00`) com snapshots do cliente, linha, plano e totais (`ped00_*`).
  - Itens em `pckvendig010` (View `dig01`) com sequencial (`ped10_seq`), código, quantidade, preço e flags (`ped10_*`).
- **Migração Automática e Resiliente de Schema:**
  - Rotina de auto-migração (`ALTER TABLE ADD COLUMN`) executada no `LocalSalesDatabaseService.getDatabase()` e nos serviços de gravação, garantindo que colunas ausentes em bases legadas (`ped00_numped`, `ped00_codcli`, `ped00_codagt`, etc.) sejam criadas sem erro.
- **Fluxo do Modal do Agente Cobrador (`ModalAgenteCobradorWidget`):**
  - Carregamento de cobradores via `carregarAgentesCobrador()` utilizando a conexão singleton.
  - Fechamento limpo pelo botão "X" sem travar ou deixar conexões pendentes.
  - Vinculação do código e tipo do cobrador (`ped00_codagt`, `ped00_digcob`, `ped00_codage`) ao cabeçalho do pedido.
- **Finalização com `concluirVendaProcess` / `ConcluirVendaService`:**
  - Atualização dos status: `ped00_sttdig = 1` (Fechado/Digitado) e `ped00_sttenv = 1` (Empacotado).
  - Atualização de estatísticas locais (`ESTFATCVD00`, `FINCAICVD00`, `ESTPRO00`) sem bloquear a venda.
  - Redirecionamento seguro para a tela de **Extrato do Pedido** (`PedidoResumoWidget`).
- **Edição Direta de Quantidade no Card (`ItemPedidoCardWidget`):**
  - O campo de quantidade no card de pedidos opera diretamente como um `TextField` numérico (`TextInputType.number`), abrindo unicamente o teclado numérico do dispositivo ao clicar, sem modais ou telas inferiores intermediárias.
  - Implementa controle de idempotência (`_ultimoValorSubmetido`) e limpeza prévia da fila de alertas (`clearSnackBars`), eliminando mensagens de validação duplicadas no `ScaffoldMessenger`.
- **Navegação Resiliente do Histórico de Pedidos (`PedidosRascunhosPageWidget`):**
  - `AppBar` com `leading` explícito com fallback para `/homePage` quando a tela for rota raiz pós-conclusão de venda.
  - Envoltório global com `PopScope(canPop: false)` interceptando o botão voltar nativo do Android para garantir retorno seguro ao menu principal sem fechamento indevido do aplicativo.

### 2.5 Sincronização & Upload FTP
- **Geração de Pacotes `.pac` Comprimidos:** Geração do XML do pedido pelo `PacXmlGeneratorService` e compressão em formato ZIP `.pac` em memória.
- **Nomenclatura Padrão de Arquivos:** `p<codRep>-<codMov>.pac` (ex: `p71-1007.pac`), gravado em `temp/` (fila) e `documents/` (backup).
- **Upload Idempotente com Verificação de Tamanho (`SIZE`):** Envio para o FTP com verificação estrita de integridade via comando FTP `SIZE`. O pedido só é marcado como `ped00_sttenv = 2` (Transmitido) e o arquivo local excluído após a confirmação exata dos bytes no servidor.

### 2.6 Relatórios & Conta-Corrente do Vendedor (CCV / Saldo Flex)
- **Menu "Relatórios" na Home:** Botão dedicado no painel principal que aciona o `ModalRelatoriosWidget`.
- **Extrato Analítico (`ContaCorrentePageWidget`):**
  - Painel superior com cálculo em tempo real do Saldo Disponível Líquido (`ccv01_vlrsalatu`), Saldo Base (`ccv01_vlrsal`), Em Digitação (`ccv01_vlrusedig`) e Em Trânsito (`ccv01_vlrusepck`).
  - Sinalização visual com cores dinâmicas para verba liberada (verde) e bloqueio impeditivo (vermelho).
  - Histórico cronológico de lançamentos analíticos da tabela `fincaimovccv00` com filtros por tipo (Créditos/Débitos) e busca textual por histórico/observação.
- **Regras de Negócio Homologadas:**
  - Cálculo de margem por item $\text{CCV} = (\text{Preço Praticado} - \text{Preço Máximo}) \times \text{Qtd}$.
  - Validação de margem flex no checkout: $\text{ccv01\_vlrsalatu} + \text{dig00\_ccvtot} \ge 0$.

### 2.7 Cadastro e Edição Offline de Clientes (`cadcli00` / View `cli00`)
- **Regras de Negócio e Higienização Fiscal:**
  - Remoção rigorosa de máscaras (`removerMascara`) para CPF/CNPJ, CEP, Telefone e Fax.
  - Conversão compulsória de campos textuais (Razão Social, Fantasia, Logradouro, Bairro, Cidade, Observações) para **MAIÚSCULO** (`UPPERCASE`).
  - Regra estrita de tipo de pessoa: Para **Pessoa Física (PF)**, a Inscrição Estadual (`cli00_insest`) é gravada como `"-"` e o RG é persistido em `cli00_nrg`; para **Pessoa Jurídica (PJ)**, a Inscrição Estadual é higienizada e preservada.
  - Sequencial automático de código de cliente via `LocalSalesDatabaseService.obterProximoCodigoCliente()`.
- **Persistência Relacional Atômica e Status de Envio:**
  - Gravação direta em `cadcli00` com `cli00_sttenv = 0` (Pendente de Envio) e `cli00_active = 1`.
  - Migração de schema defensiva com criação da View `cli00` apontando para `cadcli00`.
- **Geração de XML de Cliente (`ClienteXmlGeneratorService`):**
  - Geração imediata do XML no formato legado Suportware (`c<codRep>-<retornaMil(codCliente)>.xml`).
  - Escrita dupla resiliente: no subdiretório de organização `cli/` (`CPathCLI()`) e no diretório raiz de documentos/temp para o pipeline do FTP.
  - Registro no manifesto de cargas pendentes via `CargaRegistryService`.
- **Feedback Visual Obrigatório & Reatividade:**
  - Modal de confirmação que exibe Código, Razão Social, CNPJ/CPF e o **Caminho Completo do XML gerado** com opção de cópia (`SelectableText`).
  - Reatividade imediata no `ClientePageWidget`: a lista recarrega instantaneamente via `LocalSalesDatabaseService.getDatabase()` sem logout ou fechamento de sessão.

### 2.8 Central de Transmissão e Empacotamento Manual (Menu Ferramentas)
- **Integração no Menu Ferramentas:**
  - Acesso direto via card destacado **"📦 Gerar Pacotes e Enviar Carga"** em `FerramentasPageWidget`.
  - Navegação para a interface unificada `GerarPacotePageWidget`.
- **Três Abas Operacionais Integradas:**
  - **Aba 1 (Pedidos Aguardando):** Exibe pedidos finalizados com `sttenv = 0` (Aguardando Pacote). Permite seleção individual ou em massa e botão "Gerar Pacote (.pac)" com modal de confirmação. Atualiza atomicamente os pedidos para `sttenv = 1` (Empacotado) e vincula ao lote `pac00`.
  - **Aba 2 (Novos Clientes Pendentes):** Exibe clientes cadastrados ou alterados localmente aguardando upload (`cli00_sttenv = 0`). Exibe dados cadastrais, data/hora e ação de transmissão imediata para a pasta `/Customer/` do FTP.
  - **Aba 3 (Pacotes & Arquivos Prontos):** Visão completa de todos os pacotes `.pac` e XMLs de clientes prontos para envio, com filtros (Todos, Pedidos, Clientes), seleção em lote e botão "Conectar e Enviar Carga Completa ao FTP" com conferência de tamanho (`SIZE`) e atualização para `sttenv = 2` (Transmitido).

### 2.9 Padronização Visual de Modais, Formatação Monetária e Visualizador de Imagens
- **Arquitetura Padronizada de Modais (`AppBottomSheet` / `showAppModalBottomSheet`):**
  - Todos os modais do sistema adotam a estrutura de referência do Menu de Relatórios: drag handle centralizado, cabeçalho com ícone, título e botão fechar (`AppIconButton`), cantos superiores arredondados (24px) e largura máxima responsiva (`maxWidth: 600.0`).
  - **Proteção Rígida de SafeArea:** `useSafeArea: true` e `SafeArea(bottom: true)` com padding dinâmico via `MediaQuery.of(context).padding.bottom`, impedindo que botões ou rodapés fiquem ocultos atrás da barra de navegação virtual do Android/iOS.
- **Formatação Monetária Global (`lib/core/formatters/currency_formatter.dart`):**
  - Funções `formatMoeda()` e extensões `.toMoeda()`, `.toMoedaSemSimbolo()`.
  - Padrão monetário oficial brasileiro **`R$ 1.250,50`** (milhar com ponto e centavos com vírgula). Proibido exibir valores numéricos crus ou concatenados manualmente com ponto na UI.
- **Visualizador Interativo de Imagens de Produtos (`ImagemPreviewDialog` / `share_plus`):**
  - Componente base `ImagemLocalWidget` com toque habilitado por padrão (`enablePreview: true`).
  - Diálogo em tela cheia com zoom/pan fluidos (`InteractiveViewer`), reset com duplo toque, cópia de dados (`Clipboard`) e compartilhamento direto de imagens locais para WhatsApp/outros apps (`Share.shareXFiles`).

---

## 3. Invariantes e Regras de Segurança Rígidas (NUNCA ALTERAR)

> [!CAUTION]
> **REGRA 1: Conexão SQLite Singleton Ativa**  
> Todas as rotinas de leitura, escrita e modais **DEVEM** utilizar `LocalSalesDatabaseService.getDatabase()`.  
> **É ESTRITAMENTE PROIBIDO** chamar `db.close()` ou abrir conexões com `readOnly: true` em funções intermediárias ou blocos `finally`.  
> O SQLite no Flutter mobile opera em modo singleton; fechar o banco ou alternar para read-only derruba transações subsequentes e causa travamentos de WAL.

> [!IMPORTANT]
> **REGRA 2: Migração Defensiva e Detecção de Colunas**  
> Toda persistência deve ser protegida com blocos `ALTER TABLE ADD COLUMN` para todas as colunas de `cadcli00`, `pckvendig000`, `pckvendig010`, `pac00` e `fincaimovccv00`.  
> As operações de `UPDATE` e `SELECT` devem resolver nomes de colunas de forma resiliente inspecionando aliases e candidate keys, ignorando valores nulos ou vazios caso existam chaves candidatas com dados válidos.

> [!TIP]
> **REGRA 3: Desacoplamento da Geração do Pacote `.pac`**  
> A gravação do pedido no banco de dados SQLite tem prioridade máxima.  
> O commit do pedido (`ped00_sttdig = 1`, `ped00_sttenv = 1`) deve ser concluído e confirmado **antes** da escrita do arquivo `.pac`.  
> A geração e compressão do pacote `.pac` deve rodar em seu próprio bloco `try/catch`. Qualquer falha de I/O em disco ou permissão de arquivo deve apenas registrar log de aviso, **NUNCA** cancelando ou revertendo a venda gravada no SQLite.

> [!WARNING]
> **REGRA 4: Tratamento de Conflito de Chave Primária**  
> Como o pedido pode ser pré-salvo como rascunho antes da seleção do cobrador, a finalização deve sempre executar `UPDATE pckvendig000 ... WHERE ped00_numped = ?` ou `INSERT OR REPLACE INTO pckvendig000`. Nunca realize `INSERT` direto sem cláusula de substituição/conflito.

> [!IMPORTANT]
> **REGRA 5: Padrão Mandatório de Modais, SafeArea e Moeda na UI**  
> Todo e qualquer novo modal/bottom sheet do sistema **DEVE** utilizar exclusivamente `showAppModalBottomSheet<T>()` e estruturar seu conteúdo em `AppBottomSheet` com `SafeArea(bottom: true)`.  
> **É ESTRITAMENTE PROIBIDO** chamar `showModalBottomSheet` cru sem proteção de SafeArea ou permitir botões ocultos atrás da barra virtual de navegação.  
> Todo valor financeiro apresentado para o usuário **DEVE** utilizar `formatMoeda()` ou `.toMoeda()` de `currency_formatter.dart`.

> [!CAUTION]
> **REGRA 6: Proibição Estrita de `db.close()` em Custom Actions e Repositórios (SPEC-053)**  
> **É TERMINANTEMENTE PROIBIDO** invocar `db.close()` em custom actions, repositórios, DAOs ou blocos `finally` de consultas SQLite locais (`dbforcacad001.db` ou `dbforcadig001.db`).  
> O fechamento prematuro quebra o pool de conexões abertas do SQLite e causa o congelamento perpétuo da interface (spinner infinito) na navegação subsequente.

> [!IMPORTANT]
> **REGRA 7: Mapeamento em Memória via `ProductDbMetadata` e Extração Canônica (SPEC-054)**  
> É **obrigatório** o uso de `ProductDbMetadata.ensureLoaded(db)` para descobrir tabelas e colunas físicas uma única vez por sessão, salvando-as em memória estática e eliminando consultas repetidas a `PRAGMA table_info` e `sqlite_master` durante a digitação.  
> Na busca e catálogo de produtos, o preço unitário de venda deve ser extraído de `estpcopro00`/`pcopro00` (`pro00_preco` / `pro00_pcosub`) vinculado à tabela do pedido/cliente, e o estoque deve ser extraído de `estpro00` filtrando pela filial ativa, com fallback seguro para `cadpro00`.

---

## 4. Guia Rápido de Arquivos e Funções Principais

| Módulo / Recurso | Arquivo Principal | Função / Responsabilidade |
|---|---|---|
| **Conexão SQLite** | [`lib/data/services/local_sales_database_service.dart`](file:///d:/sistema/projetos/Mobile/forca_de_vendas/lib/data/services/local_sales_database_service.dart) | Singleton do banco, migração automática, views `dig00`/`dig01`/`cli00` e sequenciais automáticos. |
| **Persistência de Clientes** | [`lib/action_code/salvar_cliente_offline.dart`](file:///d:/sistema/projetos/Mobile/forca_de_vendas/lib/action_code/salvar_cliente_offline.dart) | Higienização fiscal, UPPERCASE, regras PF/PJ, persistência em `cadcli00`, XML em `cli/` e manifesto. |
| **Formulário de Clientes** | [`lib/pages/cliente/form_clientes_page/form_clientes_page_widget.dart`](file:///d:/sistema/projetos/Mobile/forca_de_vendas/lib/pages/cliente/form_clientes_page/form_clientes_page_widget.dart) | UI de cadastro/edição, integração com `salvarClienteOffline` e modal com caminho do XML. |
| **Listagem de Clientes** | [`lib/pages/cliente/cliente_page/cliente_page_widget.dart`](file:///d:/sistema/projetos/Mobile/forca_de_vendas/lib/pages/cliente/cliente_page/cliente_page_widget.dart) | Reatividade imediata pós-salvamento sem perda de sessão. |
| **Central de Transmissão (Ferramentas)** | [`lib/pages/gerar_pacote/gerar_pacote_page_widget.dart`](file:///d:/sistema/projetos/Mobile/forca_de_vendas/lib/pages/gerar_pacote/gerar_pacote_page_widget.dart) | 3 abas integradas: Pedidos Aguardando, Novos Clientes e Pacotes Prontos com envio FTP. |
| **Menu Ferramentas** | [`lib/pages/ferramentas/ferramentas_page/ferramentas_page_widget.dart`](file:///d:/sistema/projetos/Mobile/forca_de_vendas/lib/pages/ferramentas/ferramentas_page/ferramentas_page_widget.dart) | Acesso direto à Central de Transmissão e Empacotamento. |
| **Consulta de Clientes Pendentes** | [`lib/action_code/listar_clientes_pendentes.dart`](file:///d:/sistema/projetos/Mobile/forca_de_vendas/lib/action_code/listar_clientes_pendentes.dart) | Busca clientes locais com `sttenv = 0` para a Central de Transmissão. |
| **Empacotamento Manual** | [`lib/action_code/gerar_pacote.dart`](file:///d:/sistema/projetos/Mobile/forca_de_vendas/lib/action_code/gerar_pacote.dart) | Geração manual de `.pac` agrupando pedidos e atualizando para `sttenv = 1`. |
| **Menu de Relatórios** | [`lib/components/modal_relatorios/modal_relatorios_widget.dart`](file:///d:/sistema/projetos/Mobile/forca_de_vendas/lib/components/modal_relatorios/modal_relatorios_widget.dart) | Modal bottom sheet de acesso aos relatórios do sistema. |
| **Conta-Corrente (CCV)** | [`lib/pages/relatorios/conta_corrente/conta_corrente_page_widget.dart`](file:///d:/sistema/projetos/Mobile/forca_de_vendas/lib/pages/relatorios/conta_corrente/conta_corrente_page_widget.dart) | Tela de extrato analítico de saldo flex e consolidação de CCV. |
| **Serviço de CCV** | [`lib/services/conta_corrente_service.dart`](file:///d:/sistema/projetos/Mobile/forca_de_vendas/lib/services/conta_corrente_service.dart) | Consultas de saldo, histórico analítico e cálculos de margem. |
| **Pipeline de Fechamento** | [`lib/action_code/concluir_venda_process.dart`](file:///d:/sistema/projetos/Mobile/forca_de_vendas/lib/action_code/concluir_venda_process.dart) | Validação de itens, snapshots fiscais e orquestração do fechamento. |
| **Serviço de Persistência** | [`lib/services/concluir_venda_service.dart`](file:///d:/sistema/projetos/Mobile/forca_de_vendas/lib/services/concluir_venda_service.dart) | Transação SQLite do pedido, estatísticas e geração desacoplada do `.pac`. |
| **Persistência de Carrinho** | [`lib/action_code/salvar_carrinho_pedido.dart`](file:///d:/sistema/projetos/Mobile/forca_de_vendas/lib/action_code/salvar_carrinho_pedido.dart) | Gravação atômica de `pckvendig000` e `pckvendig010`. |
| **Seleção de Cobrador** | [`lib/components/modal_agente_cobrador/modal_agente_cobrador_widget.dart`](file:///d:/sistema/projetos/Mobile/forca_de_vendas/lib/components/modal_agente_cobrador/modal_agente_cobrador_widget.dart) | Modal de escolha do agente cobrador com fechamento seguro. |
| **Carregamento de Cobradores** | [`lib/action_code/carregar_agentes_cobrador.dart`](file:///d:/sistema/projetos/Mobile/forca_de_vendas/lib/action_code/carregar_agentes_cobrador.dart) | Consulta segura de cobradores via Singleton do banco. |
| **Geração de XML/PAC** | [`lib/services/pac_xml_generator_service.dart`](file:///d:/sistema/projetos/Mobile/forca_de_vendas/lib/services/pac_xml_generator_service.dart) | Serialização para XML legado e compressão ZIP. |
| **Upload FTP** | [`lib/services/ftp_upload_service.dart`](file:///d:/sistema/projetos/Mobile/forca_de_vendas/lib/services/ftp_upload_service.dart) | Envio em lote com verificação `SIZE` e atualização `sttenv = 2`. |
| **Padrão de Modais (Bottom Sheet)** | [`lib/core/app_bottom_sheet.dart`](file:///d:/sistema/projetos/Mobile/forca_de_vendas/lib/core/app_bottom_sheet.dart) | Componente `AppBottomSheet` e helper `showAppModalBottomSheet` com `SafeArea` obrigatória. |
| **Formatador Monetário R$** | [`lib/core/formatters/currency_formatter.dart`](file:///d:/sistema/projetos/Mobile/forca_de_vendas/lib/core/formatters/currency_formatter.dart) | Funções e extensões `.toMoeda()` padronizadas em `pt_BR` (`R$ 1.250,50`). |
| **Visualizador de Imagens** | [`lib/widgets/imagem_preview_dialog.dart`](file:///d:/sistema/projetos/Mobile/forca_de_vendas/lib/widgets/imagem_preview_dialog.dart) | Preview interativo com zoom, pan (`InteractiveViewer`), cópia e compartilhamento (`share_plus`). |

