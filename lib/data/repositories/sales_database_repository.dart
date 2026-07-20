import 'dart:convert';

import '/app_state.dart';
import '/backend/ftp/ftp_client.dart';
import '/data/services/crg_codec.dart';
import '/data/services/local_sales_database_service.dart';
import '/domain/models/sales_access_config.dart';
import '/domain/models/sales_database_install_result.dart';

/// Repositorio da carga de vendas.
///
/// Orquestra FTP, conversao `.crg` e persistencia local. As actions chamam este
/// repositorio como uma fachada, sem conhecer detalhes de transporte ou arquivo.
class SalesDatabaseRepository {
  SalesDatabaseRepository({
    CrgCodec? crgCodec,
    LocalSalesDatabaseService? localDatabase,
  })  : _crgCodec = crgCodec ?? CrgCodec(),
        _localDatabase = localDatabase ?? LocalSalesDatabaseService();

  final CrgCodec _crgCodec;
  final LocalSalesDatabaseService _localDatabase;

  Future<SalesDatabaseInstallResult> downloadAndInstall({
    required String companyCode,
    required String salespersonCode,
  }) async {
    FtpClient? ftp;
    try {
      ftp = await FtpClient.connect();
      final config = await _readAccessConfig(ftp, companyCode);
      if (!config.hasDownloadConfig) {
        throw StateError('Configuracao de download incompleta.');
      }

      await _changeDirectory(ftp, config.downloadPath);

      final crgName = '${config.databaseFilePrefix}$salespersonCode.crg';
      final crgBytes = await ftp.retr(crgName);
      final databaseBytes = _crgCodec.decodeDatabase(crgBytes);
      await _localDatabase.replaceWithValidatedBytes(databaseBytes);

      return SalesDatabaseInstallResult(
        message: 'Base local atualizada.',
        config: config,
      );
    } finally {
      await ftp?.quit();
    }
  }

  Future<void> uploadLocalDatabase({
    required String salespersonCode,
    String? companyCode,
    String? teamCode,
    String? targetPath,
  }) async {
    final emp = (companyCode ?? AppState().empresa_codigo).trim().toLowerCase();
    final empPath = emp.isEmpty ? 'diniz' : emp;
    final eqCode = (teamCode ?? salespersonCode).trim().padLeft(2, '0');
    final path = targetPath ?? '/$empPath/$eqCode/Upload';

    FtpClient? ftp;
    try {
      final databaseBytes = await _localDatabase.readDatabaseBytes();
      final crgBytes = _crgCodec.encodeDatabase(databaseBytes);

      ftp = await FtpClient.connect();
      await _changeDirectory(ftp, path);
      await ftp.stor('ven$salespersonCode.crg', crgBytes);
    } finally {
      await ftp?.quit();
    }
  }

  Future<SalesAccessConfig> _readAccessConfig(
    FtpClient ftp,
    String companyCode,
  ) async {
    await ftp.cwd('/config/');
    final accessBytes = await ftp.retr('acesso');
    final decoded = jsonDecode(utf8.decode(accessBytes));
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Arquivo acesso invalido.');
    }

    final rawConfig = decoded[companyCode];
    if (rawConfig is! Map<String, dynamic>) {
      throw StateError('Empresa nao encontrada no acesso.');
    }

    return SalesAccessConfig.fromMap(rawConfig);
  }

  Future<void> _changeDirectory(FtpClient ftp, String path) async {
    await ftp.cwd('/');
    final segments =
        path.split('/').where((segment) => segment.trim().isNotEmpty);
    for (final segment in segments) {
      final seg = segment.trim();
      try {
        await ftp.cwd(seg);
      } catch (_) {
        try {
          await ftp.mkd(seg);
          await ftp.cwd(seg);
        } catch (_) {}
      }
    }
  }
}
