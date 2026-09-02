import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:forca_de_vendas/services/faturamento_metas_service.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Database db;

  setUp(() async {
    db = await databaseFactory.openDatabase(inMemoryDatabasePath);

    // Cria as tabelas necessárias
    await db.execute('''
      CREATE TABLE cadcli00 (
        cli00_codigo INTEGER PRIMARY KEY,
        cli00_descri TEXT,
        cli00_typpes INTEGER
      )
    ''');

    await db.execute('''
      CREATE TABLE estfatdat00 (
        dat00_dattim TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE estfatcvd00 (
        fat00_codfil INTEGER,
        fat00_codven INTEGER,
        fat00_datmov TEXT,
        fat00_clides TEXT,
        fat00_clityp INTEGER,
        fat00_vlrperfat REAL DEFAULT 0,
        fat00_vlrfatven REAL DEFAULT 0,
        fat00_vlrdigven REAL DEFAULT 0,
        fat00_vlrdigloc REAL DEFAULT 0,
        fat00_vlrtotven REAL DEFAULT 0,
        fat00_vlrcalven REAL DEFAULT 0,
        fat00_vlrtotper REAL DEFAULT 0,
        fat00_vlrtotlib REAL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE pckvendig000 (
        ped00_numped INTEGER PRIMARY KEY,
        ped00_codfil INTEGER,
        ped00_codven INTEGER,
        ped00_codcli INTEGER,
        ped00_digtot REAL,
        ped00_sttdig INTEGER,
        ped00_sttenv INTEGER
      )
    ''');
  });

  tearDown(() async {
    await db.close();
  });

  group('FaturamentoMetasService - Validação Pura de Limite PF (getPEDTOTPessoaFisicaCheck)', () {
    test('Caso Válido: Cliente PJ (tipo 2) não sofre restrição de limite PF', () {
      final resultado = FaturamentoMetasService.validarLimitePessoaFisicaCalculado(
        tipoCliente: 2, // PJ
        valorPedidoAtual: 50000.0,
        totalAcumuladoPF: 10000.0,
        limiteLiberadoPF: 5000.0,
      );

      expect(resultado.valido, isTrue);
      expect(resultado.mensagemBloqueio, isNull);
    });

    test('Caso Válido: Cliente PF com faturamento acumulado + pedido dentro do limite liberado', () {
      final resultado = FaturamentoMetasService.validarLimitePessoaFisicaCalculado(
        tipoCliente: 1, // PF
        valorPedidoAtual: 1500.0,
        totalAcumuladoPF: 3000.0,
        limiteLiberadoPF: 5000.0, // 4500 <= 5000
      );

      expect(resultado.valido, isTrue);
      expect(resultado.limiteRestante, equals(500.0));
      expect(resultado.mensagemBloqueio, isNull);
    });

    test('Caso Válido: Cliente PF quando limite configurado é zero ou desativado (sem teto)', () {
      final resultado = FaturamentoMetasService.validarLimitePessoaFisicaCalculado(
        tipoCliente: 1, // PF
        valorPedidoAtual: 10000.0,
        totalAcumuladoPF: 20000.0,
        limiteLiberadoPF: 0.0,
      );

      expect(resultado.valido, isTrue);
      expect(resultado.mensagemBloqueio, isNull);
    });

    test('Caso Inválido: Cliente PF com valor do pedido excedendo o limite restante', () {
      final resultado = FaturamentoMetasService.validarLimitePessoaFisicaCalculado(
        tipoCliente: 1, // PF
        valorPedidoAtual: 2500.0,
        totalAcumuladoPF: 3000.0,
        limiteLiberadoPF: 5000.0, // 5500 > 5000
      );

      expect(resultado.valido, isFalse);
      expect(resultado.limiteRestante, equals(2000.0));
      expect(
        resultado.mensagemBloqueio,
        contains('Limite de faturamento para Pessoa Física excedido no mês'),
      );
    });

    test('Caso Inválido: Cliente PF quando o acumulado mensal já estourou o limite', () {
      final resultado = FaturamentoMetasService.validarLimitePessoaFisicaCalculado(
        tipoCliente: 1, // PF
        valorPedidoAtual: 10.0,
        totalAcumuladoPF: 6000.0,
        limiteLiberadoPF: 5000.0,
      );

      expect(resultado.valido, isFalse);
      expect(resultado.limiteRestante, equals(-1000.0));
      expect(resultado.mensagemBloqueio, isNotNull);
    });
  });

  group('FaturamentoMetasService - Validação de Limite PF com Banco SQLite', () {
    test('Caso Válido: Cliente PJ gravado no banco permite checkout livremente', () async {
      await db.insert('cadcli00', {
        'cli00_codigo': 101,
        'cli00_descri': 'Empresa ABC LTDA',
        'cli00_typpes': 2, // PJ
      });

      final res = await FaturamentoMetasService.validarLimitePessoaFisica(
        clienteCodigo: 101,
        valorPedido: 8000.0,
        customDb: db,
      );

      expect(res.valido, isTrue);
      expect(res.mensagemBloqueio, isNull);
    });

    test('Caso Válido: Cliente PF com vendas acumuladas + pedido dentro do limite', () async {
      await db.insert('cadcli00', {
        'cli00_codigo': 201,
        'cli00_descri': 'Joao Silva',
        'cli00_typpes': 1, // PF
      });

      // Configuração de meta do ERP para PF com limite de R$ 10.000,00 e R$ 4.000,00 faturados
      await db.insert('estfatcvd00', {
        'fat00_codfil': 1,
        'fat00_codven': 71,
        'fat00_clityp': 1,
        'fat00_vlrfatven': 4000.0,
        'fat00_vlrtotlib': 10000.0,
      });

      // Pedido local anterior de R$ 1.500,00
      await db.insert('pckvendig000', {
        'ped00_numped': 1,
        'ped00_codfil': 1,
        'ped00_codven': 71,
        'ped00_codcli': 201,
        'ped00_digtot': 1500.0,
        'ped00_sttdig': 1,
        'ped00_sttenv': 0,
      });

      // Novo pedido de R$ 2.000,00 (Total acumulado: 4000 + 1500 + 2000 = 7500 <= 10000)
      final res = await FaturamentoMetasService.validarLimitePessoaFisica(
        clienteCodigo: 201,
        valorPedido: 2000.0,
        codVen: 71,
        customDb: db,
      );

      expect(res.valido, isTrue);
      expect(res.limiteRestante, equals(2500.0));
      expect(res.mensagemBloqueio, isNull);
    });

    test('Caso Inválido: Cliente PF estoura o limite liberado', () async {
      await db.insert('cadcli00', {
        'cli00_codigo': 202,
        'cli00_descri': 'Maria Souza',
        'cli00_typpes': 1, // PF
      });

      await db.insert('estfatcvd00', {
        'fat00_codfil': 1,
        'fat00_codven': 71,
        'fat00_clityp': 1,
        'fat00_vlrfatven': 8000.0,
        'fat00_vlrtotlib': 10000.0,
      });

      // Novo pedido de R$ 3.000,00 (Total: 8000 + 3000 = 11000 > 10000)
      final res = await FaturamentoMetasService.validarLimitePessoaFisica(
        clienteCodigo: 202,
        valorPedido: 3000.0,
        codVen: 71,
        customDb: db,
      );

      expect(res.valido, isFalse);
      expect(res.mensagemBloqueio, contains('Limite de faturamento para Pessoa Física excedido'));
    });
  });

  group('FaturamentoMetasService - Sintetização Local (ett_sintetize_ESTFATCVD00)', () {
    test('Consolida faturamento oficial do ERP com pedidos locais em trânsito e rascunhos', () async {
      await db.insert('estfatdat00', {'dat00_dattim': '02/09/2026 10:00'});

      // Metas do ERP
      await db.insert('estfatcvd00', {
        'fat00_codfil': 1,
        'fat00_codven': 71,
        'fat00_clityp': 1,
        'fat00_clides': 'Fisica',
        'fat00_vlrcalven': 10000.0,
        'fat00_vlrfatven': 3000.0,
        'fat00_vlrtotlib': 8000.0,
      });

      await db.insert('estfatcvd00', {
        'fat00_codfil': 1,
        'fat00_codven': 71,
        'fat00_clityp': 2,
        'fat00_clides': 'Juridica',
        'fat00_vlrcalven': 50000.0,
        'fat00_vlrfatven': 25000.0,
        'fat00_vlrtotlib': 0.0,
      });

      // Clientes
      await db.insert('cadcli00', {'cli00_codigo': 10, 'cli00_descri': 'Cli PF', 'cli00_typpes': 1});
      await db.insert('cadcli00', {'cli00_codigo': 20, 'cli00_descri': 'Cli PJ', 'cli00_typpes': 2});

      // Pedidos locais: PF em trânsito (1000) e PF rascunho (500)
      await db.insert('pckvendig000', {
        'ped00_numped': 1,
        'ped00_codfil': 1,
        'ped00_codven': 71,
        'ped00_codcli': 10,
        'ped00_digtot': 1000.0,
        'ped00_sttenv': 1, // Trânsito
      });
      await db.insert('pckvendig000', {
        'ped00_numped': 2,
        'ped00_codfil': 1,
        'ped00_codven': 71,
        'ped00_codcli': 10,
        'ped00_digtot': 500.0,
        'ped00_sttenv': 0, // Rascunho
      });

      // Pedido local PJ em trânsito (5000)
      await db.insert('pckvendig000', {
        'ped00_numped': 3,
        'ped00_codfil': 1,
        'ped00_codven': 71,
        'ped00_codcli': 20,
        'ped00_digtot': 5000.0,
        'ped00_sttenv': 2, // Trânsito
      });

      final resumo = await FaturamentoMetasService.obterMetasConsolidadas(
        codVen: 71,
        codFil: 1,
        customDb: db,
      );

      // PF: ERP (3000) + Trânsito (1000) + Rascunho (500) = 4500
      expect(resumo.pessoaFisica.faturadoErp, equals(3000.0));
      expect(resumo.pessoaFisica.digitadoTransito, equals(1000.0));
      expect(resumo.pessoaFisica.rascunhoLocal, equals(500.0));
      expect(resumo.pessoaFisica.totalConsolidado, equals(4500.0));
      expect(resumo.pessoaFisica.percentualAtingido, equals(45.0)); // 4500 / 10000 = 45%
      expect(resumo.pessoaFisica.limiteRestantePf, equals(3500.0)); // 8000 - 4500 = 3500

      // PJ: ERP (25000) + Trânsito (5000) + Rascunho (0) = 30000
      expect(resumo.pessoaJuridica.faturadoErp, equals(25000.0));
      expect(resumo.pessoaJuridica.digitadoTransito, equals(5000.0));
      expect(resumo.pessoaJuridica.rascunhoLocal, equals(0.0));
      expect(resumo.pessoaJuridica.totalConsolidado, equals(30000.0));
      expect(resumo.pessoaJuridica.percentualAtingido, equals(60.0)); // 30000 / 50000 = 60%

      // Totais gerais
      expect(resumo.totalGeralMeta, equals(60000.0));
      expect(resumo.totalGeralRealizado, equals(34500.0));
      expect(resumo.percentualGeralAtingido, closeTo(57.5, 0.01)); // 34500 / 60000 = 57.5%
      expect(resumo.dataSincronizacao, equals('02/09/2026 10:00'));
    });
  });

  group('FaturamentoMetasService - Bloqueio de Venda e Alertas', () {
    test('Retorna mensagem de bloqueio explicativa com valores formatados quando PF excede cota', () async {
      await db.insert('cadcli00', {
        'cli00_codigo': 500,
        'cli00_descri': 'Consumidor Final PF',
        'cli00_typpes': 1,
      });

      await db.insert('estfatcvd00', {
        'fat00_codfil': 1,
        'fat00_codven': 71,
        'fat00_clityp': 1,
        'fat00_vlrfatven': 15000.0,
        'fat00_vlrtotlib': 16000.0, // Saldo restante: 1000
      });

      final validacao = await FaturamentoMetasService.validarLimitePessoaFisica(
        clienteCodigo: 500,
        valorPedido: 1500.0, // 15000 + 1500 = 16500 > 16000
        codVen: 71,
        customDb: db,
      );

      expect(validacao.valido, isFalse);
      expect(validacao.mensagemBloqueio, contains('Limite: R\$ 16000,00'));
      expect(validacao.mensagemBloqueio, contains('Saldo Disponível: R\$ 1000,00'));
      expect(validacao.mensagemBloqueio, contains('Pedido: R\$ 1500,00'));
    });
  });
}
