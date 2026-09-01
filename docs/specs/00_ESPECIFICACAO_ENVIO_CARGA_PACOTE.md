# ESPECIFICAÇÃO TÉCNICA E REGRAS DE NEGÓCIO: ENVIO DE CARGA E TRANSMISSÃO DE PACOTES (FTP)

Esta especificação técnica detalha todas as regras de negócio, rotinas de compactação, códigos legados em C++/Qt, nomenclatura de arquivos e a máquina de estados completa envolvida no processo de **geração, empacotamento, envio e confirmação de leitura** das vendas e cargas de dados entre a aplicação móvel de Força de Vendas (FV) e o servidor FTP da retaguarda (ERP).

---

## 1. Distinção Conceitual: Envio de Pacote (Upload) vs. Carga de Dados (Download)

No jargão operacional do vendedor em campo, a expressão *"enviar carga"* refere-se ao ato de descarregar e transmitir os pedidos fechados para a central. Na arquitetura técnica do sistema legado, existem dois fluxos distintos e complementares:

```
    ┌────────────────────────────────────────────────────────────────────────┐
    │                            SERVIDOR FTP / ERP                          │
    └──────────────────┬──────────────────────────────────▲──────────────────┘
                       │                                  │
      (1) DOWNLOAD CARGA (.crg / .7z)       (2) UPLOAD PACOTE VENDAS (.pac)
          fcfGETCRG = 3                         fcfPUTPED = 8
                       │                                  │
                       ▼                                  │
    ┌─────────────────────────────────────────────────────┴──────────────────┐
    │                      APLICAÇÃO MÓVEL - FORÇA DE VENDAS                 │
    │  dbforcacad001.db (Cadastros)            dbforcadig001.db (Digitação)  │
    └────────────────────────────────────────────────────────────────────────┘
```

1. **Upload de Vendas (Envio de Pedidos / Lotes):** Agrupamento dos pedidos fechados em formato XML, compactação em lote compactado padrão ZIP com extensão proprietária **`.pac`**, upload via FTP (`fcfPUTPED = 8`) para o diretório remoto `dirPAC`.
2. **Download de Carga (Carga de Cadastros):** Baixa da base consolidada de clientes, produtos, preços e títulos (`dbforcacad001.db` ou `dbforcacad001.crg`/`.7z`) gerada pela retaguarda via parâmetro `fcfGETCRG = 3` no diretório remoto `dirCRG`.
3. **Retorno de Processamento (Confirmação de Leitura):** O ERP lê o pacote `.pac`, processa as vendas e gera um arquivo de retorno. O app busca esses retornos via `fcfGETRET = 6` e confirma a leitura com `fcfRETPED = 11`.

---

## 2. Processo de Geração e Serialização XML dos Pedidos

Antes da compactação, os pedidos com status de faturamento local concluído (`pvddsDIGITADO`) e pendentes de envio (`pvddeDIGITADO`) são reunidos em um único documento XML em memória estruturado pela biblioteca Qt `QDomDocument`.

### Estrutura do XML Gerado (`addPACSourceXML`)
O método `TGerPacvendig00::addPACSourceXML(QDomDocument xmlPAC, QDomElement xmlRoot)` serializa o cabeçalho do pedido (`dig00`) e seus respectivos itens (`dig01`):

```xml
<?xml version="1.0" encoding="UTF-8"?>
<root>
    <pedido>
        <dig00_digfil>1</dig00_digfil>
        <dig00_digcod>1007</dig00_digcod>
        <dig00_clicod>1542</dig00_clicod>
        <dig00_clides>MERCADO EXEMPLO LTDA</dig00_clides>
        <dig00_lincod>10</dig00_lincod>
        <dig00_placod>1</dig00_placod>
        <dig00_digagt>5</dig00_digagt>
        <dig00_digcob>1</dig00_digcob>
        <dig00_digtot>1500.50</dig00_digtot>
        <dig00_subtot>120.30</dig00_subtot>
        <dig00_destot>0.00</dig00_destot>
        <dig00_bontot>0.00</dig00_bontot>
        <dig00_datsys>2026-09-01</dig00_datsys>
        <itens>
            <item>
                <dig01_digitm>1</dig01_digitm>
                <dig01_digpro>78945</dig01_digpro>
                <dig01_digqtd>10.0</dig01_digqtd>
                <dig01_digpco>150.05</dig01_digpco>
                <dig01_subtot>12.03</dig01_subtot>
                <dig01_destot>0.00</dig01_destot>
            </item>
        </itens>
    </pedido>
</root>
```

---

## 3. Mecanismo de Compactação e Código-Fonte Legado

### 3.1 Como é feita a Compactação
1. O documento XML estruturado com a listagem de pedidos é salvo temporariamente no sistema de arquivos local (`Tsysfun::CPathPAC()`).
2. O sistema aciona a classe utilitária de compactação **`Tsyscompress`** (declarada em `moc_usyscompress.cpp` / biblioteca `libsw`).
3. A rotina cria um arquivo compactado sob a especificação padrão **ZIP**.
4. **Renomeação mandatória:** O arquivo compactado **não** recebe a extensão `.zip`. Ele é gravado e renomeado diretamente com a extensão proprietária **`.pac`** (Pacote de Vendas) para que a retaguarda identifique o lote como um arquivo íntegro de faturamento externo.

### 3.2 Código Legado de Empacotamento (`ffrmdiggerpac00.cpp` / `usysvenpac00.cpp`)

Abaixo é reproduzida a lógica do método `doIncludePAC` responsável pela consolidação e disparo da compressão:

```cpp
// Extraído de ffrmdiggerpac00.cpp e usysvenpac00.cpp
bool TGerPacvendig00List::doIncludePAC(QString &message) 
{
    if (!this->doIncludePACCheck(message)) {
        return false;
    }

    // 1. Inicialização do Documento XML do Pacote
    TSYSStringList *pedList = new TSYSStringList();
    QDomDocument xmlPAC("suportware");
    QDomElement xmlRoot = xmlPAC.createElement("root");
    xmlPAC.appendChild(xmlRoot);

    // 2. Coleta dos Pedidos Selecionados para o Lote
    int pacqtd = 0;
    for (int i = 0; i < this->List.count(); ++i) {
        TGerPacvendig00 *ped = this->List.at(i);
        if (ped->checked) {
            // Serializa os nós <pedido> e <itens>
            ped->addPACSourceXML(xmlPAC, xmlRoot);
            pedList->add(QString::number(ped->dig00_digcod));
            pacqtd++;
        }
    }

    // 3. Obtenção do Sequencial do Pacote e Nomenclatura
    int codrep = this->cadrep00.ven00_codigo;
    int iseq   = this->cadrep00.getPacSeq(); // Sequencial incremental (ex: 1001)
    
    // Nomenclatura oficial: p<codRep>-<sequencial>.xml temporário
    QString xmlFileName = QString("p%1-%2.xml").arg(codrep).arg(iseq);
    QString pacFileName = QString("p%1-%2.pac").arg(codrep).arg(iseq);
    
    QString xmlFilePath = sysfun.CPathPAC(xmlFileName);
    QString pacFilePath = sysfun.CPathPAC(pacFileName);

    // 4. Gravação do arquivo XML em disco temporário
    QFile fileXML(xmlFilePath);
    if (fileXML.open(QIODevice::WriteOnly | QIODevice::Text)) {
        QTextStream stream(&fileXML);
        stream << xmlPAC.toString();
        fileXML.close();
    }

    // 5. Chamada da Compactação ZIP via Tsyscompress
    Tsyscompress compress;
    // Compacta o arquivo pXXX-YYYY.xml gerando pXXX-YYYY.pac (formato ZIP físico)
    bool compactadoComSucesso = compress.zipFile(xmlFilePath, pacFilePath);

    if (compactadoComSucesso) {
        // Remove o XML temporário descompactado
        QFile::remove(xmlFilePath);

        // 6. Registro do Lote na Tabela Local pac00
        Tpckvenpac00 pac;
        pac.pac00_pacrep = codrep;
        pac.pac00_paccod = iseq;
        pac.pac00_pacsrc = pacFileName;
        pac.pac00_pacdat = QDate::currentDate();
        pac.pac00_pacqtd = pacqtd;
        pac.pac00_sttpac = pvpspNEnviado; // 0 = Gerado, não enviado
        pac.pac00_sttenv = pvpseNEnviado; // 0 = Pendente de envio
        pac.cpost(); // Persiste no SQLite local

        // 7. Atualização do Status dos Pedidos para 'EMPACOTADO'
        for (int i = 0; i < this->List.count(); ++i) {
            TGerPacvendig00 *ped = this->List.at(i);
            if (ped->checked) {
                // Bloqueia edição no dispositivo móvel
                Tsyssql::exec(QString("UPDATE dig00 SET dig00_sttenv = 1 WHERE dig00_digcod = %1")
                              .arg(ped->dig00_digcod));
            }
        }
        return true;
    }
    return false;
}
```

---

## 4. Nomenclatura Oficial dos Arquivos

A nomenclatura de arquivos de transmissão e recepção segue máscaras fixas e padronizadas no sistema legado:

| Tipo de Arquivo | Extensão | Máscara de Nomenclatura | Exemplo Real | Função Geradora | Diretório FTP |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Pacote de Vendas (Upload)** | **`.pac`** | `p<codRep>-<seqPacote>.pac` | `p105-1001.pac` | `Tpckvenpac00::filePAC()` | `dirPAC` (`svr00_dirpac`) |
| **Cadastro Novo Cliente (Upload)** | **`.xml`** | `c<codRep>-<milissegundos>.xml` | `c105-1682930.xml` | `Cliente::fileCAD()` / `retornaMil()` | `dirCAD` / `dirCLI` (`svr00_dircad`) |
| **Localização / GPS Cliente (Upload)**| **`.xml`** | `c<codRep>-<codigo16Cliente>.xml` | `c105-0000000000001542.xml` | `Cliente::fileLOC()` | `dirCAD` / `dirCLI` |
| **Recados / Não-Venda (Upload)** | **`.xml`** | `m<codRep>-<seqMensagem>.xml` | `m105-0042.xml` | `Tpckvenmsg00::fileMSG()` | `dirMSG` (`svr00_dirmsg`) |
| **Carga de Cadastros (Download)** | **`.crg`** ou **`.7z`**| `dbforcacad001.crg` | `dbforcacad001.crg` | Retaguarda ERP | `dirCRG` (`svr00_dircrg`) |
| **Retorno de Processamento (Download)**| **`.ret`** ou **`.xml`**| `r<codRep>-<seqPacote>.ret` | `r105-1001.ret` | Retaguarda ERP | `dirPAC` |

*Nota sobre o Sequencial (`seqPacote`):* O número incremental do pacote é mantido no cadastro do vendedor no SQLite local (`txtven00_pacseq`). Ele inicia em `1000` e é incrementado linearmente até `9999`. Caso atinja o teto, é reiniciado em `1000`.

---

## 5. Máquina de Estados e Ciclo de Vida dos Status

O ciclo de vida de uma venda possui duas camadas de controle de status no banco SQLite local (`dbforcadig001.db`):
1. **Status de Faturamento Local (`dig00_sttdig` / `Tpckvendig00SttDIG`):** Monitora a edição do carrinho.
2. **Status de Transmissão e Envio (`dig00_sttenv` / `Tpckvendig00SttENV`):** Monitora a sincronização FTP com a central.
3. **Status do Pacote (`pac00_sttpac` e `pac00_sttenv` / `Tpckvenpac00StatePAC` / `Tpckvenpac00StateENV`):** Monitora o lote comprimido.

```
                    MÁQUINA DE ESTADOS DO PEDIDO DE VENDA:

   [Abertura do Pedido]
             │
             v
     sttdig = pvddsEDITANDO (0)
     sttenv = pvddeDIGITADO (0)
             │
             ├───> [doPEDAbort()] ➔ Carrinho descartado / Expurgo local
             │
             v (Concluir Venda / cpost)
     sttdig = pvddsDIGITADO (1)  [Venda salva no banco local]
     sttenv = pvddeDIGITADO (0)  [Pendente de empacotamento]
             │
             v (doIncludePAC / Compactação ZIP ➔ .pac)
     sttenv = pvddeEMPACOTE (1)  [AO ENVIAR: Travado no grid local]
             │
             v (TsysSyncronizeFTP::doFTPFilePut com sucesso)
     sttenv = pvddeENVIADOS (2)  [APÓS O ENVIO: Upload concluído no FTP]
             │
             v (fcfGETRET / importReturn - Retaguarda processou o lote)
     sttenv = pvddeRECEBIDO (3)  [LIDO PELO SISTEMA: Faturado / Confirmado]
```

### 5.1 Tabela Comparativa de Estados

| Fase Operacional | Status do Pedido (`dig00_sttenv`) | Status do Pacote (`pac00_sttenv`) | Descrição e Regra de Negócio |
| :--- | :--- | :--- | :--- |
| **Rascunho Local** | `pvddeDIGITADO = 0` | *(Sem pacote ainda)* | Pedido em digitação ou recém-salvo localmente. Aberto para edição ou exclusão física. |
| **Ao Empacotar / Ao Enviar** | `pvddeEMPACOTE = 1` | `pvpseNEnviado = 0` | O pedido foi serializado em XML e compactado no arquivo `.pac`. **Trava de integridade:** O pedido é bloqueado contra edição ou cancelamento no app móvel. |
| **Após o Envio (Sucesso FTP)**| `pvddeENVIADOS = 2` | `pvpseJEnviado = 1` | O arquivo `.pac` foi completamente transmitido para o diretório remoto `dirPAC`. A confirmação física do socket FTP dispara o commit no banco local. |
| **Lido pelo Sistema (Retaguarda)**| `pvddeRECEBIDO = 3` | `pvpseRetornad = 2` | O ERP central descompactou o `.pac`, importou os pedidos e gerou o arquivo de retorno (`.ret`). O app processou o retorno via `importReturn()`. |

---

## 6. Tratamento de Concorrência, Falhas de Rede e Idempotência

1. **Garantia de Idempotência:**
   * Cada arquivo `.pac` possui um identificador unívoco (`p<codRep>-<seq>.pac`).
   * Caso o processo de envio seja interrompido por oscilação de sinal 3G/4G/Wi-Fi antes do encerramento da chamada FTP, o arquivo temporário incompleto no servidor é descartado.
   * O aplicativo **não atualiza** o status para `pvddeENVIADOS (2)` em caso de falha de conexão; os pedidos permanecem como `pvddeEMPACOTE (1)` ou retornam para a fila de envio. Na próxima tentativa de sincronização, o pacote existente é retransmitido sem regerar novos números de pedidos nem duplicar vendas na central.
2. **Confirmação Atômica de Envio:**
   * A alteração de status para `pvddeENVIADOS` e `pvpseJEnviado` é disparada **exclusivamente no evento `FTPTranferCompleted()`** do componente `Tsysftp`.
3. **Confirmação de Leitura pelo Sistema Central (`fcfRETPED = 11`):**
   * A cada sincronização, o aplicativo consulta a pasta remota em busca de arquivos de retorno de vendas (`fcfGETRET = 6`).
   * Ao encontrar o arquivo de retorno correspondente ao lote, o método `Tpckvenpac00List::importReturn(QString filename)` lê as respostas fiscais da retaguarda (ex: número da Nota Fiscal gerada, protocolo do pedido no ERP ou inconsistências de crédito).
   * O status do pedido transita definitivamente para `pvddeRECEBIDO (3)`, e o aplicativo emite um comando `fcfRETPED = 11` para sinalizar ao servidor que o retorno foi importado com sucesso, permitindo que a retaguarda arquive o lote.

---

## 7. Rastreabilidade dos Fontes Legados

* **`ffrmdiggerpac00.h` / `ffrmdiggerpac00.cpp`:** Interface de geração de pacotes, métodos `doIncludePAC()`, `addPACSourceXML()` e carregamento de pedidos pendentes via `cload(pvddeDIGITADO)`.
* **`usysvenpac00.h` / `usysvenpac00.cpp`:** Estrutura da entidade de controle de lotes `Tpckvenpac00`, enumeradores `Tpckvenpac00StatePAC` e `Tpckvenpac00StateENV`, e método `filePAC()`.
* **`usysvenenu00.h`:** Definição canônica dos enumeradores de ciclo de vida `Tpckvendig00SttDIG` e `Tpckvendig00SttENV`.
* **`usyswebutil.h` / `usyswebutil.cpp`:** Orquestrador multithread de sincronização (`TsysSyncronize`), constantes de protocolo `TParamWriteFunc` (`fcfPUTPED = 8`, `fcfGETCRG = 3`, `fcfPUTCAD = 10`, `fcfRETPED = 11`).
* **`usysweb.h` / `usysweb.cpp`:** Cliente `TsysSyncronizeFTP`, manipulação de soquetes FTP e upload físico `doFTPFilePut()`.
* **`cliente.cpp`:** Métodos de geração de arquivos cadastrais diretos `fileCAD()` e `fileLOC()`.
