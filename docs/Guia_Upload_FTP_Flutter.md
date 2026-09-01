# 🚀 Guia de Implementação: Upload de Arquivos FTP e Geração de Pacotes (.pac)

Este documento detalha o processo de geração, compactação e envio de arquivos via FTP no novo aplicativo Flutter, respeitando a estrutura legada. O sistema legado exigia que os dados fossem transformados em XML, compactados em um arquivo `.pac` (que na verdade é um ZIP renomeado) e depois enviados para diretórios específicos no servidor FTP (`dirPAC` para pedidos, `dirCAD`/`dirCLI` para cadastros, etc.).

---

## 1. 📦 Estrutura do Arquivo XML (Suportware)

O XML gerado mantém a estrutura estrita esperada pela retaguarda ERP:

```xml
<!DOCTYPE suportware>
<root>
<rep00 rep00_codrep="8" ven00_codmod="4" rep00_numver="5.08" rep00_datpck="2026-06-17" rep00_datrep="2026-05-14" rep00_codfil="1" rep00_passwo="8"/>
<pckvenpac00>
<pac00 dig00_agtcod="512" dig00_clicod="10350" dig00_bontot="0.000" dig00_codlog="" dig00_destot="0.000" dig00_lincod="1" dig00_subtot="0.000" dig00_digpco="0" dig00_digtot="509.280" dig00_bonfrcven="0" dig00_digcod="37" dig00_digfil="1" dig00_gerntf="0" dig00_placod="2" dig00_datsys="2026-06-16" dig00_digreg="3" dig00_codlat="" dig00_digpwd="8" dig00_datenv="2026-06-17" dig00_cobcod="-1"/>
<pac01>
<row dig01_bon_id="0" dig01_pcomax="2.780" dig01_prifil="1" dig01_destot="0.000" dig01_digqtd="2.000" dig01_bontyp="0" dig01_digpco="2.780" dig01_mulemb="0" dig01_percmb="0.000" dig01_subtot="0.000" dig01_mulven="0.000" dig01_codcmb="0" dig01_pcomin="2.780" dig01_digitm="1" dig01_ccvtot="0.000" dig01_digpro="1002" dig01_codbar="" dig01_boncod="0" dig01_pcopro="0.000"/>
<row dig01_bon_id="0" dig01_pcomax="136.950" dig01_prifil="1" dig01_destot="0.000" dig01_digqtd="2.000" dig01_bontyp="0" dig01_digpco="136.950" dig01_mulemb="0" dig01_percmb="0.000" dig01_subtot="0.000" dig01_mulven="0.000" dig01_codcmb="0" dig01_pcomin="128.710" dig01_digitm="2" dig01_ccvtot="0.000" dig01_digpro="1005" dig01_codbar="" dig01_boncod="0" dig01_pcopro="0.000"/>
</pac01>
<cot00/>
</pckvenpac00>
</root>
```

> **Nota:** O arquivo é gerado e transmitido diretamente em XML puro com a extensão `.pac` (`p<codRep>-<seq>.pac`), sem compactação zip.

---

## 2. 🗜️ Geração do Arquivo `.pac`


### A. Dependências Necessárias no `pubspec.yaml`
Certifique-se de ter as seguintes bibliotecas adicionadas:

```yaml
dependencies:
  archive: ^3.3.2      # Para compactação ZIP
  path_provider: ^2.0.11 # Para salvar o arquivo temporariamente no dispositivo
  ftpconnect: ^2.0.0 # (Ou o pacote FTP que você já estiver utilizando)
```

### B. Comando para IA: Criar Serviço de Geração PAC
Se você precisar que a IA crie ou ajuste o serviço de geração do pacote, use o seguinte comando:

> **Comando Mestre para IA:**
> "Aja como um desenvolvedor Flutter Sênior. Crie o serviço `PacXmlGeneratorService` no caminho `lib/data/services/pac_xml_generator_service.dart`.
> 
> **Objetivo:**
> 1. Gerar uma string XML contendo os pedidos (baseie-se num layout padrão de Vendas).
> 2. Compactar este arquivo XML em um ZIP usando a biblioteca `archive`.
> 3. Salvar o arquivo compactado localmente usando `path_provider`, mas com a extensão `.pac`.
> 4. O nome do arquivo deve seguir a nomenclatura legada: `p<codigoRepresentante>-<codigoSequencialPacote>.pac` (ex: `p105-32504.pac`). O código sequencial vem de `MAX(ped00_numped)+1` da tabela `pckvendig000` do banco local — não de milissegundos Unix.
> 5. Retorne o `File` gerado de forma assíncrona (`Future<File>`)."

---

## 3. 🌐 Processo de Upload via FTP

Uma vez que o arquivo `.pac` (ou `.xml` para cadastros de clientes - `c<codigo>-<milissegundos>.xml`) é gerado, ele deve ser enviado para o servidor FTP. O sistema legado direcionava os arquivos para pastas específicas dependendo do tipo (ex: `dirPAC` para pacotes de vendas, `dirCAD` para cadastros).

### A. Pastas de Destino Mapeadas do Legado
- **Pedidos/Vendas (`.pac`):** Pasta `dirPAC` (Geralmente algo como `/pacotes/` ou `/vendas/`).
- **Cadastros/Clientes Novos (`.xml`):** Pastas `dirCAD` ou `dirCLI` (Nome: `c<codRep>-<ms>.xml`).
- **Atualização/Localização de Cliente (`.xml`):** Pastas `dirCAD` ou `dirCLI` (Nome: `c<codRep>-<codigo16>.xml`).

### B. Comando para IA: Criar Serviço de Upload FTP
Para que a IA crie o serviço de upload FTP que orquestra a geração e o envio:

> **Comando Mestre para IA:**
> "Aja como um desenvolvedor Flutter Sênior. Crie/Atualize o serviço `FtpUploadService` no caminho `lib/services/ftp_upload_service.dart`.
> 
> **Objetivo:**
> 1. Criar um método `enviarPedidosFtp(String codRepresentante)` que chame o `PacXmlGeneratorService` para obter o arquivo `.pac`.
> 2. Conectar ao servidor FTP (utilize o cliente FTP configurado no projeto).
> 3. Navegar para a pasta de destino de pacotes (`dirPAC` - parametrizado ou hardcoded temporariamente).
> 4. Fazer o upload do arquivo `.pac`.
> 5. Implementar tratamento de erros (`try/catch`).
> 6. Após o upload bem-sucedido, deletar o arquivo temporário local.
> 7. Siga a mesma lógica para criar um método `enviarCadastroClienteFtp`, que gera um arquivo `.xml` (sem compactação) com a nomenclatura `c<codRep>-<ms>.xml` e envia para a pasta `dirCAD`."

---

## Resumo do Fluxo

1. **Buscar Dados:** O aplicativo consulta o SQLite local para obter os pedidos pendentes de envio.
2. **Gerar XML:** Transforma os dados em uma String formatada como XML.
3. **Compactar (Apenas Pedidos):** Converte a String XML em bytes, adiciona a um objeto `Archive`, e codifica (encode) para ZIP.
4. **Salvar Localmente:** Grava o arquivo ZIP no diretório temporário do app com a extensão `.pac`.
5. **Conectar e Subir (FTP):** Conecta ao servidor, navega até `dirPAC` (ou `dirCAD` para clientes), e sobe o arquivo.
6. **Limpeza:** Deleta o arquivo temporário gerado no passo 4.
