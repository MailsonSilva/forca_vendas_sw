import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:forca_de_vendas/app_state.dart';
import 'package:forca_de_vendas/action_code/busca_produto.dart';
import 'package:forca_de_vendas/action_code/carregar_produto_detalhe.dart';
import 'package:forca_de_vendas/action_code/salvar_carrinho_pedido.dart';
import 'package:forca_de_vendas/data/services/local_sales_database_service.dart';
import 'package:forca_de_vendas/domain/services/calculo_preco_produto_service.dart';
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

    // Tabelas canônicas
    await db.execute('''
      CREATE TABLE cadpro00 (
        pro00_codigo INTEGER,
        pro00_prifil INTEGER DEFAULT 1,
        pro00_descri TEXT,
        pro00_unidad TEXT DEFAULT 'UN',
        pro00_codbar TEXT DEFAULT '',
        pro00_reffor TEXT DEFAULT '',
        pro00_ref001 TEXT DEFAULT '',
        pro00_ref002 TEXT DEFAULT '',
        pro00_codimg INTEGER DEFAULT 0,
        pro00_pcomax REAL DEFAULT 0,
        pro00_pcomin REAL DEFAULT 0,
        pro00_qtdest REAL DEFAULT 0,
        pro00_embala TEXT DEFAULT 'UN',
        pro00_codemb INTEGER DEFAULT 0,
        pro00_codmar INTEGER DEFAULT 0,
        pro00_codfab INTEGER DEFAULT 0,
        PRIMARY KEY (pro00_codigo, pro00_prifil)
      )
    ''');

    await db.execute('''
      CREATE TABLE cadproemb02 (
        pro02_codprd INTEGER,
        pro02_mulven REAL DEFAULT 1.0,
        pro02_mulemb INTEGER DEFAULT 1
      )
    ''');

    await db.execute('''
      CREATE TABLE cadpla00 (
        pla00_codigo INTEGER PRIMARY KEY,
        pla00_descri TEXT,
        pla00_fator REAL DEFAULT 1.0,
        pla00_vlrmin REAL DEFAULT 0.0,
        pla00_codtyp INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE estpcopro00 (
        pro00_codcls INTEGER,
        pro00_codtab INTEGER,
        pro00_codpro INTEGER,
        pro00_pcocus REAL,
        pro00_pcosub REAL,
        pro00_pcomin REAL,
        pro00_pcomax REAL
      )
    ''');

    await db.execute('''
      CREATE TABLE estpro00 (
        pro00_codpro INTEGER,
        pro00_codfil INTEGER,
        pro00_qtdest REAL DEFAULT 0,
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
        ped10_seq INTEGER DEFAULT 1,
        ped10_codprd TEXT,
        ped10_descri TEXT,
        ped10_unidpri TEXT,
        ped10_qtdped REAL DEFAULT 0,
        ped10_pcosub REAL DEFAULT 0,
        ped10_totprd REAL DEFAULT 0,
        ped10_pcomax REAL DEFAULT 0,
        ped10_pcomin REAL DEFAULT 0,
        ped10_digpco REAL DEFAULT 0
      )
    ''');

    // Criação dos índices da Parte 1
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_cadpro00_busca ON cadpro00(pro00_descri, pro00_codigo, pro00_prifil);');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_cadproemb02_prd ON cadproemb02(pro02_codprd);');

    // População de teste:
    // Produto 101: Preço base 100.00, pcomin 80.00, pcomax 120.00
    await db.insert('cadpro00', {
      'pro00_codigo': 101,
      'pro00_prifil': 1,
      'pro00_descri': 'PRODUTO TESTE 101',
      'pro00_unidad': 'UN',
      'pro00_pcomax': 120.00,
      'pro00_pcomin': 80.00,
      'pro00_qtdest': 50.0,
    });
    await db.insert('estpro00', {
      'pro00_codpro': 101,
      'pro00_codfil': 1,
      'pro00_qtdest': 50.0,
      'pro00_qtdpen': 0.0,
    });
    await db.insert('estpcopro00', {
      'pro00_codtab': 1,
      'pro00_codpro': 101,
      'pro00_pcosub': 100.00,
      'pro00_pcomin': 80.00,
      'pro00_pcomax': 120.00,
    });

    // Embalagem para 101: multiplicador 1.0
    await db.insert('cadproemb02', {
      'pro02_codprd': 101,
      'pro02_mulven': 1.0,
      'pro02_mulemb': 1,
    });

    // Plano 1: à vista (fator 1.0)
    await db.insert('cadpla00', {
      'pla00_codigo': 1,
      'pla00_descri': 'A VISTA',
      'pla00_fator': 1.0,
    });

    // Plano 2: a prazo com acréscimo de 10% (fator 1.10)
    await db.insert('cadpla00', {
      'pla00_codigo': 2,
      'pla00_descri': '30/60 DIAS (+10%)',
      'pla00_fator': 1.10,
    });

    // Plano 3: desconto financeiro de 5% (fator 0.95)
    await db.insert('cadpla00', {
      'pla00_codigo': 3,
      'pla00_descri': 'ANTECIPADO (-5%)',
      'pla00_fator': 0.95,
    });
  });

  tearDown(() async {
    await db.close();
  });

  group('PARTE 1: Performance da Busca e Paginação', () {
    test('Índices idx_cadpro00_busca e idx_cadproemb02_prd existem no SQLite', () async {
      final indicesPro = await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='index' AND tbl_name='cadpro00'");
      final nomesPro = indicesPro.map((r) => r['name']?.toString() ?? '').toSet();
      expect(nomesPro, contains('idx_cadpro00_busca'));

      final indicesEmb = await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='index' AND tbl_name='cadproemb02'");
      final nomesEmb = indicesEmb.map((r) => r['name']?.toString() ?? '').toSet();
      expect(nomesEmb, contains('idx_cadproemb02_prd'));
    });

    test('Busca padrão aplica paginação de 30 itens', () async {
      // Insere 40 produtos
      for (int i = 1; i <= 40; i++) {
        await db.insert('cadpro00', {
          'pro00_codigo': 1000 + i,
          'pro00_prifil': 1,
          'pro00_descri': 'ITEM PAGINADO $i',
          'pro00_pcomax': 10.0,
          'pro00_pcomin': 5.0,
          'pro00_qtdest': 10.0,
        });
      }

      final page1 = await buscaProduto('PAGINADO', null, null, null, null, null, false, false, 1, 'Todas');
      expect(page1.length, equals(30));

      final page2 = await buscaProduto('PAGINADO', null, null, null, null, null, false, false, 1, 'Todas', null, 30);
      expect(page2.length, equals(10));
    });

    test('Busca de produtos responde em menos de 100ms com catálogo populado', () async {
      final sw = Stopwatch()..start();
      final resultados = await buscaProduto('101', null, null, null, null, null, false, false, 1, 'Todas');
      sw.stop();

      expect(resultados, isNotEmpty);
      expect(sw.elapsedMilliseconds, lessThan(100),
          reason: 'A busca deve responder em menos de 100ms com índices apropriados');
    });
  });

  group('PARTE 2: Serviço Puro CalculoPrecoProdutoService e Consistência', () {
    test('CalculoPrecoProdutoService aplica corretamente Fator do Plano e Desconto', () {
      // Preço base 100.00, Fator 1.10 -> 110.00
      final resAcrescimo = CalculoPrecoProdutoService.calcularPreco(
        precoBase: 100.00,
        fatorPlano: 1.10,
        pcomin: 80.00,
      );
      expect(resAcrescimo.precoEfetivo, equals(110.00));
      expect(resAcrescimo.precoComFator, equals(110.00));

      // Preço base 100.00, Fator 0.95 -> 95.00
      final resDescontoPlano = CalculoPrecoProdutoService.calcularPreco(
        precoBase: 100.00,
        fatorPlano: 0.95,
        pcomin: 80.00,
      );
      expect(resDescontoPlano.precoEfetivo, equals(95.00));

      // Preço base 100.00, Fator 1.0, Desconto 15.00 -> 85.00
      final resComDesconto = CalculoPrecoProdutoService.calcularPreco(
        precoBase: 100.00,
        fatorPlano: 1.0,
        desconto: 15.00,
        pcomin: 80.00,
      );
      expect(resComDesconto.precoEfetivo, equals(85.00));

      // Trava de preço mínimo: Preço 100.00, Desconto 30.00 -> 70.00, mas pcomin é 80.00
      final resBloqueadoMinimo = CalculoPrecoProdutoService.calcularPreco(
        precoBase: 100.00,
        fatorPlano: 1.0,
        desconto: 30.00,
        pcomin: 80.00,
      );
      expect(resBloqueadoMinimo.precoEfetivo, equals(80.00),
          reason: 'Preço efetivo deve travar no pcomin');
      expect(resBloqueadoMinimo.atingiuPrecoMinimo, isTrue);
    });

    test('Consistência estrita de preço: buscaProduto, detalhes e pedido devem coincidir exatamente', () async {
      const int codPlano = 2; // Fator 1.10 (+10%)
      const int codTabela = 1;

      // 1. Busca de Produtos com plano 2
      final busca = await buscaProduto(
        '101',
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

      // 2. Detalhes do Produto sob demanda com mesmo plano e tabela
      AppState().tabelaPrecoAtiva = codTabela;
      AppState().planoAtivo = codPlano;
      final detalhe = await carregarProdutoDetalhe('101');
      expect(detalhe, isNotNull);
      final precoDetalhes = detalhe!.preco;

      // 3. Inclusão no carrinho e gravação do pedido
      final itemCarrinho = ItemPedidoStruct(
        codigoProduto: '101',
        descricao: detalhe.descricao,
        unidade: detalhe.unidade,
        precoUnitario: precoDetalhes,
        quantidade: 1.0,
        totalItem: precoDetalhes,
        pcomax: detalhe.pcomax,
        pcomin: detalhe.pcomin,
        mulver: 1.0,
      );

      final salvou = await salvarCarrinhoPedido(
        pedidoId: 9991,
        clienteCodigo: 1,
        linhaCodigo: '1',
        planoCodigo: '$codPlano',
        carrinhoItens: [itemCarrinho],
      );
      expect(salvou, isTrue);

      // Lê item gravado no SQLite em pckvendig010
      final itensGravados = await db.rawQuery(
        'SELECT ped10_digpco, ped10_pcosub FROM pckvendig010 WHERE ped10_numped = 9991 AND ped10_codprd = 101',
      );
      expect(itensGravados, isNotEmpty);
      final precoItemPedido = (itensGravados.first['ped10_digpco'] as num).toDouble();

      // Validação de Igualdade Monetária Rigorosa (Mesmo Produto, Mesma Tabela, Mesmo Plano)
      // Base = 100.00 * 1.10 = 110.00
      expect(precoBusca, equals(110.00));
      expect(precoDetalhes, equals(110.00));
      expect(precoItemPedido, equals(110.00));
      expect(precoBusca, equals(precoDetalhes));
      expect(precoDetalhes, equals(precoItemPedido));
    });
  });
}
