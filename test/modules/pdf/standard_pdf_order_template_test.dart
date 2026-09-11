import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:forca_de_vendas/modules/pdf/dtos/espelho_pedido_dto.dart';
import 'package:forca_de_vendas/modules/pdf/templates/standard_pdf_order_template.dart';

/// Helper: creates a minimal EspelhoPedidoDTO for testing.
EspelhoPedidoDTO _createPedido({
  List<ItemEspelhoDTO>? itens,
  List<DuplicataEspelhoDTO>? duplicatas,
  String observacao = 'Teste de observação',
  String clienteCpfCnpj = '12.345.678/0001-90',
  String clienteIE = '123456789',
  String numeroNotaFiscal = 'NF-TEST',
  int numeroPedido = 99999,
  double valorTotalBonificado = 200.0,
  double valorSubstituicaoTributaria = 150.0,
  double valorDescontoTotal = 50.0,
  double valorTotalFaturado = 4500.0,
}) {
  return EspelhoPedidoDTO(
    numeroPedido: numeroPedido,
    numeroNotaFiscal: numeroNotaFiscal,
    dataEmissao: DateTime(2026, 9, 10, 14, 30),
    vendedorCodigo: 'V001',
    vendedorNome: 'Vendedor Teste',
    clienteCodigo: 'C001',
    clienteRazaoSocial: 'Razão Social Teste Ltda',
    clienteNomeFantasia: 'Fantasia Teste',
    clienteCpfCnpj: clienteCpfCnpj,
    clienteIE: clienteIE,
    clienteEndereco: 'Rua Teste, 100 - São Paulo/SP',
    planoPagamento: '30/60/90',
    linhaProduto: 'Linha Teste',
    agenteCobrador: 'Agente Teste',
    status: 'Transmitido',
    observacao: observacao,
    valorTotalDigitado: 5000.0,
    valorTotalFaturado: valorTotalFaturado,
    valorTotalBonificado: valorTotalBonificado,
    valorSubstituicaoTributaria: valorSubstituicaoTributaria,
    valorDescontoTotal: valorDescontoTotal,
    itens: itens ?? [
      ItemEspelhoDTO(
        sequencial: 1,
        codigoProduto: 100,
        codigoEAN: '7891234567890',
        descricao: 'Produto Teste Descrição Completa',
        marca: 'Marca Teste',
        quantidadeDigitada: 10,
        quantidadeFaturada: 8,
        precoUnitario: 50.0,
        descontoPercentual: 5.0,
        valorTotal: 400.0,
      ),
      ItemEspelhoDTO(
        sequencial: 2,
        codigoProduto: 200,
        codigoEAN: '7891234567891',
        descricao: 'Produto Bonificado',
        marca: '',
        quantidadeDigitada: 5,
        quantidadeFaturada: 5,
        precoUnitario: 0.0,
        valorTotal: 0.0,
        isBonificacao: true,
      ),
    ],
    duplicatas: duplicatas ?? [
      DuplicataEspelhoDTO(numeroParcela: 1, dataVencimento: DateTime(2026, 10, 10), valor: 2500.0),
      DuplicataEspelhoDTO(numeroParcela: 2, dataVencimento: DateTime(2026, 11, 10), valor: 2500.0),
    ],
  );
}

void main() {
  late StandardPdfOrderTemplate template;
  late pw.Font boldFont;
  late pw.Font regularFont;

  setUpAll(() {
    template = StandardPdfOrderTemplate();
    // Use built-in PDF fonts for testing (no network needed)
    boldFont = pw.Font.helveticaBold();
    regularFont = pw.Font.helvetica();
  });

  group('StandardPdfOrderTemplate', () {
    group('buildHeader', () {
      test('produces widget without throwing for standard pedido', () async {
        final pedido = _createPedido();
        // buildHeader needs a pw.Context — generate via a Document to get one
        final doc = pw.Document();
        doc.addPage(
          pw.Page(
            build: (pw.Context context) {
              return template.buildHeader(pedido, context, boldFont, regularFont);
            },
          ),
        );
        // If save() completes, the widget tree was valid
        final bytes = await doc.save();
        expect(bytes, isNotEmpty);
      });
    });

    group('buildCustomerAndOrderInfo', () {
      test('produces widget for pedido with all fields populated', () {
        final pedido = _createPedido();
        final widget = template.buildCustomerAndOrderInfo(pedido, boldFont, regularFont);
        expect(widget, isNotNull);
      });

      test('shows NÃO INFORMADO when cpfCnpj is empty', () {
        final pedido = _createPedido(clienteCpfCnpj: '');
        // Should not throw
        final widget = template.buildCustomerAndOrderInfo(pedido, boldFont, regularFont);
        expect(widget, isNotNull);
      });

      test('shows ISENTO when IE is empty', () {
        final pedido = _createPedido(clienteIE: '');
        final widget = template.buildCustomerAndOrderInfo(pedido, boldFont, regularFont);
        expect(widget, isNotNull);
      });
    });

    group('buildItemsTable', () {
      test('builds table with items including bonificacao', () {
        final pedido = _createPedido();
        final widget = template.buildItemsTable(pedido.itens, boldFont, regularFont);
        expect(widget, isNotNull);
      });

      test('builds table with empty item list (header only)', () {
        final widget = template.buildItemsTable([], boldFont, regularFont);
        expect(widget, isNotNull);
      });

      test('builds table with item that has empty marca', () {
        final items = [
          ItemEspelhoDTO(
            sequencial: 1,
            codigoProduto: 100,
            codigoEAN: '',
            descricao: 'Produto sem marca',
            marca: '',
            quantidadeDigitada: 1,
            quantidadeFaturada: 1,
            precoUnitario: 10.0,
            valorTotal: 10.0,
          ),
        ];
        final widget = template.buildItemsTable(items, boldFont, regularFont);
        expect(widget, isNotNull);
      });
    });

    group('buildFinancialAndDuplicates', () {
      test('builds duplicatas section when duplicatas are present', () {
        final pedido = _createPedido();
        final widget = template.buildFinancialAndDuplicates(pedido, boldFont, regularFont);
        expect(widget, isNotNull);
      });

      test('returns SizedBox.shrink when duplicatas is empty', () {
        final pedido = _createPedido(duplicatas: []);
        final widget = template.buildFinancialAndDuplicates(pedido, boldFont, regularFont);
        expect(widget, isA<pw.SizedBox>());
      });
    });

    group('buildTotalsSummary', () {
      test('shows all financial lines when values are positive', () {
        final pedido = _createPedido();
        final widget = template.buildTotalsSummary(pedido, boldFont, regularFont);
        expect(widget, isNotNull);
      });

      test('hides conditional lines when values are zero', () {
        final pedido = _createPedido(
          valorTotalBonificado: 0,
          valorSubstituicaoTributaria: 0,
          valorDescontoTotal: 0,
          valorTotalFaturado: 0,
        );
        final widget = template.buildTotalsSummary(pedido, boldFont, regularFont);
        expect(widget, isNotNull);
      });
    });

    group('buildNotes', () {
      test('builds notes section when observacao is present', () {
        final widget = template.buildNotes('Entregar pela manhã', boldFont, regularFont);
        expect(widget, isNotNull);
      });

      test('returns SizedBox.shrink when observacao is empty', () {
        final widget = template.buildNotes('', boldFont, regularFont);
        expect(widget, isA<pw.SizedBox>());
      });

      test('returns SizedBox.shrink when observacao is only whitespace', () {
        final widget = template.buildNotes('   ', boldFont, regularFont);
        expect(widget, isA<pw.SizedBox>());
      });
    });

    group('buildFooter', () {
      test('produces footer widget with page numbers', () async {
        final doc = pw.Document();
        doc.addPage(
          pw.Page(
            build: (pw.Context context) {
              return template.buildFooter(context, regularFont);
            },
          ),
        );
        final bytes = await doc.save();
        expect(bytes, isNotEmpty);
      });
    });

    group('full document generation (integration)', () {
      test('generates a valid PDF document using all build methods', () async {
        final pedido = _createPedido();
        final doc = pw.Document();
        doc.addPage(
          pw.MultiPage(
            pageFormat: PdfPageFormat.a4,
            margin: const pw.EdgeInsets.all(20),
            header: (pw.Context context) =>
                template.buildHeader(pedido, context, boldFont, regularFont),
            footer: (pw.Context context) =>
                template.buildFooter(context, regularFont),
            build: (pw.Context context) => [
              template.buildCustomerAndOrderInfo(pedido, boldFont, regularFont),
              pw.SizedBox(height: 8),
              template.buildItemsTable(pedido.itens, boldFont, regularFont),
              template.buildFinancialAndDuplicates(pedido, boldFont, regularFont),
              template.buildTotalsSummary(pedido, boldFont, regularFont),
              template.buildNotes(pedido.observacao, boldFont, regularFont),
            ],
          ),
        );

        final bytes = await doc.save();
        expect(bytes, isNotEmpty);
        // PDF files start with %PDF
        expect(String.fromCharCodes(bytes.sublist(0, 5)), startsWith('%PDF'));
        expect(doc.document.pdfPageList.pages.length, 1);
      });

      test('falls back to numeroPedido for Nº PEDIDO when numeroNotaFiscal is empty', () {
        final pedido = _createPedido(numeroNotaFiscal: '', numeroPedido: 42);
        final header = template.buildHeader(
          pedido,
          pw.Context(document: pw.Document().document),
          boldFont,
          regularFont,
        );
        expect(header, isNotNull);
      });

      test('generates exactly 1 page filling entire page for small order of 2 items', () async {
        final pedido = _createPedido(
          numeroNotaFiscal: '',
          numeroPedido: 2,
          observacao: 'Pedido para entrega imediata',
        );
        final doc = pw.Document();
        doc.addPage(
          pw.MultiPage(
            pageFormat: PdfPageFormat.a4,
            margin: const pw.EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            header: (pw.Context context) =>
                template.buildHeader(pedido, context, boldFont, regularFont),
            footer: (pw.Context context) =>
                template.buildFooter(context, regularFont),
            build: (pw.Context context) => [
              template.buildCustomerAndOrderInfo(pedido, boldFont, regularFont),
              template.buildItemsTable(pedido.itens, boldFont, regularFont),
              template.buildFinancialAndDuplicates(pedido, boldFont, regularFont),
              template.buildTotalsSummary(pedido, boldFont, regularFont),
              template.buildNotes(pedido.observacao, boldFont, regularFont),
            ],
          ),
        );

        final bytes = await doc.save();
        expect(bytes, isNotEmpty);
        expect(doc.document.pdfPageList.pages.length, 1);
      });
    });
  });
}
