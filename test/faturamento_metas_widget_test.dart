import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forca_de_vendas/app_state.dart';
import 'package:forca_de_vendas/components/modal_relatorios/modal_relatorios_widget.dart';
import 'package:forca_de_vendas/pages/relatorios/faturamento_metas/faturamento_metas_page_widget.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
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

  testWidgets('ModalRelatoriosWidget renderiza todas as 4 opções de relatórios', (WidgetTester tester) async {
    await tester.pumpWidget(createTestableWidget(const ModalRelatoriosWidget()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Menu de Relatórios'), findsOneWidget);
    expect(find.text('Conta-Corrente (CCV)'), findsOneWidget);
    expect(find.text('Resumo de Vendas e Comissões'), findsOneWidget);
    expect(find.text('Roteiro de Visitas (Carteira)'), findsOneWidget);
    expect(find.text('Faturamento e Metas'), findsOneWidget);
  });

  testWidgets('FaturamentoMetasPageWidget renderiza cabeçalho, cards de progresso e limites', (WidgetTester tester) async {
    await tester.pumpWidget(createTestableWidget(const FaturamentoMetasPageWidget()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(tester.takeException(), isNull);
    expect(find.text('Faturamento e Metas'), findsOneWidget);
    expect(find.text('Meta Geral Consolidada'), findsOneWidget);
    expect(find.text('Pessoa Jurídica (PJ)'), findsOneWidget);
    expect(find.text('Pessoa Física (PF)'), findsOneWidget);
    expect(find.text('Cota / Limite Fiscal Pessoa Física (PF)'), findsOneWidget);
  });
}
