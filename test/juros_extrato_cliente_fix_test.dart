import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:forca_de_vendas/services/receber_duplicatas_service.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('parseData — formatos DD/MM/AAAA e variantes', () {
    test('formato DD/MM/AAAA retorna DateTime correto', () {
      final dt = ReceberDuplicatasService.parseData('26/09/2026');
      expect(dt, DateTime(2026, 9, 26));
    });

    test('formato DD/MM/AAAA com dia 01 e mês 01', () {
      final dt = ReceberDuplicatasService.parseData('01/01/2025');
      expect(dt, DateTime(2025, 1, 1));
    });

    test('formato AAAA-MM-DD retorna DateTime correto', () {
      final dt = ReceberDuplicatasService.parseData('2026-08-15');
      expect(dt, DateTime(2026, 8, 15));
    });

    test('formato AAAA-MM-DD com timestamp ISO é truncado para dia', () {
      final dt = ReceberDuplicatasService.parseData('2026-08-15T14:30:00');
      expect(dt, DateTime(2026, 8, 15));
    });

    test('formato AAAA-MM-DD com espaço e hora é truncado', () {
      final dt = ReceberDuplicatasService.parseData('2026-08-15 14:30:00');
      expect(dt, DateTime(2026, 8, 15));
    });

    test('formato AAAAMMDD compacto retorna DateTime correto', () {
      final dt = ReceberDuplicatasService.parseData('20260815');
      expect(dt, DateTime(2026, 8, 15));
    });

    test('valor nulo retorna null', () {
      expect(ReceberDuplicatasService.parseData(null), isNull);
    });

    test('string vazia retorna null', () {
      expect(ReceberDuplicatasService.parseData(''), isNull);
    });

    test('DateTime passado diretamente é normalizado (sem hora)', () {
      final dt = ReceberDuplicatasService.parseData(DateTime(2026, 5, 10, 14, 30));
      expect(dt, DateTime(2026, 5, 10));
    });
  });

  group('calcularJurosMora — edge cases', () {
    test('saldo negativo retorna 0', () {
      final juros = ReceberDuplicatasService.calcularJurosMora(
        saldoDevedor: -100.0,
        taxaJurosDiaria: 0.1,
        diasAtraso: 10,
      );
      expect(juros, 0.0);
    });

    test('arredondamento correto para 2 casas decimais', () {
      // 333.33 * (0.07 / 100) * 13 = 3.033303 → arredondado para 3.03
      final juros = ReceberDuplicatasService.calcularJurosMora(
        saldoDevedor: 333.33,
        taxaJurosDiaria: 0.07,
        diasAtraso: 13,
      );
      expect(juros, closeTo(3.03, 0.01));
    });
  });

  group('TituloDuplicataItem — propriedade pctJurDay', () {
    test('pctJurDay tem valor default 0.0', () {
      final t = TituloDuplicataItem(
        codigo: 1,
        codCli: 1,
        numeroDocumento: 'T-001',
        dataVencimento: DateTime(2026, 1, 1),
        valorOriginal: 100.0,
        valorPago: 0.0,
        saldoDevedor: 100.0,
        diasAtraso: 0,
        isVencido: false,
        totalComJuros: 100.0,
      );
      expect(t.pctJurDay, 0.0);
    });

    test('pctJurDay pode ser preenchido explicitamente', () {
      final t = TituloDuplicataItem(
        codigo: 1,
        codCli: 1,
        numeroDocumento: 'T-001',
        dataVencimento: DateTime(2026, 1, 1),
        valorOriginal: 100.0,
        valorPago: 0.0,
        saldoDevedor: 100.0,
        diasAtraso: 10,
        isVencido: true,
        totalComJuros: 101.0,
        pctJurDay: 0.10,
      );
      expect(t.pctJurDay, 0.10);
    });
  });

  group('dup00_pctjurday — hierarquia de taxa no SQLite', () {
    late String testDbPath;
    late Database db;

    setUp(() async {
      final tempDir = await Directory.systemTemp.createTemp('pctjurday_test_');
      testDbPath = p.join(tempDir.path, 'test_pctjurday.db');
      db = await openDatabase(testDbPath, version: 1, onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE cadrep00 (
            ven00_codigo INTEGER PRIMARY KEY,
            ven00_txajur REAL DEFAULT 0
          )
        ''');

        await db.execute('''
          CREATE TABLE cadcli00 (
            cli00_codigo INTEGER PRIMARY KEY,
            cli00_descri TEXT,
            cli00_fantas TEXT,
            cli00_ciddes TEXT,
            cli00_estsgl TEXT,
            cli00_crelim REAL DEFAULT 0,
            cli00_creatu REAL DEFAULT 0
          )
        ''');

        await db.execute('''
          CREATE TABLE finrecdup00 (
            dup00_codigo INTEGER PRIMARY KEY,
            dup00_codcli INTEGER,
            dup00_numero TEXT,
            dup00_datemi TEXT,
            dup00_datven TEXT,
            dup00_valori REAL DEFAULT 0,
            dup00_valdev REAL DEFAULT 0,
            dup00_valpag REAL DEFAULT 0,
            dup00_valjur REAL DEFAULT 0,
            dup00_pctjurday REAL DEFAULT 0,
            dup00_codven INTEGER DEFAULT 0,
            dup00_codagt INTEGER DEFAULT 0,
            dup00_codcob INTEGER DEFAULT 0
          )
        ''');
      });

      // Representante com taxa 0.05% ao dia
      await db.insert('cadrep00', {'ven00_codigo': 5, 'ven00_txajur': 0.05});
      // Representante sem taxa
      await db.insert('cadrep00', {'ven00_codigo': 6, 'ven00_txajur': 0.0});

      await db.insert('cadcli00', {
        'cli00_codigo': 10,
        'cli00_descri': 'LOJA TESTE PCTJURDAY',
        'cli00_fantas': 'TESTE',
        'cli00_ciddes': 'São Paulo',
        'cli00_estsgl': 'SP',
        'cli00_crelim': 10000.0,
        'cli00_creatu': 5000.0,
      });

      // Duplicata COM dup00_pctjurday = 0.12 (prioridade máxima)
      await db.insert('finrecdup00', {
        'dup00_codigo': 1,
        'dup00_codcli': 10,
        'dup00_numero': 'DUP-001',
        'dup00_datemi': '01/08/2026',
        'dup00_datven': '15/08/2026', // vencida
        'dup00_valori': 500.0,
        'dup00_valdev': 500.0,
        'dup00_valpag': 0.0,
        'dup00_valjur': 0.0,
        'dup00_pctjurday': 0.12, // taxa da duplicata
        'dup00_codven': 5,       // vendedor com taxa 0.05 (deve ser ignorado)
      });

      // Duplicata SEM dup00_pctjurday (deve cair no vendedor 0.05)
      await db.insert('finrecdup00', {
        'dup00_codigo': 2,
        'dup00_codcli': 10,
        'dup00_numero': 'DUP-002',
        'dup00_datemi': '01/08/2026',
        'dup00_datven': '10/08/2026', // vencida
        'dup00_valori': 200.0,
        'dup00_valdev': 200.0,
        'dup00_valpag': 0.0,
        'dup00_valjur': 0.0,
        'dup00_pctjurday': 0.0, // sem taxa na duplicata
        'dup00_codven': 5,       // vendedor com taxa 0.05
      });

      // Duplicata SEM pctjurday e SEM taxa vendedor → fallback dup00_valjur
      await db.insert('finrecdup00', {
        'dup00_codigo': 3,
        'dup00_codcli': 10,
        'dup00_numero': 'DUP-003',
        'dup00_datemi': '01/08/2026',
        'dup00_datven': '05/08/2026', // vencida
        'dup00_valori': 100.0,
        'dup00_valdev': 100.0,
        'dup00_valpag': 0.0,
        'dup00_valjur': 8.50,   // juros pré-calculado ERP
        'dup00_pctjurday': 0.0,
        'dup00_codven': 6,       // vendedor sem taxa
      });
    });

    tearDown(() async {
      await db.close();
      try {
        await File(testDbPath).delete();
      } catch (_) {}
    });

    test('carregarTitulosCliente: pctJurDay prioritário sobre taxa vendedor', () async {
      final hoje = DateTime(2026, 9, 2);

      final titulos = await ReceberDuplicatasService.carregarTitulosCliente(
        10,
        dbOverride: db,
        hojeRef: hoje,
      );

      expect(titulos.length, 3);

      // DUP-001: pctJurDay=0.12 (prioridade), vendedor=0.05 (ignorado)
      // Juros = 500 * (0.12 / 100) * 18 dias = 10.80
      final t1 = titulos.firstWhere((t) => t.numeroDocumento == 'DUP-001');
      expect(t1.pctJurDay, 0.12);
      expect(t1.taxaJurosDiaria, 0.12);
      expect(t1.valorJuros, 10.80);
      expect(t1.diasAtraso, 18);

      // DUP-002: pctJurDay=0, cai no vendedor=0.05
      // Juros = 200 * (0.05 / 100) * 23 dias = 2.30
      final t2 = titulos.firstWhere((t) => t.numeroDocumento == 'DUP-002');
      expect(t2.pctJurDay, 0.0);
      expect(t2.taxaJurosDiaria, 0.05);
      expect(t2.valorJuros, 2.30);
      expect(t2.diasAtraso, 23);

      // DUP-003: pctJurDay=0, vendedor=0 → fallback dup00_valjur=8.50
      final t3 = titulos.firstWhere((t) => t.numeroDocumento == 'DUP-003');
      expect(t3.pctJurDay, 0.0);
      expect(t3.valorJuros, 8.50);
      expect(t3.diasAtraso, 28);
    });

    test('listarClientesComDebito: pctJurDay prioritário sobre taxa vendedor', () async {
      final hoje = DateTime(2026, 9, 2);

      final resultado = await ReceberDuplicatasService.listarClientesComDebito(
        filtro: FiltroReceber.todos,
        dbOverride: db,
        hojeRef: hoje,
      );

      expect(resultado.length, 1);
      final cliente = resultado.first;

      // DUP-001: 500 * (0.12/100) * 18 = 10.80
      final titDup001 = cliente.titulos.firstWhere((t) => t.numeroDocumento == 'DUP-001');
      expect(titDup001.pctJurDay, 0.12);
      expect(titDup001.valorJuros, 10.80);

      // DUP-002: 200 * (0.05/100) * 23 = 2.30
      final titDup002 = cliente.titulos.firstWhere((t) => t.numeroDocumento == 'DUP-002');
      expect(titDup002.pctJurDay, 0.0);
      expect(titDup002.valorJuros, 2.30);

      // DUP-003: fallback dup00_valjur = 8.50
      final titDup003 = cliente.titulos.firstWhere((t) => t.numeroDocumento == 'DUP-003');
      expect(titDup003.valorJuros, 8.50);

      // Total juros = 10.80 + 2.30 + 8.50 = 21.60
      expect(cliente.totalJuros, closeTo(21.60, 0.01));
    });

    test('carregarTitulosCliente: taxaJurosOverride não sobrescreve pctJurDay', () async {
      final hoje = DateTime(2026, 9, 2);

      final titulos = await ReceberDuplicatasService.carregarTitulosCliente(
        10,
        dbOverride: db,
        hojeRef: hoje,
        taxaJurosOverride: 0.99, // taxa forçada pelo chamador
      );

      // DUP-001 tem pctJurDay=0.12 → deve usar 0.12 (prioridade), não 0.99
      final t1 = titulos.firstWhere((t) => t.numeroDocumento == 'DUP-001');
      expect(t1.taxaJurosDiaria, 0.12);
      expect(t1.valorJuros, 10.80);

      // DUP-002 tem pctJurDay=0 → deve usar taxaJurosOverride=0.99
      // Juros = 200 * (0.99 / 100) * 23 = 45.54
      final t2 = titulos.firstWhere((t) => t.numeroDocumento == 'DUP-002');
      expect(t2.taxaJurosDiaria, 0.99);
      expect(t2.valorJuros, 45.54);
    });
  });
}
