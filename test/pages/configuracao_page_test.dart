import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:forca_de_vendas/core/services/empresa_logo_service.dart';
import 'package:forca_de_vendas/pages/configuracao_page/configuracao_page_widget.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget createTestWidget() {
    return const MaterialApp(
      home: ConfiguracaoPageWidget(),
    );
  }

  group('ConfiguracaoPageWidget', () {
    testWidgets('renderiza tela de configurações com seções de relatório e suporte', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Configurações'), findsWidgets);
      expect(find.text('Exibir logotipo no PDF do Pedido'), findsOneWidget);
      expect(find.text('Suporte Técnico'), findsOneWidget);
      expect(find.text('+55 (98) 8128-3380'), findsOneWidget);
    });

    testWidgets('alterna o switch de exibir logotipo no PDF e persiste no SharedPreferences', (tester) async {
      SharedPreferences.setMockInitialValues({
        EmpresaLogoService.prefKeyExibirLogoPdf: true,
      });

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      final switchFinder = find.byType(Switch);
      expect(switchFinder, findsOneWidget);

      Switch switchWidget = tester.widget(switchFinder);
      expect(switchWidget.value, isTrue);

      // Toca no switch para desabilitar
      await tester.tap(switchFinder);
      await tester.pumpAndSettle();

      switchWidget = tester.widget(switchFinder);
      expect(switchWidget.value, isFalse);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(EmpresaLogoService.prefKeyExibirLogoPdf), isFalse);
    });
  });
}
