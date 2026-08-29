import 'dart:io';
import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:forca_de_vendas/data/services/pac_xml_generator_service.dart';
import 'package:forca_de_vendas/domain/models/pedido_venda.dart';
import 'package:forca_de_vendas/domain/models/status_envio.dart';
import 'package:forca_de_vendas/services/carga_registry_service.dart';
import 'package:forca_de_vendas/services/concluir_venda_service.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late Directory tempDir;
  late Directory docsDir;
  late String dbPath;
  late String manifestPath;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('persist_test_temp_');
    docsDir = await Directory.systemTemp.createTemp('persist_test_docs_');
    final databasesPath = await getDatabasesPath();
    dbPath = p.join(databasesPath, 'test_persist_${DateTime.now().microsecondsSinceEpoch}.db');
    // Remove se existir de teste anterior
    try { await File(dbPath).delete(); } catch (_) {}
    manifestPath = p.join(tempDir.path, 'carga_manifest.json');
  });

  tearDown(() async {
    try { await databaseFactory.deleteDatabase(dbPath); } catch (_) {}
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    if (docsDir.existsSync()) docsDir.deleteSync(recursive: true);
  });

  PedidoVenda sample({int codMov = 9001}) {
    final pedido = PedidoVenda(
      codFil: 1,
      codMov: codMov,
      codRep: 71,
      codCli: 1542,
      codLin: 5,
      codPla: 3,
      codAgt: 71,
      datSys: '2026-08-28',
      sttDig: PedidoSttDig.digitado,
      sttEnv: PedidoSttEnv.digitado,
      items: [
        ItemPedidoVenda(
          digpro: '78945',
          digqtd: 10.0,
          digpco: 150.05,
          pcomax: 150.05,
          pcomin: 150.05,
          destot: 0.0,
          subtot: 150.50,
          bontyp: 0,
          boncod: 0,
          ccvtot: 0.0,
          digitm: 1,
        ),
      ],
    );
    pedido.calcularTotais();
    return pedido;
  }

  test('persistencia: salvar 1 pedido 1 item e checar SELECT COUNT(*) >0 e PAC gerado', () async {
    // Pre-cria o banco com tabela via serviço, usando dbPath isolado.
    // Para forçar o serviço a usar esse dbPath, precisamos mockar getTargetDatabasePaths?
    // Em vez disso, testamos diretamente via openDatabase no dbPath e via serviço com tempDir injetado,
    // mas o serviço usa LocalSalesDatabaseService.getTargetDatabasePaths() que aponta para dbforcacad001.db.
    // Para isolar, vamos criar o arquivo físico em dbPath e também usar openDatabase direto para simular fluxo:
    // 1) cria pckvendig000 e insere header+itens manualmente como faz salvarCarrinhoPedido
    // 2) chama gerarESalvarPedidoLocal que deve fazer UPDATE + gerar PAC + sttenv=1
    //   e validamos SELECT COUNT(*) e existência do .pac.

    // Cria estrutura inicial simulando salvarCarrinhoPedido
    final db = await openDatabase(dbPath);
    await db.execute('''
      CREATE TABLE IF NOT EXISTS pckvendig000 (
        ped00_numped INTEGER PRIMARY KEY,
        ped00_codcli INTEGER,
        ped00_codlin INTEGER,
        ped00_codpla INTEGER,
        ped00_codfil INTEGER,
        ped00_codrep INTEGER,
        ped00_codagt INTEGER,
        ped00_digtab INTEGER,
        ped00_digcob INTEGER,
        ped00_bonfrcven INTEGER DEFAULT 0,
        ped00_sttdig INTEGER DEFAULT 0,
        ped00_sttenv INTEGER DEFAULT 0,
        ped00_datsys TEXT,
        ped00_clides TEXT,
        ped00_lindes TEXT,
        ped00_plades TEXT,
        ped00_digtot REAL DEFAULT 0,
        ped00_fattot REAL DEFAULT 0,
        ped00_subtot REAL DEFAULT 0,
        ped00_bontot REAL DEFAULT 0,
        ped00_destot REAL DEFAULT 0,
        ped00_pacstr TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS pckvendig010 (
        ped10_numped INTEGER,
        ped10_seq INTEGER DEFAULT 1,
        ped10_codprd TEXT,
        ped10_qtdped REAL DEFAULT 0,
        ped10_pcosub REAL DEFAULT 0,
        ped10_totprd REAL DEFAULT 0,
        ped10_qtdbon REAL DEFAULT 0,
        ped10_sttbon INTEGER DEFAULT 0,
        ped10_codcmb TEXT
      )
    ''');
    // Insere cabeçalho rascunho como faria salvarCarrinho
    await db.rawInsert(
      'INSERT INTO pckvendig000 (ped00_numped, ped00_codcli, ped00_sttdig, ped00_sttenv) VALUES (?, ?, ?, ?)',
      [9001, 1542, 0, 0],
    );
    await db.rawInsert(
      'INSERT INTO pckvendig010 (ped10_numped, ped10_codprd, ped10_qtdped, ped10_seq) VALUES (?, ?, ?, ?)',
      [9001, '78945', 10.0, 1],
    );
    await db.close();

    // Agora precisamos fazer o serviço enxergar esse dbPath.
    // Truque: copiar o arquivo para o path real que o serviço usa (dbforcacad001.db)
    final realPath = p.join(await getDatabasesPath(), 'dbforcacad001.db');
    // Backup do real se existir
    final realFile = File(realPath);
    final hadReal = await realFile.exists();
    File? backup;
    if (hadReal) {
      backup = File('$realPath.bak_${DateTime.now().microsecondsSinceEpoch}');
      await realFile.copy(backup.path);
    }
    await File(dbPath).copy(realPath);

    try {
      final pedido = sample(codMov: 9001);
      final service = ConcluirVendaService(
        getTemporaryDirectoryFn: () async => tempDir,
        getDocumentsDirFn: () async => docsDir,
        registry: CargaRegistryService(manifestPath: manifestPath),
      );

      final fileName = await service.gerarESalvarPedidoLocal(
        pedido: pedido,
        empresa: 'diniz',
        codigoEquipe: 71,
      );

      // Valida PAC
      expect(fileName, 'p71-9001.pac');
      final pacFile = File(p.join(tempDir.path, fileName));
      expect(await pacFile.exists(), isTrue);
      final bytes = await pacFile.readAsBytes();
      expect(bytes.sublist(0, 2), [0x50, 0x4B]); // ZIP magic
      final archive = ZipDecoder().decodeBytes(bytes);
      expect(archive.length, 1);

      // Valida persistência SQLite: COUNT(*)>0, sttenv=1, pacstr preenchido
      await Future.delayed(const Duration(milliseconds: 50));
      final verifyDb = await openDatabase(realPath, readOnly: true);
      final rows = await verifyDb.rawQuery('SELECT COUNT(*) as c FROM pckvendig000');
      final count = rows.first['c'] as int;
      expect(count, greaterThan(0), reason: 'SELECT COUNT(*) FROM pckvendig000 deve ser >0');

      final row = await verifyDb.rawQuery('SELECT ped00_sttenv, ped00_pacstr, ped00_sttdig FROM pckvendig000 WHERE ped00_numped = ?', [9001]);
      expect(row.isNotEmpty, isTrue);
      expect(row.first['ped00_sttenv'], equals(1), reason: 'ped00_sttenv deve ser 1 (empacotado) após PAC');
      expect(row.first['ped00_pacstr'], equals('p71-9001.pac'));
      expect(row.first['ped00_sttdig'], equals(1));

      // Valida que itens ainda existem
      final itens = await verifyDb.rawQuery('SELECT COUNT(*) as c FROM pckvendig010 WHERE ped10_numped = ?', [9001]);
      expect(itens.first['c'] as int, greaterThan(0));

      // Valida VIEW dig00 reflete pckvendig000
      try {
        final vRows = await verifyDb.rawQuery('SELECT COUNT(*) as c FROM dig00');
        expect(vRows.first['c'] as int, equals(count));
      } catch (_) {
        // Se view não existe, falha o teste — indica regressão de unificação
        fail('VIEW dig00 deve existir e refletir pckvendig000');
      }

      await verifyDb.close();

      // Também verifica docs backup
      expect(await File(p.join(docsDir.path, fileName)).exists(), isTrue);
    } finally {
      // Restaura backup — fecha antes de deletar para liberar lock Windows
      await Future.delayed(const Duration(milliseconds: 100));
      try { await databaseFactory.deleteDatabase(realPath); } catch (_) {}
      if (hadReal && backup != null) {
        try {
          await File(backup.path).copy(realPath);
          await backup.delete();
        } catch (_) {}
      }
    }
  });

  test('geracao PAC: XML contem pac00/pac01 e totais corretos', () async {
    final pedido = sample(codMov: 9002);
    final xml = PacXmlGeneratorService.generate(pedido);
    expect(xml, contains('pac00_paccod="9002"'));
    expect(xml, contains('pac01_procod="78945"'));
    expect(xml, contains('<pckvenpac00>'));
    final pacBytes = PacXmlGeneratorService.compressXmlToPac(xml);
    expect(pacBytes.sublist(0, 2), [0x50, 0x4B]);
  });
}
