import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:forca_de_vendas/action_code/listar_pedidos_pendentes.dart';
import 'package:forca_de_vendas/action_code/listar_clientes_pendentes.dart';
import 'package:forca_de_vendas/action_code/gerar_pacote.dart';
import 'package:forca_de_vendas/data/services/local_sales_database_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('pac_ferramentas_temp_');
    const MethodChannel channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (MethodCall methodCall) async {
        return tempDir.path;
      },
    );

    final db = await LocalSalesDatabaseService.getDatabase();
    await db.execute('DROP TABLE IF EXISTS pckvendig000');
    await db.execute('DROP TABLE IF EXISTS pckvendig010');
    await db.execute('DROP TABLE IF EXISTS pac00');
    await db.execute('DROP TABLE IF EXISTS cadcli00');

    await db.execute('''
      CREATE TABLE pckvendig000 (
        ped00_numped INTEGER PRIMARY KEY,
        ped00_codcli INTEGER,
        ped00_codlin INTEGER,
        ped00_codpla INTEGER,
        ped00_codfil INTEGER,
        ped00_codrep INTEGER,
        ped00_codagt INTEGER,
        ped00_digtab INTEGER,
        ped00_digcob INTEGER,
        ped00_bonfrcven INTEGER DEFAULT 0,
        ped00_sttdig INTEGER DEFAULT 0,
        ped00_sttenv INTEGER DEFAULT 0,
        ped00_datsys TEXT,
        ped00_clides TEXT,
        ped00_lindes TEXT,
        ped00_plades TEXT,
        ped00_digtot REAL DEFAULT 0,
        ped00_fattot REAL DEFAULT 0,
        ped00_subtot REAL DEFAULT 0,
        ped00_bontot REAL DEFAULT 0,
        ped00_destot REAL DEFAULT 0,
        ped00_pacstr TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE pckvendig010 (
        ped10_numped INTEGER,
        ped10_seq INTEGER DEFAULT 1,
        ped10_codprd TEXT,
        ped10_descri TEXT,
        ped10_unidpri TEXT,
        ped10_qtdped REAL DEFAULT 0,
        ped10_pcosub REAL DEFAULT 0,
        ped10_totprd REAL DEFAULT 0,
        ped10_qtdbon REAL DEFAULT 0,
        ped10_sttbon INTEGER DEFAULT 0,
        ped10_codcmb TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE pac00 (
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

    await db.execute('''
      CREATE TABLE cadcli00 (
        cli00_codigo INTEGER PRIMARY KEY,
        cli00_descri TEXT,
        cli00_fantas TEXT,
        cli00_cpfcnp TEXT,
        cli00_ciddes TEXT,
        cli00_estsgl TEXT,
        cli00_sttenv INTEGER DEFAULT 0
      )
    ''');
  });

  group('Central de Transmissão e Empacotamento (Menu Ferramentas)', () {
    test('listarPedidosPendentes e empacotamento manual via gerarPacote', () async {
      final db = await LocalSalesDatabaseService.getDatabase();

      // Insere pedido pendente de empacotamento (sttdig = 1, sttenv = 0, pacstr = '')
      await db.rawInsert('''
        INSERT INTO pckvendig000 (
          ped00_numped, ped00_codcli, ped00_clides, ped00_codrep, ped00_sttdig, ped00_sttenv, ped00_pacstr, ped00_digtot
        ) VALUES (5501, 10, 'CLIENTE TESTE', 71, 1, 0, '', 150.00)
      ''');

      await db.rawInsert('''
        INSERT INTO pckvendig010 (
          ped10_numped, ped10_seq, ped10_codprd, ped10_descri, ped10_qtdped, ped10_pcosub, ped10_totprd
        ) VALUES (5501, 1, 'PRD01', 'PRODUTO TESTE', 2.0, 75.00, 150.00)
      ''');

      // 1. Verifica listagem de pendentes
      final pendentes = await listarPedidosPendentes();
      expect(pendentes.any((p) => p.pedidoId == 5501), isTrue);

      // 2. Executa empacotamento manual
      final nomePacote = await gerarPacote(pedidosIds: [5501], codRep: 71);
      expect(nomePacote, startsWith('p71-'));
      expect(nomePacote, endsWith('.pac'));

      // 3. Verifica se status foi atualizado para sttenv = 1 e vinculado ao pacote
      final rows = await db.rawQuery('SELECT ped00_sttenv, ped00_pacstr FROM pckvendig000 WHERE ped00_numped = 5501');
      expect(rows.first['ped00_sttenv'], 1);
      expect(rows.first['ped00_pacstr'], nomePacote);

      // 4. Verifica se saiu da lista de pendentes
      final pendentesApos = await listarPedidosPendentes();
      expect(pendentesApos.any((p) => p.pedidoId == 5501), isFalse);

      // 5. Verifica se aparece nos pacotes agrupados
      final pacotes = await listarPacotesAgrupados(filtro: 'pendentes');
      expect(pacotes.any((p) => p.nomeArquivo == nomePacote), isTrue);
    });

    test('listarClientesPendentes identifica clientes com sttenv = 0 no banco local', () async {
      final db = await LocalSalesDatabaseService.getDatabase();

      await db.rawInsert('''
        INSERT INTO cadcli00 (cli00_codigo, cli00_descri, cli00_fantas, cli00_cpfcnp, cli00_sttenv)
        VALUES (9901, 'MERCADINHO LOCAL', 'MERCADINHO', '12345678000199', 0)
      ''');

      final clientesPendentes = await listarClientesPendentes(filtro: 'pendentes');
      expect(clientesPendentes.any((c) => c.clienteCodigo == 9901), isTrue);
      final cliente = clientesPendentes.firstWhere((c) => c.clienteCodigo == 9901);
      expect(cliente.razaoSocial, 'MERCADINHO LOCAL');
      expect(cliente.isPendente, isTrue);
    });
  });
}
