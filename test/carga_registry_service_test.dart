import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:forca_de_vendas/services/carga_registry_service.dart';
import 'package:forca_de_vendas/services/ftp_path_builder.dart';

void main() {
  late Directory tempDir;
  late CargaRegistryService registry;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('carga_registry_test_');
    registry = CargaRegistryService(
      manifestPath: p.join(tempDir.path, 'carga_manifest.json'),
    );
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  group('CargaRegistryService.registrar/listar', () {
    test('registers and lists a pedido record', () async {
      await registry.registrar(const CargaRegistro(
        arquivo: 'p7-12345.pac',
        tipo: TipoCarga.pedido,
        id: 1007,
      ));

      final itens = await registry.listar();
      expect(itens.length, 1);
      expect(itens.single.arquivo, 'p7-12345.pac');
      expect(itens.single.tipo, TipoCarga.pedido);
      expect(itens.single.id, 1007);
    });

    test('registers multiple records', () async {
      await registry.registrar(const CargaRegistro(
        arquivo: 'p7-12345.pac',
        tipo: TipoCarga.pedido,
        id: 1007,
      ));
      await registry.registrar(const CargaRegistro(
        arquivo: 'c7-54321.xml',
        tipo: TipoCarga.cliente,
        id: 20754,
      ));

      final itens = await registry.listar();
      expect(itens.length, 2);
    });
  });

  group('CargaRegistryService.remover', () {
    test('removes a record by arquivo name', () async {
      await registry.registrar(const CargaRegistro(
        arquivo: 'p7-12345.pac',
        tipo: TipoCarga.pedido,
        id: 1007,
      ));

      await registry.remover('p7-12345.pac');

      expect(await registry.listar(), isEmpty);
    });
  });

  group('CargaRegistryService persistence', () {
    test('survives across instances (re-reads JSON from disk)', () async {
      const reg = CargaRegistro(
        arquivo: 'p7-12345.pac',
        tipo: TipoCarga.pedido,
        id: 1007,
      );
      await registry.registrar(reg);

      final reloaded = CargaRegistryService(
        manifestPath: p.join(tempDir.path, 'carga_manifest.json'),
      );
      final itens = await reloaded.listar();
      expect(itens.length, 1);
      expect(itens.single.arquivo, reg.arquivo);
      expect(itens.single.tipo, reg.tipo);
      expect(itens.single.id, reg.id);
    });
  });
}
