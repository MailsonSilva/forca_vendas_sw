import 'dart:convert';
import 'dart:typed_data';
import 'package:intl/intl.dart';
import '../../domain/models/pedido_venda.dart';
import '../../functions/format_currency.dart';
import 'crg_codec.dart';

/// Gera e manipula o payload de texto normal do pacote de pedido de venda,
/// compactando no padrão nativo `.crg` (cabeçalho de 4 bytes + zlib)
/// em substituição ao XML.
class PacTextGeneratorService {
  /// Gera o arquivo de texto plano com a estrutura de pedido e itens (sem XML).
  static String generate(PedidoVenda pedido) {
    final StringBuffer buffer = StringBuffer();
    final DateFormat formatter = DateFormat('yyyy-MM-dd');
    final String currentDate = formatter.format(DateTime.now());

    // Linha de Cabeçalho do Pedido
    // PED|codRep|codMov|codCli|codFil|codLin|codPla|codAgt|datSys|currentDate|digtot|subtot|bontot|destot|fattot|qtdItens|codReg|tipoAgente|codTab|bonfrcven
    buffer.write('PED|');
    buffer.write('${pedido.codRep}|');
    buffer.write('${pedido.codMov}|');
    buffer.write('${pedido.codCli}|');
    buffer.write('${pedido.codFil}|');
    buffer.write('${pedido.codLin}|');
    buffer.write('${pedido.codPla}|');
    buffer.write('${pedido.codAgt}|');
    buffer.write('${pedido.datSys}|');
    buffer.write('$currentDate|');
    buffer.write('${fmtCurrencyPac(pedido.digtot)}|');
    buffer.write('${fmtCurrencyPac(pedido.subtot)}|');
    buffer.write('${fmtCurrencyPac(pedido.bontot)}|');
    buffer.write('${fmtCurrencyPac(pedido.destot)}|');
    buffer.write('${fmtCurrencyPac(pedido.fattot)}|');
    buffer.write('${pedido.items.length}|');
    buffer.write('${pedido.codReg}|');
    buffer.write('${pedido.tipoAgente}|');
    buffer.write('${pedido.codTab}|');
    buffer.write('${pedido.bonfrcven}');
    buffer.writeln();

    // Linhas dos Itens
    // ITM|codMov|digitm|digpro|digqtd|digpco|pcomax|pcomin|destot|subtot|bontyp|boncod|ccvtot|mulemb|mulven
    for (final item in pedido.items) {
      buffer.write('ITM|');
      buffer.write('${pedido.codMov}|');
      buffer.write('${item.digitm}|');
      buffer.write('${item.digpro}|');
      buffer.write('${fmtCurrencyPac(item.digqtd)}|');
      buffer.write('${fmtCurrencyPac(item.digpco)}|');
      buffer.write('${fmtCurrencyPac(item.pcomax)}|');
      buffer.write('${fmtCurrencyPac(item.pcomin)}|');
      buffer.write('${fmtCurrencyPac(item.destot)}|');
      buffer.write('${fmtCurrencyPac(item.subtot)}|');
      buffer.write('${item.bontyp}|');
      buffer.write('${item.boncod}|');
      buffer.write('${fmtCurrencyPac(item.ccvtot)}|');
      buffer.write('${fmtCurrencyPac(item.mulemb ?? 0)}|');
      buffer.write(fmtCurrencyPac(item.mulven ?? 0));
      buffer.writeln();
    }

    // Linha de Rodapé/Totais
    buffer.write('TOT|');
    buffer.write('${pedido.codMov}|');
    buffer.write('${pedido.items.length}|');
    buffer.write('${fmtCurrencyPac(pedido.digtot)}|');
    buffer.write(fmtCurrencyPac(pedido.fattot));
    buffer.writeln();

    return buffer.toString();
  }

  /// Compacta o texto do pedido no padrão de camadas Zlib com cabeçalho de 4 bytes (.crg).
  static Uint8List compressTextToCrg(String text, {int layers = 2}) {
    return CrgCodec().compressText(text, layers: layers, encoding: utf8);
  }

  /// Descompacta os bytes no padrão `.crg` e retorna a string de texto original.
  static String decompressCrgToText(List<int> crgBytes) {
    return CrgCodec().decompressText(crgBytes, encoding: utf8);
  }
}
