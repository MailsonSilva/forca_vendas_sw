import 'package:flutter_test/flutter_test.dart';
import 'package:forca_de_vendas/data/repositories/produto_repository.dart';
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

      // Criação das tabelas de acordo com a especificação técnica 00_ESPECIFICACAO_PESQUISA_PRODUTOS_EAN_MARCA_REFERENCIA.md
      await db.execute('''
        CREATE TABLE cadpro00 (
          pro00_codigo   INTEGER PRIMARY KEY,
          pro00_codbar   TEXT,
          pro00_descri   TEXT,
          pro00_deslon   TEXT,
          pro00_codmar   INTEGER,
          pro00_codfab   INTEGER,
          pro00_ref001   TEXT,
          pro00_ref002   TEXT,
          pro00_embala   TEXT,
          pro00_unidad   TEXT,
          pro00_qtdest   REAL,
          pro00_codimg   INTEGER
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

      // Inserir marcas de teste
      await db.insert('cadmar00', {'mar00_codigo': 1, 'mar00_descri': 'NESTLÉ'});
      await db.insert('cadmar00', {'mar00_codigo': 2, 'mar00_descri': 'BAMBINO'});

      // Inserir fabricantes de teste
      await db.insert('cadfor00', {'for00_codigo': 10, 'for00_descri': 'FABRICANTE ALIMENTOS S/A'});

      // Inserir produtos de teste
      await db.insert('cadpro00', {
        'pro00_codigo': 1001,
        'pro00_codbar': '7891000241501',
        'pro00_descri': 'BISCOITO WAFER CHOCOLATE 110G',
        'pro00_deslon': 'BISCOITO WAFER CHOCOLATE CROCANTE 110G',
        'pro00_codmar': 1,
        'pro00_codfab': 10,
        'pro00_ref001': 'REF-7890-A',
        'pro00_ref002': 'CX-12',
        'pro00_embala': 'CX 24 UN',
        'pro00_unidad': 'UN',
        'pro00_qtdest': 142.0,
        'pro00_codimg': 1,
      });

      await db.insert('cadpro00', {
        'pro00_codigo': 1002,
        'pro00_codbar': '7892000300100',
        'pro00_descri': 'MACARRAO ESPAGUETE 500G',
        'pro00_deslon': 'MACARRAO ESPAGUETE SEMOLA 500G',
        'pro00_codmar': 2,
        'pro00_codfab': null,
        'pro00_ref001': 'REF-MAC-500',
        'pro00_ref002': null,
        'pro00_embala': 'FD 20 UN',
        'pro00_unidad': 'FD',
        'pro00_qtdest': 80.0,
        'pro00_codimg': 2,
      });

      await db.insert('cadpro00', {
        'pro00_codigo': 1003,
        'pro00_codbar': '7893000400200',
        'pro00_descri': 'SABAO EM PO 1KG',
        'pro00_deslon': null,
        'pro00_codmar': null, // Sem marca cadastrada
        'pro00_codfab': null,
        'pro00_ref001': null,
        'pro00_ref002': 'REF-LIMPEZA-02',
        'pro00_embala': 'CX 10 UN',
        'pro00_unidad': 'UN',
        'pro00_qtdest': 35.0,
        'pro00_codimg': null,
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
  });
}
