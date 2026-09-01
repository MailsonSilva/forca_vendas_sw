# ESPECIFICAÇÃO TÉCNICA E REGRAS DE NEGÓCIO: ENVIO DE CARGA E TRANSMISSÃO DE PACOTES SEM COMPRESSÃO (XML DIRETO / .PAC) - V2

Esta especificação técnica atualizada detalha as regras de negócio, o fluxo de geração direta em XML, a remoção completa da rotina de compressão (sem ZIP), a rotina de renomeação de arquivos, a nomenclatura oficial e a máquina de estados completa envolvida no processo de **geração, empacotamento, envio e confirmação de leitura** das vendas entre a aplicação móvel de Força de Vendas (FV) e o servidor FTP da retaguarda (ERP).

---

## 1. Visão Geral da Arquitetura sem Compressão

No fluxo tradicional legado com compressão, o XML era gerado em disco temporário, compactado via utilitário ZIP (`Tsyscompress`) gerando um arquivo binário renomeado com a extensão `.pac`.

Na arquitetura **sem compressão**, a etapa de compactação ZIP é **completamente eliminada**:
1. Os dados de vendas finalizados (`dig00` e `dig01`) são reunidos e serializados diretamente na estrutura canônica de XML com atributos.
2. O arquivo é gerado em texto puro UTF-8 e **renomeado/salvo diretamente com a extensão de pacote `.pac`** (`p<codRep>-<seq>.pac`), mantendo seu conteúdo como **XML em texto claro**.
3. O servidor FTP recebe o arquivo `.pac` textual diretamente na pasta `dirPAC`, simplificando o tráfego, eliminando dependências de descompactação e prevenindo corrupções de arquivos binários em redes móveis de baixa estabilidade.

```
                  FLUXO DE TRANSMISSÃO DIRETA (SEM COMPRESSÃO):

   ┌───────────────────────────┐
   │ Pedidos Fechados (SQLite) │
   │   (dig00 / dig01 / pac00) │
   └─────────────┬─────────────┘
                 │
                 ▼
   ┌───────────────────────────┐
   │    Serialização do XML    │  Formato em texto claro com atributos XML
   │    (QDomDocument / Dart)  │  <!DOCTYPE suportware><root>...
   └─────────────┬─────────────┘
                 │
                 ▼
   ┌───────────────────────────┐
   │   Gravação e Renomeação   │  Grava o XML e renomeia/gera diretamente
   │     Direta para .pac      │  como p<codRep>-<seq>.pac (SEM PASSAGEM POR ZIP)
   └─────────────┬─────────────┘
                 │
                 ▼
   ┌───────────────────────────┐
   │    Upload FTP (Texto Puro)│  Upload via FTP (fcfPUTPED = 8)
   │        pasta dirPAC       │  para o diretório remoto do servidor
   └─────────────┬─────────────┘
                 │
                 ▼
   ┌───────────────────────────┐
   │    Confirmação do ERP     │  Retaguarda lê o XML direto no .pac
   │   (r<codRep>-<seq>.ret)   │  e emite retorno de confirmação de leitura
   └───────────────────────────┘
```

---

## 2. Código Demonstrativo: Remoção da Compressão e Renomeação Direta

Abaixo é demonstrada a refatoração técnica do método `doIncludePAC` (`ffrmdiggerpac00.cpp` / `usysvenpac00.cpp`), substituindo a chamada de compressão ZIP pela emissão e renomeação direta do XML para `.pac`:

```cpp
// Refatoração de ffrmdiggerpac00.cpp e usysvenpac00.cpp SEM COMPRESSÃO
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

    // 2. Cabeçalho Geral da Sessão / Representante (<rep00>)
    int codrep = this->cadrep00.ven00_codigo;
    int iseq   = this->cadrep00.getPacSeq(); // Sequencial incremental (ex: 1001)

    QDomElement repElement = xmlPAC.createElement("rep00");
    repElement.setAttribute("rep00_codrep", QString::number(codrep));
    repElement.setAttribute("rep00_codfil", QString::number(this->cadrep00.ven00_codfil));
    repElement.setAttribute("ven00_codmod", QString::number(this->cadrep00.ven00_codmod));
    repElement.setAttribute("rep00_numver", this->cadrep00.ven00_numver);
    repElement.setAttribute("rep00_datpck", QDate::currentDate().toString("yyyy-MM-dd"));
    repElement.setAttribute("rep00_datrep", QDate::currentDate().toString("yyyy-MM-dd"));
    repElement.setAttribute("rep00_passwo", this->cadrep00.ven00_paswor);
    xmlRoot.appendChild(repElement);

    // 3. Coleta e Serialização dos Pedidos Selecionados para o Lote
    int pacqtd = 0;
    for (int i = 0; i < this->List.count(); ++i) {
        TGerPacvendig00 *ped = this->List.at(i);
        if (ped->checked) {
            // Serializa o bloco <pckvenpac00> com <pac00> e <pac01>
            ped->addPACSourceXML(xmlPAC, xmlRoot);
            pedList->add(QString::number(ped->dig00_digcod));
            pacqtd++;
        }
    }

    // 4. Definição da Nomenclatura Oficial e Caminhos Físicos
    QString xmlTempFileName = QString("p%1-%2.xml").arg(codrep).arg(iseq);
    QString pacFileName     = QString("p%1-%2.pac").arg(codrep).arg(iseq);
    
    QString xmlTempFilePath = sysfun.CPathPAC(xmlTempFileName);
    QString pacFilePath     = sysfun.CPathPAC(pacFileName);

    // 5. Gravação Direta do XML no Arquivo Temporário
    QFile fileXML(xmlTempFilePath);
    if (!fileXML.open(QIODevice::WriteOnly | QIODevice::Text)) {
        message = "Erro ao criar arquivo XML temporário no dispositivo!";
        return false;
    }
    QTextStream stream(&fileXML);
    stream.setCodec("UTF-8");
    stream << xmlPAC.toString();
    fileXML.close();

    // -------------------------------------------------------------------------
    // 6. RENOMEAÇÃO DIRETA (COMPRESSÃO ZIP REMOVIDA)
    // O arquivo XML em texto claro é renomeado diretamente para a extensão .pac
    // -------------------------------------------------------------------------
    if (QFile::exists(pacFilePath)) {
        QFile::remove(pacFilePath); // Expurga resíduo anterior se houver
    }

    bool renomeadoComSucesso = QFile::rename(xmlTempFilePath, pacFilePath);

    if (renomeadoComSucesso) {
        // 7. Registro do Lote na Tabela Local de Pacotes (pac00)
        Tpckvenpac00 pac;
        pac.pac00_pacrep = codrep;
        pac.pac00_paccod = iseq;
        pac.pac00_pacsrc = pacFileName; // Salva o nome p<codRep>-<seq>.pac
        pac.pac00_pacdat = QDate::currentDate();
        pac.pac00_pacqtd = pacqtd;
        pac.pac00_sttpac = pvpspNEnviado; // 0 = Gerado localmente
        pac.pac00_sttenv = pvpseNEnviado; // 0 = Pendente de envio FTP
        pac.cpost(); // Persiste no SQLite local

        // 8. Atualização do Status dos Pedidos para 'EMPACOTADO' (Travamento)
        for (int i = 0; i < this->List.count(); ++i) {
            TGerPacvendig00 *ped = this->List.at(i);
            if (ped->checked) {
                Tsyssql::exec(QString("UPDATE dig00 SET dig00_sttenv = 1 WHERE dig00_digcod = %1")
                              .arg(ped->dig00_digcod));
            }
        }
        return true;
    } else {
        message = "Falha ao renomear o arquivo XML para a extensão .pac!";
        return false;
    }
}
```

---

## 3. Modelo do Layout XML Gerado

O documento XML mantém exatamente o padrão reconhecido pela retaguarda, utilizando **atributos inline** e precisão de **3 casas decimais** (`0.000`):

```xml
<!DOCTYPE suportware>
<root>
    <!-- Identificação da Sessão e Representante -->
    <rep00 rep00_codrep="71" ven00_codmod="4" rep00_numver="5.08" rep00_datpck="2026-09-01" rep00_datrep="2026-09-01" rep00_codfil="1" rep00_passwo="71"/>

    <!-- ========================================================= -->
    <!-- PRIMEIRO PEDIDO DO LOTE (Cliente 2780)                    -->
    <!-- ========================================================= -->
    <pckvenpac00>
        <pac00 dig00_agtcod="512" dig00_clicod="2780" dig00_bontot="0.000" dig00_codlog="" dig00_destot="0.000" dig00_lincod="1" dig00_subtot="75.000" dig00_digpco="0" dig00_digtot="75.000" dig00_bonfrcven="0" dig00_digcod="11" dig00_digfil="1" dig00_gerntf="0" dig00_placod="3" dig00_datsys="2026-09-01" dig00_digreg="1" dig00_codlat="" dig00_digpwd="71" dig00_datenv="2026-09-01" dig00_cobcod="-1"/>
        <pac01>
            <row dig01_bon_id="0" dig01_pcomax="18.750" dig01_prifil="1" dig01_destot="0.000" dig01_digqtd="4.000" dig01_bontyp="0" dig01_digpco="18.750" dig01_mulemb="0" dig01_percmb="0.000" dig01_subtot="75.000" dig01_mulven="0.000" dig01_codcmb="0" dig01_pcomin="18.750" dig01_digitm="1" dig01_ccvtot="0.000" dig01_digpro="25266" dig01_codbar="" dig01_boncod="0" dig01_pcopro="0.000"/>
        </pac01>
        <cot00/>
    </pckvenpac00>

    <!-- ========================================================= -->
    <!-- SEGUNDO PEDIDO DO LOTE (Cliente 48785)                    -->
    <!-- ========================================================= -->
    <pckvenpac00>
        <pac00 dig00_agtcod="527" dig00_clicod="48785" dig00_bontot="0.000" dig00_codlog="" dig00_destot="0.000" dig00_lincod="1" dig00_subtot="258.680" dig00_digpco="0" dig00_digtot="258.680" dig00_bonfrcven="0" dig00_digcod="10" dig00_digfil="1" dig00_gerntf="0" dig00_placod="2" dig00_datsys="2026-09-01" dig00_digreg="1" dig00_codlat="" dig00_digpwd="71" dig00_datenv="2026-09-01" dig00_cobcod="-1"/>
        <pac01>
            <row dig01_bon_id="0" dig01_pcomax="48.020" dig01_prifil="1" dig01_destot="0.000" dig01_digqtd="2.000" dig01_bontyp="0" dig01_digpco="48.020" dig01_mulemb="0" dig01_percmb="0.000" dig01_subtot="96.040" dig01_mulven="0.000" dig01_codcmb="0" dig01_pcomin="48.020" dig01_digitm="1" dig01_ccvtot="0.000" dig01_digpro="32337" dig01_codbar="" dig01_boncod="0" dig01_pcopro="0.000"/>
            <row dig01_bon_id="0" dig01_pcomax="40.660" dig01_prifil="1" dig01_destot="0.000" dig01_digqtd="4.000" dig01_bontyp="0" dig01_digpco="40.660" dig01_mulemb="0" dig01_percmb="0.000" dig01_subtot="162.640" dig01_mulven="0.000" dig01_codcmb="0" dig01_pcomin="40.660" dig01_digitm="2" dig01_ccvtot="0.000" dig01_digpro="33800" dig01_codbar="" dig01_boncod="0" dig01_pcopro="0.000"/>
        </pac01>
        <cot00/>
    </pckvenpac00>
</root>
```

---

## 4. Nomenclatura Oficial dos Arquivos

A nomenclatura de arquivos de transmissão e recepção segue máscaras fixas e padronizadas:

| Tipo de Arquivo | Extensão | Conteúdo Interno | Máscara de Nome | Exemplo Real | Diretório FTP |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Pacote de Vendas (Upload)** | **`.pac`** | **XML em Texto Claro (Sem ZIP)** | `p<codRep>-<seqPacote>.pac` | `p71-1001.pac` | `dirPAC` (`svr00_dirpac`) |
| **Cadastro Novo Cliente (Upload)** | **`.xml`** | XML em Texto Claro | `c<codRep>-<milissegundos>.xml` | `c71-1682930.xml` | `dirCAD` / `dirCLI` (`svr00_dircad`) |
| **Localização / GPS Cliente (Upload)**| **`.xml`** | XML em Texto Claro | `c<codRep>-<codigo16Cliente>.xml` | `c71-0000000000001542.xml`| `dirCAD` / `dirCLI` |
| **Recados / Não-Venda (Upload)** | **`.xml`** | XML em Texto Claro | `m<codRep>-<seqMensagem>.xml` | `m71-0042.xml` | `dirMSG` (`svr00_dirmsg`) |
| **Retorno de Processamento (Download)**| **`.ret`** / **`.xml`**| Texto / XML de Retorno Fiscal | `r<codRep>-<seqPacote>.ret` | `r71-1001.ret` | `dirPAC` |

*Regra do Sequencial (`seqPacote`):* Mantido no banco SQLite local (`txtven00_pacseq`), incrementando de `1000` a `9999` para evitar conflitos de nomes no servidor FTP.

---

## 5. Máquina de Estados e Ciclo de Vida dos Status

O ciclo de vida do pedido e do lote é controlado pelas tabelas **`dig00`** e **`pac00`**:

```
                    MÁQUINA DE ESTADOS DO PEDIDO DE VENDA:

   [Fechamento da Venda / Salvar]
             │
             v
     dig00_sttenv = 0 (pvddeDIGITADO)   [Venda salva no banco local / Pendente]
             │
             v [doIncludePAC: XML gerado e renomeado para p<codRep>-<seq>.pac]
     dig00_sttenv = 1 (pvddeEMPACOTE)   [AO ENVIAR: Travado contra edição no grid]
     pac00_sttenv = 0 (pvpseNEnviado)   [Pacote gerado localmente, pendente FTP]
             │
             v [FTPTranferCompleted: Upload FTP finalizado com sucesso no dirPAC]
     dig00_sttenv = 2 (pvddeENVIADOS)   [APÓS O ENVIO: Transmissão concluída]
     pac00_sttenv = 1 (pvpseJEnviado)   [Pacote transmitido para o servidor]
             │
             v [fcfGETRET / importReturn: ERP processou o lote e emitiu o retorno]
     dig00_sttenv = 3 (pvddeRECEBIDO)   [LIDO PELO SISTEMA: Faturado na central]
     pac00_sttenv = 2 (pvpseRetornad)   [Retorno fiscal importado no celular]
```

### 5.1 Tabela Comparativa de Estados

| Momento / Evento | Status do Pedido (`dig00_sttenv`) | Status do Pacote (`pac00_sttenv`) | Regra de Negócio e Comportamento |
| :--- | :--- | :--- | :--- |
| **Antes do Envio (Gravado Local)** | **`pvddeDIGITADO = 0`** | *(Inexistente)* | Pedido finalizado no smartphone. Pode ser editado, cancelado ou excluído localmente. |
| **Ao Enviar (Empacotado / Renomeado)** | **`pvddeEMPACOTE = 1`** | **`pvpseNEnviado = 0`** | O XML foi gerado e renomeado para `.pac`. **Trava rígida:** O pedido é bloqueado no grid do aplicativo contra qualquer alteração ou exclusão física. |
| **Após o Envio (Sucesso FTP)** | **`pvddeENVIADOS = 2`** | **`pvpseJEnviado = 1`** | O arquivo `.pac` subiu com sucesso para o diretório `dirPAC` (`fcfPUTPED = 8`) e o socket FTP confirmou o término da transmissão. O app realiza o commit no SQLite local. |
| **Já Lido pelo Sistema (Retaguarda)** | **`pvddeRECEBIDO = 3`** | **`pvpseRetornad = 2`** | O ERP leu o XML contido no `.pac`, faturou as vendas e gerou o arquivo de retorno (`r<codRep>-<seq>.ret`). O app processou o retorno via `importReturn()`. |

---

## 6. Confirmação de Leitura pelo Sistema Central (Leitura de Retorno)

A transição para o estado **"Já Lido pelo Sistema"** (`dig00_sttenv = 3` / `pvddeRECEBIDO` e `pac00_sttenv = 2` / `pvpseRetornad`) ocorre através das seguintes etapas:

1. **Processamento no Servidor:** O ERP lê o arquivo `p<codRep>-<seq>.pac` (como XML direto sem necessidade de descompactar), efetua a importação das vendas e grava o arquivo de retorno `r<codRep>-<seq>.ret` na pasta `dirPAC`.
2. **Download do Retorno no App:** Na sincronização seguinte do vendedor, o app aciona o comando **`fcfGETRET = 6`** para baixar os arquivos com prefixo `r<codRep>-*.ret`.
3. **Importação e Atualização Local:** O método `Tpckvenpac00List::importReturn(QString filename)` faz a leitura das informações retornadas (ex: número da Nota Fiscal emitida, data de faturamento no ERP ou cortes de estoque):
   ```sql
   UPDATE dig00 SET dig00_sttenv = 3, dig00_fatmov = <nroNota> WHERE dig00_digcod = <codPedido>;
   UPDATE pac00 SET pac00_sttenv = 2 WHERE pac00_paccod = <seqPacote>;
   ```
4. **Confirmação de Leitura (`fcfRETPED = 11`):** Após gravar os dados de faturamento no banco local, o aplicativo emite o comando `fcfRETPED = 11` via FTP, autorizando o servidor a arquivar o lote com segurança.

---

## 7. Rastreabilidade dos Arquivos Legados

* **`ffrmdiggerpac00.h` / `ffrmdiggerpac00.cpp`:** Métodos de consolidação do lote `doIncludePAC()` e serialização XML `addPACSourceXML()`.
* **`usysvenpac00.h` / `usysvenpac00.cpp`:** Entidade `Tpckvenpac00`, controle dos status `pac00_sttpac` e `pac00_sttenv`, geração do lote `filePAC()`.
* **`usysvenenu00.h`:** Constantes e enumeradores canônicos `Tpckvendig00SttDIG` e `Tpckvendig00SttENV` (`pvddeDIGITADO = 0`, `pvddeEMPACOTE = 1`, `pvddeENVIADOS = 2`, `pvddeRECEBIDO = 3`).
* **`usyswebutil.h` / `usyswebutil.cpp`:** Constantes de comando FTP `fcfPUTPED = 8`, `fcfGETRET = 6` e `fcfRETPED = 11`.
* **`usysweb.h` / `usysweb.cpp`:** Upload direto via FTP `doFTPFilePut()` enviando o arquivo `.pac` em texto claro.
