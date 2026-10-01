import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:forca_de_vendas/app_state.dart';
import 'package:forca_de_vendas/pages/home_page/home_page_widget.dart';
import 'package:forca_de_vendas/components/modal_selecao_filial/modal_selecao_filial_widget.dart';
import 'package:forca_de_vendas/data/services/local_sales_database_service.dart';

import 'package:google_fonts/google_fonts.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('HomePageWidget - Seleção de Filial', () {
    late Database db;

    setUp(() async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMessageHandler('flutter/assets', (ByteData? message) async {
        if (message == null) return null;
        try {
          final key = utf8.decode(message.buffer.asUint8List());
          if (key == 'AssetManifest.bin') {
            return const StandardMessageCodec().encodeMessage(<String, dynamic>{});
          }
        } catch (_) {}
        return ByteData(0);
      });
      SharedPreferences.setMockInitialValues({});
      AppState.reset();
      await AppState().initializePersistedState();

      // Configurar banco de dados em memória
      db = await databaseFactory.openDatabase(inMemoryDatabasePath);
      await db.execute('CREATE TABLE estpro00 (pro00_codfil TEXT)');
      await db.execute('CREATE TABLE cadfil00 (fil00_codigo TEXT, fil00_descri TEXT)');
      
      LocalSalesDatabaseService.setDatabaseForTesting(db);
    });

    tearDown(() async {
      await db.close();
      LocalSalesDatabaseService.setDatabaseForTesting(null);
    });

    Widget createWidgetUnderTest() {
      return ChangeNotifierProvider.value(
        value: AppState(),
        child: const MaterialApp(
          home: HomePageWidget(),
        ),
      );
    }

    testWidgets('Não deve exibir ModalSelecaoFilial quando ven_selfil == 0', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      AppState().ven_selfil = 0;
      AppState().codFilialAtiva = 1;
      
      await tester.runAsync(() async {
        await db.insert('estpro00', {'pro00_codfil': '1'});
        await db.insert('estpro00', {'pro00_codfil': '2'});
      });
      
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pump(const Duration(milliseconds: 300));

      final filialText = find.text('Filial: 01');
      expect(filialText, findsOneWidget);

      await tester.tap(filialText);
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(ModalSelecaoFilialWidget), findsNothing);
    });

    testWidgets('Deve exibir ModalSelecaoFilial quando ven_selfil == 1 e houver múltiplas filiais', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      AppState().ven_selfil = 1;
      AppState().codFilialAtiva = 1;
      await tester.runAsync(() async {
        await db.insert('estpro00', {'pro00_codfil': '1'});
        await db.insert('estpro00', {'pro00_codfil': '2'});
        await db.insert('cadfil00', {'fil00_codigo': '1', 'fil00_descri': 'Filial 1'});
        await db.insert('cadfil00', {'fil00_codigo': '2', 'fil00_descri': 'Filial 2'});
      });

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pump(const Duration(milliseconds: 300));

      final filialText = find.text('Filial: 01');
      expect(filialText, findsOneWidget);

      await tester.runAsync(() async {
        await tester.tap(filialText);
        await Future.delayed(const Duration(milliseconds: 300));
      });
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(ModalSelecaoFilialWidget), findsOneWidget);

      // Fechar o modal para evitar futures soltas e falha no tearDown
      await tester.tap(find.textContaining('Filial 1'));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.tap(find.text('Confirmar Filial'));
      await tester.pump(const Duration(milliseconds: 500));
    });
  });
}
