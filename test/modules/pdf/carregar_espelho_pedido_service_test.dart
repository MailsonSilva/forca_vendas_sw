import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:forca_de_vendas/modules/pdf/dtos/espelho_pedido_dto.dart';
import 'package:forca_de_vendas/modules/pdf/services/carregar_espelho_pedido_service.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Database db;

  setUp(() async {
    db = await openDatabase(inMemoryDatabasePath, version: 1, onCreate: (db, version) async {
      await db.execute('''
        CREATE TABLE pckvendig000 (
          ped00_numped INTEGER PRIMARY KEY,
          ped00_fatmov TEXT,
          ped00_pacstr TEXT,
          ped00_datsys TEXT,
          ped00_codrep INTEGER,
          ped00_codcli INTEGER,
          ped00_clides TEXT,
          ped00_plades TEXT,
          ped00_lindes TEXT,
          ped00_digagt INTEGER,
          ped00_observ TEXT,
          ped00_digtot REAL,
          ped00_fattot REAL,
          ped00_bontot REAL,
          ped00_subtot REAL,
          ped00_destot REAL,
          ped00_sttenv INTEGER
        )
      ''');

      await db.execute('''
        CREATE TABLE pckvendig010 (
          ped10_numped INTEGER,
          ped10_seq INTEGER,
          ped10_codprd TEXT,
          ped10_descri TEXT,
          ped10_unidpri TEXT,
          ped10_qtdped REAL,
          ped10_fatqtd REAL,
          ped10_pcosub REAL,
          ped10_totprd REAL,
          ped10_qtdbon REAL,
          ped10_sttbon INTEGER,
          ped10_perdes REAL
        )
      ''');

      await db.execute('''
        CREATE TABLE cadcli00 (
          cli00_codigo INTEGER PRIMARY KEY,
          cli00_descri TEXT,
          cli00_fantas TEXT,
          cli00_cpfcnp TEXT,
          cli00_insest TEXT,
          cli00_endere TEXT,
          cli00_endnum TEXT,
          cli00_bairro TEXT,
          cli00_ciddes TEXT,
          cli00_estsgl TEXT,
          cli00_cep TEXT,
          cli00_fonddd TEXT,
          cli00_fonnum TEXT
        )
      ''');

      await db.execute('''
        CREATE TABLE cadrep00 (
          ven00_codigo INTEGER PRIMARY KEY,
          ven00_nome TEXT
        )
      ''');

      await db.execute('''
        CREATE TABLE cadpro00 (
          pro00_codigo TEXT PRIMARY KEY,
          pro00_codbar TEXT,
          pro00_descri TEXT,
          pro00_codmar INTEGER
        )
      ''');

      await db.execute('''
        CREATE TABLE cadmar00 (
          mar00_codigo INTEGER PRIMARY KEY,
          mar00_descri TEXT
        )
      ''');
    });

    // Populate test data
    await db.insert('cadrep00', {'ven00_codigo': 10, 'ven00_nome': 'Representante Vendas'});
    await db.insert('cadcli00', {
      'cli00_codigo': 500,
      'cli00_descri': 'Supermercado Central Ltda',
      'cli00_fantas': 'Super Central',
      'cli00_cpfcnp': '12.345.678/0001-99',
      'cli00_insest': '1234567890',
      'cli00_endere': 'Av. Principal, 100',
      'cli00_endnum': '120',
      'cli00_bairro': 'Centro',
      'cli00_ciddes': 'Recife',
      'cli00_estsgl': 'PE',
      'cli00_cep': '50000-000',
      'cli00_fonddd': '81',
      'cli00_fonnum': '988887777',
    });

    await db.insert('cadpro00', {
      'pro00_codigo': 'P100',
      'pro00_codbar': '7890001',
      'pro00_descri': 'Biscoito Recheado 120g',
      'pro00_codmar': 1,
    });
    await db.insert('cadpro00', {
      'pro00_codigo': 'P200',
      'pro00_codbar': '7890002',
      'pro00_descri': 'Refrigerante Cola 2L',
      'pro00_codmar': 2,
    });

    await db.insert('cadmar00', {'mar00_codigo': 1, 'mar00_descri': 'Marca Delícia'});
    await db.insert('cadmar00', {'mar00_codigo': 2, 'mar00_descri': 'Marca Refri'});

    await db.insert('pckvendig000', {
      'ped00_numped': 1234,
      'ped00_fatmov': 'NF-9988',
      'ped00_pacstr': 'p22-1065',
      'ped00_datsys': '2026-09-11 10:00:00',
      'ped00_codrep': 10,
      'ped00_codcli': 500,
      'ped00_clides': 'Supermercado Central Ltda',
      'ped00_plades': '30/60 Dias',
      'ped00_lindes': 'Alimentos e Bebidas',
      'ped00_digagt': 1,
      'ped00_observ': 'Entregar pela manhã nos fundos',
      'ped00_digtot': 1500.0,
      'ped00_fattot': 1400.0,
      'ped00_bontot': 100.0,
      'ped00_subtot': 50.0,
      'ped00_destot': 20.0,
      'ped00_sttenv': 1,
    });

    await db.insert('pckvendig010', {
      'ped10_numped': 1234,
      'ped10_seq': 1,
      'ped10_codprd': 'P100',
      'ped10_descri': 'Biscoito Recheado 120g',
      'ped10_unidpri': 'PC',
      'ped10_qtdped': 20.0,
      'ped10_fatqtd': 18.0,
      'ped10_pcosub': 5.0,
      'ped10_totprd': 100.0,
      'ped10_qtdbon': 0.0,
      'ped10_sttbon': 0,
      'ped10_perdes': 5.0,
    });

    await db.insert('pckvendig010', {
      'ped10_numped': 1234,
      'ped10_seq': 2,
      'ped10_codprd': 'P200',
      'ped10_descri': 'Refrigerante Cola 2L',
      'ped10_unidpri': 'UN',
      'ped10_qtdped': 10.0,
      'ped10_fatqtd': 10.0,
      'ped10_pcosub': 8.0,
      'ped10_totprd': 80.0,
      'ped10_qtdbon': 2.0,
      'ped10_sttbon': 1,
      'ped10_perdes': 0.0,
    });
  });

  tearDown(() async {
    await db.close();
  });

  test('carregarEspelhoPedido monta EspelhoPedidoDTO com dados completos do pedido e itens', () async {
    final espelho = await carregarEspelhoPedido(1234, db: db);

    expect(espelho, isNotNull);
    expect(espelho!.numeroPedido, equals(1234));
    expect(espelho.numeroNotaFiscal, equals('NF-9988'));
    expect(espelho.numeroPacote, equals('p22-1065'));
    expect(espelho.vendedorCodigo, equals('10'));
    expect(espelho.vendedorNome, equals('Representante Vendas'));
    expect(espelho.clienteCodigo, equals('500'));
    expect(espelho.clienteRazaoSocial, equals('Supermercado Central Ltda'));
    expect(espelho.clienteNomeFantasia, equals('Super Central'));
    expect(espelho.clienteCpfCnpj, equals('12.345.678/0001-99'));
    expect(espelho.clienteIE, equals('1234567890'));
    expect(espelho.clienteEndereco, contains('Av. Principal, 100'));
    expect(espelho.clienteNumero, equals('120'));
    expect(espelho.clienteBairro, equals('Centro'));
    expect(espelho.clienteCidade, equals('Recife'));
    expect(espelho.clienteUf, equals('PE'));
    expect(espelho.clienteTelefone, equals('(81) 988887777'));
    expect(espelho.planoPagamento, equals('30/60 Dias'));
    expect(espelho.linhaProduto, equals('Alimentos e Bebidas'));
    expect(espelho.observacao, equals('Entregar pela manhã nos fundos'));
    expect(espelho.valorTotalDigitado, equals(1500.0));
    expect(espelho.valorTotalFaturado, equals(1400.0));
    expect(espelho.valorTotalBonificado, equals(100.0));
    expect(espelho.valorSubstituicaoTributaria, equals(50.0));
    expect(espelho.valorDescontoTotal, equals(20.0));

    // Itens
    expect(espelho.itens.length, equals(2));

    final item1 = espelho.itens[0];
    expect(item1.sequencial, equals(1));
    expect(item1.codigoProduto, equals(0)); // ou id
    expect(item1.codigoEAN, equals('7890001'));
    expect(item1.descricao, equals('Biscoito Recheado 120g'));
    expect(item1.marca, equals('Marca Delícia'));
    expect(item1.unidade, equals('PC'));
    expect(item1.quantidadeDigitada, equals(20.0));
    expect(item1.quantidadeFaturada, equals(18.0));
    expect(item1.corte, equals(2.0));
    expect(item1.precoUnitario, equals(5.0));
    expect(item1.valorTotal, equals(100.0));
    expect(item1.isBonificacao, isFalse);

    final item2 = espelho.itens[1];
    expect(item2.sequencial, equals(2));
    expect(item2.codigoEAN, equals('7890002'));
    expect(item2.marca, equals('Marca Refri'));
    expect(item2.unidade, equals('UN'));
    expect(item2.quantidadeDigitada, equals(10.0));
    expect(item2.corte, equals(0.0));
    expect(item2.isBonificacao, isTrue);

    // Totais calculados
    expect(espelho.totalItens, equals(2));
    expect(espelho.totalQtdPedido, equals(30.0));
    expect(espelho.totalQtdFatura, equals(28.0));
    expect(espelho.valorLiquido, equals(1400.0));
  });

  test('carregarEspelhoPedido retorna null se o pedido não existir', () async {
    final espelho = await carregarEspelhoPedido(99999, db: db);
    expect(espelho, isNull);
  });
}
