import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:forca_de_vendas/modules/pdf/dtos/espelho_pedido_dto.dart';
import 'package:forca_de_vendas/modules/pdf/contracts/pdf_order_template.dart';
import 'package:forca_de_vendas/modules/pdf/services/pdf_generator_service.dart';

/// Minimal template implementation that uses built-in fonts,
/// bypassing PdfGoogleFonts network calls in tests.
class _TestPdfOrderTemplate implements IPdfOrderTemplate {
  @override
  pw.Widget buildHeader(EspelhoPedidoDTO pedido, pw.Context context, pw.Font boldFont, pw.Font regularFont) {
    return pw.Text("PEDIDO: #${pedido.numeroPedido}", style: pw.TextStyle(font: boldFont, fontSize: 12));
  }

  @override
  pw.Widget buildCustomerAndOrderInfo(EspelhoPedidoDTO pedido, pw.Font boldFont, pw.Font regularFont) {
    return pw.Text("Cliente: ${pedido.clienteRazaoSocial}", style: pw.TextStyle(font: regularFont, fontSize: 8));
  }

  @override
  pw.Widget buildItemsTable(List<ItemEspelhoDTO> itens, pw.Font boldFont, pw.Font regularFont) {
    return pw.Column(
      children: itens.map((item) => pw.Text(
        "${item.sequencial} - ${item.descricao}: ${item.valorTotal}",
        style: pw.TextStyle(font: regularFont, fontSize: 7),
      )).toList(),
    );
  }

  @override
  pw.Widget buildFinancialAndDuplicates(EspelhoPedidoDTO pedido, pw.Font boldFont, pw.Font regularFont) {
    if (pedido.duplicatas.isEmpty) return pw.SizedBox.shrink();
    return pw.Text("Duplicatas: ${pedido.duplicatas.length}", style: pw.TextStyle(font: regularFont, fontSize: 7));
  }

  @override
  pw.Widget buildTotalsSummary(EspelhoPedidoDTO pedido, pw.Font boldFont, pw.Font regularFont) {
    return pw.Text("Total: ${pedido.valorTotalDigitado}", style: pw.TextStyle(font: boldFont, fontSize: 9));
  }

  @override
  pw.Widget buildNotes(String observacoes, pw.Font boldFont, pw.Font regularFont) {
    if (observacoes.trim().isEmpty) return pw.SizedBox.shrink();
    return pw.Text("Obs: $observacoes", style: pw.TextStyle(font: regularFont, fontSize: 7));
  }

  @override
  pw.Widget buildFooter(pw.Context context, pw.Font regularFont) {
    return pw.Text("Pagina ${context.pageNumber}", style: pw.TextStyle(font: regularFont, fontSize: 8));
  }
}

/// Helper: creates a full EspelhoPedidoDTO with diverse items for service testing.
EspelhoPedidoDTO _createFullPedido({
  String observacao = 'Entregar pela manhã',
  List<DuplicataEspelhoDTO>? duplicatas,
}) {
  return EspelhoPedidoDTO(
    numeroPedido: 12345,
    numeroNotaFiscal: 'NF-001',
    dataEmissao: DateTime(2026, 9, 10, 14, 30),
    vendedorCodigo: 'V001',
    vendedorNome: 'João Silva',
    clienteCodigo: 'C001',
    clienteRazaoSocial: 'Empresa ABC Ltda',
    clienteNomeFantasia: 'ABC Store',
    clienteCpfCnpj: '12.345.678/0001-90',
    clienteIE: '123456789',
    clienteEndereco: 'Rua das Flores, 123 - São Paulo/SP',
    planoPagamento: '30/60/90',
    linhaProduto: 'Linha Premium',
    agenteCobrador: 'Agente Carlos',
    status: 'Transmitido',
    observacao: observacao,
    valorTotalDigitado: 5000.0,
    valorTotalFaturado: 4500.0,
    valorTotalBonificado: 200.0,
    valorSubstituicaoTributaria: 150.0,
    valorDescontoTotal: 50.0,
    itens: [
      // Normal item, no corte
      ItemEspelhoDTO(
        sequencial: 1,
        codigoProduto: 100,
        codigoEAN: '7891000000001',
        descricao: 'Produto Normal',
        marca: 'Marca A',
        quantidadeDigitada: 10,
        quantidadeFaturada: 10,
        precoUnitario: 50.0,
        valorTotal: 500.0,
      ),
      // Item with corte
      ItemEspelhoDTO(
        sequencial: 2,
        codigoProduto: 200,
        codigoEAN: '7891000000002',
        descricao: 'Produto Com Corte',
        marca: 'Marca B',
        quantidadeDigitada: 20,
        quantidadeFaturada: 15,
        precoUnitario: 30.0,
        valorTotal: 450.0,
      ),
      // Bonificacao item
      ItemEspelhoDTO(
        sequencial: 3,
        codigoProduto: 300,
        codigoEAN: '7891000000003',
        descricao: 'Produto Bonificado',
        marca: 'Marca C',
        quantidadeDigitada: 5,
        quantidadeFaturada: 5,
        precoUnitario: 0.0,
        valorTotal: 0.0,
        isBonificacao: true,
      ),
    ],
    duplicatas: duplicatas ?? [
      DuplicataEspelhoDTO(numeroParcela: 1, dataVencimento: DateTime(2026, 10, 10), valor: 2250.0),
      DuplicataEspelhoDTO(numeroParcela: 2, dataVencimento: DateTime(2026, 11, 10), valor: 2250.0),
    ],
  );
}

void main() {
  late PdfGeneratorService service;
  late _TestPdfOrderTemplate testTemplate;

  setUp(() {
    testTemplate = _TestPdfOrderTemplate();
    service = PdfGeneratorService(
      template: testTemplate,
      fontLoader: () async => (pw.Font.helvetica(), pw.Font.helveticaBold()),
    );
  });

  group('PdfGeneratorService.generateOrderPdf', () {
    test('generates valid PDF bytes starting with %PDF header', () async {
      final pedido = _createFullPedido();

      final bytes = await service.generateOrderPdf(pedido: pedido);

      expect(bytes, isA<Uint8List>());
      expect(bytes.length, greaterThan(0));
      // PDF files always start with the magic bytes %PDF-
      final header = String.fromCharCodes(bytes.sublist(0, 5));
      expect(header, startsWith('%PDF'));
    });

    test('generates PDF with filtro todos (all 3 items)', () async {
      final pedido = _createFullPedido();

      final bytes = await service.generateOrderPdf(
        pedido: pedido,
        filtro: FiltroItensPdf.todos,
      );

      expect(bytes, isA<Uint8List>());
      expect(bytes.length, greaterThan(0));
    });

    test('generates PDF with filtro apenasCortes', () async {
      final pedido = _createFullPedido();

      final bytes = await service.generateOrderPdf(
        pedido: pedido,
        filtro: FiltroItensPdf.apenasCortes,
      );

      expect(bytes, isA<Uint8List>());
      expect(bytes.length, greaterThan(0));
    });

    test('generates PDF with filtro semCortes', () async {
      final pedido = _createFullPedido();

      final bytes = await service.generateOrderPdf(
        pedido: pedido,
        filtro: FiltroItensPdf.semCortes,
      );

      expect(bytes, isA<Uint8List>());
      expect(bytes.length, greaterThan(0));
    });

    test('generates PDF with filtro apenasBonificados', () async {
      final pedido = _createFullPedido();

      final bytes = await service.generateOrderPdf(
        pedido: pedido,
        filtro: FiltroItensPdf.apenasBonificados,
      );

      expect(bytes, isA<Uint8List>());
      expect(bytes.length, greaterThan(0));
    });

    test('generates PDF with empty duplicatas', () async {
      final pedido = _createFullPedido(duplicatas: []);

      final bytes = await service.generateOrderPdf(pedido: pedido);

      expect(bytes, isA<Uint8List>());
      expect(bytes.length, greaterThan(0));
    });

    test('generates PDF with empty observacao', () async {
      final pedido = _createFullPedido(observacao: '');

      final bytes = await service.generateOrderPdf(pedido: pedido);

      expect(bytes, isA<Uint8List>());
      expect(bytes.length, greaterThan(0));
    });

    test('accepts a custom template via constructor injection', () async {
      final customTemplate = _TestPdfOrderTemplate();
      final customService = PdfGeneratorService(
        template: customTemplate,
        fontLoader: () async => (pw.Font.helvetica(), pw.Font.helveticaBold()),
      );
      final pedido = _createFullPedido();

      final bytes = await customService.generateOrderPdf(pedido: pedido);

      expect(bytes, isA<Uint8List>());
      expect(bytes.length, greaterThan(0));
    });

    test('accepts a custom template via parameter override', () async {
      final pedido = _createFullPedido();
      final overrideTemplate = _TestPdfOrderTemplate();

      final bytes = await service.generateOrderPdf(
        pedido: pedido,
        customTemplate: overrideTemplate,
      );

      expect(bytes, isA<Uint8List>());
      expect(bytes.length, greaterThan(0));
    });

    test('accepts custom page format', () async {
      final pedido = _createFullPedido();

      final bytes = await service.generateOrderPdf(
        pedido: pedido,
        pageFormat: PdfPageFormat.letter,
      );

      expect(bytes, isA<Uint8List>());
      expect(bytes.length, greaterThan(0));
    });
  });
}
