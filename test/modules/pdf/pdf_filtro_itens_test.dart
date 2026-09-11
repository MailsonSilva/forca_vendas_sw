import 'package:flutter_test/flutter_test.dart';
import 'package:forca_de_vendas/modules/pdf/dtos/espelho_pedido_dto.dart';
import 'package:forca_de_vendas/modules/pdf/services/pdf_generator_service.dart';

void main() {
  // Fixture: mixed list of items with various characteristics
  final itens = [
    ItemEspelhoDTO(
      sequencial: 1,
      codigoProduto: 100,
      codigoEAN: '7891000000001',
      descricao: 'Produto Normal Sem Corte',
      marca: 'Marca A',
      quantidadeDigitada: 10,
      quantidadeFaturada: 10,
      precoUnitario: 20.0,
      valorTotal: 200.0,
    ),
    ItemEspelhoDTO(
      sequencial: 2,
      codigoProduto: 200,
      codigoEAN: '7891000000002',
      descricao: 'Produto Com Corte',
      marca: 'Marca B',
      quantidadeDigitada: 15,
      quantidadeFaturada: 10,
      precoUnitario: 30.0,
      valorTotal: 300.0,
    ),
    ItemEspelhoDTO(
      sequencial: 3,
      codigoProduto: 300,
      codigoEAN: '7891000000003',
      descricao: 'Produto Bonificado Sem Corte',
      marca: 'Marca C',
      quantidadeDigitada: 5,
      quantidadeFaturada: 5,
      precoUnitario: 0.0,
      valorTotal: 0.0,
      isBonificacao: true,
    ),
    ItemEspelhoDTO(
      sequencial: 4,
      codigoProduto: 400,
      codigoEAN: '7891000000004',
      descricao: 'Produto Bonificado Com Corte',
      marca: 'Marca D',
      quantidadeDigitada: 8,
      quantidadeFaturada: 3,
      precoUnitario: 0.0,
      valorTotal: 0.0,
      isBonificacao: true,
    ),
  ];

  group('FiltroItensPdf logic via aplicarFiltro', () {
    test('todos returns all items unchanged', () {
      final result = PdfGeneratorService.aplicarFiltro(itens, FiltroItensPdf.todos);
      expect(result.length, 4);
    });

    test('apenasCortes returns only items with corte > 0', () {
      final result = PdfGeneratorService.aplicarFiltro(itens, FiltroItensPdf.apenasCortes);
      expect(result.length, 2);
      expect(result.every((i) => i.corte > 0), isTrue);
      expect(result.map((i) => i.codigoProduto).toList(), [200, 400]);
    });

    test('semCortes returns only items with corte == 0', () {
      final result = PdfGeneratorService.aplicarFiltro(itens, FiltroItensPdf.semCortes);
      expect(result.length, 2);
      expect(result.every((i) => i.corte == 0), isTrue);
      expect(result.map((i) => i.codigoProduto).toList(), [100, 300]);
    });

    test('apenasBonificados returns only bonificacao items', () {
      final result = PdfGeneratorService.aplicarFiltro(itens, FiltroItensPdf.apenasBonificados);
      expect(result.length, 2);
      expect(result.every((i) => i.isBonificacao), isTrue);
      expect(result.map((i) => i.codigoProduto).toList(), [300, 400]);
    });

    test('apenasCortes returns empty list when no items have corte', () {
      final noCorteItems = [
        ItemEspelhoDTO(
          sequencial: 1,
          codigoProduto: 100,
          codigoEAN: '7891000000001',
          descricao: 'Sem Corte',
          marca: '',
          quantidadeDigitada: 5,
          quantidadeFaturada: 5,
          precoUnitario: 10.0,
          valorTotal: 50.0,
        ),
      ];
      final result = PdfGeneratorService.aplicarFiltro(noCorteItems, FiltroItensPdf.apenasCortes);
      expect(result, isEmpty);
    });

    test('apenasBonificados returns empty list when no items are bonificacao', () {
      final noBonifItems = [
        ItemEspelhoDTO(
          sequencial: 1,
          codigoProduto: 100,
          codigoEAN: '7891000000001',
          descricao: 'Normal',
          marca: '',
          quantidadeDigitada: 5,
          quantidadeFaturada: 5,
          precoUnitario: 10.0,
          valorTotal: 50.0,
        ),
      ];
      final result = PdfGeneratorService.aplicarFiltro(noBonifItems, FiltroItensPdf.apenasBonificados);
      expect(result, isEmpty);
    });

    test('all filters return empty list for empty input', () {
      for (final filtro in FiltroItensPdf.values) {
        final result = PdfGeneratorService.aplicarFiltro([], filtro);
        expect(result, isEmpty, reason: 'Filter $filtro should return empty for empty input');
      }
    });
  });
}
