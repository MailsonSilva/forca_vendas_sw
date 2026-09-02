# ESPECIFICAÇÃO TÉCNICA E REGRAS DE NEGÓCIO: LEITURA E PROCESSAMENTO DO ARQUIVO DE RETORNO (.RET)

Esta especificação técnica detalha todo o ciclo de vida, regras de negócio, momento de execução, integridade transacional e atualizações locais no banco SQLite do Força de Vendas decorrentes da **leitura e importação do arquivo de retorno (`.ret`)** emitido pela retaguarda (ERP).

O documento utiliza rigorosamente como base o layout de XML de retorno do ambiente de produção compartilhado.

---

## 1. Visão Geral e Momento da Leitura

O arquivo de retorno (`.ret`) fecha o ciclo da venda (*Order-to-Cash*), convertendo um pedido móvel provisório em um faturamento oficial com Nota Fiscal emitida pelo ERP.

```
   ┌────────────────────────────────────────────────────────────────────────┐
   │                          SERVIDOR FTP / RETAGUARDA                     │
   └──────────────────┬──────────────────────────────────▲──────────────────┘
                      │                                  │
       (1) fcfGETRET = 6                      (2) fcfRETPED = 11
           Download do Retorno                    Confirmação de Leitura (ACK)
           r<codRep>-<seq>.ret                    Arquivamento / Expurgo da Fila
                      │                                  │
                      ▼                                  │
   ┌─────────────────────────────────────────────────────┴──────────────────┐
   │                       APLICAÇÃO MÓVEL (SQLite)                         │
   │  Transação Única:                                                      │
   │  - ret00: Faturamento (dig00) -> sttenv = 3 (RECEBIDO), Nota Fiscal    │
   │  - ret01: Cortes de Estoque (dig01) -> fatqtd vs digqtd                │
   │  - ret03: Protocolo do Lote (pac00) -> sttenv = 2 (Retornado)          │
   │  - pro00: Delta de Estoque Físico (cadpro00)                           │
   │  - cli00: Delta de Limite de Crédito (cadcli00)                        │
   │  - fat00: Metas do Representante (estfatcvd00)                         │
   │  - ccv00: Conta-Corrente / Verba do Vendedor (fincaiccv01)             │
   │  - sql00: Scripts de Manutenção SQLite (PRAGMAs)                       │
   └────────────────────────────────────────────────────────────────────────┘
```

### Quando é feita a leitura?
A busca e leitura do arquivo `.ret` ocorre em dois momentos no aplicativo móvel:
1. **No Início da Sessão / Carga Inicial:** Durante a rotina matinal de sincronização executada pelo vendedor.
2. **Imediatamente após o Envio de um Pacote (`doFTPFilePut`):** Assim que a thread de sincronização conclui o upload de um `.pac`, o sistema verifica se a retaguarda já disponibilizou retornos processados de lotes anteriores na fila remota.

O comando de protocolo responsável é o **`fcfGETRET = 6`** (`TParamWriteFunc::fcfGETRET` em `usyswebutil.h`), que faz o download do arquivo localizado na pasta remota **`dirPAC`** para a pasta local de pacotes do aparelho (`Tsysfun::CPathPAC()`).

---

## 2. Modelo de Referência do Arquivo de Retorno (`.ret`)

O arquivo baixado possui a nomenclatura **`r<codRep>-<seqPacote>.ret`** (ex: `r71-1001.ret`) e apresenta a seguinte estrutura padrão:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<root>
	<ret00>
		<row dig00_digfil="1" dig00_digcod="12" dig00_fatmov="4677834" dig00_fatdat="2026-09-01T17:06:24.700Z" dig00_fattot="191.16" dig00_fatobs=""/>
		<row dig00_digfil="1" dig00_digcod="13" dig00_fatmov="4677835" dig00_fatdat="2026-09-01T17:06:24.700Z" dig00_fattot="23.88" dig00_fatobs=""/>
	</ret00>
	<ret01>
		<row dig01_digfil="1" dig01_digcod="12" dig01_digitm="1" dig01_fatqtd="2" dig01_fatpco="51.03"/>
		<row dig01_digfil="1" dig01_digcod="12" dig01_digitm="2" dig01_fatqtd="2" dig01_fatpco="44.55"/>
		<row dig01_digfil="1" dig01_digcod="13" dig01_digitm="1" dig01_fatqtd="2" dig01_fatpco="11.94"/>
	</ret01>
	<ret03>
		<row pac00_codfil="1" pac00_codlot="73831"/>
	</ret03>
	<pro00>
		<row pro00_codfil="1" pro00_codpro="19702" pro00_qtdest="0"/>
		<row pro00_codfil="1" pro00_codpro="42424" pro00_qtdest="15"/>
		<row pro00_codfil="1" pro00_codpro="43224" pro00_qtdest="42"/>
	</pro00>
	<cli00>
		<row cli00_codigo="9997" cli00_crelim="2000" cli00_creatu="-132.47"/>
		<row cli00_codigo="21893" cli00_crelim="0" cli00_creatu="0"/>
	</cli00>
	<fat00>
		<estfatdat00>
			<row dat00_dattim="2026-09-01T17:06:25.607Z"/>
		</estfatdat00>
		<estfatcvd00>
			<row fat00_codfil="1" fat00_codven="71" fat00_datmov="2026-09-01" fat00_clides="Juridica" fat00_clityp="2" fat00_vlrperfat="100" fat00_vlrfatven="0" fat00_vlrdigven="0" fat00_vlrdigloc="0" fat00_vlrtotven="0" fat00_vlrcalven="10000000" fat00_vlrtotper="0" fat00_vlrtotlib="10000000"/>
			<row fat00_codfil="1" fat00_codven="71" fat00_datmov="2026-09-01" fat00_clides="Fisica" fat00_clityp="1" fat00_vlrperfat="100" fat00_vlrfatven="0" fat00_vlrdigven="0" fat00_vlrdigloc="0" fat00_vlrtotven="0" fat00_vlrcalven="10000000" fat00_vlrtotper="0" fat00_vlrtotlib="10000000"/>
			<row fat00_codfil="100" fat00_codven="71" fat00_datmov="2026-09-01" fat00_clides="Juridica" fat00_clityp="2" fat00_vlrperfat="100" fat00_vlrfatven="0" fat00_vlrdigven="0" fat00_vlrdigloc="0" fat00_vlrtotven="0" fat00_vlrcalven="10000000" fat00_vlrtotper="0" fat00_vlrtotlib="10000000"/>
			<row fat00_codfil="100" fat00_codven="71" fat00_datmov="2026-09-01" fat00_clides="Fisica" fat00_clityp="1" fat00_vlrperfat="100" fat00_vlrfatven="0" fat00_vlrdigven="0" fat00_vlrdigloc="0" fat00_vlrtotven="0" fat00_vlrcalven="10000000" fat00_vlrtotper="0" fat00_vlrtotlib="10000000"/>
		</estfatcvd00>
	</fat00>
	<ccv00>
		<fincaidat00>
			<row dat00_dattim="2026-09-01T17:06:25.623Z"/>
		</fincaidat00>
		<fincaiccv01>
			<row ccv01_codfil="1" ccv01_codven="71" ccv01_vlrsal="84.84" ccv01_vlrusedig="-98.02" ccv01_vlrusepck="0" ccv01_vlrsalatu="-13.18"/>
		</fincaiccv01>
	</ccv00>
	<sql00>
		<row sql00_cmdtyp="0" sql00_cmdsql="PRAGMA integrity_check;"/>
		<row sql00_cmdtyp="0" sql00_cmdsql="PRAGMA auto_vacuum(1);"/>
		<row sql00_cmdtyp="1" sql00_cmdsql="PRAGMA integrity_check;"/>
		<row sql00_cmdtyp="1" sql00_cmdsql="PRAGMA auto_vacuum(1);"/>
	</sql00>
</root>
```

---

## 3. Algoritmo de Parse e Atualização do Banco SQLite Local

O método responsável pelo processamento do arquivo no legado é o **`Tpckvenpac00List::importReturn(QString filename)`** (`usysvenpac00.cpp`). Ele executa a leitura em bloco dentro de uma transação atômica (`BEGIN TRANSACTION` / `COMMIT`), atualizando os bancos **`dbforcadig001.db`** (digitação) e **`dbforcacad001.db`** (cadastros estáticos).

### 3.1 Bloco `<ret00>`: Confirmação de Faturamento (Tabela `dig00`)
Para cada `<row>` de `<ret00>`, o aplicativo localiza o pedido pelas chaves `dig00_digfil` e `dig00_digcod`:

```sql
UPDATE dig00 SET
    dig00_sttenv = 3,                               -- pvddeRECEBIDO (Faturado/Confirmado)
    dig00_fatmov = '4677834',                       -- Número da Nota Fiscal gerada no ERP
    dig00_fatdat = '2026-09-01',                    -- Data de faturamento da Nota Fiscal
    dig00_fattot = 191.16,                          -- Valor total líquido faturado após eventuais cortes
    dig00_fatobs = '',                              -- Observações/inconsistências fiscais
    dig00_datret = CURRENT_DATE                     -- Timestamp da leitura do retorno
WHERE dig00_digfil = 1 AND dig00_digcod = 12;
```

### 3.2 Bloco `<ret01>`: Confirmação de Itens e Apuração de Cortes (Tabela `dig01`)
Para cada `<row>` de `<ret01>`, atualiza os valores oficiais faturados por item:

```sql
UPDATE dig01 SET
    dig01_fatqtd = 2.000,                           -- Quantidade física efetivamente faturada
    dig01_fatpco = 51.030                           -- Preço unitário homologado na Nota Fiscal
WHERE dig01_digfil = 1 AND dig01_digcod = 12 AND dig01_digitm = 1;
```

#### Regra de Negócio de Corte de Estoque:
O aplicativo executa o cálculo de corte em memória comparando a quantidade solicitada com a faturada:
\\[\text{Quantidade Cortada} = \text{dig01\_digqtd (Digitada)} - \text{dig01\_fatqtd (Faturada)}\\]
* Se \\(\text{Quantidade Cortada} > 0\\), o item é sinalizado como **Item com Corte**.
* O total cortado alimenta o filtro de auditoria de inconsistências do extrato (`ffrmdigvenrel00`).

### 3.3 Bloco `<ret03>`: Protocolo do Pacote (Tabela `pac00`)
Registra o protocolo oficial de recepção do ERP para o lote:

```sql
UPDATE pac00 SET
    pac00_sttenv = 2,                               -- pvpseRetornad (Lote retornado e confirmado)
    pac00_codlot = '73831'                          -- Protocolo da central
WHERE pac00_pacrep = 71 AND pac00_paccod = 1001;
```

### 3.4 Bloco `<pro00>`: Sincronização Delta de Estoque (Tabela `cadpro00`)
Atualiza instantaneamente o saldo físico das mercadorias no banco de cadastros (`dbforcacad001.db`) sem a necessidade de baixar uma carga completa:

```sql
UPDATE cadpro00 SET
    pro00_qtdest = 0.000
WHERE pro00_codigo = 19702 AND pro00_prifil = 1;

UPDATE cadpro00 SET
    pro00_qtdest = 15.000
WHERE pro00_codigo = 42424 AND pro00_prifil = 1;

UPDATE cadpro00 SET
    pro00_qtdest = 42.000
WHERE pro00_codigo = 43224 AND pro00_prifil = 1;
```
* **Impacto Comercial:** Impede imediatamente que o vendedor continue vendendo itens que esgotaram no centro de distribuição durante o dia.

### 3.5 Bloco `<cli00>`: Sincronização Delta de Limite de Crédito (Tabela `cadcli00`)
Atualiza a saúde financeira da carteira após o abatimento do faturamento:

```sql
UPDATE cadcli00 SET
    cli00_crelim = 2000.00,
    cli00_creatu = -132.47                          -- Limite estourado negativo
WHERE cli00_codigo = 9997;

UPDATE cadcli00 SET
    cli00_crelim = 0.00,
    cli00_creatu = 0.00
WHERE cli00_codigo = 21893;
```
* **Impacto Comercial:** Caso o cliente `9997` tente fazer um novo pedido no mesmo dia, o motor `usysvenblk00` identificará o limite negativo (`cli00_creatu < 0`) e bloqueará novas vendas a prazo.

### 3.6 Bloco `<fat00>`: Acompanhamento de Metas de Venda (`estfatcvd00`)
Atualiza os acumulados de faturamento por filial e tipo de pessoa (Física / Jurídica), alimentando a tela de metas (`ffrmrelfatcvd00`):
* Registra o timestamp da apuração na tabela `estfatdat00`.
* Atualiza a tabela `estfatcvd00` com os valores faturados (`fat00_vlrfatven`), cotas mínimas (`fat00_vlrcalven`) e limites de liberação (`fat00_vlrtotlib`).

### 3.7 Bloco `<ccv00>`: Saldo de Conta-Corrente / Verba do Vendedor (`fincaiccv01`)
Atualiza a verba de flexibilização de preços e descontos do vendedor (`ffrmrelccv00`):
* `ccv01_vlrsal`: Saldo anterior (`84.84`).
* `ccv01_vlrusedig`: Valor consumido em descontos concedidos (`-98.02`).
* `ccv01_vlrsalatu`: Saldo atual da conta-corrente do vendedor (`-13.18`).
* **Impacto Comercial:** Se o saldo estiver negativo (`ccv01_vlrsalatu < 0`), o vendedor perde a margem para conceder descontos adicionais nos próximos pedidos.

### 3.8 Bloco `<sql00>`: Manutenção Preventiva do SQLite Local
Instruções SQL diretas enviadas pelo DBA da central para otimizar os bancos de dados locais:
* **`sql00_cmdtyp="0"`:** Executa no banco de Cadastros (`dbforcacad001.db`).
* **`sql00_cmdtyp="1"`:** Executa no banco de Digitação (`dbforcadig001.db`).
* **Comandos Executados:**
  1. `PRAGMA integrity_check;`: Audita índices e integridade estrutural das páginas B-Tree do SQLite.
  2. `PRAGMA auto_vacuum(1);`: Reorganiza fisicamente os arquivos de banco no disco do smartphone para recuperar espaço livre após exclusões.

---

## 4. O que Acontece APÓS a Leitura do Arquivo (Regras Pós-Processamento)

Uma vez que todos os blocos do XML são persistidos com sucesso no SQLite, o sistema executa compulsoriamente os seguintes passos de encerramento:

### A. Handshake de Confirmação no FTP (`fcfRETPED = 11`)
* O aplicativo móvel **deve notificar o servidor FTP de que o arquivo de retorno foi recebido e processado com êxito**.
* A thread de sincronização dispara o comando de protocolo **`fcfRETPED = 11`** passando o nome do arquivo processado (`r71-1001.ret`).
* **Comportamento no Servidor FTP:** O servidor recebe o comando `11`, remove o arquivo `.ret` da fila ativa e move-o para a pasta de histórico/arquivados.
* **Idempotência Garantida:** Isso impede que nas sincronizações seguintes o aplicativo baixe e processe novamente o mesmo arquivo, evitando redundância de processamento.
* **Limpeza no Aparelho:** O arquivo temporário `r71-1001.ret` salvo em disco local é excluído (`QFile::remove`).

### B. Imutabilidade e Trava Definitiva do Pedido
* O pedido com status **`dig00_sttenv = 3` (`pvddeRECEBIDO`)** atinge o seu estado final e irreversível.
* Na interface do aplicativo móvel:
  * **Edição (`dopededt`):** Bloqueada definitivamente. O pedido não pode mais ter itens alterados.
  * **Exclusão (`dopeddel`):** Bloqueada definitivamente. O pedido não pode ser apagado do aparelho.
  * **Ações Permitidas:** Apenas **Consulta Detalhada (`dopedshw`)**, **Geração de PDF** e **Replicação de Pedido (`duplic`)** para um novo carrinho.

### C. Atualização Visual do Extrato de Vendas (`ffrmdigvenrel00`)
* O status do pedido na listagem passa de *"Transmitido"* para **`"Confirmado"`**.
* A grade de pedidos preenche as colunas oficiais:
  * **N° Fatura / NF:** Exibe o número fiscal retornado (`4677834`).
  * **Data Fat.:** Exibe a data de emissão (`2026-09-01`).
  * **Valor Fat.:** Exibe o valor líquido consolidado (`191.16`).
* Caso haja divergência entre o valor emitido (`dig00_digtot`) e o faturado (`dig00_fattot`), o botão de **Inconsistências / Cortes** é habilitado para que o vendedor consulte quais itens foram cortados pela central.

### D. Atualização do Espelho de Impressão / PDF
* O extrato em PDF do pedido deixa de estampar o aviso de *"Pedido Provisório em Análise"* e passa a exibir:
  * Cabeçalho: **"PEDIDO FATURADO - NOTA FISCAL N° 4677834"**.
  * Grade comparativa: Colunas com **Qtd. Solicitada** vs. **Qtd. Atendida (Faturada)**.

---

## 5. Dicionário de Mapeamento: XML de Retorno ➔ SQLite Local

| Tag / Bloco XML | Atributo no XML | Tabela SQLite | Coluna Alvo | Tipo | Ação / Regra de Negócio |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `<ret00>` | `dig00_digfil` | `dig00` | `dig00_digfil` | INTEGER | Chave primária da filial. |
| `<ret00>` | `dig00_digcod` | `dig00` | `dig00_digcod` | INTEGER | Chave primária do pedido no celular. |
| `<ret00>` | `dig00_fatmov` | `dig00` | `dig00_fatmov` | TEXT | Número da Nota Fiscal gerada no ERP. |
| `<ret00>` | `dig00_fatdat` | `dig00` | `dig00_fatdat` | DATE | Data de faturamento no ERP. |
| `<ret00>` | `dig00_fattot` | `dig00` | `dig00_fattot` | REAL | Valor total faturado líquido. |
| `<ret00>` | *(Automático)* | `dig00` | `dig00_sttenv` | INTEGER | Forçado para `3` (`pvddeRECEBIDO`). |
| `<ret01>` | `dig01_digitm` | `dig01` | `dig01_digitm` | INTEGER | Sequencial do item no carrinho. |
| `<ret01>` | `dig01_fatqtd` | `dig01` | `dig01_fatqtd` | REAL | Quantidade física faturada (apuração de corte). |
| `<ret01>` | `dig01_fatpco` | `dig01` | `dig01_fatpco` | REAL | Preço unitário final da Nota Fiscal. |
| `<ret03>` | `pac00_codlot` | `pac00` | `pac00_codlot` | TEXT | Protocolo de faturamento do lote no ERP. |
| `<ret03>` | *(Automático)* | `pac00` | `pac00_sttenv` | INTEGER | Forçado para `2` (`pvpseRetornad`). |
| `<pro00>` | `pro00_codpro` | `cadpro00`| `pro00_codigo` | INTEGER | Código do produto. |
| `<pro00>` | `pro00_qtdest` | `cadpro00`| `pro00_qtdest` | REAL | Saldo de estoque físico atualizado da filial. |
| `<cli00>` | `cli00_codigo` | `cadcli00`| `cli00_codigo` | INTEGER | Código do cliente. |
| `<cli00>` | `cli00_crelim` | `cadcli00`| `cli00_crelim` | REAL | Limite total de crédito aprovado. |
| `<cli00>` | `cli00_creatu` | `cadcli00`| `cli00_creatu` | REAL | Limite líquido disponível atualizado. |
| `<fat00>` | Vários | `estfatcvd00` | `fat00_*` | Múltiplos | Acumulados de metas de vendas. |
| `<ccv00>` | `ccv01_vlrsalatu` | `fincaiccv01` | `ccv01_vlrsalatu` | REAL | Saldo atual da conta-corrente do vendedor. |
| `<sql00>` | `sql00_cmdsql` | *(Direto)* | Scripts SQL | DDL/DML | Execução direta de PRAGMAs de integridade. |
