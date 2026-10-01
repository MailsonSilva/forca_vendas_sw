import 'package:flutter_test/flutter_test.dart';
import 'package:forca_de_vendas/action_code/busca_produto.dart';
import 'package:forca_de_vendas/data/repositories/produto_repository.dart';
import 'package:forca_de_vendas/data/services/local_sales_database_service.dart';
import 'package:forca_de_vendas/app_state.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('Otimização Listagem de Produtos - Precificação estpcoreg00/estpcoregpco00 e Filial Dinâmica', () {
    late Database db;
    late ProdutoRepository repository;

    setUp(() async {
      db = await openDatabase(inMemoryDatabasePath);
      LocalSalesDatabaseService.setDatabaseForTesting(db);

      await db.execute('DROP TABLE IF EXISTS cadpro00');
      await db.execute('DROP TABLE IF EXISTS cadproemb00');
      await db.execute('DROP TABLE IF EXISTS estpro00');
      await db.execute('DROP TABLE IF EXISTS estpcoreg00');
      await db.execute('DROP TABLE IF EXISTS estpcoregpco00');

      await db.execute('''
        CREATE TABLE cadpro00 (
          pro00_codigo INTEGER PRIMARY KEY,
          pro00_descri TEXT,
          pro00_unidad TEXT,
          pro00_codbar TEXT,
          pro00_reffor TEXT,
          pro00_codimg INTEGER,
          pro00_codemb INTEGER
        )
      ''');

      await db.execute('''
        CREATE TABLE cadproemb00 (
          emb00_codseq INTEGER PRIMARY KEY,
          emb00_embala TEXT
        )
      ''');

      await db.execute('''
        CREATE TABLE estpro00 (
          pro00_codpro INTEGER,
          pro00_codfil INTEGER,
          pro00_qtdest REAL,
          pro00_qtdpen REAL,
          PRIMARY KEY (pro00_codfil, pro00_codpro)
        )
      ''');

      await db.execute('''
        CREATE TABLE estpcoreg00 (
          pro00_codpro INTEGER,
          pro00_codkey INTEGER,
          pro00_codpco INTEGER
        )
      ''');

      await db.execute('''
        CREATE TABLE estpcoregpco00 (
          pro00_codseq INTEGER,
          pro00_typpco INTEGER,
          pro00_pcomax REAL,
          pro00_pcomin REAL
        )
      ''');

      // 1. Cadastros de Embalagem
      await db.insert('cadproemb00', {'emb00_codseq': 10, 'emb00_embala': 'CX 12 UN'});
      await db.insert('cadproemb00', {'emb00_codseq': 20, 'emb00_embala': 'FARDO 24 UN'});

      // 2. Produto 42422 (Especificação do usuário: preço 56.65)
      await db.insert('cadpro00', {
        'pro00_codigo': 42422,
        'pro00_descri': 'PRODUTO 42422 PREMIUM ESPECIAL',
        'pro00_unidad': 'UN',
        'pro00_codbar': '789424220001',
        'pro00_reffor': 'REF-42422',
        'pro00_codimg': 101,
        'pro00_codemb': 10,
      });

      // Segundo produto: 1001
      await db.insert('cadpro00', {
        'pro00_codigo': 1001,
        'pro00_descri': 'OLEO DE SOJA 900ML',
        'pro00_unidad': 'UN',
        'pro00_codbar': '78910010001',
        'pro00_reffor': 'REF-1001',
        'pro00_codimg': 102,
        'pro00_codemb': 20,
      });

      // 3. Estoque multi-filial (Filial 1 e Filial 2)
      // Produto 42422: Filial 1 saldo = 100 - 10 = 90.0 | Filial 2 saldo = 45 - 5 = 40.0
      await db.insert('estpro00', {
        'pro00_codpro': 42422,
        'pro00_codfil': 1,
        'pro00_qtdest': 100.0,
        'pro00_qtdpen': 10.0,
      });
      await db.insert('estpro00', {
        'pro00_codpro': 42422,
        'pro00_codfil': 2,
        'pro00_qtdest': 45.0,
        'pro00_qtdpen': 5.0,
      });

      // Produto 1001: Filial 1 saldo = 200.0
      await db.insert('estpro00', {
        'pro00_codpro': 1001,
        'pro00_codfil': 1,
        'pro00_qtdest': 200.0,
        'pro00_qtdpen': 0.0,
      });

      // 4. Regras de Preço com estpcoreg00 (codkey = 1)
      await db.insert('estpcoreg00', {
        'pro00_codpro': 42422,
        'pro00_codkey': 1,
        'pro00_codpco': 500,
      });
      await db.insert('estpcoreg00', {
        'pro00_codpro': 1001,
        'pro00_codkey': 1,
        'pro00_codpco': 600,
      });

      // 5. Faixas com duplicidades de 'pro00_typpco' para testar a agregação MAX
      // Produto 42422: typpco 1 tem 56.65, typpco 2 tem 52.00 -> MAX deve ser 56.65
      await db.insert('estpcoregpco00', {
        'pro00_codseq': 500,
        'pro00_typpco': 1,
        'pro00_pcomax': 56.65,
        'pro00_pcomin': 48.00,
      });
      await db.insert('estpcoregpco00', {
        'pro00_codseq': 500,
        'pro00_typpco': 2,
        'pro00_pcomax': 52.00,
        'pro00_pcomin': 46.00,
      });

      // Produto 1001: 8.50
      await db.insert('estpcoregpco00', {
        'pro00_codseq': 600,
        'pro00_typpco': 1,
        'pro00_pcomax': 8.50,
        'pro00_pcomin': 7.00,
      });

      repository = ProdutoRepository(db: db);
    });

    tearDown(() async {
      LocalSalesDatabaseService.setDatabaseForTesting(null);
      await db.close();
    });

    test('Produto 42422 retorna preco exato 56.65 via estpcoreg00/estpcoregpco00 sem linhas duplicadas', () async {
      final produtos = await buscaProduto('42422', null, null, null, null, null, false, false, 1, '');

      expect(produtos.length, equals(1));
      final p42422 = produtos.first;
      expect(p42422.codigo, equals('42422'));
      expect(p42422.descricao, equals('PRODUTO 42422 PREMIUM ESPECIAL'));
      expect(p42422.preco, equals(56.65));
      expect(p42422.pcomax, equals(56.65));
      expect(p42422.pcomin, equals(48.00));
      expect(p42422.embalagem, equals('CX 12 UN'));
      expect(p42422.reffor, equals('REF-42422'));
      expect(p42422.imagemId, equals(101));
      expect(p42422.saldoEstoque, equals(90.0));
    });

    test('Isola saldo de estoque de acordo com filialAtiva dinamica selecionada', () async {
      // Filial 1 -> saldo = 90.0
      final resFilial1 = await buscaProduto('42422', null, null, null, null, null, false, false, 1, '');
      expect(resFilial1.first.saldoEstoque, equals(90.0));

      // Filial 2 -> saldo = 40.0
      final resFilial2 = await buscaProduto('42422', null, null, null, null, null, false, false, 2, '');
      expect(resFilial2.first.saldoEstoque, equals(40.0));

      // Se codFilial for nulo, le AppState().codFilialAtiva
      AppState().codFilialAtiva = 2;
      final resAppState = await buscaProduto('42422', null, null, null, null, null, false, false, null, '');
      expect(resAppState.first.saldoEstoque, equals(40.0));
      AppState().codFilialAtiva = 1;
    });

    test('ProdutoRepository.buscaProduto executa mesma arquitetura SQL com binds e sem duplicacoes', () async {
      final lista = await repository.buscaProduto(filtro: '42422', codFilial: 1);
      expect(lista.length, equals(1));
      expect(lista.first.preco, equals(56.65));
      expect(lista.first.saldoEstoque, equals(90.0));
    });

    test('Listagem completa traz ordenacao por pro00_descri e dados de cadproemb00', () async {
      final todos = await buscaProduto('', null, null, null, null, null, false, false, 1, '');
      expect(todos.length, equals(2));
      // Ordem alfabetica por descri: OLEO DE SOJA (1001), PRODUTO 42422 (42422)
      expect(todos[0].codigo, equals('1001'));
      expect(todos[0].embalagem, equals('FARDO 24 UN'));
      expect(todos[1].codigo, equals('42422'));
      expect(todos[1].embalagem, equals('CX 12 UN'));
    });
  });
}
