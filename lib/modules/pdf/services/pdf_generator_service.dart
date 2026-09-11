import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../contracts/pdf_order_template.dart';
import '../dtos/espelho_pedido_dto.dart';
import '../templates/standard_pdf_order_template.dart';

/// Callback para carregamento de fontes.
/// Retorna um par (regular, bold) de fontes PDF.
typedef PdfFontLoader = Future<(pw.Font regular, pw.Font bold)> Function();

/// Carregamento padrão de fontes via Google Fonts (Roboto).
Future<(pw.Font, pw.Font)> _defaultFontLoader() async {
  final regular = await PdfGoogleFonts.robotoRegular();
  final bold = await PdfGoogleFonts.robotoBold();
  return (regular, bold);
}

/// Orquestra a geração, armazenamento temporário e compartilhamento
/// do PDF do Espelho de Venda.
///
/// Responsabilidades:
/// - Carregamento assíncrono de fontes TTF (Roboto via Google Fonts)
/// - Aplicação de filtros de itens ([FiltroItensPdf])
/// - Composição do PDF usando um [IPdfOrderTemplate] injetável
/// - Salvamento em cache temporário com nome único por timestamp
/// - Acionamento do modal nativo de compartilhamento via share_plus
class PdfGeneratorService {
  final IPdfOrderTemplate _defaultTemplate;
  final PdfFontLoader _fontLoader;

  PdfGeneratorService({
    IPdfOrderTemplate? template,
    PdfFontLoader? fontLoader,
  })  : _defaultTemplate = template ?? StandardPdfOrderTemplate(),
        _fontLoader = fontLoader ?? _defaultFontLoader;

  /// Filtra a lista de itens preservando o comportamento do sistema legado.
  ///
  /// Exposto como estático para permitir testes unitários diretos
  /// sem necessidade de instanciar o serviço completo.
  @visibleForTesting
  static List<ItemEspelhoDTO> aplicarFiltro(List<ItemEspelhoDTO> itens, FiltroItensPdf filtro) {
    switch (filtro) {
      case FiltroItensPdf.apenasCortes:
        return itens.where((i) => i.corte > 0).toList();
      case FiltroItensPdf.semCortes:
        return itens.where((i) => i.corte == 0).toList();
      case FiltroItensPdf.apenasBonificados:
        return itens.where((i) => i.isBonificacao).toList();
      case FiltroItensPdf.todos:
        return itens;
    }
  }

  /// Gera os bytes do PDF em memória aplicando o filtro de itens especificado.
  Future<Uint8List> generateOrderPdf({
    required EspelhoPedidoDTO pedido,
    FiltroItensPdf filtro = FiltroItensPdf.todos,
    IPdfOrderTemplate? customTemplate,
    PdfPageFormat pageFormat = PdfPageFormat.a4,
  }) async {
    final template = customTemplate ?? _defaultTemplate;
    final pdf = pw.Document();

    // Carregamento de fontes completas com suporte ao UTF-8 brasileiro e glifos especiais
    final (fontRegular, fontBold) = await _fontLoader();

    final itensFiltrados = aplicarFiltro(pedido.itens, filtro);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: pageFormat,
        margin: const pw.EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        header: (pw.Context context) => template.buildHeader(pedido, context, fontBold, fontRegular),
        footer: (pw.Context context) => template.buildFooter(context, fontRegular),
        build: (pw.Context context) => [
          template.buildCustomerAndOrderInfo(pedido, fontBold, fontRegular),
          template.buildItemsTable(itensFiltrados, fontBold, fontRegular),
          template.buildFinancialAndDuplicates(pedido, fontBold, fontRegular),
          template.buildTotalsSummary(pedido, fontBold, fontRegular),
          template.buildNotes(pedido.observacao, fontBold, fontRegular),
        ],
      ),
    );

    return pdf.save();
  }

  /// Salva em cache temporário com timestamp e aciona o modal nativo de compartilhamento.
  Future<void> shareOrderPdf({
    required EspelhoPedidoDTO pedido,
    FiltroItensPdf filtro = FiltroItensPdf.todos,
    IPdfOrderTemplate? customTemplate,
  }) async {
    final pdfBytes = await generateOrderPdf(
      pedido: pedido,
      filtro: filtro,
      customTemplate: customTemplate,
    );

    final tempDir = await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final filePath = "${tempDir.path}/Pedido_${pedido.numeroPedido}_$timestamp.pdf";
    final file = File(filePath);

    await file.writeAsBytes(pdfBytes, flush: true);

    // ignore: deprecated_member_use
    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'application/pdf')],
      text: "Segue o Espelho do Pedido #${pedido.numeroPedido} - ${pedido.clienteRazaoSocial}",
      subject: "Espelho do Pedido #${pedido.numeroPedido}",
    );
  }
}

