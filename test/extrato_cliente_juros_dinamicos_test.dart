import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:forca_de_vendas/app_state.dart';
import 'package:forca_de_vendas/services/receber_duplicatas_service.dart';
import 'package:forca_de_vendas/pages/cliente/extrato_cliente_page/extrato_cliente_page_widget.dart';

void main() {
  late Database db;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  setUp(() async {
    AppState.reset();
    db = await openDatabase(
      inMemoryDatabasePath,
      version: 1,
      onCreate: (d, v) async {
        await d.execute('''
          CREATE TABLE finrecdup00 (
            dup00_codigo TEXT,
            dup00_codcli TEXT,
            dup00_numero TEXT,
            dup00_datemi TEXT,
            dup00_datven TEXT,
            dup00_valori REAL,
            dup00_valdev REAL,
            dup00_valpag REAL,
            dup00_valjur REAL,
            dup00_codven INTEGER,
            dup00_codagt INTEGER,
            dup00_codcob INTEGER
          )
        ''');

        await d.execute('''
          CREATE TABLE cadrep00 (
            ven00_codigo INTEGER PRIMARY KEY,
            ven00_txajur REAL
          )
        ''');

        await d.execute('''
          CREATE TABLE cadcli00 (
            cli00_codigo TEXT PRIMARY KEY,
            cli00_descri TEXT,
            cli00_fantas TEXT,
            cli00_ciddes TEXT,
            cli00_estsgl TEXT,
            cli00_crelim REAL,
            cli00_creatu REAL
          )
        ''');
      },
    );
  });

  tearDown(() async {
    await db.close();
  });

  Widget createTestableWidget(Widget child) {
    return ChangeNotifierProvider<AppState>.value(
      value: AppState(),
      child: MaterialApp(
        home: Scaffold(body: child),
      ),
    );
  }

  group('REQUISITO 1: Obtenção da taxa de juros do vendedor', () {
    test('Recupera taxa de juros do AppState.vendedorLogado.ven00Txajur', () {
      AppState().ven00Txajur = 0.25;
      expect(AppState().vendedorLogado.ven00Txajur, equals(0.25));
      expect(AppState().ven00_txajur, equals(0.25));
    });

    test('Fallback para 0.0 quando taxa for nula ou não informada', () async {
      AppState().ven00Txajur = 0.0;
      final taxa = await ReceberDuplicatasService.obterTaxaJurosVendedor(
        999,
        dbOverride: db,
      );
      expect(taxa, equals(0.0));
      expect(AppState().vendedorLogado.ven00Txajur, equals(0.0));
    });

    test('Recupera taxa da tabela cadrep00 no SQLite com sucesso', () async {
      await db.insert('cadrep00', {
        'ven00_codigo': 15,
        'ven00_txajur': 0.15,
      });

      final taxa = await ReceberDuplicatasService.obterTaxaJurosVendedor(
        15,
        dbOverride: db,
      );
      expect(taxa, equals(0.15));
    });
  });

  group('REQUISITO 2: Cálculo dinâmico de juros por título (diasAtrasado legado)', () {
    test('Parse seguro de data DD/MM/AAAA e AAAA-MM-DD com ou sem horário', () {
      final d1 = ReceberDuplicatasService.parseData('15/08/2026');
      expect(d1, equals(DateTime(2026, 8, 15)));

      final d2 = ReceberDuplicatasService.parseData('2026-08-15');
      expect(d2, equals(DateTime(2026, 8, 15)));

      final d3 = ReceberDuplicatasService.parseData('15/08/2026 14:35:00');
      expect(d3, equals(DateTime(2026, 8, 15)));

      final d4 = ReceberDuplicatasService.parseData('2026-08-15T18:00:00');
      expect(d4, equals(DateTime(2026, 8, 15)));
    });

    test('diasAtrasado ignora horas e compara apenas datas cheias', () {
      final dtHoje = DateTime(2026, 9, 25, 18, 30);
      final dtVencimento = DateTime(2026, 9, 20, 08, 00);

      final dias = ReceberDuplicatasService.calcularDiasAtraso(dtVencimento, hoje: dtHoje);
      expect(dias, equals(5));

      // Mesmo dia não é atraso
      final mesmoDia = ReceberDuplicatasService.calcularDiasAtraso(
        DateTime(2026, 9, 25, 08, 00),
        hoje: dtHoje,
      );
      expect(mesmoDia, equals(0));

      // Futuro não é atraso
      final futuro = ReceberDuplicatasService.calcularDiasAtraso(
        DateTime(2026, 9, 30, 08, 00),
        hoje: dtHoje,
      );
      expect(futuro, equals(0));
    });

    test('Cálculo de juros por título: saldoDevedor * (taxaRep / 100) * diasAtraso', () {
      const saldo = 1200.0;
      const taxa = 0.1; // 0.1% ao dia
      const dias = 10;

      final juros = ReceberDuplicatasService.calcularJurosMora(
        saldoDevedor: saldo,
        taxaJurosDiaria: taxa,
        diasAtraso: dias,
      );

      // 1200 * (0.1 / 100) * 10 = 12.00
      expect(juros, equals(12.0));

      // Título em dia: 0.0
      final jurosEmDia = ReceberDuplicatasService.calcularJurosMora(
        saldoDevedor: saldo,
        taxaJurosDiaria: taxa,
        diasAtraso: 0,
      );
      expect(jurosEmDia, equals(0.0));
    });

    test('carregarTitulosCliente calcula juros em memória mesmo com dup00_valjur zerado no banco', () async {
      final hoje = DateTime(2026, 9, 25);

      await db.insert('cadrep00', {
        'ven00_codigo': 20,
        'ven00_txajur': 0.2, // 0.2% ao dia
      });

      // Duplicata com dup00_valjur = 0.0 no SQLite
      await db.insert('finrecdup00', {
        'dup00_codigo': 'TIT-001',
        'dup00_codcli': '777',
        'dup00_numero': 'TIT-001',
        'dup00_datemi': '01/08/2026',
        'dup00_datven': '15/09/2026', // 10 dias de atraso em relação a 25/09/2026
        'dup00_valori': 1000.0,
        'dup00_valdev': 1000.0,
        'dup00_valpag': 0.0,
        'dup00_valjur': 0.0, // ZERADO NO BANCO!
        'dup00_codven': 20,
      });

      final titulos = await ReceberDuplicatasService.carregarTitulosCliente(
        777,
        dbOverride: db,
        hojeRef: hoje,
      );

      expect(titulos.length, equals(1));
      final t = titulos.first;
      expect(t.diasAtraso, equals(10));
      expect(t.isVencido, isTrue);
      // 1000 * (0.2 / 100) * 10 = 20.00
      expect(t.valorJuros, equals(20.0));
      expect(t.totalComJuros, equals(1020.0));
    });
  });

  group('REQUISITO 3: Totalizador de Juros e Quadro Inferior (ffrmextractcli00)', () {
    test('Apuração dos totais: vlrTotJuros, vlrTotTitulos e vlrSaldoDevedor', () {
      final t1 = TituloDuplicataItem(
        codigo: 1,
        codCli: 10,
        numeroDocumento: 'DOC-1',
        dataVencimento: DateTime(2026, 9, 10),
        valorOriginal: 500.0,
        valorPago: 100.0,
        saldoDevedor: 400.0,
        diasAtraso: 15,
        isVencido: true,
        valorJuros: 12.0,
        totalComJuros: 412.0,
      );

      final t2 = TituloDuplicataItem(
        codigo: 2,
        codCli: 10,
        numeroDocumento: 'DOC-2',
        dataVencimento: DateTime(2026, 9, 15),
        valorOriginal: 1000.0,
        valorPago: 0.0,
        saldoDevedor: 1000.0,
        diasAtraso: 10,
        isVencido: true,
        valorJuros: 20.0,
        totalComJuros: 1020.0,
      );

      final titulosVencidos = [t1, t2];

      final vlrTotJuros = titulosVencidos.fold<double>(0.0, (acc, t) => acc + t.valorJuros);
      final vlrTotTitulos = titulosVencidos.fold<double>(0.0, (acc, t) => acc + t.valorOriginal);
      final somaSaldoDevedor = titulosVencidos.fold<double>(0.0, (acc, t) => acc + t.saldoDevedor);
      final vlrSaldoDevedor = somaSaldoDevedor + vlrTotJuros;

      expect(vlrTotJuros, equals(32.0));
      expect(vlrTotTitulos, equals(1500.0));
      expect(somaSaldoDevedor, equals(1400.0));
      expect(vlrSaldoDevedor, equals(1432.0));
    });

    testWidgets('Exibe vlrTotJuros formatado no quadro inferior da aba Vencidos sem retornar vazio ou zerado', (tester) async {
      final titulos = <TituloDuplicataItem>[
        TituloDuplicataItem(
          codigo: 1,
          codCli: 888,
          numeroDocumento: 'DUP-VENC-1',
          dataEmissao: DateTime(2026, 8, 1),
          dataVencimento: DateTime(2026, 9, 15),
          valorOriginal: 600.0,
          valorPago: 0.0,
          saldoDevedor: 600.0,
          diasAtraso: 10,
          isVencido: true,
          valorJuros: 18.0,
          totalComJuros: 618.0,
        ),
        TituloDuplicataItem(
          codigo: 2,
          codCli: 888,
          numeroDocumento: 'DUP-VENC-2',
          dataEmissao: DateTime(2026, 8, 1),
          dataVencimento: DateTime(2026, 9, 20),
          valorOriginal: 400.0,
          valorPago: 0.0,
          saldoDevedor: 400.0,
          diasAtraso: 5,
          isVencido: true,
          valorJuros: 6.0,
          totalComJuros: 406.0,
        ),
      ];

      final cliente = ClienteReceberItem(
        codCli: 888,
        razaoSocial: 'CLIENTE TOTALIZADORES TESTE',
        fantasia: 'FANTASIA TOTALIZADORES',
        cidadeUf: 'Recife - PE',
        limiteCredito: 10000.0,
        limiteAtual: 1024.0,
        totalVencido: 1000.0,
        totalAVencer: 0.0,
        totalDevedor: 1024.0,
        totalJuros: 24.0, // 18 + 6
        maiorDiasAtraso: 10,
        qtdTitulosVencidos: 2,
        qtdTitulosTotal: 2,
        titulos: titulos,
      );

      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(createTestableWidget(
        ExtratoClientePageWidget(clienteInicial: cliente),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Aba Vencidos ativa
      expect(find.text('Vencidos (2)'), findsOneWidget);

      // Card do título exibe juros formatado (R$ 18,00 e R$ 6,00)
      expect(find.text('Juros: R\$ 18,00'), findsOneWidget);
      expect(find.text('Juros: R\$ 6,00'), findsOneWidget);

      // Quadro inferior de totais da aba Vencidos foi removido
      expect(find.text('Tot.Vencido'), findsNothing);
      expect(find.text('Inadimplência Ativa'), findsOneWidget);
      // Painel superior de resumo exibe Total Juros e valor acumulado
      expect(find.text('Total Juros'), findsOneWidget);
      expect(find.text('R\$ 24,00'), findsOneWidget);
      expect(find.text('R\$ 1.024,00'), findsWidgets);
      expect(find.text('15 dias'), findsOneWidget); // 10 + 5 dias acumulados no card superior
    });

    testWidgets('Exibe linha Total Juros no painel de resumo mesmo quando o valor for R\$ 0,00', (tester) async {
      final clienteSemJuros = ClienteReceberItem(
        codCli: 777,
        razaoSocial: 'CLIENTE SEM JUROS LTDA',
        fantasia: 'SEM JUROS',
        cidadeUf: 'Recife - PE',
        limiteCredito: 5000.0,
        limiteAtual: 500.0,
        totalVencido: 500.0,
        totalAVencer: 0.0,
        totalDevedor: 500.0,
        totalJuros: 0.0,
        maiorDiasAtraso: 5,
        qtdTitulosVencidos: 1,
        qtdTitulosTotal: 1,
        titulos: [
          TituloDuplicataItem(
            codigo: 1,
            codCli: 777,
            numeroDocumento: 'DUP-ZERADA',
            dataVencimento: DateTime(2026, 9, 20),
            valorOriginal: 500.0,
            valorPago: 0.0,
            saldoDevedor: 500.0,
            diasAtraso: 5,
            isVencido: true,
            valorJuros: 0.0,
            totalComJuros: 500.0,
          ),
        ],
      );

      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(createTestableWidget(
        ExtratoClientePageWidget(clienteInicial: clienteSemJuros),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Deve exibir "Total Juros" no painel de resumo
      expect(find.text('Total Juros'), findsOneWidget);
      expect(find.text('R\$ 0,00'), findsWidgets);
    });
  });
}

