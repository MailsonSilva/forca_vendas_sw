# ESPECIFICAÇÃO TÉCNICA E DE REGRAS DE NEGÓCIO: MÓDULO DE SINCRONIZAÇÃO E COMUNICAÇÃO (FTP/OFFLINE-FIRST)

Este documento detalha as especificações funcionais, regras de integridade transacional, regras de empacotamento offline e protocolos de comunicação via FTP para o faturamento móvel. O objetivo é fornecer o PRD e o mapeamento das regras de negócio do sistema legado de Força de Vendas (FV) para orientar a reconstrução nativa e reativa do módulo de sincronização no Flutter.

---

## 1. Fluxo de Carga (Download de Cadastros: ERP ➔ App)

A sincronização de download de dados do ERP (retaguarda) para o aplicativo móvel é totalmente orquestrada pela thread de comunicação em segundo plano **`TsysSyncronize`** (e sua subclasse de transporte **`TsysSyncronizeFTP`**), garantindo que as operações de download e processamento de dados ocorram sem bloquear a linha de execução principal (UI Thread).

```
FLUXO DE CARGA (DOWNLOAD - OFFLINE-FIRST)

  [Servidor Central ERP] ─── (Gera arquivos estáticos de carga)
                                       │
                                       v
  [Aplicativo Móvel] ─────── (Solicita carga via fcfGETCRG = 3)
                                       │
                                       v
                             (Download do Banco SQLite)
                    dbforcacad001.db  ou  dbforcacad001.7z (dirCRG)
                                       │
                    ┌──────────────────┴──────────────────┐
                    ▼                                     ▼
        [Banco de Cadastros]                    [Banco de Digitação]
         dbforcacad001.db                        dbforcadig001.db
       (TRUNCATE / Sobrescrita)                (PRESERVADO / Intocado)
                    │
         (Ordem de Carga Rígida)
```

### A. Solicitação e Download dos Arquivos
1.  **Gatilho de Sincronia:** O processo é iniciado manualmente pelo vendedor na interface de conexão (`ffrmconnect01`) ou de forma automática em intervalos programados na inicialização do aplicativo.
2.  **Solicitação de Carga (`fcfGETCRG = 3`):** O aplicativo envia um sinal ao servidor FTP da retaguarda com a constante parametrizada `fcfGETCRG` solicitando a consolidação das últimas tabelas comerciais para aquele código de vendedor.
3.  **Transporte Físico:** O cliente FTP baixa o arquivo consolidado de banco de dados do diretório remoto mapeado na variável **`dirCRG`**. O arquivo pode ser transferido como o banco estático cru **`dbforcacad001.db`** ou compactado no formato ZIP/7z (**`dbforcacad001.7z`**) para otimizar o consumo de pacotes de dados móveis do representante comercial.

### B. Isolamento e Limpeza de Bancos Locais (Offline-First)
Para manter a total resiliência offline do faturamento, o aplicativo opera com dois arquivos físicos de banco de dados SQLite distintos:
1.  **`dbforcacad001.db` (Banco de Cadastros):** Armazena as tabelas estáticas de consulta (clientes, produtos, tabelas de preço, prazos, títulos e limites comerciais).
2.  **`dbforcadig001.db` (Banco de Digitação):** Armazena as tabelas transacionais de escrita (pedidos faturados, rascunhos em digitação, logs de visita, etc.).

*   **Regra de Limpeza de Dados:** Durante a carga, o sistema realiza uma limpeza total (**`TRUNCATE` / Sobrescrita física**) no arquivo **`dbforcacad001.db`**, apagando todos os registros comerciais estáticos anteriores para dar espaço à nova tabela de preços e limite rotativo atualizado do cliente.
*   **Regra de Preservação de Transações:** O banco de escrita local **`dbforcadig001.db`** permanece **totalmente intocado**. Pedidos locais com status "Em Digitação" (rascunhos) ou pendentes de sincronização são blindados contra qualquer sobrescrita, evitando perdas de vendas em andamento.

### C. Ordem Rígida de Importação e Integridade Referencial
Para garantir que as dependências lógicas de faturamento não sejam violadas no banco local do celular, as tabelas estáticas em `dbforcacad001` são povoadas seguindo uma ordem linear rígida de importação:
1.  **Vendedor (`cadrep00`):** Configurações locais de regras, limites e permissões de faturamento.
2.  **Condições de Pagamento (`cadpla00`):** Planos comerciais de faturamento liberados.
3.  **Agentes Cobradores (`codage00`):** Lista de bancos e carteiras faturadoras ativas.
4.  **Produtos (`cadpro00` e `cadproemb02`):** Catálogo de mercadorias, saldos de estoque por filial e multiplicadores de caixas closed-pack.
5.  **Clientes (`cadcli00`):** Carteira autorizada para atendimento offline.
6.  **Títulos e Recebíveis (`dup00`):** Duplicatas em aberto para cálculo offline de atrasos e inadimplência.
7.  **Histórico Financeiro (`ESTFATCVD00Record`):** Histórico de faturamentos anteriores para acompanhamento de pós-venda.

---

## 2. Fluxo de Descarga / Envio (Upload de Pedidos e Fichas: App ➔ ERP)

```
FLUXO DE DESCARGA (UPLOAD - PROCESSAMENTO SUCESSIVO)

   [SQLite Local de Digitação] (dig00_sttenv = 0: Pronto)
               │
               ▼
     [Serialização XML] ───> Geração do XML de faturamento do pedido
               │
               ▼
     [Compactação ZIP] ───> Envelopamento e codificação fisica para ZIP
               │
               ▼
     [Renomeação .pac] ───> Geração física com o sufixo sequencial local:
                             p<Representante>-<NSequencialPacote>.pac
               │
               ▼
     [Transmissão FTP] ───> Upload do .pac via fcfPUTPED = 8 para dirPAC
               │
     ┌─────────┴─────────┐
     ▼                   ▼
 [Upload SUCESSO]    [Upload FALHOU]
 (FTP OK / Sem Erro)   (Queda de Rede)
     │                   │
     ▼                   ▼
 [Commit Transacional] [Rollback de Envio]
 UPDATE dig00          Pedidos voltam para
 SET sttenv = 2        a fila de envio local
 (JEnviado)            (sttenv = 0)
```

### A. Empacotamento e Geração do XML de Vendas
Quando os pedidos são faturados, o motor de pacotes da classe **`TGerPacvendig00List`** varre o banco localSQLite buscando registros aptos para exportação (status de transmissão do cabeçalho **`dig00_sttenv = 0`** - pronto para envio).

Para cada pedido, o método **`addPACSourceXML`** converte reativamente os registros em um documento XML estruturado:
```xml
<?xml version="1.0\" encoding=\"UTF-8\"?>
<PacoteVendas>
    <Representante>
        <Codigo>105</Codigo>
    </Representante>
    <Pedido>
        <Cabecalho>
            <CodigoPedido>10254</CodigoPedido>
            <CodigoCliente>1542</CodigoCliente>
            <FilialFaturamento>1</FilialFaturamento>
            <DataEmissao>2026-08-27</DataEmissao>
            <CondicaoPagamento>15</CondicaoPagamento>
            <AgenteCobrador>1</AgenteCobrador>
            <ValorLiquido>1250.40</ValorLiquido>
            <ValorST>45.20</ValorST>
        </Cabecalho>
        <Itens>
            <Item>
                <Sequencial>1</Sequencial>
                <CodigoProduto>78945</CodigoProduto>
                <Quantidade>10.0</Quantidade>
                <PrecoPraticado>125.04</PrecoPraticado>
                <DescontoAplicado>0.00</DescontoAplicado>
            </Item>
        </Itens>
    </Pedido>
</PacoteVendas>
```

### B. Compactação e a Extensão `.pac`
1.  **Compressão:** O conteúdo serializado em XML é transformado em um fluxo de bytes e processado pela classe utilitária de compactação **`Tsyscompress`**. O sistema gera um arquivo compactado sob a tecnologia **ZIP**.
2.  **Extensão Personalizada:** Para manter a integridade fiscal, evitar interceptações e assegurar que o arquivo só seja aberto pelo ERP correspondente, o arquivo físico ZIP gerado é renomeado no disco do celular com a extensão exclusiva **`.pac`** (Pacote de Vendas).
3.  **Nomenclatura Sequencial de Pedidos:** Ao contrário de cadastros simples de novos clientes (que usam marcas temporais `retornaMil()` para evitar concorrências), os pacotes de pedidos de venda (`.pac`) utilizam um **contador numérico sequencial curto e incremental do próprio banco local** (`pck_codigo` ou número do lote de envio daquele celular).
    *   **Padrão das Vendas (`.pac`):** `p<codigoRepresentante>-<numeroSequencialLote>.pac`
    *   *Exemplos:* `p105-32504.pac`, `p105-32505.pac` (sequência de envios curtos).
4.  **Destino FTP:** O arquivo `.pac` é transmitido via comando **`fcfPUTPED = 8`** diretamente para a pasta faturadora mapeada no servidor FTP sob a variável **`dirPAC`**.

### C. Nomenclatura e Envio de Cadastros de Novos Clientes (`.xml` cru)
Os cadastros ou atualizações de fichas cadastrais de clientes novos efetuadas em campo não sofrem compactação `.pac`. São exportados como XMLs planos e enviados diretamente para processamento administrativo:
1.  **Novos Clientes (Método `fileCAD()`):** Usa milissegundos curtos do sistema para garantir que nomes nunca colidam na pasta de recepção de cadastros:
    *   *Padrão:* `c<codigoRepresentante>-<retornaMil()>.xml` (Ex: `c105-89302.xml`)
2.  **Atualização de Cliente Existente (Método `fileLOC()`):** Usa a identificação cadastral de 16 caracteres gerada para o cliente:
    *   *Padrão:* `c<codigoRepresentante>-<codigo16>.xml` (Ex: `c105-0000000000001542.xml`)
3.  **Destino FTP:** Transmitidos via comando **`fcfPUTCAD = 10`** para os diretórios remotos de cadastros **`dirCAD`** ou **`dirCLI`**.

### D. Garantia de Idempotência e Atualização de Status
Para evitar faturamentos duplicados na central por oscilações ou falhas na transmissão FTP, o sistema legado aplica as seguintes travas funcionais:

1.  **Bloqueio de Edição Intermediário (Status = Empacotado):**
    Assim que o vendedor inicia a sincronização, os cabeçalhos dos pedidos inclusos no lote têm o status de digitação local atualizado temporariamente de Pronto (`dig00_sttdig = 1`) para Empacotado (**`dig00_sttenv = 1`** ou `pvddeEMPACOTE`). Isso bloqueia qualquer tentativa de exclusão do pedido ou edição dos itens no grid móvel durante o upload.
2.  **Rastreamento Atômico dos IDs em Memória:**
    O motor de sincronização retém em um vetor na memória RAM (`List` ou `QVector<int>`) a listagem exata dos IDs dos pedidos contidos no arquivo `.pac` em andamento.
3.  **Confirmação do Upload e Commit Físico:**
    O aplicativo faz o upload do `.pac`. A alteração do status para enviado no banco de dados local **só ocorre após a confirmação absoluta de sucesso do protocolo FTP (Upload 100% concluído)** de gravação física do arquivo no diretório remoto.
    Após a resposta positiva do servidor FTP, a thread dispara uma query de atualização atômica no SQLite local:
    ```sql
    UPDATE dig00 
    SET dig00_sttenv = 2 -- Status "Transmitido / JEnviado" (pvddeENVIADOS)
    WHERE dig00_digcod IN (<lista_de_ids_rastreados_em_memoria>);
    ```
    Isso impede que interrupções de conexão deixem o pedido no limbo, garantindo que o faturamento local só mude para enviado se o arquivo foi recebido na íntegra na retaguarda.

---

## 3. Tratamento de Concorrência, Rede e Falhas (Offline-First)

A arquitetura do módulo de comunicação foi concebida sob os princípios de resiliência e estabilidade da operação móvel externa de vendas:

### A. Execução Assíncrona e Isolada
*   **Comunicação em Thread Dedicada:** A classe de sincronização herda de **`QThread`**, operando em um canal de execução paralelo e isolado da UI Thread.
*   **Digitação e Vendas Simultâneas:** O vendedor pode abrir a Central de Vendas, consultar estoques cadastrados no banco `dbforcacad001` e faturar novos pedidos mesmo com a thread de sincronização ativa rodando uploads e downloads em segundo plano. Não há travamento de banco ou bloqueio de escrita móvel.

### B. Monitoramento e Detecção Ativa de Sinal (Rede)
*   **Detecção de Interfaces de Conexão:** Antes de acionar qualquer comando de soquete ou chamada FTP, o sistema legado avalia as configurações de rede ativas no smartphone utilizando a classe de gerenciamento de sessões físicas de soquetes (`QNetworkSession` e `QNetworkConfigurationManager`).
*   **Tratamento de Conexão Indisponível:** Se o aparelho não possuir nenhuma rede WiFi ou de dados móveis ativa, a thread impede as chamadas de conexão FTP e entra em estado de hibernação, emitindo apenas mensagens amigáveis na central e mantendo os pacotes de vendas na fila de transmissão do aparelho.

### C. Tratamento de Timeouts, Retries e Quedas de Conexão
*   **Timeouts Estritos de Envio:** O aplicativo configura timeouts estritos para as operações de handshake, login de usuário FTP no servidor (`svr00_svuser` / `svr00_svpass`) e transferência de pacotes. Se o tempo limite for atingido por lentidão ou instabilidade de rede móvel (2G/3G), a conexão é abortada sumariamente.
*   **Protocolo de Descarte de Resíduos Remotos:** No momento em que uma transmissão é interrompida por queda física de sinal antes de completar 100% do envio, o cliente FTP descarta o buffer residual enviado de forma a não deixar arquivos corrompidos na pasta do FTP.
*   **Rollback de Envio Local (Recuperação Automática):** Se ocorrer uma queda de internet antes da confirmação de upload do arquivo `.pac`, a transação de commit local é abortada. Os pedidos mantidos no vetor em memória retornam para o status pronto para envio (**`dig00_sttenv = 0`**), liberando o botão de sincronização e permitindo que eles entrem automaticamente na fila do próximo ciclo de upload, com total integridade dos dados e sem perdas financeiras.

---

## 4. Recomendações Técnicas para a Implementação no Flutter

Para replicar com segurança e máxima performance esta robusta arquitetura offline-first no Flutter, adote as seguintes práticas recomendadas de engenharia:

### A. Persistência de Dados e Threading
*   **Banco Local com Drift (SQLite) ou Sqflite:** Utilize o plugin **Drift** de forma reativa. O Drift gera código fortemente tipado para as tabelas de cadastros (`cadpro00`, `cadcli00`) e movimentos (`dig00`, `dig01`), oferecendo execução nativa assíncrona por meio de isolados do Dart (Background Isolates), o que evita qualquer gargalo de renderização na interface durante a inserção de produtos ou processamento de arquivos.

### B. Empacotamento Reativo de Vendas em Dart
*   **Biblioteca `archive` para Compactação ZIP:** No Flutter, você pode gerar a string XML do faturamento local e utilizar a biblioteca **`archive`** para realizar a compactação do XML em formato ZIP em memória, salvando o arquivo resultante localmente com a extensão `.pac` de forma extremamente rápida.
*   **Idempotência com Records do Dart 3:** Retorne um Record `(File arquivoPac, List<int> idsPedidos)` da sua camada de geração de pacotes. Passe esses parâmetros para o serviço de FTP. Somente após a Promise de upload do arquivo finalizar com sucesso no servidor remoto, execute a query de atualização do status do lote no SQLite local.

### C. Protocolo de Comunicação Confiável
*   **Uso de `ftpconnect`:** Utilize a biblioteca **`ftpconnect`** ou similar em Flutter para controlar as conexões FTP assíncronas de forma segura. Ela já possui suporte nativo a timeouts de conexão, monitoramento ativo do progresso de envio de bytes (para atualizar barras de progresso na interface) e fechamento íntegro de soquetes, facilitando o gerenciamento do ciclo de vida da sincronização de faturamento.
