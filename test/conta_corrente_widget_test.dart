import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forca_de_vendas/app_state.dart';
import 'package:forca_de_vendas/components/modal_relatorios/modal_relatorios_widget.dart';
import 'package:forca_de_vendas/pages/relatorios/conta_corrente/conta_corrente_page_widget.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
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
  });

  tearDownAll(() async {});

  Widget createTestableWidget(Widget child) {
    return ChangeNotifierProvider<AppState>.value(
      value: AppState(),
      child: MaterialApp(
        home: child,
      ),
    );
  }

  testWidgets('ModalRelatoriosWidget renderiza opções de relatórios corretamente', (WidgetTester tester) async {
    await tester.pumpWidget(createTestableWidget(const ModalRelatoriosWidget()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Menu de Relatórios'), findsOneWidget);
    expect(find.text('Conta-Corrente (CCV)'), findsOneWidget);
    expect(find.text('Extrato de margens, créditos e débitos de Saldo Flex.'), findsOneWidget);
    expect(find.byIcon(Icons.account_balance_wallet_rounded), findsOneWidget);
  });

  testWidgets('ContaCorrentePageWidget renderiza cabeçalho, filtros e lista', (WidgetTester tester) async {
    await tester.pumpWidget(createTestableWidget(const ContaCorrentePageWidget()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(tester.takeException(), isNull);
    expect(find.text('Conta-Corrente (CCV)'), findsOneWidget);
  });
}
