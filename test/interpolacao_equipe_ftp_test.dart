import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:forca_de_vendas/app_state.dart';
import 'package:forca_de_vendas/backend/ftp/ftp_transport.dart';
import 'package:forca_de_vendas/domain/models/config_empresa_acesso.dart';
import 'package:forca_de_vendas/domain/models/sales_access_config.dart';
import 'package:forca_de_vendas/services/carga_registry_service.dart';
import 'package:forca_de_vendas/services/ftp_download_service.dart';
import 'package:forca_de_vendas/services/ftp_upload_service.dart';
import 'package:forca_de_vendas/services/status_envio_db.dart';

class _FakeFtpTransport implements FtpTransport {
  final List<String> cwdCalls = [];
  final List<String> mkdCalls = [];
  final List<String> storNames = [];
  final Map<String, List<int>> retrFiles = {};
  final Map<String, int> fileSizes = {};
  List<String> nlstResult = [];
  bool quitCalled = false;

  @override
  Future<void> cwd(String path) async {
    cwdCalls.add(path);
  }

  @override
  Future<void> mkd(String path) async {
    mkdCalls.add(path);
  }

  @override
  Future<void> stor(
    String fileName,
    List<int> bytes, {
    void Function(int sent)? onProgress,
  }) async {
    storNames.add(fileName);
    fileSizes[fileName] = bytes.length;
    onProgress?.call(bytes.length);
  }

  @override
  Future<int> size(String fileName) async {
    return fileSizes[fileName] ?? 0;
  }

  @override
  Future<List<int>> retr(String fileName) async {
    final data = retrFiles[fileName];
    if (data == null) {
      throw Exception('Arquivo não encontrado: $fileName');
    }
    return data;
  }

  @override
  Future<List<String>> nlst([String? path]) async {
    return nlstResult;
  }

  @override
  Future<void> dele(String fileName) async {}

  @override
  Future<void> rename(String oldName, String newName) async {}

  @override
  Future<void> quit() async {
    quitCalled = true;
  }
}

class _FakeStatusDb extends StatusEnvioDb {
  final List<int> pedidos = [];
  final List<int> clientes = [];

  @override
  Future<void> marcarPedidoEnviado(int codMov) async => pedidos.add(codMov);

  @override
  Future<void> marcarClienteEnviado(int codCli) async => clientes.add(codCli);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AppState.reset();
  });

  group('Interpolação de Código da Equipe em ConfigEmpresaAcesso & SalesAccessConfig', () {
    test('resolverCaminho interpola {codigo_da_equipe} com 2 dígitos', () {
      final config = ConfigEmpresaAcesso(
        codigoEmpresa: 'DZ1000SW',
        nomeEmpresa: 'DISTRIBUIDORA DINIZ',
        pastaDownload: '/diniz/{codigo_da_equipe}/Upload/',
        pastaUpload: '/diniz/{codigo_da_equipe}/Externo/',
        nomeArquivoDb: 'ven',
      );

      expect(config.resolverCaminho(config.pastaDownload, '1'), equals('/diniz/01/Upload/'));
      expect(config.resolverCaminho(config.pastaDownload, '02'), equals('/diniz/02/Upload/'));
      expect(config.resolverCaminho(config.pastaUpload, '71'), equals('/diniz/71/Externo/'));
    });

    test('resolverCaminho interpola {codigoEquipe} como sinônimo', () {
      final config = ConfigEmpresaAcesso(
        codigoEmpresa: 'DZ1000SW',
        nomeEmpresa: 'DISTRIBUIDORA DINIZ',
        pastaDownload: '/diniz/{codigoEquipe}/Upload/',
        pastaUpload: '/diniz/{codigoEquipe}/Externo/',
        nomeArquivoDb: 'ven',
      );

      expect(config.resolverCaminho(config.pastaDownload, '5'), equals('/diniz/05/Upload/'));
      expect(config.resolverCaminho(config.pastaUpload, '5'), equals('/diniz/05/Externo/'));
    });

    test('resolverCaminho aplica fallback seguro quando equipe é vazia ou nula', () {
      final config = ConfigEmpresaAcesso(
        codigoEmpresa: 'DZ1000SW',
        nomeEmpresa: 'DISTRIBUIDORA DINIZ',
        pastaDownload: '/diniz/{codigo_da_equipe}/Upload/',
        pastaUpload: '/diniz/{codigo_da_equipe}/Externo/',
        nomeArquivoDb: 'ven',
      );

      expect(config.resolverCaminho(config.pastaDownload, ''), equals('/diniz/01/Upload/'));
      expect(config.resolverCaminho(config.pastaUpload, '   '), equals('/diniz/01/Externo/'));
      expect(config.resolverCaminho(config.pastaUpload, '0'), equals('/diniz/01/Externo/'));
    });

    test('SalesAccessConfig interpola caminhos corretamente', () {
      const accessConfig = SalesAccessConfig(
        downloadPath: '/diniz/{codigo_da_equipe}/Upload/',
        uploadPath: '/diniz/{codigo_da_equipe}/Externo/',
        databaseFilePrefix: 'ven',
        nomeEmpresa: 'DISTRIBUIDORA DINIZ',
      );

      expect(accessConfig.resolverDownloadPath('2'), equals('/diniz/02/Upload/'));
      expect(accessConfig.resolverUploadPath('2'), equals('/diniz/02/Externo/'));
    });
  });

  group('FtpDownloadService & SincronizacaoService', () {
    test('resolve pasta_download com equipe e busca carga do vendedor no diretório correto', () async {
      final fakeFtp = _FakeFtpTransport();
      final configAcesso = ConfigEmpresaAcesso(
        codigoEmpresa: 'DZ1000SW',
        nomeEmpresa: 'DISTRIBUIDORA DINIZ',
        pastaDownload: '/diniz/{codigo_da_equipe}/Upload/',
        pastaUpload: '/diniz/{codigo_da_equipe}/Externo/',
        nomeArquivoDb: 'ven',
      );

      final downloadService = FtpDownloadService(
        connectFtp: () async => fakeFtp,
      );

      final path = downloadService.resolverDiretorioDownload(
        config: configAcesso,
        codigoEquipe: '3',
      );

      expect(path, equals('/diniz/03/Upload/'));
    });
  });

  group('FtpUploadService com rota interpolada de pasta_upload', () {
    test('envia pacotes e novos clientes para pasta_upload resolvida (.../Externo/)', () async {
      final tempDir = Directory.systemTemp.createTempSync('ftp_upload_interpolado_');
      addTearDown(() {
        if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
      });

      final filePac = File(p.join(tempDir.path, 'p71-100.pac'))..writeAsStringSync('pacote-teste');
      final fakeFtp = _FakeFtpTransport();
      final fakeStatusDb = _FakeStatusDb();

      final service = FtpUploadService(
        connectFtp: () async => fakeFtp,
        getTemporaryDirectoryFn: () async => tempDir,
        statusDb: fakeStatusDb,
        registry: CargaRegistryService(
          manifestPath: p.join(tempDir.path, 'manifest.json'),
        ),
      );

      final result = await service.enviarArquivosPendentes(
        empresa: 'diniz',
        codigoEquipe: 2,
        pastaUploadTemplate: '/diniz/{codigo_da_equipe}/Externo/',
        arquivosSelecionados: [p.basename(filePac.path)],
      );

      expect(result.success, isTrue);
      // Navegação deve ter percorrido 'diniz', '02', 'Externo'
      expect(fakeFtp.cwdCalls, contains('02'));
      expect(fakeFtp.cwdCalls, contains('Externo'));
      expect(fakeFtp.storNames, contains('p71-100.pac'));
    });
  });
}
