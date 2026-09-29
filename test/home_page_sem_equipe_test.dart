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
    AppState.reset();
  });

  testWidgets('HomePage: exibe apenas nome do vendedor e remove equipe do cabeçalho', (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    AppState().vendedor_nome = 'VENDEDOR TESTE';
    AppState().vendedor_equipe = 2;

    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: AppState(),
        child: const MaterialApp(
          home: HomePageWidget(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));

    // Deve exibir exclusivamente o nome do vendedor sem o sufixo de equipe
    expect(find.text('Bem vindo, VENDEDOR TESTE'), findsOneWidget);
    expect(find.textContaining('(Equipe 2)'), findsNothing);
  });
}
