import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:forca_de_vendas/action_code/carregar_pedido_resumo.dart';
import 'package:forca_de_vendas/action_code/contar_filiais.dart';
import 'package:forca_de_vendas/data/repositories/sales_database_repository.dart';
import 'package:forca_de_vendas/services/estoque_filial_service.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('SPEC-047 Seam 3: Renomeação Remota no Servidor FTP pós-download de carga', () {
    test('formata o novo nome removendo a extensão e adicionando o sufixo _YYYYMMDD_HHmmss', () {
      final dt1 = DateTime(2026, 9, 17, 9, 22, 47);
      expect(
        SalesDatabaseRepository.gerarNomeArquivoRenomeadoIso('carga_105.db', dt1),
        'carga_105_20260917_092247',
      );

      final dt2 = DateTime(2025, 3, 7, 14, 8, 2);
      expect(
        SalesDatabaseRepository.gerarNomeArquivoRenomeadoIso('ven105.crg', dt2),
        'ven105_20250307_140802',
      );

      final dt3 = DateTime(2026, 1, 5, 4, 3, 9);
      expect(
        SalesDatabaseRepository.gerarNomeArquivoRenomeadoIso('dbforcacad001.sqlite', dt3),
        'dbforcacad001_20260105_040309',
      );
    });
  });

  group('SPEC-047 Seam 2: Estoque Dinâmico por Filial e Validação de Venda Negativa', () {
    late Database db;
    late EstoqueFilialService estoqueService;

    setUp(() async {
      db = await databaseFactory.openDatabase(inMemoryDatabasePath);
      estoqueService = EstoqueFilialService(database: db);

      await db.execute('''
        CREATE TABLE cadpro00 (
          pro00_codigo INTEGER PRIMARY KEY,
          pro00_descri TEXT,
          pro00_qtdest REAL DEFAULT 0,
          pro00_unidad TEXT,
          pro00_codbar TEXT
        )
      ''');

      await db.execute('''
        CREATE TABLE estpro00 (
          pro00_codfil INTEGER,
          pro00_codpro TEXT,
          pro00_qtdest REAL DEFAULT 0,
          pro00_qtdpen REAL DEFAULT 0,
          PRIMARY KEY (pro00_codfil, pro00_codpro)
        )
      ''');

      // Produto 101: cadpro00 tem 50.0, mas estpro00 tem 15.0 na filial 1 e 30.0 na filial 2
      await db.insert('cadpro00', {
        'pro00_codigo': 101,
        'pro00_descri': 'PRODUTO TESTE MULTIFILIAL',
        'pro00_qtdest': 50.0,
        'pro00_unidad': 'CX',
        'pro00_codbar': '7891000101',
      });
      await db.insert('estpro00', {
        'pro00_codfil': 1,
        'pro00_codpro': '101',
        'pro00_qtdest': 15.0,
        'pro00_qtdpen': 0.0,
      });
      await db.insert('estpro00', {
        'pro00_codfil': 2,
        'pro00_codpro': '101',
        'pro00_qtdest': 30.0,
        'pro00_qtdpen': 0.0,
      });

      // Produto 202: existe apenas em cadpro00 com 42.0 (sem registro em estpro00)
      await db.insert('cadpro00', {
        'pro00_codigo': 202,
        'pro00_descri': 'PRODUTO APENAS CADPRO',
        'pro00_qtdest': 42.0,
        'pro00_unidad': 'UN',
        'pro00_codbar': '7891000202',
      });
    });

    tearDown(() async {
      await db.close();
    });

    test('retorna estoque particionado por filial ativa a partir de estpro00', () async {
      final estoqueFilial1 = await estoqueService.obterEstoqueDisponivel(
        codigoProduto: 101,
        filialAtiva: 1,
      );
      expect(estoqueFilial1, 15.0);

      final estoqueFilial2 = await estoqueService.obterEstoqueDisponivel(
        codigoProduto: 101,
        filialAtiva: 2,
      );
      expect(estoqueFilial2, 30.0);
    });

    test('faz fallback para cadpro00 quando produto nao possui linha na filial em estpro00', () async {
      final estoqueFilial1 = await estoqueService.obterEstoqueDisponivel(
        codigoProduto: 202,
        filialAtiva: 1,
      );
      expect(estoqueFilial1, 42.0);

      final estoqueFilial3 = await estoqueService.obterEstoqueDisponivel(
        codigoProduto: 202,
        filialAtiva: 3,
      );
      expect(estoqueFilial3, 42.0);
    });

    test('retorna 0.0 quando o produto nao existe em nenhuma tabela', () async {
      final estoqueInexistente = await estoqueService.obterEstoqueDisponivel(
        codigoProduto: 9999,
        filialAtiva: 1,
      );
      expect(estoqueInexistente, 0.0);
    });

    test('valida venda negativa bloqueando se ven00_estneg == false e liberando se ven00_estneg == true', () {
      // Bloqueio de venda negativa (ven00_estneg == false):
      expect(
        estoqueService.validarVendaEstoque(
          quantidadeDigitada: 10.0,
          estoqueDisponivel: 15.0,
          permiteVendaNegativa: false,
        ),
        isTrue,
      );
      expect(
        estoqueService.validarVendaEstoque(
          quantidadeDigitada: 15.0,
          estoqueDisponivel: 15.0,
          permiteVendaNegativa: false,
        ),
        isTrue,
      );
      expect(
        estoqueService.validarVendaEstoque(
          quantidadeDigitada: 16.0,
          estoqueDisponivel: 15.0,
          permiteVendaNegativa: false,
        ),
        isFalse,
      );

      // Permissão de venda negativa (ven00_estneg == true):
      expect(
        estoqueService.validarVendaEstoque(
          quantidadeDigitada: 50.0,
          estoqueDisponivel: 15.0,
          permiteVendaNegativa: true,
        ),
        isTrue,
      );
    });
  });

  group('SPEC-047 Seam 1: Gestão Multi-Filial e Seleção no Login', () {
    late Database db;

    setUp(() async {
      db = await databaseFactory.openDatabase(inMemoryDatabasePath);
      await db.execute('''
        CREATE TABLE cadfil00 (
          fil00_codigo INTEGER PRIMARY KEY,
          fil00_descri TEXT,
          fil00_active INTEGER DEFAULT 1
        )
      ''');
    });

    tearDown(() async {
      if (db.isOpen) await db.close();
    });

    test('Cenário 1: Filial Única ativa retorna count == 1 para auto-seleção', () async {
      await db.insert('cadfil00', {
        'fil00_codigo': 1,
        'fil00_descri': 'MATRIZ SÃO PAULO',
        'fil00_active': 1,
      });

      final res = await contarFiliais(customDb: db);
      expect(res.count, 1);
      expect(res.filiais.length, 1);
      expect(res.filiais.first.codigo, '1');
      expect(res.filiais.first.descricao, 'MATRIZ SÃO PAULO');
      // Garante que o banco não foi fechado (INVARIANT 1)
      expect(db.isOpen, isTrue);
    });

    test('Cenário 2: Multi-Empresa retorna count > 1 filtrando fil00_active = 1', () async {
      await db.insert('cadfil00', {
        'fil00_codigo': 1,
        'fil00_descri': 'MATRIZ SÃO PAULO',
        'fil00_active': 1,
      });
      await db.insert('cadfil00', {
        'fil00_codigo': 2,
        'fil00_descri': 'FILIAL CAMPINAS',
        'fil00_active': 1,
      });
      await db.insert('cadfil00', {
        'fil00_codigo': 3,
        'fil00_descri': 'FILIAL DESATIVADA',
        'fil00_active': 0, // inativa
      });

      final res = await contarFiliais(customDb: db);
      expect(res.count, 2);
      expect(res.filiais.length, 2);
      expect(res.filiais.map((f) => f.codigo), containsAll(['1', '2']));
      expect(res.filiais.map((f) => f.codigo), isNot(contains('3')));
      expect(db.isOpen, isTrue);
    });
  });

  group('SPEC-047 Seam 4: Carregamento do Resumo do Pedido com 12 Campos Canônicos', () {
    late Database db;

    setUp(() async {
      db = await databaseFactory.openDatabase(inMemoryDatabasePath);
      await db.execute('''
        CREATE TABLE pckvendig000 (
          ped00_numped INTEGER PRIMARY KEY,
          dig00_digcod INTEGER,
          dig00_digfil INTEGER,
          ped00_datsys TEXT,
          dig00_datsys TEXT,
          ped00_codcli INTEGER,
          ped00_clides TEXT,
          dig00_clicod INTEGER,
          ped00_codpla INTEGER,
          ped00_plades TEXT,
          dig00_placod INTEGER,
          ped00_codlin INTEGER,
          ped00_lindes TEXT,
          dig00_lincod INTEGER,
          ped00_codagt INTEGER,
          ped00_digagt INTEGER,
          dig00_digagt INTEGER,
          ped00_qtditm INTEGER,
          dig00_qtditm INTEGER,
          ped00_bontot REAL,
          dig00_bontot REAL,
          ped00_digtot REAL,
          dig00_digtot REAL,
          ped00_subtot REAL,
          dig00_subtot REAL,
          ped00_fattot REAL,
          dig00_fattot REAL,
          ped00_digobs TEXT,
          dig00_digobs TEXT
        )
      ''');

      await db.execute('''
        CREATE TABLE cadagt00 (
          agt00_codigo INTEGER PRIMARY KEY,
          agt00_descri TEXT
        )
      ''');
      await db.insert('cadagt00', {
        'agt00_codigo': 10,
        'agt00_descri': 'BANCO DO BRASIL',
      });

      await db.insert('pckvendig000', {
        'ped00_numped': 1001,
        'dig00_digcod': 1001,
        'dig00_digfil': 1,
        'ped00_datsys': '2026-09-17 09:30:00',
        'dig00_datsys': '2026-09-17 09:30:00',
        'ped00_codcli': 500,
        'ped00_clides': 'MERCADO CENTRAL LTDA',
        'ped00_codpla': 1,
        'ped00_plades': '30/60/90 DIAS',
        'ped00_codlin': 2,
        'ped00_lindes': 'ALIMENTOS',
        'ped00_codagt': 10,
        'ped00_digagt': 10,
        'dig00_digagt': 10,
        'ped00_qtditm': 4,
        'dig00_qtditm': 4,
        'ped00_bontot': 50.0,
        'dig00_bontot': 50.0,
        'ped00_digtot': 1500.0,
        'dig00_digtot': 1500.0,
        'ped00_subtot': 120.0,
        'dig00_subtot': 120.0,
        'ped00_fattot': 1380.0,
        'dig00_fattot': 1380.0,
        'ped00_digobs': 'Entregar após as 14h nos fundos',
        'dig00_digobs': 'Entregar após as 14h nos fundos',
      });
    });

    tearDown(() async {
      if (db.isOpen) await db.close();
    });

    test('carrega os 12 campos canônicos do resumo sem fechar o singleton SQLite', () async {
      final resumo = await carregarPedidoResumo(1001, customDb: db);
      expect(resumo, isNotNull);
      // 1. Número do Pedido (dig00_digcod)
      expect(resumo!.numeroPedido, 1001);
      // 2. Data de Emissão (dig00_datsys)
      expect(resumo.dataEmissao, '2026-09-17 09:30:00');
      // 3. Cliente (dig00_clicod + Razão)
      expect(resumo.clienteCodigo, 500);
      expect(resumo.clienteNome, 'MERCADO CENTRAL LTDA');
      // 4. Plano de Pagamento (dig00_placod + Nome)
      expect(resumo.planoCodigo, '1');
      expect(resumo.planoDescricao, '30/60/90 DIAS');
      // 5. Linha de Produto (dig00_lincod + Nome)
      expect(resumo.linhaCodigo, '2');
      expect(resumo.linhaDescricao, 'ALIMENTOS');
      // 6. Agente Cobrador (dig00_digagt + Nome)
      expect(resumo.agenteCodigo, '10');
      expect(resumo.agenteDescricao, contains('BANCO DO BRASIL'));
      // 7. Qtd de Itens (dig00_qtditm)
      expect(resumo.quantidadeItens, 4);
      // 8. Bônus / Bonificação (dig00_bontot)
      expect(resumo.valorBonus, 50.0);
      // 9. Valor dos Produtos (dig00_digtot)
      expect(resumo.valorProdutos, 1500.0);
      // 10. Substituição Tributária (dig00_subtot)
      expect(resumo.valorSubstituicao, 120.0);
      // 11. Total Faturado/Geral (dig00_fattot)
      expect(resumo.totalFatura, 1380.0);
      // 12. Observação (dig00_digobs)
      expect(resumo.observacao, 'Entregar após as 14h nos fundos');

      // Invariante 1: O banco permanece aberto
      expect(db.isOpen, isTrue);
    });
  });
}
