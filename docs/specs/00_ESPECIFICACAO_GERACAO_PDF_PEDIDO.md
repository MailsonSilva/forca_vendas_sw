ESPECIFICAÇÃO TÉCNICA COMPLETA: GERAÇÃO, VISUALIZAÇÃO E COMPARTILHAMENTO DE PDF DO PEDIDO (ESPELHO DE VENDA)1. Visão Geral e Contexto de MigraçãoEste documento define a arquitetura técnica, modelo de dados, tratamento de internacionalização de fontes, regras de quebra de página/tabela e fluxo de compartilhamento para o módulo de Geração do Espelho de Venda em PDF no aplicativo Força de Vendas em Flutter.  A especificação substitui o mecanismo legado em C++/Qt (ffrmdigvenrel01.cpp / QPrinter / QPainter), eliminando falhas históricas de permissão no Android (FileUriExposedException / restrições de Scoped Storage ao acessar diretórios públicos) e estruturando o serviço em uma arquitetura extensível por meio de Templates Intercambiáveis.  A. Diagnóstico Comparativo (Legado vs. Flutter Moderno)AspectoLegado C++/Qt (ffrmdigvenrel01)Novo Módulo FlutterMecanismo GráficoCoordenadas absolutas em canvas de impressão via QPainter.  Composição declarativa e vetorial via pacote pdf (pw.MultiPage, tabelas flexíveis).  ArmazenamentoGravado com caminho fixo em disco (DownloadLocation + "/ForcaDeVendas/pedido.pdf").  Gerado dinamicamente em memória (Uint8List) e armazenado pontualmente no cache (getTemporaryDirectory()) com chave de timestamp.  CompartilhamentoChamada direta que falhava no Android devido a permissões de repositório público.  Compartilhamento nativo via share_plus (XFile integrado a ContentProvider seguro).  TipografiaFontes do sistema operacional (Tahoma, Droid Sans) embutidas no executável.  Carregamento assíncrono via PdfGoogleFonts (Roboto) com suporte a UTF-8 (acentuação gráfica) e glifo de moeda (R$).Filtros de Itensbtntodoitens, btncomcorte, btnsemcorte, btncombonif.  Enum FiltroItensPdf preservando a mesma regra de negócio do legado.  2. Dependências Técnicas (pubspec.yaml)YAMLdependencies:
  flutter:
    sdk: flutter
  pdf: ^3.10.8              # Motor de composição declarativa de arquivos PDF
  printing: ^5.13.1         # Integração com fontes do Google Fonts, preview e drivers de impressão
  share_plus: ^9.0.0        # Compartilhamento via Intent nativo / ContentProvider seguro
  path_provider: ^2.1.2     # Acesso padronizado ao diretório temporário/cache do dispositivo
  intl: ^0.19.0             # Formatação de moedas, decimais e datas locais (pt_BR)
3. Arquitetura em Camadas do MóduloO módulo é dividido em quatro componentes independentes:
┌─────────────────────────────────────────────────────────┐
│              1. Camada de Dados (DTO)                   │
│   EspelhoPedidoDTO, ItemEspelhoDTO, DuplicataEspelhoDTO │
└──────────────────────────┬──────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────┐
│        2. Contrato de Template (Interface)              │
│               IPdfOrderTemplate                         │
│  (buildHeader, buildCustomerInfo, buildTable, etc.)     │
└──────────────────────────┬──────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────┐
│       3. Implementação Concreta de Layout               │
│               StandardPdfOrderTemplate                  │
│    (Implementa o layout padrão A4 / expansível)         │
└──────────────────────────┬──────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────┐
│      4. Orquestrador e Serviço de Compartilhamento      │
│               PdfGeneratorService                       │
│ (Carrega fontes TTF, gera bytes, exporta e aciona Share)│
└─────────────────────────────────────────────────────────┘
4. Dicionário de Dados do Espelho (EspelhoPedidoDTO)Os dados consumidos pelo relatório agrupam informações das tabelas do pedido (dig00), itens (dig01), cliente (cadcli00), vendedor (cadrep00), agente (cadagt00) e duplicatas/parcelas (caddup00 ou similar):  A. Cabeçalho e Identificação do PedidonumeroPedido (dig00_digcod): Número de identificação local gerado no aplicativo.  numeroNotaFiscal (dig00_fatmov): Número do faturamento/NF retornado pela central do ERP.  dataEmissao (dig00_datsys): Data e hora da gravação.  vendedorCodigo / vendedorNome (dig00_digrep / dig00_desrep): Código e nome do representante.  planoPagamento (dig00_placod): Condição comercial / parcelamento aplicado.  linhaProduto (dig00_lincod): Linha comercial vinculada ao pedido.  agenteCobrador (dig00_codagt / agt00_descri): Agente cobrador financeiro.statusPedido (dig00_sttenv / dig00_sttped): Situação atual (Rascunho, Transmitido, Faturado, etc.).  observacao (dig00_observ): Observações comerciais ou instruções de entrega digitadas no pedido.B. Dados do ClienteclienteCodigo (dig00_clicod / cli00_codigo): Código do cliente no ERP.  clienteRazaoSocial (cli00_descri / dig00_clides): Razão social do estabelecimento.  clienteNomeFantasia (cli00_fantas): Nome de fachada do estabelecimento.  clienteCpfCnpj (dig00_cpfcnp): CNPJ ou CPF do comprador.  clienteIE (dig00_insest): Inscrição Estadual.  clienteEndereco (cli00_endere, cli00_ciddes, cli00_estsgl): Endereço cadastrado completo.  C. Itens do Pedido (List<ItemEspelhoDTO>)sequencial (dig01_digitm): Índice da linha do produto digitado.  codigoProduto (dig01_digpro / pro00_codigo): Código interno do item.  codigoEAN (pro00_codbar): Código de barras padrão do produto.  descricao (pro00_descri): Descrição oficial do item.  marca (mar00_descri): Marca do fabricante.  quantidadeDigitada (dig01_digqtd): Quantidade solicitada pelo vendedor.  quantidadeFaturada (dig01_fatqtd): Quantidade liberada/faturada no retorno do ERP.  precoUnitario (dig01_digpco / dig01_fatpco): Preço unitário líquido.  descontoPercentual (dig01_perdes): Desconto comercial aplicado no item.valorTotal (dig01_digtot): Total líquido da linha.  isBonificacao (isBonif): Booleano identificando bonificação/brinde.  D. Duplicatas / Previsão Financeira (List<DuplicataEspelhoDTO>)numeroParcela: Sequencial da parcela (ex: 1, 2, 3).dataVencimento: Data de vencimento calculada ou informada.valorDuplicata: Valor em moeda corrente da parcela.E. Resumo FinanceirovalorTotalDigitado (dig00_digtot): Somatório dos itens digitados.  valorTotalFaturado (dig00_fattot): Somatório faturado.  valorTotalBonificado (dig00_bontot): Total referente a bonificações.  valorSubstituicaoTributaria (dig00_subtot): Total de retenções/ST.valorDescontoComercial: Abatimentos concedidos no fechamento.5. Implementação Completa em Dart / Flutter5.1. DTOs e Estrutura de TiposDart// lib/modules/pdf/dtos/espelho_pedido_dto.dart

enum FiltroItensPdf { todos, apenasCortes, semCortes, apenasBonificados }

class ItemEspelhoDTO {
  final int sequencial;
  final int codigoProduto;
  final String codigoEAN;
  final String descricao;
  final String marca;
  final double quantidadeDigitada;
  final double quantidadeFaturada;
  final double precoUnitario;
  final double descontoPercentual;
  final double valorTotal;
  final bool isBonificacao;

  ItemEspelhoDTO({
    required this.sequencial,
    required this.codigoProduto,
    required this.codigoEAN,
    required this.descricao,
    required this.marca,
    required this.quantidadeDigitada,
    required this.quantidadeFaturada,
    required this.precoUnitario,
    this.descontoPercentual = 0.0,
    required this.valorTotal,
    this.isBonificacao = false,
  });

  double get corte => quantidadeDigitada - quantidadeFaturada;
}

class DuplicataEspelhoDTO {
  final int numeroParcela;
  final DateTime dataVencimento;
  final double valor;

  DuplicataEspelhoDTO({
    required this.numeroParcela,
    required this.dataVencimento,
    required this.valor,
  });
}

class EspelhoPedidoDTO {
  final int numeroPedido;
  final String numeroNotaFiscal;
  final DateTime dataEmissao;
  final String vendedorCodigo;
  final String vendedorNome;
  final String clienteCodigo;
  final String clienteRazaoSocial;
  final String clienteNomeFantasia;
  final String clienteCpfCnpj;
  final String clienteIE;
  final String clienteEndereco;
  final String planoPagamento;
  final String linhaProduto;
  final String agenteCobrador;
  final String status;
  final String observacao;
  final double valorTotalDigitado;
  final double valorTotalFaturado;
  final double valorTotalBonificado;
  final double valorSubstituicaoTributaria;
  final double valorDescontoTotal;
  final List<ItemEspelhoDTO> itens;
  final List<DuplicataEspelhoDTO> duplicatas;

  EspelhoPedidoDTO({
    required this.numeroPedido,
    required this.numeroNotaFiscal,
    required this.dataEmissao,
    required this.vendedorCodigo,
    required this.vendedorNome,
    required this.clienteCodigo,
    required this.clienteRazaoSocial,
    required this.clienteNomeFantasia,
    required this.clienteCpfCnpj,
    required this.clienteIE,
    required this.clienteEndereco,
    required this.planoPagamento,
    required this.linhaProduto,
    required this.agenteCobrador,
    required this.status,
    required this.observacao,
    required this.valorTotalDigitado,
    required this.valorTotalFaturado,
    required this.valorTotalBonificado,
    required this.valorSubstituicaoTributaria,
    this.valorDescontoTotal = 0.0,
    required this.itens,
    this.duplicatas = const [],
  });
}
5.2. Contrato de Template Visual (IPdfOrderTemplate)Dart// lib/modules/pdf/contracts/pdf_order_template.dart

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../dtos/espelho_pedido_dto.dart';

abstract class IPdfOrderTemplate {
  pw.Widget buildHeader(EspelhoPedidoDTO pedido, pw.Context context, pw.Font boldFont, pw.Font regularFont);
  pw.Widget buildCustomerAndOrderInfo(EspelhoPedidoDTO pedido, pw.Font boldFont, pw.Font regularFont);
  pw.Widget buildItemsTable(List<ItemEspelhoDTO> itens, pw.Font boldFont, pw.Font regularFont);
  pw.Widget buildFinancialAndDuplicates(EspelhoPedidoDTO pedido, pw.Font boldFont, pw.Font regularFont);
  pw.Widget buildTotalsSummary(EspelhoPedidoDTO pedido, pw.Font boldFont, pw.Font regularFont);
  pw.Widget buildNotes(String observacoes, pw.Font boldFont, pw.Font regularFont);
  pw.Widget buildFooter(pw.Context context, pw.Font regularFont);
}
5.3. Implementação Concreta Padrão (StandardPdfOrderTemplate)Esta implementação trata acentuação UTF-8, o símbolo de moeda R$ e impede quebras indesejadas de texto através de quebra automática (softWrap: true) e limitação de caracteres.  Dart// lib/modules/pdf/templates/standard_pdf_order_template.dart

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../contracts/pdf_order_template.dart';
import '../dtos/espelho_pedido_dto.dart';

class StandardPdfOrderTemplate implements IPdfOrderTemplate {
  final NumberFormat _currencyFormat = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
  final DateFormat _dateFormat = DateFormat('dd/MM/yyyy HH:mm');
  final DateFormat _dateOnlyFormat = DateFormat('dd/MM/yyyy');

  @override
  pw.Widget buildHeader(EspelhoPedidoDTO pedido, pw.Context context, pw.Font boldFont, pw.Font regularFont) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  "ESPELHO DO PEDIDO DE VENDA",
                  style: pw.TextStyle(font: boldFont, fontSize: 14, color: PdfColors.blue900),
                ),
                pw.Text(
                  "Emissão: ${_dateFormat.format(pedido.dataEmissao)}",
                  style: pw.TextStyle(font: regularFont, fontSize: 8, color: PdfColors.grey700),
                ),
              ],
            ),
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.blue900, width: 1),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
              ),
              child: pw.Text(
                "PEDIDO: #${pedido.numeroPedido}",
                style: pw.TextStyle(font: boldFont, fontSize: 12, color: PdfColors.blue900),
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 4),
        pw.Divider(thickness: 0.8, color: PdfColors.grey400),
      ],
    );
  }

  @override
  pw.Widget buildCustomerAndOrderInfo(EspelhoPedidoDTO pedido, pw.Font boldFont, pw.Font regularFont) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(6),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400, width: 0.5),
        color: PdfColors.grey100,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            children: [
              pw.Expanded(
                flex: 6,
                child: pw.RichText(
                  text: pw.TextSpan(
                    text: "CLIENTE: ",
                    style: pw.TextStyle(font: boldFont, fontSize: 8),
                    children: [
                      pw.TextSpan(
                        text: "[${pedido.clienteCodigo}] ${pedido.clienteRazaoSocial}",
                        style: pw.TextStyle(font: regularFont, fontSize: 8),
                      ),
                    ],
                  ),
                ),
              ),
              pw.Expanded(
                flex: 4,
                child: pw.RichText(
                  text: pw.TextSpan(
                    text: "CNPJ/CPF: ",
                    style: pw.TextStyle(font: boldFont, fontSize: 8),
                    children: [
                      pw.TextSpan(
                        text: pedido.clienteCpfCnpj.isNotEmpty ? pedido.clienteCpfCnpj : "NÃO INFORMADO",
                        style: pw.TextStyle(font: regularFont, fontSize: 8),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 2),
          pw.Row(
            children: [
              pw.Expanded(
                flex: 6,
                child: pw.RichText(
                  text: pw.TextSpan(
                    text: "ENDEREÇO: ",
                    style: pw.TextStyle(font: boldFont, fontSize: 8),
                    children: [
                      pw.TextSpan(
                        text: pedido.clienteEndereco,
                        style: pw.TextStyle(font: regularFont, fontSize: 8),
                      ),
                    ],
                  ),
                ),
              ),
              pw.Expanded(
                flex: 4,
                child: pw.RichText(
                  text: pw.TextSpan(
                    text: "INSC. ESTADUAL: ",
                    style: pw.TextStyle(font: boldFont, fontSize: 8),
                    children: [
                      pw.TextSpan(
                        text: pedido.clienteIE.isNotEmpty ? pedido.clienteIE : "ISENTO",
                        style: pw.TextStyle(font: regularFont, fontSize: 8),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 4),
          pw.Divider(thickness: 0.5, color: PdfColors.grey300),
          pw.SizedBox(height: 2),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text("VENDEDOR: [${pedido.vendedorCodigo}] ${pedido.vendedorNome}", style: pw.TextStyle(font: regularFont, fontSize: 8)),
              pw.Text("PLANO: ${pedido.planoPagamento}", style: pw.TextStyle(font: regularFont, fontSize: 8)),
              pw.Text("COBRANÇA: ${pedido.agenteCobrador}", style: pw.TextStyle(font: regularFont, fontSize: 8)),
              pw.Text("STATUS: ${pedido.status.toUpperCase()}", style: pw.TextStyle(font: boldFont, fontSize: 8, color: PdfColors.blue800)),
            ],
          ),
        ],
      ),
    );
  }

  @override
  pw.Widget buildItemsTable(List<ItemEspelhoDTO> itens, pw.Font boldFont, pw.Font regularFont) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
      columnWidths: const {
        0: pw.FixedColumnWidth(20),  // Seq
        1: pw.FixedColumnWidth(35),  // Cód
        2: pw.FlexColumnWidth(3.5),  // Descrição / Marca
        3: pw.FixedColumnWidth(40),  // Qtd Dig
        4: pw.FixedColumnWidth(40),  // Qtd Fat
        5: pw.FixedColumnWidth(30),  // Corte
        6: pw.FixedColumnWidth(50),  // Unitário
        7: pw.FixedColumnWidth(55),  // Total Líquido
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.blue800),
          children: [
            _cellHeader("Seq", boldFont, align: pw.TextAlign.center),
            _cellHeader("Cód", boldFont, align: pw.TextAlign.center),
            _cellHeader("Descrição / Marca", boldFont),
            _cellHeader("Dig.", boldFont, align: pw.TextAlign.right),
            _cellHeader("Fat.", boldFont, align: pw.TextAlign.right),
            _cellHeader("Corte", boldFont, align: pw.TextAlign.right),
            _cellHeader("Unitário", boldFont, align: pw.TextAlign.right),
            _cellHeader("Total", boldFont, align: pw.TextAlign.right),
          ],
        ),
        ...itens.map((item) {
          final isCorte = item.corte > 0;
          return pw.TableRow(
            decoration: item.isBonificacao ? const pw.BoxDecoration(color: PdfColors.amber50) : null,
            children: [
              _cellBody(item.sequencial.toString(), regularFont, align: pw.TextAlign.center),
              _cellBody(item.codigoProduto.toString(), regularFont, align: pw.TextAlign.center),
              pw.Padding(
                padding: const pw.EdgeInsets.all(3),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      item.descricao,
                      style: pw.TextStyle(font: regularFont, fontSize: 7),
                      softWrap: true,
                    ),
                    if (item.marca.isNotEmpty)
                      pw.Text(
                        "Marca: ${item.marca}",
                        style: pw.TextStyle(font: regularFont, fontSize: 6, color: PdfColors.grey700),
                      ),
                  ],
                ),
              ),
              _cellBody(item.quantidadeDigitada.toStringAsFixed(0), regularFont, align: pw.TextAlign.right),
              _cellBody(item.quantidadeFaturada.toStringAsFixed(0), regularFont, align: pw.TextAlign.right),
              _cellBody(
                item.corte.toStringAsFixed(0),
                regularFont,
                align: pw.TextAlign.right,
                textColor: isCorte ? PdfColors.red900 : PdfColors.black,
              ),
              _cellBody(_currencyFormat.format(item.precoUnitario), regularFont, align: pw.TextAlign.right),
              _cellBody(_currencyFormat.format(item.valorTotal), regularFont, align: pw.TextAlign.right),
            ],
          );
        }),
      ],
    );
  }

  @override
  pw.Widget buildFinancialAndDuplicates(EspelhoPedidoDTO pedido, pw.Font boldFont, pw.Font regularFont) {
    if (pedido.duplicatas.isEmpty) {
      return pw.SizedBox.shrink();
    }

    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 8),
      padding: const pw.EdgeInsets.all(6),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400, width: 0.5),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text("PARCELAMENTO / DUPLICATAS:", style: pw.TextStyle(font: boldFont, fontSize: 7, color: PdfColors.blue900)),
          pw.SizedBox(height: 4),
          pw.Wrap(
            spacing: 12,
            runSpacing: 4,
            children: pedido.duplicatas.map((dup) {
              return pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
                  color: PdfColors.grey50,
                ),
                child: pw.Text(
                  "Parc ${dup.numeroParcela}: ${_dateOnlyFormat.format(dup.dataVencimento)} - ${_currencyFormat.format(dup.valor)}",
                  style: pw.TextStyle(font: regularFont, fontSize: 7),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  @override
  pw.Widget buildTotalsSummary(EspelhoPedidoDTO pedido, pw.Font boldFont, pw.Font regularFont) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 8),
      padding: const pw.EdgeInsets.all(6),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400, width: 0.5),
        color: PdfColors.grey100,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              if (pedido.valorTotalBonificado > 0)
                pw.Text("Total Bonificado: ${_currencyFormat.format(pedido.valorTotalBonificado)}", style: pw.TextStyle(font: regularFont, fontSize: 8, color: PdfColors.orange900)),
              if (pedido.valorSubstituicaoTributaria > 0)
                pw.Text("Substituição Tributária (ST): ${_currencyFormat.format(pedido.valorSubstituicaoTributaria)}", style: pw.TextStyle(font: regularFont, fontSize: 8)),
              if (pedido.valorDescontoTotal > 0)
                pw.Text("Desconto Total: ${_currencyFormat.format(pedido.valorDescontoTotal)}", style: pw.TextStyle(font: regularFont, fontSize: 8, color: PdfColors.red900)),
            ],
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text("Total Digitado: ${_currencyFormat.format(pedido.valorTotalDigitado)}", style: pw.TextStyle(font: boldFont, fontSize: 9)),
              if (pedido.valorTotalFaturado > 0)
                pw.Text("Total Faturado: ${_currencyFormat.format(pedido.valorTotalFaturado)}", style: pw.TextStyle(font: boldFont, fontSize: 10, color: PdfColors.green900)),
            ],
          ),
        ],
      ),
    );
  }

  @override
  pw.Widget buildNotes(String observacoes, pw.Font boldFont, pw.Font regularFont) {
    if (observacoes.trim().isEmpty) {
      return pw.SizedBox.shrink();
    }

    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 6),
      padding: const pw.EdgeInsets.all(6),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text("OBSERVAÇÕES DO PEDIDO:", style: pw.TextStyle(font: boldFont, fontSize: 7, color: PdfColors.grey800)),
          pw.SizedBox(height: 2),
          pw.Text(
            observacoes,
            style: pw.TextStyle(font: regularFont, fontSize: 7),
            softWrap: true,
          ),
        ],
      ),
    );
  }

  @override
  pw.Widget buildFooter(pw.Context context, pw.Font regularFont) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 8),
      alignment: pw.Alignment.centerRight,
      child: pw.Text(
        "Página ${context.pageNumber} de ${context.pagesCount}",
        style: pw.TextStyle(font: regularFont, fontSize: 8, color: PdfColors.grey600),
      ),
    );
  }

  pw.Widget _cellHeader(String title, pw.Font font, {pw.TextAlign align = pw.TextAlign.left}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      child: pw.Text(
        title,
        textAlign: align,
        style: pw.TextStyle(font: font, fontSize: 7, color: PdfColors.white),
      ),
    );
  }

  pw.Widget _cellBody(String text, pw.Font font, {pw.TextAlign align = pw.TextAlign.left, PdfColor textColor = PdfColors.black}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(font: font, fontSize: 7, color: textColor),
      ),
    );
  }
}
5.4. Orquestrador do Serviço (PdfGeneratorService)O orquestrador implementa:Carregamento Assíncrono de Fontes TTF: Usa PdfGoogleFonts.robotoRegular() e PdfGoogleFonts.robotoBold().Ciclo de Vida de Arquivo Temporário: Previne leitura de arquivos defasados por cache do Android ao gerar nomes com hash/timestamp único (Pedido_{cod}_{timestamp}.pdf).  Desacoplamento de Layout: Aceita qualquer implementação de IPdfOrderTemplate.Dart// lib/modules/pdf/services/pdf_generator_service.dart

import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../contracts/pdf_order_template.dart';
import '../dtos/espelho_pedido_dto.dart';
import '../templates/standard_pdf_order_template.dart';

class PdfGeneratorService {
  final IPdfOrderTemplate _defaultTemplate;

  PdfGeneratorService({IPdfOrderTemplate? template})
      : _defaultTemplate = template ?? StandardPdfOrderTemplate();

  /// Gera os bytes do PDF em memória aplicando o filtro de itens especificado
  Future<Uint8List> generateOrderPdf({
    required EspelhoPedidoDTO pedido,
    FiltroItensPdf filtro = FiltroItensPdf.todos,
    IPdfOrderTemplate? customTemplate,
    PdfPageFormat pageFormat = PdfPageFormat.a4,
  }) async {
    final template = customTemplate ?? _defaultTemplate;
    final pdf = pw.Document();

    // Carregamento de fontes completas com suporte ao UTF-8 brasileiro e glifos especiais
    final fontRegular = await PdfGoogleFonts.robotoRegular();
    final fontBold = await PdfGoogleFonts.robotoBold();

    final itensFiltrados = _aplicarFiltro(pedido.itens, filtro);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: pageFormat,
        margin: const pw.EdgeInsets.all(20),
        header: (pw.Context context) => template.buildHeader(pedido, context, fontBold, fontRegular),
        footer: (pw.Context context) => template.buildFooter(context, fontRegular),
        build: (pw.Context context) => [
          template.buildCustomerAndOrderInfo(pedido, fontBold, fontRegular),
          pw.SizedBox(height: 8),
          template.buildItemsTable(itensFiltrados, fontBold, fontRegular),
          template.buildFinancialAndDuplicates(pedido, fontBold, fontRegular),
          template.buildTotalsSummary(pedido, fontBold, fontRegular),
          template.buildNotes(pedido.observacao, fontBold, fontRegular),
        ],
      ),
    );

    return pdf.save();
  }

  /// Filtra a lista de itens preservando o comportamento do sistema legado
  List<ItemEspelhoDTO> _aplicarFiltro(List<ItemEspelhoDTO> itens, FiltroItensPdf filtro) {
    switch (filtro) {
      case FiltroItensPdf.apenasCortes:
        return itens.where((i) => i.corte > 0).toList();
      case FiltroItensPdf.semCortes:
        return itens.where((i) => i.corte == 0).toList();
      case FiltroItensPdf.apenasBonificados:
        return itens.where((i) => i.isBonificacao).toList();
      case FiltroItensPdf.todos:
      default:
        return itens;
    }
  }

  /// Salva em cache temporário com timestamp e aciona o modal nativo de compartilhamento
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

    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'application/pdf')],
      text: "Segue o Espelho do Pedido #${pedido.numeroPedido} - ${pedido.clienteRazaoSocial}",
      subject: "Espelho do Pedido #${pedido.numeroPedido}",
    );
  }
}
6. Procedimento de Troca por Template Visual CustomizadoQuando um novo layout de PDF for recebido:Crie a classe concreta: Implemente a interface IPdfOrderTemplate (ex: CustomClientPdfTemplate).Mantenha os DTOs e Regras: Os DTOs e as regras de filtragem (FiltroItensPdf) e compartilhamento permanecem inalterados.  Injeção de Dependência: Registre o novo template no PdfGeneratorService:Dartfinal service = PdfGeneratorService(template: CustomClientPdfTemplate());