import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:forca_de_vendas/app_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Data e Hora da Última Atualização (AppState)', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      AppState.reset();
      await AppState().initializePersistedState();
    });

    test('retorna mensagem padrao quando nenhuma carga foi realizada', () {
      final appState = AppState();
      expect(appState.dataHoraUltimaCarga, isNull);
      expect(
        appState.dataHoraUltimaCargaFormatada,
        'Última atualização: Não realizada',
      );
    });

    test('persiste e formata a data e hora da última carga no formato DD/MM/AAAA às HH:MM', () async {
      final appState = AppState();
      final dataCarga = DateTime(2026, 9, 15, 14, 55);

      appState.dataHoraUltimaCarga = dataCarga;

      expect(appState.dataHoraUltimaCarga, equals(dataCarga));
      expect(
        appState.dataHoraUltimaCargaFormatada,
        'Última atualização: 15/09/2026 às 14:55',
      );

      // Simula reinicialização do app para verificar se persistiu em SharedPreferences
      AppState.reset();
      final novoAppState = AppState();
      await novoAppState.initializePersistedState();

      expect(novoAppState.dataHoraUltimaCarga, equals(dataCarga));
      expect(
        novoAppState.dataHoraUltimaCargaFormatada,
        'Última atualização: 15/09/2026 às 14:55',
      );
    });
  });
}
