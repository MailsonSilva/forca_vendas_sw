import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:forca_de_vendas/app_state.dart';
import 'package:forca_de_vendas/pages/login_page/login_page_widget.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues({});
    AppState.reset();
  });

  Widget createLoginTestWidget() {
    return ChangeNotifierProvider<AppState>.value(
      value: AppState(),
      child: const MaterialApp(
        home: LoginPageWidget(),
      ),
    );
  }

  testWidgets('Tela de login exibe campos de empresa e vendedor e logo com dimensões ampliadas', (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(createLoginTestWidget());
    await tester.pump(const Duration(milliseconds: 200));

    // 1. Verifica campos visíveis
    expect(find.widgetWithText(TextFormField, 'Código da Empresa'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Código do Vendedor'), findsOneWidget);
    expect(find.text('ENTRAR'), findsOneWidget);

    // 2. Verifica a presença das logos ampliadas
    final imageFinder = find.byType(Image);
    expect(imageFinder, findsWidgets);

    // 3. Testa submissão com campos vazios -> Alerta de empresa
    await tester.tap(find.text('ENTRAR'));
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Código de acesso da empresa não foi encontrado'), findsOneWidget);
    await tester.tap(find.text('OK'));
    await tester.pump(const Duration(milliseconds: 200));

    // 4. Preenche empresa mas não preenche vendedor -> Alerta de vendedor
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Código da Empresa'),
      'EMPRESA_TESTE',
    );
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.text('ENTRAR'));
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Vendedor não encontrado'), findsOneWidget);
  });
}
