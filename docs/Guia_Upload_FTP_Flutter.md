# 🚀 Guia de Implementação: Upload de Arquivos FTP e Geração de Pacotes (.pac)

Este documento detalha o processo de geração, compactação e envio de arquivos via FTP no novo aplicativo Flutter, respeitando a estrutura legada. O sistema legado exigia que os dados fossem transformados em XML, compactados em um arquivo `.pac` (que na verdade é um ZIP renomeado) e depois enviados para diretórios específicos no servidor FTP (`dirPAC` para pedidos, `dirCAD`/`dirCLI` para cadastros, etc.).

---

## 1. 📦 Estrutura do Arquivo XML

O XML gerado deve manter a estrutura esperada pelo servidor legado. Abaixo, um exemplo de como deve ser a estrutura base do XML de Vendas/Pedidos:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<PacoteVendas>
    <Representante>
        <Codigo>105</Codigo>
    </Representante>
    <Pedido>
        <Cabecalho>
            <CodigoPedido>99823</CodigoPedido>
            <CodigoCliente>1542</CodigoCliente>
            <DataEmissao>2023-10-25</DataEmissao>
            <ValorTotal>1500.50</ValorTotal>
            <CondicaoPagamento>30/60 D</CondicaoPagamento>
        </Cabecalho>
        <Itens>
            <Item>
                <CodigoProduto>78945</CodigoProduto>
                <Quantidade>10</Quantidade>
                <PrecoUnitario>150.05</PrecoUnitario>
            </Item>
        </Itens>
    </Pedido>
</PacoteVendas>
```

> **Nota:** A estrutura exata do XML (nós e atributos) deve refletir a modelagem exata do banco de dados (SQLite local) e a expectativa do servidor legado.

---

## 2. 🗜️ Geração e Compactação do Arquivo `.pac`

O arquivo `.pac` não é um formato proprietário, é simplesmente um arquivo **ZIP** renomeado. Para replicar isso no Flutter, usamos o pacote `archive` para criar o ZIP em memória e salvá-lo com a extensão `.pac`.

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
> 4. O nome do arquivo deve seguir a nomenclatura legada: `p<codigoRepresentante>-<milissegundos>.pac` (ex: `p105-1682930.pac`).
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
