import 'package:flutter_test/flutter_test.dart';
import 'package:forca_de_vendas/action_code/busca_produto.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart' as p;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('buscaProduto Tests', () {
    late String dbPath;

    setUp(() async {
      dbPath = p.join(await getDatabasesPath(), 'dbforcacad001.db');
      final db = await openDatabase(dbPath);

      await db.execute('DROP TABLE IF EXISTS cadpro00');
      await db.execute('DROP TABLE IF EXISTS estpro00');
      await db.execute('DROP TABLE IF EXISTS estpcopro00');
      await db.execute('DROP TABLE IF EXISTS pckvendig000');
      await db.execute('DROP TABLE IF EXISTS pckvendig010');

      await db.execute('DROP TABLE IF EXISTS cadmar00');
      await db.execute('DROP TABLE IF EXISTS cadfor00');

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
          pro00_embala TEXT
        )
      ''');

      await db.execute('''
        CREATE TABLE cadmar00 (
          mar00_codigo INTEGER PRIMARY KEY,
          mar00_descri TEXT
        )
      ''');

      await db.execute('''
        CREATE TABLE cadfor00 (
          for00_codigo INTEGER PRIMARY KEY,
          for00_descri TEXT
        )
      ''');

      await db.insert('cadmar00', {'mar00_codigo': 10, 'mar00_descri': 'NESTLÉ'});
      await db.insert('cadfor00', {'for00_codigo': 20, 'for00_descri': 'NESTLÉ BRASIL LTDA'});

      await db.execute('''
        CREATE TABLE estpro00 (
          pro00_codpro TEXT,
          pro00_codfil INTEGER,
          pro00_qtdest REAL,
          pro00_qtdpen REAL
        )
      ''');

      await db.execute('''
        CREATE TABLE estpcopro00 (
          pro00_codpro TEXT,
          pro00_codtab INTEGER,
          pro00_pcosub REAL
        )
      ''');

      await db.execute('''
        CREATE TABLE pckvendig000 (
          ped00_numped INTEGER PRIMARY KEY,
          ped00_sttdig INTEGER DEFAULT 0
        )
      ''');

      await db.execute('''
        CREATE TABLE pckvendig010 (
          ped10_numped INTEGER,
          ped10_codprd TEXT,
          ped10_qtdped REAL,
          ped10_qtdbon REAL
        )
      ''');

      // Inserir produto de teste com EAN, Marca, Referências e Fabricante
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
      });

      // Inserir segundo produto com outra marca e referência
      await db.insert('cadpro00', {
        'pro00_codigo': '102',
        'pro00_descri': 'BISCOITO CRACKER',
        'pro00_unidad': 'PCT',
        'pro00_codbar': '7890002999',
        'pro00_codmar': 10,
        'pro00_codfab': 20,
        'pro00_ref001': 'REF-CRACKER',
        'pro00_ref002': null,
        'pro00_embala': 'FD 30 UN',
      });

      // Estoque bruto = 50, pendente = 5 -> saldo inicial sem rascunho = 45
      await db.insert('estpro00', {
        'pro00_codpro': '101',
        'pro00_codfil': 1,
        'pro00_qtdest': 50.0,
        'pro00_qtdpen': 5.0,
      });

      // Preços: Tabela 1 = R$ 10.00, Tabela 2 = R$ 15.00
      await db.insert('estpcopro00', {
        'pro00_codpro': '101',
        'pro00_codtab': 1,
        'pro00_pcosub': 10.0,
      });
      await db.insert('estpcopro00', {
        'pro00_codpro': '101',
        'pro00_codtab': 2,
        'pro00_pcosub': 15.0,
      });

      await db.close();
    });

    test('buscaProduto lista produtos e calcula saldo disponível da filial ativa (pro00_qtdest - pro00_qtdpen)', () async {
      final res = await buscaProduto(
        '101',
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
      expect(res.isNotEmpty, isTrue);
      final p101 = res.first;
      expect(p101.codigo, equals('101'));
      expect(p101.descricao, equals('PRODUTO TESTE 01'));
      expect(p101.unidade, equals('UN'));
      expect(p101.codbar, equals('7890001'));
      expect(p101.saldoEstoque, equals(45.0)); // 50 - 5
      expect(p101.marca, equals('NESTLÉ'));
      expect(p101.fabricante, equals('NESTLÉ BRASIL LTDA'));
      expect(p101.referencia1, equals('REF-A1'));
      expect(p101.referencia2, equals('REF-B2'));
      expect(p101.embalagem, equals('CX 12 UN'));
    });

    test('buscaProduto localiza produto por código de barras (EAN)', () async {
      final resEan = await buscaProduto(
        '7890002999',
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
      expect(resEan.length, equals(1));
      expect(resEan.first.codigo, equals('102'));
      expect(resEan.first.descricao, equals('BISCOITO CRACKER'));
      expect(resEan.first.codbar, equals('7890002999'));
      expect(resEan.first.referencia1, equals('REF-CRACKER'));
      expect(resEan.first.embalagem, equals('FD 30 UN'));
    });

    test('buscaProduto retorna produtos ordenados por descrição quando termo for vazio', () async {
      final res = await buscaProduto(
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
      );
      expect(res.length, equals(2));
      expect(res[0].codigo, equals('102')); // BISCOITO CRACKER
      expect(res[1].codigo, equals('101')); // PRODUTO TESTE 01
    });

    test('buscaProduto localiza produtos por marca no termo de busca', () async {
      final resMarca = await buscaProduto(
        'NESTLÉ',
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
      expect(resMarca.length, equals(2));
      expect(resMarca.every((p) => p.marca == 'NESTLÉ'), isTrue);
    });

    test('buscaProduto localiza produto por referência', () async {
      final resRef = await buscaProduto(
        'REF-CRACKER',
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
      expect(resRef.length, equals(1));
      expect(resRef.first.codigo, equals('102'));
      expect(resRef.first.referencia1, equals('REF-CRACKER'));
    });

    test('buscaProduto aplica filtro avançado de marca', () async {
      final resFiltroMarca = await buscaProduto(
        '',
        null,
        null,
        null,
        null,
        'NESTLÉ',
        false,
        false,
        1,
        'Todas',
      );
      expect(resFiltroMarca.length, equals(2));
      expect(resFiltroMarca.every((p) => p.marca == 'NESTLÉ'), isTrue);
    });
  });
}
