import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import '../app_state.dart';
import '../data/services/local_sales_database_service.dart';

/// Serviço responsável por resolver e armazenar a versão do aplicativo
/// a ser exibida nas configurações, respeitando as regras de precedência:
/// 1. Campo `ven00_numver` do vendedor logado em `cadrep00`
/// 2. Fallback 1: `cfg00_versis` de `cadcfg00`
/// 3. Fallback 2: Versão do pacote do aplicativo (PackageInfo)
class VersaoAppService {
  VersaoAppService._();
  static final VersaoAppService instance = VersaoAppService._();

  static const String versaoAppKey = 'app_versao_app';

  /// Extrai e resolve a versão do aplicativo:
  /// - SELECT ven00_numver FROM cadrep00 WHERE ven00_codigo = :codVendedorLogado LIMIT 1;
  /// - Fallback 1: SELECT cfg00_versis FROM cadcfg00 LIMIT 1;
  /// - Fallback 2: [versaoPacoteFallback] ou PackageInfo.fromPlatform()
  Future<String> resolverVersaoApp({
    Database? db,
    int? codVendedor,
    String? versaoPacoteFallback,
  }) async {
    String versaoResolvida = '';
    Database? localDb = db;

    try {
      if (localDb == null) {
        try {
          localDb = await LocalSalesDatabaseService.getDatabase();
        } catch (_) {}
      }

      if (localDb != null && localDb.isOpen) {
        final cod = (codVendedor != null && codVendedor > 0)
            ? codVendedor
            : AppState().vendedor_codigo;

        // 1. SELECT ven00_numver FROM cadrep00 WHERE ven00_codigo = :codVendedorLogado LIMIT 1;
        try {
          final tRep = await localDb.rawQuery(
            "SELECT name FROM sqlite_master WHERE type='table' AND lower(name)='cadrep00'",
          );
          if (tRep.isNotEmpty) {
            final cols = await localDb.rawQuery('PRAGMA table_info(cadrep00)');
            final colNames = cols
                .map((r) => r['name']?.toString().toLowerCase())
                .whereType<String>()
                .toSet();

            if (colNames.contains('ven00_numver')) {
              List<Map<String, dynamic>> rows = [];
              if (cod > 0) {
                final idCol = colNames.contains('ven00_codigo')
                    ? 'ven00_codigo'
                    : (colNames.contains('rep00_codigo') ? 'rep00_codigo' : null);
                if (idCol != null) {
                  rows = await localDb.rawQuery(
                    'SELECT ven00_numver FROM cadrep00 WHERE $idCol = ? LIMIT 1',
                    [cod],
                  );
                }
              }
              if (rows.isEmpty) {
                rows = await localDb.rawQuery(
                  'SELECT ven00_numver FROM cadrep00 WHERE ven00_numver IS NOT NULL AND TRIM(ven00_numver) != "" LIMIT 1',
                );
              }

              if (rows.isNotEmpty && rows.first['ven00_numver'] != null) {
                final val = rows.first['ven00_numver'].toString().trim();
                if (val.isNotEmpty) {
                  versaoResolvida = val;
                }
              }
            }
          }
        } catch (e) {
          debugPrint('[VersaoAppService] Falha ao consultar cadrep00: $e');
        }

        // 2. Fallback 1: Caso ven00_numver esteja nulo ou vazio: SELECT cfg00_versis FROM cadcfg00 LIMIT 1;
        if (versaoResolvida.isEmpty) {
          try {
            final tCfg = await localDb.rawQuery(
              "SELECT name FROM sqlite_master WHERE type='table' AND lower(name)='cadcfg00'",
            );
            if (tCfg.isNotEmpty) {
              final cols = await localDb.rawQuery('PRAGMA table_info(cadcfg00)');
              final colNames = cols
                  .map((r) => r['name']?.toString().toLowerCase())
                  .whereType<String>()
                  .toSet();

              if (colNames.contains('cfg00_versis')) {
                final rows = await localDb.rawQuery(
                  'SELECT cfg00_versis FROM cadcfg00 LIMIT 1',
                );
                if (rows.isNotEmpty && rows.first['cfg00_versis'] != null) {
                  final val = rows.first['cfg00_versis'].toString().trim();
                  if (val.isNotEmpty) {
                    versaoResolvida = val;
                  }
                }
              }
            }
          } catch (e) {
            debugPrint('[VersaoAppService] Falha ao consultar cadcfg00: $e');
          }
        }
      }
    } catch (_) {}

    // 3. Fallback 2: Versão do pacote atual (PackageInfo)
    if (versaoResolvida.isEmpty) {
      if (versaoPacoteFallback != null && versaoPacoteFallback.trim().isNotEmpty) {
        versaoResolvida = versaoPacoteFallback.trim();
      } else {
        try {
          final pkg = await PackageInfo.fromPlatform();
          if (pkg.version.trim().isNotEmpty) {
            versaoResolvida = pkg.version.trim();
          }
        } catch (_) {}
      }
    }

    // Armazenar na sessão ativa / AppState / SharedPreferences
    if (versaoResolvida.isNotEmpty) {
      await persistirVersaoResolvida(versaoResolvida);
    }

    return versaoResolvida;
  }

  /// Salva no AppState e SharedPreferences para acesso rápido na tela de configurações.
  Future<void> persistirVersaoResolvida(String versao) async {
    AppState().versaoApp = versao;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(versaoAppKey, versao);
    } catch (_) {}
  }
}
