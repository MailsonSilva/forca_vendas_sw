import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:forca_de_vendas/services/receber_duplicatas_service.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('ReceberDuplicatasService - Cálculos Puros', () {
    test('calcularDiasAtraso calcula corretamente títulos vencidos e a vencer', () {
      final hoje = DateTime(2026, 9, 2);

      // Título vencido há 10 dias
      final v1 = DateTime(2026, 8, 23);
      expect(ReceberDuplicatasService.calcularDiasAtraso(v1, hoje: hoje), 10);

      // Título vencendo hoje
      final v2 = DateTime(2026, 9, 2);
      expect(ReceberDuplicatasService.calcularDiasAtraso(v2, hoje: hoje), 0);

      // Título vencendo no futuro
      final v3 = DateTime(2026, 9, 15);
      expect(ReceberDuplicatasService.calcularDiasAtraso(v3, hoje: hoje), 0);
    });

    test('calcularJurosMora aplica taxa diária do representante de forma ponderada', () {
      // Saldo R$ 1.000,00, Taxa 0,05% ao dia, 20 dias de atraso
      // Juros = 1000 * (0.05 / 100) * 20 = 10.00
      final juros = ReceberDuplicatasService.calcularJurosMora(
        saldoDevedor: 1000.0,
        taxaJurosDiaria: 0.05,
        diasAtraso: 20,
      );
      expect(juros, 10.0);

      // Se a taxa for 0 ou nula, juros devem ser estritamente 0.00
      final jurosZero = ReceberDuplicatasService.calcularJurosMora(
        saldoDevedor: 1000.0,
        taxaJurosDiaria: 0.0,
        diasAtraso: 20,
      );
      expect(jurosZero, 0.0);

      // Se não houver atraso, juros devem ser 0.00
      final jurosSemAtraso = ReceberDuplicatasService.calcularJurosMora(
        saldoDevedor: 1000.0,
        taxaJurosDiaria: 0.1,
        diasAtraso: 0,
      );
      expect(jurosSemAtraso, 0.0);
    });

    test('parseData reconhece formatos múltiplos de datas', () {
      final dt1 = ReceberDuplicatasService.parseData('2026-08-15');
      expect(dt1, DateTime(2026, 8, 15));

      final dt2 = ReceberDuplicatasService.parseData('15/08/2026');
      expect(dt2, DateTime(2026, 8, 15));

      final dt3 = ReceberDuplicatasService.parseData('20260815');
      expect(dt3, DateTime(2026, 8, 15));

      final dtNull = ReceberDuplicatasService.parseData('');
      expect(dtNull, isNull);
    });

    test('gerarTextoCobrancaAmigavel formata extrato com clareza para WhatsApp', () {
      final cliente = ClienteReceberItem(
        codCli: 101,
        razaoSocial: 'SUPERMERCADO BOA VISTA LTDA',
        fantasia: 'BOA VISTA',
        cidadeUf: 'Recife - PE',
        limiteCredito: 5000.0,
        limiteAtual: 4200.0,
        totalVencido: 350.0,
        totalAVencer: 450.0,
        totalDevedor: 800.0,
        totalJuros: 15.0,
        maiorDiasAtraso: 18,
        qtdTitulosVencidos: 1,
        qtdTitulosTotal: 2,
        titulos: [
          TituloDuplicataItem(
            codigo: 1,
            codCli: 101,
            numeroDocumento: 'DUP-1001',
            dataEmissao: DateTime(2026, 8, 1),
            dataVencimento: DateTime(2026, 8, 15),
            valorOriginal: 350.0,
            valorPago: 0.0,
            saldoDevedor: 350.0,
            diasAtraso: 18,
            isVencido: true,
            taxaJurosDiaria: 0.1,
            valorJuros: 15.0,
            totalComJuros: 365.0,
          ),
          TituloDuplicataItem(
            codigo: 2,
            codCli: 101,
            numeroDocumento: 'DUP-1002',
            dataEmissao: DateTime(2026, 8, 20),
            dataVencimento: DateTime(2026, 9, 20),
            valorOriginal: 450.0,
            valorPago: 0.0,
            saldoDevedor: 450.0,
            diasAtraso: 0,
            isVencido: false,
            totalComJuros: 450.0,
          ),
        ],
      );

      final texto = ReceberDuplicatasService.gerarTextoCobrancaAmigavel(
        cliente,
        nomeVendedor: 'Vendedor Teste',
      );

      expect(texto, contains('SUPERMERCADO BOA VISTA LTDA'));
      expect(texto, contains('DUP-1001'));
      expect(texto, contains('18 dias em atraso'));
      expect(texto, contains('Total Vencido:'));
      expect(texto, contains('Valor do Juros:'));
      expect(texto, contains('15,00'));
      expect(texto, contains('Total A Vencer:'));
    });
  });

  group('ReceberDuplicatasService - Consultas SQLite Integradas', () {
    late String testDbPath;
    late Database db;

    setUp(() async {
      final tempDir = await Directory.systemTemp.createTemp('receber_test_');
      testDbPath = p.join(tempDir.path, 'test_receber.db');
      db = await openDatabase(testDbPath, version: 1, onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE cadrep00 (
            ven00_codigo INTEGER PRIMARY KEY,
            ven00_txajur REAL DEFAULT 0
          )
        ''');

        await db.execute('''
          CREATE TABLE cadcli00 (
            cli00_codigo INTEGER PRIMARY KEY,
            cli00_descri TEXT,
            cli00_fantas TEXT,
            cli00_ciddes TEXT,
            cli00_estsgl TEXT,
            cli00_crelim REAL DEFAULT 0,
            cli00_creatu REAL DEFAULT 0
          )
        ''');

        await db.execute('''
          CREATE TABLE dup00 (
            dup00_codigo INTEGER PRIMARY KEY,
            dup00_codcli INTEGER,
            dup00_datemi TEXT,
            dup00_datven TEXT,
            dup00_valori REAL DEFAULT 0,
            dup00_valdev REAL DEFAULT 0,
            dup00_valpag REAL DEFAULT 0,
            dup00_codven INTEGER,
            dup00_codagt INTEGER,
            dup00_codcob INTEGER
          )
        ''');
      });

      // Inserir representante com taxa 0.05% ao dia
      await db.insert('cadrep00', {'ven00_codigo': 10, 'ven00_txajur': 0.05});

      // Inserir clientes
      await db.insert('cadcli00', {
        'cli00_codigo': 1,
        'cli00_descri': 'MERCADO CENTRAL LTDA',
        'cli00_fantas': 'MERCADO CENTRAL',
        'cli00_ciddes': 'Recife',
        'cli00_estsgl': 'PE',
        'cli00_crelim': 5000.0,
        'cli00_creatu': 4500.0,
      });

      await db.insert('cadcli00', {
        'cli00_codigo': 2,
        'cli00_descri': 'PADARIA BOM JESUS',
        'cli00_fantas': 'BOM JESUS',
        'cli00_ciddes': 'Olinda',
        'cli00_estsgl': 'PE',
        'cli00_crelim': 2000.0,
        'cli00_creatu': 1800.0,
      });

      // Inserir duplicatas para Cliente 1 (uma vencida, uma a vencer)
      await db.insert('dup00', {
        'dup00_codigo': 101,
        'dup00_codcli': 1,
        'dup00_datemi': '2026-08-01',
        'dup00_datven': '2026-08-15', // Vencida
        'dup00_valori': 300.0,
        'dup00_valdev': 300.0,
        'dup00_valpag': 0.0,
      });

      await db.insert('dup00', {
        'dup00_codigo': 102,
        'dup00_codcli': 1,
        'dup00_datemi': '2026-08-20',
        'dup00_datven': '2026-09-30', // A vencer
        'dup00_valori': 200.0,
        'dup00_valdev': 200.0,
        'dup00_valpag': 0.0,
      });

      // Inserir duplicata para Cliente 2 (apenas a vencer)
      await db.insert('dup00', {
        'dup00_codigo': 201,
        'dup00_codcli': 2,
        'dup00_datemi': '2026-08-25',
        'dup00_datven': '2026-09-25', // A vencer
        'dup00_valori': 500.0,
        'dup00_valdev': 500.0,
        'dup00_valpag': 0.0,
      });
    });

    tearDown(() async {
      await db.close();
      try {
        await File(testDbPath).delete();
      } catch (_) {}
    });

    test('obterTaxaJurosVendedor busca taxa cadastrada no representante', () async {
      final taxa = await ReceberDuplicatasService.obterTaxaJurosVendedor(
        10,
        dbOverride: db,
      );
      expect(taxa, 0.05);

      final taxaInexistente = await ReceberDuplicatasService.obterTaxaJurosVendedor(
        999,
        dbOverride: db,
      );
      expect(taxaInexistente, 0.0);
    });

    test('carregarTitulosCliente retorna duplicatas processadas com juros e dias de atraso', () async {
      final hoje = DateTime(2026, 9, 2);
      final titulos = await ReceberDuplicatasService.carregarTitulosCliente(
        1,
        taxaJurosOverride: 0.05,
        dbOverride: db,
        hojeRef: hoje,
      );

      expect(titulos.length, 2);

      final tVencido = titulos.firstWhere((t) => t.isVencido);
      expect(tVencido.codigo, 101);
      expect(tVencido.diasAtraso, 18);
      // 300 * (0.05 / 100) * 18 = 2.70
      expect(tVencido.valorJuros, 2.70);
      expect(tVencido.totalComJuros, 302.70);

      final tAVencer = titulos.firstWhere((t) => !t.isVencido);
      expect(tAVencer.codigo, 102);
      expect(tAVencer.diasAtraso, 0);
      expect(tAVencer.valorJuros, 0.0);
    });

    test('listarClientesComDebito aplica filtros de inadimplência corretamente', () async {
      final hoje = DateTime(2026, 9, 2);

      // Filtro: Todos
      final todos = await ReceberDuplicatasService.listarClientesComDebito(
        filtro: FiltroReceber.todos,
        taxaJurosOverride: 0.05,
        dbOverride: db,
        hojeRef: hoje,
      );
      expect(todos.length, 2);

      // Filtro: Apenas Vencidos (deve retornar apenas o Cliente 1)
      final apenasVencidos = await ReceberDuplicatasService.listarClientesComDebito(
        filtro: FiltroReceber.apenasVencidos,
        taxaJurosOverride: 0.05,
        dbOverride: db,
        hojeRef: hoje,
      );
      expect(apenasVencidos.length, 1);
      expect(apenasVencidos.first.codCli, 1);

      // Filtro: A Vencer (deve retornar apenas clientes sem vencidos ativos)
      final aVencer = await ReceberDuplicatasService.listarClientesComDebito(
        filtro: FiltroReceber.aVencer,
        taxaJurosOverride: 0.05,
        dbOverride: db,
        hojeRef: hoje,
      );
      expect(aVencer.length, 1);
      expect(aVencer.first.codCli, 2);
    });

    test('listarClientesComDebito ordena por Maior Tempo de Atraso (Aging)', () async {
      final hoje = DateTime(2026, 9, 2);

      final ordenados = await ReceberDuplicatasService.listarClientesComDebito(
        filtro: FiltroReceber.todos,
        ordenacao: OrdenacaoReceber.maiorAtraso,
        taxaJurosOverride: 0.05,
        dbOverride: db,
        hojeRef: hoje,
      );

      expect(ordenados.first.codCli, 1); // Cliente 1 tem 18 dias de atraso
      expect(ordenados.last.codCli, 2);  // Cliente 2 tem 0 dias de atraso
    });
  });
}
