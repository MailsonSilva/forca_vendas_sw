import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:forca_de_vendas/action_code/concluir_venda_process.dart';
import 'package:forca_de_vendas/action_code/carregar_pedido_resumo.dart';
import 'package:forca_de_vendas/action_code/listar_pedidos_pendentes.dart';
import 'package:forca_de_vendas/backend/schema/structs/item_pedido_struct.dart';
import 'package:forca_de_vendas/app_state.dart';

import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late String dbPath;
  File? backupFile;
  bool hadOriginalDb = false;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AppState().initializePersistedState();

    final databasesPath = await getDatabasesPath();
    dbPath = p.join(databasesPath, 'dbforcacad001.db');
    final realFile = File(dbPath);
    hadOriginalDb = await realFile.exists();
    if (hadOriginalDb) {
      final bPath = p.join(databasesPath, 'dbforcacad001_test_backup.db');
      backupFile = await realFile.copy(bPath);
    }

    // Configura AppState para o teste
    AppState().vendedor_codigo = 71;
    AppState().vendedor_equipe = 71;
    AppState().empresa_codigo = 'diniz';

    // Cria banco com tabelas de suporte para o teste
    final db = await openDatabase(dbPath);
    await db.execute('DROP TABLE IF EXISTS cadpro00');
    await db.execute('DROP TABLE IF EXISTS cadcli00');
    await db.execute('DROP TABLE IF EXISTS codage00');
    await db.execute('DROP TABLE IF EXISTS cadlin00');
    await db.execute('DROP TABLE IF EXISTS cadpla00');
    await db.execute('DROP TABLE IF EXISTS pckvendig000');
    await db.execute('DROP TABLE IF EXISTS pckvendig010');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS cadcli00 (
        cli00_codigo INTEGER PRIMARY KEY,
        cli00_descri TEXT,
        cli00_fantasi TEXT,
        cli00_cpfcnp TEXT,
        cli00_crelim REAL,
        cli00_active INTEGER
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS codage00 (
        age00_codigo INTEGER PRIMARY KEY,
        age00_descri TEXT,
        age00_tipo INTEGER
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS cadlin00 (
        lin00_codigo INTEGER PRIMARY KEY,
        lin00_descri TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS cadpla00 (
        pla00_codigo INTEGER PRIMARY KEY,
        pla00_descri TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS cadpro00 (
        pro00_codigo TEXT PRIMARY KEY,
        pro00_descri TEXT,
        pro00_pcomin REAL,
        pro00_qtdest REAL,
        pro00_indfra INTEGER
      )
    ''');

    // Popula dados de suporte
    await db.rawInsert(
      'INSERT OR REPLACE INTO cadcli00 (cli00_codigo, cli00_descri, cli00_fantasi, cli00_cpfcnp, cli00_crelim, cli00_active) VALUES (?, ?, ?, ?, ?, ?)',
      [1542, 'MERCADO CENTRAL LTDA', 'MERCADO CENTRAL', '12345678000199', 50000.0, 1],
    );
    await db.rawInsert(
      'INSERT OR REPLACE INTO codage00 (age00_codigo, age00_descri, age00_tipo) VALUES (?, ?, ?)',
      [10, 'BANCO DO BRASIL CARTEIRA 17', 1],
    );
    await db.rawInsert(
      'INSERT OR REPLACE INTO cadlin00 (lin00_codigo, lin00_descri) VALUES (?, ?)',
      [5, 'BEBIDAS E ALIMENTOS'],
    );
    await db.rawInsert(
      'INSERT OR REPLACE INTO cadpla00 (pla00_codigo, pla00_descri) VALUES (?, ?)',
      [3, '30/60/90 DIAS'],
    );
    await db.rawInsert(
      'INSERT OR REPLACE INTO cadpro00 (pro00_codigo, pro00_descri, pro00_pcomin, pro00_qtdest, pro00_indfra) VALUES (?, ?, ?, ?, ?)',
      ['78945', 'ARROZ TIPO 1 5KG', 20.0, 100.0, 0],
    );

    await db.close();
  });

  tearDown(() async {
    try {
      await databaseFactory.deleteDatabase(dbPath);
    } catch (_) {}
    if (hadOriginalDb && backupFile != null && await backupFile!.exists()) {
      try {
        await backupFile!.copy(dbPath);
        await backupFile!.delete();
      } catch (_) {}
    }
  });

  test('Fluxo completo: Concluir Pedido com Agente Cobrador -> Persistencia SQLite -> Resumo -> Historico/Extrato', () async {
    const int testPedId = 8801;
    final List<ItemPedidoStruct> carrinho = [
      ItemPedidoStruct(
        codigoProduto: '78945',
        descricao: 'ARROZ TIPO 1 5KG',
        unidade: 'UN',
        quantidade: 5.0,
        precoUnitario: 25.0,
        totalItem: 125.0,
        isBonificacao: false,
        quantidadeBonificada: 0.0,
        codigoCombo: '',
        unidadeComercial: 5.0,
        mulver: 1.0,
      ),
    ];

    // 1. Executa a conclusao de venda com Agente Cobrador 10 selecionado
    final bool success = await concluirVendaProcess(
      pedidoId: testPedId,
      clienteCodigo: 1542,
      linhaCodigo: '5',
      planoCodigo: '3',
      carrinhoItens: carrinho,
      codAgenteCobrador: 10,
      bonfrcven: 0,
    );

    expect(success, isTrue, reason: 'concluirVendaProcess deve retornar true');

    // 2. Verifica a persistencia direta no SQLite
    final db = await openDatabase(dbPath, readOnly: true);
    final headerRows = await db.rawQuery('SELECT * FROM pckvendig000 WHERE ped00_numped = ?', [testPedId]);
    expect(headerRows.isNotEmpty, isTrue, reason: 'Cabecalho do pedido deve existir no SQLite');

    final h = headerRows.first;
    expect(h['ped00_sttdig'], equals(1), reason: 'sttdig deve ser 1 (Digitado)');
    expect(h['ped00_sttenv'], equals(1), reason: 'sttenv deve ser 1 (Empacotado/Gerado PAC)');
    expect(h['ped00_codagt'], equals(10), reason: 'codagt deve ser 10 (Agente selecionado)');
    expect(h['ped00_pacstr'], equals('p71-8801.pac'), reason: 'pacstr deve ser preenchido com nome do .pac');
    expect(h['ped00_digtot'], equals(125.0));

    final itemRows = await db.rawQuery('SELECT * FROM pckvendig010 WHERE ped10_numped = ?', [testPedId]);
    expect(itemRows.length, equals(1), reason: 'Item deve estar gravado em pckvendig010');
    expect(itemRows.first['ped10_codprd'], equals('78945'));
    expect(itemRows.first['ped10_qtdped'], equals(5.0));
    expect(itemRows.first['ped10_pcosub'], equals(25.0));

    await db.close();

    // 3. Verifica carregamento na tela de Resumo do Pedido (PedidoResumoWidget / carregarPedidoResumo)
    final resumo = await carregarPedidoResumo(testPedId);
    expect(resumo, isNotNull);
    expect(resumo!.numeroPedido, equals(testPedId));
    expect(resumo.clienteNome, contains('MERCADO CENTRAL'));
    expect(resumo.valorProdutos, equals(125.0));
    expect(resumo.valorSubstituicao, equals(9.0));
    expect(resumo.totalFatura, equals(116.0));

    // 4. Verifica listagem no Historico de Pedidos / Extrato (PedidosRascunhosPageWidget / listarPedidosHistorico)
    final listaHistorico = await listarPedidosHistorico(
      filtroTexto: '',
      filtroStatus: 'todos',
      filtroPeriodo: 'todos',
    );

    expect(listaHistorico.isNotEmpty, isTrue, reason: 'Historico deve retornar pedidos');
    final itemHistorico = listaHistorico.firstWhere((p) => p.pedidoId == testPedId);
    expect(itemHistorico.pedidoId, equals(testPedId));
    expect(itemHistorico.clienteNome, contains('MERCADO CENTRAL'));
    expect(itemHistorico.agenteDescricao, contains('BANCO DO BRASIL'));
    expect(itemHistorico.valorProdutos, equals(125.0));
    expect(itemHistorico.valorSubstituicao, equals(9.0));
    expect(itemHistorico.totalFatura, equals(116.0));
    expect(itemHistorico.sttEnv, equals(1), reason: 'Status deve ser 1 (Empacotado)');
    expect(itemHistorico.sttDig, equals(1), reason: 'Status digitacao deve ser 1 (Digitado)');

    // 5. Verifica se aparece no filtro especifico de 'empacotado'
    final listaEmpacotados = await listarPedidosHistorico(
      filtroTexto: '',
      filtroStatus: 'empacotado',
      filtroPeriodo: 'todos',
    );
    expect(listaEmpacotados.any((p) => p.pedidoId == testPedId), isTrue, reason: 'Deve constar no filtro empacotado');
  });
}
