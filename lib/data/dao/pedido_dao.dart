import 'package:sqflite/sqflite.dart';
import '../services/local_sales_database_service.dart';

/// DAO compat PRD dig00/dig01 → pckvendig000/010.
/// Físico permanece dbforcacad001.db; alias lógico via view temporária / SELECT.
class PedidoDao {
  Future<Database> get db async {
    final dbPath = await LocalSalesDatabaseService.getDatabasePath();
    return openDatabase(dbPath);
  }

  /// Garante views temporárias dig00/dig01 → pckvendig000/010 para compat PRD.
  /// Recria DROP+CREATE para que ALTER TABLE de colunas novas seja refletido (SELECT * da view).
  Future<void> ensureAliasViews(Database database) async {
    try {
      // Se pckvendig000 não existe ainda, não tenta criar view
      final t = await database.rawQuery("SELECT name FROM sqlite_master WHERE type='table' AND lower(name)='pckvendig000'");
      if (t.isNotEmpty) {
        try { await database.execute('DROP VIEW IF EXISTS dig00'); } catch (_) {}
        await database.execute('CREATE VIEW dig00 AS SELECT * FROM pckvendig000');
      }
    } catch (_) {}
    try {
      final t2 = await database.rawQuery("SELECT name FROM sqlite_master WHERE type='table' AND lower(name)='pckvendig010'");
      if (t2.isNotEmpty) {
        try { await database.execute('DROP VIEW IF EXISTS dig01'); } catch (_) {}
        await database.execute('CREATE VIEW dig01 AS SELECT * FROM pckvendig010');
      }
    } catch (_) {}
  }

  Future<List<Map<String, dynamic>>> queryDig00({int? numped}) async {
    final database = await db;
    try {
      await ensureAliasViews(database);
      if (numped != null) {
        // Tenta via alias primeiro, fallback tabela real
        try {
          return await database.rawQuery('SELECT * FROM dig00 WHERE ped00_numped = ?', [numped]);
        } catch (_) {
          return await database.query('pckvendig000', where: 'ped00_numped = ?', whereArgs: [numped]);
        }
      }
      try {
        return await database.rawQuery('SELECT * FROM dig00');
      } catch (_) {
        return await database.query('pckvendig000');
      }
    } finally {
      await database.close();
    }
  }

  Future<List<Map<String, dynamic>>> queryDig01({required int numped}) async {
    final database = await db;
    try {
      await ensureAliasViews(database);
      try {
        return await database.rawQuery('SELECT * FROM dig01 WHERE ped10_numped = ?', [numped]);
      } catch (_) {
        return await database.query('pckvendig010', where: 'ped10_numped = ?', whereArgs: [numped]);
      }
    } finally {
      await database.close();
    }
  }

  /// Alias direto compat PRD: dbforcadig001.db == dbforcacad001.db (mesmo arquivo).
  static String get aliasName => 'dbforcadig001.db';
  static String get physicalName => 'dbforcacad001.db';
}
