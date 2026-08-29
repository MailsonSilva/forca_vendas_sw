import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import '../app_state.dart';

/// PRD 1 §1D — Rotina de manutenção e expurgo no SQLite local (Tpckvendig00::doMaintenance)
/// Executada no logout ou manutenção para limpar rascunhos órfãos ou abandonados sem itens (sttdig = 0).
Future<void> doMaintenance({String? dbPathOverride}) async {
  try {
    final Set<String> targetPaths = {};
    if (dbPathOverride != null) {
      targetPaths.add(dbPathOverride);
    } else {
      final dbPath = p.join(await getDatabasesPath(), 'dbforcacad001.db');
      final dbPathAlt = p.join(await getDatabasesPath(), 'dbforcadig001.db');
      if (await File(dbPath).exists()) targetPaths.add(dbPath);
      if (await File(dbPathAlt).exists()) targetPaths.add(dbPathAlt);
      if (targetPaths.isEmpty) targetPaths.add(dbPath);
    }

    for (final path in targetPaths) {
      if (!await File(path).exists()) continue;
      Database? db;
      try {
        db = await openDatabase(path);
        final tables = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table'");
        final tableNames = tables.map((r) => r['name']?.toString().toLowerCase() ?? '').toSet();

        if (tableNames.contains('pckvendig000') && tableNames.contains('pckvendig010')) {
          // 1. Expurga rascunhos em pckvendig000 (ped00_sttdig = 0) que não possuem itens em pckvendig010
          await db.rawDelete('''
            DELETE FROM pckvendig000
            WHERE (ped00_sttdig = 0 OR ped00_sttdig IS NULL)
              AND ped00_numped NOT IN (
                SELECT DISTINCT ped10_numped 
                FROM pckvendig010 
                WHERE ped10_numped IS NOT NULL AND ped10_numped != 0
              )
          ''');

          // 2. Expurga itens órfãos em pckvendig010 sem cabeçalho correspondente
          await db.rawDelete('''
            DELETE FROM pckvendig010
            WHERE ped10_numped NOT IN (
              SELECT DISTINCT ped00_numped 
              FROM pckvendig000 
              WHERE ped00_numped IS NOT NULL AND ped00_numped != 0
            )
          ''');
        } else if (tableNames.contains('pckvendig000')) {
          // Se só tem pckvendig000, remove rascunhos com total zerado ou sem itens
          try {
            await db.rawDelete('DELETE FROM pckvendig000 WHERE ped00_sttdig = 0 AND (ped00_digtot = 0 OR ped00_digtot IS NULL)');
          } catch (_) {}
        }
      } catch (e) {
        print('Erro no doMaintenance para $path: $e');
      } finally {
        if (db != null && db.isOpen) {
          await db.close();
        }
      }
    }
  } catch (e) {
    print('Erro geral no doMaintenance: $e');
  }
}

/// Rotina completa de Logout do Vendedor
Future<void> logoutVendedor({String? dbPathOverride}) async {
  // 1. Executa expurgo no SQLite local
  await doMaintenance(dbPathOverride: dbPathOverride);

  // 2. Limpa variáveis de sessão em memória
  AppState().update(() {
    AppState().vendedor_codigo = 0;
    AppState().vendedor_nome = '';
    AppState().vendedor_logado_codigo = 0;
    AppState().vendedor_logado_nome = '';
    AppState().pedido_numero = 0;
    AppState().pedido_items_json = '';
    AppState().ven_passet = '';
  });
}
