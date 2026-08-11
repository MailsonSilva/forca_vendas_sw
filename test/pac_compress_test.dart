import 'dart:convert';
import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forca_de_vendas/data/services/pac_xml_generator_service.dart';

void main() {
  const String xml = '<root><pedido/></root>';

  group('PacXmlGeneratorService.compressXmlToPac', () {
    test('returns a ZIP archive with a single XML entry', () {
      final bytes = PacXmlGeneratorService.compressXmlToPac(xml);

      final archive = ZipDecoder().decodeBytes(bytes);
      expect(archive.length, 1);

      final entry = archive.first;
      final content = utf8.decode(entry.content as List<int>);
      expect(content, xml);
    });

    test('decoded content matches the original XML exactly', () {
      final bytes = PacXmlGeneratorService.compressXmlToPac(xml);
      final archive = ZipDecoder().decodeBytes(bytes);
      expect(utf8.decode(archive.first.content as List<int>), xml);
    });

    test('produces valid zip magic bytes', () {
      final bytes = PacXmlGeneratorService.compressXmlToPac(xml);
      expect(bytes.length, greaterThan(0));
      expect(bytes.sublist(0, 2), [0x50, 0x4B]); // 'PK'
    });
  });
}
