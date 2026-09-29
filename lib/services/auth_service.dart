import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import '../app_state.dart';
import '../data/repositories/sales_database_repository.dart';
import '../data/services/local_sales_database_service.dart';
import '../domain/models/config_empresa_acesso.dart';
import '../action_code/offline_login.dart';

/// Serviço responsável pela autenticação e validação do vendedor.
class AuthService {
  final SalesDatabaseRepository _salesDatabaseRepository;

  AuthService({SalesDatabaseRepository? salesDatabaseRepository})
      : _salesDatabaseRepository =
            salesDatabaseRepository ?? SalesDatabaseRepository();

  /// Valida se o vendedor existe e está habilitado para login.
  ///
  /// Se o banco local já existir, consulta a tabela `cadrep00`.
  /// Se o banco não existir (primeiro acesso) e [configEmpresa] for fornecida,
  /// tenta baixar e instalar a carga do vendedor via FTP para validar.
  Future<bool> validarVendedor(
    String codigoVendedor, {
    String? senha,
    ConfigEmpresaAcesso? configEmpresa,
    Database? dbOverride,
  }) async {
    final cod = int.tryParse(codigoVendedor.trim());
    if (cod == null || cod <= 0) {
      return false;
    }

    // 1. Caso com dbOverride (útil para testes unitários isolados)
    if (dbOverride != null) {
      return _validarNoBanco(dbOverride, cod, senha);
    }

    // 2. Verifica se o banco local já existe
    final dbExiste = await LocalSalesDatabaseService().exists();

    if (dbExiste) {
      Database? db;
      try {
        db = await LocalSalesDatabaseService.getDatabase();
        return await _validarNoBanco(db, cod, senha);
      } catch (e) {
        debugPrint('[AuthService] Erro ao consultar banco local: $e');
        return false;
      }
    }

    // 3. Primeiro acesso: baixa a carga da empresa/vendedor para instalar o banco
    if (configEmpresa != null) {
      try {
        final result = await _salesDatabaseRepository.downloadAndInstall(
          companyCode: configEmpresa.codigoEmpresa,
          salespersonCode: codigoVendedor.trim(),
        );

        if (!result.success) {
          return false;
        }

        // Valida se o vendedor está na base instalada
        final db = await LocalSalesDatabaseService.getDatabase();
        return await _validarNoBanco(db, cod, senha);
      } catch (e) {
        debugPrint('[AuthService] Erro no primeiro acesso do vendedor: $e');
        return false;
      }
    }

    return false;
  }

  Future<bool> _validarNoBanco(Database db, int codigoVendedor, String? senha) async {
    try {
      final rows = await db.rawQuery(
        'SELECT * FROM cadrep00 WHERE ven00_codigo = ? LIMIT 1',
        [codigoVendedor],
      );

      if (rows.isEmpty) {
        return false;
      }

      final row = rows.first;

      // Se foi fornecida senha e a base possui campo de senha do supervisor/vendedor
      if (senha != null && senha.trim().isNotEmpty) {
        if (row.containsKey('ven00_passet') && row['ven00_passet'] != null) {
          final pass = row['ven00_passet'].toString().trim();
          if (pass.isNotEmpty && pass != senha.trim()) {
            return false;
          }
        }
      }

      return true;
    } catch (e) {
      debugPrint('[AuthService] Falha ao consultar cadrep00: $e');
      return false;
    }
  }

  /// Inicia a sessão do vendedor, carregando dados cadastrais e permissões no [AppState].
  Future<void> iniciarSessao(
    String codigoVendedor, {
    Database? dbOverride,
    String? dbPath,
  }) async {
    final cod = int.tryParse(codigoVendedor.trim());
    if (cod == null || cod <= 0) return;

    if (dbOverride != null) {
      final rows = await dbOverride.rawQuery(
        'SELECT * FROM cadrep00 WHERE ven00_codigo = ? LIMIT 1',
        [cod],
      );
      if (rows.isNotEmpty) {
        final row = rows.first;
        final appState = AppState();
        appState.vendedor_codigo = (row['ven00_codigo'] as num?)?.toInt() ?? cod;
        appState.vendedor_nome = row['ven00_descri']?.toString().trim() ?? '';
        appState.vendedor_equipe = (row['ven00_codeqp'] as num?)?.toInt() ?? 0;
        if (row['ven00_txajur'] != null) {
          appState.ven00_txajur = (row['ven00_txajur'] as num).toDouble();
        }
        if (row['ven00_chkest'] != null) {
          appState.ven_chkest = (row['ven00_chkest'] as num).toInt();
        }
        if (row['ven00_selfil'] != null) {
          appState.ven_selfil = (row['ven00_selfil'] as num).toInt();
        }
        if (row['ven00_estneg'] != null) {
          appState.ven_estneg = (row['ven00_estneg'] as num).toInt();
        }
        if (row['ven00_gerbonfor'] != null) {
          appState.ven_gerbonfor = (row['ven00_gerbonfor'] as num).toInt();
        }
        if (row['ven00_chkage'] != null) {
          appState.ven_chkage = (row['ven00_chkage'] as num).toInt();
        }
        if (row['ven00_ignlimfis'] != null) {
          appState.ven_ignlimfis = (row['ven00_ignlimfis'] as num).toInt();
        }
        if (row['ven00_maxitmdig'] != null) {
          appState.ven_maxitmdig = (row['ven00_maxitmdig'] as num).toInt();
        }
        if (row['ven00_passet'] != null) {
          appState.ven_passet = row['ven00_passet'].toString().trim();
        }
        if (row['ven00_numver'] != null && row['ven00_numver'].toString().trim().isNotEmpty) {
          appState.versaoApp = row['ven00_numver'].toString().trim();
        }
      }
      return;
    }

    // Utiliza offlineLogin padrão que já processa cadrep00, cadfil00 e parâmetros
    final res = await offlineLogin(codigoVendedor.trim(), dbPath: dbPath);
    if (res.success) {
      final appState = AppState();
      appState.vendedor_codigo = res.vendedorCodigo;
      appState.vendedor_nome = res.vendedorNome;
      appState.vendedor_equipe = res.vendedorEquipe;
    }
  }
}
