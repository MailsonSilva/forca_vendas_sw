import 'package:flutter_test/flutter_test.dart';
import 'package:forca_de_vendas/action_code/busca_produto.dart';
import 'package:forca_de_vendas/data/services/local_sales_database_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart' as p;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('SPEC-050: Consulta SQL Oficial de Produtos e Estoque Multi-Filial', () {
    late String dbPath;
    late Database db;

    setUp(() async {
      dbPath = p.join(await getDatabasesPath(), 'dbforcacad001.db');
      db = await openDatabase(dbPath);

      await db.execute('DROP TABLE IF EXISTS cadpro00');
      await db.execute('DROP TABLE IF EXISTS estpro00');
      await db.execute('DROP TABLE IF EXISTS estpcopro00');
      await db.execute('DROP TABLE IF EXISTS pckvendig000');
      await db.execute('DROP TABLE IF EXISTS pckvendig010');

      // Tabela base: cadpro00
      await db.execute('''
        CREATE TABLE cadpro00 (
          pro00_codigo INTEGER PRIMARY KEY,
          pro00_descri TEXT NOT NULL,
          pro00_unidad TEXT NOT NULL,
          pro00_pcomax REAL NOT NULL,
          pro00_codbar TEXT,
          pro00_qtdest REAL DEFAULT 0
        )
      ''');

      // Tabela de estoque particionado: estpro00
      await db.execute('''
        CREATE TABLE estpro00 (
          pro00_codpro TEXT NOT NULL,
          pro00_codfil TEXT NOT NULL,
          pro00_qtdest REAL NOT NULL
        )
      ''');

      // Popula dados para teste
      // 1. Produto 101: cadpro00 tem pcomax 15.50, unidade 'CX', qtdest 10.
      // Em estpro00: filial 1 tem 50.0, filial 2 tem 80.0
      await db.insert('cadpro00', {
        'pro00_codigo': 101,
        'pro00_descri': 'PRODUTO ALFA 101',
        'pro00_unidad': 'CX',
        'pro00_pcomax': 15.50,
        'pro00_codbar': '7891000101',
        'pro00_qtdest': 10.0,
      });
      await db.insert('estpro00', {
        'pro00_codpro': '101',
        'pro00_codfil': '1',
        'pro00_qtdest': 50.0,
      });
      await db.insert('estpro00', {
        'pro00_codpro': '101',
        'pro00_codfil': '2',
        'pro00_qtdest': 80.0,
      });

      // 2. Produto 202: existe apenas em cadpro00 (sem registro em estpro00) com estoque 35.0
      await db.insert('cadpro00', {
        'pro00_codigo': 202,
        'pro00_descri': 'PRODUTO BETA 202 (SEM ESTPRO)',
        'pro00_unidad': 'UN',
        'pro00_pcomax': 22.00,
        'pro00_codbar': '7891000202',
        'pro00_qtdest': 35.0,
      });

      // 3. Inserção de 150 produtos para teste de paginação (LIMIT 100 OFFSET :offset)
      final batch = db.batch();
      for (int i = 300; i < 450; i++) {
        batch.insert('cadpro00', {
          'pro00_codigo': i,
          'pro00_descri': 'PRODUTO PAGINADO ${i.toString().padLeft(4, '0')}',
          'pro00_unidad': 'UN',
          'pro00_pcomax': 10.0 + (i % 5),
          'pro00_codbar': 'EAN$i',
          'pro00_qtdest': 5.0,
        });
      }
      await batch.commit(noResult: true);

      // Cria os índices de performance recomendados
      await LocalSalesDatabaseService.criarIndicesBuscaEEstoque(db);
      await db.close();
    });

    test('1. Query oficial traz dados canônicos e respeita estoque da filial ativa 1', () async {
      final produtos = await buscaProduto(
        '101',
        null,
        null,
        null,
        null,
        null,
        false,
        false,
        1, // filial 1
        'Todas',
      );

      expect(produtos, isNotEmpty);
      final p101 = produtos.firstWhere((p) => p.codigo == '101');
      expect(p101.descricao, equals('PRODUTO ALFA 101'));
      expect(p101.unidade, equals('CX'));
      expect(p101.pcomax, equals(15.50));
      expect(p101.codbar, equals('7891000101'));
      expect(p101.saldoEstoque, equals(50.0), reason: 'Na filial 1 o saldo deve ser 50.0');
    });

    test('2. Query oficial filtra rigorosamente filial ativa 2 e não filial 1', () async {
      final produtos = await buscaProduto(
        '101',
        null,
        null,
        null,
        null,
        null,
        false,
        false,
        2, // filial 2
        'Todas',
      );

      expect(produtos, isNotEmpty);
      final p101 = produtos.firstWhere((p) => p.codigo == '101');
      expect(p101.saldoEstoque, equals(80.0), reason: 'Na filial 2 o saldo deve ser 80.0');
    });

    test('3. Saldo de estoque é 0.0 quando produto não possui estpro00 na filial ativa', () async {
      final produtos = await buscaProduto(
        '202',
        null,
        null,
        null,
        null,
        null,
        false,
        false,
        1,
        'Todas',
      );

      expect(produtos, isNotEmpty);
      final p202 = produtos.firstWhere((p) => p.codigo == '202');
      expect(p202.saldoEstoque, equals(0.0), reason: 'Sem estpro00 na filial ativa deve retornar 0.0');
      expect(p202.unidade, equals('UN'));
      expect(p202.pcomax, equals(22.00));
    });

    test('4. Paginação com LIMIT 100 e OFFSET fatia os resultados sem sobreposição', () async {
      // Página 1: offset 0
      final pagina1 = await buscaProduto(
        'PAGINADO',
        null,
        null,
        null,
        null,
        null,
        false,
        false,
        1,
        'Todas',
        null,
        0, // offset 0
      );

      expect(pagina1.length, equals(100));

      // Página 2: offset 100
      final pagina2 = await buscaProduto(
        'PAGINADO',
        null,
        null,
        null,
        null,
        null,
        false,
        false,
        1,
        'Todas',
        null,
        100, // offset 100
      );

      expect(pagina2.length, equals(50));

      // Garante que não há produto da página 1 na página 2
      final codigosPag1 = pagina1.map((p) => p.codigo).toSet();
      final codigosPag2 = pagina2.map((p) => p.codigo).toSet();
      final intersecao = codigosPag1.intersection(codigosPag2);
      expect(intersecao, isEmpty, reason: 'Páginas consecutivas não podem ter elementos repetidos');
    });

    test('5. Índices de performance existem no SQLite pós-carga', () async {
      final dbCheck = await openDatabase(dbPath, readOnly: true);
      final indicesEst = await dbCheck.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='index' AND tbl_name='estpro00'");
      final nomesEst = indicesEst.map((r) => r['name']?.toString() ?? '').toSet();
      expect(nomesEst, contains('idx_estpro00_filial_prod'));

      final indicesPro = await dbCheck.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='index' AND tbl_name='cadpro00'");
      final nomesPro = indicesPro.map((r) => r['name']?.toString() ?? '').toSet();
      expect(nomesPro, contains('idx_cadpro00_busca'));

      await dbCheck.close();
    });

    test('6. Desempenho da consulta de produtos responde em menos de 100ms', () async {
      final sw = Stopwatch()..start();
      final resultados = await buscaProduto(
        'PAGINADO',
        null,
        null,
        null,
        null,
        null,
        false,
        false,
        1,
        'Todas',
        null,
        0,
      );
      sw.stop();

      expect(resultados, isNotEmpty);
      expect(sw.elapsedMilliseconds, lessThan(100),
          reason: 'Consulta com índices deve responder em menos de 100ms');
    });
  });
}
