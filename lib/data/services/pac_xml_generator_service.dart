import 'dart:convert';
import 'dart:typed_data';
import 'package:intl/intl.dart';
import '../../domain/models/pedido_venda.dart';



/// Gera o payload XML do pacote de pedido de venda (pckvenpac00) no
/// protocolo legado Suportware.
///
/// Estrutura estrita (conforme `refatoração.md`):
/// ```xml
/// <!DOCTYPE suportware>
/// <root sys_versao="1.0" rep00_codigo="[CODIGO_REPRESENTANTE]">
///   <pckvenpac00>
///     <pac00 pac00_pacrep="..." pac00_paccod="..." ...>
///       <pac01 pac01_paccod="..." pac01_pacitm="..." ... />
///     </pac00>
///   </pckvenpac00>
/// </root>
/// ```
///
/// Conteúdo em texto puro (sem zip/criptografia), com atributos do cabeçalho
/// `rep00_*`/`ven00_*` dobrados sobre a tag `pac00` e os atributos de item
/// (`dig01_*` legados) renomeados para `pac01_*`.
class PacXmlGeneratorService {
  static String _fmt3(num? v) => (v ?? 0.0).toStringAsFixed(3);

  static String _escapeXml(String? s) {
    if (s == null || s.isEmpty) return '';
    return s
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }

  static String generate(PedidoVenda pedido) {
    final StringBuffer xml = StringBuffer();
    final DateFormat formatter = DateFormat('yyyy-MM-dd');
    final String currentDate = formatter.format(DateTime.now());

    xml.writeln('<!DOCTYPE suportware>');
    xml.writeln('<root>');
    xml.writeln(
      '<rep00 rep00_codrep="${pedido.codRep}" ven00_codmod="4" rep00_numver="5.08" '
      'rep00_datpck="${pedido.datSys}" rep00_datrep="$currentDate" '
      'rep00_codfil="${pedido.codFil}" rep00_passwo="${pedido.codRep}"/>',
    );
    xml.writeln('<pckvenpac00>');

    // pac00 — cabeçalho com atributos dig00_*
    xml.write('<pac00 ');
    xml.write('dig00_agtcod="${pedido.codAgt}" ');
    xml.write('dig00_clicod="${pedido.codCli}" ');
    xml.write('dig00_bontot="${_fmt3(pedido.bontot)}" ');
    xml.write('dig00_codlog="" ');
    xml.write('dig00_destot="${_fmt3(pedido.destot)}" ');
    xml.write('dig00_lincod="${pedido.codLin}" ');
    xml.write('dig00_subtot="${_fmt3(pedido.subtot)}" ');
    xml.write('dig00_digpco="0" ');
    xml.write('dig00_digtot="${_fmt3(pedido.digtot)}" ');
    xml.write('dig00_bonfrcven="${pedido.bonfrcven}" ');
    xml.write('dig00_digcod="${pedido.codMov}" ');
    xml.write('dig00_digfil="${pedido.codFil}" ');
    xml.write('dig00_gerntf="0" ');
    xml.write('dig00_placod="${pedido.codPla}" ');
    xml.write('dig00_datsys="${pedido.datSys}" ');
    xml.write('dig00_digreg="${pedido.codReg}" ');
    xml.write('dig00_codlat="" ');
    xml.write('dig00_digpwd="${pedido.codRep}" ');
    xml.write('dig00_datenv="$currentDate" ');
    xml.write('dig00_cobcod="-1" ');
    xml.write('dig00_digobs="${_escapeXml(pedido.observacao)}"');
    xml.writeln('/>');

    // SPEC-042: nó <dig00> com tag <digobs>
    xml.writeln('<dig00>');
    xml.writeln('  <digobs>${_escapeXml(pedido.observacao)}</digobs>');
    xml.writeln('</dig00>');

    // pac01 — itens representados por <row .../>
    xml.writeln('<pac01>');
    for (final item in pedido.items) {
      xml.write('<row ');
      xml.write('dig01_bon_id="0" ');
      xml.write('dig01_pcomax="${_fmt3(item.pcomax)}" ');
      xml.write('dig01_prifil="1" ');
      xml.write('dig01_destot="${_fmt3(item.destot)}" ');
      xml.write('dig01_digqtd="${_fmt3(item.digqtd)}" ');
      xml.write('dig01_bontyp="${item.bontyp}" ');
      xml.write('dig01_digpco="${_fmt3(item.digpco)}" ');
      xml.write('dig01_mulemb="${item.mulemb?.toInt() ?? 0}" ');
      xml.write('dig01_percmb="${_fmt3(item.percmb ?? 0.0)}" ');
      xml.write('dig01_subtot="${_fmt3(item.subtot)}" ');
      xml.write('dig01_mulven="${_fmt3(item.mulven ?? 0.0)}" ');
      xml.write('dig01_codcmb="0" ');
      xml.write('dig01_pcomin="${_fmt3(item.pcomin)}" ');
      xml.write('dig01_digitm="${item.digitm}" ');
      xml.write('dig01_ccvtot="${_fmt3(item.ccvtot)}" ');
      xml.write('dig01_digpro="${item.digpro}" ');
      xml.write('dig01_codbar="" ');
      xml.write('dig01_boncod="${item.boncod}" ');
      xml.write('dig01_pcopro="0.000"');
      xml.writeln('/>');
    }
    xml.writeln('</pac01>');

    // cot00 (vazia como no layout legado)
    xml.writeln('<cot00/>');
    xml.writeln('</pckvenpac00>');
    xml.writeln('</root>');

    return xml.toString();
  }

  /// Gera o payload XML consolidado de um lote de pedidos de venda (pckvenpac00)
  /// para empacotamento múltiplo conforme o novo layout homologado.
  static String generateBatch(List<PedidoVenda> pedidos, int codRep) {
    if (pedidos.isEmpty) {
      throw ArgumentError('A lista de pedidos para gerar o lote não pode ser vazia.');
    }

    final StringBuffer xml = StringBuffer();
    final DateFormat formatter = DateFormat('yyyy-MM-dd');
    final String currentDate = formatter.format(DateTime.now());
    final firstPedido = pedidos.first;

    xml.writeln('<!DOCTYPE suportware>');
    xml.writeln('<root>');
    xml.writeln(
      '<rep00 rep00_codrep="$codRep" ven00_codmod="4" rep00_numver="5.08" '
      'rep00_datpck="${firstPedido.datSys}" rep00_datrep="$currentDate" '
      'rep00_codfil="${firstPedido.codFil}" rep00_passwo="$codRep"/>',
    );
    for (final pedido in pedidos) {
      xml.writeln('<pckvenpac00>');

      // pac00 — cabeçalho do pedido
      xml.write('<pac00 ');
      xml.write('dig00_agtcod="${pedido.codAgt}" ');
      xml.write('dig00_clicod="${pedido.codCli}" ');
      xml.write('dig00_bontot="${_fmt3(pedido.bontot)}" ');
      xml.write('dig00_codlog="" ');
      xml.write('dig00_destot="${_fmt3(pedido.destot)}" ');
      xml.write('dig00_lincod="${pedido.codLin}" ');
      xml.write('dig00_subtot="${_fmt3(pedido.subtot)}" ');
      xml.write('dig00_digpco="0" ');
      xml.write('dig00_digtot="${_fmt3(pedido.digtot)}" ');
      xml.write('dig00_bonfrcven="${pedido.bonfrcven}" ');
      xml.write('dig00_digcod="${pedido.codMov}" ');
      xml.write('dig00_digfil="${pedido.codFil}" ');
      xml.write('dig00_gerntf="0" ');
      xml.write('dig00_placod="${pedido.codPla}" ');
      xml.write('dig00_datsys="${pedido.datSys}" ');
      xml.write('dig00_digreg="${pedido.codReg}" ');
      xml.write('dig00_codlat="" ');
      xml.write('dig00_digpwd="$codRep" ');
      xml.write('dig00_datenv="$currentDate" ');
      xml.write('dig00_cobcod="-1" ');
      xml.write('dig00_digobs="${_escapeXml(pedido.observacao)}"');
      xml.writeln('/>');

      // SPEC-042: nó <dig00> com tag <digobs>
      xml.writeln('<dig00>');
      xml.writeln('  <digobs>${_escapeXml(pedido.observacao)}</digobs>');
      xml.writeln('</dig00>');

      // pac01 — itens do pedido
      xml.writeln('<pac01>');
      for (final item in pedido.items) {
        xml.write('<row ');
        xml.write('dig01_bon_id="0" ');
        xml.write('dig01_pcomax="${_fmt3(item.pcomax)}" ');
        xml.write('dig01_prifil="1" ');
        xml.write('dig01_destot="${_fmt3(item.destot)}" ');
        xml.write('dig01_digqtd="${_fmt3(item.digqtd)}" ');
        xml.write('dig01_bontyp="${item.bontyp}" ');
        xml.write('dig01_digpco="${_fmt3(item.digpco)}" ');
        xml.write('dig01_mulemb="${item.mulemb?.toInt() ?? 0}" ');
        xml.write('dig01_percmb="${_fmt3(item.percmb ?? 0.0)}" ');
        xml.write('dig01_subtot="${_fmt3(item.subtot)}" ');
        xml.write('dig01_mulven="${_fmt3(item.mulven ?? 0.0)}" ');
        xml.write('dig01_codcmb="0" ');
        xml.write('dig01_pcomin="${_fmt3(item.pcomin)}" ');
        xml.write('dig01_digitm="${item.digitm}" ');
        xml.write('dig01_ccvtot="${_fmt3(item.ccvtot)}" ');
        xml.write('dig01_digpro="${item.digpro}" ');
        xml.write('dig01_codbar="" ');
        xml.write('dig01_boncod="${item.boncod}" ');
        xml.write('dig01_pcopro="0.000"');
        xml.writeln('/>');
      }
      xml.writeln('</pac01>');

      // cot00 (vazia como no layout legado)
      xml.writeln('<cot00/>');
      xml.writeln('</pckvenpac00>');
    }

    xml.writeln('</root>');

    return xml.toString();

  }

  /// Converte o XML de pedido em bytes UTF-8 para o arquivo `.pac`
  /// (protocolo legado: arquivo com extensão `.pac` contendo o XML puro em UTF-8, sem compactação zip).
  static Uint8List compressXmlToPac(String xml, {String? internalFileName}) {
    final bytes = utf8.encode(xml);
    return Uint8List.fromList(bytes);
  }
}



