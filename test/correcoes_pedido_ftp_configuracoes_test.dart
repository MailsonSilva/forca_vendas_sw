import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:forca_de_vendas/app_state.dart';
import 'package:forca_de_vendas/action_code/salvar_carrinho_pedido.dart';
import 'package:forca_de_vendas/data/repositories/sales_database_repository.dart';
import 'package:forca_de_vendas/data/services/local_sales_database_service.dart';
import 'package:forca_de_vendas/main.dart';
import 'package:forca_de_vendas/pages/configuracao_page/configuracao_page_widget.dart';
import 'package:forca_de_vendas/pages/home_page/home_page_widget.dart';
import 'package:forca_de_vendas/services/nav_bar_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AppState().initializePersistedState();
    NavBarService().navegarParaHome();
  });

  group('Item 1: Filial no Novo Pedido e AppState', () {
    test('AppState possui alias filialAtiva sincronizado com codFilialAtiva', () {
      AppState().filialAtiva = 5;
      expect(AppState().filialAtiva, 5);
      expect(AppState().codFilialAtiva, 5);

      AppState().codFilialAtiva = 9;
      expect(AppState().filialAtiva, 9);
      expect(AppState().codFilialAtiva, 9);
    });

    test('salvarCarrinhoPedido persiste dig00_digfil com a filial informada/ativa', () async {
      final db = await databaseFactory.openDatabase(inMemoryDatabasePath);
      LocalSalesDatabaseService.setDatabaseForTesting(db);

      AppState().filialAtiva = 3;

      final success = await salvarCarrinhoPedido(
        pedidoId: 101,
        clienteCodigo: 1,
        linhaCodigo: '1',
        planoCodigo: '1',
        codFilial: 3,
        carrinhoItens: [],
      );

      expect(success, isTrue);

      final rows = await db.rawQuery(
        'SELECT ped00_codfil, dig00_digfil FROM pckvendig000 WHERE ped00_numped = ?',
        [101],
      );

      expect(rows.isNotEmpty, isTrue);
      expect(rows.first['ped00_codfil'], 3);
      expect(rows.first['dig00_digfil'], 3);

      await db.close();
      LocalSalesDatabaseService.setDatabaseForTesting(null);
    });
  });

  group('Item 2: Nomenclatura da Carga no FTP', () {
    test('gerarNomeArquivoRenomeado remove extensões e formata ven[cod].[YYYY-MM-DD] [HH-mm-ss]', () {
      final dt = DateTime(2025, 3, 7, 14, 8, 2);

      expect(
        SalesDatabaseRepository.gerarNomeArquivoRenomeado('ven268.crg', dt),
        'ven268.2025-03-07 14-08-02',
      );

      expect(
        SalesDatabaseRepository.gerarNomeArquivoRenomeado('ven268.db', dt),
        'ven268.2025-03-07 14-08-02',
      );

      expect(
        SalesDatabaseRepository.gerarNomeArquivoRenomeado('ven268.db.tmp', dt),
        'ven268.2025-03-07 14-08-02',
      );
    });
  });

  group('Item 3: Botão Voltar e PopScope nas Configurações', () {
    testWidgets('ConfiguracaoPage possui botão de voltar na AppBar e PopScope ativo', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: const ConfiguracaoPageWidget(),
          routes: {
            HomePageWidget.routePath: (ctx) => const Scaffold(body: Text('HomePage')),
          },
        ),
      );
      await tester.pump();

      // Verifica presença de PopScope
      final popScopeFinder = find.byWidgetPredicate((w) => w is PopScope);
      expect(popScopeFinder, findsOneWidget);
      final popScope = tester.widget<PopScope>(popScopeFinder);
      expect(popScope.canPop, isFalse);

      // Verifica presença do botão voltar na AppBar
      final backButtonFinder = find.byTooltip('Voltar ao Menu Principal');
      expect(backButtonFinder, findsOneWidget);
    });

    testWidgets('Tocar no botão Voltar da ConfiguracaoPage notifica NavBarService para HomePage', (tester) async {
      NavBarService().navegarParaConfiguracao();
      expect(NavBarService().currentTab, NavBarService.configuracaoTab);

      await tester.pumpWidget(
        const MaterialApp(
          home: ConfiguracaoPageWidget(),
        ),
      );
      await tester.pump();

      final backButtonFinder = find.byTooltip('Voltar ao Menu Principal');
      await tester.tap(backButtonFinder);
      await tester.pumpAndSettle();

      expect(NavBarService().currentTab, NavBarService.homeTab);
    });

    testWidgets('NavBarPage alterna da tab ConfiguracaoPage para HomePage ao tocar no botão voltar', (tester) async {
      await tester.pumpWidget(
        ChangeNotifierProvider<AppState>(
          create: (_) => AppState(),
          child: const MaterialApp(
            home: NavBarPage(initialPage: 'ConfiguracaoPage'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Confirma que está exibindo a AppBar de Configurações
      expect(find.text('Configurações'), findsOneWidget);

      // Toca no botão voltar da AppBar de Configurações
      final backButtonFinder = find.byTooltip('Voltar ao Menu Principal');
      expect(backButtonFinder, findsOneWidget);
      await tester.tap(backButtonFinder);
      await tester.pumpAndSettle();

      // Verifica que agora está na tela Home (Painel Administrativo)
      expect(find.text('Painel Administrativo'), findsOneWidget);
      expect(NavBarService().currentTab, NavBarService.homeTab);
    });
  });
}
