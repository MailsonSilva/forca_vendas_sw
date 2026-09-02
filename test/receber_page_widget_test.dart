import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forca_de_vendas/app_state.dart';
import 'package:forca_de_vendas/components/extrato_duplicatas/extrato_duplicatas_widget.dart';
import 'package:forca_de_vendas/pages/receber/receber_page_widget.dart';
import 'package:forca_de_vendas/services/receber_duplicatas_service.dart';
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

  testWidgets('ReceberPageWidget renderiza cabeçalho, card de resumo e chips de filtro', (WidgetTester tester) async {
    await tester.pumpWidget(createTestableWidget(const ReceberPageWidget()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Contas a Receber'), findsOneWidget);
    expect(find.text('Posição Geral de Débitos'), findsOneWidget);
    expect(find.text('Todos com Débito'), findsOneWidget);
    expect(find.text('Apenas Vencidos'), findsOneWidget);
    expect(find.text('A Vencer'), findsNWidgets(2));
    expect(find.byIcon(Icons.sort_rounded), findsOneWidget);
    expect(find.byIcon(Icons.refresh_rounded), findsOneWidget);
  });

  testWidgets('ExtratoDuplicatasWidget renderiza resumo financeiro e botões de ação', (WidgetTester tester) async {
    final cliente = ClienteReceberItem(
      codCli: 42,
      razaoSocial: 'COMERCIAL ALVORADA LTDA',
      fantasia: 'ALVORADA',
      cidadeUf: 'Recife - PE',
      limiteCredito: 10000.0,
      limiteAtual: 7500.0,
      totalVencido: 1250.0,
      totalAVencer: 1250.0,
      totalDevedor: 2500.0,
      totalJuros: 25.0,
      maiorDiasAtraso: 14,
      qtdTitulosVencidos: 1,
      qtdTitulosTotal: 2,
      titulos: [
        TituloDuplicataItem(
          codigo: 501,
          codCli: 42,
          numeroDocumento: '501-A',
          dataVencimento: DateTime(2026, 8, 19),
          valorOriginal: 1250.0,
          valorPago: 0.0,
          saldoDevedor: 1250.0,
          diasAtraso: 14,
          isVencido: true,
          valorJuros: 25.0,
          totalComJuros: 1275.0,
        ),
      ],
    );

    await tester.pumpWidget(createTestableWidget(ExtratoDuplicatasWidget(clienteInicial: cliente)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Extrato de Duplicatas'), findsOneWidget);
    expect(find.text('COMERCIAL ALVORADA LTDA'), findsOneWidget);
    expect(find.text('Compartilhar'), findsOneWidget);
    expect(find.text('Novo Pedido'), findsOneWidget);
    expect(find.text('Total Vencido'), findsOneWidget);
    expect(find.text('Total A Vencer'), findsOneWidget);
  });
}
