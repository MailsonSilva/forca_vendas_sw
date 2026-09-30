import 'package:flutter_test/flutter_test.dart';
import 'package:forca_de_vendas/app_state.dart';
import 'package:forca_de_vendas/backend/schema/structs/index.dart';
import 'package:forca_de_vendas/data/repositories/produto_repository.dart';
import 'package:forca_de_vendas/action_code/salvar_carrinho_pedido.dart';
import 'package:forca_de_vendas/data/services/local_sales_database_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('ProdutoRepository Tests', () {
    late Database db;
    late ProdutoRepository repository;

    setUp(() async {
      db = await openDatabase(inMemoryDatabasePath);

      // Criação das tabelas de acordo com a especificação técnica 00_ESPECIFICACAO_PESQUISA_PRODUTOS_EAN_MARCA_REFERENCIA.md e SPEC-052
      await db.execute('''
        CREATE TABLE cadpro00 (
          pro00_codigo   INTEGER PRIMARY KEY,
          pro00_codbar   TEXT,
          pro00_descri   TEXT,
          pro00_deslon   TEXT,
          pro00_unidad   TEXT,
          pro00_codimg   INTEGER,
          pro00_codemb   INTEGER,
          pro00_codmar   INTEGER,
          pro00_codfab   INTEGER,
          pro00_codgrp   INTEGER,
          pro00_codsgr   INTEGER,
          pro00_coddep   INTEGER,
          pro00_codsec   INTEGER,
          pro00_codlin   INTEGER,
          pro00_codtrb   INTEGER,
          pro00_pesbru   REAL,
          pro00_pesliq   REAL,
          pro00_ref001   TEXT,
          pro00_ref002   TEXT,
          pro00_embala   TEXT,
          pro00_qtdest   REAL
        )
      ''');

      await db.execute('''
        CREATE TABLE cadmar00 (
          mar00_codigo   INTEGER PRIMARY KEY,
          mar00_descri   TEXT
        )
      ''');

      await db.execute('''
        CREATE TABLE cadfor00 (
          for00_codigo   INTEGER PRIMARY KEY,
          for00_descri   TEXT
        )
      ''');

      await db.execute('''
        CREATE TABLE cadpro02 (
          pro02_codpro   INTEGER PRIMARY KEY,
          pro02_mulemb   INTEGER,
          pro02_mulven   REAL
        )
      ''');

      await db.execute('''
        CREATE TABLE estpro00 (
          pro00_codfil   INTEGER,
          pro00_codpro   INTEGER,
          pro00_qtdest   REAL,
          pro00_qtdpen   REAL,
          pro00_prifil   TEXT,
          PRIMARY KEY (pro00_codfil, pro00_codpro)
        )
      ''');

      await db.execute('''
        CREATE TABLE cadprofra00 (
          fra00_codpro   INTEGER PRIMARY KEY,
          fra00_indfra   INTEGER,
          fra00_peso     REAL
        )
      ''');

      await db.execute('''
        CREATE TABLE cadprobon00 (
          bon00_codpro   INTEGER PRIMARY KEY,
          bon00_defbon   TEXT,
          bon00_defbonven TEXT
        )
      ''');

      await db.execute('''
        CREATE TABLE cadproemb00 (
          emb00_codseq   INTEGER PRIMARY KEY,
          emb00_embala   TEXT
        )
      ''');

      await db.execute('''
        CREATE TABLE estprodat00 (
          pro00_codfil   INTEGER,
          pro00_codpro   INTEGER,
          pro00_entdat   TEXT,
          PRIMARY KEY (pro00_codfil, pro00_codpro)
        )
      ''');

      // Inserir marcas de teste
      await db.insert('cadmar00', {'mar00_codigo': 1, 'mar00_descri': 'NESTLÉ'});
      await db.insert('cadmar00', {'mar00_codigo': 2, 'mar00_descri': 'BAMBINO'});

      // Inserir fabricantes de teste
      await db.insert('cadfor00', {'for00_codigo': 10, 'for00_descri': 'FABRICANTE ALIMENTOS S/A'});

      // Inserir embalagens de teste
      await db.insert('cadproemb00', {'emb00_codseq': 5, 'emb00_embala': 'FARDO COM 12 UN'});

      // Inserir produtos de teste
      await db.insert('cadpro00', {
        'pro00_codigo': 1001,
        'pro00_codbar': '7891000241501',
        'pro00_descri': 'BISCOITO WAFER CHOCOLATE 110G',
        'pro00_deslon': 'BISCOITO WAFER CHOCOLATE CROCANTE 110G',
        'pro00_unidad': 'UN',
        'pro00_codimg': 1,
        'pro00_codemb': 5,
        'pro00_codmar': 1,
        'pro00_codfab': 10,
        'pro00_codgrp': 101,
        'pro00_codsgr': 1,
        'pro00_coddep': 2,
        'pro00_codsec': 3,
        'pro00_codlin': 4,
        'pro00_codtrb': 0,
        'pro00_pesbru': 0.120,
        'pro00_pesliq': 0.110,
        'pro00_ref001': 'REF-7890-A',
        'pro00_ref002': 'CX-12',
        'pro00_embala': 'CX 24 UN',
        'pro00_qtdest': 142.0,
      });

      await db.insert('cadpro00', {
        'pro00_codigo': 1002,
        'pro00_codbar': '7892000300100',
        'pro00_descri': 'MACARRAO ESPAGUETE 500G',
        'pro00_deslon': 'MACARRAO ESPAGUETE SEMOLA 500G',
        'pro00_unidad': 'FD',
        'pro00_codimg': 2,
        'pro00_codemb': null,
        'pro00_codmar': 2,
        'pro00_codfab': null,
        'pro00_codgrp': null,
        'pro00_codsgr': null,
        'pro00_coddep': null,
        'pro00_codsec': null,
        'pro00_codlin': null,
        'pro00_codtrb': null,
        'pro00_pesbru': null,
        'pro00_pesliq': null,
        'pro00_ref001': 'REF-MAC-500',
        'pro00_ref002': null,
        'pro00_embala': 'FD 20 UN',
        'pro00_qtdest': 80.0,
      });

      await db.insert('cadpro00', {
        'pro00_codigo': 1003,
        'pro00_codbar': '7893000400200',
        'pro00_descri': 'SABAO EM PO 1KG',
        'pro00_deslon': null,
        'pro00_unidad': 'UN',
        'pro00_codimg': null,
        'pro00_codemb': null,
        'pro00_codmar': null, // Sem marca cadastrada
        'pro00_codfab': null,
        'pro00_codgrp': null,
        'pro00_codsgr': null,
        'pro00_coddep': null,
        'pro00_codsec': null,
        'pro00_codlin': null,
        'pro00_codtrb': null,
        'pro00_pesbru': null,
        'pro00_pesliq': null,
        'pro00_ref001': null,
        'pro00_ref002': 'REF-LIMPEZA-02',
        'pro00_embala': 'CX 10 UN',
        'pro00_qtdest': 35.0,
      });

      // Inserir dados de estoque na filial 1
      await db.insert('estpro00', {
        'pro00_codfil': 1,
        'pro00_codpro': 1001,
        'pro00_qtdest': 150.0,
        'pro00_qtdpen': 20.0, // Saldo líquido = 130.0
        'pro00_prifil': 'S',
      });

      await db.insert('estpro00', {
        'pro00_codfil': 1,
        'pro00_codpro': 1002,
        'pro00_qtdest': 50.0,
        'pro00_qtdpen': 50.0, // Saldo líquido = 0.0
        'pro00_prifil': 'N',
      });

      // Inserir dados de amarrações legadas do produto 1001
      await db.insert('cadpro02', {
        'pro02_codpro': 1001,
        'pro02_mulemb': 12,
        'pro02_mulven': 1.5,
      });

      await db.insert('cadprofra00', {
        'fra00_codpro': 1001,
        'fra00_indfra': 1,
        'fra00_peso': 0.110,
      });

      await db.insert('cadprobon00', {
        'bon00_codpro': 1001,
        'bon00_defbon': 'BONIF_PADRAO',
        'bon00_defbonven': 'S',
      });

      await db.insert('estprodat00', {
        'pro00_codfil': 1,
        'pro00_codpro': 1001,
        'pro00_entdat': '2026-09-01',
      });

      repository = ProdutoRepository(db: db);
    });

    tearDown(() async {
      await db.close();
    });

    test('buscarProdutos retorna todos os produtos ordenados por descrição quando a query for nula ou vazia', () async {
      final todos = await repository.buscarProdutos(null);
      expect(todos.length, equals(3));
      expect(todos[0].id, equals(1001));
      expect(todos[1].id, equals(1002));
      expect(todos[2].id, equals(1003));
    });

    test('buscarProdutos localiza produto pelo Código EAN (pro00_codbar)', () async {
      final resultado = await repository.buscarProdutos('7891000241501');
      expect(resultado.length, equals(1));
      expect(resultado.first.id, equals(1001));
      expect(resultado.first.ean, equals('7891000241501'));
      expect(resultado.first.marca, equals('NESTLÉ'));
      expect(resultado.first.fabricante, equals('FABRICANTE ALIMENTOS S/A'));
    });

    test('buscarProdutos localiza produtos pelo nome da Marca (mar00_descri)', () async {
      final resultado = await repository.buscarProdutos('NESTLÉ');
      expect(resultado.length, equals(1));
      expect(resultado.first.id, equals(1001));
      expect(resultado.first.marca, equals('NESTLÉ'));
    });

    test('buscarProdutos localiza produto pela Referência 1 (pro00_ref001)', () async {
      final resultado = await repository.buscarProdutos('REF-7890-A');
      expect(resultado.length, equals(1));
      expect(resultado.first.id, equals(1001));
      expect(resultado.first.referencia1, equals('REF-7890-A'));
      expect(resultado.first.referenciaFormatada, equals('REF-7890-A / CX-12'));
    });

    test('buscarProdutos localiza produto pela Referência 2 (pro00_ref002)', () async {
      final resultado = await repository.buscarProdutos('REF-LIMPEZA-02');
      expect(resultado.length, equals(1));
      expect(resultado.first.id, equals(1003));
      expect(resultado.first.referenciaFormatada, equals('REF-LIMPEZA-02'));
    });

    test('buscarProdutos trata LEFT JOIN com marca nula fornecendo fallback SEM MARCA', () async {
      final resultado = await repository.buscarProdutos('SABAO');
      expect(resultado.length, equals(1));
      expect(resultado.first.id, equals(1003));
      expect(resultado.first.marca, equals('SEM MARCA'));
      expect(resultado.first.fabricante, equals(''));
    });

    // =========================================================================
    // SPEC-052: QUERY 1 - LISTAGEM LEVE DO CARD
    // =========================================================================
    group('SPEC-052: Query 1 - listarProdutosCard', () {
      test('retorna produtos com saldo líquido calculado estritamente para a filial ativa', () async {
        final cards = await repository.listarProdutosCard(filialAtiva: 1);
        expect(cards.length, equals(3));

        // 1001: 150 - 20 = 130
        final p1 = cards.firstWhere((c) => c.codigo == 1001);
        expect(p1.descricao, equals('BISCOITO WAFER CHOCOLATE 110G'));
        expect(p1.unidade, equals('UN'));
        expect(p1.codbar, equals('7891000241501'));
        expect(p1.codimg, equals(1));
        expect(p1.qtdest, equals(130.0));

        // 1002: 50 - 50 = 0
        final p2 = cards.firstWhere((c) => c.codigo == 1002);
        expect(p2.qtdest, equals(0.0));

        // 1003: sem registro em estpro00 para filial 1 -> fallback cadpro00.pro00_qtdest = 35.0
        final p3 = cards.firstWhere((c) => c.codigo == 1003);
        expect(p3.qtdest, equals(35.0));
      });

      test('filtra por termo pesquisando em descrição, código e código de barras', () async {
        final porDesc = await repository.listarProdutosCard(termo: 'MACARRAO', filialAtiva: 1);
        expect(porDesc.length, equals(1));
        expect(porDesc.first.codigo, equals(1002));

        final porCodigo = await repository.listarProdutosCard(termo: '1003', filialAtiva: 1);
        expect(porCodigo.length, equals(1));
        expect(porCodigo.first.codigo, equals(1003));

        final porBar = await repository.listarProdutosCard(termo: '7891000241501', filialAtiva: 1);
        expect(porBar.length, equals(1));
        expect(porBar.first.codigo, equals(1001));
      });

      test('filtra com curinga % entre palavras no listarProdutosCard', () async {
        final porCuringa = await repository.listarProdutosCard(
          termo: 'BISCOITO%WAFER',
          filialAtiva: 1,
        );
        expect(porCuringa.length, equals(1));
        expect(porCuringa.first.codigo, equals(1001));
      });

      test('filtra por referência com prefixo @ no listarProdutosCard', () async {
        final porRef = await repository.listarProdutosCard(
          termo: '@REF-MAC-500',
          filialAtiva: 1,
        );
        expect(porRef.length, equals(1));
        expect(porRef.first.codigo, equals(1002));
      });

      test('filtra por início da palavra (prefixada) e descarta termos no meio da palavra', () async {
        final porInicio = await repository.listarProdutosCard(
          termo: 'WAFER',
          filialAtiva: 1,
        );
        expect(porInicio.length, equals(1));
        expect(porInicio.first.codigo, equals(1001));

        final porMeio = await repository.listarProdutosCard(
          termo: 'AFER',
          filialAtiva: 1,
        );
        expect(porMeio.isEmpty, isTrue);
      });

      test('aplica paginação LIMIT 100 e OFFSET corretamente', () async {
        final pag1 = await repository.listarProdutosCard(filialAtiva: 1, limit: 2, offset: 0);
        expect(pag1.length, equals(2));
        expect(pag1[0].codigo, equals(1001));
        expect(pag1[1].codigo, equals(1002));

        final pag2 = await repository.listarProdutosCard(filialAtiva: 1, limit: 2, offset: 2);
        expect(pag2.length, equals(1));
        expect(pag2[0].codigo, equals(1003));
      });

      test('chamada com termo nulo ou em branco monta query sem WHERE e retorna todos os produtos cadastrados', () async {
        final semTermo = await repository.listarProdutosCard(termo: null, filialAtiva: 1);
        expect(semTermo.length, equals(3));

        final termoBranco = await repository.listarProdutosCard(termo: '   ', filialAtiva: 1);
        expect(termoBranco.length, equals(3));
      });
    });

    // =========================================================================
    // SPEC-052: QUERY 2 - DETALHE COMPLETO SOB DEMANDA (Tcadpro00::cload)
    // =========================================================================
    group('SPEC-052: Query 2 - obterDetalhesProduto', () {
      test('carrega todos os 26 campos e amarrações relacionais do legado usysctr00', () async {
        final detalhe = await repository.obterDetalhesProduto(1001, 1);
        expect(detalhe, isNotNull);
        expect(detalhe!.codigo, equals(1001));
        expect(detalhe.codbar, equals('7891000241501'));
        expect(detalhe.descricao, equals('BISCOITO WAFER CHOCOLATE 110G'));
        expect(detalhe.deslon, equals('BISCOITO WAFER CHOCOLATE CROCANTE 110G'));
        expect(detalhe.unidade, equals('UN'));
        expect(detalhe.codimg, equals(1));
        expect(detalhe.embalagem, equals('FARDO COM 12 UN'));
        expect(detalhe.indfra, equals(1));
        expect(detalhe.peso, equals(0.110));
        expect(detalhe.codfab, equals(10));
        expect(detalhe.codmar, equals(1));
        expect(detalhe.codgrp, equals(101));
        expect(detalhe.codsgr, equals(1));
        expect(detalhe.coddep, equals(2));
        expect(detalhe.codsec, equals(3));
        expect(detalhe.codlin, equals(4));
        expect(detalhe.codtrb, equals(0));
        expect(detalhe.pesbru, equals(0.120));
        expect(detalhe.pesliq, equals(0.110));
        expect(detalhe.defbon, equals('BONIF_PADRAO'));
        expect(detalhe.defbonven, equals('S'));
        expect(detalhe.entdat, equals('2026-09-01'));
        expect(detalhe.prifil, equals('S'));
        expect(detalhe.qtdest, equals(130.0)); // 150 - 20
        expect(detalhe.mulemb, equals(12));
        expect(detalhe.mulven, equals(1.5));
      });

      test('aplica fallbacks do COALESCE quando tabelas auxiliares não possuem dados', () async {
        final detalhe = await repository.obterDetalhesProduto(1003, 1);
        expect(detalhe, isNotNull);
        expect(detalhe!.codigo, equals(1003));
        expect(detalhe.mulemb, equals(1)); // COALESCE(pr2.pro02_mulemb, 1)
        expect(detalhe.mulven, equals(1.0)); // COALESCE(pr2.pro02_mulven, 1.0)
        expect(detalhe.qtdest, equals(35.0)); // COALESCE(est.pro00_qtdest - est.pro00_qtdpen, sel.pro00_qtdest, 0)
        expect(detalhe.embalagem, isNull);
        expect(detalhe.indfra, isNull);
        expect(detalhe.defbon, isNull);
      });

      test('retorna null se o produto não existir', () async {
        final detalhe = await repository.obterDetalhesProduto(99999, 1);
        expect(detalhe, isNull);
      });
    });

    // =========================================================================
    // SPEC-058: PRECIFICAÇÃO CANÔNICA, MARGENS E ISOLAMENTO DE FILIAL
    // =========================================================================
    group('SPEC-058: Precificação Canônica (estpcoreg00 / estpcopro00) e Isolamento de Filial', () {
      setUp(() async {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS estpcoreg00 (
            pro00_codpro INTEGER,
            pro00_codtab INTEGER,
            pro00_codreg INTEGER,
            pro00_codpco INTEGER
          )
        ''');

        await db.execute('''
          CREATE TABLE IF NOT EXISTS estpcopro00 (
            pro00_codcls INTEGER,
            pro00_codpro INTEGER,
            pro00_pcocus REAL,
            pro00_pcosub REAL
          )
        ''');

        // Produto 1001: Mapeado na região 10 e tabela 1 para classe 5
        await db.insert('estpcoreg00', {
          'pro00_codpro': 1001,
          'pro00_codtab': 1,
          'pro00_codreg': 10,
          'pro00_codpco': 5,
        });

        // Valores de classe 5: pcosub = 15.50, pcocus = 10.00
        await db.insert('estpcopro00', {
          'pro00_codpro': 1001,
          'pro00_codcls': 5,
          'pro00_pcocus': 10.00,
          'pro00_pcosub': 15.50,
        });

        // Produto 1002: Não tem estpcoreg00, mas tem classe 3 em estpcopro00
        await db.insert('estpcopro00', {
          'pro00_codpro': 1002,
          'pro00_codcls': 3,
          'pro00_pcocus': null,
          'pro00_pcosub': 8.00,
        });

        // Estoque na filial 2 para produto 1001: 50 - 5 = 45.0
        await db.insert('estpro00', {
          'pro00_codfil': 2,
          'pro00_codpro': 1001,
          'pro00_qtdest': 50.0,
          'pro00_qtdpen': 5.0,
          'pro00_prifil': 'S',
        });
      });

      test('apura preco, pcomax e pcomin via estpcoreg00 + estpcopro00', () async {
        AppState().tabelaPrecoAtiva = 1;
        AppState().clienteSelecionado = ClienteResultStruct(cli00Codreg: 10, cli00Typpco: 1);

        final cards = await repository.listarProdutosCard(
          filialAtiva: 1,
          codTabela: 1,
          codRegiao: 10,
        );
        final p1 = cards.firstWhere((c) => c.codigo == 1001);
        expect(p1.preco, equals(15.50));
        expect(p1.pcomax, equals(15.50));
        expect(p1.pcomin, equals(10.00));

        final detalhe = await repository.obterDetalhesProduto(1001, 1, 1, 10);
        expect(detalhe, isNotNull);
        expect(detalhe!.preco, equals(15.50));
        expect(detalhe.pcomax, equals(15.50));
        expect(detalhe.pcomin, equals(10.00));
      });

      test('fallback de classe de preço padrão do cliente quando não há registro em estpcoreg00', () async {
        AppState().tabelaPrecoAtiva = 1;
        AppState().clienteSelecionado = ClienteResultStruct(cli00Codreg: 10, cli00Typpco: 3);

        final cards = await repository.listarProdutosCard(
          filialAtiva: 1,
          codTabela: 1,
          codRegiao: 10,
          codClasseCliente: 3,
        );
        final p2 = cards.firstWhere((c) => c.codigo == 1002);
        expect(p2.preco, equals(8.00));
        expect(p2.pcomax, equals(8.00));
        expect(p2.pcomin, equals(8.00)); // pcocus nulo -> fallback pcosub
      });

      test('produto sem tabela em estpcopro00 retorna estritamente preco/pcomax/pcomin = 0.0 sem ler cadpro00.pro00_preco', () async {
        final cards = await repository.listarProdutosCard(filialAtiva: 1, codTabela: 1);
        final p3 = cards.firstWhere((c) => c.codigo == 1003);
        expect(p3.preco, equals(0.0));
        expect(p3.pcomax, equals(0.0));
        expect(p3.pcomin, equals(0.0));

        final detalhe = await repository.obterDetalhesProduto(1003, 1, 1);
        expect(detalhe, isNotNull);
        expect(detalhe!.preco, equals(0.0));
        expect(detalhe.pcomax, equals(0.0));
        expect(detalhe.pcomin, equals(0.0));
      });

      test('isolamento de filial calcula saldo estritamente pela filial ativa', () async {
        final cardsFilial1 = await repository.listarProdutosCard(filialAtiva: 1);
        final p1Filial1 = cardsFilial1.firstWhere((c) => c.codigo == 1001);
        expect(p1Filial1.qtdest, equals(130.0)); // 150 - 20 na filial 1

        final cardsFilial2 = await repository.listarProdutosCard(filialAtiva: 2);
        final p1Filial2 = cardsFilial2.firstWhere((c) => c.codigo == 1001);
        expect(p1Filial2.qtdest, equals(45.0)); // 50 - 5 na filial 2
      });

      test('filtro apenasEstoque oculta itens com saldo <= 0', () async {
        // Produto 1002 na filial 1 tem saldo líquido = 0.0
        final comFiltro = await repository.listarProdutosCard(
          filialAtiva: 1,
          apenasEstoque: true,
        );
        expect(comFiltro.any((c) => c.codigo == 1002), isFalse);

        final semFiltro = await repository.listarProdutosCard(
          filialAtiva: 1,
          apenasEstoque: false,
        );
        expect(semFiltro.any((c) => c.codigo == 1002), isTrue);
      });

      test('salvarCarrinhoPedido persiste dig01_pcomax, dig01_pcomin e dig01_digpco no pckvendig010', () async {
        LocalSalesDatabaseService.setDatabaseForTesting(db);

        final itemValido = ItemPedidoStruct(
          codigoProduto: '1001',
          descricao: 'BISCOITO WAFER',
          unidade: 'UN',
          precoUnitario: 12.00,
          pcomax: 15.50,
          pcomin: 10.00,
          quantidade: 2.0,
          totalItem: 24.00,
        );

        final sucesso = await salvarCarrinhoPedido(
          pedidoId: 991,
          clienteCodigo: 1,
          linhaCodigo: '1',
          planoCodigo: '1',
          carrinhoItens: [itemValido],
          codFilial: 1,
        );
        expect(sucesso, isTrue);

        final itensSalvos = await db.rawQuery('SELECT * FROM pckvendig010 WHERE ped10_numped = 991');
        expect(itensSalvos.length, equals(1));
        final row = itensSalvos.first;
        expect(row['dig01_pcomax'], equals(15.50));
        expect(row['dig01_pcomin'], equals(10.00));
        expect(row['dig01_digpco'], equals(12.00));
      });

      test('salvarCarrinhoPedido bloqueia inclusão com preco <= 0 quando não bonificado', () async {
        LocalSalesDatabaseService.setDatabaseForTesting(db);

        final itemZero = ItemPedidoStruct(
          codigoProduto: '1003',
          descricao: 'ITEM PRECO ZERO',
          unidade: 'UN',
          precoUnitario: 0.0,
          pcomax: 0.0,
          pcomin: 0.0,
          quantidade: 1.0,
          totalItem: 0.0,
          isBonificacao: false,
        );

        final sucesso = await salvarCarrinhoPedido(
          pedidoId: 992,
          clienteCodigo: 1,
          linhaCodigo: '1',
          planoCodigo: '1',
          carrinhoItens: [itemZero],
          codFilial: 1,
        );
        expect(sucesso, isFalse);
      });

      test('salvarCarrinhoPedido permite inclusão com preco = 0 para item bonificado', () async {
        LocalSalesDatabaseService.setDatabaseForTesting(db);

        final itemBonificado = ItemPedidoStruct(
          codigoProduto: '1001',
          descricao: 'BISCOITO BONIFICADO',
          unidade: 'UN',
          precoUnitario: 0.0,
          pcomax: 15.50,
          pcomin: 10.00,
          quantidade: 0.0,
          quantidadeBonificada: 1.0,
          totalItem: 0.0,
          isBonificacao: true,
        );

        final sucesso = await salvarCarrinhoPedido(
          pedidoId: 993,
          clienteCodigo: 1,
          linhaCodigo: '1',
          planoCodigo: '1',
          carrinhoItens: [itemBonificado],
          codFilial: 1,
        );
        expect(sucesso, isTrue);
      });

      test('salvarCarrinhoPedido bloqueia digpco fora da faixa pcomin e pcomax', () async {
        LocalSalesDatabaseService.setDatabaseForTesting(db);

        // Abaixo do mínimo (9.00 < 10.00)
        final itemAbaixo = ItemPedidoStruct(
          codigoProduto: '1001',
          descricao: 'ITEM ABAIXO DO PISO',
          unidade: 'UN',
          precoUnitario: 9.00,
          pcomax: 15.50,
          pcomin: 10.00,
          quantidade: 1.0,
          totalItem: 9.00,
        );

        final sucessoAbaixo = await salvarCarrinhoPedido(
          pedidoId: 994,
          clienteCodigo: 1,
          linhaCodigo: '1',
          planoCodigo: '1',
          carrinhoItens: [itemAbaixo],
          codFilial: 1,
        );
        expect(sucessoAbaixo, isFalse);

        // Acima do máximo (16.00 > 15.50)
        final itemAcima = ItemPedidoStruct(
          codigoProduto: '1001',
          descricao: 'ITEM ACIMA DO TETO',
          unidade: 'UN',
          precoUnitario: 16.00,
          pcomax: 15.50,
          pcomin: 10.00,
          quantidade: 1.0,
          totalItem: 16.00,
        );

        final sucessoAcima = await salvarCarrinhoPedido(
          pedidoId: 995,
          clienteCodigo: 1,
          linhaCodigo: '1',
          planoCodigo: '1',
          carrinhoItens: [itemAcima],
          codFilial: 1,
        );
        expect(sucessoAcima, isFalse);
      });
    });
  });
}
