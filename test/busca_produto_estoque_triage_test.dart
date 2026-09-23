import 'package:flutter_test/flutter_test.dart';
import 'package:forca_de_vendas/action_code/busca_produto.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart' as p;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('Triage Estoque em buscaProduto', () {
    late String dbPath;

    setUp(() async {
      dbPath = p.join(await getDatabasesPath(), 'dbforcacad001.db');
      final db = await openDatabase(dbPath);

      await db.execute('DROP TABLE IF EXISTS cadpro00');
      await db.execute('DROP TABLE IF EXISTS estpro00');
      await db.execute('DROP TABLE IF EXISTS estpcopro00');
      await db.execute('DROP TABLE IF EXISTS pckvendig000');
      await db.execute('DROP TABLE IF EXISTS pckvendig010');

      // Schema realístico com pro00_codigo INTEGER e pro00_qtdest
      await db.execute('''
        CREATE TABLE cadpro00 (
          pro00_codigo INTEGER PRIMARY KEY,
          pro00_descri TEXT,
          pro00_unidad TEXT,
          pro00_qtdest REAL DEFAULT 0,
          pro00_codbar TEXT
        )
      ''');

      // estpro00 com pro00_codfil TEXT ('01') e pro00_codpro TEXT ('101')
      await db.execute('''
        CREATE TABLE estpro00 (
          pro00_codpro TEXT,
          pro00_codfil TEXT,
          pro00_qtdest REAL,
          pro00_qtdpen REAL
        )
      ''');

      // 1. Produto 101: INTEGER em cadpro00, TEXT '101' e filial '01' em estpro00 (Estoque = 75)
      await db.insert('cadpro00', {
        'pro00_codigo': 101,
        'pro00_descri': 'PRODUTO COM FILIAL FORMATADA EM TEXTO',
        'pro00_unidad': 'UN',
        'pro00_qtdest': 0.0,
      });
      await db.insert('estpro00', {
        'pro00_codpro': '101',
        'pro00_codfil': '01',
        'pro00_qtdest': 75.0,
        'pro00_qtdpen': 0.0,
      });

      // 2. Produto 202: INTEGER 202 em cadpro00 com estoque 40 direto em cadpro00 (sem estpro00)
      await db.insert('cadpro00', {
        'pro00_codigo': 202,
        'pro00_descri': 'PRODUTO COM ESTOQUE APENAS EM CADPRO',
        'pro00_unidad': 'CX',
        'pro00_qtdest': 40.0,
      });

      // 3. Produto 303: Código com zero à esquerda em estpro00 ('00303') e cadpro00 (303)
      await db.insert('cadpro00', {
        'pro00_codigo': 303,
        'pro00_descri': 'PRODUTO COM CODIGO COM ZEROS A ESQUERDA',
        'pro00_unidad': 'FD',
        'pro00_qtdest': 0.0,
      });
      await db.insert('estpro00', {
        'pro00_codpro': '00303',
        'pro00_codfil': '1',
        'pro00_qtdest': 25.0,
        'pro00_qtdpen': 0.0,
      });

      await db.close();
    });

    test('deve trazer estoque quando pro00_codfil for "01" e filial pesquisada for 1', () async {
      final produtos = await buscaProduto(
        '101',
        null,
        null,
        null,
        null,
        null,
        false,
        false,
        1, // int 1
        'Todas',
      );

      expect(produtos, isNotEmpty);
      final p101 = produtos.firstWhere((p) => p.codigo == '101');
      expect(p101.saldoEstoque, equals(75.0),
          reason: 'Estoque de produto com filial "01" deve ser 75.0 e não 0.0');
    });

    test('deve trazer estoque 0.0 quando produto não tiver estpro00 na filial ativa', () async {
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
      expect(p202.saldoEstoque, equals(0.0),
          reason: 'Estoque de produto sem estpro00 na filial ativa deve ser 0.0 conforme SPEC-052');
    });

    test('deve trazer estoque quando estpro00 tiver código do produto com zeros à esquerda "00303"', () async {
      final produtos = await buscaProduto(
        '303',
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
      final p303 = produtos.firstWhere((p) => p.codigo == '303');
      expect(p303.saldoEstoque, equals(25.0),
          reason: 'Estoque de produto com zero à esquerda deve ser 25.0');
    });
  });
}
