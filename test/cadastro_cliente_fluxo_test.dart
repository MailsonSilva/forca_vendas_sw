import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:forca_de_vendas/action_code/salvar_cliente_offline.dart';
import 'package:forca_de_vendas/action_code/pesquisa_cliente.dart';
import 'package:forca_de_vendas/backend/schema/structs/cliente_result_struct.dart';
import 'package:forca_de_vendas/data/services/local_sales_database_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late Directory docsDir;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('cli_temp_');
    docsDir = await Directory.systemTemp.createTemp('cli_docs_');

    const MethodChannel channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (MethodCall methodCall) async {
        return tempDir.path;
      },
    );

    final db = await LocalSalesDatabaseService.getDatabase();
    await db.execute('DROP TABLE IF EXISTS cadcli00');
    await db.execute('''
      CREATE TABLE cadcli00 (
        cli00_codigo INTEGER PRIMARY KEY,
        cli00_codigo16 TEXT,
        cli00_descri TEXT,
        cli00_fantas TEXT,
        cli00_typpes INTEGER,
        cli00_cpfcnp TEXT,
        cli00_insest TEXT,
        cli00_nrg TEXT,
        cli00_email TEXT,
        cli00_emaildanfe TEXT,
        cli00_ramo TEXT,
        cli00_crelim REAL DEFAULT 0,
        cli00_creatu REAL DEFAULT 0,
        cli00_endere TEXT,
        cli00_endnum TEXT,
        cli00_bairro TEXT,
        cli00_ciddes TEXT,
        cli00_estsgl TEXT,
        cli00_endcep TEXT,
        cli00_fonddd TEXT,
        cli00_fonnum TEXT,
        cli00_observ TEXT,
        cli00_active INTEGER DEFAULT 1,
        cli00_endcob TEXT,
        cli00_numcob TEXT,
        cli00_bairrocob TEXT,
        cli00_cidadecob TEXT,
        cli00_ufcob TEXT,
        cli00_cepcob TEXT,
        cli00_dddcob TEXT,
        cli00_fonecob TEXT,
        cli00_sttenv INTEGER DEFAULT 0
      )
    ''');
    await db.execute('DROP VIEW IF EXISTS cli00');
    await db.execute('CREATE VIEW cli00 AS SELECT * FROM cadcli00');
  });

  tearDown(() async {
    try {
      if (await tempDir.exists()) await tempDir.delete(recursive: true);
      if (await docsDir.exists()) await docsDir.delete(recursive: true);
    } catch (_) {}
  });

  group('Módulo de Cadastro e Edição de Clientes (Regras de Negócio)', () {
    test('removerMascara remove pontos, traços, barras, parênteses e espaços', () {
      expect(removerMascara('12.345.678/0001-95'), '12345678000195');
      expect(removerMascara('01001-000'), '01001000');
      expect(removerMascara('(11) 99999-8888'), '11999998888');
      expect(removerMascara(' 123 - 456 '), '123456');
    });

    test('salvarClienteOffline insere novo cliente PJ com autogeração de ID, UPPERCASE e XML em cli/', () async {
      final novoCliente = ClienteResultStruct(
        cli00Codigo: 0,
        cli00Descri: 'mercado silva e souza ltda',
        cli00Fantas: 'Mercado Silva',
        cli00Pessoa: 'J',
        cli00Cpfcnp: '12.345.678/0001-95',
        cli00Insest: '109876543',
        cli00Observ: 'contato@mercadosilva.com.br',
        cli00Contat: 'nfe@mercadosilva.com.br',
        cli00Endere: 'Rua das Flores',
        cli00Endnum: '100',
        cli00Bairro: 'Centro',
        cli00Ciddes: 'Sao Paulo',
        cli00Estsgl: 'SP',
        cli00Endcep: '01001-000',
        cli00Fonddd: '(11)',
        cli00Fonnum: '3333-4444',
        cli00Crelim: 5000.0,
      );

      final resultado = await salvarClienteOffline(
        clienteData: novoCliente,
        codigoVendedor: '71',
        tempDirOverride: tempDir,
        docsDirOverride: docsDir,
      );

      expect(resultado.success, isTrue);
      expect(resultado.clienteId, greaterThan(0));
      expect(resultado.xmlPath, isNotNull);
      expect(resultado.xmlNome, startsWith('c71-'));
      expect(resultado.xmlNome, endsWith('.xml'));

      // Verifica no SQLite (cadcli00)
      final db = await LocalSalesDatabaseService.getDatabase();
      final rows = await db.rawQuery(
        'SELECT * FROM cadcli00 WHERE cli00_codigo = ?',
        [resultado.clienteId],
      );
      expect(rows, hasLength(1));
      final r = rows.first;
      expect(r['cli00_descri'], 'MERCADO SILVA E SOUZA LTDA'); // UPPERCASE
      expect(r['cli00_cpfcnp'], '12345678000195'); // Sem máscara
      expect(r['cli00_endcep'], '01001000'); // Sem máscara
      expect(r['cli00_fonddd'], '11');
      expect(r['cli00_fonnum'], '33334444');
      expect(r['cli00_insest'], '109876543');
      expect(r['cli00_typpes'], 2); // 2 = PJ
      expect(r['cli00_active'], 1);
      expect(r['cli00_sttenv'], 0); // Pendente de envio
      expect(r['cli00_endcob'], 'Rua das Flores'); // Copiado para cobrança

      // Verifica integridade do arquivo XML gerado na subpasta cli/
      final file = File(resultado.xmlPath!);
      expect(await file.exists(), isTrue);
      final content = await file.readAsString();
      expect(content, contains('cli00_codigo="${resultado.clienteId}"'));
      expect(content, contains('cli00_codigoRep="71"'));
      expect(content, contains('cli00_rSocial="MERCADO SILVA E SOUZA LTDA"'));
    });

    test('salvarClienteOffline insere cliente PF gravando Inscrição Estadual como "-" e RG em nrg', () async {
      final clientePf = ClienteResultStruct(
        cli00Codigo: 0,
        cli00Descri: 'Jose da Silva',
        cli00Fantas: 'Ze da Silva',
        cli00Pessoa: 'F',
        cli00Cpfcnp: '123.456.789-00',
        cli00Insest: 'Isento',
        cli02NRGProp: '44.555.666-X',
        cli00Endere: 'Av Brasil',
        cli00Endnum: '50',
        cli00Bairro: 'Jardim',
        cli00Ciddes: 'Campinas',
        cli00Estsgl: 'SP',
        cli00Endcep: '13000-000',
        cli00Fonddd: '19',
        cli00Fonnum: '98888-7777',
      );

      final resultado = await salvarClienteOffline(
        clienteData: clientePf,
        codigoVendedor: '71',
        tempDirOverride: tempDir,
        docsDirOverride: docsDir,
      );

      expect(resultado.success, isTrue);

      final db = await LocalSalesDatabaseService.getDatabase();
      final rows = await db.rawQuery(
        'SELECT * FROM cadcli00 WHERE cli00_codigo = ?',
        [resultado.clienteId],
      );
      expect(rows, hasLength(1));
      final r = rows.first;
      expect(r['cli00_descri'], 'JOSE DA SILVA');
      expect(r['cli00_cpfcnp'], '12345678900');
      expect(r['cli00_insest'], '-'); // Regra PF: '-'
      expect(r['cli00_nrg'], '44.555.666-X'); // RG persistido
      expect(r['cli00_typpes'], 1); // 1 = PF
    });

    test('salvarClienteOffline atualiza cliente existente (UPDATE) e gera XML com codigo16', () async {
      // Inicia com um cliente já existente
      final db = await LocalSalesDatabaseService.getDatabase();
      await db.rawInsert('''
        INSERT INTO cadcli00 (cli00_codigo, cli00_descri, cli00_fantas, cli00_cpfcnp, cli00_active, cli00_sttenv)
        VALUES (2780, 'CLIENTE ANTIGO', 'ANTIGO', '11122233344', 1, 2)
      ''');

      final clienteEditado = ClienteResultStruct(
        cli00Codigo: 2780,
        cli00Descri: 'Cliente Antigo Atualizado',
        cli00Fantas: 'Fantasia Nova',
        cli00Pessoa: 'F',
        cli00Cpfcnp: '111.222.333-44',
        cli00Endere: 'Rua Nova',
        cli00Endnum: '99',
        cli00Bairro: 'Bairro Novo',
        cli00Ciddes: 'Santos',
        cli00Estsgl: 'SP',
        cli00Endcep: '11000-000',
        cli00Fonddd: '13',
        cli00Fonnum: '3200-0000',
      );

      final resultado = await salvarClienteOffline(
        clienteData: clienteEditado,
        codigoVendedor: '71',
        tempDirOverride: tempDir,
        docsDirOverride: docsDir,
      );

      expect(resultado.success, isTrue);
      expect(resultado.clienteId, 2780);
      expect(resultado.xmlNome, 'c71-0000000000002780.xml'); // Nomenclatura oficial edição

      final rows = await db.rawQuery('SELECT * FROM cadcli00 WHERE cli00_codigo = 2780');
      expect(rows.first['cli00_descri'], 'CLIENTE ANTIGO ATUALIZADO');
      expect(rows.first['cli00_fantas'], 'Fantasia Nova');
      expect(rows.first['cli00_sttenv'], 0); // Volta para pendente após edição
    });

    test('pesquisaCliente encontra cliente recém-salvo mantendo conexão singleton aberta', () async {
      final cliente = ClienteResultStruct(
        cli00Codigo: 0,
        cli00Descri: 'Farmacia Nova Esperanca',
        cli00Fantas: 'Esperanca Farma',
        cli00Pessoa: 'J',
        cli00Cpfcnp: '99.888.777/0001-66',
        cli00Insest: '123456',
        cli00Endere: 'Rua Central',
        cli00Endnum: '1',
        cli00Bairro: 'Centro',
        cli00Ciddes: 'Curitiba',
        cli00Estsgl: 'PR',
        cli00Endcep: '80000-000',
        cli00Fonddd: '41',
        cli00Fonnum: '3000-0000',
      );

      final salvo = await salvarClienteOffline(
        clienteData: cliente,
        codigoVendedor: '71',
        tempDirOverride: tempDir,
        docsDirOverride: docsDir,
      );

      expect(salvo.success, isTrue);

      // Pesquisa pelo termo "Esperanca"
      final busca1 = await pesquisaCliente('Esperanca', 0);
      expect(busca1.any((c) => c.cli00Codigo == salvo.clienteId), isTrue);

      // Pesquisa por código
      final busca2 = await pesquisaCliente(salvo.clienteId.toString(), 0);
      expect(busca2.any((c) => c.cli00Codigo == salvo.clienteId), isTrue);

      // Garante que o banco continua aberto para transações subsequentes
      final db = await LocalSalesDatabaseService.getDatabase();
      expect(db.isOpen, isTrue);
    });
  });
}
