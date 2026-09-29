import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import '../app_state.dart';
import '../backend/ftp/ftp_client.dart';
import '../backend/ftp/ftp_transport.dart';
import '../data/repositories/sales_database_repository.dart';
import '../data/services/local_sales_database_service.dart';
import '../domain/models/config_empresa_acesso.dart';
import '../domain/models/sales_database_install_result.dart';
import 'acesso_ftp_service.dart';

/// Serviço especializado no download de cargas FTP com interpolação de equipe do vendedor.
class FtpDownloadService {
  final Future<FtpTransport> Function() _connectFtp;
  final AcessoFtpService _acessoFtpService;
  final SalesDatabaseRepository _salesDbRepo;

  FtpDownloadService({
    Future<FtpTransport> Function()? connectFtp,
    AcessoFtpService? acessoFtpService,
    SalesDatabaseRepository? salesDatabaseRepository,
  })  : _connectFtp = connectFtp ?? (() => FtpClient.connect()),
        _acessoFtpService = acessoFtpService ?? AcessoFtpService(),
        _salesDbRepo = salesDatabaseRepository ?? SalesDatabaseRepository();

  Future<FtpTransport> Function() get connectFtp => _connectFtp;
  AcessoFtpService get acessoFtpService => _acessoFtpService;
  SalesDatabaseRepository get salesDbRepo => _salesDbRepo;

  /// Resolve o caminho remoto final de download da carga interpolando o código da equipe.
  /// Formato padrão no `acesso.json`: `/diniz/{codigo_da_equipe}/Upload/` -> `/diniz/01/Upload/`.
  String resolverDiretorioDownload({
    required ConfigEmpresaAcesso config,
    String? codigoEquipe,
    String fallback = '01',
  }) {
    return config.resolverCaminho(config.pastaDownload, codigoEquipe, fallback: fallback);
  }

  /// Obtém o código da equipe do vendedor através da sessão ativa ou do cadastro local SQLite (`cadrep00.ven00_codeqp`).
  Future<String> obterCodigoEquipeVendedor({
    String? vendedorCodigo,
    Database? db,
  }) async {
    // 1. Sessão autenticada (AppState)
    final eqpSessao = AppState().vendedor_equipe;
    if (eqpSessao > 0) {
      return eqpSessao.toString().padLeft(2, '0');
    }

    // 2. Tabela local cadrep00.ven00_codeqp
    try {
      final dbInst = db ?? (await LocalSalesDatabaseService().exists()
          ? await LocalSalesDatabaseService.getDatabase()
          : null);

      if (dbInst != null) {
        final codVen = int.tryParse(vendedorCodigo ?? '') ?? AppState().vendedor_codigo;
        if (codVen > 0) {
          final rows = await dbInst.rawQuery(
            'SELECT ven00_codeqp FROM cadrep00 WHERE ven00_codigo = ? LIMIT 1',
            [codVen],
          );
          if (rows.isNotEmpty && rows.first['ven00_codeqp'] != null) {
            final eqp = rows.first['ven00_codeqp'].toString().trim();
            if (eqp.isNotEmpty && eqp != '0') {
              return eqp.padLeft(2, '0');
            }
          }
        }

        final genericRows = await dbInst.rawQuery(
          'SELECT ven00_codeqp FROM cadrep00 WHERE ven00_codeqp IS NOT NULL AND ven00_codeqp > 0 LIMIT 1',
        );
        if (genericRows.isNotEmpty && genericRows.first['ven00_codeqp'] != null) {
          final eqp = genericRows.first['ven00_codeqp'].toString().trim();
          if (eqp.isNotEmpty && eqp != '0') {
            return eqp.padLeft(2, '0');
          }
        }
      }
    } catch (e) {
      debugPrint('[FtpDownloadService] Erro ao consultar ven00_codeqp local: $e');
    }

    // 3. SharedPreferences / AppState fallback
    try {
      final prefEquipe = AppState().prefs.getInt('app_vendedor_equipe') ?? 0;
      if (prefEquipe > 0) {
        return prefEquipe.toString().padLeft(2, '0');
      }
    } catch (_) {}

    // Fallback seguro caso não seja encontrada equipe
    return '01';
  }

  /// Executa o download da carga do vendedor garantindo a interpolação do diretório remoto.
  Future<SalesDatabaseInstallResult> baixarCarga({
    required String companyCode,
    required String salespersonCode,
    String? teamCode,
  }) async {
    final equipe = (teamCode != null && teamCode.trim().isNotEmpty && teamCode.trim() != '0')
        ? teamCode.trim().padLeft(2, '0')
        : await obterCodigoEquipeVendedor(vendedorCodigo: salespersonCode);

    return _salesDbRepo.downloadAndInstall(
      companyCode: companyCode,
      salespersonCode: salespersonCode,
      teamCode: equipe,
    );
  }
}
