import 'package:flutter_test/flutter_test.dart';
import 'package:forca_de_vendas/app_state.dart';
import 'package:forca_de_vendas/domain/services/bloqueio_financeiro_service.dart';
import 'package:forca_de_vendas/app_constants.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart' as p;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('BloqueioFinanceiroService & Títulos Vencidos Tests', () {
    test('kEnableBloqueioFinanceiro should be true', () {
      expect(kEnableBloqueioFinanceiro, isTrue);
    });

    test('verificaCredito does not block on order start (valorPedido == 0)', () {
      final resAbertura = BloqueioFinanceiroService.verificaCredito(
        crelim: 5000.0,
        creatu: 0.0,
        valorPedido: 0.0,
      );
      expect(resAbertura.bloqueado, isFalse);
    });

    test('verificaCredito blocks when order exceeds available credit (creatu)', () {
      final resExcedido = BloqueioFinanceiroService.verificaCredito(
        crelim: 5000.0,
        creatu: 1000.0,
        valorPedido: 1200.0,
      );
      expect(resExcedido.bloqueado, isTrue);
      expect(resExcedido.motivo, contains('Limite de crédito excedido'));

      final resAprovado = BloqueioFinanceiroService.verificaCredito(
        crelim: 5000.0,
        creatu: 1000.0,
        valorPedido: 800.0,
      );
      expect(resAprovado.bloqueado, isFalse);
    });

    test('isPlanoAVista identifies cash / à vista modalities', () async {
      final dbPath = p.join(await getDatabasesPath(), 'test_plano.db');
      final db = await openDatabase(dbPath);
      await db.execute('DROP TABLE IF EXISTS cadpla00');
      await db.execute('''
        CREATE TABLE cadpla00 (
          pla00_codigo INTEGER PRIMARY KEY,
          pla00_descri TEXT,
          pla00_codtyp INTEGER
        )
      ''');
      await db.insert('cadpla00', {'pla00_codigo': 1, 'pla00_descri': 'A VISTA DINHEIRO', 'pla00_codtyp': 0});
      await db.insert('cadpla00', {'pla00_codigo': 2, 'pla00_descri': '30 DIAS BOLETO', 'pla00_codtyp': 1});
      await db.close();

      expect(await BloqueioFinanceiroService.isPlanoAVista('1', dbPathOverride: dbPath), isTrue);
      expect(await BloqueioFinanceiroService.isPlanoAVista('2', dbPathOverride: dbPath), isFalse);
    });

    test('verificaFechamentoPedido bypasses credit check for cash (à vista) sales', () async {
      final dbPath = p.join(await getDatabasesPath(), 'test_fechamento_vista.db');
      final db = await openDatabase(dbPath);
      await db.execute('DROP TABLE IF EXISTS cadpla00');
      await db.execute('DROP TABLE IF EXISTS cadcli00');
      await db.execute('CREATE TABLE cadpla00 (pla00_codigo INTEGER PRIMARY KEY, pla00_descri TEXT, pla00_codtyp INTEGER)');
      await db.execute('CREATE TABLE cadcli00 (cli00_codigo INTEGER PRIMARY KEY, cli00_crelim REAL, cli00_creatu REAL)');
      await db.insert('cadpla00', {'pla00_codigo': 1, 'pla00_descri': 'A VISTA', 'pla00_codtyp': 0});
      await db.insert('cadcli00', {'cli00_codigo': 10, 'cli00_crelim': 100.0, 'cli00_creatu': 50.0});
      await db.close();

      // Pedido de R$ 500 para cliente com limite de R$ 50 -> à vista não bloqueia
      AppState().ven_ignlimfis = 0;
      final res = await BloqueioFinanceiroService.verificaFechamentoPedido(
        clienteCodigo: 10,
        valorPedido: 500.0,
        planoCodigo: '1',
        dbPathOverride: dbPath,
      );
      expect(res.bloqueado, isFalse);
    });

    test('verificaFechamentoPedido bypasses credit check when ven_ignlimfis == 1', () async {
      final dbPath = p.join(await getDatabasesPath(), 'test_fechamento_ign.db');
      final db = await openDatabase(dbPath);
      await db.execute('DROP TABLE IF EXISTS cadpla00');
      await db.execute('DROP TABLE IF EXISTS cadcli00');
      await db.execute('CREATE TABLE cadpla00 (pla00_codigo INTEGER PRIMARY KEY, pla00_descri TEXT, pla00_codtyp INTEGER)');
      await db.execute('CREATE TABLE cadcli00 (cli00_codigo INTEGER PRIMARY KEY, cli00_crelim REAL, cli00_creatu REAL)');
      await db.insert('cadpla00', {'pla00_codigo': 2, 'pla00_descri': '30 DIAS', 'pla00_codtyp': 1});
      await db.insert('cadcli00', {'cli00_codigo': 10, 'cli00_crelim': 100.0, 'cli00_creatu': 50.0});
      await db.close();

      // Representante com permissão para ignorar limite
      AppState().ven_ignlimfis = 1;
      final res = await BloqueioFinanceiroService.verificaFechamentoPedido(
        clienteCodigo: 10,
        valorPedido: 500.0,
        planoCodigo: '2',
        dbPathOverride: dbPath,
      );
      expect(res.bloqueado, isFalse);
    });

    test('verificaFechamentoPedido blocks on term sales when credit exceeded and ven_ignlimfis == 0', () async {
      final dbPath = p.join(await getDatabasesPath(), 'test_fechamento_block.db');
      final db = await openDatabase(dbPath);
      await db.execute('DROP TABLE IF EXISTS cadpla00');
      await db.execute('DROP TABLE IF EXISTS cadcli00');
      await db.execute('CREATE TABLE cadpla00 (pla00_codigo INTEGER PRIMARY KEY, pla00_descri TEXT, pla00_codtyp INTEGER)');
      await db.execute('CREATE TABLE cadcli00 (cli00_codigo INTEGER PRIMARY KEY, cli00_crelim REAL, cli00_creatu REAL)');
      await db.insert('cadpla00', {'pla00_codigo': 2, 'pla00_descri': '30 DIAS', 'pla00_codtyp': 1});
      await db.insert('cadcli00', {'cli00_codigo': 10, 'cli00_crelim': 100.0, 'cli00_creatu': 50.0});
      await db.close();

      AppState().ven_ignlimfis = 0;
      final res = await BloqueioFinanceiroService.verificaFechamentoPedido(
        clienteCodigo: 10,
        valorPedido: 500.0,
        planoCodigo: '2',
        dbPathOverride: dbPath,
      );
      expect(res.bloqueado, isTrue);
      expect(res.motivo, contains('Limite de crédito insuficiente'));
    });

    test('listarTitulosVencidos returns overdue invoices from dup00', () async {
      final dbPath = p.join(await getDatabasesPath(), 'test_dup00.db');
      final db = await openDatabase(dbPath);
      await db.execute('DROP TABLE IF EXISTS dup00');
      await db.execute('''
        CREATE TABLE dup00 (
          dup00_codigo TEXT PRIMARY KEY,
          dup00_codcli INTEGER,
          dup00_datemi TEXT,
          dup00_datven TEXT,
          dup00_valori REAL,
          dup00_valdev REAL,
          dup00_valpag REAL
        )
      ''');
      // Vencido
      await db.insert('dup00', {
        'dup00_codigo': 'FAT-1001',
        'dup00_codcli': 55,
        'dup00_datemi': '2026-01-01',
        'dup00_datven': '2026-02-01',
        'dup00_valori': 350.0,
        'dup00_valdev': 350.0,
        'dup00_valpag': 0.0,
      });
      // Em dia / futuro
      await db.insert('dup00', {
        'dup00_codigo': 'FAT-1002',
        'dup00_codcli': 55,
        'dup00_datemi': '2026-08-01',
        'dup00_datven': '2026-12-31',
        'dup00_valori': 200.0,
        'dup00_valdev': 200.0,
        'dup00_valpag': 0.0,
      });
      await db.close();

      final titulos = await BloqueioFinanceiroService.listarTitulosVencidos(55, dbPathOverride: dbPath);
      expect(titulos.length, equals(1));
      expect(titulos.first.numeroDocumento, equals('FAT-1001'));
      expect(titulos.first.valor, equals(350.0));
      expect(titulos.first.diasAtraso, greaterThan(0));
    });

    test('validaSenhaSupervisor returns true for matching password in cadrep00 or AppState', () async {
      final dbPath = p.join(await getDatabasesPath(), 'test_cadrep_sup.db');
      final db = await openDatabase(dbPath);
      await db.execute('DROP TABLE IF EXISTS cadrep00');
      await db.execute('CREATE TABLE cadrep00 (ven00_codigo INTEGER PRIMARY KEY, ven00_descri TEXT, ven00_passet TEXT)');
      await db.rawInsert('INSERT INTO cadrep00 (ven00_codigo, ven00_descri, ven00_passet) VALUES (1, "SUPERVISOR", "SUP123")');
      await db.close();

      final valido = await BloqueioFinanceiroService.validaSenhaSupervisor('SUP123', dbPathOverride: dbPath);
      expect(valido, isTrue);

      final invalido = await BloqueioFinanceiroService.validaSenhaSupervisor('ERRADA', dbPathOverride: dbPath);
      expect(invalido, isFalse);
    });
  });
}
