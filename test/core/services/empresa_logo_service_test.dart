import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:forca_de_vendas/core/services/empresa_logo_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Database db;
  late Directory tempDir;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    tempDir = await Directory.systemTemp.createTemp('empresa_logo_test_');

    db = await openDatabase(
      inMemoryDatabasePath,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE cadace00 (
            ace00_codigo INTEGER PRIMARY KEY,
            srv00_imglog BLOB
          )
        ''');
      },
    );
  });

  tearDown(() async {
    await db.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('EmpresaLogoService Decodificador Base64 e Binario', () {
    final expectedBytes = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);
    final rawBase64 = base64Encode(expectedBytes);

    test('decodifica String Base64 pura', () {
      final decoded = EmpresaLogoService.decodificarBase64OuBinario(rawBase64);
      expect(decoded, equals(expectedBytes));
    });

    test('decodifica String Base64 com prefixo data URI', () {
      final uri = 'data:image/png;base64,$rawBase64';
      final decoded = EmpresaLogoService.decodificarBase64OuBinario(uri);
      expect(decoded, equals(expectedBytes));
    });

    test('decodifica String Base64 com quebras de linha e espaços', () {
      final formatted = '  data:image/png;base64, \r\n ${rawBase64.substring(0, 4)} \n ${rawBase64.substring(4)} \r\n ';
      final decoded = EmpresaLogoService.decodificarBase64OuBinario(formatted);
      expect(decoded, equals(expectedBytes));
    });

    test('retorna null para String malformada', () {
      final decoded = EmpresaLogoService.decodificarBase64OuBinario('!!!nao-e-base64-valido!!!');
      expect(decoded, isNull);
    });

    test('retorna null para null ou String vazia', () {
      expect(EmpresaLogoService.decodificarBase64OuBinario(null), isNull);
      expect(EmpresaLogoService.decodificarBase64OuBinario(''), isNull);
      expect(EmpresaLogoService.decodificarBase64OuBinario('   '), isNull);
    });

    test('preserva Uint8List e List<int> de binário direto', () {
      final directUint8 = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 1, 2, 3]);
      expect(EmpresaLogoService.decodificarBase64OuBinario(directUint8), equals(directUint8));

      final directList = [0xFF, 0xD8, 0xFF, 0xE0, 10, 20];
      expect(EmpresaLogoService.decodificarBase64OuBinario(directList), equals(Uint8List.fromList(directList)));
    });

    test('decodifica List<int> contendo texto ASCII em base64', () {
      final asciiBytes = utf8.encode('data:image/png;base64,$rawBase64');
      final decoded = EmpresaLogoService.decodificarBase64OuBinario(asciiBytes);
      expect(decoded, equals(expectedBytes));
    });
  });

  group('EmpresaLogoService Integração com Banco e Cache', () {
    test('extrairLogoDaCarga decodifica Base64 de cadace00 e persiste em empresa_logo.png', () async {
      final service = EmpresaLogoService(customCacheDir: tempDir.path);
      final fakePngBytes = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 1, 2, 3]);
      final base64String = 'data:image/png;base64,${base64Encode(fakePngBytes)}';

      // Insere como String (conforme o ERP armazena)
      await db.insert('cadace00', {
        'ace00_codigo': 1,
        'srv00_imglog': base64String,
      });

      final result = await service.extrairLogoDaCarga(db);

      expect(result, isNotNull);
      expect(result, equals(fakePngBytes));

      final cacheFile = File('${tempDir.path}/${EmpresaLogoService.cacheFileName}');
      expect(await cacheFile.exists(), isTrue);
      // O arquivo em disco DEVE conter o binário decodificado
      expect(await cacheFile.readAsBytes(), equals(fakePngBytes));
    });

    test('extrairLogoDaCarga extrai BLOB binário de cadace00 e persiste no arquivo', () async {
      final service = EmpresaLogoService(customCacheDir: tempDir.path);

      final fakeBytes = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 0x01, 0x02, 0x03]);

      await db.insert('cadace00', {
        'ace00_codigo': 1,
        'srv00_imglog': fakeBytes,
      });

      final result = await service.extrairLogoDaCarga(db);

      expect(result, isNotNull);
      expect(result, equals(fakeBytes));

      final cacheFile = File('${tempDir.path}/${EmpresaLogoService.cacheFileName}');
      expect(await cacheFile.exists(), isTrue);
      expect(await cacheFile.readAsBytes(), equals(fakeBytes));
    });

    test('extrairLogoDaCarga retorna null quando cadace00 não possui srv00_imglog', () async {
      final service = EmpresaLogoService(customCacheDir: tempDir.path);

      await db.insert('cadace00', {
        'ace00_codigo': 1,
        'srv00_imglog': null,
      });

      final result = await service.extrairLogoDaCarga(db);
      expect(result, isNull);
    });

    test('obterLogoBytes recupera do cache em disco quando presente', () async {
      final service = EmpresaLogoService(customCacheDir: tempDir.path);
      final fakeBytes = Uint8List.fromList([1, 2, 3, 4, 5]);

      final cacheFile = File('${tempDir.path}/${EmpresaLogoService.cacheFileName}');
      await cacheFile.writeAsBytes(fakeBytes);

      final result = await service.obterLogoBytes();
      expect(result, equals(fakeBytes));
    });

    test('obterLogoBytes faz fallback para o banco caso o cache em disco não exista', () async {
      final service = EmpresaLogoService(customCacheDir: tempDir.path);
      final fakeBytes = Uint8List.fromList([9, 8, 7, 6]);

      await db.insert('cadace00', {
        'ace00_codigo': 1,
        'srv00_imglog': fakeBytes,
      });

      final result = await service.obterLogoBytes(db: db);
      expect(result, equals(fakeBytes));

      // Deve ter gravado em disco no fallback
      final cacheFile = File('${tempDir.path}/${EmpresaLogoService.cacheFileName}');
      expect(await cacheFile.exists(), isTrue);
    });

    test('preferência config_exibir_logo_pdf padrão é true e pode ser alternada', () async {
      final service = EmpresaLogoService(customCacheDir: tempDir.path);

      // Padrão sem chave salva deve ser true
      expect(await service.isExibirLogoPdfHabilitado(), isTrue);

      await service.setExibirLogoPdf(false);
      expect(await service.isExibirLogoPdfHabilitado(), isFalse);

      await service.setExibirLogoPdf(true);
      expect(await service.isExibirLogoPdfHabilitado(), isTrue);
    });
  });
}
