import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:forca_de_vendas/domain/models/resumo_vendas_model.dart';
import 'package:forca_de_vendas/services/resumo_vendas_service.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Database db;

  setUp(() async {
    db = await databaseFactory.openDatabase(inMemoryDatabasePath);

    // Cria as tabelas do resumo de vendas
    await db.execute('''
      CREATE TABLE cadcli00 (
        cli00_codigo INTEGER PRIMARY KEY,
        cli00_descri TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE cadpro00 (
        pro00_codigo INTEGER PRIMARY KEY,
        pro00_descri TEXT,
        pro00_commax REAL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE pckvendig000 (
        ped00_numped INTEGER PRIMARY KEY,
        ped00_codfil INTEGER,
        ped00_codven INTEGER,
        ped00_codcli INTEGER,
        ped00_datsys TEXT,
        ped00_digtot REAL DEFAULT 0,
        ped00_fattot REAL DEFAULT 0,
        ped00_sttdig INTEGER DEFAULT 0,
        ped00_sttenv INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE pckvendig010 (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        ped10_numped INTEGER,
        ped10_item INTEGER,
        ped10_codpro TEXT,
        ped10_digqtd REAL DEFAULT 0,
        ped10_fatqtd REAL DEFAULT 0,
        ped10_digpco REAL DEFAULT 0,
        ped10_fatpco REAL DEFAULT 0,
        ped10_bontyp INTEGER DEFAULT 0
      )
    ''');
  });

  tearDown(() async {
    await db.close();
  });

  group('ResumoVendasService - Fórmulas e Regras de Negócio (ffrmrelresven00)', () {
    test('Calcula comissão produto a produto respeitando percentuais diferentes por item', () {
      final item1 = ResumoVendasItemComissao.fromMap({
        'ped10_item': 1,
        'ped10_codpro': '101',
        'pro00_descri': 'Produto A (5%)',
        'ped10_fatqtd': 10.0,
        'ped10_fatpco': 100.0, // Total = 1000.0
        'pro00_commax': 5.0, // Comissão = 50.0
        'ped10_bontyp': 0,
      });

      final item2 = ResumoVendasItemComissao.fromMap({
        'ped10_item': 2,
        'ped10_codpro': '102',
        'pro00_descri': 'Produto B (8%)',
        'ped10_fatqtd': 5.0,
        'ped10_fatpco': 200.0, // Total = 1000.0
        'pro00_commax': 8.0, // Comissão = 80.0
        'ped10_bontyp': 0,
      });

      expect(item1.valorItemTotal, equals(1000.0));
      expect(item1.valorComissao, equals(50.0));

      expect(item2.valorItemTotal, equals(1000.0));
      expect(item2.valorComissao, equals(80.0));
    });

    test('Item bonificado (bontyp > 0) possui comissão estritamente zerada', () {
      final itemBonificado = ResumoVendasItemComissao.fromMap({
        'ped10_item': 1,
        'ped10_codpro': '201',
        'pro00_descri': 'Brinde Promocional',
        'ped10_fatqtd': 20.0,
        'ped10_fatpco': 50.0, // Total = 1000.0
        'pro00_commax': 10.0, // Teria 10%, mas é bonificado
        'ped10_bontyp': 1, // Bonificado
      });

      expect(itemBonificado.isBonificado, isTrue);
      expect(itemBonificado.valorComissao, equals(0.0));
    });

    test('Pedido faturado com corte por ruptura apura comissão apenas sobre o faturado real', () {
      // Digitado 10 un, mas faturado apenas 6 un por corte
      final itemCortado = ResumoVendasItemComissao.fromMap({
        'ped10_item': 1,
        'ped10_codpro': '301',
        'pro00_descri': 'Item com corte',
        'ped10_digqtd': 10.0,
        'ped10_fatqtd': 6.0,
        'ped10_fatpco': 100.0, // Total faturado = 600.0
        'pro00_commax': 5.0, // 5% de 600.0 = 30.0
        'ped10_bontyp': 0,
      });

      expect(itemCortado.quantidadeFaturada, equals(6.0));
      expect(itemCortado.valorItemTotal, equals(600.0));
      expect(itemCortado.valorComissao, equals(30.0));
    });
  });

  group('ResumoVendasService - Consultas e Consolidação SQLite por Período', () {
    test('Consolida Venda Bruta, Devoluções/Cortes, Venda Líquida e Comissões do Período', () async {
      // Cadastra Clientes
      await db.insert('cadcli00', {'cli00_codigo': 10, 'cli00_descri': 'Mercado Central'});
      await db.insert('cadcli00', {'cli00_codigo': 20, 'cli00_descri': 'Padaria Estrela'});

      // Cadastra Produtos com comissões de 5% e 10%
      await db.insert('cadpro00', {'pro00_codigo': 101, 'pro00_descri': 'Arroz 5kg', 'pro00_commax': 5.0});
      await db.insert('cadpro00', {'pro00_codigo': 102, 'pro00_descri': 'Feijao 1kg', 'pro00_commax': 10.0});

      // Pedido #1 (01/09/2026): Faturado 100% sem cortes
      // 10 un Arroz a R$ 20,00 = R$ 200,00 (Comissão 5% = R$ 10,00)
      await db.insert('pckvendig000', {
        'ped00_numped': 1,
        'ped00_codfil': 1,
        'ped00_codven': 71,
        'ped00_codcli': 10,
        'ped00_datsys': '2026-09-01',
        'ped00_digtot': 200.0,
        'ped00_fattot': 200.0,
        'ped00_sttenv': 3, // Faturado
      });
      await db.insert('pckvendig010', {
        'ped10_numped': 1,
        'ped10_item': 1,
        'ped10_codpro': '101',
        'ped10_digqtd': 10.0,
        'ped10_fatqtd': 10.0,
        'ped10_digpco': 20.0,
        'ped10_fatpco': 20.0,
        'ped10_bontyp': 0,
      });

      // Pedido #2 (01/09/2026): Faturado parcialmente com corte de R$ 50,00
      // Digitado: 10 Feijão a R$ 10 = R$ 100,00. Faturado: 5 Feijão a R$ 10 = R$ 50,00 (Comissão 10% = R$ 5,00)
      await db.insert('pckvendig000', {
        'ped00_numped': 2,
        'ped00_codfil': 1,
        'ped00_codven': 71,
        'ped00_codcli': 20,
        'ped00_datsys': '2026-09-01',
        'ped00_digtot': 100.0,
        'ped00_fattot': 50.0,
        'ped00_sttenv': 3, // Faturado
      });
      await db.insert('pckvendig010', {
        'ped10_numped': 2,
        'ped10_item': 1,
        'ped10_codpro': '102',
        'ped10_digqtd': 10.0,
        'ped10_fatqtd': 5.0,
        'ped10_digpco': 10.0,
        'ped10_fatpco': 10.0,
        'ped10_bontyp': 0,
      });

      // Pedido #3 (02/09/2026): Rascunho/Trânsito ainda não faturado
      // 5 Arroz a R$ 20 = R$ 100,00 (Comissão prevista 5% = R$ 5,00)
      await db.insert('pckvendig000', {
        'ped00_numped': 3,
        'ped00_codfil': 1,
        'ped00_codven': 71,
        'ped00_codcli': 10,
        'ped00_datsys': '2026-09-02',
        'ped00_digtot': 100.0,
        'ped00_fattot': 0.0,
        'ped00_sttenv': 1, // Em trânsito
      });
      await db.insert('pckvendig010', {
        'ped10_numped': 3,
        'ped10_item': 1,
        'ped10_codpro': '101',
        'ped10_digqtd': 5.0,
        'ped10_fatqtd': 0.0,
        'ped10_digpco': 20.0,
        'ped10_fatpco': 0.0,
        'ped10_bontyp': 0,
      });

      final resumo = await ResumoVendasService.obterResumoVendas(
        dataInicio: DateTime(2026, 9, 1),
        dataFim: DateTime(2026, 9, 2),
        codVen: 71,
        codFil: 1,
        customDb: db,
      );

      // Venda Bruta = 200 + 100 + 100 = 400.0
      expect(resumo.totalVendaBruta, equals(400.0));

      // Devoluções/Cortes = 50.0 (Pedido #2)
      expect(resumo.totalDevolucoes, equals(50.0));

      // Venda Líquida = 400.0 - 50.0 = 350.0 (200 + 50 faturado + 100 previsto)
      expect(resumo.totalVendaLiquida, equals(350.0));

      // Comissão Total = 10 (Ped 1) + 5 (Ped 2) + 5 (Ped 3 previsto) = 20.0
      expect(resumo.totalComissao, equals(20.0));

      // Quantidade total de pedidos = 3
      expect(resumo.totalPedidos, equals(3));
      expect(resumo.dias.length, equals(2)); // 01/09 e 02/09

      // Dia 01/09
      final dia1 = resumo.dias.firstWhere((d) => d.data == '2026-09-01');
      expect(dia1.pedidos.length, equals(2));
      expect(dia1.totalBruto, equals(300.0));
      expect(dia1.totalDevolucoes, equals(50.0));
      expect(dia1.totalLiquido, equals(250.0));
      expect(dia1.totalComissao, equals(15.0));

      // Dia 02/09
      final dia2 = resumo.dias.firstWhere((d) => d.data == '2026-09-02');
      expect(dia2.pedidos.length, equals(1));
      expect(dia2.totalBruto, equals(100.0));
      expect(dia2.totalComissao, equals(5.0));
    });

    test('Gera texto estruturado de compartilhamento para WhatsApp / Clipboard', () {
      final resumo = ResumoVendasConsolidado(
        dataInicio: DateTime(2026, 9, 1),
        dataFim: DateTime(2026, 9, 2),
        totalVendaBruta: 1500.0,
        totalDevolucoes: 200.0,
        totalVendaLiquida: 1300.0,
        totalComissao: 75.50,
        totalPedidos: 5,
        dias: const [],
      );

      final texto = ResumoVendasService.gerarTextoCompartilhamento(resumo, nomeVendedor: 'VENDEDOR TESTE');

      expect(texto, contains('RESUMO DE VENDAS E COMISSÕES'));
      expect(texto, contains('Vendedor: VENDEDOR TESTE'));
      expect(texto, contains('Venda Bruta: R\$ 1.500,00'));
      expect(texto, contains('Devoluções/Cortes: R\$ 200,00'));
      expect(texto, contains('Venda Líquida: R\$ 1.300,00'));
      expect(texto, contains('Comissão Estimada: R\$ 75,50'));
    });
  });
}
