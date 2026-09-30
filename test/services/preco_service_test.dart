import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:forca_de_vendas/app_state.dart';
import 'package:forca_de_vendas/backend/schema/structs/cliente_result_struct.dart';
import 'package:forca_de_vendas/backend/schema/structs/item_pedido_struct.dart';
import 'package:forca_de_vendas/data/repositories/produto_repository.dart';
import 'package:forca_de_vendas/data/services/local_sales_database_service.dart';
import 'package:forca_de_vendas/domain/services/valide_pco_service.dart';
import 'package:forca_de_vendas/action_code/salvar_carrinho_pedido.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Database db;
  late ProdutoRepository repository;

  setUp(() async {
    db = await databaseFactory.openDatabase(inMemoryDatabasePath);
    LocalSalesDatabaseService.setDatabaseForTesting(db);
    repository = ProdutoRepository();

    // 1. Cria tabelas físicas da SPEC-058 e SPEC-052
    await db.execute('''
      CREATE TABLE cadpro00 (
        pro00_codigo INTEGER PRIMARY KEY,
        pro00_descri TEXT,
        pro00_unidad TEXT,
        pro00_codbar TEXT,
        pro00_codimg INTEGER,
        pro00_qtdest REAL DEFAULT 0,
        pro00_preco REAL DEFAULT 0,
        pro00_defbon TEXT,
        pro00_defbonven TEXT
      );
    ''');

    await db.execute('''
      CREATE TABLE estpcoreg00 (
        pro00_codkey INTEGER,
        pro00_typpco INTEGER,
        pro00_codmod INTEGER,
        pro00_codpro INTEGER,
        pro00_codreg INTEGER,
        pro00_codtab INTEGER,
        pro00_codpco INTEGER,
        pro00_codcom INTEGER
      );
    ''');

    await db.execute('''
      CREATE TABLE estpcopro00 (
        pro00_codcls INTEGER,
        pro00_codpro INTEGER,
        pro00_pcocus REAL,
        pro00_pcosub REAL,
        pro00_altdat TEXT,
        pro00_altflg INTEGER
      );
    ''');

    await db.execute('''
      CREATE TABLE estpro00 (
        pro00_codfil INTEGER,
        pro00_codpro INTEGER,
        pro00_qtdest REAL,
        pro00_qtdpen REAL,
        pro00_prifil TEXT
      );
    ''');

    await db.execute('''
      CREATE TABLE pckvendig000 (
        ped00_numped INTEGER PRIMARY KEY,
        ped00_codcli INTEGER,
        ped00_codlin INTEGER,
        ped00_codpla INTEGER,
        ped00_codfil INTEGER,
        ped00_codrep INTEGER,
        ped00_subtot REAL DEFAULT 0,
        ped00_destot REAL DEFAULT 0,
        ped00_digtot REAL DEFAULT 0,
        ped00_bontot REAL DEFAULT 0,
        ped00_fattot REAL DEFAULT 0,
        ped00_sttdig INTEGER DEFAULT 1,
        ped00_sttenv INTEGER DEFAULT 0,
        ped00_datsys TEXT,
        ped00_datemi TEXT
      );
    ''');

    await db.execute('''
      CREATE TABLE pckvendig010 (
        ped10_numped INTEGER,
        ped10_seq INTEGER,
        ped10_codprd TEXT,
        ped10_descri TEXT,
        ped10_unidpri TEXT,
        ped10_qtdped REAL,
        ped10_pcosub REAL,
        ped10_totprd REAL,
        ped10_qtdbon REAL,
        ped10_sttbon INTEGER,
        ped10_codcmb TEXT,
        dig01_pcomax REAL,
        dig01_pcomin REAL,
        dig01_digpco REAL,
        ped10_pcomax REAL,
        ped10_pcomin REAL,
        ped10_digpco REAL
      );
    ''');

    // 2. Popula dados de teste
    await db.insert('cadpro00', {
      'pro00_codigo': 1001,
      'pro00_descri': 'PRODUTO REGIONAL 1001',
      'pro00_unidad': 'CX',
      'pro00_preco': 99.00, // Preço fictício do cadastro base que deve ser ignorado!
      'pro00_defbon': '1',
    });

    await db.insert('cadpro00', {
      'pro00_codigo': 1002,
      'pro00_descri': 'PRODUTO DIRETO 1002',
      'pro00_unidad': 'UN',
      'pro00_preco': 50.00,
      'pro00_defbon': '0',
    });

    await db.insert('cadpro00', {
      'pro00_codigo': 1003,
      'pro00_descri': 'PRODUTO SEM TABELA 1003',
      'pro00_unidad': 'UN',
      'pro00_preco': 10.00,
      'pro00_defbon': '0',
    });

    // Produto 1001: Região 10, Tabela 1 -> aponta para classe 5 em estpcopro00
    await db.insert('estpcoreg00', {
      'pro00_codpro': 1001,
      'pro00_codtab': 1,
      'pro00_codreg': 10,
      'pro00_codpco': 5,
    });

    await db.insert('estpcopro00', {
      'pro00_codpro': 1001,
      'pro00_codcls': 5,
      'pro00_pcocus': 12.00,
      'pro00_pcosub': 20.00,
    });

    // Produto 1002: Direto por classe 3
    await db.insert('estpcopro00', {
      'pro00_codpro': 1002,
      'pro00_codcls': 3,
      'pro00_pcocus': 8.00,
      'pro00_pcosub': 15.00,
    });

    // Estoques:
    // Produto 1001 na Filial 1: 100 - 10 = 90
    await db.insert('estpro00', {
      'pro00_codfil': 1,
      'pro00_codpro': 1001,
      'pro00_qtdest': 100.0,
      'pro00_qtdpen': 10.0,
      'pro00_prifil': 'S',
    });

    // Produto 1001 na Filial 2: 40 - 0 = 40
    await db.insert('estpro00', {
      'pro00_codfil': 2,
      'pro00_codpro': 1001,
      'pro00_qtdest': 40.0,
      'pro00_qtdpen': 0.0,
      'pro00_prifil': 'S',
    });

    // Produto 1002 na Filial 1: saldo zero (5 - 5 = 0)
    await db.insert('estpro00', {
      'pro00_codfil': 1,
      'pro00_codpro': 1002,
      'pro00_qtdest': 5.0,
      'pro00_qtdpen': 5.0,
      'pro00_prifil': 'S',
    });
  });

  tearDown(() async {
    await db.close();
  });

  group('SPEC-058: PrecoService & ValidePcoService Tests', () {
    test('Validação matemática de digpco entre pcomin e pcomax', () {
      // Preço válido
      final vOk = ValidePcoService.validePCOValues(
        pcomin: 10.0,
        pcomax: 20.0,
        commax: 10.0,
        digpco: 15.0,
        destot: 0.0,
        freadpco: true,
      );
      expect(vOk.valido, isTrue);

      // Preço abaixo do mínimo
      final vAbaixo = ValidePcoService.validePCOValues(
        pcomin: 10.0,
        pcomax: 20.0,
        commax: 10.0,
        digpco: 9.99,
        destot: 0.0,
        freadpco: true,
      );
      expect(vAbaixo.valido, isFalse);
      expect(vAbaixo.mensagem, contains('abaixo'));

      // Preço acima do máximo
      final vAcima = ValidePcoService.validePCOValues(
        pcomin: 10.0,
        pcomax: 20.0,
        commax: 10.0,
        digpco: 20.01,
        destot: 0.0,
        freadpco: true,
      );
      expect(vAcima.valido, isFalse);
      expect(vAcima.mensagem, contains('acima'));
    });

    test('obterFaixasPreco resolve hierarquia regional estpcoreg00 -> estpcopro00', () async {
      final faixa = await ValidePcoService.obterFaixasPreco(
        '1001',
        codTabela: 1,
        codRegiao: 10,
      );

      expect(faixa.precoBase, equals(20.00));
      expect(faixa.pcomax, equals(20.00));
      expect(faixa.pcomin, equals(12.00)); // Custo base pcocus
      expect(faixa.tabelaOrigem, equals('estpcopro00'));
    });

    test('ProdutoRepository.listarProdutosCard apura preco regional e isolamento de filial', () async {
      AppState().codFilialAtiva = 1;
      AppState().tabelaPrecoAtiva = 1;
      AppState().clienteSelecionado = ClienteResultStruct(cli00Codreg: 10, cli00Typpco: 1);

      final cardsFilial1 = await repository.listarProdutosCard(
        filialAtiva: 1,
        codTabela: 1,
        codRegiao: 10,
      );

      final c1001 = cardsFilial1.firstWhere((c) => c.codigo == 1001);
      expect(c1001.preco, equals(20.00));
      expect(c1001.pcomax, equals(20.00));
      expect(c1001.pcomin, equals(20.00));
      expect(c1001.qtdest, equals(90.0)); // 100 - 10

      // Filial 2: saldo isolado de 40.0
      final cardsFilial2 = await repository.listarProdutosCard(
        filialAtiva: 2,
        codTabela: 1,
        codRegiao: 10,
      );
      final c1001F2 = cardsFilial2.firstWhere((c) => c.codigo == 1001);
      expect(c1001F2.qtdest, equals(40.0));
    });

    test('ProdutoRepository.obterDetalhesProduto apura classe direta para produto sem estpcoreg00', () async {
      AppState().clienteSelecionado = ClienteResultStruct(cli00Codreg: 10, cli00Typpco: 3);

      final detalhe = await repository.obterDetalhesProduto(1002, 1, 1, 10, 3);
      expect(detalhe, isNotNull);
      expect(detalhe!.preco, equals(15.00));
      expect(detalhe.pcomax, equals(15.00));
      expect(detalhe.pcomin, equals(8.00));
      expect(detalhe.qtdest, equals(0.0)); // 5 - 5
    });

    test('Produto sem tabela retorna preco = 0.0 sem ler cadpro00.pro00_preco', () async {
      final detalhe = await repository.obterDetalhesProduto(1003, 1, 1);
      expect(detalhe, isNotNull);
      expect(detalhe!.preco, equals(0.0));
      expect(detalhe.pcomax, equals(0.0));
      expect(detalhe.pcomin, equals(0.0));
    });

    test('salvarCarrinhoPedido persiste dig01_pcomax e dig01_pcomin e valida limites', () async {
      final itemValido = ItemPedidoStruct(
        codigoProduto: '1001',
        descricao: 'PRODUTO REGIONAL 1001',
        unidade: 'CX',
        precoUnitario: 18.00,
        pcomax: 20.00,
        pcomin: 12.00,
        quantidade: 2.0,
        totalItem: 36.00,
      );

      final sucesso = await salvarCarrinhoPedido(
        pedidoId: 501,
        clienteCodigo: 1,
        linhaCodigo: '1',
        planoCodigo: '1',
        carrinhoItens: [itemValido],
        codFilial: 1,
      );
      expect(sucesso, isTrue);

      final itens = await db.rawQuery('SELECT * FROM pckvendig010 WHERE ped10_numped = 501');
      expect(itens.length, equals(1));
      expect(itens.first['dig01_pcomax'], equals(20.00));
      expect(itens.first['dig01_pcomin'], equals(12.00));
      expect(itens.first['dig01_digpco'], equals(18.00));
    });

    test('salvarCarrinhoPedido bloqueia preco zero para item comum', () async {
      final itemZero = ItemPedidoStruct(
        codigoProduto: '1003',
        descricao: 'ITEM ZERO',
        unidade: 'UN',
        precoUnitario: 0.0,
        pcomax: 0.0,
        pcomin: 0.0,
        quantidade: 1.0,
        totalItem: 0.0,
        isBonificacao: false,
      );

      final sucesso = await salvarCarrinhoPedido(
        pedidoId: 502,
        clienteCodigo: 1,
        linhaCodigo: '1',
        planoCodigo: '1',
        carrinhoItens: [itemZero],
        codFilial: 1,
      );
      expect(sucesso, isFalse);
    });

    test('salvarCarrinhoPedido permite preco zero para bonificacao autorizada', () async {
      final itemBonificado = ItemPedidoStruct(
        codigoProduto: '1001',
        descricao: 'BONIFICADO',
        unidade: 'CX',
        precoUnitario: 0.0,
        pcomax: 20.00,
        pcomin: 12.00,
        quantidade: 0.0,
        quantidadeBonificada: 1.0,
        totalItem: 0.0,
        isBonificacao: true,
      );

      final sucesso = await salvarCarrinhoPedido(
        pedidoId: 503,
        clienteCodigo: 1,
        linhaCodigo: '1',
        planoCodigo: '1',
        carrinhoItens: [itemBonificado],
        codFilial: 1,
      );
      expect(sucesso, isTrue);
    });
  });
}
