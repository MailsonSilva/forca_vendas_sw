import 'package:flutter_test/flutter_test.dart';
import 'package:forca_de_vendas/functions/format_quantity.dart';

void main() {
  group('formatQuantity tests', () {
    test('formata unidades não fracionadas como inteiros', () {
      expect(formatQuantity(14.0, unidade: 'UN'), '14');
      expect(formatQuantity(14.75, unidade: 'CX'), '14');
      expect(formatQuantity(5.0, unidade: 'PC'), '5');
      expect(formatQuantity(100.0, unidade: 'FD'), '100');
      expect(formatQuantity(0, unidade: 'UN'), '0');
      expect(formatQuantity(null, unidade: 'UN'), '0');
    });

    test('formata unidades fracionadas com 3 casas decimais', () {
      expect(formatQuantity(1.45, unidade: 'KG'), '1,450');
      expect(formatQuantity(2.5, unidade: 'MT'), '2,500');
      expect(formatQuantity(0.75, unidade: 'LT'), '0,750');
      expect(formatQuantity(10.1234, unidade: 'M2'), '10,123');
      expect(formatQuantity(3.2, isFracionado: true), '3,200');
    });
  });
}
