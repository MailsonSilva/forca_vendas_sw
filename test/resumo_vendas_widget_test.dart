import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forca_de_vendas/app_state.dart';
import 'package:forca_de_vendas/components/modal_relatorios/modal_relatorios_widget.dart';
import 'package:forca_de_vendas/pages/relatorios/resumo_vendas/resumo_vendas_page_widget.dart';
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
        home: child,
      ),
    );
  }

  testWidgets('ModalRelatoriosWidget renderiza opções de relatórios incluindo Resumo de Vendas', (tester) async {
    await tester.pumpWidget(createTestableWidget(const ModalRelatoriosWidget()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Relatórios'), findsOneWidget);
    expect(find.text('Conta-Corrente (CCV)'), findsOneWidget);
    expect(find.text('Resumo de Vendas e Comissões'), findsOneWidget);
    expect(find.text('Apuração de vendas brutas, líquidas, devoluções e comissões.'), findsOneWidget);
    expect(find.byIcon(Icons.query_stats_rounded), findsOneWidget);
  });

  testWidgets('ResumoVendasPageWidget renderiza cabeçalho e botões de ação', (tester) async {
    await tester.pumpWidget(createTestableWidget(const ResumoVendasPageWidget()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(tester.takeException(), isNull);
    expect(find.text('Resumo de Vendas'), findsOneWidget);
    expect(find.byIcon(Icons.share_outlined), findsOneWidget);
    expect(find.byIcon(Icons.refresh_rounded), findsOneWidget);
    expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);
  });
}
