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

    test('buscaProduto filters price by active price table (codTabela)', () async {
      // Busca com tabela 1
      final resTab1 = await buscaProduto(
        '101',
        0,
        null,
        null,
        null,
        null,
        false,
        false,
        1,
        'Todas',
        1,
      );
      expect(resTab1.isNotEmpty, isTrue);
      expect(resTab1.first.preco, equals(10.0));

      // Busca com tabela 2
      final resTab2 = await buscaProduto(
        '101',
        0,
        null,
        null,
        null,
        null,
        false,
        false,
        1,
        'Todas',
        2,
      );
      expect(resTab2.isNotEmpty, isTrue);
      expect(resTab2.first.preco, equals(15.0));
    });

    test('buscaProduto deducts real-time local draft items from stock balance', () async {
      // Antes de rascunho: saldo = 50 - 5 = 45
      final resSemRascunho = await buscaProduto(
        '101',
        0,
        null,
        null,
        null,
        null,
        false,
        false,
        1,
        'Todas',
        1,
      );
      expect(resSemRascunho.first.saldoEstoque, equals(45.0));

      // Adiciona um pedido em rascunho (sttdig = 0) com 12 unidades reservadas
      final db = await openDatabase(dbPath);
      await db.insert('pckvendig000', {'ped00_numped': 9001, 'ped00_sttdig': 0});
      await db.insert('pckvendig010', {
        'ped10_numped': 9001,
        'ped10_codprd': '101',
        'ped10_qtdped': 10.0,
        'ped10_qtdbon': 2.0,
      });
      await db.close();

      // Após rascunho: saldo = 50 - 5 - 12 = 33
      final resComRascunho = await buscaProduto(
        '101',
        0,
        null,
        null,
        null,
        null,
        false,
        false,
        1,
        'Todas',
        1,
      );
      expect(resComRascunho.first.saldoEstoque, equals(33.0));
    });

    test('buscaProduto localiza por EAN, Marca, Referencia e preenche novos campos no ProdutoResultStruct', () async {
      // 1. Busca por Código EAN
      final resEan = await buscaProduto('7890002999', 0, null, null, null, null, false, false, 1, 'Todas');
      expect(resEan.length, equals(1));
      expect(resEan.first.codigo, equals('102'));
      expect(resEan.first.descricao, equals('BISCOITO CRACKER'));
      expect(resEan.first.codbar, equals('7890002999'));
      expect(resEan.first.marca, equals('NESTLÉ'));
      expect(resEan.first.fabricante, equals('NESTLÉ BRASIL LTDA'));
      expect(resEan.first.referencia1, equals('REF-CRACKER'));
      expect(resEan.first.referenciaFormatada, equals('REF-CRACKER'));
      expect(resEan.first.embalagem, equals('FD 30 UN'));

      // 2. Busca por Marca
      final resMarca = await buscaProduto('NESTLÉ', 0, null, null, null, null, false, false, 1, 'Todas');
      expect(resMarca.length, equals(2));

      // 3. Busca por Referência 1
      final resRef1 = await buscaProduto('REF-A1', 0, null, null, null, null, false, false, 1, 'Todas');
      expect(resRef1.length, equals(1));
      expect(resRef1.first.codigo, equals('101'));
      expect(resRef1.first.referenciaFormatada, equals('REF-A1 / REF-B2'));

      // 4. Busca por Referência 2
      final resRef2 = await buscaProduto('REF-B2', 0, null, null, null, null, false, false, 1, 'Todas');
      expect(resRef2.length, equals(1));
      expect(resRef2.first.codigo, equals('101'));
    });
  });
}
