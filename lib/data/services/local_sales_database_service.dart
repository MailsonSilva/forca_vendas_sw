import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import '/core/services/empresa_logo_service.dart';
import '../../services/sequence_generator_service.dart';
import '../../app_state.dart';

/// Responsavel pelo arquivo SQLite local da forca de vendas.
///
/// Mantem nomes de arquivos, gravacao temporaria e validacao da tabela critica
/// fora das actions para que a UI nao carregue regra de infraestrutura.
class LocalSalesDatabaseService {
  static const databaseName = 'dbforcacad001.db';
  /// Alias PRD compat — físico permanece dbforcacad001.db (sem renomear arquivo).
  static const aliasDig = 'dbforcadig001.db';
  static const _tempDatabaseName = 'temp_db.db';

  static Database? _dbForTesting;
  static Database? _activeDb;

  static void setDatabaseForTesting(Database? db) {
    _dbForTesting = db;
  }

  /// Reinicializa o pool de conexões com o SQLite ('dbforcacad001.db')
  /// para invalidar caches antigos em memória e liberar file locks.
  static Future<void> closeAndResetConnectionPool() async {
    if (_activeDb != null) {
      if (_activeDb!.isOpen) {
        try {
          await _activeDb!.close();
        } catch (_) {}
      }
      _activeDb = null;
    }
  }

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
    if (_dbForTesting != null) {
      return _dbForTesting!;
    }
    final path = await getDatabasePath();
    final db = await openDatabase(path, readOnly: readOnly);

    // Pragmas de alto desempenho no SQLite nativo
    try {
      await db.execute('PRAGMA journal_mode = WAL');
      await db.execute('PRAGMA synchronous = NORMAL');
      await db.execute('PRAGMA temp_store = MEMORY');
      await db.execute('PRAGMA cache_size = -64000'); // ~64MB em RAM
      await db.execute('PRAGMA optimize');
    } catch (_) {}

    if (!readOnly) {
      try {
        await _ensureSchemaAndMigrate(db);
        await _criarIndicesPerformance(db);
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
      // SPEC-046: compatibilidade com colunas legadas dig00_*
      'dig00_digcod': 'INTEGER',
      'dig00_digfil': 'INTEGER',
      'dig00_paccod': 'INTEGER',
      'dig00_pacstr': 'TEXT',
      'dig00_sttenv': 'INTEGER',
      'dig00_datenv': 'TEXT',
      'ped00_paccod': 'INTEGER',
      'ped00_datenv': 'TEXT',
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
      'cli00_codage': 'INTEGER DEFAULT 0',
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
      'pro00_reffor': 'TEXT',
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
        pro00_reffor TEXT,
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
    // Views de compatibilidade para duplicatas (SPEC-045: finrecdup00 / dup00)
    try {
      final hasFinrec = (await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table' AND name='finrecdup00'")).isNotEmpty;
      final hasDup00 = (await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table' AND name='dup00'")).isNotEmpty;
      if (hasFinrec && !hasDup00) {
        await db.execute('CREATE VIEW IF NOT EXISTS dup00 AS SELECT * FROM finrecdup00');
        await db.execute('CREATE VIEW IF NOT EXISTS findup00 AS SELECT * FROM finrecdup00');
        await db.execute('CREATE VIEW IF NOT EXISTS cadrecdup00 AS SELECT * FROM finrecdup00');
      } else {
        try { await db.execute('DROP VIEW IF EXISTS findup00'); } catch (_) {}
        try { await db.execute('CREATE VIEW IF NOT EXISTS cadrecdup00 AS SELECT * FROM dup00'); } catch (_) {}
      }
    } catch (_) {}
    try { await db.execute('DROP VIEW IF EXISTS cli00'); } catch (_) {}
    try { await db.execute('CREATE VIEW IF NOT EXISTS cli00 AS SELECT * FROM cadcli00'); } catch (_) {}

    // View de compatibilidade SPEC-046: pckvendig00
    try {
      final hasPck00 = (await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table' AND name='pckvendig00'")).isNotEmpty;
      if (!hasPck00) {
        await db.execute('DROP VIEW IF EXISTS pckvendig00');
        await db.execute('CREATE VIEW IF NOT EXISTS pckvendig00 AS SELECT * FROM pckvendig000');
      }
    } catch (_) {}
  }

  /// Cria índices de performance nas tabelas de catálogo após importação de carga.
  ///
  /// Chamado imediatamente após `_ensureSchemaAndMigrate` em `replaceWithValidatedBytes`
  /// para garantir que todas as buscas subsequentes usem índices ao invés de full table scan.
  static Future<void> _criarIndicesPerformance(Database db) async {
    // Descobre tabelas presentes no banco
    Set<String> tables = {};
    try {
      final t = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table'");
      tables = t.map((r) => r['name']?.toString().toLowerCase() ?? '').toSet();
    } catch (_) {}

    // Índices essenciais para busca rápida de produtos (cadpro00) e estoque (estpro00)
    if (tables.contains('cadpro00')) {
      try { await db.execute('CREATE INDEX IF NOT EXISTS idx_cadpro00_descri_cod ON cadpro00(pro00_descri ASC, pro00_codigo);'); } catch (_) {}
      try { await db.execute('CREATE INDEX IF NOT EXISTS idx_cadpro00_busca ON cadpro00(pro00_descri ASC, pro00_codigo);'); } catch (_) {}
      try { await db.execute('CREATE INDEX IF NOT EXISTS idx_cadpro00_order ON cadpro00(pro00_descri ASC, pro00_codigo);'); } catch (_) {}
      try { await db.execute('CREATE INDEX IF NOT EXISTS idx_cadpro00_descri ON cadpro00(pro00_descri)'); } catch (_) {}
      try { await db.execute('CREATE INDEX IF NOT EXISTS idx_cadpro00_codigo ON cadpro00(pro00_codigo)'); } catch (_) {}
      try { await db.execute('CREATE INDEX IF NOT EXISTS idx_cadpro00_codbar ON cadpro00(pro00_codbar)'); } catch (_) {}
      try { await db.execute('CREATE INDEX IF NOT EXISTS idx_cadpro00_filtros ON cadpro00(pro00_codlin, pro00_codgrp, pro00_codmar)'); } catch (_) {}
    }

    // Índices para marcas (cadmar00)
    if (tables.contains('cadmar00')) {
      try { await db.execute('CREATE INDEX IF NOT EXISTS idx_cadmar00_cod ON cadmar00(mar00_codigo);'); } catch (_) {}
    }

    // Índices para estoque particionado (estpro00)
    if (tables.contains('estpro00')) {
      try { await db.execute('CREATE INDEX IF NOT EXISTS idx_estpro00_fil_pro ON estpro00(pro00_codfil, pro00_codpro);'); } catch (_) {}
      try { await db.execute('CREATE INDEX IF NOT EXISTS idx_estpro00_filial_prod ON estpro00(pro00_codfil, pro00_codpro, pro00_qtdest);'); } catch (_) {}
      try { await db.execute('CREATE INDEX IF NOT EXISTS idx_estpro00_codpro_codfil ON estpro00(pro00_codpro, pro00_codfil)'); } catch (_) {}
      try { await db.execute('CREATE INDEX IF NOT EXISTS idx_estpro00_filial_prod_cov ON estpro00(pro00_codfil, pro00_codpro, pro00_qtdest, pro00_qtdpen);'); } catch (_) {}
    }

    // Índices para multiplicadores de embalagem (cadpro02) - SPEC-052
    if (tables.contains('cadpro02')) {
      try { await db.execute('CREATE INDEX IF NOT EXISTS idx_cadpro02_prod ON cadpro02(pro02_codpro);'); } catch (_) {}
    }

    // Índices para fracionamento de produtos (cadprofra00) - SPEC-052
    if (tables.contains('cadprofra00')) {
      try { await db.execute('CREATE INDEX IF NOT EXISTS idx_cadprofra00_prod ON cadprofra00(fra00_codpro);'); } catch (_) {}
    }

    // Índices para bonificação de produtos (cadprobon00) - SPEC-052
    if (tables.contains('cadprobon00')) {
      try { await db.execute('CREATE INDEX IF NOT EXISTS idx_cadprobon00_prod ON cadprobon00(bon00_codpro);'); } catch (_) {}
    }

    // Índices para histórico de datas por filial e produto (estprodat00) - SPEC-052
    if (tables.contains('estprodat00')) {
      try { await db.execute('CREATE INDEX IF NOT EXISTS idx_estprodat00_fil_prod ON estprodat00(pro00_codfil, pro00_codpro);'); } catch (_) {}
    }

    // Índices para tabela de preços (estpcopro00)
    if (tables.contains('estpcopro00')) {
      try { await db.execute('CREATE INDEX IF NOT EXISTS idx_estpcopro00_tab_pro ON estpcopro00(pro00_codtab, pro00_codpro);'); } catch (_) {}
      try { await db.execute('CREATE INDEX IF NOT EXISTS idx_estpcopro00_codpro ON estpcopro00(pro00_codpro)'); } catch (_) {}
    }

    // Índices para clientes (cadcli00)
    if (tables.contains('cadcli00')) {
      try { await db.execute('CREATE INDEX IF NOT EXISTS idx_cadcli00_busca ON cadcli00(cli00_descri, cli00_fantas, cli00_codigo, cli00_cpfcnp)'); } catch (_) {}
      try { await db.execute('CREATE INDEX IF NOT EXISTS idx_cadcli00_descri ON cadcli00(cli00_descri)'); } catch (_) {}
      try { await db.execute('CREATE INDEX IF NOT EXISTS idx_cadcli00_codigo ON cadcli00(cli00_codigo)'); } catch (_) {}
      try { await db.execute('CREATE INDEX IF NOT EXISTS idx_cadcli00_cpfcnp ON cadcli00(cli00_cpfcnp)'); } catch (_) {}
    }

    // Otimização do planner SQLite pós-carga
    try { await db.execute('PRAGMA optimize'); } catch (_) {}
    try { await db.execute('PRAGMA temp_store = MEMORY'); } catch (_) {}
    try { await db.execute('PRAGMA cache_size = -64000'); } catch (_) {}
  }

  /// Cria índices oficiais de busca e estoque multi-filial pós-carga (SPEC-050)
  static Future<void> criarIndicesBuscaEEstoque(Database db) async {
    await _criarIndicesPerformance(db);
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


  /// Obtém o próximo sequencial de pacote incremental (range 1000..9999) conforme SPEC-046.
  static Future<int> obterProximoSequencialPacote(int codRep) async {
    final db = await getDatabase();
    final service = SequenceGeneratorService(db);
    return service.obterProximoCodigoPacote(codRep);
  }

  /// Obtém o próximo código sequencial do pedido (+1) conforme SPEC-046.
  static Future<int> obterProximoCodigoPedido({int? codFilial, int? codVendedor}) async {
    final db = await getDatabase();
    final service = SequenceGeneratorService(db);
    final fil = codFilial ?? (AppState().codFilialAtiva != 0 ? AppState().codFilialAtiva : 1);
    final rep = codVendedor ?? AppState().vendedor_codigo;
    return service.obterProximoCodigoPedido(fil, rep);
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

      // Reinicializa o pool de conexões antes de substituir o arquivo físico
      await closeAndResetConnectionPool();

      if (await finalFile.exists()) {
        await finalFile.delete();
      }
      await tempFile.rename(finalFile.path);

      // 2. Garante schema das tabelas de digitação/pacotes e restaura os dados pré-existentes
      Database? newDb;
      try {
        newDb = await openDatabase(finalFile.path);
        await _ensureSchemaAndMigrate(newDb);

        // 2.1 Cria índices de performance imediatamente após a carga
        await _criarIndicesPerformance(newDb);

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

        // 4. Extrai e atualiza razão social / nome da empresa da nova carga (cadace00.srv00_descri)
        try {
          final tAce = await newDb.rawQuery("SELECT name FROM sqlite_master WHERE type='table' AND lower(name)='cadace00'");
          if (tAce.isNotEmpty) {
            final aceCols = await newDb.rawQuery('PRAGMA table_info(cadace00)');
            final aceCn = aceCols.map((r) => r['name'].toString().toLowerCase()).toSet();
            if (aceCn.contains('srv00_descri')) {
              final rows = await newDb.rawQuery('SELECT srv00_descri FROM cadace00 WHERE srv00_descri IS NOT NULL AND TRIM(srv00_descri) != "" LIMIT 1');
              if (rows.isNotEmpty && rows.first['srv00_descri'] != null) {
                final emp = rows.first['srv00_descri'].toString().trim();
                if (emp.isNotEmpty) {
                  AppState().empresaNome = emp;
                }
              }
            }
          }
        } catch (_) {}
      } finally {
        if (newDb != null && newDb.isOpen) {
          await newDb.close();
        }
      }

      // Reinicializa o pool de conexões logo após a substituição do arquivo físico
      await closeAndResetConnectionPool();
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
