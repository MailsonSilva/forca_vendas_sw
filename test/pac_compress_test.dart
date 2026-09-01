import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:forca_de_vendas/data/services/pac_xml_generator_service.dart';

void main() {
  const String xml = '<root><pedido/></root>';

  group('PacXmlGeneratorService.compressXmlToPac', () {
    test('returns plain UTF-8 XML bytes for .pac file without zip compression', () {
      final bytes = PacXmlGeneratorService.compressXmlToPac(xml);
      final content = utf8.decode(bytes);
      expect(content, xml);
    });

    test('decoded content matches the original XML exactly', () {
      final bytes = PacXmlGeneratorService.compressXmlToPac(xml);
      expect(utf8.decode(bytes), xml);
    });

    test('preserves XML payload without zip header overhead', () {
      final bytes = PacXmlGeneratorService.compressXmlToPac(xml);
      expect(bytes.length, equals(utf8.encode(xml).length));
    });
  });
}

