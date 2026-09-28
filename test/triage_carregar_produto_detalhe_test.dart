import 'package:flutter_test/flutter_test.dart';
import 'package:forca_de_vendas/action_code/carregar_produto_detalhe.dart';
import 'package:forca_de_vendas/data/repositories/produto_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart' as p;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('Triage: carregarProdutoDetalhe e obterDetalhesProduto em banco padrão', () {
    late String dbPath;

    setUp(() async {
      dbPath = p.join(await getDatabasesPath(), 'dbforcacad001.db');
      final db = await openDatabase(dbPath);

      await db.execute('DROP TABLE IF EXISTS cadpro00');
      await db.execute('DROP TABLE IF EXISTS estpro00');
      await db.execute('DROP TABLE IF EXISTS estpcopro00');
      await db.execute('DROP TABLE IF EXISTS cadmar00');
      await db.execute('DROP TABLE IF EXISTS cadfor00');
      // Tabelas cadpro02, cadprofra00, cadprobon00, cadproemb00, estprodat00 NÃO EXISTEM neste banco padrão!
      await db.execute('DROP TABLE IF EXISTS cadpro02');
      await db.execute('DROP TABLE IF EXISTS cadprofra00');
      await db.execute('DROP TABLE IF EXISTS cadprobon00');
      await db.execute('DROP TABLE IF EXISTS cadproemb00');
      await db.execute('DROP TABLE IF EXISTS estprodat00');

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
