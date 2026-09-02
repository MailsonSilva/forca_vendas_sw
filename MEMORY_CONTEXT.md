# MEMORY CONTEXT — FORÇA DE VENDAS (FLUTTER & SQLITE)
> **Versão:** 2.2.0  
> **Status:** 100% Homologado, Testado e Protegido (71/71 Testes Automatizados Aprovados)  
> **Escopo:** Aplicativo Mobile Força de Vendas Offline-First (Flutter / SQLite / XML-PAC / FTP)

---

## 1. Visão Geral e Arquitetura do Aplicativo

### 1.1 Padrão Arquitetural
O aplicativo adota uma arquitetura modular por camadas e orientada a casos de uso (**Clean Architecture / Feature-First**), separando estritamente:
- **Presentation Layer (`lib/pages/`, `lib/components/`):** Widgets Flutter reativos, modais padronizados, formulários com `InputDecorationTheme` global e gerenciamento de estado via `AppModel` com métodos `safeSetState`, `initState` e `dispose`.
- **Domain Layer (`lib/domain/models/`, `lib/domain/services/`):** Modelos de negócio puros (`PedidoVenda`, `ItemPedidoVenda`, `ParcelaVenda`, `AgenteCobrador`, `StatusEnvio`, `ContaCorrenteSaldo`, `ContaCorrenteMovimentacao`), regras fiscais (`IcmsStService`) e validações financeiras (`BloqueioFinanceiroService`).
- **Data & Infrastructure Layer (`lib/data/`, `lib/services/`, `lib/backend/`):** Acesso a banco local (`LocalSalesDatabaseService`), gerador de pacotes comprimidos (`PacXmlGeneratorService`), registro e manifesto de arquivos (`CargaRegistryService`), serviço de conta-corrente (`ContaCorrenteService`) e cliente FTP (`FtpUploadService`, `FtpClient`).
- **Action Code Layer (`lib/action_code/`):** Orquestradores de casos de uso e regras de transição (ex: `concluirVendaProcess`, `salvarCarrinhoPedido`, `carregarAgentesCobrador`, `carregarClienteOffline`, `enviarArquivosPendentesFtp`).

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
- **Busca Rápida de Clientes:** Filtro instantâneo por código, razão social, nome fantasia e CNPJ/CPF em `cadcli00`.
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

---

## 3. Invariantes e Regras de Segurança Rígidas (NUNCA ALTERAR)

> [!CAUTION]
> **REGRA 1: Conexão SQLite Singleton Ativa**  
> Todas as rotinas de leitura, escrita e modais **DEVEM** utilizar `LocalSalesDatabaseService.getDatabase()`.  
> **É ESTRITAMENTE PROIBIDO** chamar `db.close()` ou abrir conexões com `readOnly: true` em funções intermediárias ou blocos `finally`.  
> O SQLite no Flutter mobile opera em modo singleton; fechar o banco ou alternar para read-only derruba transações subsequentes e causa travamentos de WAL.

> [!IMPORTANT]
> **REGRA 2: Migração Defensiva e Detecção de Colunas**  
> Toda persistência deve ser protegida com blocos `ALTER TABLE ADD COLUMN` para todas as colunas de `pckvendig000`, `pckvendig010` e `fincaimovccv00`.  
> As operações de `UPDATE` e `SELECT` devem resolver a coluna de ID primário de forma resiliente inspecionando aliases (`ped00_numped`, `numped`, `ped00_codmov`, `codmov`, `ped00_pedcod`, `id`).

> [!TIP]
> **REGRA 3: Desacoplamento da Geração do Pacote `.pac`**  
> A gravação do pedido no banco de dados SQLite tem prioridade máxima.  
> O commit do pedido (`ped00_sttdig = 1`, `ped00_sttenv = 1`) deve ser concluído e confirmado **antes** da escrita do arquivo `.pac`.  
> A geração e compressão do pacote `.pac` deve rodar em seu próprio bloco `try/catch`. Qualquer falha de I/O em disco ou permissão de arquivo deve apenas registrar log de aviso, **NUNCA** cancelando ou revertendo a venda gravada no SQLite.

> [!WARNING]
> **REGRA 4: Tratamento de Conflito de Chave Primária**  
> Como o pedido pode ser pré-salvo como rascunho antes da seleção do cobrador, a finalização deve sempre executar `UPDATE pckvendig000 ... WHERE ped00_numped = ?` ou `INSERT OR REPLACE INTO pckvendig000`. Nunca realize `INSERT` direto sem cláusula de substituição/conflito.

---

## 4. Guia Rápido de Arquivos e Funções Principais

| Módulo / Recurso | Arquivo Principal | Função / Responsabilidade |
|---|---|---|
| **Conexão SQLite** | [`lib/data/services/local_sales_database_service.dart`](file:///d:/sistema/projetos/Mobile/forca_de_vendas/lib/data/services/local_sales_database_service.dart) | Singleton do banco, migração automática e views `dig00`/`dig01`. |
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

