import 'package:flutter_test/flutter_test.dart';
import 'package:forca_de_vendas/action_code/carregar_agentes_cobrador.dart';
import 'package:forca_de_vendas/action_code/concluir_venda_process.dart';
import 'package:forca_de_vendas/action_code/obter_dados_pedido_novo.dart';
import 'package:forca_de_vendas/backend/schema/structs/index.dart';
import 'package:forca_de_vendas/data/services/local_sales_database_service.dart';
import 'package:forca_de_vendas/domain/services/valide_pco_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('Seção 1: Validação de Faixas de Preço e Descontos (ValidePcoService)', () {
    test('validePCOValues valida preço dentro da faixa permitida', () {
      final res = ValidePcoService.validePCOValues(
        pcomin: 10.0,
        pcomax: 20.0,
        commax: 15.0,
        digpco: 15.0,
        destot: 5.0,
        freadpco: true,
        isEdicaoManual: true,
      );
      expect(res.valido, isTrue);
      expect(res.mensagem, isEmpty);
    });

    test('validePCOValues bloqueia preço abaixo do mínimo (pcomin)', () {
      final res = ValidePcoService.validePCOValues(
        pcomin: 10.0,
        pcomax: 20.0,
        commax: 15.0,
        digpco: 8.50,
        destot: 0.0,
        freadpco: true,
        isEdicaoManual: true,
      );
      expect(res.valido, isFalse);
      expect(res.mensagem, contains('Preço digitado abaixo do preço mínimo'));
    });

    test('validePCOValues bloqueia preço acima do máximo (pcomax)', () {
      final res = ValidePcoService.validePCOValues(
        pcomin: 10.0,
        pcomax: 20.0,
        commax: 15.0,
        digpco: 25.00,
        destot: 0.0,
        freadpco: true,
        isEdicaoManual: true,
      );
      expect(res.valido, isFalse);
      expect(res.mensagem, contains('Preço digitado acima do preço máximo'));
    });

    test('validePCOValues bloqueia edição quando representante não tem permissão (freadpco = false)', () {
      final res = ValidePcoService.validePCOValues(
        pcomin: 10.0,
        pcomax: 20.0,
        commax: 15.0,
        digpco: 15.0,
        destot: 0.0,
        freadpco: false,
        isEdicaoManual: true,
      );
      expect(res.valido, isFalse);
      expect(res.mensagem, contains('sem permissão para alteração de preços'));
    });

    test('validePCOValues bloqueia desconto acima do teto (commax)', () {
      final res = ValidePcoService.validePCOValues(
        pcomin: 10.0,
        pcomax: 20.0,
        commax: 10.0,
        digpco: 15.0,
        destot: 12.5,
        freadpco: true,
        isEdicaoManual: true,
      );
      expect(res.valido, isFalse);
      expect(res.mensagem, contains('Desconto excede a flexibilidade permitida'));
    });

    test('obterFaixasPreco busca faixas com hierarquia regional estpcoregpco00 > estpcopro00 > cadpro00', () async {
      final db = await LocalSalesDatabaseService.getDatabase();

      await db.execute('DROP TABLE IF EXISTS estpcoregpco00');
      await db.execute('DROP TABLE IF EXISTS estpcopro00');
      await db.execute('DROP TABLE IF EXISTS cadpro00');

      await db.execute('''
        CREATE TABLE estpcoregpco00 (
          pco00_codpro INTEGER,
          pco00_codtab INTEGER,
          pco00_codreg INTEGER,
          pco00_pcomin REAL,
          pco00_pcomax REAL
        )
      ''');
      await db.execute('''
        CREATE TABLE estpcopro00 (
          pro00_codpro INTEGER,
          pro00_codtab INTEGER,
          pro00_pcosub REAL,
          pro00_pcomin REAL,
          pro00_pcomax REAL,
          pro00_commax REAL
        )
      ''');
      await db.execute('''
        CREATE TABLE cadpro00 (
          pro00_codigo INTEGER PRIMARY KEY,
          pro00_descri TEXT,
          pro00_pcosub REAL,
          pro00_pcomin REAL,
          pro00_pcomax REAL,
          pro00_commax REAL,
          pro00_freadpco INTEGER DEFAULT 1
        )
      ''');

      // Produto 101 tem regra regional (estpcoregpco00)
      await db.insert('estpcoregpco00', {
        'pco00_codpro': 101,
        'pco00_codtab': 1,
        'pco00_codreg': 5,
        'pco00_pcomin': 12.0,
        'pco00_pcomax': 18.0,
      });

      // Produto 102 tem regra de tabela de preço (estpcopro00)
      await db.insert('estpcopro00', {
        'pro00_codpro': 102,
        'pro00_codtab': 1,
        'pro00_pcosub': 50.0,
        'pro00_pcomin': 45.0,
        'pro00_pcomax': 55.0,
        'pro00_commax': 10.0,
      });

      // Produto 103 tem apenas cadastro base (cadpro00)
      await db.insert('cadpro00', {
        'pro00_codigo': 103,
        'pro00_descri': 'PRODUTO TESTE BASE',
        'pro00_pcosub': 100.0,
        'pro00_pcomin': 90.0,
        'pro00_pcomax': 110.0,
        'pro00_commax': 5.0,
        'pro00_freadpco': 1,
      });

      final f1 = await ValidePcoService.obterFaixasPreco('101', codTabela: 1, codRegiao: 5);
      expect(f1.pcomin, equals(12.0));
      expect(f1.pcomax, equals(18.0));
      expect(f1.tabelaOrigem, equals('estpcoregpco00'));

      final f2 = await ValidePcoService.obterFaixasPreco('102', codTabela: 1);
      expect(f2.pcomin, equals(45.0));
      expect(f2.pcomax, equals(55.0));
      expect(f2.tabelaOrigem, equals('estpcopro00'));

      final f3 = await ValidePcoService.obterFaixasPreco('103');
      expect(f3.pcomin, equals(90.0));
      expect(f3.pcomax, equals(110.0));
      expect(f3.tabelaOrigem, equals('cadpro00'));
    });
  });

  group('Seção 2: Filtragem Cruzada de Planos de Pagamento e Valor Mínimo', () {
    test('carregarPlanosDisponiveisCliente filtra apenas planos com cobradores autorizados via cadcliage00 e cadprz02', () async {
      final db = await LocalSalesDatabaseService.getDatabase();

      await db.execute('DROP TABLE IF EXISTS cadcli00');
      await db.execute('DROP TABLE IF EXISTS cadcliage00');
      await db.execute('DROP TABLE IF EXISTS cadprz02');
      await db.execute('DROP TABLE IF EXISTS cadprz00');
      await db.execute('DROP TABLE IF EXISTS cadpla00');

      await db.execute('''
        CREATE TABLE cadcli00 (
          cli00_codigo INTEGER PRIMARY KEY,
          cli00_descri TEXT,
          cli00_codcls INTEGER,
          cli00_codscl INTEGER,
          cli00_codmod INTEGER,
          cli00_codreg INTEGER,
          cli00_codtyp INTEGER
        )
      ''');
      await db.execute('''
        CREATE TABLE cadpla00 (
          pla00_codigo INTEGER PRIMARY KEY,
          pla00_descri TEXT,
          pla00_codseq INTEGER,
          pla00_vlrmin REAL DEFAULT 0,
          pla00_codcls INTEGER DEFAULT 0,
          pla00_codscl INTEGER DEFAULT 0,
          pla00_codmod INTEGER DEFAULT 0,
          pla00_codreg INTEGER DEFAULT 0,
          pla00_codtyp INTEGER DEFAULT 0
        )
      ''');
      await db.execute('''
        CREATE TABLE cadcliage00 (
          age00_codcli INTEGER,
          age00_codage INTEGER
        )
      ''');
      await db.execute('''
        CREATE TABLE cadprz02 (
          prz02_codcls INTEGER DEFAULT 0,
          prz02_codscl INTEGER DEFAULT 0,
          prz02_codprz INTEGER,
          prz02_codagt INTEGER
        )
      ''');

      // Cliente 500: vinculado exclusivamente ao agente 10
      await db.insert('cadcli00', {
        'cli00_codigo': 500,
        'cli00_descri': 'CLIENTE TESTE FILTRAGEM',
      });
      await db.insert('cadcliage00', {'age00_codcli': 500, 'age00_codage': 10});

      // Plano 1 (À Vista): autorizado para agente 10
      await db.insert('cadpla00', {
        'pla00_codigo': 1,
        'pla00_descri': 'A VISTA 10',
        'pla00_codseq': 1,
        'pla00_vlrmin': 50.0,
      });
      await db.insert('cadprz02', {'prz02_codprz': 1, 'prz02_codagt': 10});

      // Plano 2 (30 Dias): autorizado APENAS para agente 20 (cliente 500 NÃO tem)
      await db.insert('cadpla00', {
        'pla00_codigo': 2,
        'pla00_descri': '30 DIAS BOLETO 20',
        'pla00_codseq': 2,
        'pla00_vlrmin': 200.0,
      });
      await db.insert('cadprz02', {'prz02_codprz': 2, 'prz02_codagt': 20});

      final planos = await carregarPlanosDisponiveisCliente(clienteCodigo: 500);

      expect(planos.length, equals(1));
      expect(planos.first.codigo, equals('1'));
      expect(planos.first.descricao, equals('A VISTA 10'));
      expect(planos.first.vlrmin, equals(50.0));
    });

    test('concluirVendaProcess bloqueia encerramento se total do pedido for inferior a pla00_vlrmin', () async {
      final db = await LocalSalesDatabaseService.getDatabase();

      await db.execute('DROP TABLE IF EXISTS cadpla00');
      await db.execute('''
        CREATE TABLE cadpla00 (
          pla00_codigo INTEGER PRIMARY KEY,
          pla00_descri TEXT,
          pla00_vlrmin REAL DEFAULT 0
        )
      ''');
      await db.insert('cadpla00', {
        'pla00_codigo': 99,
        'pla00_descri': 'PLANO MINIMO ALTO',
        'pla00_vlrmin': 300.0,
      });

      final itens = [
        ItemPedidoStruct(
          codigoProduto: '101',
          descricao: 'PRODUTO PEQUENO',
          unidade: 'UN',
          precoUnitario: 50.0,
          quantidade: 2.0,
          totalItem: 100.0,
        ),
      ];

      expect(
        () async => await concluirVendaProcess(
          pedidoId: 9901,
          clienteCodigo: 500,
          linhaCodigo: '1',
          planoCodigo: '99',
          carrinhoItens: itens,
          codAgenteCobrador: 10,
        ),
        throwsA(predicate((e) => e.toString().contains('inferior ao valor mínimo exigido'))),
      );
    });
  });

  group('Seção 2.4: Filtragem Estrita de Agentes Cobradores (cadcliage00 ∩ cadprz02)', () {
    test('carregarAgentesCobrador retorna apenas a intersecção autorizada para cliente e plano', () async {
      final db = await LocalSalesDatabaseService.getDatabase();

      await db.execute('DROP TABLE IF EXISTS cadage00');
      await db.execute('DROP TABLE IF EXISTS cadcliage00');
      await db.execute('DROP TABLE IF EXISTS cadprz02');

      await db.execute('''
        CREATE TABLE cadage00 (
          age00_codigo INTEGER PRIMARY KEY,
          age00_descri TEXT
        )
      ''');
      await db.execute('''
        CREATE TABLE cadcliage00 (
          age00_codcli INTEGER,
          age00_codage INTEGER
        )
      ''');
      await db.execute('''
        CREATE TABLE cadprz02 (
          prz02_codprz INTEGER,
          prz02_codagt INTEGER
        )
      ''');

      // Agentes no catálogo
      await db.insert('cadage00', {'age00_codigo': 10, 'age00_descri': 'BANCO DO BRASIL'});
      await db.insert('cadage00', {'age00_codigo': 20, 'age00_descri': 'ITAU UNIBANCO'});
      await db.insert('cadage00', {'age00_codigo': 30, 'age00_descri': 'CARTEIRA VENDEDOR'});

      // Cliente 600 tem homologados BB (10) e ITAU (20)
      await db.insert('cadcliage00', {'age00_codcli': 600, 'age00_codage': 10});
      await db.insert('cadcliage00', {'age00_codcli': 600, 'age00_codage': 20});

      // Plano 5 (Cartão/Boleto) homologado apenas para ITAU (20) e CARTEIRA (30)
      await db.insert('cadprz02', {'prz02_codprz': 5, 'prz02_codagt': 20});
      await db.insert('cadprz02', {'prz02_codprz': 5, 'prz02_codagt': 30});

      // Intersecção: [10, 20] ∩ [20, 30] = [20] (ITAU UNIBANCO)
      final agentes = await carregarAgentesCobrador(
        clienteCodigo: 600,
        planoCodigo: 5,
      );

      expect(agentes.length, equals(1));
      expect(agentes.first.codigo, equals('20'));
      expect(agentes.first.descricao, equals('ITAU UNIBANCO'));
    });
  });
}
