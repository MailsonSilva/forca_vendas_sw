import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:forca_de_vendas/app_state.dart';
import 'package:forca_de_vendas/pages/configuracao_page/configuracao_page_widget.dart';
import 'package:forca_de_vendas/services/carga_database_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Leitura da versão do sistema vinda da carga (cadcfg00.cfg00_versis)', () {
    late String dbPath;
    late Database db;
    late Directory tempDir;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      AppState.reset();
      await AppState().initializePersistedState();

      tempDir = await Directory.systemTemp.createTemp('versao_carga_test_');
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

    test('1. Extrai versão via SELECT cfg00_versis FROM cadcfg00 LIMIT 1 e persiste em SharedPreferences e AppState', () async {
      await db.execute('''
        CREATE TABLE cadcfg00 (
          cfg00_numcar INTEGER,
          cfg00_versis TEXT
        );
      ''');

      await db.insert('cadcfg00', {
        'cfg00_numcar': 100,
        'cfg00_versis': 'v4.1.5',
      });

      final service = CargaDatabaseService();
      final versaoExtraida = await service.extrairVersaoSistema(db);
      expect(versaoExtraida, equals('v4.1.5'));

      final resultado = await service.processarCamposCarga(db: db);
      expect(resultado.versaoSistema, equals('v4.1.5'));

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('versao_carga_sistema'), equals('v4.1.5'));
      expect(AppState().versaoSistema, equals('v4.1.5'));
    });

    test('2. Fallback de segurança 1: SELECT srv00_verapp FROM cadace00 LIMIT 1 quando cadcfg00 não tem cfg00_versis', () async {
      await db.execute('''
        CREATE TABLE cadcfg00 (
          cfg00_numcar INTEGER
        );
      ''');
      await db.execute('''
        CREATE TABLE cadace00 (
          srv00_verapp TEXT
        );
      ''');

      await db.insert('cadcfg00', {'cfg00_numcar': 101});
      await db.insert('cadace00', {'srv00_verapp': 'v3.2.0'});

      final service = CargaDatabaseService();
      final versaoExtraida = await service.extrairVersaoSistema(db);
      expect(versaoExtraida, equals('v3.2.0'));

      await service.processarCamposCarga(db: db);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('versao_carga_sistema'), equals('v3.2.0'));
      expect(AppState().versaoSistema, equals('v3.2.0'));
    });

    test('3. Fallback de segurança 2: SELECT srv00_versis FROM cadace00 LIMIT 1 quando srv00_verapp não existe', () async {
      await db.execute('''
        CREATE TABLE cadace00 (
          srv00_versis TEXT
        );
      ''');

      await db.insert('cadace00', {'srv00_versis': 'v2.0.1'});

      final service = CargaDatabaseService();
      final versaoExtraida = await service.extrairVersaoSistema(db);
      expect(versaoExtraida, equals('v2.0.1'));

      await service.processarCamposCarga(db: db);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('versao_carga_sistema'), equals('v2.0.1'));
      expect(AppState().versaoSistema, equals('v2.0.1'));
    });
  });

  group('Exibição da Versão da Carga na Tela de Configurações', () {
    testWidgets('Exibe seção "Sobre o Sistema" com ListTile contendo a versão da carga', (tester) async {
      SharedPreferences.setMockInitialValues({
        'versao_carga_sistema': 'v4.1.5',
      });
      AppState.reset();
      AppState().versaoSistema = 'v4.1.5';
      await AppState().initializePersistedState();

      await tester.pumpWidget(
        const MaterialApp(
          home: ConfiguracaoPageWidget(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Sobre o Sistema'), findsOneWidget);
      expect(find.text('Versão do Sistema (Carga)'), findsOneWidget);
      expect(find.text('v4.1.5'), findsOneWidget);
      expect(find.byIcon(Icons.info_outline), findsOneWidget);
    });

    testWidgets('Exibe "Não identificada" quando não houver versão lida da carga', (tester) async {
      SharedPreferences.setMockInitialValues({});
      AppState.reset();
      await AppState().initializePersistedState();

      await tester.pumpWidget(
        const MaterialApp(
          home: ConfiguracaoPageWidget(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Sobre o Sistema'), findsOneWidget);
      expect(find.text('Versão do Sistema (Carga)'), findsOneWidget);
      expect(find.text('Não identificada'), findsOneWidget);
      expect(find.byIcon(Icons.info_outline), findsOneWidget);
    });

    testWidgets('Reflete dinamicamente a versão da carga mais recente se atualizada', (tester) async {
      SharedPreferences.setMockInitialValues({});
      AppState.reset();
      await AppState().initializePersistedState();

      await tester.pumpWidget(
        const MaterialApp(
          home: ConfiguracaoPageWidget(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Não identificada'), findsOneWidget);

      // Simula chegada/atualização de carga em segundo plano
      AppState().versaoSistema = 'v5.0.0';
      await tester.pumpAndSettle();

      expect(find.text('v5.0.0'), findsOneWidget);
      expect(find.text('Não identificada'), findsNothing);
    });
  });
}
