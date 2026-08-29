# PROJECT BRAIN — FORÇA DE VENDAS (FLUTTER & SQLITE)
> **Versão:** 2.0.0  
> **Status:** Homologado & Ativo  
> **Escopo:** Aplicativo Mobile Força de Vendas Offline-First (Flutter / SQLite / FTP)

---

## 1. Visão Geral e Arquitetura

### 1.1 Padrão Arquitetural
O projeto adota uma arquitetura em camadas orientada a recursos (**Feature-First / Clean Architecture** adaptada para ecossistemas híbridos Flutter / FlutterFlow), separando estritamente:
- **UI / Presentation Layer (`lib/pages/`, `lib/components/`, `lib/widget/`):** Telas e componentes reativos utilizando `AppModel` e `safeSetState`.
- **Domain Layer (`lib/domain/models/`, `lib/domain/services/`):** Modelos puros de negócio (`PedidoVenda`, `ItemPedidoVenda`, `ParcelaVenda`, `AgenteCobrador`, `StatusEnvio`), cálculos fiscais (`IcmsStService`) e validações de crédito (`BloqueioFinanceiroService`).
- **Data / Infrastructure Layer (`lib/data/`, `lib/backend/`, `lib/services/`):** DAOs, serviços de banco local (`LocalSalesDatabaseService`), gerador de XML/PAC (`PacXmlGeneratorService`), cliente FTP (`FtpClient`, `FtpTransport`, `FtpUploadService`) e manifesto de arquivos (`CargaRegistryService`).
- **Action Code Layer (`lib/action_code/`):** Ações orquestradoras e pipelines de caso de uso (ex: `concluirVendaProcess`, `salvarCarrinhoPedido`, `buscaProduto`, `listarPedidosHistorico`, `offlineLogin`, `doMaintenance`).

```
lib/
├── action_code/      # Casos de uso e pipelines de negócio
├── backend/          # API Manager, FTP Client/Transport e Schemas Structs
├── components/       # Modais e widgets compartilhados
├── core/             # Helpers de navegação, tema e utilitários
├── data/             # DAOs, Repositories e Serviços de Infraestrutura
├── domain/           # Entidades de domínio, Enums e Serviços puros
├── functions/        # Funções puras de formatação e resolução
├── pages/            # Telas do aplicativo (Home, Pedidos, Clientes, etc.)
└── services/         # Orquestradores de persistência, carga e envio FTP
```

---

### 1.2 Gerenciamento de Estado Global (`AppState`)
O estado global do aplicativo é centralizado no singleton reativo `AppState` (`lib/app_state.dart`), com persistência local assíncrona via `SharedPreferences`:
- **Sessão do Representante:** `vendedor_codigo`, `vendedor_nome`, `vendedor_equipe`, `empresa_codigo`.
- **Sessão de Filial:** `codFilialAtiva`, `filialAtivaDes` (isolamento multi-filial).
- **Parâmetros de Perfil Comercial (`cadrep00`):**
  - `ven_chkest` (1 = Bloqueio rígido de estoque; 0 = Permissivo/Aviso).
  - `ven_gerbonfor` (1 = Permite bonificação comercial de força de venda).
  - `ven_chkage` (1 = Exige agente cobrador obrigatório).
  - `ven_ignlimfis` (1 = Ignora limite de crédito do cliente; 0 = Bloqueio rígido).
  - `ven_maxitmdig` (Limite máximo de itens permitidos no pedido).
  - `ven_passet` (Senha de supervisor para desbloqueio comercial).

---

### 1.3 Injeção de Dependências e Ciclo de Vida
- **Services:** Instanciados via factory / singleton sem acoplamento direto com a UI.
- **LocalSalesDatabaseService:** Ponto único de acesso ao SQLite local, garantindo que conexões sejam abertas e fechadas de forma limpa, criando views de compatibilidade (`dig00`, `dig01`) e assegurando sincronização física.
- **Ciclo de Vida das Telas:** Gerenciado via `AppModel` com métodos `initState` e `dispose` explícitos para desalocar controllers, focus nodes e animações.

---

## 2. Mapa do Banco de Dados Local (SQLite)

### 2.1 Arquivos Físicos e Isolamento
O aplicativo trabalha no modo **Offline-First**, utilizando dois arquivos lógicos de banco de dados no diretório `getDatabasesPath()`:
1. **`dbforcacad001.db` (Banco de Cadastros e Persistência Unificada):** Contém os dados estáticos sincronizados da retaguarda ERP (clientes, produtos, tabelas de preço, prazos, duplicatas) e as tabelas ativas de digitação.
2. **`dbforcadig001.db` (Alias de Digitação / Compatibilidade PRD):** Espelho lógico/físico para garantir que pedidos em andamento nunca sejam sobrescritos durante atualizações de carga.

O serviço `LocalSalesDatabaseService.getTargetDatabasePaths()` resolve automaticamente todos os bancos presentes no dispositivo para garantir consistência de gravação e leitura.

---

### 2.2 Schemas das Tabelas Ativas

#### A. Cabeçalho de Pedidos (`pckvendig000` / View `dig00`)
```sql
CREATE TABLE IF NOT EXISTS pckvendig000 (
  ped00_numped INTEGER PRIMARY KEY,   -- Número sequencial do pedido
  ped00_codcli INTEGER,               -- Código do cliente faturado
  ped00_codlin INTEGER,               -- Código da linha de produto
  ped00_codpla INTEGER,               -- Código da condição/plano de pagamento
  ped00_codfil INTEGER,               -- Filial faturadora da venda
  ped00_codrep INTEGER,               -- Código do representante vendedor
  ped00_codagt INTEGER,               -- Código do agente cobrador
  ped00_digtab INTEGER,               -- Tabela de preços aplicada
  ped00_digcob INTEGER,               -- Tipo de cobrança (age00_tipo)
  ped00_bonfrcven INTEGER DEFAULT 0,  -- Flag de bonificação autorizada
  ped00_sttdig INTEGER DEFAULT 0,     -- Status de Digitação (0=Rascunho, 1=Concluído)
  ped00_sttenv INTEGER DEFAULT 0,     -- Status de Envio (0=Digitado, 1=Empacotado, 2=Transmitido)
  ped00_datsys TEXT,                  -- Data da digitação (YYYY-MM-DD)
  ped00_clides TEXT,                  -- Razão Social do cliente (Snapshot)
  ped00_lindes TEXT,                  -- Descrição da linha (Snapshot)
  ped00_plades TEXT,                  -- Descrição do plano (Snapshot)
  ped00_digtot REAL DEFAULT 0,        -- Total líquido dos produtos
  ped00_fattot REAL DEFAULT 0,        -- Total da fatura (digtot - subtot)
  ped00_subtot REAL DEFAULT 0,        -- Valor total de ICMS-ST
  ped00_bontot REAL DEFAULT 0,        -- Valor total de bonificações
  ped00_destot REAL DEFAULT 0,        -- Valor total de descontos
  ped00_pacstr TEXT                   -- Nome do arquivo .pac gerado (ex: p71-1007.pac)
);
```

#### B. Itens do Pedido (`pckvendig010` / View `dig01`)
```sql
CREATE TABLE IF NOT EXISTS pckvendig010 (
  ped10_numped INTEGER,               -- FK apontando para ped00_numped
  ped10_seq INTEGER DEFAULT 1,        -- Sequencial do item no pedido (1, 2, 3...)
  ped10_codprd TEXT,                  -- Código de catálogo do produto
  ped10_descri TEXT,                  -- Descrição comercial do produto
  ped10_unidpri TEXT,                 -- Unidade de medida (UN, CX, KG)
  ped10_qtdped REAL DEFAULT 0,        -- Quantidade vendida
  ped10_pcosub REAL DEFAULT 0,        -- Preço unitário praticado
  ped10_totprd REAL DEFAULT 0,        -- Total líquido do item
  ped10_qtdbon REAL DEFAULT 0,        -- Quantidade bonificada
  ped10_sttbon INTEGER DEFAULT 0,     -- Flag item bonificado (0=Não, 1=Sim)
  ped10_codcmb TEXT,                  -- Código do combo associado (se houver)
  ped10_subtot REAL DEFAULT 0,        -- ICMS-ST calculado para a linha
  ped10_destot REAL DEFAULT 0         -- Desconto nominal aplicado na linha
);
```

#### C. Catálogo de Produtos (`cadpro00`) e Embalagens (`cadproemb02`)
```sql
-- cadpro00
pro00_codigo INTEGER PRIMARY KEY,     -- Código único do produto
pro00_descri TEXT,                    -- Descrição comercial
pro00_unidad TEXT,                    -- Sigla da unidade (UN, CX, KG, LT)
pro00_indfra INTEGER,                 -- 0 = Inteiro obrigatório, 1 = Aceita decimais
pro00_peso INTEGER,                   -- 1 = Venda pesada / balança
pro00_pesbru REAL,                    -- Peso bruto unitário
pro00_pesliq REAL,                    -- Peso líquido unitário
pro00_qtdest REAL,                    -- Saldo físico de estoque sincronizado
pro00_prifil INTEGER,                 -- Filial detentora do estoque
pro02_mulemb INTEGER,                 -- Multiplicador da embalagem master
pro02_mulven REAL                     -- Multiplicador de venda (mulver)
```

#### D. Cadastro de Clientes (`cadcli00`) e Duplicatas (`dup00`)
```sql
-- cadcli00
cli00_codigo INTEGER PRIMARY KEY,     -- Código do cliente
cli00_descri TEXT,                    -- Razão Social
cli00_fantas TEXT,                    -- Nome Fantasia
cli00_cpfcnp TEXT,                    -- CPF ou CNPJ sem formatação
cli00_insest TEXT,                    -- Inscrição Estadual
cli00_active INTEGER,                 -- 1 = Ativo, 0 = Inativo / Bloqueado
cli00_codrep INTEGER,                 -- Representante vinculado
cli00_codage INTEGER,                 -- Agente cobrador padrão
cli00_crelim REAL,                    -- Limite de crédito total concedido
cli00_creatu REAL,                    -- Saldo de crédito disponível atualizado
cli00_titven REAL,                    -- Total de títulos vencidos em aberto
cli00_titave REAL                     -- Total de títulos a vencer

-- dup00 (Duplicatas em aberto para auditoria financeira offline)
dup00_codcli INTEGER,                 -- Código do cliente
dup00_numdup TEXT,                    -- Número da duplicata
dup00_datven TEXT,                    -- Data de vencimento (YYYY-MM-DD)
dup00_valdup REAL,                    -- Valor original da duplicata
dup00_saldup REAL,                    -- Saldo devedor em aberto
dup00_codven INTEGER                  -- Representante emissor do título
```

#### E. Tabelas de Suporte e Estatísticas Locais
- **`cadrep00`:** Configurações do vendedor, equipe e permissões comerciais.
- **`cadpla00`:** Planos de pagamento, multiplicadores financeiros (`pla00_fator`) e prazos.
- **`cadlin00`:** Linhas e categorias de produtos.
- **`cadfer00`:** Calendário de feriados para postergação automática de vencimentos.
- **`codage00` / `cadagt00` / `cadcob00`:** Agentes cobradores e bancos emissores.
- **`ESTFATCVD00`:** Snapshot de faturamento local por pedido para extrato offline.
- **`FINCAICVD00`:** Movimentação financeira e provisão de caixa por pedido.
- **`ESTPRO00`:** Registro de saldos e quantidades pendentes (`pro00_qtdpen`) por filial.

---

## 3. Fluxos e Regras Centrais

### 3.1 Autenticação e Isolamento Multi-Filial
1. **Login Online (Primeiro Acesso):** Comunica com a API Serverless para validação e autorização de download de carga inicial.
2. **Login Offline:** Valida credenciais na tabela `cadrep00`, carregando as permissões comerciais para o `AppState`.
3. **Isolamento de Sessão:** A filial ativa (`AppState().codFilialAtiva`) é injetada em todas as consultas de estoque, preços e no cabeçalho dos pedidos (`ped00_codfil`), garantindo integridade estrita entre diferentes filiais no mesmo aparelho.

---

### 3.2 Consulta de Produtos, Preços e Estoque Dinâmico
- **Cálculo de Estoque Disponível:**
  $$\text{Estoque Disponível} = \text{pro00\_qtdest} - \sum (\text{Itens em pedidos rascunho com } \text{sttdig}=0)$$
- **Políticas de Preço:**
  $$\text{Preço Efetivo} = \text{Preço Base da Tabela} \times \text{Fator do Plano} - \text{Descontos}$$
  - Bloqueio impeditivo se `Preço Digitado < pro00_pcomin`.
  - Auditoria de teto de desconto via `pro00_commax`.
- **Motor Fiscal (ICMS-ST Dinâmico):**
  - MVA e alíquotas lidas dinamicamente do banco local para cada item faturado via `IcmsStService`.
  - Base ST calculada e deduzida do ICMS próprio, alimentando `ped10_subtot` e consolidando em `ped00_subtot`.
- **Tratamento de Unidades:**
  - `pro00_indfra = 0`: Restrição estrita a quantidades inteiras.
  - `pro00_indfra = 1` ou `pro00_peso = 1`: Suporte a frações decimais (3 casas).

---

### 3.3 Máquina de Estados do Pedido

```
                     ┌──────────────────────────────┐
                     │ RASCUNHO (pvddsEDITANDO)     │  sttdig = 0 | sttenv = 0
                     │ (Itens editáveis no grid)    │
                     └──────────────┬───────────────┘
                                    │
                         (concluirVendaProcess)
                                    │
                                    v
                     ┌──────────────────────────────┐
                     │ CONCLUÍDO (pvddsDIGITADO)    │  sttdig = 1 | sttenv = 0
                     │ (Valores congelados)         │
                     └──────────────┬───────────────┘
                                    │
                        (Geração Automática .PAC)
                                    │
                                    v
                     ┌──────────────────────────────┐
                     │ EMPACOTADO (pvddeEMPACOTE)   │  sttdig = 1 | sttenv = 1
                     │ (Travado contra edições)     │
                     └──────────────┬───────────────┘
                                    │
                         (Upload FTP Concluído)
                                    │
                                    v
                     ┌──────────────────────────────┐
                     │ TRANSMITIDO (pvddeENVIADOS)  │  sttdig = 1 | sttenv = 2
                     │ (Histórico / Somente Leitura)│
                     └──────────────────────────────┘
```

#### Regras de Transição:
- **Rascunho (`sttdig = 0`, `sttenv = 0`):** Em digitação livre; itens podem ser alterados/excluídos.
- **Concluído (`sttdig = 1`, `sttenv = 0`):** Fechado pelo motor de vendas.
- **Empacotado (`sttdig = 1`, `sttenv = 1`):** XML serializado e comprimido em `.pac`, pronto para envio via FTP. Bloqueado contra alteração no grid.
- **Transmitido (`sttdig = 1`, `sttenv = 2`):** Upload confirmado com sucesso pelo servidor FTP.

---

### 3.4 Pipeline de Sincronização e Empacotamento FTP

#### A. Estrutura do Pacote `.pac` (Protocolo Suportware)
O arquivo `.pac` é um container ZIP padronizado contendo internamente o arquivo `pedido.xml`:
- **Nomenclatura do Arquivo:** `p<codRep>-<codMov>.pac` (Ex: `p71-1007.pac`).
- **Nomenclatura de Novos Clientes:** `c<codRep>-<retornaMil()>.xml`.
- **Envelope XML Legado:**
  ```xml
  <!DOCTYPE suportware>
  <root sys_versao="1.0" rep00_codigo="71">
    <pckvenpac00>
      <pac00 pac00_pacrep="71" pac00_paccod="1007" pac00_pacqtd="3" pac00_pactot="450.00" ...>
        <pac01 pac01_paccod="1007" pac01_pacitm="1" pac01_procod="78945" pac01_qtd="10.00" ... />
      </pac00>
      <cot00/>
    </pckvenpac00>
  </root>
  ```

#### B. Diretórios Remotos FTP por Empresa e Equipe
- **Pedidos (`.pac`):** `/{empresa}/{equipe}/Externo/`
- **Novos Clientes (`.xml`):** `/{empresa}/{equipe}/Customer/`
- **Cargas Gerais:** `/{empresa}/{equipe}/Upload/`

---

## 4. Decisões Técnicas e Invariantes

> [!IMPORTANT]
> **INVARIANTES ARQUITETURAIS E REGRAS ESTRITAS (NÃO VIOLAR EM REFATORAÇÕES):**

1. **Conexão SQLite Singleton Ativa:**
   Todas as rotinas de leitura, escrita e modais devem utilizar `LocalSalesDatabaseService.getDatabase()`. É estritamente proibido invocar `db.close()` ou abrir sessões com `readOnly: true` em funções intermediárias ou blocos `finally`.

2. **Separação Rígida entre Gravação Local e Rede:**
   A conclusão de venda (`concluirVendaProcess` / `salvarCarrinhoPedido` / `ConcluirVendaService.gerarESalvarPedidoLocal`) é **100% offline**. Ela grava no SQLite e gera o `.pac` em disco local sem realizar chamadas de rede. O upload FTP ocorre exclusivamente sob demanda em *Ferramentas → Dados → Subir Carga* ou no sync em segundo plano.

3. **Desacoplamento da Geração do Pacote .pac:**
   O commit da venda no SQLite tem prioridade máxima (`sttdig = 1`, `sttenv = 1`). A geração/compressão do `.pac` é encapsulada em bloco try/catch isolado; falhas de arquivo/permissão nunca anulam ou revertem o pedido gravado no banco de dados.

4. **Tratamento de Conflito de Chave Primária:**
   Como o pedido pode ser pré-salvo em `pckvendig000`, a finalização deve usar `INSERT OR REPLACE INTO pckvendig000` ou `UPDATE pckvendig000 ... WHERE ped00_numped = ?`. Nunca fazer `INSERT` simples sem resolução de conflito.

5. **Garantia Defensiva de Tabelas e Colunas:**
   Toda rotina de escrita e abertura no SQLite deve invocar `CREATE TABLE IF NOT EXISTS` para as tabelas principais (`pckvendig000`, `pckvendig010`) e estatísticas (`ESTFATCVD00`, `FINCAICVD00`, `ESTPRO00`), além de aplicar `ALTER TABLE ... ADD COLUMN` para todas as colunas de cabeçalho e itens, garantindo retrocompatibilidade com bancos legados.

6. **Tratamento e Rastreamento Explícito de Exceções:**
   Qualquer falha durante a persistência relacional do pedido deve capturar `(e, stack)`, imprimir com destaque `>>> ERRO REAL NO CONCLUIR_VENDA_PROCESS: $e \n $stack` e propagar exceções com mensagem detalhada para exibição na UI.

7. **Idempotência no Upload FTP:**
   A atualização de `sttenv = 2` no SQLite só é executada após confirmação absoluta do comando `stor` do FTP e verificação do tamanho do arquivo remoto (`SIZE`). Em caso de falha de conexão, o arquivo permanece na pasta temporária e o status permanece `sttenv = 1` para reenvio automático.
