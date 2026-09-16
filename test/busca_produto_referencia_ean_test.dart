import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart' as p;
import 'package:forca_de_vendas/action_code/busca_produto.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('Referência e Código de Barras (EAN) do Produto', () {
    late String dbPath;

    setUp(() async {
      dbPath = p.join(await getDatabasesPath(), 'dbforcacad001.db');
      final db = await openDatabase(dbPath);

      await db.execute('DROP TABLE IF EXISTS cadpro00');
      await db.execute('DROP TABLE IF EXISTS cadmar00');
      await db.execute('DROP TABLE IF EXISTS cadfor00');
      await db.execute('DROP TABLE IF EXISTS estpro00');

      await db.execute('''
        CREATE TABLE cadpro00 (
          pro00_codigo TEXT PRIMARY KEY,
          pro00_descri TEXT,
          pro00_unidad TEXT,
          pro00_codbar TEXT,
          pro00_codmar INTEGER,
          pro00_codfab INTEGER,
          pro00_reffor TEXT,
          pro00_ref001 TEXT,
          pro00_ref002 TEXT,
          pro00_embala TEXT,
          pro00_qtdest REAL DEFAULT 0
        )
      ''');

      await db.execute('''
        CREATE TABLE cadmar00 (
          mar00_codigo INTEGER PRIMARY KEY,
          mar00_descri TEXT
        )
      ''');

      await db.insert('cadmar00', {'mar00_codigo': 1, 'mar00_descri': 'HONDA'});

      await db.insert('cadpro00', {
        'pro00_codigo': '2001',
        'pro00_descri': 'CABO DE EMBREAGEM',
        'pro00_unidad': 'PC',
        'pro00_codbar': '7891000241501',
        'pro00_codmar': 1,
        'pro00_reffor': 'REF-FORNECEDOR-999',
        'pro00_ref001': 'REF-HONDA-100',
        'pro00_ref002': 'FAB-200',
        'pro00_embala': 'PC',
        'pro00_qtdest': 50.0,
      });

      await db.insert('cadpro00', {
        'pro00_codigo': '2002',
        'pro00_descri': 'PASTILHA DE FREIO',
        'pro00_unidad': 'JG',
        'pro00_codbar': '7891000241502',
        'pro00_codmar': 1,
        'pro00_reffor': 'FORN-PAST-77',
        'pro00_embala': 'JG',
        'pro00_qtdest': 30.0,
      });

      await db.close();
    });

    test('query SQL de buscaProduto carrega pro00_codbar, ref001 e ref002', () async {
      final produtos = await buscaProduto(
        '2001', // busca por código
        0,
        '',
        '',
        '',
        '',
        false,
        false,
        1,
        'Todas',
      );

      expect(produtos.length, 1);
      final pItem = produtos.first;

      expect(pItem.codigo, '2001');
      expect(pItem.codbar, '7891000241501');
      expect(pItem.referencia1, 'REF-HONDA-100');
      expect(pItem.referencia2, 'FAB-200');
      expect(pItem.reffor, 'REF-FORNECEDOR-999');
      expect(pItem.referenciaFormatada, 'REF-FORNECEDOR-999');
      expect(pItem.marca, 'HONDA');
      expect(pItem.unidade, 'PC');
      expect(pItem.saldoEstoque, 50.0);
    });

    test('busca por código de barras encontra o produto corretamente', () async {
      final produtos = await buscaProduto(
        '7891000241501', // busca pelo código de barras / EAN
        0,
        '',
        '',
        '',
        '',
        false,
        false,
        1,
        'Todas',
      );

      expect(produtos.length, 1);
      expect(produtos.first.codigo, '2001');
      expect(produtos.first.codbar, '7891000241501');
    });

    test('busca por referência de fábrica encontra o produto corretamente', () async {
      final produtos = await buscaProduto(
        'REF-HONDA-100',
        0,
        '',
        '',
        '',
        '',
        false,
        false,
        1,
        'Todas',
      );

      expect(produtos.length, 1);
      expect(produtos.first.codigo, '2001');
      expect(produtos.first.referencia1, 'REF-HONDA-100');
    });

    test('carrega e busca pelo campo pro00_reffor da cadpro00 exibindo como referência', () async {
      final produtos = await buscaProduto(
        'FORN-PAST-77', // busca pelo valor do campo pro00_reffor
        0,
        '',
        '',
        '',
        '',
        false,
        false,
        1,
        'Todas',
      );

      expect(produtos.length, 1);
      final p = produtos.first;
      expect(p.codigo, '2002');
      expect(p.referenciaFormatada, 'FORN-PAST-77');
    });
  });
}
