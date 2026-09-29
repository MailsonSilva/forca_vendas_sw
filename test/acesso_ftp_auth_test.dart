import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:forca_de_vendas/app_state.dart';
import 'package:forca_de_vendas/domain/models/config_empresa_acesso.dart';
import 'package:forca_de_vendas/services/acesso_ftp_service.dart';
import 'package:forca_de_vendas/services/auth_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AppState.reset();
  });

  group('ConfigEmpresaAcesso', () {
    test('cria instância a partir de JSON padrão do acesso.json', () {
      final json = {
        'nome_empresa': 'DISTRIBUIDORA DINIZ',
        'pasta_download': '/diniz/Upload/',
        'pasta_upload': '/diniz/upload/',
        'nome_arquivo_db': 'ven',
      };

      final config = ConfigEmpresaAcesso.fromJson('DZ1000SW', json);

      expect(config.codigoEmpresa, equals('DZ1000SW'));
      expect(config.nomeEmpresa, equals('DISTRIBUIDORA DINIZ'));
      expect(config.pastaDownload, equals('/diniz/Upload/'));
      expect(config.pastaUpload, equals('/diniz/upload/'));
      expect(config.nomeArquivoDb, equals('ven'));
    });

    test('aplica valores default e aceita chaves legadas', () {
      final json = {
        'empresa': 'EMPRESA TESTE',
        'caminho_download': '/teste/download/',
        'caminho_upload': '/teste/upload/',
      };

      final config = ConfigEmpresaAcesso.fromJson('TESTE123', json);

      expect(config.codigoEmpresa, equals('TESTE123'));
      expect(config.nomeEmpresa, equals('EMPRESA TESTE'));
      expect(config.pastaDownload, equals('/teste/download/'));
      expect(config.pastaUpload, equals('/teste/upload/'));
      expect(config.nomeArquivoDb, equals('ven'));
    });

    test('resolverPastaUploadEquipe concatena pastaUpload com equipe formatada', () {
      final config = ConfigEmpresaAcesso(
        codigoEmpresa: 'DZ1000SW',
        nomeEmpresa: 'DISTRIBUIDORA DINIZ',
        pastaDownload: '/diniz/Upload/',
        pastaUpload: '/diniz/upload/',
        nomeArquivoDb: 'ven',
      );

      expect(config.resolverPastaUploadEquipe(1), equals('/diniz/upload/01'));
      expect(config.resolverPastaUploadEquipe(7), equals('/diniz/upload/07'));
      expect(config.resolverPastaUploadEquipe(12), equals('/diniz/upload/12'));
      expect(config.resolverPastaUploadEquipe(1, barraFinal: true), equals('/diniz/upload/01/'));
    });
  });

  group('AcessoFtpService', () {
    final mockJsonString = jsonEncode({
      'DZ1000SW': {
        'nome_empresa': 'DISTRIBUIDORA DINIZ',
        'pasta_download': '/diniz/Upload/',
        'pasta_upload': '/diniz/upload/',
        'nome_arquivo_db': 'ven',
      },
      'JP1000SW': {
        'nome_empresa': 'JOAO PESSOA DIST',
        'pasta_download': '/jp/Upload/',
        'pasta_upload': '/jp/upload/',
        'nome_arquivo_db': 'ven',
      },
    });

    test('buscarConfigEmpresa retorna config quando empresa existe (case-insensitive)', () async {
      final service = AcessoFtpService(
        baixarConteudoFtpFn: () async => mockJsonString,
      );

      final configExato = await service.buscarConfigEmpresa('DZ1000SW');
      expect(configExato, isNotNull);
      expect(configExato!.codigoEmpresa, equals('DZ1000SW'));
      expect(configExato.nomeEmpresa, equals('DISTRIBUIDORA DINIZ'));

      final configLower = await service.buscarConfigEmpresa('dz1000sw');
      expect(configLower, isNotNull);
      expect(configLower!.codigoEmpresa, equals('DZ1000SW'));

      final configComEspacos = await service.buscarConfigEmpresa('  JP1000SW  ');
      expect(configComEspacos, isNotNull);
      expect(configComEspacos!.codigoEmpresa, equals('JP1000SW'));
    });

    test('buscarConfigEmpresa retorna null quando código da empresa não existe', () async {
      final service = AcessoFtpService(
        baixarConteudoFtpFn: () async => mockJsonString,
      );

      final config = await service.buscarConfigEmpresa('EMPRESA_INEXISTENTE');
      expect(config, isNull);

      final configVazio = await service.buscarConfigEmpresa('');
      expect(configVazio, isNull);
    });

    test('buscarConfigEmpresa usa cache offline se conexão FTP falhar', () async {
      bool falharConexao = false;

      final service = AcessoFtpService(
        baixarConteudoFtpFn: () async {
          if (falharConexao) throw Exception('Sem conexão de internet');
          return mockJsonString;
        },
      );

      // Primeiro acesso com sucesso popula cache
      final config1 = await service.buscarConfigEmpresa('DZ1000SW');
      expect(config1, isNotNull);

      // Agora simula queda de conexão
      falharConexao = true;
      final configOffline = await service.buscarConfigEmpresa('DZ1000SW');
      expect(configOffline, isNotNull);
      expect(configOffline!.nomeEmpresa, equals('DISTRIBUIDORA DINIZ'));

      // Empresa que não existe continua retornando null mesmo offline
      final configInexistenteOffline = await service.buscarConfigEmpresa('INEXISTENTE');
      expect(configInexistenteOffline, isNull);
    });
  });

  group('AuthService e Login Flow', () {
    late Database testDb;

    setUp(() async {
      testDb = await openDatabase(
        inMemoryDatabasePath,
        version: 1,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE cadrep00 (
              ven00_codigo INTEGER PRIMARY KEY,
              ven00_descri TEXT,
              ven00_codeqp INTEGER,
              ven00_codfil INTEGER,
              ven00_selfil INTEGER,
              ven00_chkest INTEGER,
              ven00_gerbonfor INTEGER,
              ven00_chkage INTEGER,
              ven00_ignlimfis INTEGER,
              ven00_maxitmdig INTEGER,
              ven00_passet TEXT,
              ven00_txajur REAL
            )
          ''');

          await db.insert('cadrep00', {
            'ven00_codigo': 105,
            'ven00_descri': 'VENDEDOR TESTE 105',
            'ven00_codeqp': 2,
            'ven00_codfil': 1,
            'ven00_selfil': 0,
            'ven00_chkest': 1,
            'ven00_gerbonfor': 0,
            'ven00_chkage': 0,
            'ven00_ignlimfis': 0,
            'ven00_maxitmdig': 100,
            'ven00_passet': '1234',
            'ven00_txajur': 2.5,
          });
        },
      );
    });

    tearDown(() async {
      await testDb.close();
    });

    test('validarVendedor retorna true para vendedor existente no banco', () async {
      final authService = AuthService();
      final valido = await authService.validarVendedor(
        '105',
        dbOverride: testDb,
      );
      expect(valido, isTrue);
    });

    test('validarVendedor retorna false para vendedor não cadastrado', () async {
      final authService = AuthService();
      final valido = await authService.validarVendedor(
        '999',
        dbOverride: testDb,
      );
      expect(valido, isFalse);
    });

    test('validarVendedor retorna false para código inválido ou vazio', () async {
      final authService = AuthService();
      expect(await authService.validarVendedor('', dbOverride: testDb), isFalse);
      expect(await authService.validarVendedor('ABC', dbOverride: testDb), isFalse);
      expect(await authService.validarVendedor('0', dbOverride: testDb), isFalse);
    });

    test('salvarConfigAcesso e iniciarSessao gravam dados no AppState e SharedPreferences', () async {
      final appState = AppState();
      await appState.initializePersistedState();

      final config = ConfigEmpresaAcesso(
        codigoEmpresa: 'DZ1000SW',
        nomeEmpresa: 'DISTRIBUIDORA DINIZ',
        pastaDownload: '/diniz/Upload/',
        pastaUpload: '/diniz/upload/',
        nomeArquivoDb: 'ven',
      );

      final authService = AuthService();
      await authService.iniciarSessao('105', dbOverride: testDb);

      expect(appState.vendedor_codigo, equals(105));
      expect(appState.vendedor_nome, equals('VENDEDOR TESTE 105'));
      expect(appState.vendedor_equipe, equals(2));
      expect(appState.ven00_txajur, equals(2.5));

      // Salva as configurações de acesso vinculadas à equipe do vendedor (2 -> '02')
      await appState.salvarConfigAcesso(config, codigoEquipe: appState.vendedor_equipe);

      expect(appState.empresa_codigo, equals('DZ1000SW'));
      expect(appState.empresaNome, equals('DISTRIBUIDORA DINIZ'));
      expect(appState.pastaDownload0, equals('/diniz/Upload/'));
      expect(appState.pasta_download, equals('/diniz/Upload/'));
      expect(appState.pastaUpload0, equals('/diniz/upload/02'));
      expect(appState.pasta_upload, equals('/diniz/upload/02'));
      expect(appState.nomeArquivoDb, equals('ven'));
    });
  });
}
