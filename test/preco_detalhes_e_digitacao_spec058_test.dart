import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:forca_de_vendas/app_state.dart';
import 'package:forca_de_vendas/action_code/busca_produto.dart';
import 'package:forca_de_vendas/action_code/carregar_produto_detalhe.dart';
import 'package:forca_de_vendas/action_code/salvar_carrinho_pedido.dart';
import 'package:forca_de_vendas/data/repositories/produto_repository.dart';
import 'package:forca_de_vendas/data/services/local_sales_database_service.dart';
import 'package:forca_de_vendas/domain/services/valide_pco_service.dart';
import 'package:forca_de_vendas/backend/schema/structs/cliente_result_struct.dart';
import 'package:forca_de_vendas/backend/schema/structs/item_pedido_struct.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Database db;

  setUp(() async {
    db = await databaseFactory.openDatabase(inMemoryDatabasePath);
    LocalSalesDatabaseService.setDatabaseForTesting(db);

    AppState().tabelaPrecoAtiva = 1;
    AppState().codFilialAtiva = 1;
    AppState().planoAtivo = 1;
    AppState().clienteSelecionado = ClienteResultStruct(
      cli00Codigo: 1,
      cli00Descri: 'CLIENTE TESTE',
      cli00Codreg: 0, // Sem região regionalizada
      cli00Typpco: 1, // Classe de preço 1
    );

    // Schema SQLite fiel ao legado e SPEC-058 (estpcopro00 sem pro00_codtab)
    await db.execute('''
      CREATE TABLE cadpro00 (
        pro00_codigo INTEGER PRIMARY KEY,
        pro00_descri TEXT,
        pro00_unidad TEXT DEFAULT 'UN',
        pro00_codbar TEXT DEFAULT '',
        pro00_reffor TEXT DEFAULT '',
        pro00_ref001 TEXT DEFAULT '',
        pro00_ref002 TEXT DEFAULT '',
        pro00_codimg INTEGER DEFAULT 0,
        pro00_qtdest REAL DEFAULT 100,
        pro00_embala TEXT DEFAULT 'UN',
        pro00_codemb INTEGER DEFAULT 0,
        pro00_codmar INTEGER DEFAULT 0,
        pro00_codfab INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE cadpla00 (
        pla00_codigo INTEGER PRIMARY KEY,
        pla00_descri TEXT,
        pla00_fator REAL DEFAULT 1.0
      )
    ''');

    // Tabela estpcopro00 canônica da SPEC-058:
    // pro00_codcls, pro00_codpro, pro00_pcocus, pro00_pcosub
    await db.execute('''
      CREATE TABLE estpcopro00 (
        pro00_codcls INTEGER,
        pro00_codpro INTEGER,
        pro00_pcocus REAL,
        pro00_pcosub REAL
      )
    ''');

    await db.execute('''
      CREATE TABLE estpro00 (
        pro00_codpro INTEGER,
        pro00_codfil INTEGER,
        pro00_qtdest REAL DEFAULT 100,
        pro00_qtdpen REAL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE pckvendig000 (
        ped00_numped INTEGER PRIMARY KEY,
        ped00_codcli INTEGER,
        ped00_codlin INTEGER,
        ped00_codpla INTEGER,
        ped00_codfil INTEGER,
        ped00_digtab INTEGER,
        ped00_sttdig INTEGER DEFAULT 0,
        ped00_sttenv INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE pckvendig010 (
        ped10_numped INTEGER,
        ped10_seqite INTEGER,
        ped10_codprd INTEGER,
        ped10_descri TEXT,
        ped10_unidpri TEXT,
        ped10_qtdped REAL,
        ped10_pcosub REAL,
        ped10_prcuni REAL,
        ped10_vlruni REAL,
        ped10_totprd REAL,
        ped10_qtdbon REAL DEFAULT 0,
        ped10_sttbon INTEGER DEFAULT 0,
        dig01_pcomax REAL,
        dig01_pcomin REAL,
        dig01_digpco REAL,
        ped10_pcomax REAL,
        ped10_pcomin REAL,
        ped10_digpco REAL
      )
    ''');

    // Popula planos: plano 1 (fator 1.0) e plano 2 (fator 1.10)
    await db.insert('cadpla00', {'pla00_codigo': 1, 'pla00_descri': 'A VISTA', 'pla00_fator': 1.0});
    await db.insert('cadpla00', {'pla00_codigo': 2, 'pla00_descri': 'A PRAZO 30D', 'pla00_fator': 1.10});

    // Produto 501: Cadastrado apenas com estpcopro00.pro00_pcosub = 80.00
    await db.insert('cadpro00', {
      'pro00_codigo': 501,
      'pro00_descri': 'PRODUTO TESTE 501',
      'pro00_unidad': 'UN',
    });
    await db.insert('estpcopro00', {
      'pro00_codcls': 1,
      'pro00_codpro': 501,
      'pro00_pcocus': 40.00,
      'pro00_pcosub': 80.00, // Preço praticado correto
    });
    await db.insert('estpro00', {
      'pro00_codpro': 501,
      'pro00_codfil': 1,
      'pro00_qtdest': 50.0,
      'pro00_qtdpen': 0.0,
    });
  });

  tearDown(() async {
    await db.close();
  });

  group('SPEC-058: Validação e Alinhamento de Preço em Todas as Telas', () {
    test('ValidePcoService.obterFaixasPreco deve ler pro00_pcosub de estpcopro00 mesmo sem estpcoreg00', () async {
      final faixa = await ValidePcoService.obterFaixasPreco(
        '501',
        codTabela: 1,
        codClasseCliente: 1,
      );

      expect(faixa.precoBase, equals(80.00), reason: 'precoBase deve ser pro00_pcosub (80.00)');
      expect(faixa.pcomax, equals(80.00));
      expect(faixa.pcomin, equals(40.00));
    });

    test('Preço na busca, nos detalhes e na digitação do pedido devem ser idênticos (com fator do plano)', () async {
      const int codPlano = 2; // Fator 1.10 -> 80.00 * 1.10 = 88.00
      const int codTabela = 1;

      // 1. Busca de Produtos (já funciona)
      final busca = await buscaProduto(
        '501',
        null,
        null,
        null,
        null,
        null,
        false,
        false,
        1,
        'Todas',
        codTabela,
        0,
        30,
        codPlano,
      );
      expect(busca, isNotEmpty);
      final precoBusca = busca.first.preco;
      expect(precoBusca, equals(88.00));

      // 2. Detalhes do Produto sob demanda
      final detalhe = await carregarProdutoDetalhe('501', codPlano, codTabela);
      expect(detalhe, isNotNull);
      final precoDetalhes = detalhe!.preco;
      expect(precoDetalhes, equals(88.00), reason: 'Detalhes deve apurar 88.00 via pro00_pcosub x fator 1.10');

      // 3. Digitação do pedido: inclusão e persistência
      final item = ItemPedidoStruct(
        codigoProduto: '501',
        descricao: detalhe.descricao,
        unidade: detalhe.unidade,
        precoUnitario: precoDetalhes,
        pcomax: detalhe.pcomax,
        pcomin: detalhe.pcomin,
        quantidade: 2.0,
        totalItem: precoDetalhes * 2.0,
      );

      final ok = await salvarCarrinhoPedido(
        pedidoId: 701,
        clienteCodigo: 1,
        linhaCodigo: '1',
        planoCodigo: '$codPlano',
        carrinhoItens: [item],
        codFilial: 1,
      );
      expect(ok, isTrue);

      final salvos = await db.rawQuery('SELECT * FROM pckvendig010 WHERE ped10_numped = 701');
      expect(salvos, isNotEmpty);
      final row = salvos.first;
      expect((row['ped10_digpco'] as num).toDouble(), equals(88.00));
      expect((row['dig01_digpco'] as num).toDouble(), equals(88.00));
      expect((row['ped10_pcosub'] as num).toDouble(), equals(88.00));
    });
  });
}
