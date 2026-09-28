import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:flutter/material.dart';
import 'package:forca_de_vendas/app_state.dart';
import 'package:forca_de_vendas/backend/ftp/ftp_transport.dart';
import 'package:forca_de_vendas/pages/envio/envio_page_widget.dart';
import 'package:forca_de_vendas/services/carga_database_service.dart';
import 'package:forca_de_vendas/services/ftp_upload_service.dart';
import 'package:forca_de_vendas/services/sincronizacao_service.dart';
import 'package:forca_de_vendas/services/status_envio_db.dart';

class MockFtpTransport implements FtpTransport {
  MockFtpTransport({
    List<String>? initialFiles,
    this.simulateRenameOnPoll = false,
    this.simulateRetFileOnPoll = false,
    this.renameExtension = '.pro',
  }) : remoteFiles = List.from(initialFiles ?? []);

  final List<String> remoteFiles;
  final bool simulateRenameOnPoll;
  final bool simulateRetFileOnPoll;
  final String renameExtension;

  String currentDir = '/';
  int nlstCalls = 0;
  final List<String> storedFiles = [];

  Future<void> connect(String host, int port) async {}

  @override
  Future<void> cwd(String path) async {
    currentDir = path;
  }

  @override
  Future<void> mkd(String path) async {}

  @override
  Future<void> stor(String remoteName, List<int> bytes,
      {void Function(int sent)? onProgress}) async {
    storedFiles.add(remoteName);
    remoteFiles.add(remoteName);
    onProgress?.call(bytes.length);
  }

  @override
  Future<List<int>> retr(String remoteName) async {
    return [60, 114, 111, 119, 47, 62]; // "<row/>"
  }

  @override
  Future<int> size(String remoteName) async {
    return 100;
  }

  @override
  Future<List<String>> nlst([String? path]) async {
    nlstCalls++;
    if (nlstCalls >= 2) {
      if (simulateRenameOnPoll) {
        // Renomeia qualquer arquivo .pac para .pro
        for (int i = 0; i < remoteFiles.length; i++) {
          if (remoteFiles[i].endsWith('.pac')) {
            remoteFiles[i] = remoteFiles[i].replaceAll('.pac', renameExtension);
          }
        }
      } else if (simulateRetFileOnPoll) {
        // Gera arquivo .ret
        for (final f in List<String>.from(remoteFiles)) {
          if (f.startsWith('p') && f.endsWith('.pac')) {
            final retName = 'r${f.substring(1).replaceAll(".pac", ".ret")}';
            if (!remoteFiles.contains(retName)) {
              remoteFiles.add(retName);
            }
          }
        }
      }
    }
    return List.from(remoteFiles);
  }

  @override
  Future<void> rename(String from, String to) async {
    final idx = remoteFiles.indexOf(from);
    if (idx != -1) {
      remoteFiles[idx] = to;
    }
  }

  @override
  Future<void> dele(String remoteName) async {
    remoteFiles.remove(remoteName);
  }

  @override
  Future<void> quit() async {}
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AppState().initializePersistedState();
  });

  group('SPEC-056: Leitura de Campos da Carga (cadcfg00 e cadrep00)', () {
    late String dbPath;
    late Database db;

    setUp(() async {
      final tempDir = await Directory.systemTemp.createTemp('spec056_carga_');
      dbPath = p.join(tempDir.path, 'dbforcacad001.db');
      db = await openDatabase(
        dbPath,
        version: 1,
        onCreate: (d, v) async {
          await d.execute('''
            CREATE TABLE cadcfg00 (
              cfg00_numcar INTEGER,
              cfg00_datcar TEXT,
              cfg00_versis TEXT
            );
          ''');
          await d.execute('''
            CREATE TABLE cadrep00 (
              ven00_codigo INTEGER PRIMARY KEY,
              ven00_codeqp INTEGER,
              ven00_codfil INTEGER,
              ven00_nome TEXT
            );
          ''');
        },
      );
    });

    tearDown(() async {
      await db.close();
      try {
        final f = File(dbPath);
        if (await f.exists()) await f.delete();
      } catch (_) {}
    });

    test('Lê sequencial, data da carga, versão do sistema e equipe do vendedor', () async {
      await db.insert('cadcfg00', {
        'cfg00_numcar': 1054,
        'cfg00_datcar': '2026-09-28 10:30:00',
        'cfg00_versis': '2.4.15',
      });

      await db.insert('cadrep00', {
        'ven00_codigo': 71,
        'ven00_codeqp': 12,
        'ven00_codfil': 1,
        'ven00_nome': 'Vendedor Teste',
      });

      AppState().vendedor_codigo = 71;

      final service = CargaDatabaseService();
      final resultado = await service.processarCamposCarga(
        db: db,
        vendedorCodigo: 71,
      );

      expect(resultado.sequencialCarga, equals(1054));
      expect(resultado.versaoSistema, equals('2.4.15'));
      expect(resultado.equipeVendedor, equals(12));
      expect(resultado.filialVendedor, equals(1));

      // Verifica reflexo no AppState
      expect(AppState().sequencialCarga, equals(1054));
      expect(AppState().versaoSistema, equals('2.4.15'));
      expect(AppState().vendedor_equipe, equals(12));

      // Formatação exigida na Home: "Última Carga: nº X em DD/MM/AAAA HH:MM"
      expect(
        AppState().dataHoraUltimaCargaFormatada,
        contains('Última Carga: nº 1054 em 28/09/2026 10:30'),
      );
    });

    test('Fallback de versão em srv00_verapp na tabela cadace00 ou cadcfg00', () async {
      await db.execute('DROP TABLE cadcfg00');
      await db.execute('''
        CREATE TABLE cadcfg00 (
          cfg00_numcar INTEGER,
          cfg00_datcar TEXT
        );
      ''');
      await db.execute('''
        CREATE TABLE cadace00 (
          srv00_verapp TEXT
        );
      ''');

      await db.insert('cadcfg00', {
        'cfg00_numcar': 42,
        'cfg00_datcar': '2026-09-28 14:00:00',
      });
      await db.insert('cadace00', {
        'srv00_verapp': '3.0.0',
      });

      final service = CargaDatabaseService();
      final resultado = await service.processarCamposCarga(
        db: db,
        vendedorCodigo: 71,
      );

      expect(resultado.versaoSistema, equals('3.0.0'));
      expect(AppState().versaoSistema, equals('3.0.0'));
      expect(resultado.sequencialCarga, equals(42));
    });

    test('SincronizacaoService atualiza perfil do vendedor e log de carga', () async {
      await db.execute('DROP TABLE IF EXISTS cadcfg00');
      await db.execute('DROP TABLE IF EXISTS cadrep00');
      await db.execute('''
        CREATE TABLE cadcfg00 (
          cfg00_numcar INTEGER,
          cfg00_datcar TEXT,
          cfg00_versis TEXT
        );
      ''');
      await db.execute('''
        CREATE TABLE cadrep00 (
          ven00_codigo INTEGER PRIMARY KEY,
          ven00_codeqp INTEGER,
          ven00_codfil INTEGER,
          ven00_nome TEXT
        );
      ''');

      await db.insert('cadcfg00', {
        'cfg00_numcar': 2048,
        'cfg00_datcar': '2026-09-28 15:45:00',
        'cfg00_versis': '4.1.0',
      });
      await db.insert('cadrep00', {
        'ven00_codigo': 99,
        'ven00_codeqp': 55,
        'ven00_codfil': 2,
        'ven00_nome': 'Representante Suportware',
      });

      final sincService = SincronizacaoService();
      final res = await sincService.processarCamposCarga(db: db, vendedorCodigo: 99);

      expect(res.sequencialCarga, equals(2048));
      expect(res.versaoSistema, equals('4.1.0'));
      expect(res.equipeVendedor, equals(55));
      expect(res.filialVendedor, equals(2));

      expect(AppState().sequencialCarga, equals(2048));
      expect(AppState().versaoSistema, equals('4.1.0'));
      expect(AppState().vendedor_equipe, equals(55));
      expect(AppState().vendedor_nome, equals('Representante Suportware'));
      expect(AppState().logUltimaCarga, contains('seq=2048'));
      expect(AppState().logUltimaCarga, contains('equipe=55'));
    });
  });

  group('SPEC-056: Rotina de Envio com Aguardo de Retorno FTP', () {
    late String dbDigPath;
    late Database dbDig;

    setUp(() async {
      final tempDir = await Directory.systemTemp.createTemp('spec056_dig_');
      dbDigPath = p.join(tempDir.path, 'dbforcadig001.db');
      dbDig = await openDatabase(
        dbDigPath,
        version: 1,
        onCreate: (d, v) async {
          await d.execute('''
            CREATE TABLE pckvendig000 (
              ped00_numped INTEGER PRIMARY KEY,
              ped00_pacstr TEXT,
              ped00_sttenv INTEGER DEFAULT 0
            );
          ''');
          await d.execute('''
            CREATE TABLE pac00 (
              pac00_pacsrc TEXT PRIMARY KEY,
              pac00_sttenv INTEGER DEFAULT 0,
              pac00_sttpac INTEGER DEFAULT 0
            );
          ''');
        },
      );

      await dbDig.insert('pckvendig000', {
        'ped00_numped': 501,
        'ped00_pacstr': 'p71-1001.pac',
        'ped00_sttenv': 1, // Empacotado
      });
      await dbDig.insert('pac00', {
        'pac00_pacsrc': 'p71-1001.pac',
        'pac00_sttenv': 0,
        'pac00_sttpac': 0,
      });
    });

    tearDown(() async {
      await dbDig.close();
      try {
        final f = File(dbDigPath);
        if (await f.exists()) await f.delete();
      } catch (_) {}
    });

    test('Confirma processamento quando o arquivo .pac é renomeado pela retaguarda (.pro)', () async {
      final mockFtp = MockFtpTransport(
        initialFiles: ['p71-1001.pac'],
        simulateRenameOnPoll: true,
        renameExtension: '.pro',
      );

      final statusDb = StatusEnvioDb(dbPath: dbDigPath);
      final uploadService = FtpUploadService(
        connectFtp: () async => mockFtp,
        statusDb: statusDb,
      );

      final result = await uploadService.aguardarRetornoPacote(
        empresa: 'diniz',
        codigoEquipe: 12,
        codRep: 71,
        ipac: 1001,
        intervalo: const Duration(milliseconds: 10),
        timeout: const Duration(milliseconds: 200),
      );

      expect(result.status, equals(PollingRetornoStatus.confirmado));
      expect(result.mensagem, contains('Processamento confirmado'));

      // Valida atualização dos pedidos para dig00_sttenv = 3
      final verifyDb1 = await openDatabase(dbDigPath);
      final rows = await verifyDb1.query('pckvendig000', where: 'ped00_numped = ?', whereArgs: [501]);
      expect(rows.first['ped00_sttenv'], equals(3));
      await verifyDb1.close();
    });

    test('Confirma processamento quando é gerado arquivo de retorno .ret', () async {
      final mockFtp = MockFtpTransport(
        initialFiles: ['p71-1001.pac'],
        simulateRetFileOnPoll: true,
      );

      final statusDb = StatusEnvioDb(dbPath: dbDigPath);
      final uploadService = FtpUploadService(
        connectFtp: () async => mockFtp,
        statusDb: statusDb,
      );

      final result = await uploadService.aguardarRetornoPacote(
        empresa: 'diniz',
        codigoEquipe: 12,
        codRep: 71,
        ipac: 1001,
        intervalo: const Duration(milliseconds: 10),
        timeout: const Duration(milliseconds: 200),
      );

      expect(result.status, equals(PollingRetornoStatus.confirmado));

      // Valida atualização dos pedidos para dig00_sttenv = 3
      final verifyDb2 = await openDatabase(dbDigPath);
      final rows = await verifyDb2.query('pckvendig000', where: 'ped00_numped = ?', whereArgs: [501]);
      expect(rows.first['ped00_sttenv'], equals(3));
      await verifyDb2.close();
    });

    test('Trata timeout após tempo limite sem lançar exceção', () async {
      // Mock que nunca renomeia e nunca gera retorno
      final mockFtp = MockFtpTransport(
        initialFiles: ['p71-1001.pac'],
        simulateRenameOnPoll: false,
        simulateRetFileOnPoll: false,
      );

      final statusDb = StatusEnvioDb(dbPath: dbDigPath);
      final uploadService = FtpUploadService(
        connectFtp: () async => mockFtp,
        statusDb: statusDb,
      );

      final result = await uploadService.aguardarRetornoPacote(
        empresa: 'diniz',
        codigoEquipe: 12,
        codRep: 71,
        ipac: 1001,
        intervalo: const Duration(milliseconds: 15),
        timeout: const Duration(milliseconds: 50),
      );

      expect(result.status, equals(PollingRetornoStatus.timeout));
      expect(
        result.mensagem,
        contains('Lote enviado, aguardando confirmação da retaguarda em segundo plano'),
      );

      // Os pedidos não são marcados como 3 no timeout, permanecem no estado de lote enviado
      final verifyDb3 = await openDatabase(dbDigPath);
      final rows = await verifyDb3.query('pckvendig000', where: 'ped00_numped = ?', whereArgs: [501]);
      expect(rows.first['ped00_sttenv'], isNot(3));
      await verifyDb3.close();
    });

    test('Utiliza dirPac customizado quando informado explicitamente', () async {
      final mockFtp = MockFtpTransport(
        initialFiles: ['p71-1001.pac'],
        simulateRenameOnPoll: true,
      );

      final statusDb = StatusEnvioDb(dbPath: dbDigPath);
      final uploadService = FtpUploadService(
        connectFtp: () async => mockFtp,
        statusDb: statusDb,
      );

      final result = await uploadService.aguardarRetornoPacote(
        empresa: 'diniz',
        codigoEquipe: 12,
        codRep: 71,
        ipac: 1001,
        dirPac: '/diniz/12/dirPAC/',
        intervalo: const Duration(milliseconds: 10),
        timeout: const Duration(milliseconds: 100),
      );

      expect(result.status, equals(PollingRetornoStatus.confirmado));
      expect(mockFtp.currentDir, equals('dirPAC'));
    });

    testWidgets('EnvioPageWidget renderiza elementos de controle e botão de transmissão', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: EnvioPageWidget(
            nomePacote: 'p71-1001.pac',
            sequencialPacote: 1001,
          ),
        ),
      );

      expect(find.text('Comunicação FTP (ffrmcom00)'), findsOneWidget);
      expect(find.text('Pacote: p71-1001.pac'), findsOneWidget);
      expect(find.text('Transmitir e Aguardar Retorno'), findsOneWidget);

      final popScopeFinder = find.byType(PopScope);
      expect(popScopeFinder, findsWidgets);
      final popScope = tester.widget<PopScope>(popScopeFinder.first);
      expect(popScope.canPop, isTrue);
    });
  });
}
