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

  testWidgets('Primeiro acesso: exibe campos de empresa e vendedor', (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(createLoginTestWidget());
    await tester.pump(const Duration(milliseconds: 200));

    // 1. Verifica campos visíveis
    expect(find.widgetWithText(TextFormField, 'Código da Empresa'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Código do Vendedor'), findsOneWidget);
    expect(find.text('ENTRAR'), findsOneWidget);

    // 2. Testa submissão com campos vazios -> Alerta de empresa
    await tester.tap(find.text('ENTRAR'));
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Código de acesso da empresa não foi encontrado'), findsOneWidget);
    await tester.tap(find.text('OK'));
    await tester.pump(const Duration(milliseconds: 200));

    // 3. Preenche empresa mas não preenche vendedor -> Alerta de vendedor
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Código da Empresa'),
      'EMPRESA_TESTE',
    );
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.text('ENTRAR'));
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Vendedor não encontrado'), findsOneWidget);
  });

  testWidgets('Acesso subsequente: oculta código da empresa e trava vendedor vinculado', (tester) async {
    SharedPreferences.setMockInitialValues({
      'codigo_empresa': 'DZ1000SW',
      'codigo_vendedor_vinculado': '71',
    });

    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(createLoginTestWidget());
    await tester.pump(const Duration(milliseconds: 200));

    // 1. Campo de empresa NÃO deve ser exibido
    expect(find.widgetWithText(TextFormField, 'Código da Empresa'), findsNothing);

    // 2. Campo de vendedor DEVE ser exibido
    expect(find.widgetWithText(TextFormField, 'Código do Vendedor'), findsOneWidget);

    // 3. Tentativa de logar com vendedor diferente (90 != 71)
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Código do Vendedor'),
      '90',
    );
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.text('ENTRAR'));
    await tester.pump(const Duration(milliseconds: 200));

    // 4. Deve exibir mensagem de bloqueio imediato
    expect(find.text('Este dispositivo está vinculado exclusivamente ao vendedor 71'), findsOneWidget);
  });

  testWidgets('Responsividade: renderiza sem overflow em tela reduzida 360x640', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(createLoginTestWidget());
    await tester.pump(const Duration(milliseconds: 200));

    expect(tester.takeException(), isNull);
    expect(find.byType(SingleChildScrollView), findsWidgets);
    expect(find.byType(ConstrainedBox), findsWidgets);
  });
}

