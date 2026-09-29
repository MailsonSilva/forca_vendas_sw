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

  /// Interpola dinamicamente o código da equipe do vendedor nos templates de pasta.
  /// Suporta os marcadores `{codigo_da_equipe}` e `{codigoEquipe}`.
  /// Garante formato de 2 dígitos (ex: '1' -> '01', '2' -> '02').
  /// Se [codigoEquipe] for nulo, vazio ou '0', utiliza fallback seguro ('01').
  String resolverCaminho(String template, String? codigoEquipe, {String fallback = '01'}) {
    final raw = (codigoEquipe == null || codigoEquipe.trim().isEmpty || codigoEquipe.trim() == '0')
        ? fallback
        : codigoEquipe.trim();
    final equipeFormatada = raw.padLeft(2, '0');
    return template
        .replaceAll('{codigo_da_equipe}', equipeFormatada)
        .replaceAll('{codigoEquipe}', equipeFormatada);
  }

  /// Retorna o caminho de download com a equipe do vendedor interpolada.
  String resolverPastaDownload(String? codigoEquipe) =>
      resolverCaminho(pastaDownload, codigoEquipe);

  /// Retorna o caminho de upload com a equipe do vendedor interpolada.
  String resolverPastaUpload(String? codigoEquipe) =>
      resolverCaminho(pastaUpload, codigoEquipe);

  /// Concatena ou interpola a pasta base de upload com o código da equipe do vendedor (ven00_codeqp).
  /// Exemplo: `${pasta_upload}${codigoEquipe}` -> `/diniz/upload/01`
  /// Ou template: `/diniz/{codigo_da_equipe}/Externo/` -> `/diniz/01/Externo/`
  String resolverPastaUploadEquipe(int codigoEquipe, {bool barraFinal = false}) {
    var base = pastaUpload.trim();
    if (base.isEmpty) return '';

    if (base.contains('{codigo_da_equipe}') || base.contains('{codigoEquipe}')) {
      final resolvido = resolverPastaUpload(codigoEquipe.toString());
      if (barraFinal && !resolvido.endsWith('/')) {
        return '$resolvido/';
      }
      return resolvido;
    }

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
