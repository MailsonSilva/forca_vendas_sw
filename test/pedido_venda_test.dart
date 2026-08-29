import 'package:flutter_test/flutter_test.dart';
import 'package:forca_de_vendas/domain/models/pedido_venda.dart';
import 'package:forca_de_vendas/data/services/pac_xml_generator_service.dart';

void main() {
  test('Should calculate totals correctly and generate XML', () {
    final items = [
      ItemPedidoVenda(
        digpro: '42422',
        digqtd: 2.0,
        digpco: 50.0,
        pcomax: 60.0,
        pcomin: 40.0,
        destot: 10.0,
        subtot: 100.0,
        bontyp: 0,
        boncod: 0,
        ccvtot: 0.0,
        digitm: 1,
      ),
      ItemPedidoVenda(
        digpro: '99999',
        digqtd: 1.0,
        digpco: 30.0,
        pcomax: 30.0,
        pcomin: 30.0,
        destot: 0.0,
        subtot: 0.0,
        bontyp: 1,
        boncod: 2,
        ccvtot: 30.0,
        digitm: 2,
      ),
    ];

    final pedido = PedidoVenda(
      codFil: 1,
      codMov: 1007,
      codRep: 71,
      codCli: 36109,
      codLin: 1,
      codPla: 2,
      codAgt: 612,
      datSys: '2026-07-20',
      items: items,
    );

    pedido.calcularTotais();

    // Verify totals calculation:
    // item 1 is normal: liquido = (2.0 * 50.0) - 10.0 = 90.0. subtot = 100.0, destot = 10.0
    // item 2 is bonification: bontot = (1.0 * 30.0) = 30.0.
    expect(pedido.digtot, equals(90.0));
    expect(pedido.bontot, equals(30.0));
    expect(pedido.destot, equals(10.0));
    expect(pedido.subtot, equals(100.0));

    // Verify XML structure (protocolo pac00_*/pac01_* da Suportware)
    final xml = PacXmlGeneratorService.generate(pedido);
    expect(xml, contains('<!DOCTYPE suportware>'));
    expect(xml, contains('<root sys_versao="1.0" rep00_codigo="71">'));
    expect(xml, contains('pac00_pacrep="71"'));
    expect(xml, contains('pac00_paccod="1007"'));
    expect(xml, contains('pac00_pacqtd="2"'));
    expect(xml, contains('pac00_pactot="90.00"'));
    expect(xml, contains('pac00_clicod="36109"'));
    expect(xml, contains('pac00_bontot="30.00"'));
    expect(xml, contains('pac00_destot="10.00"'));
    expect(xml, contains('pac00_subtot="100.00"'));
    expect(xml, contains('pac00_digtot="90.00"'));
    expect(xml, contains('pac00_lincod="1"'));
    expect(xml, contains('pac00_placod="2"'));
    expect(xml, contains('pac00_agtcod="612"'));
    expect(xml, contains('pac00_digfil="1"'));
    expect(xml, contains('<cot00/>'));
    expect(xml, contains('pac01_pacitm="1"'));
    expect(xml, contains('pac01_procod="42422"'));
    expect(xml, contains('pac01_qtd="2.00"'));
    expect(xml, contains('pac01_pco="50.00"'));
    expect(xml, contains('pac01_pcomax="60.00"'));
    expect(xml, contains('pac01_pcomin="40.00"'));
    expect(xml, contains('pac01_digitm="2"'));
    expect(xml, contains('pac01_procod="99999"'));
    expect(xml, isNot(contains('dig00_')));
    expect(xml, isNot(contains('dig01_')));
    expect(xml, isNot(contains('<rep00 ')));
    expect(xml, isNot(contains('<row ')));
  });
}
