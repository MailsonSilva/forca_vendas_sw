import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:forca_de_vendas/app_state.dart';
import 'package:forca_de_vendas/pages/home_page/home_page_widget.dart';
import 'package:forca_de_vendas/pages/configuracao_page/configuracao_page_widget.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  setUp(() {
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
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues({});
  });

  group('Logout relocation tests', () {
    testWidgets('HomePageWidget nao deve conter botao de sair', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      AppState.reset();
      final appState = AppState();
      await appState.initializePersistedState();

      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: appState,
          child: const MaterialApp(
            home: HomePageWidget(),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));

      // O botao de sair com icone logout_rounded ou tooltip 'Sair da conta' nao deve existir na HomePage
      expect(find.byIcon(Icons.logout_rounded), findsNothing);
      expect(find.byTooltip('Sair da conta'), findsNothing);
      expect(find.text('Sair do Sistema'), findsNothing);
    });

    testWidgets('ConfiguracaoPageWidget deve conter secao e botao de Sair do Sistema', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ConfiguracaoPageWidget(),
        ),
      );
      await tester.pumpAndSettle();

      // Deve encontrar a secao e o botao de sair
      final logoutFinder = find.text('Sair do Sistema');
      expect(logoutFinder, findsOneWidget);
      expect(find.byIcon(Icons.logout_rounded), findsOneWidget);

      // Tocar no botao deve abrir o dialogo de confirmacao de logout
      await tester.ensureVisible(logoutFinder);
      await tester.tap(logoutFinder);
      await tester.pumpAndSettle();

      expect(find.text('Deseja realmente encerrar a sessão e realizar o logout?'), findsOneWidget);
      expect(find.text('Cancelar'), findsOneWidget);
      expect(find.text('Sair'), findsOneWidget);
    });
  });
}
