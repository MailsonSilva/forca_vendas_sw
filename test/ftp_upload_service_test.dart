import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:forca_de_vendas/backend/ftp/ftp_transport.dart';
import 'package:forca_de_vendas/services/ftp_path_builder.dart';
import 'package:forca_de_vendas/services/ftp_upload_service.dart';
import 'package:forca_de_vendas/services/status_envio_db.dart';

class _FakeFtp implements FtpTransport {
  final List<String> cwdCalls = [];
  final List<String> mkdCalls = [];
  final List<String> storNames = [];
  final Map<String, int> sizes = {};
  final Map<String, int> sizeOverride = {};
  bool quitCalled = false;

  @override
  Future<void> cwd(String path) async => cwdCalls.add(path);

  @override
  Future<void> mkd(String path) async => mkdCalls.add(path);

  @override
  Future<void> stor(
    String fileName,
    List<int> bytes, {
    void Function(int sent)? onProgress,
  }) async {
    storNames.add(fileName);
    sizes[fileName] = bytes.length;
    onProgress?.call(bytes.length);
  }

  @override
  Future<int> size(String fileName) async =>
      sizeOverride[fileName] ?? sizes[fileName] ?? 0;

  @override
  Future<void> quit() async => quitCalled = true;
}

class _FakeStatusDb extends StatusEnvioDb {
  final List<int> pedidosMarcados = [];
  final List<int> clientesMarcados = [];

  @override
  Future<void> marcarPedidoEnviado(int codMov) async {
    pedidosMarcados.add(codMov);
  }

  @override
  Future<void> marcarClienteEnviado(int codCli) async {
    clientesMarcados.add(codCli);
  }
}

void main() {
  final List<Directory> tempDirs = [];  tearDown(() {
    for (final d in tempDirs) {
      if (d.existsSync()) d.deleteSync(recursive: true);
    }
    tempDirs.clear();
  });

  (Directory, FtpUploadService, _FakeFtp, _FakeStatusDb) setup(
      {required List<String> arquivos}) {
    final tempDir = Directory.systemTemp.createTempSync('ftp_upload_test_');
    tempDirs.add(tempDir);
    for (final nome in arquivos) {
      File(p.join(tempDir.path, nome)).writeAsStringSync('conteudo-$nome');
    }
    final fake = _FakeFtp();
    final statusDb = _FakeStatusDb();
    final service = FtpUploadService(
      connectFtp: () async => fake,
      getTemporaryDirectoryFn: () async => tempDir,
      statusDb: statusDb,
    );
    return (tempDir, service, fake, statusDb);
  }

  group('FtpUploadService.classificarTipoArquivo', () {
    test('classifies by legacy naming', () {
      expect(FtpUploadService.classificarTipoArquivo('p71-1007'),
          TipoCarga.pedido);
      expect(FtpUploadService.classificarTipoArquivo('c71-36109'),
          TipoCarga.cliente);
      expect(FtpUploadService.classificarTipoArquivo('cli_020754'),
          TipoCarga.cliente);
      expect(FtpUploadService.classificarTipoArquivo('relatorio_geral'),
          TipoCarga.uploadGeral);
      expect(FtpUploadService.classificarTipoArquivo('.oculto'),
          TipoCarga.uploadGeral);
    });
  });

  group('FtpUploadService.enviarArquivosPendentes', () {
    test('uploads a pedido to /{empresa}/{equipe}/Externo/ and marks status',
        () async {
      final (tempDir, service, fake, statusDb) = setup(arquivos: ['p71-1007']);

      final result = await service.enviarArquivosPendentes(
        empresa: 'DINIZ',
        codigoEquipe: 7,
      );

      expect(result.success, isTrue);
      expect(fake.storNames, ['p71-1007']);
      expect(fake.cwdCalls, contains('/'));
      expect(fake.cwdCalls, contains('diniz'));
      expect(fake.cwdCalls, contains('07'));
      expect(fake.cwdCalls, contains('Externo'));
      expect(fake.quitCalled, isTrue);
      expect(statusDb.pedidosMarcados, [1007]);
      expect(statusDb.clientesMarcados, isEmpty);

      expect(File(p.join(tempDir.path, 'p71-1007')).existsSync(), isFalse);
      expect(
          File(p.join(tempDir.path, 'enviados', 'p71-1007')).existsSync(),
          isTrue);
    });

    test('uploads a cliente to /{empresa}/{equipe}/Customer/ and marks status',
        () async {
      final (_, service, fake, statusDb) = setup(arquivos: ['cli_020754']);

      final result = await service.enviarArquivosPendentes(
        empresa: 'diniz',
        codigoEquipe: 71,
      );

      expect(result.success, isTrue);
      expect(fake.storNames, ['cli_020754']);
      expect(fake.cwdCalls, contains('Customer'));
      expect(statusDb.clientesMarcados, [20754]);
      expect(statusDb.pedidosMarcados, isEmpty);
    });

    test('keeps file pending (retry) when SIZE diverges', () async {
      final (tempDir, service, fake, _) = setup(arquivos: ['p71-1007']);

      // Simula servidor recebendo tamanho divergente
      fake.sizeOverride['p71-1007'] = 123456;

      final result = await service.enviarArquivosPendentes(
        empresa: 'diniz',
        codigoEquipe: 7,
      );

      expect(result.success, isFalse);
      expect(result.enviados.single.sucesso, isFalse);
      expect(fake.quitCalled, isTrue);
      expect(File(p.join(tempDir.path, 'p71-1007')).existsSync(), isTrue);
      expect(
          File(p.join(tempDir.path, 'enviados', 'p71-1007')).existsSync(),
          isFalse);
    });

    test('respects enviarPedidos/enviarClientes filters', () async {
      final (_, service, fake, statusDb) =
          setup(arquivos: ['p71-1007', 'cli_020754']);

      final result = await service.enviarArquivosPendentes(
        empresa: 'diniz',
        codigoEquipe: 7,
        enviarPedidos: false,
        enviarClientes: true,
      );

      expect(result.success, isTrue);
      expect(fake.storNames, ['cli_020754']);
      expect(statusDb.clientesMarcados, [20754]);
      expect(statusDb.pedidosMarcados, isEmpty);
    });

    test('returns empty-success when no files pending', () async {
      final (_, service, fake, _) = setup(arquivos: []);

      final result = await service.enviarArquivosPendentes(
        empresa: 'diniz',
        codigoEquipe: 7,
      );

      expect(result.success, isTrue);
      expect(result.message, contains('Nenhum arquivo'));
      expect(fake.quitCalled, isFalse);
    });
  });
}
