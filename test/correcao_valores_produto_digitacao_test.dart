import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:forca_de_vendas/app_state.dart';
import 'package:forca_de_vendas/data/repositories/produto_repository.dart';
import 'package:forca_de_vendas/data/services/local_sales_database_service.dart';
import 'package:forca_de_vendas/domain/services/valide_pco_service.dart';
import 'package:forca_de_vendas/domain/services/calculo_preco_produto_service.dart';
import 'package:forca_de_vendas/action_code/carregar_produto_detalhe.dart';
import 'package:forca_de_vendas/action_code/busca_produto.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Database db;
  late ProdutoRepository repository;

  setUp(() async {
    db = await databaseFactory.openDatabase(inMemoryDatabasePath);
    LocalSalesDatabaseService.setDatabaseForTesting(db);
    repository = ProdutoRepository(db: db);

    AppState().codFilialAtiva = 1;
    AppState().planoAtivo = 1;
    AppState().tabelaPrecoAtiva = 1;

    await db.execute('''
      CREATE TABLE cadpro00 (
        pro00_codigo INTEGER PRIMARY KEY,
        pro00_descri TEXT,
        pro00_unidad TEXT DEFAULT 'PC',
        pro00_codbar TEXT DEFAULT '42422',
        pro00_reffor TEXT DEFAULT 'N/A',
        pro00_ref001 TEXT DEFAULT '',
        pro00_ref002 TEXT DEFAULT '',
        pro00_codimg INTEGER DEFAULT 0,
        pro00_codemb INTEGER DEFAULT 1,
        pro00_codmar INTEGER DEFAULT 1
      );
    ''');

    await db.execute('''
      CREATE TABLE cadmar00 (
        mar00_codigo INTEGER PRIMARY KEY,
        mar00_descri TEXT
      );
    ''');
    await db.insert('cadmar00', {'mar00_codigo': 1, 'mar00_descri': 'TORK'});

    await db.execute('''
      CREATE TABLE estpro00 (
        pro00_codpro INTEGER,
        pro00_codfil INTEGER,
        pro00_qtdest REAL DEFAULT 217,
        pro00_qtdpen REAL DEFAULT 0
      );
    ''');

    // Tabela estpcopro00 contendo o preço de contingência / legado de 41.97
    await db.execute('''
      CREATE TABLE estpcopro00 (
        pro00_codpro INTEGER,
        pro00_codcls INTEGER,
        pro00_codtab INTEGER,
        pro00_pcosub REAL,
        pro00_preco REAL,
        pro00_pcocus REAL,
        pro00_pcomax REAL,
        pro00_pcomin REAL
      );
    ''');

    // Matriz regional estpcoreg00
    await db.execute('''
      CREATE TABLE estpcoreg00 (
        pro00_codkey INTEGER,
        pro00_codpro INTEGER,
        pro00_codreg INTEGER,
        pro00_codtab INTEGER,
        pro00_codpco INTEGER
      );
    ''');

    // Matriz de precificação estpcoregpco00 com preço oficial 56.65 e piso 48.00
    await db.execute('''
      CREATE TABLE estpcoregpco00 (
        pro00_codseq INTEGER PRIMARY KEY,
        pro00_pcomax REAL,
        pro00_pcomin REAL,
        pro00_typpco INTEGER DEFAULT 1
      );
    ''');

    await db.execute('''
      CREATE TABLE cadpla00 (
        pla00_codigo INTEGER PRIMARY KEY,
        pla00_descri TEXT,
        pla00_fator REAL DEFAULT 1.0
      );
    ''');

    // Insere Produto 42422
    await db.insert('cadpro00', {
      'pro00_codigo': 42422,
      'pro00_descri': 'ABA LATERAL TANQUE BROS-125/150 AZ 03/04',
      'pro00_unidad': 'PC',
      'pro00_codbar': '42422',
      'pro00_reffor': 'N/A',
      'pro00_codmar': 1,
    });

    await db.insert('estpro00', {
      'pro00_codpro': 42422,
      'pro00_codfil': 1,
      'pro00_qtdest': 217.0,
      'pro00_qtdpen': 0.0,
    });

    // Inserção em estpcopro00 com o valor de 41.97
    await db.insert('estpcopro00', {
      'pro00_codpro': 42422,
      'pro00_codcls': 1,
      'pro00_codtab': 1,
      'pro00_pcosub': 41.97,
      'pro00_preco': 41.97,
    });

    // Inserção em estpcoreg00 com registro regional apontando para o seq 100 (56.65)
    // E um registro residual apontando para 99 (41.97) para testar desambiguação
    await db.insert('estpcoreg00', {
      'pro00_codkey': 1,
      'pro00_codpro': 42422,
      'pro00_codreg': 0,
      'pro00_codtab': 0,
      'pro00_codpco': 99,
    });

    await db.insert('estpcoreg00', {
      'pro00_codkey': 1,
      'pro00_codpro': 42422,
      'pro00_codreg': 1,
      'pro00_codtab': 1,
      'pro00_codpco': 100,
    });

    await db.insert('estpcoregpco00', {
      'pro00_codseq': 99,
      'pro00_pcomax': 41.97,
      'pro00_pcomin': 41.97,
      'pro00_typpco': 1,
    });

    await db.insert('estpcoregpco00', {
      'pro00_codseq': 100,
      'pro00_pcomax': 56.65,
      'pro00_pcomin': 48.00,
      'pro00_typpco': 1,
    });

    await db.insert('cadpla00', {
      'pla00_codigo': 1,
      'pla00_descri': 'AVISTA 10 DIAS',
      'pla00_fator': 1.0,
    });
  });

  tearDown(() async {
    await db.close();
  });

  group('Correção dos Valores do Produto e Faixas de Preço Máximo/Mínimo', () {
    test('1. buscaProduto deve retornar preco 56.65, pcomax 56.65 e pcomin 48.00', () async {
      final produtos = await buscaProduto('42422', null, null, null, null, null, false, false, 1, '');
      expect(produtos, isNotEmpty);
      final p = produtos.first;
      expect(p.codigo, equals('42422'));
      expect(p.preco, equals(56.65));
      expect(p.pcomax, equals(56.65));
      expect(p.pcomin, equals(48.00));
      expect(p.saldoEstoque, equals(217.0));
    });

    test('2. ValidePcoService.obterFaixasPreco deve retornar pcomax 56.65 e pcomin 48.00 (e não 41.97)', () async {
      final faixa = await ValidePcoService.obterFaixasPreco(
        '42422',
        codTabela: 1,
        codRegiao: 1,
        codClasseCliente: 1,
      );
      expect(faixa.pcomax, equals(56.65));
      expect(faixa.pcomin, equals(48.00));
      expect(faixa.precoBase, equals(56.65));
    });

    test('3. ProdutoRepository.obterDetalhesProduto deve retornar preco_venda 56.65, pcomax 56.65 e pcomin 48.00', () async {
      final detalhe = await repository.obterDetalhesProduto(42422, 1, 1, 1, 1);
      expect(detalhe, isNotNull);
      expect(detalhe!.preco, equals(56.65));
      expect(detalhe.pcomax, equals(56.65));
      expect(detalhe.pcomin, equals(48.00));
    });

    test('4. carregarProdutoDetalhe deve retornar preco 56.65, pcomax 56.65 e pcomin 48.00', () async {
      final res = await carregarProdutoDetalhe('42422', 1, 1);
      expect(res, isNotNull);
      expect(res!.preco, equals(56.65));
      expect(res.pcomax, equals(56.65));
      expect(res.pcomin, equals(48.00));
    });

    test('5. CalculoPrecoProdutoService.calcularPrecoCompleto deve calcular faixas oficiais', () async {
      final calc = await CalculoPrecoProdutoService.calcularPrecoCompleto(
        codProduto: '42422',
        codTabela: 1,
        codPlano: 1,
        codFilial: 1,
        codRegiao: 1,
        codClasseCliente: 1,
        db: db,
      );
      expect(calc.precoEfetivo, equals(56.65));
      expect(calc.pcomax, equals(56.65));
      expect(calc.pcomin, equals(48.00));
    });
  });
}
