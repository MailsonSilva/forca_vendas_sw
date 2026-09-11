import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:forca_de_vendas/pages/pedido_resumo/pedido_resumo_widget.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  testWidgets('PedidoResumoWidget renders PDF action button in AppBar', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: PedidoResumoWidget(pedidoId: 100),
      ),
    );

    // Initial pump builds the scaffold and AppBar
    await tester.pump();

    // Verify AppBar title
    expect(find.text('Extrato do Pedido'), findsOneWidget);

    // Verify the old icon 'Icons.list_alt_rounded' is NOT present in the AppBar
    expect(find.byIcon(Icons.list_alt_rounded), findsNothing);

    // Verify the new PDF icon and label ARE present in the AppBar
    expect(find.byIcon(Icons.picture_as_pdf_rounded), findsOneWidget);
    expect(find.text('PDF'), findsOneWidget);
  });
}
