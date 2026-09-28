import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:forca_de_vendas/app_state.dart';
import 'package:forca_de_vendas/pages/envio/envio_page_widget.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AppState().initializePersistedState();
    AppState().vendedor_nome = 'Vendedor Teste';
    AppState().vendedor_codigo = 71;
    AppState().vendedor_equipe = 12;
  });

  testWidgets('EnvioPageWidget renderiza cabeçalho, botão e PopScope', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: EnvioPageWidget(
          nomePacote: 'p71-1001.pac',
          sequencialPacote: 1001,
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Comunicação FTP (ffrmcom00)'), findsOneWidget);
    expect(find.text('Pacote: p71-1001.pac'), findsOneWidget);
    expect(find.text('Transmitir e Aguardar Retorno'), findsOneWidget);

    // Valida que o PopScope está ativo no Scaffold
    final popScopeFinder = find.byType(PopScope);
    expect(popScopeFinder, findsWidgets);

    final PopScope popScope = tester.widget<PopScope>(popScopeFinder.first);
    expect(popScope.canPop, isTrue); // Inicialmente desbloqueado
  });
}
