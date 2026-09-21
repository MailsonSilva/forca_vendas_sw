import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:forca_de_vendas/action_code/listar_pedidos_pendentes.dart';
import 'package:forca_de_vendas/services/status_envio_db.dart';
import 'package:forca_de_vendas/data/services/local_sales_database_service.dart';
import 'package:forca_de_vendas/app_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late String dbPath;
  late Directory tempDir;
  File? backupFile;
  bool hadOriginalDb = false;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AppState().initializePersistedState();

    tempDir = await Directory.systemTemp.createTemp('test_pac_temp_');
    const MethodChannel channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (MethodCall methodCall) async {
        return tempDir.path;
      },
    );

    final databasesPath = await getDatabasesPath();
    dbPath = p.join(databasesPath, 'dbforcacad001.db');
    final realFile = File(dbPath);
    hadOriginalDb = await realFile.exists();
    if (hadOriginalDb) {
      final bPath = p.join(databasesPath, 'dbforcacad001_test_clone_backup.db');
      backupFile = await realFile.copy(bPath);
    }

    final db = await openDatabase(dbPath);
    await db.execute('DROP VIEW IF EXISTS pckvendig00');
    await db.execute('DROP TABLE IF EXISTS pckvendig00');
    await db.execute('DROP TABLE IF EXISTS pckvendig000');
    await db.execute('DROP TABLE IF EXISTS pckvendig010');
    await db.execute('DROP TABLE IF EXISTS cadcli00');

    await db.execute('''
      CREATE TABLE cadcli00 (
        cli00_codigo INTEGER PRIMARY KEY,
        cli00_descri TEXT,
        cli00_fantasi TEXT,
        cli00_cgc TEXT,
        cli00_cidade TEXT,
        cli00_limite REAL,
        cli00_endereco TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE pckvendig000 (
        ped00_numped INTEGER PRIMARY KEY,
        ped00_codcli INTEGER,
        ped00_clides TEXT,
        ped00_codlin TEXT,
        ped00_lindes TEXT,
        ped00_codpla TEXT,
        ped00_plades TEXT,
        ped00_codage INTEGER,
        ped00_agedes TEXT,
        ped00_datsys TEXT,
        ped00_sttdig INTEGER,
        ped00_sttenv INTEGER,
        ped00_fattot REAL,
        ped00_digtot REAL,
        ped00_pacstr TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE pckvendig010 (
        ped10_numped INTEGER,
        ped10_seqnum INTEGER,
        ped10_codpro INTEGER,
        ped10_prodes TEXT,
        ped10_qtdped REAL,
        ped10_vlruni REAL,
        ped10_vlrtot REAL,
        PRIMARY KEY (ped10_numped, ped10_seqnum)
      )
    ''');
    await db.close();
  });

  tearDown(() async {
    try {
      await databaseFactory.deleteDatabase(dbPath);
    } catch (_) {}
    if (tempDir.existsSync()) {
      try { tempDir.deleteSync(recursive: true); } catch (_) {}
    }
    if (hadOriginalDb && backupFile != null && await backupFile!.exists()) {
      await backupFile!.copy(dbPath);
      await backupFile!.delete();
    }
  });

  group('Fluxo de Clonagem de Pedidos', () {
    test('clonarPedidoLocal duplica cabeçalho e itens em estado de rascunho com novo ID incremental', () async {
      final db = await LocalSalesDatabaseService.getDatabase();

      // Insere cadastro do cliente
      await db.rawInsert('''
        INSERT INTO cadcli00 (cli00_codigo, cli00_descri, cli00_fantasi, cli00_cgc, cli00_cidade, cli00_limite, cli00_endereco)
        VALUES (501, 'MERCADO CENTRAL LTDA', 'MERCADO CENTRAL', '12.345.678/0001-90', 'TERESINA', 5000.0, 'RUA PRINCIPAL 100')
      ''');

      // Insere pedido original concluído / empacotado
      await db.rawInsert('''
        INSERT INTO pckvendig000 (
          ped00_numped, ped00_codcli, ped00_clides, ped00_codlin, ped00_lindes,
          ped00_codpla, ped00_plades, ped00_sttdig, ped00_sttenv, ped00_pacstr, ped00_fattot
        ) VALUES (
          100, 501, 'MERCADO CENTRAL', '10', 'LINHA PRINCIPAL',
          '30', 'A VISTA 30D', 1, 2, 'p71-1.pac', 150.00
        )
      ''');

      await db.rawInsert('''
        INSERT INTO pckvendig010 (ped10_numped, ped10_seqnum, ped10_codpro, ped10_prodes, ped10_qtdped, ped10_vlruni, ped10_vlrtot)
        VALUES (100, 1, 1001, 'PRODUTO A', 2.0, 50.0, 100.0)
      ''');
      await db.rawInsert('''
        INSERT INTO pckvendig010 (ped10_numped, ped10_seqnum, ped10_codpro, ped10_prodes, ped10_qtdped, ped10_vlruni, ped10_vlrtot)
        VALUES (100, 2, 1002, 'PRODUTO B', 1.0, 50.0, 50.0)
      ''');

      // Executa clonagem
      final info = await clonarPedidoLocal(100);

      expect(info, isNotNull);
      expect(info!.novoPedidoId, equals(101));
      expect(info.clienteCodigo, equals(501));
      expect(info.clienteNome, equals('MERCADO CENTRAL'));
      expect(info.linhaCodigo, equals('10'));
      expect(info.linhaDescricao, equals('LINHA PRINCIPAL'));
      expect(info.planoCodigo, equals('30'));
      expect(info.planoDescricao, equals('A VISTA 30D'));
      expect(info.clienteCnpj, equals('12.345.678/0001-90'));
      expect(info.clienteCidade, equals('TERESINA'));
      expect(info.clienteLimite, equals('5.000,00'));
      expect(info.clienteEndereco, equals('RUA PRINCIPAL 100'));

      // Verifica dados persistidos para o novo ID no SQLite
      final novoCab = await db.rawQuery('SELECT * FROM pckvendig000 WHERE ped00_numped = 101');
      expect(novoCab.length, equals(1));
      expect(novoCab.first['ped00_sttdig'], equals(0)); // Rascunho / Em Digitação (Em Aberto)
      expect(novoCab.first['ped00_sttenv'], equals(0)); // Não enviado
      expect(novoCab.first['ped00_pacstr'], equals('')); // Pacote limpo

      final novosItens = await db.rawQuery('SELECT * FROM pckvendig010 WHERE ped10_numped = 101 ORDER BY ped10_seqnum');
      expect(novosItens.length, equals(2));
      expect(novosItens[0]['ped10_codpro'], equals(1001));
      expect(novosItens[1]['ped10_codpro'], equals(1002));
      expect(novosItens[0]['ped10_qtdped'], equals(2.0));
      expect(novosItens[1]['ped10_qtdped'], equals(1.0));
    });
  });

  group('Gestão de Pacotes e Atualização Atômica de Status', () {
    test('StatusEnvioDb.marcarPacoteEnviado atualiza todos os pedidos vinculados a ped00_sttenv = 2', () async {
      final db = await LocalSalesDatabaseService.getDatabase();

      // Insere pedidos associados a um lote de pacote
      await db.rawInsert('''
        INSERT INTO pckvendig000 (ped00_numped, ped00_codcli, ped00_sttdig, ped00_sttenv, ped00_pacstr)
        VALUES (201, 1, 1, 1, 'p71-10.pac')
      ''');
      await db.rawInsert('''
        INSERT INTO pckvendig000 (ped00_numped, ped00_codcli, ped00_sttdig, ped00_sttenv, ped00_pacstr)
        VALUES (202, 2, 1, 1, 'p71-10.pac')
      ''');

      // Executa marcação após upload confirmado
      await StatusEnvioDb().marcarPacoteEnviado('p71-10.pac');

      final rows = await db.rawQuery('SELECT ped00_numped, ped00_sttenv FROM pckvendig000 WHERE ped00_pacstr = "p71-10.pac"');
      expect(rows.length, equals(2));
      for (final r in rows) {
        expect(r['ped00_sttenv'], equals(2));
      }
    });

    test('listarPacotesAgrupados lista pacotes pendentes e transmitidos corretamente', () async {
      final db = await LocalSalesDatabaseService.getDatabase();

      await db.rawInsert('''
        INSERT INTO pckvendig000 (ped00_numped, ped00_codcli, ped00_sttdig, ped00_sttenv, ped00_pacstr, ped00_fattot)
        VALUES (301, 10, 1, 2, 'p71-50.pac', 89.90)
      ''');

      final pacotes = await listarPacotesAgrupados(filtro: 'todos');
      expect(pacotes.any((p) => p.nomeArquivo == 'p71-50.pac'), isTrue);

      final pacEnviado = pacotes.firstWhere((p) => p.nomeArquivo == 'p71-50.pac');
      expect(pacEnviado.isEnviado, isTrue);
      expect(pacEnviado.totalValor, equals(89.90));
    });
  });
}
