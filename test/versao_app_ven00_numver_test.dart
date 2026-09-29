import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:forca_de_vendas/app_state.dart';
import 'package:forca_de_vendas/pages/configuracao_page/configuracao_page_widget.dart';
import 'package:forca_de_vendas/services/carga_database_service.dart';
import 'package:forca_de_vendas/services/versao_app_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Regras de Extração e Precedência da Versão do App (ven00_numver)', () {
    late String dbPath;
    late Database db;
    late Directory tempDir;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      AppState.reset();
      await AppState().initializePersistedState();

      tempDir = await Directory.systemTemp.createTemp('versao_ven00_test_');
      dbPath = p.join(tempDir.path, 'dbforcacad001.db');
      db = await openDatabase(
        dbPath,
        version: 1,
        onCreate: (d, v) async {},
      );
    });

    tearDown(() async {
      await db.close();
      try {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      } catch (_) {}
    });

    test('1. Extrai versão a partir de ven00_numver do vendedor logado em cadrep00', () async {
      await db.execute('''
        CREATE TABLE cadrep00 (
          ven00_codigo INTEGER PRIMARY KEY,
          ven00_descri TEXT,
          ven00_numver TEXT
        );
      ''');
      await db.execute('''
        CREATE TABLE cadcfg00 (
          cfg00_versis TEXT
        );
      ''');

      await db.insert('cadrep00', {
        'ven00_codigo': 10,
        'ven00_descri': 'Vendedor 10',
        'ven00_numver': 'v2.5.0-build10',
      });
      await db.insert('cadrep00', {
        'ven00_codigo': 20,
        'ven00_descri': 'Vendedor 20',
        'ven00_numver': 'v3.0.0-build20',
      });
      await db.insert('cadcfg00', {
        'cfg00_versis': 'v1.0.0-carga',
      });

      AppState().vendedor_codigo = 10;

      final versao = await VersaoAppService.instance.resolverVersaoApp(
        db: db,
        codVendedor: 10,
        versaoPacoteFallback: '1.0.0',
      );

      expect(versao, equals('v2.5.0-build10'));
      expect(AppState().versaoApp, equals('v2.5.0-build10'));

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('app_versao_app'), equals('v2.5.0-build10'));
    });

    test('2. Fallback 1: Caso ven00_numver esteja nulo ou vazio no vendedor, busca cfg00_versis em cadcfg00', () async {
      await db.execute('''
        CREATE TABLE cadrep00 (
          ven00_codigo INTEGER PRIMARY KEY,
          ven00_descri TEXT,
          ven00_numver TEXT
        );
      ''');
      await db.execute('''
        CREATE TABLE cadcfg00 (
          cfg00_versis TEXT
        );
      ''');

      await db.insert('cadrep00', {
        'ven00_codigo': 10,
        'ven00_descri': 'Vendedor 10',
        'ven00_numver': '', // Vazio
      });
      await db.insert('cadcfg00', {
        'cfg00_versis': 'v4.2.1-carga',
      });

      final versao = await VersaoAppService.instance.resolverVersaoApp(
        db: db,
        codVendedor: 10,
        versaoPacoteFallback: '1.0.0',
      );

      expect(versao, equals('v4.2.1-carga'));
      expect(AppState().versaoApp, equals('v4.2.1-carga'));

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('app_versao_app'), equals('v4.2.1-carga'));
    });

    test('3. Fallback 2: Caso nem ven00_numver nem cfg00_versis existam, mantém a versão do pacote atual', () async {
      await db.execute('''
        CREATE TABLE cadrep00 (
          ven00_codigo INTEGER PRIMARY KEY,
          ven00_descri TEXT
        );
      ''');
      await db.execute('''
        CREATE TABLE cadcfg00 (
          cfg00_numcar INTEGER
        );
      ''');

      await db.insert('cadrep00', {
        'ven00_codigo': 10,
        'ven00_descri': 'Vendedor 10',
      });
      await db.insert('cadcfg00', {
        'cfg00_numcar': 123,
      });

      final versao = await VersaoAppService.instance.resolverVersaoApp(
        db: db,
        codVendedor: 10,
        versaoPacoteFallback: '2.1.0',
      );

      expect(versao, equals('2.1.0'));
      expect(AppState().versaoApp, equals('2.1.0'));

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('app_versao_app'), equals('2.1.0'));
    });

    test('4. CargaDatabaseService integra extrairVersaoAppVendedor e processarCamposCarga', () async {
      await db.execute('''
        CREATE TABLE cadrep00 (
          ven00_codigo INTEGER,
          ven00_numver TEXT
        );
      ''');
      await db.execute('''
        CREATE TABLE cadcfg00 (
          cfg00_numcar INTEGER,
          cfg00_versis TEXT
        );
      ''');

      await db.insert('cadrep00', {
        'ven00_codigo': 55,
        'ven00_numver': 'v9.8.7',
      });
      await db.insert('cadcfg00', {
        'cfg00_numcar': 10,
        'cfg00_versis': 'v1.1.1',
      });

      final service = CargaDatabaseService();
      final extraida = await service.extrairVersaoAppVendedor(db, vendedorCodigo: 55);
      expect(extraida, equals('v9.8.7'));

      final resultado = await service.processarCamposCarga(db: db, vendedorCodigo: 55);
      expect(resultado.versaoApp, equals('v9.8.7'));
      expect(AppState().versaoApp, equals('v9.8.7'));
    });
  });

  group('Vinculação e Restrição de UI no Widget de Configurações', () {
    testWidgets('Renderiza versão obtida de ven00_numver no widget pré-existente e NÃO cria seção Sobre o Sistema', (tester) async {
      SharedPreferences.setMockInitialValues({
        'app_versao_app': 'v2.5.0-build10',
      });
      AppState.reset();
      AppState().versaoApp = 'v2.5.0-build10';
      await AppState().initializePersistedState();

      await tester.pumpWidget(
        const MaterialApp(
          home: ConfiguracaoPageWidget(),
        ),
      );
      await tester.pumpAndSettle();

      // UI Restriction check
      expect(find.text('Sobre o Sistema'), findsNothing);
      expect(find.text('Versão do Sistema (Carga)'), findsNothing);

      // Existing widget verification
      expect(find.text('Versão do App: v2.5.0-build10'), findsOneWidget);
    });
  });
}
