import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:forca_de_vendas/app_state.dart';
import 'package:forca_de_vendas/components/modal_selecao_filial/modal_selecao_filial_widget.dart';
import 'package:forca_de_vendas/action_code/contar_filiais.dart';
import 'package:forca_de_vendas/pages/configuracao_page/configuracao_page_widget.dart';
import 'package:forca_de_vendas/services/carga_database_service.dart';
import 'package:forca_de_vendas/services/estoque_filial_service.dart';
import 'package:forca_de_vendas/services/filial_service.dart';
import 'package:forca_de_vendas/services/sequence_generator_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Regra 1: Sequencial de Pacote (pckvenpac00 / 1000..9999 e vínculo)', () {
    late Database db;

    setUp(() async {
      db = await databaseFactory.openDatabase(inMemoryDatabasePath);
      await db.execute('''
        CREATE TABLE pckvenpac00 (
          pac00_pacrep INTEGER,
          pac00_paccod INTEGER,
          pac00_pacsrc TEXT PRIMARY KEY,
          pac00_pacdat TEXT,
          pac00_pacqtd INTEGER DEFAULT 0,
          pac00_pactot REAL DEFAULT 0,
          pac00_sttpac INTEGER DEFAULT 0,
          pac00_sttenv INTEGER DEFAULT 0
        );
      ''');
      await db.execute('''
        CREATE TABLE pckvendig00 (
          dig00_digcod INTEGER PRIMARY KEY,
          dig00_paccod INTEGER,
          dig00_pacstr TEXT,
          dig00_sttenv INTEGER DEFAULT 0,
          dig00_datenv TEXT
        );
      ''');
    });

    tearDown(() async {
      await db.close();
    });

    test('Sequencial de pacote: se < 1000 ou >= 9999 retorna 1000; caso contrário max + 1', () async {
      final service = SequenceGeneratorService(db);
      
      // Base vazia -> 1000
      expect(await service.obterProximoCodigoPacote(71), 1000);

      // max < 1000 (ex: 999) -> 1000
      await db.insert('pckvenpac00', {
        'pac00_pacrep': 71,
        'pac00_paccod': 999,
        'pac00_pacsrc': 'p71-999.pac',
      });
      expect(await service.obterProximoCodigoPacote(71), 1000);

      // max = 1000 -> 1001
      await db.insert('pckvenpac00', {
        'pac00_pacrep': 71,
        'pac00_paccod': 1000,
        'pac00_pacsrc': 'p71-1000.pac',
      });
      expect(await service.obterProximoCodigoPacote(71), 1001);

      // max = 9999 -> rollover para 1000
      await db.insert('pckvenpac00', {
        'pac00_pacrep': 71,
        'pac00_paccod': 9999,
        'pac00_pacsrc': 'p71-9999.pac',
      });
      expect(await service.obterProximoCodigoPacote(71), 1000);
    });

    test('Registra lote em pckvenpac00 e atualiza pedidos vinculados com dig00_paccod', () async {
      await db.insert('pckvendig00', {
        'dig00_digcod': 101,
        'dig00_paccod': 0,
        'dig00_pacstr': '',
        'dig00_sttenv': 0,
      });

      final service = SequenceGeneratorService(db);
      await service.registrarPacoteEPedidos(
        codigoVendedor: 71,
        ipac: 1000,
        pedidosIds: [101],
        totalValorLote: 250.0,
      );

      final pacRows = await db.query('pckvenpac00', where: 'pac00_paccod = ?', whereArgs: [1000]);
      expect(pacRows.isNotEmpty, isTrue);
      expect(pacRows.first['pac00_pacsrc'], 'p71-1000.pac');
      expect(pacRows.first['pac00_pacqtd'], 1);

      final pedRows = await db.query('pckvendig00', where: 'dig00_digcod = ?', whereArgs: [101]);
      expect(pedRows.first['dig00_paccod'], 1000);
      expect(pedRows.first['dig00_pacstr'], 'p71-1000');
      expect(pedRows.first['dig00_sttenv'], 2);
    });
  });

  group('Regra 2: Baixa de Estoque Local na Criação do Pedido', () {
    late Database db;

    setUp(() async {
      db = await databaseFactory.openDatabase(inMemoryDatabasePath);
      await db.execute('''
        CREATE TABLE estpro00 (
          pro00_codfil INTEGER,
          pro00_codpro TEXT,
          pro00_qtdest REAL DEFAULT 0,
          pro00_qtdpen REAL DEFAULT 0,
          PRIMARY KEY (pro00_codfil, pro00_codpro)
        );
      ''');
      await db.execute('''
        CREATE TABLE cadpro00 (
          pro00_codigo TEXT PRIMARY KEY,
          pro00_qtdest REAL DEFAULT 0
        );
      ''');

      // Produto 'PRD01': estoque 10.0 na filial 1 e 5.0 na filial 2
      await db.insert('estpro00', {
        'pro00_codfil': 1,
        'pro00_codpro': 'PRD01',
        'pro00_qtdest': 10.0,
        'pro00_qtdpen': 0.0,
      });
      await db.insert('estpro00', {
        'pro00_codfil': 2,
        'pro00_codpro': 'PRD01',
        'pro00_qtdest': 5.0,
        'pro00_qtdpen': 0.0,
      });
      await db.insert('cadpro00', {
        'pro00_codigo': 'PRD01',
        'pro00_qtdest': 15.0,
      });
    });

    tearDown(() async {
      await db.close();
    });

    test('Baixa estoque em estpro00 por filial e cadpro00, garantindo MAX(0.0, est - qtd)', () async {
      await EstoqueFilialService.baixarEstoquePedido(
        db: db,
        codFil: 1,
        itens: const [
          ItemBaixaEstoque(codPro: 'PRD01', quantidade: 4.0),
        ],
      );

      final rEst1 = await db.query('estpro00', where: 'pro00_codpro = ? AND pro00_codfil = ?', whereArgs: ['PRD01', 1]);
      expect(rEst1.first['pro00_qtdest'], 6.0);

      final rEst2 = await db.query('estpro00', where: 'pro00_codpro = ? AND pro00_codfil = ?', whereArgs: ['PRD01', 2]);
      expect(rEst2.first['pro00_qtdest'], 5.0); // Filial 2 inalterada

      final rCad = await db.query('cadpro00', where: 'pro00_codigo = ?', whereArgs: ['PRD01']);
      expect(rCad.first['pro00_qtdest'], 11.0); // 15 - 4
    });

    test('Garante que estoque não fica negativo se pedido for maior que saldo', () async {
      await EstoqueFilialService.baixarEstoquePedido(
        db: db,
        codFil: 1,
        itens: const [
          ItemBaixaEstoque(codPro: 'PRD01', quantidade: 20.0),
        ],
      );

      final rEst1 = await db.query('estpro00', where: 'pro00_codpro = ? AND pro00_codfil = ?', whereArgs: ['PRD01', 1]);
      expect(rEst1.first['pro00_qtdest'], 0.0);

      final rCad = await db.query('cadpro00', where: 'pro00_codigo = ?', whereArgs: ['PRD01']);
      expect(rCad.first['pro00_qtdest'], 0.0);
    });
  });

  group('Regra 3: Descrição da Filial no Modal e Fallbacks', () {
    late Database db;

    setUp(() async {
      db = await databaseFactory.openDatabase(inMemoryDatabasePath);
      await db.execute('''
        CREATE TABLE cadfil00 (
          fil00_codigo INTEGER,
          fil00_descri TEXT
        );
      ''');
      await db.execute('''
        CREATE TABLE cadace00 (
          srv00_descri TEXT
        );
      ''');
      await db.execute('''
        CREATE TABLE cadrep00 (
          ven00_empresa TEXT
        );
      ''');
    });

    tearDown(() async {
      await db.close();
    });

    test('Obtém filiais com COALESCE(fil00_descri, "Filial " || fil00_codigo)', () async {
      await db.insert('cadfil00', {'fil00_codigo': 1, 'fil00_descri': 'Matriz Centro'});
      await db.insert('cadfil00', {'fil00_codigo': 2, 'fil00_descri': null});

      final filiais = await FilialService.obterFiliaisComDescricaoQuery(db, ['1', '2']);
      expect(filiais.length, 2);
      expect(filiais.firstWhere((f) => f.codigo == '1').descricao, 'Matriz Centro');
      expect(filiais.firstWhere((f) => f.codigo == '2').descricao, 'Filial 2');
    });

    test('Fallback para cadace00 ou cadrep00 se cadfil00 não tiver descrição', () async {
      await db.insert('cadace00', {'srv00_descri': 'Empresa Diniz Suporte'});

      final filiais = await FilialService.obterFiliaisComDescricaoQuery(db, ['1']);
      expect(filiais.length, 1);
      expect(filiais.first.descricao, 'Empresa Diniz Suporte');
    });

    testWidgets('ModalSelecaoFilialWidget renderiza title com codigo - descricao e subtitle de ativa', (tester) async {
      AppState.reset();
      AppState().codFilialAtiva = 1;

      final filiais = [
        FilialInfo(codigo: '1', descricao: 'Matriz / Depósito'),
        FilialInfo(codigo: '2', descricao: 'Filial Litoral'),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ModalSelecaoFilialWidget(filiais: filiais),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('1 - Matriz / Depósito'), findsOneWidget);
      expect(find.text('2 - Filial Litoral'), findsOneWidget);
      expect(find.textContaining('Filial ativa na sessão atual'), findsOneWidget);
    });
  });

  group('Regra 4: Sequencial da Versão na Carga e em Configurações', () {
    late Database db;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      AppState.reset();
      await AppState().initializePersistedState();

      db = await databaseFactory.openDatabase(inMemoryDatabasePath);
      await db.execute('''
        CREATE TABLE cadcfg00 (
          cfg00_numcar INTEGER,
          cfg00_datcar TEXT,
          cfg00_versis TEXT
        );
      ''');
    });

    tearDown(() async {
      await db.close();
    });

    test('Salva versao_carga_sistema em SharedPreferences após leitura de cadcfg00', () async {
      await db.insert('cadcfg00', {
        'cfg00_numcar': 120,
        'cfg00_datcar': '2026-09-28',
        'cfg00_versis': 'v4.1.5',
      });

      final service = CargaDatabaseService();
      await service.processarCamposCarga(db: db);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('versao_carga_sistema'), 'v4.1.5');
      expect(AppState().versaoSistema, 'v4.1.5');
    });

    testWidgets('ConfiguracaoPageWidget exibe item Versão do Sistema (Carga) na seção Sobre o Sistema', (tester) async {
      SharedPreferences.setMockInitialValues({
        'versao_carga_sistema': 'v4.1.5',
      });
      AppState.reset();
      AppState().versaoSistema = 'v4.1.5';
      await AppState().initializePersistedState();

      await tester.pumpWidget(
        const MaterialApp(
          home: ConfiguracaoPageWidget(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Sobre o Sistema'), findsOneWidget);
      expect(find.text('Versão do Sistema (Carga)'), findsOneWidget);
      expect(find.text('v4.1.5'), findsOneWidget);
    });
  });
}
