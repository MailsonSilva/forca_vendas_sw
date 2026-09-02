import 'package:flutter_test/flutter_test.dart';
import 'package:forca_de_vendas/services/conta_corrente_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Database db;

  setUp(() async {
    db = await databaseFactory.openDatabase(inMemoryDatabasePath);

    // Cria as tabelas de conta corrente
    await db.execute('''
      CREATE TABLE fincaidat00 (
        dat00_dattim TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE fincaiccv01 (
        ccv01_codfil INTEGER,
        ccv01_codven INTEGER,
        ccv01_vlrsal REAL DEFAULT 0,
        ccv01_vlrusedig REAL DEFAULT 0,
        ccv01_vlrusepck REAL DEFAULT 0,
        ccv01_vlrsalatu REAL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE fincaimovccv00 (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        ccv00_codfil INTEGER,
        ccv00_codven INTEGER,
        ccv00_datmov TEXT,
        ccv00_typmov TEXT,
        ccv00_vlrmov REAL DEFAULT 0,
        ccv00_vlrsal REAL DEFAULT 0,
        ccv00_observ TEXT
      )
    ''');
  });

  tearDown(() async {
    await db.close();
  });

  group('ContaCorrenteService - Regras e Fórmulas de Negócio', () {
    test('Cálculo do CCV unitário do item: venda com desconto gera débito (negativo)', () {
      // Preço Tabela = 50.00, Preço Praticado = 45.00, Quantidade = 10
      // Diferença = 45.00 - 50.00 = -5.00
      // CCV Item = -5.00 * 10 = -50.00
      final ccv = ContaCorrenteService.calcularItemCcv(
        precoPraticado: 45.00,
        precoTabela: 50.00,
        quantidade: 10.0,
      );

      expect(ccv, equals(-50.00));
    });

    test('Cálculo do CCV unitário do item: venda acima da tabela gera crédito (positivo)', () {
      // Preço Tabela = 50.00, Preço Praticado = 55.00, Quantidade = 4
      // Diferença = 55.00 - 50.00 = +5.00
      // CCV Item = +5.00 * 4 = +20.00
      final ccv = ContaCorrenteService.calcularItemCcv(
        precoPraticado: 55.00,
        precoTabela: 50.00,
        quantidade: 4.0,
      );

      expect(ccv, equals(20.00));
    });

    test('Cálculo do CCV do pedido: soma o saldo de todos os itens do carrinho', () {
      final itens = [
        {'preco_praticado': 40.0, 'preco_tabela': 50.0, 'quantidade': 2.0}, // -20.0
        {'preco_praticado': 60.0, 'preco_tabela': 50.0, 'quantidade': 1.0}, // +10.0
        {'preco_praticado': 100.0, 'preco_tabela': 100.0, 'quantidade': 5.0}, // 0.0
      ];

      final totalCcv = ContaCorrenteService.calcularPedidoCcv(itens);
      expect(totalCcv, equals(-10.0));
    });

    test('Validação de Limite Flex no Checkout: permite se saldoAtual + ccvPedido >= 0', () {
      // Saldo disponível = 50.00, Desconto do pedido = -30.00 -> Restante 20.00 >= 0 -> PERMITIDO
      final valido1 = ContaCorrenteService.validarSaldoCcv(
        saldoAtual: 50.00,
        ccvPedido: -30.00,
      );
      expect(valido1, isTrue);

      // Saldo disponível = 20.00, Desconto do pedido = -20.00 -> Restante 0.00 >= 0 -> PERMITIDO
      final valido2 = ContaCorrenteService.validarSaldoCcv(
        saldoAtual: 20.00,
        ccvPedido: -20.00,
      );
      expect(valido2, isTrue);

      // Saldo disponível = 10.00, Desconto do pedido = -25.00 -> Restante -15.00 < 0 -> BLOQUEADO
      final valido3 = ContaCorrenteService.validarSaldoCcv(
        saldoAtual: 10.00,
        ccvPedido: -25.00,
      );
      expect(valido3, isFalse);
    });
  });

  group('ContaCorrenteService - Persistência e Consultas SQLite', () {
    test('obterSaldoConsolidado retorna dados de saldo consolidado e data de sincronização', () async {
      await db.insert('fincaidat00', {'dat00_dattim': '02/09/2026 09:30'});
      await db.insert('fincaiccv01', {
        'ccv01_codfil': 1,
        'ccv01_codven': 71,
        'ccv01_vlrsal': 150.00,
        'ccv01_vlrusedig': -30.00,
        'ccv01_vlrusepck': -10.00,
        'ccv01_vlrsalatu': 110.00,
      });

      final saldo = await ContaCorrenteService.obterSaldoConsolidado(
        codVen: 71,
        codFil: 1,
        customDb: db,
      );

      expect(saldo.codFil, equals(1));
      expect(saldo.codVen, equals(71));
      expect(saldo.saldoBase, equals(150.00));
      expect(saldo.saldoEmDigitacao, equals(-30.00));
      expect(saldo.saldoEmTransito, equals(-10.00));
      expect(saldo.saldoDisponivel, equals(110.00));
      expect(saldo.dataSincronizacao, equals('02/09/2026 09:30'));
      expect(saldo.isPositivo, isTrue);
    });

    test('obterMovimentacoes retorna lançamentos com suporte a filtros e busca', () async {
      await ContaCorrenteService.registrarMovimentacao(
        codFil: 1,
        codVen: 71,
        dataMovimento: '2026-09-01',
        tipoMovimento: 'C',
        valorMovimento: 50.00,
        saldoAcumulado: 150.00,
        observacao: 'Comissão adicional bonificada',
        customDb: db,
      );

      await ContaCorrenteService.registrarMovimentacao(
        codFil: 1,
        codVen: 71,
        dataMovimento: '2026-09-02',
        tipoMovimento: 'D',
        valorMovimento: 40.00,
        saldoAcumulado: 110.00,
        observacao: 'Desconto concedido Pedido #1007',
        customDb: db,
      );

      // Todos os lançamentos
      final todas = await ContaCorrenteService.obterMovimentacoes(
        codVen: 71,
        codFil: 1,
        customDb: db,
      );
      expect(todas.length, equals(2));

      // Filtro por Crédito
      final creditos = await ContaCorrenteService.obterMovimentacoes(
        codVen: 71,
        codFil: 1,
        filtroTipo: 'C',
        customDb: db,
      );
      expect(creditos.length, equals(1));
      expect(creditos.first.tipoMovimento, equals('C'));
      expect(creditos.first.isCredito, isTrue);

      // Filtro por Débito
      final debitos = await ContaCorrenteService.obterMovimentacoes(
        codVen: 71,
        codFil: 1,
        filtroTipo: 'D',
        customDb: db,
      );
      expect(debitos.length, equals(1));
      expect(debitos.first.tipoMovimento, equals('D'));
      expect(debitos.first.isDebito, isTrue);

      // Busca por observação
      final busca = await ContaCorrenteService.obterMovimentacoes(
        codVen: 71,
        codFil: 1,
        busca: 'Pedido #1007',
        customDb: db,
      );
      expect(busca.length, equals(1));
      expect(busca.first.observacao, contains('Pedido #1007'));
    });
  });
}
