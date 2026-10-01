import 'package:flutter_test/flutter_test.dart';
import 'package:forca_de_vendas/action_code/carregar_produto_detalhe.dart';
import 'package:forca_de_vendas/data/repositories/produto_repository.dart';
import 'package:forca_de_vendas/data/services/local_sales_database_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('Triage: carregarProdutoDetalhe e obterDetalhesProduto em banco padrão', () {
    late Database db;

    setUp(() async {
      db = await openDatabase(inMemoryDatabasePath);
      LocalSalesDatabaseService.setDatabaseForTesting(db);

      await db.execute('''
        CREATE TABLE cadpro00 (
          pro00_codigo TEXT PRIMARY KEY,
          pro00_descri TEXT,
          pro00_unidad TEXT,
          pro00_codbar TEXT,
          pro00_codmar INTEGER,
          pro00_codfab INTEGER,
          pro00_ref001 TEXT,
          pro00_ref002 TEXT,
          pro00_embala TEXT,
          pro00_qtdest REAL DEFAULT 0
        )
      ''');

      await db.insert('cadpro00', {
        'pro00_codigo': '101',
        'pro00_descri': 'PRODUTO TESTE 01',
        'pro00_unidad': 'UN',
        'pro00_codbar': '7890001',
        'pro00_codmar': 10,
        'pro00_codfab': 20,
        'pro00_ref001': 'REF-A1',
        'pro00_ref002': 'REF-B2',
        'pro00_embala': 'CX 12 UN',
        'pro00_qtdest': 50.0,
      });
    });

    tearDown(() async {
      LocalSalesDatabaseService.setDatabaseForTesting(null);
      await db.close();
    });

    test('reproduz a falha ao carregar detalhes quando tabelas auxiliares opcionais não existem', () async {
      final repo = ProdutoRepository();
      // Deve conseguir carregar o detalhe do produto 101 mesmo se tabelas auxiliares não existirem!
      final detalhe = await repo.obterDetalhesProduto(101, 1);
      expect(detalhe, isNotNull);
      expect(detalhe!.codigo, 101);
      expect(detalhe.descricao, 'PRODUTO TESTE 01');

      final result = await carregarProdutoDetalhe('101');
      expect(result, isNotNull);
      expect(result!.codigo, '101');
      expect(result.descricao, 'PRODUTO TESTE 01');
    });
  });
}
