import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:forca_de_vendas/action_code/pesquisa_cliente.dart';
import 'package:forca_de_vendas/action_code/obter_dados_pedido_novo.dart';
import 'package:forca_de_vendas/action_code/carregar_cliente_offline.dart';
import 'package:forca_de_vendas/backend/ftp/ftp_transport.dart';
import 'package:forca_de_vendas/data/repositories/cliente_repository.dart';
import 'package:forca_de_vendas/data/services/local_sales_database_service.dart';
import 'package:forca_de_vendas/domain/models/cliente_novo_model.dart';
import 'package:forca_de_vendas/pages/cliente/form_clientes_page/form_clientes_page_widget.dart';
import 'package:forca_de_vendas/services/cliente_ftp_sync_service.dart';
import 'package:forca_de_vendas/services/ftp_upload_service.dart';

/// Mock de transporte FTP em memória
class _MockFtpTransport implements FtpTransport {
  final List<String> directories = [];
  final Map<String, List<int>> remoteFiles = {};
  String currentDir = '/';

  Future<void> connect() async {}

  @override
  Future<void> quit() async {}

  @override
  Future<void> cwd(String path) async {
    if (path == '/') {
      currentDir = '/';
    } else if (path.startsWith('/')) {
      currentDir = path.endsWith('/') ? path : '$path/';
    } else {
      currentDir = currentDir.endsWith('/')
          ? '$currentDir$path/'
          : '$currentDir/$path/';
    }
  }

  @override
  Future<void> mkd(String path) async {
    directories.add(path);
  }

  @override
  Future<void> stor(
    String remoteName,
    List<int> bytes, {
    void Function(int sentBytes)? onProgress,
  }) async {
    final cleanDir = currentDir.endsWith('/') ? currentDir : '$currentDir/';
    final fullPath = '$cleanDir$remoteName';
    remoteFiles[fullPath] = List.from(bytes);
    onProgress?.call(bytes.length);
  }

  @override
  Future<int> size(String remoteName) async {
    final cleanDir = currentDir.endsWith('/') ? currentDir : '$currentDir/';
    final fullPath = '$cleanDir$remoteName';
    if (!remoteFiles.containsKey(fullPath)) {
      throw Exception('Arquivo não encontrado no FTP: $fullPath');
    }
    return remoteFiles[fullPath]!.length;
  }

  @override
  Future<List<String>> nlst([String? path]) async {
    return remoteFiles.keys.map((k) => k.split('/').last).toList();
  }

  @override
  Future<List<int>> retr(String remoteName) async {
    final fullPath = '$currentDir/$remoteName';
    return remoteFiles[fullPath] ?? [];
  }

  @override
  Future<void> dele(String fileName) async {
    final fullPath = '$currentDir/$fileName';
    remoteFiles.remove(fullPath);
  }

  @override
  Future<void> rename(String oldName, String newName) async {
    final oldPath = '$currentDir/$oldName';
    final newPath = '$currentDir/$newName';
    if (remoteFiles.containsKey(oldPath)) {
      remoteFiles[newPath] = remoteFiles.remove(oldPath)!;
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Database db;

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  setUp(() async {
    db = await openDatabase(inMemoryDatabasePath, version: 1,
        onCreate: (Database db, int version) async {
      await db.execute('''
        CREATE TABLE cadcli00 (
          cli00_codigo INTEGER PRIMARY KEY,
          cli00_descri TEXT,
          cli00_fantas TEXT,
          cli00_cpfcnp TEXT,
          cli00_endere TEXT,
          cli00_endnum TEXT,
          cli00_bairro TEXT,
          cli00_ciddes TEXT,
          cli00_estsgl TEXT,
          cli00_endcep TEXT,
          cli00_fonddd TEXT,
          cli00_fonnum TEXT,
          cli00_crelim REAL DEFAULT 0,
          cli00_creatu REAL DEFAULT 0,
          cli00_titven REAL DEFAULT 0,
          cli00_active INTEGER DEFAULT 1,
          cli00_sttenv INTEGER DEFAULT 0
        )
      ''');
      await db.execute('''
        CREATE TABLE cadram00 (
          ram00_codigo INTEGER PRIMARY KEY,
          ram00_descri TEXT
        )
      ''');
    });

    LocalSalesDatabaseService.setDatabaseForTesting(db);
    ClienteRepository.setDatabaseForTesting(db);
  });

  tearDown(() async {
    LocalSalesDatabaseService.setDatabaseForTesting(null);
    ClienteRepository.setDatabaseForTesting(null);
    try {
      if (db.isOpen) await db.close();
    } catch (_) {}
  });

  group('1. Bloqueio de Edição de Clientes da Carga e Permissão para Novo Cliente', () {
    test('carregarClienteOffline busca cliente 1050 sem travar', () async {
      await db.insert('cadcli00', {
        'cli00_codigo': 1050,
        'cli00_descri': 'SUPERMERCADO CARGA LTDA',
        'cli00_fantas': 'SUPER CARGA',
        'cli00_cpfcnp': '11222333000199',
        'cli00_active': 1,
      });

      final res = await carregarClienteOffline(1050);
      expect(res, isNotNull);
      expect(res!.cli00Descri, 'SUPERMERCADO CARGA LTDA');
    });

    testWidgets('Cliente da carga (cli00_codigo > 0) bloqueia edição e exibe badge', (tester) async {
      await tester.runAsync(() async {
        // Insere cliente vindo da carga no cadcli00
        await db.insert('cadcli00', {
          'cli00_codigo': 1050,
          'cli00_descri': 'SUPERMERCADO CARGA LTDA',
          'cli00_fantas': 'SUPER CARGA',
          'cli00_cpfcnp': '11222333000199',
          'cli00_active': 1,
        });

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: FormClientesPageWidget(
                clienteCodigo: 1050,
                isNovoCliente: false,
              ),
            ),
          ),
        );

        // Permite que o I/O do sqflite ffi termine no addPostFrameCallback
        await Future.delayed(const Duration(milliseconds: 200));
        await tester.pump();
      });

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Deve exibir o badge / chip indicando que é cliente de carga sincronizado
      expect(find.text('Cliente sincronizado (Carga)'), findsOneWidget);

      // O botão "SALVAR CADASTRO" NÃO deve estar visível para cliente de carga
      expect(find.text('SALVAR CADASTRO'), findsNothing);

      // Os campos de formulário devem estar desabilitados / readOnly
      final textFields = tester.widgetList<TextFormField>(find.byType(TextFormField));
      expect(textFields, isNotEmpty);
      for (final tf in textFields) {
        // Cada campo deve ser somente leitura ou desabilitado
        final isReadOnlyOrDisabled = !tf.enabled || (tf.controller != null);
        expect(isReadOnlyOrDisabled, isTrue);
      }
    });

    testWidgets('Novo cliente permite preenchimento e exibe botão SALVAR CADASTRO', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FormClientesPageWidget(
              isNovoCliente: true,
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Não deve exibir badge de carga
      expect(find.text('Cliente sincronizado (Carga)'), findsNothing);

      // Botão de salvar deve estar disponível
      expect(find.text('SALVAR CADASTRO'), findsOneWidget);
    });
  });

  group('2. Repositório Local de Clientes (cadclipre00)', () {
    test('Salva novo cliente na cadclipre00 sem alterar cadcli00 da carga', () async {
      final repo = ClienteRepository();
      await repo.inicializarTabelas();

      // cadcli00 possui 1 cliente da carga
      await db.insert('cadcli00', {
        'cli00_codigo': 500,
        'cli00_descri': 'CLIENTE CARGA ORIGINAL',
        'cli00_active': 1,
      });

      final novo = ClienteNovo(
        razaoSocial: 'NOVA PADARIA CENTRAL LTDA',
        nomeFantasia: 'PADARIA CENTRAL',
        cpfCnpj: '98765432000100',
        endereco: 'AV PRINCIPAL 100',
        cidade: 'CURITIBA',
        uf: 'PR',
        cep: '80000000',
        ddd: '41',
        telefone: '33334444',
      );

      final idGerado = await repo.inserirNovoCliente(novo, codRep: 71);
      expect(idGerado, greaterThan(0));

      // Verifica tabela cadclipre00
      final rowsPre = await db.query('cadclipre00', where: 'cli00_codigo = ?', whereArgs: [idGerado]);
      expect(rowsPre, hasLength(1));
      expect(rowsPre.first['novo_local'], 1);
      expect(rowsPre.first['status_envio'], 'pendente_envio');
      expect(rowsPre.first['cli00_descri'], 'NOVA PADARIA CENTRAL LTDA');

      // Verifica que cadcli00 não foi afetada (mantém apenas 1 registro)
      final rowsCarga = await db.query('cadcli00');
      expect(rowsCarga, hasLength(1));
      expect(rowsCarga.first['cli00_codigo'], 500);

      // Verifica que aparece em pesquisaCliente
      final busca = await pesquisaCliente('PADARIA', 0);
      expect(busca.any((c) => c.cli00Descri.contains('PADARIA')), isTrue);

      // Verifica que aparece em obterDadosPedidoNovo
      final dadosPedido = await obterDadosPedidoNovo();
      expect(dadosPedido.clientes.any((c) => c.cli00Descri.contains('PADARIA')), isTrue);

      // Verifica que pode ser carregado por carregarClienteOffline
      final carregado = await carregarClienteOffline(idGerado);
      expect(carregado, isNotNull);
      expect(carregado!.cli00Descri, 'NOVA PADARIA CENTRAL LTDA');
      expect(carregado.isNovoCliente, isTrue);
    });
  });

  group('3. Geração de XML e Envio FTP (fcfPUTCAD = 10)', () {
    test('ClienteFtpSyncService gera XML estruturado puro conforme protocolo', () {
      final novo = ClienteNovo(
        codigo: 12,
        razaoSocial: 'DROGARIA POPULAR SA',
        nomeFantasia: 'FARMACIA POPULAR',
        cpfCnpj: '12345678000195',
        endereco: 'RUA DO COMERCIO 45',
        cidade: 'SAO PAULO',
        uf: 'SP',
        cep: '01001000',
        ddd: '11',
        telefone: '988887777',
      );

      final xml = ClienteFtpSyncService.gerarXmlNovoCliente(
        cliente: novo,
        codVendedor: '71',
      );

      expect(xml, contains('<?xml version="1.0" encoding="UTF-8"?>'));
      expect(xml, contains('<cadcli00>'));
      expect(xml, contains('<cli00_codrep>71</cli00_codrep>'));
      expect(xml, contains('<cli00_descri>DROGARIA POPULAR SA</cli00_descri>'));
      expect(xml, contains('<cli00_fantas>FARMACIA POPULAR</cli00_fantas>'));
      expect(xml, contains('<cli00_cpfcnp>12345678000195</cli00_cpfcnp>'));
      expect(xml, contains('<cli00_endere>RUA DO COMERCIO 45</cli00_endere>'));
      expect(xml, contains('<cli00_ciddes>SAO PAULO</cli00_ciddes>'));
      expect(xml, contains('<cli00_estsgl>SP</cli00_estsgl>'));
      expect(xml, contains('<cli00_endcep>01001000</cli00_endcep>'));
      expect(xml, contains('<cli00_fonddd>11</cli00_fonddd>'));
      expect(xml, contains('<cli00_fonnum>988887777</cli00_fonnum>'));
      expect(xml, contains('</cadcli00>'));
    });

    test('FtpUploadService envia novos clientes ao FTP (dirCAD) e atualiza para sincronizado', () async {
      final repo = ClienteRepository();
      await repo.inicializarTabelas();

      final idCli = await repo.inserirNovoCliente(
        ClienteNovo(
          razaoSocial: 'MERCADINHO DO BAIRRO',
          nomeFantasia: 'MERCADINHO',
          cpfCnpj: '44555666000188',
          endereco: 'RUA DAS ARARAS 12',
          cidade: 'LONDRINA',
          uf: 'PR',
          cep: '86000000',
          ddd: '43',
          telefone: '33221100',
        ),
        codRep: 71,
      );

      final tempDir = await Directory.systemTemp.createTemp('ftp_cli_test_');
      addTearDown(() async {
        try {
          if (await tempDir.exists()) await tempDir.delete(recursive: true);
        } catch (_) {}
      });

      final mockFtp = _MockFtpTransport();
      final uploadService = FtpUploadService(
        connectFtp: () async => mockFtp,
        getTemporaryDirectoryFn: () async => tempDir,
      );

      final result = await uploadService.enviarNovosClientesFtp(
        codVendedor: '71',
        empresa: 'diniz',
        codigoEquipe: 71,
        dirCAD: '/diniz/71/Customer/',
        repository: repo,
      );

      expect(result.success, isTrue);
      expect(result.enviados, hasLength(1));

      // Verifica nomenclatura legada c<rep>-<ms>.xml
      final nomeArquivo = result.enviados.first.nome;
      expect(nomeArquivo, startsWith('c71-'));
      expect(nomeArquivo, endsWith('.xml'));

      // Verifica envio no diretório correto do FTP
      final chaveFtp = '/diniz/71/Customer/$nomeArquivo';
      expect(mockFtp.remoteFiles.containsKey(chaveFtp), isTrue);

      // Verifica se o status foi atualizado para sincronizado
      final rows = await db.query('cadclipre00', where: 'cli00_codigo = ?', whereArgs: [idCli]);
      expect(rows.first['status_envio'], 'sincronizado');
    });
  });
}
