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
