import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:forca_de_vendas/domain/models/carteira_roteirizacao_model.dart';
import 'package:forca_de_vendas/services/carteira_roteirizacao_service.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Database db;

  setUp(() async {
    db = await databaseFactory.openDatabase(inMemoryDatabasePath);

    // Cria a tabela cadcli00 com colunas completas de roteirização
    await db.execute('''
      CREATE TABLE cadcli00 (
        cli00_codigo INTEGER PRIMARY KEY,
        cli00_descri TEXT,
        cli00_fantas TEXT,
        cli00_endere TEXT,
        cli00_ciddes TEXT,
        cli00_estsgl TEXT,
        cli00_fonddd TEXT,
        cli00_fonnum TEXT,
        cli00_cpfcnp TEXT,
        cli00_crelim REAL DEFAULT 0,
        cli00_creatu REAL DEFAULT 0,
        cli00_datcom TEXT,
        cli00_pessoa TEXT,
        cli00_typpes INTEGER,
        cli00_active INTEGER DEFAULT 1,
        cli00_observ TEXT,
        cli00_titven REAL DEFAULT 0,
        cli00_titave REAL DEFAULT 0,
        cli00_flgven INTEGER DEFAULT 0,
        cli16_codlat REAL,
        cli16_codlon REAL
      )
    ''');
  });

  tearDown(() async {
    await db.close();
  });

  group('CarteiraRoteirizacao - Regras de Crédito no PDV (Cores de Alerta)', () {
    test('Cliente com títulos vencidos é classificado como Inadimplente (Vermelho)', () {
      final cli = ClienteRoteiroItem.fromMap({
        'cli00_codigo': 101,
        'cli00_descri': 'Mercado A',
        'cli00_titven': 1500.0,
        'cli00_titave': 300.0,
      });

      expect(cli.statusCredito, equals(StatusCreditoCliente.inadimplente));
      expect(cli.possuiInadimplencia, isTrue);
      expect(cli.possuiTitulosAVencer, isFalse);
    });

    test('Cliente com títulos a vencer e sem vencidos é classificado como Títulos a Vencer (Amarelo)', () {
      final cli = ClienteRoteiroItem.fromMap({
        'cli00_codigo': 102,
        'cli00_descri': 'Mercado B',
        'cli00_titven': 0.0,
        'cli00_titave': 800.0,
      });

      expect(cli.statusCredito, equals(StatusCreditoCliente.titulosAVencer));
      expect(cli.possuiInadimplencia, isFalse);
      expect(cli.possuiTitulosAVencer, isTrue);
    });

    test('Cliente sem débitos pendentes é classificado como Regular (Verde)', () {
      final cli = ClienteRoteiroItem.fromMap({
        'cli00_codigo': 103,
        'cli00_descri': 'Mercado C',
        'cli00_titven': 0.0,
        'cli00_titave': 0.0,
      });

      expect(cli.statusCredito, equals(StatusCreditoCliente.regular));
      expect(cli.isRegular, isTrue);
    });
  });

  group('CarteiraRoteirizacaoService - Consultas e Filtros SQLite (ffrmrelclirot00)', () {
    setUp(() async {
      // Inserção de massa de dados para testes de filtros
      await db.insert('cadcli00', {
        'cli00_codigo': 1,
        'cli00_descri': 'SUPERMERCADO ALVORADA',
        'cli00_fantas': 'ALVORADA',
        'cli00_ciddes': 'SAO PAULO',
        'cli00_estsgl': 'SP',
        'cli00_cpfcnp': '12.345.678/0001-90',
        'cli00_typpes': 2, // PJ
        'cli00_active': 1, // Ativo
        'cli00_flgven': 1, // Segunda-Feira
        'cli00_titven': 0.0,
        'cli00_titave': 0.0,
      });

      await db.insert('cadcli00', {
        'cli00_codigo': 2,
        'cli00_descri': 'PADARIA CENTRAL LTDA',
        'cli00_fantas': 'PADARIA CENTRAL',
        'cli00_ciddes': 'CAMPINAS',
        'cli00_estsgl': 'SP',
        'cli00_cpfcnp': '98.765.432/0001-10',
        'cli00_typpes': 2, // PJ
        'cli00_active': 1, // Ativo
        'cli00_flgven': 3, // Quarta-Feira
        'cli00_titven': 450.0, // Inadimplente
        'cli00_titave': 0.0,
      });

      await db.insert('cadcli00', {
        'cli00_codigo': 3,
        'cli00_descri': 'JOAO DA SILVA MERCEARIA',
        'cli00_fantas': 'MERCEARIA DO JOAO',
        'cli00_ciddes': 'CAMPINAS',
        'cli00_estsgl': 'SP',
        'cli00_cpfcnp': '111.222.333-44',
        'cli00_typpes': 1, // PF
        'cli00_active': 1, // Ativo
        'cli00_flgven': 3, // Quarta-Feira
        'cli00_titven': 0.0,
        'cli00_titave': 1200.0, // A vencer
      });

      await db.insert('cadcli00', {
        'cli00_codigo': 4,
        'cli00_descri': 'BAR DO ZE INATIVO',
        'cli00_ciddes': 'SANTOS',
        'cli00_estsgl': 'SP',
        'cli00_active': 0, // Inativo
        'cli00_flgven': 3, // Quarta-Feira
      });
    });

    test('Filtra clientes pela Rota do Dia (ex: Quarta-feira cli00_flgven = 3)', () async {
      final resumo = await CarteiraRoteirizacaoService.obterCarteiraRoteirizada(
        filtro: const RoteirizacaoFiltro(diaVisita: 3, statusAtivo: 1),
        customDb: db,
      );

      // Deve retornar clientes 2 e 3 (ativos da quarta-feira)
      expect(resumo.totalClientes, equals(2));
      expect(resumo.totalInadimplentes, equals(1)); // Cliente 2
      expect(resumo.totalTitulosAVencer, equals(1)); // Cliente 3
      expect(resumo.totalRegulares, equals(0));
    });

    test('Filtro por busca textual pesquisa por Razão Social, Fantasia e CPF/CNPJ', () async {
      final resumo = await CarteiraRoteirizacaoService.obterCarteiraRoteirizada(
        filtro: const RoteirizacaoFiltro(buscaTexto: 'ALVORADA', diaVisita: -1),
        customDb: db,
      );

      expect(resumo.totalClientes, equals(1));
      expect(resumo.clientes.first.codigo, equals(1));
    });

    test('Filtro por Tipo de Pessoa (Pessoa Física)', () async {
      final resumo = await CarteiraRoteirizacaoService.obterCarteiraRoteirizada(
        filtro: const RoteirizacaoFiltro(tipoPessoa: 1, diaVisita: -1),
        customDb: db,
      );

      expect(resumo.totalClientes, equals(1));
      expect(resumo.clientes.first.codigo, equals(3));
      expect(resumo.clientes.first.razaoSocial, equals('JOAO DA SILVA MERCEARIA'));
    });

    test('Filtro por Cidade e UF', () async {
      final resumo = await CarteiraRoteirizacaoService.obterCarteiraRoteirizada(
        filtro: const RoteirizacaoFiltro(cidade: 'CAMPINAS', uf: 'SP', diaVisita: -1),
        customDb: db,
      );

      expect(resumo.totalClientes, equals(2)); // Clientes 2 e 3
    });
  });
}
