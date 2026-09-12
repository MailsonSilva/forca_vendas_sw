import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import '/core/services/empresa_logo_service.dart';

/// Responsavel pelo arquivo SQLite local da forca de vendas.
///
/// Mantem nomes de arquivos, gravacao temporaria e validacao da tabela critica
/// fora das actions para que a UI nao carregue regra de infraestrutura.
class LocalSalesDatabaseService {
  static const databaseName = 'dbforcacad001.db';
  /// Alias PRD compat — físico permanece dbforcacad001.db (sem renomear arquivo).
  static const aliasDig = 'dbforcadig001.db';
  static const _tempDatabaseName = 'temp_db.db';

  Future<File> get databaseFile async {
    final databasesPath = await getDatabasesPath();
    return File(p.join(databasesPath, databaseName));
  }

  /// Retorna o caminho absoluto do banco de dados SQLite unificado.
  static Future<String> getDatabasePath() async {
    final databasesPath = await getDatabasesPath();
    final pMain = p.join(databasesPath, databaseName);
    final pAlt = p.join(databasesPath, aliasDig);
    if (await File(pMain).exists()) return pMain;
    if (await File(pAlt).exists()) return pAlt;
    return pMain;
  }

  /// Retorna a instância aberta do banco de dados SQLite unificado com migração automática.
  static Future<Database> getDatabase({bool readOnly = false}) async {
    final path = await getDatabasePath();
    final db = await openDatabase(path, readOnly: readOnly);
    if (!readOnly) {
      try {
        await _ensureSchemaAndMigrate(db);
      } catch (_) {}
    }
    return db;
  }

  /// Garante a criação de tabelas e migração de colunas para bancos legados
  static Future<void> _ensureSchemaAndMigrate(Database db) async {
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
        ped10_descri TEXT,
        ped10_unidpri TEXT,
        ped10_qtdped REAL DEFAULT 0,
        ped10_pcosub REAL DEFAULT 0,
        ped10_totprd REAL DEFAULT 0,
        ped10_qtdbon REAL DEFAULT 0,
        ped10_sttbon INTEGER DEFAULT 0,
        ped10_codcmb TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS pac00 (
        pac00_pacrep INTEGER,
        pac00_paccod INTEGER,
        pac00_pacsrc TEXT PRIMARY KEY,
        pac00_pacdat TEXT,
        pac00_pacqtd INTEGER DEFAULT 0,
        pac00_pactot REAL DEFAULT 0,
        pac00_sttpac INTEGER DEFAULT 0,
        pac00_sttenv INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS pckvenpac00 (
        pac00_pacrep INTEGER,
        pac00_paccod INTEGER,
        pac00_pacsrc TEXT PRIMARY KEY,
        pac00_pacdat TEXT,
        pac00_pacqtd INTEGER DEFAULT 0,
        pac00_pactot REAL DEFAULT 0,
        pac00_sttpac INTEGER DEFAULT 0,
        pac00_sttenv INTEGER DEFAULT 0
      )
    ''');

    for (final e in {
      'ped00_numped': 'INTEGER',
      'ped00_codcli': 'INTEGER',
      'ped00_codlin': 'INTEGER',
      'ped00_codpla': 'INTEGER',
      'ped00_codfil': 'INTEGER',
      'ped00_codrep': 'INTEGER',
      'ped00_codagt': 'INTEGER',
      'ped00_digagt': 'INTEGER',
      'ped00_digcob': 'INTEGER',
      'ped00_digtab': 'INTEGER',
      'ped00_bonfrcven': 'INTEGER',
      'ped00_sttdig': 'INTEGER',
      'ped00_sttenv': 'INTEGER',
      'ped00_datsys': 'TEXT',
      'ped00_datemi': 'TEXT',
      'ped00_clides': 'TEXT',
      'ped00_lindes': 'TEXT',
      'ped00_plades': 'TEXT',
      'ped00_digtot': 'REAL',
      'ped00_fattot': 'REAL',
      'ped00_subtot': 'REAL',
      'ped00_bontot': 'REAL',
      'ped00_destot': 'REAL',
      'ped00_pacstr': 'TEXT',
      'ped00_fatmov': 'TEXT',
      'ped00_fatdat': 'TEXT',
      'ped00_fatobs': 'TEXT',
      'ped00_datret': 'TEXT',
      'ped00_ccvtot': 'REAL',
    }.entries) {
      try {
        await db.execute('ALTER TABLE pckvendig000 ADD COLUMN ${e.key} ${e.value}');
      } catch (_) {}
    }

    for (final e in {
      'ped10_numped': 'INTEGER',
      'ped10_seq': 'INTEGER',
      'ped10_codprd': 'TEXT',
      'ped10_descri': 'TEXT',
      'ped10_unidpri': 'TEXT',
      'ped10_qtdped': 'REAL',
      'ped10_pcosub': 'REAL',
      'ped10_totprd': 'REAL',
      'ped10_qtdbon': 'REAL',
      'ped10_sttbon': 'INTEGER',
      'ped10_codcmb': 'TEXT',
      'ped10_subtot': 'REAL',
      'ped10_valsub': 'REAL',
      'dig01_subtot': 'REAL',
      'ped10_destot': 'REAL',
      'dig01_destot': 'REAL',
      'ped10_fatqtd': 'REAL',
      'ped10_fatpco': 'REAL',
      'ped10_digitm': 'INTEGER',
      'ped10_ccvtot': 'REAL',
    }.entries) {
      try {
        await db.execute('ALTER TABLE pckvendig010 ADD COLUMN ${e.key} ${e.value}');
      } catch (_) {}
    }

    for (final e in {
      'cli00_codigo16': 'TEXT',
      'cli00_descri': 'TEXT',
      'cli00_fantas': 'TEXT',
      'cli00_flgven': 'INTEGER',
      'cli00_titven': 'REAL',
      'cli00_titave': 'REAL',
      'cli00_ciddes': 'TEXT',
      'cli00_estsgl': 'TEXT',
      'cli00_active': 'INTEGER',
      'cli00_typpes': 'INTEGER',
      'cli00_cpfcnp': 'TEXT',
      'cli00_insest': 'TEXT',
      'cli00_nrg': 'TEXT',
      'cli00_email': 'TEXT',
      'cli00_emaildanfe': 'TEXT',
      'cli00_ramo': 'TEXT',
      'cli00_endere': 'TEXT',
      'cli00_endnum': 'TEXT',
      'cli00_bairro': 'TEXT',
      'cli00_endcep': 'TEXT',
      'cli00_fonddd': 'TEXT',
      'cli00_fonnum': 'TEXT',
      'cli00_observ': 'TEXT',
      'cli00_descobs': 'TEXT',
      'cli00_endcob': 'TEXT',
      'cli00_numcob': 'TEXT',
      'cli00_bairrocob': 'TEXT',
      'cli00_cidadecob': 'TEXT',
      'cli00_ufcob': 'TEXT',
      'cli00_cepcob': 'TEXT',
      'cli00_dddcob': 'TEXT',
      'cli00_fonecob': 'TEXT',
      'cli00_sttenv': 'INTEGER DEFAULT 0',
      'cli00_crelim': 'REAL DEFAULT 0',
      'cli00_creatu': 'REAL DEFAULT 0',
    }.entries) {
      try {
        await db.execute('ALTER TABLE cadcli00 ADD COLUMN ${e.key} ${e.value}');
      } catch (_) {}
    }

    for (final e in {
      'pro00_descri': 'TEXT',
      'pro00_commax': 'REAL',
      'pro00_codbar': 'TEXT',
      'pro00_deslon': 'TEXT',
      'pro00_codmar': 'INTEGER',
      'pro00_codfab': 'INTEGER',
      'pro00_ref001': 'TEXT',
      'pro00_ref002': 'TEXT',
      'pro00_embala': 'TEXT',
      'pro00_unidad': 'TEXT',
      'pro00_codimg': 'INTEGER',
    }.entries) {
      try {
        await db.execute('ALTER TABLE cadpro00 ADD COLUMN ${e.key} ${e.value}');
      } catch (_) {}
    }


    for (final e in {
      'pac00_codlot': 'TEXT',
    }.entries) {
      try {
        await db.execute('ALTER TABLE pac00 ADD COLUMN ${e.key} ${e.value}');
      } catch (_) {}
    }

    // Tabelas para dados de retornos e cadastros
    await db.execute('''
      CREATE TABLE IF NOT EXISTS cadpro00 (
        pro00_codigo INTEGER,
        pro00_prifil INTEGER DEFAULT 1,
        pro00_qtdest REAL DEFAULT 0,
        pro00_codbar TEXT,
        pro00_descri TEXT,
        pro00_deslon TEXT,
        pro00_codmar INTEGER,
        pro00_codfab INTEGER,
        pro00_ref001 TEXT,
        pro00_ref002 TEXT,
        pro00_embala TEXT,
        pro00_unidad TEXT,
        pro00_codimg INTEGER,
        PRIMARY KEY (pro00_codigo, pro00_prifil)
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS cadmar00 (
        mar00_codigo INTEGER PRIMARY KEY,
        mar00_descri TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS cadfor00 (
        for00_codigo INTEGER PRIMARY KEY,
        for00_descri TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS cadcli00 (
        cli00_codigo INTEGER PRIMARY KEY,
        cli00_crelim REAL DEFAULT 0,
        cli00_creatu REAL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS estfatdat00 (
        dat00_dattim TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS estfatcvd00 (
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
      CREATE TABLE IF NOT EXISTS fincaidat00 (
        dat00_dattim TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS fincaiccv01 (
        ccv01_codfil INTEGER,
        ccv01_codven INTEGER,
        ccv01_vlrsal REAL DEFAULT 0,
        ccv01_vlrusedig REAL DEFAULT 0,
        ccv01_vlrusepck REAL DEFAULT 0,
        ccv01_vlrsalatu REAL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS fincaimovccv00 (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        ccv00_codfil INTEGER,
        ccv00_codven INTEGER,
        ccv00_datmov TEXT,
        ccv00_typmov TEXT,
        ccv00_vlrmov REAL DEFAULT 0,
        ccv00_vlrsal REAL DEFAULT 0,
        ccv00_observ TEXT
      )
    ''');

    // Tabela de duplicatas / contas a receber (dup00)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS dup00 (
        dup00_codigo INTEGER PRIMARY KEY,
        dup00_codcli INTEGER,
        dup00_datemi TEXT,
        dup00_datven TEXT,
        dup00_valori REAL DEFAULT 0,
        dup00_valdev REAL DEFAULT 0,
        dup00_valpag REAL DEFAULT 0,
        dup00_codven INTEGER,
        dup00_codagt INTEGER,
        dup00_codcob INTEGER
      )
    ''');
    try { await db.execute('CREATE INDEX IF NOT EXISTS idx_dup00_codcli ON dup00 (dup00_codcli)'); } catch (_) {}
    try { await db.execute('CREATE INDEX IF NOT EXISTS idx_dup00_datven ON dup00 (dup00_datven)'); } catch (_) {}

    // Garantir coluna de taxa de juros do representante
    try {
      await db.execute('ALTER TABLE cadrep00 ADD COLUMN ven00_txajur REAL DEFAULT 0');
    } catch (_) {}

    // Views de compatibilidade dig00 / dig01 / dup00 / cli00
    try { await db.execute('DROP VIEW IF EXISTS dig00'); } catch (_) {}
    try { await db.execute('CREATE VIEW IF NOT EXISTS dig00 AS SELECT * FROM pckvendig000'); } catch (_) {}
    try { await db.execute('DROP VIEW IF EXISTS dig01'); } catch (_) {}
    try { await db.execute('CREATE VIEW IF NOT EXISTS dig01 AS SELECT * FROM pckvendig010'); } catch (_) {}
    try { await db.execute('DROP VIEW IF EXISTS findup00'); } catch (_) {}
    try { await db.execute('CREATE VIEW IF NOT EXISTS cadrecdup00 AS SELECT * FROM dup00'); } catch (_) {}
    try { await db.execute('DROP VIEW IF EXISTS cli00'); } catch (_) {}
    try { await db.execute('CREATE VIEW IF NOT EXISTS cli00 AS SELECT * FROM cadcli00'); } catch (_) {}
  }


  /// Obtém o próximo código sequencial para novo cliente local
  static Future<int> obterProximoCodigoCliente() async {
    final db = await getDatabase();
    try {
      final rows = await db.rawQuery('SELECT IFNULL(MAX(cli00_codigo), 0) AS max_cod FROM cadcli00');
      if (rows.isNotEmpty) {
        final val = rows.first['max_cod'];
        final n = (val is num) ? val.toInt() : (int.tryParse(val?.toString() ?? '') ?? 0);
        return n > 0 ? n + 1 : 1;
      }
      return 1;
    } catch (_) {
      return 1;
    }
  }


  /// Obtém o próximo sequencial de pacote incremental (range 1000..9999).
  /// Conforme especificação Suportware: txtven00_pacseq inicia em 1000 e vai até 9999.
  static Future<int> obterProximoSequencialPacote(int codRep) async {
    final db = await getDatabase();
    int currentSeq = 0;

    // 1. Tenta buscar no cadastro do representante cadrep00
    try {
      final rows = await db.rawQuery('SELECT * FROM cadrep00 WHERE ven00_codigo = ? OR rep00_codigo = ? LIMIT 1', [codRep, codRep]);
      if (rows.isNotEmpty) {
        final r = rows.first;
        for (final k in ['txtven00_pacseq', 'ven00_pacseq', 'pacseq', 'rep00_pacseq']) {
          if (r.containsKey(k) && r[k] != null) {
            currentSeq = int.tryParse(r[k].toString()) ?? 0;
            if (currentSeq > 0) break;
          }
        }
      }
    } catch (_) {}

    // 2. Tenta buscar o maior sequencial gravado na tabela pac00
    if (currentSeq == 0) {
      try {
        final rows = await db.rawQuery('SELECT MAX(pac00_paccod) as max_seq FROM pac00 WHERE pac00_pacrep = ?', [codRep]);
        if (rows.isNotEmpty && rows.first['max_seq'] != null) {
          final s = int.tryParse(rows.first['max_seq'].toString()) ?? 0;
          if (s > currentSeq) currentSeq = s;
        }
      } catch (_) {}
    }

    int nextSeq = (currentSeq >= 1000) ? currentSeq + 1 : 1000;
    if (nextSeq > 9999) {
      nextSeq = 1000; // Rollover conforme especificação
    }

    // Tenta atualizar no cadrep00 se a tabela/coluna existir
    try {
      await db.rawUpdate('UPDATE cadrep00 SET txtven00_pacseq = ? WHERE ven00_codigo = ? OR rep00_codigo = ?', [nextSeq, codRep, codRep]);
    } catch (_) {}

    return nextSeq;
  }


  /// Retorna todos os caminhos de bancos existentes no dispositivo (principal e alias)
  /// para garantir sincronização de escrita caso ambos os arquivos existam.
  static Future<List<String>> getTargetDatabasePaths() async {
    final databasesPath = await getDatabasesPath();
    final pMain = p.join(databasesPath, databaseName);
    final pAlt = p.join(databasesPath, aliasDig);
    final list = <String>[];
    if (await File(pMain).exists()) list.add(pMain);
    if (await File(pAlt).exists() && pAlt != pMain && !list.contains(pAlt)) list.add(pAlt);
    if (list.isEmpty) list.add(pMain);
    return list;
  }

  Future<Database> getDb({bool readOnly = false}) async {
    return getDatabase(readOnly: readOnly);
  }

  Future<bool> exists() async {
    final file = await databaseFile;
    return await file.exists();
  }

  Future<List<int>> readDatabaseBytes() async {
    final file = await databaseFile;
    if (!await file.exists()) {
      throw const FileSystemException('Banco de dados local nao encontrado.');
    }
    return file.readAsBytes();
  }

  Future<void> replaceWithValidatedBytes(List<int> sqliteBytes) async {
    final databasesPath = await getDatabasesPath();
    final tempFile = File(p.join(databasesPath, _tempDatabaseName));
    final finalFile = File(p.join(databasesPath, databaseName));

    // 1. PROTEÇÃO DE DADOS TRANSACIONAIS NA ATUALIZAÇÃO DA CARGA:
    // Nunca apague ou perca as tabelas de movimentação de vendas:
    // 'pckvendig000', 'pckvendig010', 'pac00', 'pckvenpac00'.
    final List<Map<String, dynamic>> backupPckvendig000 = [];
    final List<Map<String, dynamic>> backupPckvendig010 = [];
    final List<Map<String, dynamic>> backupPac00 = [];
    final List<Map<String, dynamic>> backupPckvenpac00 = [];

    if (await finalFile.exists()) {
      Database? existingDb;
      try {
        existingDb = await openDatabase(finalFile.path, readOnly: true);

        try {
          final r000 = await existingDb.query('pckvendig000');
          backupPckvendig000.addAll(r000);
        } catch (_) {}

        try {
          final r010 = await existingDb.query('pckvendig010');
          backupPckvendig010.addAll(r010);
        } catch (_) {}

        try {
          final rPac = await existingDb.query('pac00');
          backupPac00.addAll(rPac);
        } catch (_) {}

        try {
          final rPckPac = await existingDb.query('pckvenpac00');
          backupPckvenpac00.addAll(rPckPac);
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
      await _validateSalespersonTable(tempFile.path);
      if (await finalFile.exists()) {
        await finalFile.delete();
      }
      await tempFile.rename(finalFile.path);

      // 2. Garante schema das tabelas de digitação/pacotes e restaura os dados pré-existentes
      Database? newDb;
      try {
        newDb = await openDatabase(finalFile.path);
        await _ensureSchemaAndMigrate(newDb);

        if (backupPckvendig000.isNotEmpty ||
            backupPckvendig010.isNotEmpty ||
            backupPac00.isNotEmpty ||
            backupPckvenpac00.isNotEmpty) {
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
        }

        // 3. Extrai e persiste com segurança a nova logo recebida na carga (cadace00.srv00_imglog)
        try {
          await EmpresaLogoService.instance.extrairLogoDaCarga(newDb);
        } catch (_) {}
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

  Future<void> _validateSalespersonTable(String databasePath) async {
    Database? database;
    try {
      database = await openDatabase(databasePath, readOnly: true);
      final rows = await database.rawQuery('SELECT COUNT(*) FROM cadrep00');
      if (rows.isEmpty) {
        throw StateError('A tabela cadrep00 nao retornou dados de validacao.');
      }
    } finally {
      if (database != null && database.isOpen) {
        await database.close();
      }
    }
  }
}
