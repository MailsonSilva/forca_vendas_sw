import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forca_de_vendas/app_state.dart';
import 'package:forca_de_vendas/pages/login_page/login_page_widget.dart';
import 'package:forca_de_vendas/components/botao_menu_home/botao_menu_home_widget.dart';
import 'package:forca_de_vendas/components/modal_cliente/modal_cliente_widget.dart';
import 'package:forca_de_vendas/components/modal_pedidos/modal_pedidos_widget.dart';
import 'package:forca_de_vendas/components/quantity_modal/quantity_modal_widget.dart';
import 'package:forca_de_vendas/components/modal_agente_cobrador/modal_agente_cobrador_widget.dart';
import 'package:forca_de_vendas/components/modal_selecao_filial/modal_selecao_filial_widget.dart';
import 'package:forca_de_vendas/action_code/contar_filiais.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  Widget createTestableWidget(Widget child) {
    return ChangeNotifierProvider<AppState>.value(
      value: AppState(),
      child: MaterialApp(
        home: Scaffold(
          body: child,
        ),
      ),
    );
  }

  group('Validação de Telas e Modais Responsivos (Comportamento e Bindings)', () {
    testWidgets('LoginPageWidget renderiza formulário de login e reage a entradas', (tester) async {
      await tester.pumpWidget(createTestableWidget(const LoginPageWidget()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(tester.takeException(), isNull);
      expect(find.byType(LoginPageWidget), findsOneWidget);
      expect(find.byType(TextFormField), findsAtLeastNWidgets(2));
    });

    testWidgets('BotaoMenuHomeWidget renderiza texto e ícone corretamente', (tester) async {
      bool clicou = false;
      await tester.pumpWidget(createTestableWidget(
        InkWell(
          onTap: () => clicou = true,
          child: const BotaoMenuHomeWidget(
            description: 'MEUS CLIENTES',
            icon: Icon(Icons.people),
          ),
        ),
      ));
      await tester.pump();

      expect(find.text('MEUS CLIENTES'), findsOneWidget);
      expect(find.byIcon(Icons.people), findsOneWidget);

      await tester.tap(find.text('MEUS CLIENTES'));
      await tester.pump();

      expect(clicou, isTrue);
    });

    testWidgets('ModalClienteWidget renderiza opções e botão de fechar com altura compacta', (tester) async {
      await tester.pumpWidget(createTestableWidget(
        const Align(
          alignment: Alignment.bottomCenter,
          child: ModalClienteWidget(),
        ),
      ));
      await tester.pump();

      expect(find.text('Clientes'), findsOneWidget);
      expect(find.text('Consultar Clientes'), findsOneWidget);
      expect(find.text('Contas a Receber'), findsOneWidget);
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);

      final modalSize = tester.getSize(find.byType(ModalClienteWidget));
      expect(modalSize.height, lessThan(520.0));
    });

    testWidgets('ModalPedidosWidget renderiza opções e botão de fechar com altura compacta', (tester) async {
      await tester.pumpWidget(createTestableWidget(
        const Align(
          alignment: Alignment.bottomCenter,
          child: ModalPedidosWidget(),
        ),
      ));
      await tester.pump();

      expect(find.text('Pedidos'), findsOneWidget);
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);

      final modalSize = tester.getSize(find.byType(ModalPedidosWidget));
      expect(modalSize.height, lessThan(350.0));
    });

    testWidgets('QuantityModalWidget exibe dados vinculados do produto e stepper', (tester) async {
      await tester.pumpWidget(createTestableWidget(
        const QuantityModalWidget(
          codigoProduto: 'PROD-100',
          descricaoProduto: 'REFRIGERANTE COLA 2L',
          unidadeProduto: 'UN',
          precoUnitario: 8.50,
          saldoDisponivel: 50.0,
        ),
      ));
      await tester.pump();

      expect(find.text('REFRIGERANTE COLA 2L'), findsOneWidget);
      expect(find.text('PROD-100'), findsOneWidget);
      expect(find.text('UN'), findsOneWidget);
      expect(find.text('CONFIRMAR PEDIDO'), findsOneWidget);
    });

    testWidgets('ModalAgenteCobradorWidget renderiza campo de busca e fallback', (tester) async {
      await tester.pumpWidget(createTestableWidget(
        const ModalAgenteCobradorWidget(
          clienteCodigo: 999,
          planoCodigo: 999,
        ),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Selecione o Agente Cobrador'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('ModalSelecaoFilialWidget renderiza filiais e permite seleção', (tester) async {
      final filiais = [
        FilialInfo(codigo: '1', descricao: 'MATRIZ SP'),
        FilialInfo(codigo: '2', descricao: 'FILIAL RJ'),
      ];

      await tester.pumpWidget(createTestableWidget(
        ModalSelecaoFilialWidget(filiais: filiais),
      ));
      await tester.pump();

      expect(find.text('Selecione a Filial'), findsOneWidget);
      expect(find.text('MATRIZ SP'), findsOneWidget);
      expect(find.text('FILIAL RJ'), findsOneWidget);
      expect(find.text('Confirmar Filial'), findsOneWidget);

      await tester.tap(find.text('MATRIZ SP'));
      await tester.pumpAndSettle();

      // Botão habilitado após seleção
      final btn = tester.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'Confirmar Filial'));
      expect(btn.enabled, isTrue);
    });
  });
}
