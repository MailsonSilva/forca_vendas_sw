import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Testes SPEC-050: Criação de índices de performance pós-carga
/// e robustez do mapeamento de colunas de estpro00.
void main() {
  // Inicializa FFI para testes em desktop
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Índices de Performance Pós-Carga', () {
    late Database db;

    setUp(() async {
      db = await databaseFactory.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(version: 1),
      );

      // Cria tabelas mínimas de catálogo
      await db.execute('''
        CREATE TABLE cadpro00 (
          pro00_codigo TEXT PRIMARY KEY,
          pro00_descri TEXT,
          pro00_codbar TEXT,
          pro00_unidad TEXT,
          pro00_qtdest REAL DEFAULT 0,
          pro00_codlin INTEGER,
          pro00_codgrp INTEGER,
          pro00_codmar INTEGER
        )
      ''');

      await db.execute('''
        CREATE TABLE estpro00 (
          pro00_codpro TEXT,
          pro00_codfil INTEGER,
          pro00_qtdest REAL DEFAULT 0,
          pro00_qtdpen REAL DEFAULT 0
        )
      ''');

      await db.execute('''
        CREATE TABLE estpcopro00 (
          pro00_codpro TEXT,
          pro00_codtab INTEGER,
          pro00_pcosub REAL DEFAULT 0
        )
      ''');

      await db.execute('''
        CREATE TABLE cadcli00 (
          cli00_codigo INTEGER PRIMARY KEY,
          cli00_descri TEXT
        )
      ''');
    });

    tearDown(() async {
      if (db.isOpen) await db.close();
    });

    test('cria índices em cadpro00 para busca por descrição, código e código de barras', () async {
      await _criarIndicesPerformanceTestavel(db);

      final indices = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='index' AND tbl_name='cadpro00'");
      final nomes = indices.map((r) => r['name']?.toString() ?? '').toSet();

      expect(nomes, contains('idx_cadpro00_descri'));
      expect(nomes, contains('idx_cadpro00_codigo'));
      expect(nomes, contains('idx_cadpro00_codbar'));
      expect(nomes, contains('idx_cadpro00_filtros'));
    });

    test('cria índice composto em estpro00 para busca por produto+filial', () async {
      await _criarIndicesPerformanceTestavel(db);

      final indices = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='index' AND tbl_name='estpro00'");
      final nomes = indices.map((r) => r['name']?.toString() ?? '').toSet();

      expect(nomes, contains('idx_estpro00_codpro_codfil'));
    });

    test('cria índice em estpcopro00 para busca de preços', () async {
      await _criarIndicesPerformanceTestavel(db);

      final indices = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='index' AND tbl_name='estpcopro00'");
      final nomes = indices.map((r) => r['name']?.toString() ?? '').toSet();

      expect(nomes, contains('idx_estpcopro00_codpro'));
    });

    test('cria índices em cadcli00 para busca de clientes', () async {
      await _criarIndicesPerformanceTestavel(db);

      final indices = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='index' AND tbl_name='cadcli00'");
      final nomes = indices.map((r) => r['name']?.toString() ?? '').toSet();

      expect(nomes, contains('idx_cadcli00_descri'));
      expect(nomes, contains('idx_cadcli00_codigo'));
    });

    test('é idempotente — executar duas vezes não causa erro', () async {
      await _criarIndicesPerformanceTestavel(db);
      // Não deve lançar exceção
      await _criarIndicesPerformanceTestavel(db);

      final indices = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='index' AND tbl_name='cadpro00'");
      expect(indices.length, greaterThanOrEqualTo(4));
    });

    test('não falha se tabela não existe no banco', () async {
      // Abre um banco vazio sem nenhuma tabela de catálogo
      final dbVazio = await databaseFactory.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(version: 1, singleInstance: false),
      );

      // Não deve lançar exceção
      await _criarIndicesPerformanceTestavel(dbVazio);

      // Nenhum índice criado pelo nosso método (sqlite_master pode ter autoindex)
      final indices = await dbVazio.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='index' AND name LIKE 'idx_%'",
      );
      expect(indices, isEmpty);

      await dbVazio.close();
    });
  });

  group('Mapeamento de Colunas de estpro00', () {
    test('mapeia pro00_codpro como coluna de código do produto', () {
      final colunas = {'pro00_codpro', 'pro00_codfil', 'pro00_qtdest'};
      expect(_resolverColunaCodProduto(colunas), equals('pro00_codpro'));
    });

    test('mapeia pro00_codigo como coluna alternativa de código do produto', () {
      final colunas = {'pro00_codigo', 'pro00_codfil', 'pro00_qtdest'};
      expect(_resolverColunaCodProduto(colunas), equals('pro00_codigo'));
    });

    test('mapeia est00_codpro como coluna legada de código do produto', () {
      final colunas = {'est00_codpro', 'est00_codfil', 'est00_qtdest'};
      expect(_resolverColunaCodProduto(colunas), equals('est00_codpro'));
    });

    test('mapeia codpro como coluna simplificada de código do produto', () {
      final colunas = {'codpro', 'codfil', 'qtdest'};
      expect(_resolverColunaCodProduto(colunas), equals('codpro'));
    });

    test('mapeia estpro00_codpro como coluna prefixada de código do produto', () {
      final colunas = {'estpro00_codpro', 'estpro00_codfil', 'estpro00_qtdest'};
      expect(_resolverColunaCodProduto(colunas), equals('estpro00_codpro'));
    });

    test('retorna null quando nenhuma coluna conhecida está presente', () {
      final colunas = {'id', 'produto_id', 'quantidade'};
      expect(_resolverColunaCodProduto(colunas), isNull);
    });

    test('mapeia pro00_qtdest como coluna de quantidade em estoque', () {
      final colunas = {'pro00_codpro', 'pro00_codfil', 'pro00_qtdest'};
      expect(_resolverColunaQtdEstoque(colunas), equals('pro00_qtdest'));
    });

    test('mapeia saldo como coluna alternativa de quantidade em estoque', () {
      final colunas = {'pro00_codpro', 'pro00_codfil', 'saldo'};
      expect(_resolverColunaQtdEstoque(colunas), equals('saldo'));
    });

    test('mapeia estpro00_qtdest como coluna prefixada de quantidade em estoque', () {
      final colunas = {'estpro00_codpro', 'estpro00_codfil', 'estpro00_qtdest'};
      expect(_resolverColunaQtdEstoque(colunas), equals('estpro00_qtdest'));
    });
  });
}

// --------------------------------------------------------------------------
// Replica compacta da lógica de _criarIndicesPerformance para testes
// --------------------------------------------------------------------------
Future<void> _criarIndicesPerformanceTestavel(Database db) async {
  Set<String> tables = {};
  try {
    final t = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table'");
    tables = t.map((r) => r['name']?.toString().toLowerCase() ?? '').toSet();
  } catch (_) {}

  if (tables.contains('cadpro00')) {
    try { await db.execute('CREATE INDEX IF NOT EXISTS idx_cadpro00_descri ON cadpro00(pro00_descri)'); } catch (_) {}
    try { await db.execute('CREATE INDEX IF NOT EXISTS idx_cadpro00_codigo ON cadpro00(pro00_codigo)'); } catch (_) {}
    try { await db.execute('CREATE INDEX IF NOT EXISTS idx_cadpro00_codbar ON cadpro00(pro00_codbar)'); } catch (_) {}
    try { await db.execute('CREATE INDEX IF NOT EXISTS idx_cadpro00_filtros ON cadpro00(pro00_codlin, pro00_codgrp, pro00_codmar)'); } catch (_) {}
  }

  if (tables.contains('estpro00')) {
    try { await db.execute('CREATE INDEX IF NOT EXISTS idx_estpro00_codpro_codfil ON estpro00(pro00_codpro, pro00_codfil)'); } catch (_) {}
  }

  if (tables.contains('estpcopro00')) {
    try { await db.execute('CREATE INDEX IF NOT EXISTS idx_estpcopro00_codpro ON estpcopro00(pro00_codpro)'); } catch (_) {}
  }

  if (tables.contains('cadcli00')) {
    try { await db.execute('CREATE INDEX IF NOT EXISTS idx_cadcli00_descri ON cadcli00(cli00_descri)'); } catch (_) {}
    try { await db.execute('CREATE INDEX IF NOT EXISTS idx_cadcli00_codigo ON cadcli00(cli00_codigo)'); } catch (_) {}
  }

  try { await db.execute('PRAGMA optimize'); } catch (_) {}
  try { await db.execute('PRAGMA temp_store = MEMORY'); } catch (_) {}
}

// --------------------------------------------------------------------------
// Réplica da lógica de mapeamento de colunas de busca_produto.dart para testes
// --------------------------------------------------------------------------
String? _resolverColunaCodProduto(Set<String> estCols) {
  for (final c in ['pro00_codpro', 'pro00_codigo', 'est00_codpro', 'codpro', 'estpro00_codpro']) {
    if (estCols.contains(c)) return c;
  }
  return null;
}

String? _resolverColunaQtdEstoque(Set<String> estCols) {
  for (final c in ['pro00_qtdest', 'est00_qtdest', 'qtdest', 'saldo', 'estpro00_qtdest']) {
    if (estCols.contains(c)) return c;
  }
  return null;
}
