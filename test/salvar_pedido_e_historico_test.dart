import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:forca_de_vendas/action_code/concluir_venda_process.dart';
import 'package:forca_de_vendas/action_code/carregar_pedido_resumo.dart';
import 'package:forca_de_vendas/action_code/listar_pedidos_pendentes.dart';
import 'package:forca_de_vendas/action_code/gerar_pacote.dart';
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
  late Directory tempDir;
  File? backupFile;
  bool hadOriginalDb = false;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AppState().initializePersistedState();

    tempDir = await Directory.systemTemp.createTemp('test_hist_temp_');
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
    if (tempDir.existsSync()) {
      try { tempDir.deleteSync(recursive: true); } catch (_) {}
    }
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

    // 2. Verifica a persistencia direta no SQLite: sttdig=1, sttenv=0 (Aguardando Pacote), pacstr=""
    final db = await openDatabase(dbPath, readOnly: true);
    final headerRows = await db.rawQuery('SELECT * FROM pckvendig000 WHERE ped00_numped = ?', [testPedId]);
    expect(headerRows.isNotEmpty, isTrue, reason: 'Cabecalho do pedido deve existir no SQLite');

    final h = headerRows.first;
    expect(h['ped00_sttdig'], equals(1), reason: 'sttdig deve ser 1 (Digitado)');
    expect(h['ped00_sttenv'], equals(0), reason: 'sttenv deve ser 0 (Aguardando Pacote)');
    expect(h['ped00_codagt'], equals(10), reason: 'codagt deve ser 10 (Agente selecionado)');
    expect(h['ped00_pacstr'] == null || h['ped00_pacstr'] == '', isTrue, reason: 'pacstr deve estar vazio ao concluir venda');
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

    // 4. Verifica listagem no Historico de Pedidos (Aguardando Pacote / podeEmpacotar = true)
    final listaHistorico = await listarPedidosHistorico(
      filtroTexto: '',
      filtroStatus: 'todos',
      filtroPeriodo: 'todos',
    );

    expect(listaHistorico.isNotEmpty, isTrue, reason: 'Historico deve retornar pedidos');
    final itemHistorico = listaHistorico.firstWhere((p) => p.pedidoId == testPedId);
    expect(itemHistorico.pedidoId, equals(testPedId));
    expect(itemHistorico.clienteNome, contains('MERCADO CENTRAL'));
    expect(itemHistorico.clienteCnpj, equals('12345678000199'));
    expect(itemHistorico.agenteDescricao, contains('BANCO DO BRASIL'));
    expect(itemHistorico.valorProdutos, equals(125.0));
    expect(itemHistorico.valorSubstituicao, equals(9.0));
    expect(itemHistorico.totalFatura, equals(116.0));
    expect(itemHistorico.sttEnv, equals(0), reason: 'Status deve ser 0 (Aguardando Pacote)');
    expect(itemHistorico.sttDig, equals(1), reason: 'Status digitacao deve ser 1 (Digitado)');
    expect(itemHistorico.podeEmpacotar, isTrue, reason: 'Pedido deve estar elegível para empacotar');

    // 5. Verifica se aparece no filtro especifico de 'pronto' / 'pendente'
    final listaProntos = await listarPedidosHistorico(
      filtroTexto: '',
      filtroStatus: 'pronto',
      filtroPeriodo: 'todos',
    );
    expect(listaProntos.any((p) => p.pedidoId == testPedId), isTrue, reason: 'Deve constar no filtro pronto/aguardando pacote');

    // 6. Gera o pacote com o pedido e valida transição de status para Empacotado (sttenv=1)
    final nomePacote = await gerarPacote(pedidosIds: [testPedId], codRep: 71);
    expect(nomePacote, contains('.pac'));

    final listaAposPacote = await listarPedidosHistorico(filtroStatus: 'empacotado');
    expect(listaAposPacote.any((p) => p.pedidoId == testPedId), isTrue);
    final itemEmpacotado = listaAposPacote.firstWhere((p) => p.pedidoId == testPedId);
    expect(itemEmpacotado.sttEnv, equals(1));
    expect(itemEmpacotado.podeEmpacotar, isFalse, reason: 'Pedido empacotado não pode mais ser empacotado');

    // 7. Valida que tentar empacotar novamente o mesmo pedido lança exceção
    expect(
      () => gerarPacote(pedidosIds: [testPedId], codRep: 71),
      throwsException,
      reason: 'Pedido já empacotado não pode ser re-empacotado',
    );

    // 8. Fluxo de Clonagem: Clona o pedido #8801
    final info = await clonarPedidoLocal(testPedId);
    expect(info, isNotNull);
    expect(info!.novoPedidoId, isNot(equals(testPedId)));
    expect(info.clienteCodigo, equals(1542));
    expect(info.clienteNome, contains('MERCADO CENTRAL'));
    expect(info.clienteCnpj, equals('12345678000199'));

    final int novoPedId = info.novoPedidoId;

    // Valida que o pedido clonado está em aberto (sttdig=0, sttenv=0) no SQLite
    final verifyDb = await openDatabase(dbPath, readOnly: true);
    final cabClonado = await verifyDb.rawQuery('SELECT * FROM pckvendig000 WHERE ped00_numped = ?', [novoPedId]);
    expect(cabClonado.isNotEmpty, isTrue);
    expect(cabClonado.first['ped00_sttdig'], equals(0), reason: 'Pedido clonado deve estar em aberto (sttdig=0)');
    expect(cabClonado.first['ped00_sttenv'], equals(0), reason: 'Pedido clonado deve estar sttenv=0');
    expect(cabClonado.first['ped00_pacstr'] == null || cabClonado.first['ped00_pacstr'] == '', isTrue);

    // Valida que os itens do pedido original foram copiados para o pedido clonado
    final itensClonados = await verifyDb.rawQuery('SELECT * FROM pckvendig010 WHERE ped10_numped = ?', [novoPedId]);
    expect(itensClonados.length, equals(1), reason: 'Itens devem estar presentes no pedido clonado');
    expect(itensClonados.first['ped10_codprd'], equals('78945'));
    expect(itensClonados.first['ped10_qtdped'], equals(5.0));
    await verifyDb.close();

    // 9. Conclui o pedido clonado e valida que os itens e totais são preservados
    final List<ItemPedidoStruct> itensParaConcluir = itensClonados.map((r) => ItemPedidoStruct(
      codigoProduto: r['ped10_codprd'].toString(),
      descricao: 'ARROZ TIPO 1 5KG',
      unidade: 'UN',
      quantidade: (r['ped10_qtdped'] as num).toDouble(),
      precoUnitario: (r['ped10_pcosub'] as num).toDouble(),
      totalItem: (r['ped10_qtdped'] as num).toDouble() * (r['ped10_pcosub'] as num).toDouble(),
    )).toList();

    final concluiuClonado = await concluirVendaProcess(
      pedidoId: novoPedId,
      clienteCodigo: info.clienteCodigo,
      linhaCodigo: info.linhaCodigo,
      planoCodigo: info.planoCodigo,
      carrinhoItens: itensParaConcluir,
      codAgenteCobrador: 10,
    );
    expect(concluiuClonado, isTrue);

    // Valida que o pedido clonado agora está concluído com itens salvos
    final dbFinal = await openDatabase(dbPath, readOnly: true);
    final cabFinal = await dbFinal.rawQuery('SELECT * FROM pckvendig000 WHERE ped00_numped = ?', [novoPedId]);
    expect(cabFinal.first['ped00_sttdig'], equals(1));
    expect(cabFinal.first['ped00_sttenv'], equals(0));

    final itensFinal = await dbFinal.rawQuery('SELECT * FROM pckvendig010 WHERE ped10_numped = ?', [novoPedId]);
    expect(itensFinal.length, equals(1), reason: 'Itens devem permanecer no pedido clonado concluído');
    await dbFinal.close();
  });
}
