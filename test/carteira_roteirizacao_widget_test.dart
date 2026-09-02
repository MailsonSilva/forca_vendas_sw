import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forca_de_vendas/app_state.dart';
import 'package:forca_de_vendas/components/modal_relatorios/modal_relatorios_widget.dart';
import 'package:forca_de_vendas/pages/relatorios/carteira_roteirizacao/carteira_roteirizacao_page_widget.dart';
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

  testWidgets('ModalRelatoriosWidget renderiza opções incluindo Roteiro de Visitas', (tester) async {
    await tester.pumpWidget(createTestableWidget(const ModalRelatoriosWidget()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Relatórios'), findsOneWidget);
    expect(find.text('Conta-Corrente (CCV)'), findsOneWidget);
    expect(find.text('Resumo de Vendas e Comissões'), findsOneWidget);
    expect(find.text('Roteiro de Visitas (Carteira)'), findsOneWidget);
    expect(find.byIcon(Icons.route_rounded), findsOneWidget);
  });

  testWidgets('CarteiraRoteirizacaoPageWidget renderiza cabeçalho, campo de busca e chips de rota', (tester) async {
    await tester.pumpWidget(createTestableWidget(const CarteiraRoteirizacaoPageWidget()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(tester.takeException(), isNull);
    expect(find.text('Roteiro de Visitas'), findsOneWidget);
    expect(find.byIcon(Icons.refresh_rounded), findsOneWidget);
    expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
  });
}
