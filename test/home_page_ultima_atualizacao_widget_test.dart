import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:forca_de_vendas/app_state.dart';
import 'package:forca_de_vendas/pages/home_page/home_page_widget.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('HomePage exibe a data e hora da última carga', (tester) async {
    SharedPreferences.setMockInitialValues({});
    AppState.reset();
    final appState = AppState();
    await appState.initializePersistedState();
    appState.dataHoraUltimaCarga = DateTime(2026, 9, 15, 14, 55);

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: appState,
        child: const MaterialApp(
          home: HomePageWidget(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(
      find.text('Última atualização: 15/09/2026 às 14:55'),
      findsOneWidget,
    );
  });
}
