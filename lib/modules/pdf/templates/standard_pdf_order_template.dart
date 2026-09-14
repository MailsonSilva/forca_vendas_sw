import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../contracts/pdf_order_template.dart';
import '../dtos/espelho_pedido_dto.dart';

/// Template padrão A4 para o Espelho de Venda / Pré-Pedido em PDF.
///
/// Reproduz fielmente o modelo impresso de Pré-Pedido:
/// - Cabeçalho: Quadro para imagem do cliente à esquerda, título PRÉ-PEDIDO,
///   vendedor e endereço da empresa ao centro, tabela Nº FORÇA/PEDIDO/PACOTE/STATUS à direita.
/// - Destinatário/Remetente: Tabela em grade com dados completos do cliente.
/// - Condições Comerciais: Barra retangular com Plano, Agente e Linha.
/// - Tabela de Produtos: Colunas COD/PRODUTO, QTD PED, QTD FAT, DESCRIÇÃO, UN, MARCA, VLR/UNIT, TOTAL.
///   Preenchimento com linhas vazias até o rodapé para manter o formato contínuo.
/// - Totais: Barra TOTAL PEDIDO com contagens de itens, quantidades, valores brutos e líquidos.
/// - Rodapé: Identificação institucional e numeração de páginas no formato "X / Y".
class StandardPdfOrderTemplate implements IPdfOrderTemplate {
  final NumberFormat _currencyFormat =
      NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
  final DateFormat _dateOnlyFormat = DateFormat('dd/MM/yyyy');

  String _formatQty(double value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }
    return value.toStringAsFixed(2);
  }

  String _formatMoney(double value) {
    return _currencyFormat.format(value).replaceAll('R\$', '').trim();
  }

  @override
  pw.Widget buildHeader(EspelhoPedidoDTO pedido, pw.Context context,
      pw.Font boldFont, pw.Font regularFont) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 4),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.black, width: 0.8),
      ),
      padding: const pw.EdgeInsets.all(3),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          // 1. Quadro Imagem do Cliente (Superior Esquerdo)
          pw.Container(
            width: 44,
            height: 44,
            /*decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.black, width: 0.6),
            ),*/
            alignment: pw.Alignment.center,
            child: pedido.clienteFotoBytes != null &&
                    pedido.clienteFotoBytes!.isNotEmpty
                ? pw.Image(pw.MemoryImage(pedido.clienteFotoBytes!),
                    fit: pw.BoxFit.contain)
                : pw.SizedBox.shrink(),
          ),

          pw.SizedBox(width: 4),

          // 2. Centro: Título PRÉ-PEDIDO, Vendedor, Dados da Empresa
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Text(
                  "PRÉ-PEDIDO",
                  style: pw.TextStyle(font: boldFont, fontSize: 10),
                  textAlign: pw.TextAlign.center,
                ),
                pw.Text(
                  "${pedido.vendedorCodigo.isNotEmpty ? pedido.vendedorCodigo : '0'} - ${pedido.vendedorNome.isNotEmpty ? pedido.vendedorNome : 'VENDEDOR'}",
                  style: pw.TextStyle(font: boldFont, fontSize: 6.5),
                  textAlign: pw.TextAlign.center,
                ),
                pw.SizedBox(height: 2),
                pw.Container(
                  width: double.infinity,
                  padding:
                      const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey500, width: 0.5),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(pedido.empresaEndereco,
                          style:
                              pw.TextStyle(font: regularFont, fontSize: 5.5)),
                      pw.Text(pedido.empresaBairroCep,
                          style:
                              pw.TextStyle(font: regularFont, fontSize: 5.5)),
                      pw.Text(pedido.empresaCidadeUf,
                          style:
                              pw.TextStyle(font: regularFont, fontSize: 5.5)),
                      pw.Text(pedido.empresaTelefone,
                          style:
                              pw.TextStyle(font: regularFont, fontSize: 5.5)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          pw.SizedBox(width: 4),

          // 3. Direita: Tabela Nº FORÇA, Nº PEDIDO, Nº PACOTE, STATUS
          pw.Container(
            width: 125,
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.black, width: 0.6),
            ),
            child: pw.Table(
              border: pw.TableBorder.all(color: PdfColors.black, width: 0.5),
              columnWidths: const {
                0: pw.FixedColumnWidth(52),
                1: pw.FlexColumnWidth(),
              },
              children: [
                _buildHeaderInfoRow("Nº FORÇA", "${pedido.numeroPedido}",
                    boldFont, regularFont),
                _buildHeaderInfoRow(
                    "Nº PEDIDO",
                    pedido.numeroNotaFiscal.isNotEmpty
                        ? pedido.numeroNotaFiscal
                        : "${pedido.numeroPedido}",
                    boldFont,
                    regularFont),
                _buildHeaderInfoRow(
                    "Nº PACOTE",
                    pedido.numeroPacote.isNotEmpty ? pedido.numeroPacote : "-",
                    boldFont,
                    regularFont),
                _buildHeaderInfoRow(
                    "STATUS",
                    pedido.status.isNotEmpty ? pedido.status : "Digitado",
                    boldFont,
                    regularFont),
              ],
            ),
          ),
        ],
      ),
    );
  }

  pw.TableRow _buildHeaderInfoRow(
      String label, String value, pw.Font boldFont, pw.Font regularFont) {
    return pw.TableRow(
      children: [
        pw.Container(
          color: const PdfColor.fromInt(0xFFF0F0F0),
          padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: pw.Text(label,
              style: pw.TextStyle(font: boldFont, fontSize: 6.5)),
        ),
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: pw.Text(value,
              style: pw.TextStyle(font: regularFont, fontSize: 6.5)),
        ),
      ],
    );
  }

  @override
  pw.Widget buildCustomerAndOrderInfo(
      EspelhoPedidoDTO pedido, pw.Font boldFont, pw.Font regularFont) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Título DESTINATÁRIO/REMETENTE
        pw.Text("DESTINATÁRIO/REMETENTE",
            style: pw.TextStyle(font: boldFont, fontSize: 6.5)),
        pw.SizedBox(height: 1),

        // Tabela com bordas finas contendo os dados do cliente
        pw.Container(
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.black, width: 0.6),
          ),
          child: pw.Column(
            children: [
              // Linha 1: CÓDIGO / RAZÃO SOCIAL | FANTASIA
              pw.Row(
                children: [
                  pw.Expanded(
                    flex: 6,
                    child: _buildClientCell(
                        "CÓDIGO / RAZÃO SOCIAL",
                        "${pedido.clienteCodigo} - ${pedido.clienteRazaoSocial}",
                        boldFont,
                        regularFont,
                        borderRight: true),
                  ),
                  pw.Expanded(
                    flex: 5,
                    child: _buildClientCell("FANTASIA",
                        pedido.clienteNomeFantasia, boldFont, regularFont),
                  ),
                ],
              ),
              pw.Divider(color: PdfColors.black, thickness: 0.5, height: 0),

              // Linha 2: ENDEREÇO | Nº | BAIRRO/DISTRITO | CEP | DATA DE EMISSÃO
              pw.Row(
                children: [
                  pw.Expanded(
                    flex: 5,
                    child: _buildClientCell("ENDEREÇO", pedido.clienteEndereco,
                        boldFont, regularFont,
                        borderRight: true),
                  ),
                  pw.Container(
                    width: 35,
                    child: _buildClientCell(
                        "Nº",
                        pedido.clienteNumero.isNotEmpty
                            ? pedido.clienteNumero
                            : "S/N",
                        boldFont,
                        regularFont,
                        borderRight: true),
                  ),
                  pw.Expanded(
                    flex: 3,
                    child: _buildClientCell("BAIRRO/DISTRITO",
                        pedido.clienteBairro, boldFont, regularFont,
                        borderRight: true),
                  ),
                  pw.Expanded(
                    flex: 2,
                    child: _buildClientCell(
                        "CEP", pedido.clienteCep, boldFont, regularFont,
                        borderRight: true),
                  ),
                  pw.Expanded(
                    flex: 2,
                    child: _buildClientCell(
                        "DATA DE EMISSÃO",
                        _dateOnlyFormat.format(pedido.dataEmissao),
                        boldFont,
                        regularFont),
                  ),
                ],
              ),
              pw.Divider(color: PdfColors.black, thickness: 0.5, height: 0),

              // Linha 3: MUNICÍPIO | UF | FONE/FAX | CNPJ / CPF | INSCRIÇÃO ESTADUAL
              pw.Row(
                children: [
                  pw.Expanded(
                    flex: 4,
                    child: _buildClientCell("MUNICÍPIO", pedido.clienteCidade,
                        boldFont, regularFont,
                        borderRight: true),
                  ),
                  pw.Container(
                    width: 25,
                    child: _buildClientCell(
                        "UF", pedido.clienteUf, boldFont, regularFont,
                        borderRight: true),
                  ),
                  pw.Expanded(
                    flex: 3,
                    child: _buildClientCell("FONE/FAX", pedido.clienteTelefone,
                        boldFont, regularFont,
                        borderRight: true),
                  ),
                  pw.Expanded(
                    flex: 3,
                    child: _buildClientCell(
                        "CNPJ / CPF",
                        pedido.clienteCpfCnpj.isNotEmpty
                            ? pedido.clienteCpfCnpj
                            : "NÃO INFORMADO",
                        boldFont,
                        regularFont,
                        borderRight: true),
                  ),
                  pw.Expanded(
                    flex: 3,
                    child: _buildClientCell(
                        "INSCRIÇÃO ESTADUAL",
                        pedido.clienteIE.isNotEmpty
                            ? pedido.clienteIE
                            : "ISENTO",
                        boldFont,
                        regularFont),
                  ),
                ],
              ),
            ],
          ),
        ),

        pw.SizedBox(height: 3),

        // Barra de Condições Comerciais (PLANO, AGENTE, LINHA)
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.black, width: 0.6),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text("PLANO: ${pedido.planoPagamento.toUpperCase()}",
                  style: pw.TextStyle(font: boldFont, fontSize: 7)),
              pw.Text("AGENTE: ${pedido.agenteCobrador.toUpperCase()}",
                  style: pw.TextStyle(font: boldFont, fontSize: 7)),
              pw.Text("LINHA: ${pedido.linhaProduto.toUpperCase()}",
                  style: pw.TextStyle(font: boldFont, fontSize: 7)),
            ],
          ),
        ),
      ],
    );
  }

  pw.Widget _buildClientCell(
      String label, String value, pw.Font boldFont, pw.Font regularFont,
      {bool borderRight = false}) {
    return pw.Container(
      decoration: borderRight
          ? const pw.BoxDecoration(
              border: pw.Border(
                  right: pw.BorderSide(color: PdfColors.black, width: 0.5)))
          : null,
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(label,
              style: pw.TextStyle(
                  font: regularFont, fontSize: 5.0, color: PdfColors.grey700)),
          pw.Text(value,
              style: pw.TextStyle(font: boldFont, fontSize: 7.0), maxLines: 1),
        ],
      ),
    );
  }

  @override
  pw.Widget buildItemsTable(
      List<ItemEspelhoDTO> itens, pw.Font boldFont, pw.Font regularFont) {
    const int targetRows = 48;
    final int emptyRowsNeeded =
        (targetRows - itens.length).clamp(0, targetRows);

    final tableRows = <pw.TableRow>[
      // Cabeçalho da Tabela
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFE0E0E0)),
        children: [
          _cellHeader("COD/PRODUTO", boldFont, align: pw.TextAlign.center),
          _cellHeader("QTD PED", boldFont, align: pw.TextAlign.center),
          _cellHeader("QTD FAT", boldFont, align: pw.TextAlign.center),
          _cellHeader("DESCRIÇÃO DO PRODUTO / SERVIÇO", boldFont,
              align: pw.TextAlign.left),
          _cellHeader("UN", boldFont, align: pw.TextAlign.center),
          _cellHeader("MARCA", boldFont, align: pw.TextAlign.left),
          _cellHeader("VLR / UNIT", boldFont, align: pw.TextAlign.right),
          _cellHeader("TOTAL", boldFont, align: pw.TextAlign.right),
        ],
      ),
    ];

    // Linhas de dados
    for (final item in itens) {
      tableRows.add(
        pw.TableRow(
          children: [
            _cellBody(
                "${item.codigoProduto > 0 ? item.codigoProduto : item.sequencial}",
                regularFont,
                align: pw.TextAlign.center),
            _cellBody(_formatQty(item.quantidadeDigitada), regularFont,
                align: pw.TextAlign.center),
            _cellBody(_formatQty(item.quantidadeFaturada), regularFont,
                align: pw.TextAlign.center),
            _cellBody(item.descricao, boldFont, align: pw.TextAlign.left),
            _cellBody(item.unidade, regularFont, align: pw.TextAlign.center),
            _cellBody(item.marca, regularFont, align: pw.TextAlign.left),
            _cellBody(_formatMoney(item.precoUnitario), regularFont,
                align: pw.TextAlign.right),
            _cellBody(_formatMoney(item.valorTotal), regularFont,
                align: pw.TextAlign.right),
          ],
        ),
      );
    }

    // Linhas de grade vazias para preencher a folha contínua
    for (int i = 0; i < emptyRowsNeeded; i++) {
      tableRows.add(
        pw.TableRow(
          children: [
            _cellEmpty(),
            _cellEmpty(),
            _cellEmpty(),
            _cellEmpty(),
            _cellEmpty(),
            _cellEmpty(),
            _cellEmpty(),
            _cellEmpty(),
          ],
        ),
      );
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(height: 3),
        pw.Text("DADOS DO PRODUTO/SERVIÇO",
            style: pw.TextStyle(font: boldFont, fontSize: 6.5)),
        pw.SizedBox(height: 1),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.black, width: 0.5),
          columnWidths: const {
            0: pw.FixedColumnWidth(50),
            1: pw.FixedColumnWidth(35),
            2: pw.FixedColumnWidth(35),
            3: pw.FlexColumnWidth(),
            4: pw.FixedColumnWidth(22),
            5: pw.FixedColumnWidth(60),
            6: pw.FixedColumnWidth(48),
            7: pw.FixedColumnWidth(48),
          },
          children: tableRows,
        ),
      ],
    );
  }

  pw.Widget _cellHeader(String title, pw.Font font,
      {pw.TextAlign align = pw.TextAlign.left}) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 2, vertical: 2),
      child: pw.Text(
        title,
        textAlign: align,
        style: pw.TextStyle(font: font, fontSize: 5.5),
      ),
    );
  }

  pw.Widget _cellBody(String text, pw.Font font,
      {pw.TextAlign align = pw.TextAlign.left}) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 2, vertical: 1.5),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(font: font, fontSize: 6.0),
        maxLines: 1,
      ),
    );
  }

  pw.Widget _cellEmpty() {
    return pw.Container(
      height: 11,
      padding: const pw.EdgeInsets.all(0),
      child: pw.SizedBox.shrink(),
    );
  }

  @override
  pw.Widget buildFinancialAndDuplicates(
      EspelhoPedidoDTO pedido, pw.Font boldFont, pw.Font regularFont) {
    if (pedido.duplicatas.isEmpty) return pw.SizedBox.shrink();

    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 2),
      padding: const pw.EdgeInsets.all(3),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.black, width: 0.5),
      ),
      child: pw.Wrap(
        spacing: 8,
        runSpacing: 2,
        children: pedido.duplicatas.map((dup) {
          return pw.Text(
            "Parc ${dup.numeroParcela}: ${_dateOnlyFormat.format(dup.dataVencimento)} - ${_currencyFormat.format(dup.valor)}",
            style: pw.TextStyle(font: regularFont, fontSize: 6.5),
          );
        }).toList(),
      ),
    );
  }

  @override
  pw.Widget buildTotalsSummary(
      EspelhoPedidoDTO pedido, pw.Font boldFont, pw.Font regularFont) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 2),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.black, width: 0.8),
      ),
      child: pw.Row(
        children: [
          // Bloco TOTAL PEDIDO em destaque
          pw.Container(
            width: 120,
            padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 4),
            color: const PdfColor.fromInt(0xFFD0D0D0),
            alignment: pw.Alignment.center,
            child: pw.Text(
              "TOTAL PEDIDO",
              style: pw.TextStyle(font: boldFont, fontSize: 10),
            ),
          ),

          // Tabela de Totais
          pw.Expanded(
            child: pw.Table(
              border: pw.TableBorder.all(color: PdfColors.black, width: 0.5),
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(
                      color: PdfColor.fromInt(0xFFE8E8E8)),
                  children: [
                    _cellHeaderSmall("TOT/ITENS", boldFont),
                    _cellHeaderSmall("TOT/QTD/PEDIDO", boldFont),
                    _cellHeaderSmall("TOT/QTD/FATURA", boldFont),
                    _cellHeaderSmall("VOLUMES", boldFont),
                    _cellHeaderSmall("VALOR PED. BRUTO", boldFont),
                    _cellHeaderSmall("VALOR FAT. BRUTO", boldFont),
                    _cellHeaderSmall("VALOR DESCONTO", boldFont),
                    _cellHeaderSmall("VALOR LÍQUIDO", boldFont),
                  ],
                ),
                pw.TableRow(
                  children: [
                    _cellValueSmall("${pedido.totalItens}", boldFont),
                    _cellValueSmall(
                        _formatQty(pedido.totalQtdPedido), boldFont),
                    _cellValueSmall(
                        _formatQty(pedido.totalQtdFatura), boldFont),
                    _cellValueSmall("", boldFont),
                    _cellValueSmall(
                        _formatMoney(pedido.valorTotalDigitado), boldFont,
                        align: pw.TextAlign.right),
                    _cellValueSmall(
                        _formatMoney(pedido.valorTotalFaturado), boldFont,
                        align: pw.TextAlign.right),
                    _cellValueSmall(
                        _formatMoney(pedido.valorDescontoTotal), boldFont,
                        align: pw.TextAlign.right),
                    _cellValueSmall(_formatMoney(pedido.valorLiquido), boldFont,
                        align: pw.TextAlign.right),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _cellHeaderSmall(String title, pw.Font font) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 1, vertical: 1.5),
      alignment: pw.Alignment.center,
      child: pw.Text(
        title,
        textAlign: pw.TextAlign.center,
        style: pw.TextStyle(font: font, fontSize: 4.8),
      ),
    );
  }

  pw.Widget _cellValueSmall(String value, pw.Font font,
      {pw.TextAlign align = pw.TextAlign.center}) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 2, vertical: 2),
      alignment: align == pw.TextAlign.right
          ? pw.Alignment.centerRight
          : align == pw.TextAlign.left
              ? pw.Alignment.centerLeft
              : pw.Alignment.center,
      child: pw.Text(
        value,
        textAlign: align,
        style: pw.TextStyle(font: font, fontSize: 6.5),
      ),
    );
  }

  @override
  pw.Widget buildNotes(
      String observacoes, pw.Font boldFont, pw.Font regularFont) {
    if (observacoes.trim().isEmpty) {
      return pw.SizedBox.shrink();
    }

    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 2),
      padding: const pw.EdgeInsets.all(3),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.black, width: 0.5),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text("OBSERVAÇÕES: ",
              style: pw.TextStyle(font: boldFont, fontSize: 6)),
          pw.Expanded(
            child: pw.Text(observacoes,
                style: pw.TextStyle(font: regularFont, fontSize: 6)),
          ),
        ],
      ),
    );
  }

  @override
  pw.Widget buildFooter(pw.Context context, pw.Font regularFont) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(top: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            "Empresa de Software suportware.com.br",
            style: pw.TextStyle(
                font: regularFont, fontSize: 6, color: PdfColors.grey800),
          ),
          pw.Text(
            "${context.pageNumber} / ${context.pagesCount}",
            style: pw.TextStyle(
                font: regularFont, fontSize: 6, color: PdfColors.grey800),
          ),
        ],
      ),
    );
  }
}
