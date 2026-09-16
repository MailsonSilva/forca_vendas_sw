import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:forca_de_vendas/app_state.dart';
import 'package:forca_de_vendas/core/formatters/currency_formatter.dart';
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
        // dup00_codcli como TEXT para testar coerção CAST(... AS INTEGER)
        await d.execute('''
          CREATE TABLE dup00 (
            dup00_codigo TEXT,
            dup00_codcli TEXT,
            dup00_numero TEXT,
            dup00_datemi TEXT,
            dup00_datven TEXT,
            dup00_valori REAL,
            dup00_valdev REAL,
            dup00_valpag REAL,
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

  group('SPEC-043: Query SQL e Regras de Negócio de Títulos', () {
    test('carregarTitulosCliente busca com sucesso quando dup00_codcli é TEXT via CAST', () async {
      final hoje = DateTime(2026, 9, 16);

      // Inserir título para cliente 48785 como TEXT
      await db.insert('dup00', {
        'dup00_codigo': '2098/2',
        'dup00_codcli': '48785', // TEXT
        'dup00_numero': '2098/2',
        'dup00_datemi': '2026-07-01',
        'dup00_datven': '2026-08-01', // Vencido
        'dup00_valori': 500.0,
        'dup00_valdev': 500.0,
        'dup00_valpag': 0.0,
        'dup00_codven': 1,
        'dup00_codagt': 2,
        'dup00_codcob': 1,
      });

      final titulos = await ReceberDuplicatasService.carregarTitulosCliente(
        48785, // Passando int
        dbOverride: db,
        hojeRef: hoje,
        taxaJurosOverride: 0.1,
      );

      expect(titulos.length, equals(1));
      expect(titulos.first.numeroDocumento, equals('2098/2'));
      expect(titulos.first.isVencido, isTrue);
      expect(titulos.first.diasAtraso, equals(46));
      expect(titulos.first.valorJuros, greaterThan(0.0));
    });

    test('carregarTitulosCliente carrega títulos vencidos e a vencer com saldo > 0', () async {
      final hoje = DateTime(2026, 9, 16);

      // Título 1: Vencido
      await db.insert('dup00', {
        'dup00_codigo': '101',
        'dup00_codcli': '48785',
        'dup00_numero': '101',
        'dup00_datemi': '2026-08-01',
        'dup00_datven': '2026-09-01', // Vencido há 15 dias
        'dup00_valori': 1000.0,
        'dup00_valdev': 1000.0,
        'dup00_valpag': 0.0,
      });

      // Título 2: A vencer (vincendo)
      await db.insert('dup00', {
        'dup00_codigo': '102',
        'dup00_codcli': '48785',
        'dup00_numero': '102',
        'dup00_datemi': '2026-09-01',
        'dup00_datven': '2026-10-01', // A vencer no futuro
        'dup00_valori': 800.0,
        'dup00_valdev': 800.0,
        'dup00_valpag': 0.0,
      });

      // Título 3: Quitado (valdev = 0) -> Deve ser ignorado
      await db.insert('dup00', {
        'dup00_codigo': '103',
        'dup00_codcli': '48785',
        'dup00_numero': '103',
        'dup00_datemi': '2026-07-01',
        'dup00_datven': '2026-08-01',
        'dup00_valori': 600.0,
        'dup00_valdev': 0.0,
        'dup00_valpag': 600.0,
      });

      final titulos = await ReceberDuplicatasService.carregarTitulosCliente(
        48785,
        dbOverride: db,
        hojeRef: hoje,
        taxaJurosOverride: 0.1,
      );

      // Deve carregar exatamente os 2 títulos com saldo devedor > 0
      expect(titulos.length, equals(2));

      final vencido = titulos.firstWhere((t) => t.numeroDocumento == '101');
      expect(vencido.isVencido, isTrue);
      expect(vencido.diasAtraso, equals(15));
      expect(vencido.valorJuros, equals(15.0)); // 1000 * 0.001 * 15 = 15.0

      final aVencer = titulos.firstWhere((t) => t.numeroDocumento == '102');
      expect(aVencer.isVencido, isFalse);
      expect(aVencer.diasAtraso, equals(0));
      expect(aVencer.valorJuros, equals(0.0));
    });

    test('SPEC-044: carregarTitulosCliente retorna os 11 títulos do cliente 48785', () async {
      final hoje = DateTime(2026, 9, 16);

      // Inserir 11 títulos todos com saldo devedor > 0
      for (int i = 1; i <= 11; i++) {
        final isVencido = i <= 5;
        await db.insert('dup00', {
          'dup00_codigo': 'T-$i',
          'dup00_codcli': '48785',
          'dup00_numero': 'T-$i',
          'dup00_datemi': '2026-07-01',
          'dup00_datven': isVencido ? '2026-08-0$i' : '2026-10-0$i',
          'dup00_valori': 500.0 + i * 10,
          'dup00_valdev': 500.0 + i * 10,
          'dup00_valpag': 0.0,
          'dup00_codven': 1,
          'dup00_codagt': 1,
          'dup00_codcob': 1,
        });
      }

      final titulos = await ReceberDuplicatasService.carregarTitulosCliente(
        48785,
        dbOverride: db,
        hojeRef: hoje,
        taxaJurosOverride: 0.1,
      );

      // Todos os 11 títulos devem ser carregados (nenhum filtro por vendedor ou data < now)
      expect(titulos.length, equals(11));
      // 5 vencidos + 6 a vencer
      expect(titulos.where((t) => t.isVencido).length, equals(5));
      expect(titulos.where((t) => !t.isVencido).length, equals(6));
    });

    test('SPEC-044: carregarTitulosCliente funciona quando coluna é dup00_clicod (COALESCE)', () async {
      // Criar um banco com dup00_clicod ao invés de dup00_codcli
      final dbClicod = await openDatabase(
        inMemoryDatabasePath,
        version: 1,
        singleInstance: false,
        onCreate: (d, v) async {
          await d.execute('''
            CREATE TABLE dup00 (
              dup00_codigo TEXT,
              dup00_clicod TEXT,
              dup00_numero TEXT,
              dup00_datemi TEXT,
              dup00_datven TEXT,
              dup00_valori REAL,
              dup00_valdev REAL,
              dup00_valpag REAL,
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
        },
      );


      try {
        final hoje = DateTime(2026, 9, 16);

        // Inserir 3 títulos usando dup00_clicod
        for (int i = 1; i <= 3; i++) {
          await dbClicod.insert('dup00', {
            'dup00_codigo': 'CL-$i',
            'dup00_clicod': '48785',
            'dup00_numero': 'CL-$i',
            'dup00_datemi': '2026-07-01',
            'dup00_datven': '2026-08-01',
            'dup00_valori': 300.0,
            'dup00_valdev': 300.0,
            'dup00_valpag': 0.0,
            'dup00_codven': 1,
            'dup00_codagt': 1,
            'dup00_codcob': 1,
          });
        }

        final titulos = await ReceberDuplicatasService.carregarTitulosCliente(
          48785,
          dbOverride: dbClicod,
          hojeRef: hoje,
          taxaJurosOverride: 0.1,
        );

        // Deve encontrar os 3 títulos mesmo com dup00_clicod ao invés de dup00_codcli
        expect(titulos.length, equals(3));
        expect(titulos.first.codCli, equals(48785));
      } finally {
        await dbClicod.close();
      }
    });
  });

  group('SPEC-043: ExtratoClientePageWidget UI e Totais', () {
    testWidgets('ExtratoClientePageWidget exibe contador Títulos (11) e totais consolidados na aba Faturamento', (tester) async {
      // Cria 11 títulos para reproduzir o cenário do cliente 48785 da SPEC-043
      final titulos = <TituloDuplicataItem>[];

      // 5 vencidos somando R$ 3.375,70
      final valoresVencidos = [700.0, 800.0, 900.0, 500.0, 475.70];
      for (int i = 0; i < valoresVencidos.length; i++) {
        titulos.add(TituloDuplicataItem(
          codigo: 2000 + i,
          codCli: 48785,
          numeroDocumento: 'VENC-${i + 1}',
          dataEmissao: DateTime(2026, 7, 1),
          dataVencimento: DateTime(2026, 8, 1 + i),
          valorOriginal: valoresVencidos[i],
          valorPago: 0.0,
          saldoDevedor: valoresVencidos[i],
          diasAtraso: 30 - i,
          isVencido: true,
          valorJuros: 10.0 + i,
          totalComJuros: valoresVencidos[i] + 10.0 + i,
          codVen: 1,
          codAgt: 1,
          codCob: 1,
        ));
      }

      // 6 a vencer somando R$ 2.565,22 (Total Devedor = 3.375,70 + 2.565,22 = 5.940,92)
      final valoresAVencer = [500.0, 500.0, 500.0, 500.0, 500.0, 65.22];
      for (int i = 0; i < valoresAVencer.length; i++) {
        titulos.add(TituloDuplicataItem(
          codigo: 3000 + i,
          codCli: 48785,
          numeroDocumento: 'VINC-${i + 1}',
          dataEmissao: DateTime(2026, 9, 1),
          dataVencimento: DateTime(2026, 10, 1 + i),
          valorOriginal: valoresAVencer[i],
          valorPago: 0.0,
          saldoDevedor: valoresAVencer[i],
          diasAtraso: 0,
          isVencido: false,
          valorJuros: 0.0,
          totalComJuros: valoresAVencer[i],
          codVen: 1,
          codAgt: 1,
          codCob: 1,
        ));
      }

      final cliente = ClienteReceberItem(
        codCli: 48785,
        razaoSocial: 'MERCADO CENTRAL 48785 LTDA',
        fantasia: 'MERCADO CENTRAL',
        cidadeUf: 'Caruaru - PE',
        limiteCredito: 7000.0,
        limiteAtual: 1190.12,
        totalVencido: 3375.70,
        totalAVencer: 2565.22,
        totalDevedor: 5940.92,
        totalJuros: 60.0,
        maiorDiasAtraso: 30,
        qtdTitulosVencidos: 5,
        qtdTitulosTotal: 11,
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

      // 1. Aba superior deve exibir Títulos (11)
      expect(find.text('Títulos (11)'), findsOneWidget);

      // 2. Alternar para a Aba Títulos
      await tester.tap(find.text('Títulos (11)'));
      await tester.pumpAndSettle();

      // Deve exibir os títulos na lista, incluindo vincendos
      expect(find.text('Documento: VENC-1'), findsOneWidget);
      expect(find.text('Documento: VINC-1'), findsOneWidget);

      // 3. Título vencido deve ter indicador de Vencido
      expect(find.text('Vencido'), findsWidgets);

      // 4. Alternar para a Aba Faturamento (Resumo & Totais)
      await tester.tap(find.text('Faturamento'));
      await tester.pumpAndSettle();

      // 5. Card de Totais consolidados
      expect(find.text(3375.70.toMoeda()), findsWidgets);
      expect(find.text(5940.92.toMoeda()), findsWidgets);
    });

    testWidgets('ExtratoClientePageWidget com modoBloqueio exibe botão Liberar Pedido e retorna true ao tocar', (tester) async {
      final titulos = [
        TituloDuplicataItem(
          codigo: 1,
          codCli: 48785,
          numeroDocumento: '19994/1',
          dataEmissao: DateTime(2026, 7, 9),
          dataVencimento: DateTime(2026, 8, 9),
          valorOriginal: 310.0,
          valorPago: 0.0,
          saldoDevedor: 310.0,
          diasAtraso: 8,
          isVencido: true,
          taxaJurosDiaria: 0.20,
          valorJuros: 4.96,
          totalComJuros: 314.96,
        ),
      ];

      final cliente = ClienteReceberItem(
        codCli: 48785,
        razaoSocial: 'A W A ROCHA',
        fantasia: 'AE RASTREIO MOTO PECAS',
        cidadeUf: 'Recife - PE',
        limiteCredito: 1000.0,
        limiteAtual: 314.96,
        totalVencido: 310.0,
        totalAVencer: 0.0,
        totalDevedor: 314.96,
        totalJuros: 4.96,
        maiorDiasAtraso: 8,
        qtdTitulosVencidos: 1,
        qtdTitulosTotal: 1,
        titulos: titulos,
      );

      bool? resultadoRetorno;
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) {
            return ElevatedButton(
              onPressed: () async {
                resultadoRetorno = await ExtratoClientePageWidget.show(
                  context,
                  cliente: cliente,
                  modoBloqueio: true,
                );
              },
              child: const Text('Abrir'),
            );
          },
        ),
      ));

      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();

      // Botão "Liberar Pedido" deve estar visível
      expect(find.text('Liberar Pedido'), findsOneWidget);

      // Alternar para aba Faturamento
      await tester.tap(find.text('Faturamento'));
      await tester.pumpAndSettle();

      // Verificar layout estruturado de Faturamento
      expect(find.text('TÍTULO: '), findsOneWidget);
      expect(find.text('19994/1'), findsOneWidget);
      expect(find.text('EMISSÃO'), findsOneWidget);
      expect(find.text('VENCIMENTO'), findsOneWidget);
      expect(find.text('SALDO DEVEDOR:'), findsOneWidget);
      expect(find.text('Tot.Vencido'), findsOneWidget);
      expect(find.text('Total Juros'), findsOneWidget);
      expect(find.text('Dias/Atraso'), findsOneWidget);
      expect(find.text('Valor Devedor'), findsOneWidget);

      // Tocar em "Liberar Pedido"
      await tester.tap(find.text('Liberar Pedido'));
      await tester.pumpAndSettle();

      // Deve ter fechado o Extrato e retornado true
      expect(resultadoRetorno, isTrue);
    });
  });

  group('SPEC-045: Tabela Física finrecdup00 e Parsing de Datas Brasileiras', () {
    test('carregarTitulosCliente e listarClientesComDebito encontram finrecdup00 e apuram 11 títulos do cliente 48785', () async {
      final dbFinrec = await openDatabase(
        inMemoryDatabasePath,
        singleInstance: false,
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

      final hoje = DateTime(2026, 9, 16);

      // Inserir 5 títulos vencidos somando R$ 3.375,70 (datas no formato brasileiro DD/MM/AAAA)
      final vencidosValores = [1000.0, 800.0, 700.0, 500.0, 375.70];
      for (int i = 0; i < vencidosValores.length; i++) {
        await dbFinrec.insert('finrecdup00', {
          'dup00_codigo': '209$i/1',
          'dup00_codcli': '48785',
          'dup00_numero': '209$i/1',
          'dup00_datemi': '01/06/2026',
          'dup00_datven': '0${i + 1}/08/2026', // Formato brasileiro DD/MM/AAAA vencido
          'dup00_valori': vencidosValores[i],
          'dup00_valdev': vencidosValores[i],
          'dup00_valpag': 0.0,
          'dup00_codven': 1,
          'dup00_codagt': 2,
          'dup00_codcob': 1,
        });
      }

      // Inserir 6 títulos a vencer somando R$ 2.565,22 (Total 3.375,70 + 2.565,22 = 5.940,92)
      final aVencerValores = [500.0, 500.0, 500.0, 500.0, 500.0, 65.22];
      for (int i = 0; i < aVencerValores.length; i++) {
        await dbFinrec.insert('finrecdup00', {
          'dup00_codigo': '309$i/1',
          'dup00_codcli': '48785',
          'dup00_numero': '309$i/1',
          'dup00_datemi': '01/09/2026',
          'dup00_datven': '${17 + i}/09/2026', // Formato brasileiro DD/MM/AAAA a vencer
          'dup00_valori': aVencerValores[i],
          'dup00_valdev': aVencerValores[i],
          'dup00_valpag': 0.0,
          'dup00_codven': 1,
          'dup00_codagt': 2,
          'dup00_codcob': 1,
        });
      }

      // 1. carregarTitulosCliente apura os 11 títulos da finrecdup00
      final titulos = await ReceberDuplicatasService.carregarTitulosCliente(
        48785,
        dbOverride: dbFinrec,
        hojeRef: hoje,
        taxaJurosOverride: 0.1,
      );

      expect(titulos.length, 11);

      final titulosVencidos = titulos.where((t) => t.isVencido).toList();
      final titulosAVencer = titulos.where((t) => !t.isVencido).toList();

      expect(titulosVencidos.length, 5);
      expect(titulosAVencer.length, 6);

      final totalVencido = titulosVencidos.fold<double>(0.0, (acc, t) => acc + t.saldoDevedor);
      final totalDevedorGeral = titulos.fold<double>(0.0, (acc, t) => acc + t.saldoDevedor);

      expect(totalVencido, closeTo(3375.70, 0.01));
      expect(totalDevedorGeral, closeTo(5940.92, 0.01));

      // 2. listarClientesComDebito com finrecdup00
      await dbFinrec.insert('cadcli00', {
        'cli00_codigo': '48785',
        'cli00_descri': 'MERCADO CENTRAL 48785 LTDA',
        'cli00_fantas': 'MERCADO CENTRAL',
      });

      final clientesDebito = await ReceberDuplicatasService.listarClientesComDebito(
        dbOverride: dbFinrec,
        hojeRef: hoje,
      );

      expect(clientesDebito.length, 1);
      expect(clientesDebito.first.codCli, 48785);
      expect(clientesDebito.first.qtdTitulosTotal, 11);
      expect(clientesDebito.first.qtdTitulosVencidos, 5);
      expect(clientesDebito.first.totalVencido, closeTo(3375.70, 0.01));
      expect(clientesDebito.first.totalDevedor, closeTo(5940.92, 0.01));

      await dbFinrec.close();
    });
  });
}
