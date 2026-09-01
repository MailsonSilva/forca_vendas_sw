import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

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
    }.entries) {
      try {
        await db.execute('ALTER TABLE pckvendig010 ADD COLUMN ${e.key} ${e.value}');
      } catch (_) {}
    }

    // Views de compatibilidade dig00 / dig01
    try { await db.execute('DROP VIEW IF EXISTS dig00'); } catch (_) {}
    try { await db.execute('CREATE VIEW IF NOT EXISTS dig00 AS SELECT * FROM pckvendig000'); } catch (_) {}
    try { await db.execute('DROP VIEW IF EXISTS dig01'); } catch (_) {}
    try { await db.execute('CREATE VIEW IF NOT EXISTS dig01 AS SELECT * FROM pckvendig010'); } catch (_) {}
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

    await tempFile.parent.create(recursive: true);
    await tempFile.writeAsBytes(sqliteBytes, flush: true);

    try {
      await _validateSalespersonTable(tempFile.path);
      if (await finalFile.exists()) {
        await finalFile.delete();
      }
      await tempFile.rename(finalFile.path);
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
