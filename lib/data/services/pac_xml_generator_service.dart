import 'package:intl/intl.dart';
import '../../domain/models/pedido_venda.dart';

class PacXmlGeneratorService {
  static String generate(PedidoVenda pedido) {
    final StringBuffer xml = StringBuffer();
    final DateFormat formatter = DateFormat('yyyy-MM-dd');
    final String currentDate = formatter.format(DateTime.now());

    xml.writeln('<!DOCTYPE suportware>');
    xml.writeln('<root>');
    
    // rep00
    xml.write(' <rep00 ');
    xml.write('ven00_codmod="4" ');
    xml.write('rep00_numver="5.08" ');
    xml.write('rep00_datpck="${pedido.datSys}" ');
    xml.write('rep00_datrep="$currentDate" ');
    xml.write('rep00_codfil="${pedido.codFil}" ');
    xml.write('rep00_passwo="${pedido.codRep}" ');
    xml.write('rep00_codrep="${pedido.codRep}"');
    xml.writeln('/>');

    // pckvenpac00
    xml.writeln(' <pckvenpac00>');

    // pac00
    xml.write('  <pac00 ');
    xml.write('dig00_digreg="${pedido.codReg}" ');
    xml.write('dig00_codlat="" ');
    xml.write('dig00_digpwd="${pedido.codRep}" ');
    xml.write('dig00_datenv="$currentDate" ');
    xml.write('dig00_cobcod="-1" ');
    xml.write('dig00_agtcod="${pedido.codAgt}" ');
    xml.write('dig00_clicod="${pedido.codCli}" ');
    xml.write('dig00_bontot="${pedido.bontot.toStringAsFixed(3)}" ');
    xml.write('dig00_bonfrcven="0" ');
    xml.write('dig00_lincod="${pedido.codLin}" ');
    xml.write('dig00_codlog="" ');
    xml.write('dig00_destot="${pedido.destot.toStringAsFixed(3)}" ');
    xml.write('dig00_subtot="${pedido.subtot.toStringAsFixed(3)}" ');
    xml.write('dig00_digpco="1" ');
    xml.write('dig00_digtot="${pedido.digtot.toStringAsFixed(3)}" ');
    xml.write('dig00_placod="${pedido.codPla}" ');
    xml.write('dig00_digcod="${pedido.codMov}" ');
    xml.write('dig00_digfil="${pedido.codFil}" ');
    xml.write('dig00_gerntf="0" ');
    xml.write('dig00_datsys="${pedido.datSys}"');
    xml.writeln('/>');

    // pac01
    xml.writeln('  <pac01>');
    for (final item in pedido.items) {
      xml.write('   <row ');
      xml.write('dig01_digpro="${item.digpro}" ');
      xml.write('dig01_codbar="" ');
      xml.write('dig01_boncod="${item.boncod}" ');
      xml.write('dig01_pcopro="0.000" ');
      xml.write('dig01_bon_id="0" ');
      xml.write('dig01_pcomax="${item.pcomax.toStringAsFixed(3)}" ');
      xml.write('dig01_prifil="1" ');
      xml.write('dig01_destot="${item.destot.toStringAsFixed(3)}" ');
      xml.write('dig01_digqtd="${item.digqtd.toStringAsFixed(3)}" ');
      xml.write('dig01_bontyp="${item.bontyp}" ');
      xml.write('dig01_mulemb="0" ');
      xml.write('dig01_digpco="${item.digpco.toStringAsFixed(3)}" ');
      xml.write('dig01_percmb="0.000" ');
      xml.write('dig01_mulven="0.000" ');
      xml.write('dig01_subtot="${item.subtot.toStringAsFixed(3)}" ');
      xml.write('dig01_codcmb="0" ');
      xml.write('dig01_pcomin="${item.pcomin.toStringAsFixed(3)}" ');
      xml.write('dig01_digitm="${item.digitm}" ');
      xml.write('dig01_ccvtot="${item.ccvtot.toStringAsFixed(3)}"');
      xml.writeln('/>');
    }
    xml.writeln('  </pac01>');

    // cot00 (vazia como no layout legado)
    xml.writeln('  <cot00/>');
    xml.writeln(' </pckvenpac00>');
    xml.writeln('</root>');

    return xml.toString();
  }
}
