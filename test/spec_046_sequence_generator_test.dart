import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:forca_de_vendas/services/sequence_generator_service.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late Database db;

  setUp(() async {
    db = await databaseFactory.openDatabase(inMemoryDatabasePath);
    // Cria tabela de pacotes conforme ffrmdiggerpac00.cpp
    await db.execute('''
      CREATE TABLE pckvenpac00 (
        pac00_pacrep INTEGER,
        pac00_paccod INTEGER,
        pac00_pacsrc TEXT PRIMARY KEY,
        pac00_pacdat TEXT,
        pac00_pacqtd INTEGER DEFAULT 0,
        pac00_pactot REAL DEFAULT 0,
        pac00_sttpac INTEGER DEFAULT 0,
        pac00_sttenv INTEGER DEFAULT 0
      )
    ''');
  });

  tearDown(() async {
    await db.close();
  });

  group('Seam 1: Sequencial de Pacote (pckvenpac00 / pac00_paccod)', () {
    test('retorna 1000 quando a base estiver zerada (sem registros)', () async {
      final service = SequenceGeneratorService(db);
      final ipac = await service.obterProximoCodigoPacote(71);
      expect(ipac, 1000);
    });

    test('retorna 1000 quando ultimo_pacote < 1000', () async {
      await db.insert('pckvenpac00', {
        'pac00_pacrep': 71,
        'pac00_paccod': 500,
        'pac00_pacsrc': 'p71-500.pac',
      });

      final service = SequenceGeneratorService(db);
      final ipac = await service.obterProximoCodigoPacote(71);
      expect(ipac, 1000);
    });

    test('realiza incremento normal (1000 -> 1001 e 1500 -> 1501)', () async {
      await db.insert('pckvenpac00', {
        'pac00_pacrep': 71,
        'pac00_paccod': 1000,
        'pac00_pacsrc': 'p71-1000.pac',
      });

      final service = SequenceGeneratorService(db);
      expect(await service.obterProximoCodigoPacote(71), 1001);

      await db.insert('pckvenpac00', {
        'pac00_pacrep': 71,
        'pac00_paccod': 1500,
        'pac00_pacsrc': 'p71-1500.pac',
      });

      expect(await service.obterProximoCodigoPacote(71), 1501);
    });

    test('realiza rollover para 1000 quando atinge 9999 ou superior', () async {
      await db.insert('pckvenpac00', {
        'pac00_pacrep': 71,
        'pac00_paccod': 9999,
        'pac00_pacsrc': 'p71-9999.pac',
      });

      final service = SequenceGeneratorService(db);
      expect(await service.obterProximoCodigoPacote(71), 1000);

      // Caso com valor inconsistente superior a 9999
      await db.insert('pckvenpac00', {
        'pac00_pacrep': 71,
        'pac00_paccod': 10500,
        'pac00_pacsrc': 'p71-10500.pac',
      });

      expect(await service.obterProximoCodigoPacote(71), 1000);
    });

    test('isola a sequência por representante (pac00_pacrep)', () async {
      await db.insert('pckvenpac00', {
        'pac00_pacrep': 71,
        'pac00_paccod': 1250,
        'pac00_pacsrc': 'p71-1250.pac',
      });
      await db.insert('pckvenpac00', {
        'pac00_pacrep': 85,
        'pac00_paccod': 2100,
        'pac00_pacsrc': 'p85-2100.pac',
      });

      final service = SequenceGeneratorService(db);
      expect(await service.obterProximoCodigoPacote(71), 1251);
      expect(await service.obterProximoCodigoPacote(85), 2101);
      expect(await service.obterProximoCodigoPacote(99), 1000); // zerado para o rep 99
    });
  });

  group('Seam 2: Sequencial de Pedido (pckvendig00 / dig00_digcod por filial)', () {
    setUp(() async {
      await db.execute('''
        CREATE TABLE pckvendig00 (
          dig00_digfil INTEGER,
          dig00_digcod INTEGER,
          dig00_digrep INTEGER,
          dig00_clicod INTEGER,
          dig00_paccod INTEGER,
          dig00_pacstr TEXT,
          dig00_sttenv INTEGER DEFAULT 0,
          dig00_datenv TEXT,
          PRIMARY KEY (dig00_digfil, dig00_digcod)
        )
      ''');
    });

    test('incrementa sequencialmente os pedidos por filial (MAX(dig00_digcod) + 1)', () async {
      await db.insert('pckvendig00', {
        'dig00_digfil': 1,
        'dig00_digcod': 100,
        'dig00_digrep': 71,
      });
      await db.insert('pckvendig00', {
        'dig00_digfil': 1,
        'dig00_digcod': 101,
        'dig00_digrep': 71,
      });

      final service = SequenceGeneratorService(db);
      final next = await service.obterProximoCodigoPedido(1, 71);
      expect(next, 102);
    });

    test('isola a sequência de pedidos estritamente por filial', () async {
      await db.insert('pckvendig00', {
        'dig00_digfil': 1,
        'dig00_digcod': 50,
        'dig00_digrep': 71,
      });
      await db.insert('pckvendig00', {
        'dig00_digfil': 2,
        'dig00_digcod': 200,
        'dig00_digrep': 71,
      });

      final service = SequenceGeneratorService(db);
      expect(await service.obterProximoCodigoPedido(1, 71), 51);
      expect(await service.obterProximoCodigoPedido(2, 71), 201);
      expect(await service.obterProximoCodigoPedido(3, 71), 1); // filial sem pedidos
    });

    test('recupera valor padrão de cadrep00 se base estiver zerada', () async {
      await db.execute('''
        CREATE TABLE cadrep00 (
          ven00_codigo INTEGER PRIMARY KEY,
          ven00_pedseq INTEGER DEFAULT 0
        )
      ''');
      await db.insert('cadrep00', {
        'ven00_codigo': 71,
        'ven00_pedseq': 5000,
      });

      final service = SequenceGeneratorService(db);
      // Base pckvendig00 vazia para filial 1 -> pega cadrep00 (5000) + 1 = 5001
      final next = await service.obterProximoCodigoPedido(1, 71);
      expect(next, 5001);
    });
  });

  group('Seam 3: Empacotamento e Atualização de Pedidos (pckvenpac00 / pckvendig00)', () {
    setUp(() async {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS pckvendig00 (
          dig00_digfil INTEGER,
          dig00_digcod INTEGER PRIMARY KEY,
          dig00_digrep INTEGER,
          dig00_clicod INTEGER,
          dig00_paccod INTEGER,
          dig00_pacstr TEXT,
          dig00_sttenv INTEGER DEFAULT 0,
          dig00_datenv TEXT
        )
      ''');

      await db.insert('pckvendig00', {
        'dig00_digfil': 1,
        'dig00_digcod': 10,
        'dig00_digrep': 71,
        'dig00_sttenv': 0,
        'dig00_pacstr': '',
      });
      await db.insert('pckvendig00', {
        'dig00_digfil': 1,
        'dig00_digcod': 11,
        'dig00_digrep': 71,
        'dig00_sttenv': 0,
        'dig00_pacstr': '',
      });
    });

    test('registra pacote na pckvenpac00 e atualiza pedidos com dig00_paccod, dig00_pacstr, dig00_sttenv=2 e dig00_datenv', () async {
      final service = SequenceGeneratorService(db);
      final hoje = DateTime.now().toString().split(' ').first;

      await service.registrarPacoteEPedidos(
        codigoVendedor: 71,
        ipac: 1000,
        pedidosIds: [10, 11],
        totalValorLote: 350.50,
      );

      // 1. Verifica inserção na pckvenpac00
      final pacRows = await db.rawQuery('SELECT * FROM pckvenpac00 WHERE pac00_pacrep = 71 AND pac00_paccod = 1000');
      expect(pacRows, isNotEmpty);
      expect(pacRows.first['pac00_pacrep'], 71);
      expect(pacRows.first['pac00_paccod'], 1000);
      expect(pacRows.first['pac00_pacsrc'], 'p71-1000.pac');
      expect(pacRows.first['pac00_pacqtd'], 2);
      expect(pacRows.first['pac00_pactot'], 350.50);
      expect(pacRows.first['pac00_pacdat'], hoje);

      // 2. Verifica atualização dos pedidos selecionados na pckvendig00
      final pedRows = await db.rawQuery('SELECT * FROM pckvendig00 WHERE dig00_digcod IN (10, 11) ORDER BY dig00_digcod');
      expect(pedRows.length, 2);
      for (final r in pedRows) {
        expect(r['dig00_paccod'], 1000);
        expect(r['dig00_pacstr'], 'p71-1000');
        expect(r['dig00_sttenv'], 2); // pvddeEMPACOTE
        expect(r['dig00_datenv'], hoje);
      }
    });

    test('formata nome de arquivo e pacstr conforme padrão estrito', () {
      final service = SequenceGeneratorService(db);
      expect(service.formatarNomeArquivoPacote(71, 1000), 'p71-1000.pac');
      expect(service.formatarPacStr(71, 1000), 'p71-1000');
    });
  });

  group('Seam 4: Integração com LocalSalesDatabaseService e Views', () {
    test('view pckvendig00 reflete pckvendig000 e suporta consulta de max_cod', () async {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS pckvendig000 (
          ped00_numped INTEGER PRIMARY KEY,
          ped00_codfil INTEGER,
          dig00_digcod INTEGER,
          dig00_digfil INTEGER
        )
      ''');
      await db.execute('CREATE VIEW IF NOT EXISTS pckvendig00_view AS SELECT * FROM pckvendig000');

      await db.insert('pckvendig000', {
        'ped00_numped': 9001,
        'ped00_codfil': 1,
        'dig00_digcod': 9001,
        'dig00_digfil': 1,
      });

      final rows = await db.rawQuery('SELECT COALESCE(MAX(dig00_digcod), 0) as max_cod FROM pckvendig00_view WHERE dig00_digfil = 1');
      expect(rows.first['max_cod'], 9001);
    });
  });
}
