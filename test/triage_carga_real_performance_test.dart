import 'package:flutter_test/flutter_test.dart';
import 'package:forca_de_vendas/action_code/busca_produto.dart';
import 'package:forca_de_vendas/action_code/carregar_produto_detalhe.dart';
import 'package:forca_de_vendas/action_code/pesquisa_cliente.dart';
import 'package:forca_de_vendas/data/services/local_sales_database_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('Triage Performance e Carga Real: Produtos e Clientes', () {
    late Database db;

    setUp(() async {
      db = await openDatabase(inMemoryDatabasePath);
      LocalSalesDatabaseService.setDatabaseForTesting(db);

      await db.execute('''
        CREATE TABLE cadcli00 (
          cli00_codigo INTEGER PRIMARY KEY,
          cli00_descri TEXT,
          cli00_fantas TEXT,
          cli00_cpfcnp TEXT,
          cli00_endere TEXT,
          cli00_ciddes TEXT,
          cli00_estsgl TEXT,
          cli00_active INTEGER DEFAULT 1
        )
      ''');

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
        CREATE TABLE estpcoreg00 (
          pro00_codpro INTEGER,
          pro00_codtab INTEGER,
          pro00_codreg INTEGER,
          pro00_codpco INTEGER,
          pro00_codkey INTEGER DEFAULT 1
        )
      ''');

      await db.execute('''
        CREATE TABLE estpro00 (
          pro00_codpro INTEGER,
          pro00_codfil INTEGER,
          pro00_qtdest REAL DEFAULT 0,
          pro00_qtdpen REAL DEFAULT 0
        )
      ''');

      await db.execute('''
        CREATE TABLE estpcoregpco00 (
          pro00_codseq INTEGER,
          pro00_pcomax REAL,
          pro00_pcomin REAL
        )
      ''');

      // Inserir produto 101
      await db.insert('cadpro00', {
        'pro00_codigo': 101,
        'pro00_descri': 'PRODUTO REAL 101',
        'pro00_unidad': 'UN',
        'pro00_codbar': '789101',
        'pro00_qtdest': 15.0,
      });

      // Inserir estoque particionado em estpro00 para a filial 1
      await db.insert('estpro00', {
        'pro00_codpro': 101,
        'pro00_codfil': 1,
        'pro00_qtdest': 50.0,
        'pro00_qtdpen': 10.0,
      });

      // Inserir relacionamento para o produto 101
      await db.insert('estpcoreg00', {
        'pro00_codpro': 101,
        'pro00_codtab': 1,
        'pro00_codreg': 1,
        'pro00_codpco': 10,
        'pro00_codkey': 1,
      });
      await db.insert('estpcoregpco00', {
        'pro00_codseq': 10,
        'pro00_pcomax': 45.0,
        'pro00_pcomin': 40.0,
      });

      // Inserir massa de outros produtos em estpcoreg00
      final batch = db.batch();
      for (int i = 200; i < 500; i++) {
        batch.insert('estpcoreg00', {
          'pro00_codpro': i,
          'pro00_codtab': 1,
          'pro00_codreg': 1,
          'pro00_codpco': i,
          'pro00_codkey': 1,
        });
        batch.insert('estpcoregpco00', {
          'pro00_codseq': i,
          'pro00_pcomax': 10.0 + i,
          'pro00_pcomin': 8.0 + i,
        });
      }
      await batch.commit(noResult: true);

      // Inserir cliente de teste com código formatado ou texto
      await db.insert('cadcli00', {
        'cli00_codigo': 42,
        'cli00_descri': 'MERCADO CENTRAL EIRELI',
        'cli00_fantas': 'MERCADO CENTRAL',
        'cli00_cpfcnp': '12.345.678/0001-90',
        'cli00_ciddes': 'SAO PAULO',
        'cli00_estsgl': 'SP',
        'cli00_active': 1,
      });
    });

    tearDown(() async {
      LocalSalesDatabaseService.setDatabaseForTesting(null);
      await db.close();
    });

    test('carregarProdutoDetalhe responde rápido e traz dados completos do produto 101', () async {
      final stopwatch = Stopwatch()..start();
      final detalhe = await carregarProdutoDetalhe('101');
      stopwatch.stop();

      expect(detalhe, isNotNull);
      expect(detalhe!.codigo, equals('101'));
      expect(detalhe.descricao, equals('PRODUTO REAL 101'));
      expect(stopwatch.elapsedMilliseconds, lessThan(300),
          reason: 'A consulta de detalhe deve ser imediata e filtrada por produto');
    });

    test('pesquisaCliente localiza cliente por código numérico e por nome em qualquer caixa', () async {
      // Busca por código
      final porCod = await pesquisaCliente('42');
      expect(porCod, isNotEmpty);
      expect(porCod.first.cli00Codigo, equals(42));

      // Busca por minúsculo
      final porMinusculo = await pesquisaCliente('mercado');
      expect(porMinusculo, isNotEmpty);
      expect(porMinusculo.first.cli00Descri, contains('MERCADO'));
    });

    test('carregarProdutoDetalhe e buscaProduto trazem estoque atual, pendente e disponível', () async {
      // 1. Detalhes do Produto
      final detalhe = await carregarProdutoDetalhe('101');
      expect(detalhe, isNotNull);
      expect(detalhe!.estoqueAtual, equals(50.0), reason: 'Estoque atual deve refletir estpro00');
      expect(detalhe.estoquePendente, equals(10.0), reason: 'Estoque pendente deve refletir estpro00.pro00_qtdpen');
      expect(detalhe.saldoEstoque, equals(40.0), reason: 'Saldo disponível deve ser atual - pendente');

      // 2. Busca de Produto na lista
      final lista = await buscaProduto('101', null, null, null, null, null, false, false, 1, 'Todas');
      expect(lista, isNotEmpty);
      final item = lista.firstWhere((p) => p.codigo == '101');
      expect(item.estoqueAtual, equals(50.0), reason: 'Estoque atual na lista');
      expect(item.estoquePendente, equals(10.0), reason: 'Estoque pendente na lista');
      expect(item.saldoEstoque, equals(40.0), reason: 'Saldo disponível na lista');
    });
  });
}
