/// Abstração do transporte FTP usado pelo módulo de upload.
///
/// Implementada por [FtpClient] (socket bruto) e utilizada por
/// `FtpUploadService`. Permite injetar um fake em testes sem tocar a rede.
abstract class FtpTransport {
  /// Troca de diretório. Aceita path absoluto (`/x/y`) ou relativo (`pasta`).
  Future<void> cwd(String path);

  /// Cria um diretório no FTP (se ainda não existir).
  Future<void> mkd(String path);

  /// Envia [bytes] para o diretório atual com o nome informado.
  /// Dispara [onProgress] (opcional) com o total de bytes já enviados.
  Future<void> stor(
    String fileName,
    List<int> bytes, {
    void Function(int sent)? onProgress,
  });

  /// Retorna o tamanho remoto (em bytes) do arquivo no diretório atual.
  Future<int> size(String fileName);

  /// Baixa o arquivo do diretório atual. Retorna os bytes.
  Future<List<int>> retr(String fileName);

  /// Lista os nomes dos arquivos no diretório atual (ou [path]).
  Future<List<String>> nlst([String? path]);

  /// Deleta um arquivo no diretório atual.
  Future<void> dele(String fileName);

  /// Encerra a conexão de forma limpa.
  Future<void> quit();
}

