import 'package:flutter_test/flutter_test.dart';
import 'package:forca_de_vendas/data/services/crg_codec.dart';
import 'package:forca_de_vendas/data/services/pac_text_generator_service.dart';
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
      datSys: '2026-08-31',
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

  group('PacTextGeneratorService', () {
    test('generate() produz linhas de texto delimitadas e sem tags XML', () {
      final text = PacTextGeneratorService.generate(sample());

      expect(text, isNot(contains('<')));
      expect(text, isNot(contains('>')));
      expect(text, isNot(contains('<?xml')));
      expect(text, isNot(contains('<root')));

      expect(text, contains('PED|71|32504|1542|1|5|3|71|2026-08-31|'));
      expect(text, contains('ITM|32504|1|78945|10.00|150.05|'));
      expect(text, contains('TOT|32504|1|1500.50|'));
    });

    test('compressTextToCrg e decompressCrgToText fazem roundtrip perfeito', () {
      final originalText = PacTextGeneratorService.generate(sample());
      final crgBytes = PacTextGeneratorService.compressTextToCrg(originalText);

      expect(crgBytes.length, greaterThan(4));
      // Os primeiros 4 bytes representam o tamanho da camada
      final lengthHeader = (crgBytes[0] << 24) |
          (crgBytes[1] << 16) |
          (crgBytes[2] << 8) |
          crgBytes[3];
      expect(lengthHeader, greaterThan(0));

      final decompressedText = PacTextGeneratorService.decompressCrgToText(crgBytes);
      expect(decompressedText, equals(originalText));
    });

    test('CrgCodec compacta e descompacta texto puro em 1 ou 2 camadas', () {
      const sampleText = 'FORCA_DE_VENDAS_TEXTO_TESTE_123456789';
      final codec = CrgCodec();

      final compressed2 = codec.compressText(sampleText, layers: 2);
      expect(codec.decompressText(compressed2), equals(sampleText));

      final compressed1 = codec.compressText(sampleText, layers: 1);
      expect(codec.decompressText(compressed1), equals(sampleText));
    });
  });
}
