import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:forca_de_vendas/backend/ftp/ftp_transport.dart';
import 'package:forca_de_vendas/services/carga_registry_service.dart';
import 'package:forca_de_vendas/services/ftp_path_builder.dart';
import 'package:forca_de_vendas/services/ftp_upload_service.dart';
import 'package:forca_de_vendas/services/status_envio_db.dart';
import 'package:path/path.dart' as p;

class _FakeNavegacaoFtp implements FtpTransport {
  final List<String> cwdCalls = [];
  final List<String> mkdCalls = [];
  final List<String> storCalls = [];

  final Map<String, int> fileSizes = {};

  @override
  Future<void> cwd(String path) async => cwdCalls.add(path);

  @override
  Future<void> mkd(String path) async => mkdCalls.add(path);

  @override
  Future<void> stor(String fileName, List<int> bytes, {void Function(int sent)? onProgress}) async {
    storCalls.add(fileName);
    fileSizes[fileName] = bytes.length;
  }

  @override
  Future<int> size(String fileName) async => fileSizes[fileName] ?? 15;

  @override
  Future<List<int>> retr(String fileName) async => [];

  @override
  Future<List<String>> nlst([String? path]) async => [];

  @override
  Future<void> dele(String fileName) async {}

  @override
  Future<void> rename(String oldName, String newName) async {}

  @override
  Future<void> quit() async {}
}

void main() {
  test('FtpUploadService usa pasta_upload do acesso.json (/diniz/{equipe}/Externo/) e NUNCA cria pasta com codigo de acesso DZ1000SW', () async {
    final tempDir = Directory.systemTemp.createTempSync('teste_caminho_ftp_');
    final fakeFtp = _FakeNavegacaoFtp();

    final pedidoFile = File(p.join(tempDir.path, 'p71-1001.pac'))..writeAsStringSync('conteudo-pedido');

    final service = FtpUploadService(
      connectFtp: () async => fakeFtp,
      getTemporaryDirectoryFn: () async => tempDir,
      statusDb: StatusEnvioDb(),
      registry: CargaRegistryService(
        manifestPath: p.join(tempDir.path, 'manifest.json'),
      ),
    );

    // Simula o cenário real: código de acesso da empresa no app é DZ1000SW,
    // e o template no acesso.json é /diniz/{codigo_da_equipe}/Externo/
    final result = await service.enviarArquivosPendentes(
      empresa: 'DZ1000SW',
      codigoEquipe: 71,
      pastaUploadTemplate: '/diniz/{codigo_da_equipe}/Externo/',
      registros: [
        const CargaRegistro(
          arquivo: 'p71-1001.pac',
          tipo: TipoCarga.pedido,
          id: 1001,
        ),
      ],
    );

    expect(result.success, isTrue);

    // Valida que NUNCA tentou criar ou navegar para DZ1000SW
    final acessouDz = fakeFtp.cwdCalls.any((c) => c.toLowerCase().contains('dz1000sw')) ||
        fakeFtp.mkdCalls.any((c) => c.toLowerCase().contains('dz1000sw'));
    expect(acessouDz, isFalse, reason: 'O FTP jamais deve criar ou navegar na pasta com código de acesso DZ1000SW');

    // Valida que navegou na pasta correta definida no acesso.json: diniz e 71 e Externo
    expect(fakeFtp.cwdCalls, contains('diniz'));
    expect(fakeFtp.cwdCalls, contains('71'));
    expect(fakeFtp.cwdCalls, contains('Externo'));

    tempDir.deleteSync(recursive: true);
  });

  test('FtpUploadService respeita pastaUploadTemplate mesmo quando já estiver resolvida sem marcadores', () async {
    final tempDir = Directory.systemTemp.createTempSync('teste_caminho_resolvido_');
    final fakeFtp = _FakeNavegacaoFtp();

    final pedidoFile = File(p.join(tempDir.path, 'p71-1002.pac'))..writeAsStringSync('conteudo-pedido');

    final service = FtpUploadService(
      connectFtp: () async => fakeFtp,
      getTemporaryDirectoryFn: () async => tempDir,
      statusDb: StatusEnvioDb(),
      registry: CargaRegistryService(
        manifestPath: p.join(tempDir.path, 'manifest.json'),
      ),
    );

    // Template já resolvido como /diniz/71/Externo/
    final result = await service.enviarArquivosPendentes(
      empresa: 'DZ1000SW',
      codigoEquipe: 71,
      pastaUploadTemplate: '/diniz/71/Externo/',
      registros: [
        const CargaRegistro(
          arquivo: 'p71-1002.pac',
          tipo: TipoCarga.pedido,
          id: 1002,
        ),
      ],
    );

    expect(result.success, isTrue);

    final acessouDz = fakeFtp.cwdCalls.any((c) => c.toLowerCase().contains('dz1000sw')) ||
        fakeFtp.mkdCalls.any((c) => c.toLowerCase().contains('dz1000sw'));
    expect(acessouDz, isFalse);
    expect(fakeFtp.cwdCalls, contains('diniz'));
    expect(fakeFtp.cwdCalls, contains('71'));
    expect(fakeFtp.cwdCalls, contains('Externo'));

    tempDir.deleteSync(recursive: true);
  });
}
