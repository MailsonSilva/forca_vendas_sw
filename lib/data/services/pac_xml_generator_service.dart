import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
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
  static String generate(PedidoVenda pedido) {
    final StringBuffer xml = StringBuffer();
    final DateFormat formatter = DateFormat('yyyy-MM-dd');
    final String currentDate = formatter.format(DateTime.now());

    xml.writeln('<!DOCTYPE suportware>');
    xml.writeln('<root sys_versao="1.0" rep00_codigo="${pedido.codRep}">');

    xml.writeln(' <pckvenpac00>');

    // pac00 — cabeçalho (doc + campos legados renomeados dig00_* → pac00_*)
    xml.write('  <pac00 ');
    xml.write('pac00_pacrep="${pedido.codRep}" ');
    xml.write('pac00_paccod="${pedido.codMov}" ');
    xml.write('pac00_pacqtd="${pedido.items.length}" ');
    xml.write('pac00_pactot="${pedido.digtot.toStringAsFixed(3)}" ');
    xml.write('pac00_clicod="${pedido.codCli}" ');

    // Campos do antigo <rep00/> dobrados no pac00 (sem perder dados)
    xml.write('ven00_codmod="4" ');
    xml.write('rep00_numver="5.08" ');
    xml.write('rep00_datpck="${pedido.datSys}" ');
    xml.write('rep00_datrep="$currentDate" ');
    xml.write('rep00_codfil="${pedido.codFil}" ');
    xml.write('rep00_passwo="${pedido.codRep}" ');

    // Campos legados de cabeçalho (dig00_* → pac00_*)
    xml.write('pac00_digreg="${pedido.codReg}" ');
    xml.write('pac00_codlat="" ');
    xml.write('pac00_digpwd="${pedido.codRep}" ');
    xml.write('pac00_datenv="$currentDate" ');
    xml.write('pac00_cobcod="-1" ');
    xml.write('pac00_agtcod="${pedido.codAgt}" ');
    xml.write('pac00_bontot="${pedido.bontot.toStringAsFixed(3)}" ');
    xml.write('pac00_bonfrcven="0" ');
    xml.write('pac00_lincod="${pedido.codLin}" ');
    xml.write('pac00_codlog="" ');
    xml.write('pac00_destot="${pedido.destot.toStringAsFixed(3)}" ');
    xml.write('pac00_subtot="${pedido.subtot.toStringAsFixed(3)}" ');
    xml.write('pac00_digpco="1" ');
    xml.write('pac00_digtot="${pedido.digtot.toStringAsFixed(3)}" ');
    xml.write('pac00_placod="${pedido.codPla}" ');
    xml.write('pac00_digfil="${pedido.codFil}" ');
    xml.write('pac00_gerntf="0" ');
    xml.write('pac00_datsys="${pedido.datSys}"');
    xml.writeln('/>');

    // pac01 — itens (dig01_* → pac01_*)
    for (final item in pedido.items) {
      xml.write('  <pac01 ');
      xml.write('pac01_paccod="${pedido.codMov}" ');
      xml.write('pac01_pacitm="${item.digitm}" ');
      xml.write('pac01_procod="${item.digpro}" ');
      xml.write('pac01_qtd="${item.digqtd.toStringAsFixed(3)}" ');
      xml.write('pac01_pco="${item.digpco.toStringAsFixed(3)}" ');
      xml.write('pac01_codbar="" ');
      xml.write('pac01_boncod="${item.boncod}" ');
      xml.write('pac01_pcopro="0.000" ');
      xml.write('pac01_bon_id="0" ');
      xml.write('pac01_pcomax="${item.pcomax.toStringAsFixed(3)}" ');
      xml.write('pac01_prifil="1" ');
      xml.write('pac01_destot="${item.destot.toStringAsFixed(3)}" ');
      xml.write('pac01_bontyp="${item.bontyp}" ');
      xml.write('pac01_mulemb="0" ');
      xml.write('pac01_percmb="0.000" ');
      xml.write('pac01_mulven="0.000" ');
      xml.write('pac01_subtot="${item.subtot.toStringAsFixed(3)}" ');
      xml.write('pac01_codcmb="0" ');
      xml.write('pac01_pcomin="${item.pcomin.toStringAsFixed(3)}" ');
      xml.write('pac01_digitm="${item.digitm}" ');
      xml.write('pac01_ccvtot="${item.ccvtot.toStringAsFixed(3)}"');
      xml.writeln('/>');
    }

    // cot00 (vazia como no layout legado)
    xml.writeln('  <cot00/>');
    xml.writeln(' </pckvenpac00>');
    xml.writeln('</root>');

    return xml.toString();
  }

  /// Compacta o XML de pedido em um arquivo ZIP em memória com a extensão
  /// `.pac` (protocolo legado: `.pac` é um ZIP renomeado).
  ///
  /// Pura (sem I/O): o chamador decide onde gravar o arquivo. O conteúdo
  /// original do XML é preservado íntegro dentro do arquivo `pedido.xml`.
  static Uint8List compressXmlToPac(String xml) {
    final archive = Archive()
      ..addFile(ArchiveFile('pedido.xml', utf8.encode(xml).length, utf8.encode(xml)));
    return Uint8List.fromList(ZipEncoder().encode(archive)!);
  }
}
