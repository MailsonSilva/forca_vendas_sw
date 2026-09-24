import 'package:flutter_test/flutter_test.dart';
import 'package:forca_de_vendas/action_code/busca_produto.dart';
import 'package:forca_de_vendas/action_code/pesquisa_cliente.dart';
import 'package:forca_de_vendas/data/services/local_sales_database_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart' as p;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('Otimização e Performance SQLite (Produtos e Clientes)', () {
    late String dbPath;
    late String dbCadPath;
    late Database db;
    late Database dbCad;

    setUp(() async {
      ProductDbMetadata.reset();
      dbPath = p.join(await getDatabasesPath(), LocalSalesDatabaseService.databaseName);
      dbCadPath = p.join(await getDatabasesPath(), 'dbforcacad001.db');
      db = await openDatabase(dbPath);
      dbCad = await openDatabase(dbCadPath);

      // Limpa tabelas
      await db.execute('DROP TABLE IF EXISTS cadpro00');
      await db.execute('DROP TABLE IF EXISTS estpro00');
      await db.execute('DROP TABLE IF EXISTS cadcli00');

      await dbCad.execute('DROP TABLE IF EXISTS cadmar00');
      await dbCad.execute('DROP TABLE IF EXISTS estpcopro00');
      await dbCad.execute('CREATE TABLE IF NOT EXISTS cadmar00 (mar00_codigo INTEGER PRIMARY KEY, mar00_descri TEXT)');
      await dbCad.execute('CREATE TABLE IF NOT EXISTS estpcopro00 (pro00_codpro TEXT, pro00_codtab INTEGER, pro00_pcosub REAL, pro00_preco REAL)');

      await dbCad.execute('CREATE TABLE IF NOT EXISTS cadpro00 (pro00_codigo TEXT PRIMARY KEY, pro00_descri TEXT, pro00_unidad TEXT, pro00_pcomax REAL, pro00_codbar TEXT, pro00_qtdest REAL DEFAULT 0, pro00_codmar INTEGER)');
      await dbCad.execute('CREATE TABLE IF NOT EXISTS estpro00 (pro00_codpro TEXT, pro00_codfil INTEGER, pro00_qtdest REAL DEFAULT 0, pro00_qtdpen REAL DEFAULT 0)');
      await dbCad.execute('DELETE FROM cadpro00');
      await dbCad.execute('DELETE FROM estpro00');
      await dbCad.execute('DELETE FROM cadmar00');
      await dbCad.execute('DELETE FROM estpcopro00');

      // Cria cadpro00
      const createCadpro = '''
        CREATE TABLE IF NOT EXISTS cadpro00 (
          pro00_codigo TEXT PRIMARY KEY,
          pro00_descri TEXT,
          pro00_unidad TEXT,
          pro00_pcomax REAL,
          pro00_codbar TEXT,
          pro00_qtdest REAL DEFAULT 0,
          pro00_codmar INTEGER
        )
      ''';
      await db.execute(createCadpro);
      await dbCad.execute(createCadpro);

      // Cria estpro00
      const createEstpro = '''
        CREATE TABLE IF NOT EXISTS estpro00 (
          pro00_codpro TEXT,
          pro00_codfil INTEGER,
          pro00_qtdest REAL DEFAULT 0,
          pro00_qtdpen REAL DEFAULT 0
        )
      ''';
      await db.execute(createEstpro);
      await dbCad.execute(createEstpro);

      // Cria cadcli00
      await db.execute('''
        CREATE TABLE cadcli00 (
          cli00_codigo INTEGER PRIMARY KEY,
          cli00_descri TEXT,
          cli00_fantas TEXT,
          cli00_cpfcnp TEXT,
          cli00_ciddes TEXT,
          cli00_estsgl TEXT,
          cli00_creatu REAL DEFAULT 0,
          cli00_titven REAL DEFAULT 0,
          cli00_active INTEGER DEFAULT 1
        )
      ''');

      // Cria índices solicitados no plano
      await db.execute('CREATE INDEX IF NOT EXISTS idx_cadpro00_busca ON cadpro00(pro00_descri, pro00_codigo, pro00_codbar)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_estpro00_filial_pro ON estpro00(pro00_codpro, pro00_codfil)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_cadcli00_busca ON cadcli00(cli00_descri, cli00_fantas, cli00_codigo, cli00_cpfcnp)');

      await dbCad.execute('CREATE INDEX IF NOT EXISTS idx_cadpro00_busca ON cadpro00(pro00_descri, pro00_codigo, pro00_codbar)');
      await dbCad.execute('CREATE INDEX IF NOT EXISTS idx_estpro00_filial_pro ON estpro00(pro00_codpro, pro00_codfil)');

      // Popula dados para teste de busca e paginação
      final batch = db.batch();
      final batchCad = dbCad.batch();
      batchCad.insert('cadmar00', {'mar00_codigo': 10, 'mar00_descri': 'MARCA TESTE'});

      for (int i = 1; i <= 150; i++) {
        final codPro = i.toString().padLeft(4, '0');
        final proMap = {
          'pro00_codigo': codPro,
          'pro00_descri': 'PRODUTO REGISTRO $codPro',
          'pro00_unidad': 'UN',
          'pro00_pcomax': 100.0 + i,
          'pro00_codbar': '789000000$codPro',
          'pro00_qtdest': 50.0,
          'pro00_codmar': 10,
        };
        batch.insert('cadpro00', proMap, conflictAlgorithm: ConflictAlgorithm.replace);
        batchCad.insert('cadpro00', proMap, conflictAlgorithm: ConflictAlgorithm.replace);

        final estMap = {
          'pro00_codpro': codPro,
          'pro00_codfil': 1,
          'pro00_qtdest': 80.0,
          'pro00_qtdpen': 0.0,
        };
        batch.insert('estpro00', estMap, conflictAlgorithm: ConflictAlgorithm.replace);
        batchCad.insert('estpro00', estMap, conflictAlgorithm: ConflictAlgorithm.replace);

        batchCad.insert('estpcopro00', {
          'pro00_codpro': codPro,
          'pro00_codtab': 1,
          'pro00_pcosub': 150.0 + i,
          'pro00_preco': 150.0 + i,
        }, conflictAlgorithm: ConflictAlgorithm.replace);

        final codCli = i;
        final doc = (10000000000 + i).toString(); // CPF sintético
        batch.insert('cadcli00', {
          'cli00_codigo': codCli,
          'cli00_descri': 'CLIENTE TESTE $codCli',
          'cli00_fantas': 'FANTASIA $codCli',
          'cli00_cpfcnp': doc,
          'cli00_ciddes': 'GOIANIA',
          'cli00_estsgl': 'GO',
          'cli00_creatu': 5000.0,
          'cli00_titven': 0.0,
          'cli00_active': 1,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await batch.commit(noResult: true);
      await batchCad.commit(noResult: true);

      // Cria índice cobridor para keyset pagination
      await db.execute('CREATE INDEX IF NOT EXISTS idx_cadpro00_order ON cadpro00(pro00_descri ASC, pro00_codigo)');
      await dbCad.execute('CREATE INDEX IF NOT EXISTS idx_cadpro00_order ON cadpro00(pro00_descri ASC, pro00_codigo)');

      await db.close();
      await dbCad.close();
    });

    test('EXPLAIN QUERY PLAN comprova uso de índices nas consultas', () async {
      final testDb = await openDatabase(dbPath);

      // Query de Produtos com cursor keyset: EXPLAIN QUERY PLAN
      final explainProd = await testDb.rawQuery('''
        EXPLAIN QUERY PLAN
        SELECT 
          p.pro00_codigo, 
          p.pro00_descri, 
          p.pro00_unidad, 
          p.pro00_pcomax, 
          p.pro00_codbar, 
          COALESCE(e.pro00_qtdest, p.pro00_qtdest, 0) AS pro00_qtdest
        FROM cadpro00 p
        LEFT JOIN estpro00 e ON e.pro00_codpro = p.pro00_codigo 
                             AND e.pro00_codfil = 1
        WHERE p.pro00_descri > 'PRODUTO REGISTRO 0050'
        ORDER BY p.pro00_descri ASC
        LIMIT 100;
      ''');

      final planTextProd = explainProd.map((e) => e['detail'].toString()).join(' | ');
      expect(
        planTextProd.contains('USING INDEX') || planTextProd.contains('USING PRIMARY KEY') || planTextProd.contains('idx_cadpro00_order'),
        isTrue,
        reason: 'A query de produto com cursor keyset deve utilizar índice. Plano: $planTextProd',
      );

      // 2. Query de Clientes: EXPLAIN QUERY PLAN
      final explainCli = await testDb.rawQuery('''
        EXPLAIN QUERY PLAN
        SELECT 
          cli00_codigo, 
          cli00_descri, 
          cli00_fantas, 
          cli00_cpfcnp, 
          cli00_ciddes, 
          cli00_estsgl, 
          cli00_creatu, 
          cli00_titven
        FROM cadcli00
        WHERE cli00_codigo = 1
        ORDER BY cli00_descri ASC
        LIMIT 100 OFFSET 0;
      ''');

      final planTextCli = explainCli.map((e) => e['detail'].toString()).join(' | ');
      expect(
        planTextCli.contains('USING INDEX') ||
            planTextCli.contains('USING PRIMARY KEY') ||
            planTextCli.contains('USING INTEGER PRIMARY KEY') ||
            planTextCli.contains('idx_cadcli00_busca'),
        isTrue,
        reason: 'A query de cliente deve utilizar índice ou primary key. Plano: $planTextCli',
      );

      await testDb.close();
    });

    test('pesquisaCliente sanitiza máscara de CPF/CNPJ e busca por documento formatado', () async {
      // Registro tem CPF limpo: "10000000010"
      // Usuário busca formatado com pontos e traço: "100.000.000-10"
      final resultadoFormatado = await pesquisaCliente('100.000.000-10', 0);
      expect(resultadoFormatado.isNotEmpty, isTrue);
      expect(resultadoFormatado.first.cli00Codigo, equals(10));

      // Busca por código direto
      final resultadoCod = await pesquisaCliente('10', 0);
      expect(resultadoCod.any((c) => c.cli00Codigo == 10), isTrue);

      // Busca textual por razão social
      final resultadoTexto = await pesquisaCliente('CLIENTE TESTE 10', 0);
      expect(resultadoTexto.any((c) => c.cli00Codigo == 10), isTrue);
    });

    test('pesquisaCliente e buscaProduto retornam listagem completa conforme SPEC-053', () async {
      // 1. Clientes
      final listaCli = await pesquisaCliente('');
      expect(listaCli.length, greaterThanOrEqualTo(100));
      expect(listaCli.first.cli00Codigo, isNotNull);

      // 2. Produtos
      final listaProd = await buscaProduto('', null, null, null, null, null, false, false, 1, 'Todas');
      expect(listaProd.length, greaterThanOrEqualTo(100));
      expect(listaProd.first.codigo, isNotEmpty);
    });

    test('buscaProduto traz Preço, Marca e Estoque corretos com persistência em memória', () async {
      final listaProd = await buscaProduto('', null, null, null, null, null, false, false, 1, 'Todas', 1);
      expect(listaProd.isNotEmpty, isTrue);
      final primeiro = listaProd.first;
      expect(primeiro.codigo, isNotEmpty);
      expect(primeiro.marca, equals('MARCA TESTE'));
      expect(primeiro.saldoEstoque, equals(80.0));
      expect(primeiro.preco, equals(151.0));
    });
  });
}
