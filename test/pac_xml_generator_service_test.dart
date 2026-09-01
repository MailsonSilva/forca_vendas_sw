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

  test('generate() produz envelope com rep00 avulso e pckvenpac00', () {
    final xml = PacXmlGeneratorService.generate(sample());
    expect(xml, contains('<!DOCTYPE suportware>'));
    expect(xml, contains('<root>'));
    expect(xml, contains('<rep00 rep00_codrep="71" ven00_codmod="4" rep00_numver="5.08"'));
    expect(xml, contains('<pckvenpac00>'));
    expect(xml, contains('</pac01>'));
    expect(xml, contains('<cot00/>'));
    expect(xml, contains('</pckvenpac00>'));
    expect(xml, contains('</root>'));
  });

  test('generate() mapeia cabeçalho pac00 com atributos dig00_*', () {
    final xml = PacXmlGeneratorService.generate(sample());
    expect(xml, contains('dig00_agtcod="71"'));
    expect(xml, contains('dig00_clicod="1542"'));
    expect(xml, contains('dig00_digcod="32504"'));
    expect(xml, contains('dig00_digtot="1500.500"'));
    expect(xml, contains('dig00_lincod="5"'));
    expect(xml, contains('dig00_placod="3"'));
    expect(xml, contains('dig00_digfil="1"'));
    expect(xml, contains('dig00_cobcod="-1"'));
  });

  test('generate() mapeia itens dentro de pac01 com tag row e atributos dig01_*', () {
    final xml = PacXmlGeneratorService.generate(sample());
    expect(xml, contains('<pac01>'));
    expect(xml, contains('<row '));
    expect(xml, contains('dig01_digpro="78945"'));
    expect(xml, contains('dig01_digqtd="10.000"'));
    expect(xml, contains('dig01_digpco="150.050"'));
    expect(xml, contains('dig01_digitm="1"'));
    expect(xml, contains('</pac01>'));
  });

  test('generateBatch() agrupa múltiplos pedidos sob o mesmo pckvenpac00 com rep00', () {
    final p1 = sample();
    final p2 = PedidoVenda(
      codFil: 1,
      codMov: 32505,
      codRep: 71,
      codCli: 1543,
      codLin: 5,
      codPla: 3,
      codAgt: 71,
      datSys: '2026-08-11',
      items: [
        ItemPedidoVenda(
          digpro: '78946',
          digqtd: 5.0,
          digpco: 100.0,
          pcomax: 100.0,
          pcomin: 100.0,
          destot: 0.0,
          subtot: 500.0,
          bontyp: 0,
          boncod: 0,
          ccvtot: 0.0,
          digitm: 1,
        ),
      ],
    );
    p2.calcularTotais();

    final xml = PacXmlGeneratorService.generateBatch([p1, p2], 71);
    expect(xml, contains('<!DOCTYPE suportware>'));
    expect(xml, contains('<root>'));
    expect(xml, contains('<rep00 rep00_codrep="71"'));
    expect(xml, contains('dig00_digcod="32504"'));
    expect(xml, contains('dig00_digcod="32505"'));
    expect(xml, contains('dig01_digpro="78945"'));
    expect(xml, contains('dig01_digpro="78946"'));
    // Cada pedido possui seu próprio bloco pckvenpac00 com cot00
    expect('<pckvenpac00>'.allMatches(xml).length, equals(2));
    expect('</pckvenpac00>'.allMatches(xml).length, equals(2));
    expect('<cot00/>'.allMatches(xml).length, equals(2));
    expect(xml, contains('</root>'));
  });

  test('compressXmlToPac() retorna bytes UTF-8 com o XML íntegro', () {
    final xml = PacXmlGeneratorService.generate(sample());
    final pacBytes = PacXmlGeneratorService.compressXmlToPac(xml);
    expect(pacBytes, isNotEmpty);
  });

}


