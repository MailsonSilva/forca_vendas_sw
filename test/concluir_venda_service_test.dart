import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:forca_de_vendas/data/services/pac_xml_generator_service.dart';
import 'package:forca_de_vendas/domain/models/pedido_venda.dart';
import 'package:forca_de_vendas/services/carga_registry_service.dart';
import 'package:forca_de_vendas/services/concluir_venda_service.dart';
import 'package:forca_de_vendas/services/ftp_path_builder.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late Directory tempDir;
  late Directory docsDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('concluir_test_');
    docsDir = await Directory.systemTemp.createTemp('concluir_docs_');
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    if (docsDir.existsSync()) docsDir.deleteSync(recursive: true);
  });

  PedidoVenda sample() {
    final pedido = PedidoVenda(
      codFil: 1, codMov: 32504, codRep: 71, codCli: 1542,
      codLin: 5, codPla: 3, codAgt: 71, datSys: '2026-08-11',
      items: [
        ItemPedidoVenda(
          digpro: '78945', digqtd: 10.0, digpco: 150.05,
          pcomax: 150.05, pcomin: 150.05, destot: 0.0,
          subtot: 1500.50, bontyp: 0, boncod: 0,
          ccvtot: 0.0, digitm: 1,
        ),
      ],
    );
    pedido.calcularTotais();
    return pedido;
  }

  test('gera arquivo .pac em temp com nomenclatura sequencial e ZIP válido', () async {
    final service = ConcluirVendaService(
      getTemporaryDirectoryFn: () async => tempDir,
      getDocumentsDirFn: () async => docsDir,
      registry: CargaRegistryService(
        manifestPath: p.join(tempDir.path, 'carga_manifest.json'),
      ),
    );

    final fileName = await service.gerarESalvarPedidoLocal(
      pedido: sample(),
      empresa: 'diniz',
      codigoEquipe: 71,
    );

    expect(fileName, 'p71-32504.pac');
    final file = File(p.join(tempDir.path, 'p71-32504.pac'));
    expect(await file.exists(), isTrue);
    final bytes = await file.readAsBytes();
    expect(bytes.sublist(0, 2), [0x50, 0x4B]); // ZIP magic

    final archive = ZipDecoder().decodeBytes(bytes);
    expect(archive.length, 1);
    final xml = utf8.decode(archive.first.content as List<int>);
    expect(xml, contains('<root sys_versao="1.0" rep00_codigo="71">'));
    final recompressed = PacXmlGeneratorService.compressXmlToPac(xml);
    final redecoded = utf8.decode(ZipDecoder().decodeBytes(recompressed).first.content as List<int>);
    expect(redecoded, equals(xml));
  });

  test('registra arquivo→id no manifesto e grava também em documents/', () async {
    final registry = CargaRegistryService(
      manifestPath: p.join(tempDir.path, 'carga_manifest.json'),
    );
    final service = ConcluirVendaService(
      getTemporaryDirectoryFn: () async => tempDir,
      getDocumentsDirFn: () async => docsDir,
      registry: registry,
    );

    final fileName = await service.gerarESalvarPedidoLocal(
      pedido: sample(),
      empresa: 'diniz',
      codigoEquipe: 71,
    );

    final registros = await registry.listar();
    expect(registros.length, 1);
    expect(registros.single.arquivo, 'p71-32504.pac');
    expect(registros.single.tipo, TipoCarga.pedido);
    expect(registros.single.id, 32504);
    expect(await File(p.join(docsDir.path, fileName)).exists(), isTrue);
  });
}
