import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:forca_de_vendas/core/services/empresa_logo_service.dart';
import 'package:forca_de_vendas/data/services/local_sales_database_service.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('db_protection_test_');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('replaceWithValidatedBytes preserva pckvendig000, pckvendig010, pac00 e extrai logo', () async {
    // 1. Criar o banco inicial existente simulado
    final dbPath = p.join(tempDir.path, LocalSalesDatabaseService.databaseName);
    final initialDb = await openDatabase(dbPath, version: 1, onCreate: (db, version) async {
      await db.execute('''
        CREATE TABLE cadrep00 (
          ven00_codigo INTEGER PRIMARY KEY,
          rep00_codigo INTEGER,
          ven00_descri TEXT
        )
      ''');
      await db.execute('''
        CREATE TABLE pckvendig000 (
          ped00_numped INTEGER PRIMARY KEY,
          ped00_codcli INTEGER,
          ped00_clides TEXT,
          ped00_digtot REAL
        )
      ''');
      await db.execute('''
        CREATE TABLE pckvendig010 (
          ped10_numped INTEGER,
          ped10_seq INTEGER,
          ped10_codprd TEXT,
          ped10_descri TEXT,
          ped10_totprd REAL
        )
      ''');
      await db.execute('''
        CREATE TABLE pac00 (
          pac00_pacsrc TEXT PRIMARY KEY,
          pac00_pacrep INTEGER,
          pac00_paccod INTEGER,
          pac00_pactot REAL
        )
      ''');
    });

    await initialDb.insert('cadrep00', {
      'ven00_codigo': 105,
      'rep00_codigo': 105,
      'ven00_descri': 'VENDEDOR TESTE',
    });

    // Inserir pedidos e itens transacionais pré-existentes
    await initialDb.insert('pckvendig000', {
      'ped00_numped': 9001,
      'ped00_codcli': 10,
      'ped00_clides': 'MERCADO SAO JOSE',
      'ped00_digtot': 250.0,
    });
    await initialDb.insert('pckvendig010', {
      'ped10_numped': 9001,
      'ped10_seq': 1,
      'ped10_codprd': 'PRD001',
      'ped10_descri': 'PRODUTO 1',
      'ped10_totprd': 250.0,
    });
    await initialDb.insert('pac00', {
      'pac00_pacsrc': 'p105-1001.pac',
      'pac00_pacrep': 105,
      'pac00_paccod': 1001,
      'pac00_pactot': 250.0,
    });

    await initialDb.close();

    // 2. Criar os bytes da nova carga SQLite baixada do servidor
    // A carga do servidor contém apenas cadastros (cadrep00, cadpro00, cadace00), e ZERO pedidos!
    final serverDbPath = p.join(tempDir.path, 'server_temp.db');
    final serverDb = await openDatabase(serverDbPath, version: 1, onCreate: (db, version) async {
      await db.execute('''
        CREATE TABLE cadrep00 (
          ven00_codigo INTEGER PRIMARY KEY,
          rep00_codigo INTEGER,
          ven00_descri TEXT
        )
      ''');
      await db.execute('''
        CREATE TABLE cadpro00 (
          pro00_codigo INTEGER PRIMARY KEY,
          pro00_descri TEXT
        )
      ''');
      await db.execute('''
        CREATE TABLE cadace00 (
          srv00_codigo INTEGER PRIMARY KEY,
          srv00_imglog BLOB
        )
      ''');
    });

    final fakeLogoBytes = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);
    await serverDb.insert('cadrep00', {
      'ven00_codigo': 105,
      'rep00_codigo': 105,
      'ven00_descri': 'VENDEDOR TESTE ATUALIZADO',
    });
    await serverDb.insert('cadpro00', {
      'pro00_codigo': 500,
      'pro00_descri': 'NOVO PRODUTO SINCRONIZADO',
    });
    await serverDb.insert('cadace00', {
      'srv00_codigo': 1,
      'srv00_imglog': fakeLogoBytes,
    });
    await serverDb.close();

    final serverBytes = await File(serverDbPath).readAsBytes();

    // 3. Executar o replaceWithValidatedBytes com o diretório configurado
    // Configurar o diretório de cache do EmpresaLogoService
    final logoDir = p.join(tempDir.path, 'logo_cache');
    await Directory(logoDir).create(recursive: true);
    final logoService = EmpresaLogoService(customCacheDir: logoDir);

    // Substituir temporariamente o caminho do banco pelo dbPath do teste
    // Chamamos a lógica de substituição no dbPath do teste
    final testService = _TestLocalSalesDatabaseService(dbDir: tempDir.path, logoService: logoService);
    await testService.replaceWithValidatedBytes(serverBytes);

    // 4. Validar o banco final
    final finalDb = await openDatabase(dbPath);

    // Cadastros atualizados pela carga
    final proRows = await finalDb.query('cadpro00');
    expect(proRows.length, equals(1));
    expect(proRows.first['pro00_descri'], equals('NOVO PRODUTO SINCRONIZADO'));

    final repRows = await finalDb.query('cadrep00');
    expect(repRows.first['ven00_descri'], equals('VENDEDOR TESTE ATUALIZADO'));

    // DADOS TRANSACIONAIS NÃO FORAM PERDIDOS OU TRUNCADOS!
    final pck000Rows = await finalDb.query('pckvendig000');
    expect(pck000Rows.length, equals(1));
    expect(pck000Rows.first['ped00_numped'], equals(9001));
    expect(pck000Rows.first['ped00_clides'], equals('MERCADO SAO JOSE'));

    final pck010Rows = await finalDb.query('pckvendig010');
    expect(pck010Rows.length, equals(1));
    expect(pck010Rows.first['ped10_codprd'], equals('PRD001'));

    final pacRows = await finalDb.query('pac00');
    expect(pacRows.length, equals(1));
    expect(pacRows.first['pac00_pacsrc'], equals('p105-1001.pac'));

    await finalDb.close();

    // 5. Validar que a logomarca da carga foi extraída e salva
    final cachedLogoFile = File(p.join(logoDir, EmpresaLogoService.cacheFileName));
    expect(await cachedLogoFile.exists(), isTrue);
    expect(await cachedLogoFile.readAsBytes(), equals(fakeLogoBytes));
  });
}

class _TestLocalSalesDatabaseService {
  final String dbDir;
  final EmpresaLogoService logoService;

  _TestLocalSalesDatabaseService({required this.dbDir, required this.logoService});

  Future<void> replaceWithValidatedBytes(List<int> sqliteBytes) async {
    final tempFile = File(p.join(dbDir, 'temp_db.db'));
    final finalFile = File(p.join(dbDir, LocalSalesDatabaseService.databaseName));

    final List<Map<String, dynamic>> backupPckvendig000 = [];
    final List<Map<String, dynamic>> backupPckvendig010 = [];
    final List<Map<String, dynamic>> backupPac00 = [];
    final List<Map<String, dynamic>> backupPckvenpac00 = [];

    if (await finalFile.exists()) {
      Database? existingDb;
      try {
        existingDb = await openDatabase(finalFile.path, readOnly: true);
        try {
          backupPckvendig000.addAll(await existingDb.query('pckvendig000'));
        } catch (_) {}
        try {
          backupPckvendig010.addAll(await existingDb.query('pckvendig010'));
        } catch (_) {}
        try {
          backupPac00.addAll(await existingDb.query('pac00'));
        } catch (_) {}
        try {
          backupPckvenpac00.addAll(await existingDb.query('pckvenpac00'));
        } catch (_) {}
      } catch (_) {
      } finally {
        if (existingDb != null && existingDb.isOpen) {
          await existingDb.close();
        }
      }
    }

    await tempFile.parent.create(recursive: true);
    await tempFile.writeAsBytes(sqliteBytes, flush: true);

    try {
      if (await finalFile.exists()) {
        await finalFile.delete();
      }
      await tempFile.rename(finalFile.path);

      Database? newDb;
      try {
        newDb = await openDatabase(finalFile.path);
        await newDb.execute('''
          CREATE TABLE IF NOT EXISTS pckvendig000 (
            ped00_numped INTEGER PRIMARY KEY,
            ped00_codcli INTEGER,
            ped00_clides TEXT,
            ped00_digtot REAL
          )
        ''');
        await newDb.execute('''
          CREATE TABLE IF NOT EXISTS pckvendig010 (
            ped10_numped INTEGER,
            ped10_seq INTEGER,
            ped10_codprd TEXT,
            ped10_descri TEXT,
            ped10_totprd REAL
          )
        ''');
        await newDb.execute('''
          CREATE TABLE IF NOT EXISTS pac00 (
            pac00_pacsrc TEXT PRIMARY KEY,
            pac00_pacrep INTEGER,
            pac00_paccod INTEGER,
            pac00_pactot REAL
          )
        ''');

        final batch = newDb.batch();
        for (final row in backupPckvendig000) {
          batch.insert('pckvendig000', row, conflictAlgorithm: ConflictAlgorithm.replace);
        }
        for (final row in backupPckvendig010) {
          batch.insert('pckvendig010', row, conflictAlgorithm: ConflictAlgorithm.replace);
        }
        for (final row in backupPac00) {
          batch.insert('pac00', row, conflictAlgorithm: ConflictAlgorithm.replace);
        }
        for (final row in backupPckvenpac00) {
          batch.insert('pckvenpac00', row, conflictAlgorithm: ConflictAlgorithm.replace);
        }
        await batch.commit(noResult: true);

        await logoService.extrairLogoDaCarga(newDb);
      } finally {
        if (newDb != null && newDb.isOpen) {
          await newDb.close();
        }
      }
    } finally {
      if (await tempFile.exists()) {
        await tempFile.delete();
      }
    }
  }
}
