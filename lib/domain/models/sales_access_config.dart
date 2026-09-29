/// Configuracao de acesso da empresa retornada pelo arquivo `acesso` no FTP.
///
/// Este modelo isola o formato externo do JSON legado do restante do app.
class SalesAccessConfig {
  const SalesAccessConfig({
    required this.downloadPath,
    required this.uploadPath,
    required this.databaseFilePrefix,
    this.nomeEmpresa = '',
  });

  final String downloadPath;
  final String uploadPath;
  final String databaseFilePrefix;
  final String nomeEmpresa;

  bool get hasDownloadConfig =>
      downloadPath.isNotEmpty && databaseFilePrefix.isNotEmpty;

  bool get hasUploadConfig => uploadPath.isNotEmpty;

  /// Interpola dinamicamente o código da equipe do vendedor nos caminhos de download/upload.
  String resolverCaminho(String template, String? codigoEquipe, {String fallback = '01'}) {
    final raw = (codigoEquipe == null || codigoEquipe.trim().isEmpty || codigoEquipe.trim() == '0')
        ? fallback
        : codigoEquipe.trim();
    final equipeFormatada = raw.padLeft(2, '0');
    return template
        .replaceAll('{codigo_da_equipe}', equipeFormatada)
        .replaceAll('{codigoEquipe}', equipeFormatada);
  }

  /// Retorna o caminho remoto de download resolvido com a equipe.
  String resolverDownloadPath(String? codigoEquipe) =>
      resolverCaminho(downloadPath, codigoEquipe);

  /// Retorna o caminho remoto de upload resolvido com a equipe.
  String resolverUploadPath(String? codigoEquipe) =>
      resolverCaminho(uploadPath, codigoEquipe);

  static SalesAccessConfig fromMap(Map<String, dynamic> map) {
    final downloadPath = map['pasta_download']?.toString().trim() ?? '';
    final uploadPath = map['pasta_upload']?.toString().trim() ?? '';
    final databaseFilePrefix = map['nome_arquivo_db']?.toString().trim() ?? '';
    final nomeEmpresa = map['nome_empresa']?.toString().trim() ??
        map['empresa']?.toString().trim() ??
        '';

    return SalesAccessConfig(
      downloadPath: downloadPath,
      uploadPath: uploadPath,
      databaseFilePrefix: databaseFilePrefix,
      nomeEmpresa: nomeEmpresa,
    );
  }
}
