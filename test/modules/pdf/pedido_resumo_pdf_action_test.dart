import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:forca_de_vendas/pages/pedido_resumo/pedido_resumo_widget.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  setUpAll(() {
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

  testWidgets('PedidoResumoWidget renders PDF action button in AppBar', (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

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
