/// Representa a configuração de acesso da empresa obtida no arquivo `acesso.json` do FTP.
class ConfigEmpresaAcesso {
  final String codigoEmpresa;
  final String nomeEmpresa;
  final String pastaDownload;
  final String pastaUpload;
  final String nomeArquivoDb;

  ConfigEmpresaAcesso({
    required this.codigoEmpresa,
    required this.nomeEmpresa,
    required this.pastaDownload,
    required this.pastaUpload,
    required this.nomeArquivoDb,
  });

  factory ConfigEmpresaAcesso.fromJson(String codigo, Map<String, dynamic> json) {
    return ConfigEmpresaAcesso(
      codigoEmpresa: codigo.trim(),
      nomeEmpresa: (json['nome_empresa'] ?? json['empresa'] ?? '').toString().trim(),
      pastaDownload: (json['pasta_download'] ?? json['caminho_download'] ?? '').toString().trim(),
      pastaUpload: (json['pasta_upload'] ?? json['caminho_upload'] ?? '').toString().trim(),
      nomeArquivoDb: (json['nome_arquivo_db'] ?? json['prefixo_arquivo'] ?? 'ven').toString().trim(),
    );
  }

  Map<String, dynamic> toJson() => {
    'codigo_empresa': codigoEmpresa,
    'nome_empresa': nomeEmpresa,
    'pasta_download': pastaDownload,
    'pasta_upload': pastaUpload,
    'nome_arquivo_db': nomeArquivoDb,
  };

  /// Concatena a pasta base de upload com o código da equipe do vendedor (ven00_codeqp).
  /// Exemplo: `${pasta_upload}${codigoEquipe}` -> `/diniz/upload/01`
  String resolverPastaUploadEquipe(int codigoEquipe, {bool barraFinal = false}) {
    var base = pastaUpload.trim();
    if (base.isEmpty) return '';
    if (!base.endsWith('/')) {
      base = '$base/';
    }
    final equipeFormatada = codigoEquipe.toString().padLeft(2, '0');
    return barraFinal ? '$base$equipeFormatada/' : '$base$equipeFormatada';
  }

  @override
  String toString() {
    return 'ConfigEmpresaAcesso(empresa: $codigoEmpresa, nome: $nomeEmpresa, download: $pastaDownload, upload: $pastaUpload, prefixoDb: $nomeArquivoDb)';
  }
}
