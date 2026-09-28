import 'package:flutter_test/flutter_test.dart';
import 'package:forca_de_vendas/domain/services/produto_search_filter_builder.dart';

void main() {
  group('ProdutoSearchFilterBuilder', () {
    test('1. Pesquisa por Nome - Termo simples: deve prefixar e buscar início de palavras', () {
      final res = ProdutoSearchFilterBuilder.build(
        input: 'Luva',
        colDesc: 'p.pro00_descri',
      );

      expect(res.hasFilter, isTrue);
      expect(res.sql, '(p.pro00_descri LIKE ? OR p.pro00_descri LIKE ?)');
      expect(res.binds, ['Luva%', '% Luva%']);
    });

    test('1.1. Pesquisa por Nome - Termo com espaços nas bordas', () {
      final res = ProdutoSearchFilterBuilder.build(
        input: '  Bota  ',
        colDesc: 'p.pro00_descri',
      );

      expect(res.hasFilter, isTrue);
      expect(res.sql, '(p.pro00_descri LIKE ? OR p.pro00_descri LIKE ?)');
      expect(res.binds, ['Bota%', '% Bota%']);
    });

    test('2. Pesquisa por Curinga % - Duas partes ex: Luva%azul', () {
      final res = ProdutoSearchFilterBuilder.build(
        input: 'Luva%azul',
        colDesc: 'p.pro00_descri',
      );

      expect(res.hasFilter, isTrue);
      expect(res.sql, 'p.pro00_descri LIKE ?');
      expect(res.binds, ['%Luva%azul%']);
    });

    test('2.1. Pesquisa por Curinga % - Múltiplas partes com espaços ex: Luva % diadora % azul', () {
      final res = ProdutoSearchFilterBuilder.build(
        input: 'Luva % diadora % azul',
        colDesc: 'p.pro00_descri',
      );

      expect(res.hasFilter, isTrue);
      expect(res.sql, 'p.pro00_descri LIKE ?');
      expect(res.binds, ['%Luva%diadora%azul%']);
    });

    test('2.2. Pesquisa por Curinga % - Apenas uma parte com curinga no final ex: Luva%', () {
      final res = ProdutoSearchFilterBuilder.build(
        input: 'Luva%',
        colDesc: 'p.pro00_descri',
      );

      expect(res.hasFilter, isTrue);
      expect(res.sql, 'p.pro00_descri LIKE ?');
      expect(res.binds, ['Luva%']);
    });

    test('2.3. Pesquisa por Curinga % - Apenas % puro não deve gerar cláusula', () {
      final res = ProdutoSearchFilterBuilder.build(
        input: ' %%% ',
        colDesc: 'p.pro00_descri',
      );

      expect(res.hasFilter, isFalse);
      expect(res.sql, isEmpty);
      expect(res.binds, isEmpty);
    });

    test('3. Pesquisa Numérica - Padrão numérico sem prefixo (código ou ean)', () {
      final res = ProdutoSearchFilterBuilder.build(
        input: '15159',
        colCod: 'p.pro00_codigo',
        colCodbar: 'p.pro00_codbar',
      );

      expect(res.hasFilter, isTrue);
      expect(res.sql, '(CAST(p.pro00_codigo AS TEXT) = ? OR p.pro00_codbar = ?)');
      expect(res.binds, ['15159', '15159']);
    });

    test('3.1. Pesquisa Numérica - Sem coluna de código de barras disponível', () {
      final res = ProdutoSearchFilterBuilder.build(
        input: '15159',
        colCod: 'p.pro00_codigo',
        colCodbar: null,
      );

      expect(res.hasFilter, isTrue);
      expect(res.sql, 'CAST(p.pro00_codigo AS TEXT) = ?');
      expect(res.binds, ['15159']);
    });

    test('4. Pesquisa por Referência com Prefixo @ - Descarta @ e filtra colunas de ref', () {
      final res = ProdutoSearchFilterBuilder.build(
        input: '@15487',
        colRefs: ['p.pro00_ref001', 'p.pro00_ref002', 'p.pro00_reffor'],
      );

      expect(res.hasFilter, isTrue);
      expect(res.sql, '(p.pro00_ref001 LIKE ? OR p.pro00_ref002 LIKE ? OR p.pro00_reffor LIKE ?)');
      expect(res.binds, ['15487%', '15487%', '15487%']);
    });

    test('4.1. Pesquisa por Referência com Prefixo @ e alfanumérico ex: @df1526', () {
      final res = ProdutoSearchFilterBuilder.build(
        input: '@df1526',
        colRefs: ['p.pro00_ref001', 'p.pro00_ref002', 'p.pro00_reffor'],
      );

      expect(res.hasFilter, isTrue);
      expect(res.sql, '(p.pro00_ref001 LIKE ? OR p.pro00_ref002 LIKE ? OR p.pro00_reffor LIKE ?)');
      expect(res.binds, ['df1526%', 'df1526%', 'df1526%']);
    });

    test('4.2. Pesquisa por Referência com @ vazio ou apenas espaços', () {
      final res = ProdutoSearchFilterBuilder.build(
        input: '@   ',
        colRefs: ['p.pro00_ref001', 'p.pro00_ref002', 'p.pro00_reffor'],
      );

      expect(res.hasFilter, isFalse);
      expect(res.sql, isEmpty);
      expect(res.binds, isEmpty);
    });

    test('5. Input vazio ou nulo não gera filtro', () {
      final resNull = ProdutoSearchFilterBuilder.build(input: null);
      expect(resNull.hasFilter, isFalse);

      final resVazio = ProdutoSearchFilterBuilder.build(input: '   ');
      expect(resVazio.hasFilter, isFalse);
    });
  });
}
