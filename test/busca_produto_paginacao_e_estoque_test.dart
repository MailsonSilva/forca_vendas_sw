import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart' as p;
import 'package:forca_de_vendas/action_code/busca_produto.dart';
import 'package:forca_de_vendas/data/repositories/produto_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('Busca de Produtos - Paginação e Filtro de Estoque', () {
    late String dbPath;

    setUp(() async {
      ProdutoMetadataCache.reset();
      dbPath = p.join(await getDatabasesPath(), 'dbforcacad001.db');
      final db = await openDatabase(dbPath);

      await db.execute('DROP TABLE IF EXISTS cadpro00');
      await db.execute('DROP TABLE IF EXISTS estpro00');
      await db.execute('DROP TABLE IF EXISTS estpcopro00');
      await db.execute('DROP TABLE IF EXISTS estpcoreg00');
      await db.execute('DROP TABLE IF EXISTS estpcoregpco00');
      await db.execute('DROP TABLE IF EXISTS cadmar00');
      await db.execute('DROP TABLE IF EXISTS cadfor00');

      await db.execute('''
        CREATE TABLE cadpro00 (
          pro00_codigo INTEGER PRIMARY KEY,
          pro00_descri TEXT,
          pro00_unidad TEXT,
          pro00_codbar TEXT,
          pro00_qtdest REAL DEFAULT 0
        )
      ''');

      await db.execute('''
        CREATE TABLE estpro00 (
          pro00_codpro INTEGER,
          pro00_codfil INTEGER,
          pro00_qtdest REAL,
          pro00_qtdpen REAL
        )
      ''');

      await db.execute('''
        CREATE TABLE estpcopro00 (
          pro00_codpro INTEGER,
          pro00_codtab INTEGER,
          pro00_pcosub REAL
        )
      ''');

      // Inserir 60 produtos:
      // Produtos 1 a 40: estoque ZERO
      // Produtos 41 a 60: estoque POSITIVO (10 unidades)
      final batch = db.batch();
      for (int i = 1; i <= 60; i++) {
        final codFormat = i.toString().padLeft(4, '0');
        batch.insert('cadpro00', {
          'pro00_codigo': i,
          'pro00_descri': 'PRODUTO TESTE $codFormat',
          'pro00_unidad': 'UN',
          'pro00_codbar': '789$codFormat',
          'pro00_qtdest': 0.0,
        });

        batch.insert('estpro00', {
          'pro00_codpro': i,
          'pro00_codfil': 1,
          'pro00_qtdest': i > 40 ? 10.0 : 0.0,
          'pro00_qtdpen': 0.0,
        });

        batch.insert('estpcopro00', {
          'pro00_codpro': i,
          'pro00_codtab': 1,
          'pro00_pcosub': 25.50,
        });
      }
      await batch.commit(noResult: true);
      await db.close();
    });

    test('apenasEstoque=true retorna produtos mesmo que os primeiros de cadpro00 não tenham estoque', () async {
      // Se houvesse o bug de subquery com LIMIT 30 antes do filtro de estoque, retornaria vazio
      // porque produtos 1 a 30 têm estoque ZERO!
      final prodsComEstoque = await buscaProduto(
        '',
        null,
        null,
        null,
        null,
        null,
        true, // apenasEstoque
        false,
        1,
        'Todas',
        1,
        0,
        30,
      );

      expect(prodsComEstoque, isNotEmpty);
      expect(prodsComEstoque.length, equals(20)); // produtos 41 a 60
      expect(prodsComEstoque.every((p) => p.saldoEstoque > 0), isTrue);
      expect(prodsComEstoque.first.codigo, equals('41'));
    });

    test('buscaProduto paginação com offset e limit funciona corretamente', () async {
      final p1 = await buscaProduto(
        '',
        null,
        null,
        null,
        null,
        null,
        false,
        false,
        1,
        'Todas',
        1,
        0, // offset 0
        25, // limit 25
      );
      expect(p1.length, equals(25));
      expect(p1.first.codigo, equals('1'));
      expect(p1.last.codigo, equals('25'));

      final p2 = await buscaProduto(
        '',
        null,
        null,
        null,
        null,
        null,
        false,
        false,
        1,
        'Todas',
        1,
        25, // offset 25
        25, // limit 25
      );
      expect(p2.length, equals(25));
      expect(p2.first.codigo, equals('26'));
      expect(p2.last.codigo, equals('50'));
    });
  });
}
