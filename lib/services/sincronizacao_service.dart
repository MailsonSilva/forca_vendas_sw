import 'package:sqflite/sqflite.dart';
import '../data/repositories/sales_database_repository.dart';
import '../domain/models/sales_database_install_result.dart';
import 'carga_database_service.dart';

/// Serviço orquestrador de sincronização de carga de dados e metadados (SPEC-056).
///
/// Integra a substituição do banco `dbforcacad001.db` com a extração e validação
/// de sequencial da carga, versão do sistema e perfil da equipe do vendedor.
class SincronizacaoService {
  SincronizacaoService({
    CargaDatabaseService? cargaDatabaseService,
    SalesDatabaseRepository? salesDatabaseRepository,
  })  : _cargaDbService = cargaDatabaseService ?? CargaDatabaseService(),
        _salesDbRepo = salesDatabaseRepository ?? SalesDatabaseRepository();

  final CargaDatabaseService _cargaDbService;
  final SalesDatabaseRepository _salesDbRepo;

  /// Processa e inspeciona os campos da carga no SQLite local:
  /// - Sequencial da Carga (`cfg00_numcar` / `cfg00_seqcar` em `cadcfg00`)
  /// - Versão do Sistema (`cfg00_versis` com fallback `srv00_verapp` em `cadace00` ou `cadcfg00`)
  /// - Equipe do Vendedor (`ven00_codeqp` em `cadrep00`)
  Future<CargaInfoResult> processarCamposCarga({
    Database? db,
    int? vendedorCodigo,
  }) {
    return _cargaDbService.processarCamposCarga(
      db: db,
      vendedorCodigo: vendedorCodigo,
    );
  }

  /// Baixa a carga do FTP, valida e substitui `dbforcacad001.db`, sincronizando
  /// em seguida os metadados de carga e versão no AppState e SharedPreferences.
  Future<SalesDatabaseInstallResult> sincronizarCarga({
    required String companyCode,
    required String salespersonCode,
  }) {
    return _salesDbRepo.downloadAndInstall(
      companyCode: companyCode,
      salespersonCode: salespersonCode,
    );
  }
}
