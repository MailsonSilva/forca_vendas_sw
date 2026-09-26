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

  group('TDD - Ajustes Extrato do Cliente (Cálculos e finrecdup00)', () {
    test('Cálculo de juros dinâmico em atraso e zero para a vencer', () {
      // Regra: juros = dup00_valdev * (ven00_txajur / 100) * dias_atraso
      // Para títulos a vencer: manter 0.00
      const saldo = 1000.0;
      const taxa = 0.1; // 0.1% ao dia
      const diasAtraso = 15;

      final jurosVencido = ReceberDuplicatasService.calcularJurosMora(
        saldoDevedor: saldo,
        taxaJurosDiaria: taxa,
        diasAtraso: diasAtraso,
      );
      // 1000 * 0.001 * 15 = 15.00
      expect(jurosVencido, equals(15.0));

      final jurosAVencer = ReceberDuplicatasService.calcularJurosMora(
        saldoDevedor: saldo,
        taxaJurosDiaria: taxa,
        diasAtraso: 0,
      );
      expect(jurosAVencer, equals(0.0));
    });

    test('carregarTitulosCliente lê finrecdup00 com datas DD/MM/AAAA e AAAA-MM-DD e apura juros e dias', () async {
      final hoje = DateTime(2026, 9, 25);

      await db.insert('cadrep00', {
        'ven00_codigo': 10,
        'ven00_txajur': 0.1, // 0.1%
      });

      // Título 1: Vencido com data brasileira DD/MM/AAAA
      // Vencimento: 15/09/2026 -> 10 dias de atraso em 25/09/2026
      await db.insert('finrecdup00', {
        'dup00_codigo': 'DUP-01',
        'dup00_codcli': '12345',
        'dup00_numero': 'DUP-01',
        'dup00_datemi': '01/08/2026',
        'dup00_datven': '15/09/2026',
        'dup00_valori': 500.0,
        'dup00_valdev': 500.0,
        'dup00_valpag': 0.0,
        'dup00_valjur': 0.0,
        'dup00_codven': 10,
        'dup00_codagt': 1,
        'dup00_codcob': 1,
      });

      // Título 2: Vencido com data ISO AAAA-MM-DD
      // Vencimento: 2026-09-05 -> 20 dias de atraso em 25/09/2026
      await db.insert('finrecdup00', {
        'dup00_codigo': 'DUP-02',
        'dup00_codcli': '12345',
        'dup00_numero': 'DUP-02',
        'dup00_datemi': '2026-08-01',
        'dup00_datven': '2026-09-05',
        'dup00_valori': 1000.0,
        'dup00_valdev': 1000.0,
        'dup00_valpag': 0.0,
        'dup00_valjur': 0.0,
        'dup00_codven': 10,
        'dup00_codagt': 1,
        'dup00_codcob': 1,
      });

      // Título 3: A vencer com data DD/MM/AAAA
      // Vencimento: 30/09/2026 -> 0 dias de atraso
      await db.insert('finrecdup00', {
        'dup00_codigo': 'DUP-03',
        'dup00_codcli': '12345',
        'dup00_numero': 'DUP-03',
        'dup00_datemi': '01/09/2026',
        'dup00_datven': '30/09/2026',
        'dup00_valori': 800.0,
        'dup00_valdev': 800.0,
        'dup00_valpag': 0.0,
        'dup00_valjur': 0.0,
        'dup00_codven': 10,
        'dup00_codagt': 1,
        'dup00_codcob': 1,
      });

      final titulos = await ReceberDuplicatasService.carregarTitulosCliente(
        12345,
        dbOverride: db,
        hojeRef: hoje,
      );

      expect(titulos.length, equals(3));

      final t1 = titulos.firstWhere((t) => t.numeroDocumento == 'DUP-01');
      expect(t1.isVencido, isTrue);
      expect(t1.diasAtraso, equals(10));
      // 500 * (0.1/100) * 10 = 5.0
      expect(t1.valorJuros, equals(5.0));

      final t2 = titulos.firstWhere((t) => t.numeroDocumento == 'DUP-02');
      expect(t2.isVencido, isTrue);
      expect(t2.diasAtraso, equals(20));
      // 1000 * (0.1/100) * 20 = 20.0
      expect(t2.valorJuros, equals(20.0));

      final t3 = titulos.firstWhere((t) => t.numeroDocumento == 'DUP-03');
      expect(t3.isVencido, isFalse);
      expect(t3.diasAtraso, equals(0));
      expect(t3.valorJuros, equals(0.0));
    });
  });

  group('TDD - Widget ExtratoClientePageWidget (Abas, Totais e Dias de Atraso)', () {
    testWidgets('Abre por padrão na aba Vencidos, exibe dias acumulados e oculta totais na aba Todos', (tester) async {
      final titulos = <TituloDuplicataItem>[
        // Título vencido 1: 15 dias de atraso, juros 15.00, saldo 500.00
        TituloDuplicataItem(
          codigo: 101,
          codCli: 999,
          numeroDocumento: 'DUP-VENC-1',
          dataEmissao: DateTime(2026, 8, 1),
          dataVencimento: DateTime(2026, 9, 10),
          valorOriginal: 500.0,
          valorPago: 0.0,
          saldoDevedor: 500.0,
          diasAtraso: 15,
          isVencido: true,
          valorJuros: 15.0,
          totalComJuros: 515.0,
          taxaJurosDiaria: 0.2,
        ),
        // Título vencido 2: 25 dias de atraso, juros 50.00, saldo 1000.00
        TituloDuplicataItem(
          codigo: 102,
          codCli: 999,
          numeroDocumento: 'DUP-VENC-2',
          dataEmissao: DateTime(2026, 7, 1),
          dataVencimento: DateTime(2026, 8, 31),
          valorOriginal: 1000.0,
          valorPago: 0.0,
          saldoDevedor: 1000.0,
          diasAtraso: 25,
          isVencido: true,
          valorJuros: 50.0,
          totalComJuros: 1050.0,
          taxaJurosDiaria: 0.2,
        ),
        // Título a vencer: 0 dias atraso, saldo 700.00
        TituloDuplicataItem(
          codigo: 103,
          codCli: 999,
          numeroDocumento: 'DUP-AVENC-1',
          dataEmissao: DateTime(2026, 9, 1),
          dataVencimento: DateTime(2026, 10, 15),
          valorOriginal: 700.0,
          valorPago: 0.0,
          saldoDevedor: 700.0,
          diasAtraso: 0,
          isVencido: false,
          valorJuros: 0.0,
          totalComJuros: 700.0,
        ),
      ];

      final cliente = ClienteReceberItem(
        codCli: 999,
        razaoSocial: 'CLIENTE TESTE TDD LTDA',
        fantasia: 'TESTE TDD',
        cidadeUf: 'Recife - PE',
        limiteCredito: 5000.0,
        limiteAtual: 2200.0,
        totalVencido: 1500.0,
        totalAVencer: 700.0,
        totalDevedor: 2200.0,
        totalJuros: 65.0, // 15 + 50
        maiorDiasAtraso: 25,
        qtdTitulosVencidos: 2,
        qtdTitulosTotal: 3,
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

      // 1. ABA PADRÃO E RENOMEAÇÃO DE ABAS:
      // A segunda aba chama-se 'Vencidos (2)' e a terceira 'Todos (3)'
      expect(find.text('Vencidos (2)'), findsOneWidget);
      expect(find.text('Todos (3)'), findsOneWidget);

      // Como a segunda aba (índice 1) deve ser a padrão (initialIndex: 1),
      // a tela já abre exibindo a lista de vencidos!
      expect(find.text('Título: DUP-VENC-1'), findsOneWidget);
      expect(find.text('Título: DUP-VENC-2'), findsOneWidget);
      // E NÃO exibe o título a vencer na aba Vencidos
      expect(find.text('Título: DUP-AVENC-1'), findsNothing);

      // 2. CAMPO DE JUROS:
      // Verifica exibição do campo de Juros nos cards
      expect(find.textContaining('Juros:'), findsWidgets);

      // 3. QUADRO SUPERIOR DE RESUMO:
      // Deve exibir "Dias de atraso" e o total acumulado: 15 + 25 = 40 dias (em vez de apenas 25)
      expect(find.text('Dias de atraso'), findsOneWidget);
      expect(find.text('40 dias'), findsOneWidget);
      // Resumo exibe total de juros (apenas no resumo superior, pois quadro inferior foi removido)
      expect(find.text('Total Juros'), findsOneWidget);

      // 4. QUADRO INFERIOR DE TOTAIS E CONTAINER DE INADIMPLÊNCIA NA ABA VENCIDOS:
      // Quadro inferior foi removido
      expect(find.text('Tot.Vencido'), findsNothing);
      // Badge continua único no header do cliente (o da aba foi removido)
      expect(find.text('Inadimplência Ativa'), findsOneWidget);

      // 5. NAVEGAÇÃO PARA A ABA "TODOS":
      await tester.tap(find.text('Todos (3)'));
      await tester.pumpAndSettle();

      // Na aba Todos, deve exibir todos os títulos
      expect(find.text('Título: DUP-VENC-1'), findsOneWidget);
      expect(find.text('Título: DUP-VENC-2'), findsOneWidget);
      expect(find.text('Título: DUP-AVENC-1'), findsOneWidget);

      // E na aba Todos: quadro inferior removido e badge único no header do cliente
      expect(find.text('Tot.Vencido'), findsNothing);
      expect(find.text('Inadimplência Ativa'), findsOneWidget);
    });
  });
}
