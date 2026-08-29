import 'package:flutter_test/flutter_test.dart';
import 'package:forca_de_vendas/action_code/do_maintenance.dart';
import 'package:forca_de_vendas/app_state.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart' as p;

import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('doMaintenance & logout Tests', () {
    late String dbPath;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await AppState().initializePersistedState();
      dbPath = p.join(await getDatabasesPath(), 'dbforcacad001.db');
      final db = await openDatabase(dbPath);

      await db.execute('DROP TABLE IF EXISTS pckvendig000');
      await db.execute('DROP TABLE IF EXISTS pckvendig010');

      await db.execute('''
        CREATE TABLE pckvendig000 (
          ped00_numped INTEGER PRIMARY KEY,
          ped00_sttdig INTEGER DEFAULT 0,
          ped00_sttenv INTEGER DEFAULT 0,
          ped00_digtot REAL DEFAULT 0
        )
      ''');

      await db.execute('''
        CREATE TABLE pckvendig010 (
          ped10_numped INTEGER,
          ped10_codprd TEXT,
          ped10_qtdped REAL
        )
      ''');

      // 1. Pedido rascunho com item (não deve ser deletado)
      await db.insert('pckvendig000', {'ped00_numped': 100, 'ped00_sttdig': 0, 'ped00_sttenv': 0});
      await db.insert('pckvendig010', {'ped10_numped': 100, 'ped10_codprd': 'PROD_A', 'ped10_qtdped': 2.0});

      // 2. Pedido rascunho sem item (órfão / abandonado -> DEVE ser expurgado)
      await db.insert('pckvendig000', {'ped00_numped': 200, 'ped00_sttdig': 0, 'ped00_sttenv': 0});

      // 3. Pedido concluído/digitado sem item (sttdig = 1 -> não deve ser deletado pelo expurgo de rascunho)
      await db.insert('pckvendig000', {'ped00_numped': 300, 'ped00_sttdig': 1, 'ped00_sttenv': 0});

      // 4. Item órfão em pckvendig010 sem cabeçalho (DEVE ser expurgado)
      await db.insert('pckvendig010', {'ped10_numped': 999, 'ped10_codprd': 'PROD_ORFAO', 'ped10_qtdped': 1.0});

      await db.close();
    });

    test('doMaintenance removes orphan drafts without items and keeps drafts with items', () async {
      await doMaintenance(dbPathOverride: dbPath);

      final db = await openDatabase(dbPath);
      final headers = await db.query('pckvendig000');
      final items = await db.query('pckvendig010');
      await db.close();

      final headerIds = headers.map((r) => r['ped00_numped']).toSet();
      final itemParentIds = items.map((r) => r['ped10_numped']).toSet();

      // Pedido 100 (com item) deve continuar existindo
      expect(headerIds.contains(100), isTrue);

      // Pedido 200 (rascunho vazio) deve ter sido expurgado
      expect(headerIds.contains(200), isFalse);

      // Pedido 300 (concluído) deve continuar existindo
      expect(headerIds.contains(300), isTrue);

      // Item 999 (órfão) deve ter sido expurgado
      expect(itemParentIds.contains(999), isFalse);
      expect(itemParentIds.contains(100), isTrue);
    });

    test('logoutVendedor executes doMaintenance and resets AppState session variables', () async {
      AppState().vendedor_codigo = 42;
      AppState().vendedor_nome = 'Vendedor Teste';
      AppState().pedido_numero = 105;

      await logoutVendedor(dbPathOverride: dbPath);

      expect(AppState().vendedor_codigo, equals(0));
      expect(AppState().vendedor_nome, equals(''));
      expect(AppState().pedido_numero, equals(0));
    });
  });
}
