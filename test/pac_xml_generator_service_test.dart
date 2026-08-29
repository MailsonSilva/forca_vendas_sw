import 'package:flutter_test/flutter_test.dart';
import 'package:forca_de_vendas/data/services/pac_xml_generator_service.dart';
import 'package:forca_de_vendas/domain/models/pedido_venda.dart';

void main() {
  PedidoVenda sample() {
    final pedido = PedidoVenda(
      codFil: 1,
      codMov: 32504,
      codRep: 71,
      codCli: 1542,
      codLin: 5,
      codPla: 3,
      codAgt: 71,
      datSys: '2026-08-11',
      items: [
        ItemPedidoVenda(
          digpro: '78945',
          digqtd: 10.0,
          digpco: 150.05,
          pcomax: 150.05,
          pcomin: 150.05,
          destot: 0.0,
          subtot: 1500.50,
          bontyp: 0,
          boncod: 0,
          ccvtot: 0.0,
          digitm: 1,
        ),
      ],
    );
    pedido.calcularTotais();
    return pedido;
  }

  test('generate() produz envelope legacy com rep00_codigo', () {
    final xml = PacXmlGeneratorService.generate(sample());
    expect(xml, contains('<!DOCTYPE suportware>'));
    expect(xml, contains('<root sys_versao="1.0" rep00_codigo="71">'));
    expect(xml, contains('<pckvenpac00>'));
    expect(xml, contains('</pckvenpac00>'));
    expect(xml, contains('</root>'));
  });

  test('generate() mapeia cabeçalho pac00_* e sequencial do pacote', () {
    final xml = PacXmlGeneratorService.generate(sample());
    expect(xml, contains('pac00_pacrep="71"'));
    expect(xml, contains('pac00_paccod="32504"'));
    expect(xml, contains('pac00_pacqtd="1"'));
    expect(xml, contains('pac00_pactot="1500.50"'));
    expect(xml, contains('pac00_clicod="1542"'));
    expect(xml, contains('pac00_lincod="5"'));
    expect(xml, contains('pac00_placod="3"'));
    expect(xml, contains('pac00_agtcod="71"'));
    expect(xml, contains('pac00_digfil="1"'));
  });

  test('generate() mapeia itens pac01_*', () {
    final xml = PacXmlGeneratorService.generate(sample());
    expect(xml, contains('pac01_paccod="32504"'));
    expect(xml, contains('pac01_pacitm="1"'));
    expect(xml, contains('pac01_procod="78945"'));
    expect(xml, contains('pac01_qtd="10.00"'));
    expect(xml, contains('pac01_pco="150.05"'));
    expect(xml, contains('<cot00/>'));
  });

  test('generate() não vaza campos dig00_/dig01_/rep00 avulsos', () {
    final xml = PacXmlGeneratorService.generate(sample());
    expect(xml, isNot(contains('dig00_')));
    expect(xml, isNot(contains('dig01_')));
    expect(xml, isNot(contains('<rep00 ')));
  });
}
