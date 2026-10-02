import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:forca_de_vendas/app_state.dart';
import 'package:forca_de_vendas/data/repositories/produto_repository.dart';
import 'package:forca_de_vendas/data/services/local_sales_database_service.dart';
import 'package:forca_de_vendas/domain/services/valide_pco_service.dart';
import 'package:forca_de_vendas/action_code/carregar_produto_detalhe.dart';

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

    // 1. Schema para teste da otimização estpcoreg00 / estpcoregpco00
    await db.execute('''
      CREATE TABLE cadpro00 (
        pro00_codigo INTEGER PRIMARY KEY,
        pro00_descri TEXT,
        pro00_unidad TEXT DEFAULT 'UN',
        pro00_codbar TEXT DEFAULT '',
        pro00_reffor TEXT DEFAULT '',
        pro00_codimg INTEGER DEFAULT 0,
        pro00_codemb INTEGER DEFAULT 1
      );
    ''');

    await db.execute('''
      CREATE TABLE cadproemb00 (
        emb00_codseq INTEGER PRIMARY KEY,
        emb00_embala TEXT
      );
    ''');

    await db.execute('''
      CREATE TABLE estpro00 (
        pro00_codpro INTEGER,
        pro00_codfil INTEGER,
        pro00_qtdest REAL DEFAULT 0,
        pro00_qtdpen REAL DEFAULT 0
      );
    ''');

    await db.execute('''
      CREATE TABLE estpcoreg00 (
        pro00_codkey INTEGER,
        pro00_codpro INTEGER,
        pro00_codpco INTEGER
      );
    ''');

    await db.execute('''
      CREATE TABLE estpcoregpco00 (
        pro00_codseq INTEGER PRIMARY KEY,
        pro00_pcomax REAL,
        pro00_pcomin REAL
      );
    ''');

    await db.execute('''
      CREATE TABLE cadpla00 (
        pla00_codigo INTEGER PRIMARY KEY,
        pla00_descri TEXT,
        pla00_fator REAL DEFAULT 1.0
      );
    ''');

    // Inserção do produto 42422 conforme exemplo do usuário (preço 56.65)
    await db.insert('cadpro00', {
      'pro00_codigo': 42422,
      'pro00_descri': 'PRODUTO TESTE 42422',
      'pro00_unidad': 'CX',
      'pro00_codbar': '7891234567890',
      'pro00_reffor': 'REF42422',
      'pro00_codimg': 100,
      'pro00_codemb': 1,
    });

    await db.insert('cadproemb00', {
      'emb00_codseq': 1,
      'emb00_embala': 'CX COM 12',
    });

    // Filial 1 tem saldo 15.0, Filial 2 tem saldo 80.0
    await db.insert('estpro00', {
      'pro00_codpro': 42422,
      'pro00_codfil': 1,
      'pro00_qtdest': 20.0,
      'pro00_qtdpen': 5.0, // Saldo líquido = 15.0
    });

    await db.insert('estpro00', {
      'pro00_codpro': 42422,
      'pro00_codfil': 2,
      'pro00_qtdest': 80.0,
      'pro00_qtdpen': 0.0, // Saldo líquido = 80.0
    });

    // Relacionamento regional estpcoreg00 com pro00_codkey = 1
    await db.insert('estpcoreg00', {
      'pro00_codkey': 1,
      'pro00_codpro': 42422,
      'pro00_codpco': 555,
    });

    // Preço em estpcoregpco00 com pcomax = 56.65 e pcomin = 51.00
    await db.insert('estpcoregpco00', {
      'pro00_codseq': 555,
      'pro00_pcomax': 56.65,
      'pro00_pcomin': 51.00,
    });

    await db.insert('cadpla00', {
      'pla00_codigo': 1,
      'pla00_descri': 'A VISTA',
      'pla00_fator': 1.0,
    });
  });

  tearDown(() async {
    await db.close();
  });

  group('Otimização de Precificação via estpcoreg00/estpcoregpco00 e Filial Dinâmica', () {
    test('buscaProduto deve retornar preco exato 56.65 para produto 42422 e saldo da filial ativa 1', () async {
      final produtos = await repository.buscaProduto(
        filtro: '42422',
        codFilial: 1,
      );

      expect(produtos, isNotEmpty);
      final p = produtos.first;
      expect(p.codigo, equals('42422'));
      expect(p.descricao, equals('PRODUTO TESTE 42422'));
      expect(p.embalagem, equals('CX COM 12'));
      expect(p.preco, equals(56.65));
      expect(p.pcomax, equals(56.65));
      expect(p.pcomin, equals(51.00));
      expect(p.saldoEstoque, equals(15.0));
      expect(p.estoqueAtual, equals(15.0));
    });

    test('buscaProduto deve isolar estoque dinâmico ao passar codFilial 2', () async {
      final produtos = await repository.buscaProduto(
        filtro: '42422',
        codFilial: 2,
      );

      expect(produtos, isNotEmpty);
      final p = produtos.first;
      expect(p.saldoEstoque, equals(80.0));
      expect(p.preco, equals(56.65));
    });

    test('ValidePcoService e carregarProdutoDetalhe devem refletir o preco 56.65 de estpcoregpco00', () async {
      final faixa = await ValidePcoService.obterFaixasPreco('42422');
      expect(faixa.pcomax, equals(56.65));
      expect(faixa.pcomin, equals(51.00));
      expect(faixa.precoBase, equals(56.65));

      final detalhe = await carregarProdutoDetalhe('42422');
      expect(detalhe, isNotNull);
      expect(detalhe!.preco, equals(56.65));
      expect(detalhe.pcomax, equals(56.65));
      expect(detalhe.pcomin, equals(51.00));
    });

    test('buscaProduto deve responder em alta performance (menos de 100ms)', () async {
      final sw = Stopwatch()..start();
      final produtos = await repository.buscaProduto(
        filtro: '42422',
        codFilial: 1,
      );
      sw.stop();

      expect(produtos, isNotEmpty);
      expect(sw.elapsedMilliseconds, lessThan(100));
    });
  });
}
