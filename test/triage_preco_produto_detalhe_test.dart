import 'package:flutter_test/flutter_test.dart';
import 'package:forca_de_vendas/action_code/carregar_produto_detalhe.dart';
import 'package:forca_de_vendas/data/repositories/produto_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart' as p;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('Triage: Preço do produto na tela de informações do produto', () {
    late String dbPath;

    setUp(() async {
      dbPath = p.join(await getDatabasesPath(), 'dbforcacad001.db');
      final db = await openDatabase(dbPath);

      await db.execute('DROP TABLE IF EXISTS cadpro00');
      await db.execute('DROP TABLE IF EXISTS estpro00');
      await db.execute('DROP TABLE IF EXISTS estpcopro00');

      await db.execute('''
        CREATE TABLE cadpro00 (
          pro00_codigo TEXT PRIMARY KEY,
          pro00_descri TEXT,
          pro00_unidad TEXT,
          pro00_codbar TEXT,
          pro00_preco REAL DEFAULT 0,
          pro00_qtdest REAL DEFAULT 0
        )
      ''');

      await db.execute('''
        CREATE TABLE estpcopro00 (
          pro00_codpro TEXT,
          pro00_codtab INTEGER,
          pro00_pcosub REAL,
          pro00_preco REAL
        )
      ''');

      // Produto 101: pro00_pcosub é NULL, pro00_preco é 49.90
      await db.insert('cadpro00', {
        'pro00_codigo': '101',
        'pro00_descri': 'PRODUTO COM PRECO BASE EM PRO00_PRECO',
        'pro00_unidad': 'UN',
        'pro00_codbar': '7890001',
        'pro00_qtdest': 10.0,
      });

      await db.insert('estpcopro00', {
        'pro00_codpro': '101',
        'pro00_codtab': 1,
        'pro00_pcosub': null,
        'pro00_preco': 49.90,
      });

      // Produto 102: pro00_pcosub é 25.50
      await db.insert('cadpro00', {
        'pro00_codigo': '102',
        'pro00_descri': 'PRODUTO COM PCOSUB',
        'pro00_unidad': 'UN',
        'pro00_codbar': '7890002',
        'pro00_qtdest': 5.0,
      });

      await db.insert('estpcopro00', {
        'pro00_codpro': '102',
        'pro00_codtab': 1,
        'pro00_pcosub': 25.50,
        'pro00_preco': 30.00,
      });

      await db.close();
    });

    test('obterDetalhesProduto e carregarProdutoDetalhe devem trazer preco_venda de estpcopro00 via COALESCE(t.pro00_pcosub, t.pro00_preco, 0.0)', () async {
      final repo = ProdutoRepository();

      // Produto 101: deve trazer 49.90
      final detalhe101 = await repo.obterDetalhesProduto(101, 1);
      expect(detalhe101, isNotNull);
      expect(detalhe101!.preco, equals(49.90));

      final res101 = await carregarProdutoDetalhe('101');
      expect(res101, isNotNull);
      expect(res101!.preco, equals(49.90));

      // Produto 102: deve trazer 25.50 (pro00_pcosub)
      final detalhe102 = await repo.obterDetalhesProduto(102, 1);
      expect(detalhe102, isNotNull);
      expect(detalhe102!.preco, equals(25.50));

      final res102 = await carregarProdutoDetalhe('102');
      expect(res102, isNotNull);
      expect(res102!.preco, equals(25.50));
    });
  });
}
