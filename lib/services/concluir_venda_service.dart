import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../backend/ftp/ftp_client.dart';
import '../domain/models/pedido_venda.dart';
import '../data/services/local_sales_database_service.dart';
import '../data/services/pac_xml_generator_service.dart';
import 'carga_registry_service.dart';
import 'ftp_path_builder.dart';
import 'status_envio_db.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ConcluirVendaService — separação de responsabilidades:
//
//   ┌─ gerarESalvarPedidoLocal() ─────────────────────────────────────────────┐
//   │  Chamado ao finalizar/salvar um pedido (concluir_venda_process.dart).   │
//   │  Responsabilidades:                                                     │
//   │    1. Recalcula totais do pedido                                        │
//   │    2. Persiste totais no SQLite (pckvendig000)                          │
//   │    3. Atualiza estatísticas locais                                      │
//   │    4. Gera conteúdo XML (PAC)                                           │
//   │    5. Salva arquivo localmente (temp/ e documents/)                     │
//   │  NÃO faz nenhuma chamada de rede/FTP.                                   │
//   └─────────────────────────────────────────────────────────────────────────┘
//
//   ┌─ enviarPedidoFtp() ─────────────────────────────────────────────────────┐
//   │  Chamado EXCLUSIVAMENTE por: Ferramentas → Dados → Subir Carga          │
//   │  (AtualizarCargaWidget._startUpload via enviarArquivosPendentesFtp).   │
//   │  Responsabilidades:                                                     │
//   │    1. Upload do arquivo XML gerado para o FTP                           │
//   │    2. Atualiza status do pedido no SQLite após envio                    │
//   │    3. Move arquivo da temp/ para enviados/ (auditoria)                 │
//   └─────────────────────────────────────────────────────────────────────────┘
// ─────────────────────────────────────────────────────────────────────────────

class ConcluirVendaService {
  ConcluirVendaService({
    Future<Directory> Function()? getTemporaryDirectoryFn,
    Future<Directory> Function()? getDocumentsDirFn,
    CargaRegistryService? registry,
  })  : _getTemporaryDirectoryFn =
            getTemporaryDirectoryFn ?? _safeGetTempDir,
        _getDocumentsDirFn =
            getDocumentsDirFn ?? _safeGetDocsDir,
        _registry = registry ?? CargaRegistryService();

  static Future<Directory> _safeGetTempDir() async {
    try {
      return await getTemporaryDirectory();
    } catch (_) {
      return Directory.systemTemp;
    }
  }

  static Future<Directory> _safeGetDocsDir() async {
    try {
      return await getApplicationDocumentsDirectory();
    } catch (_) {
      final dir = Directory(p.join(Directory.systemTemp.path, 'documents'));
      if (!dir.existsSync()) dir.createSync(recursive: true);
      return dir;
    }
  }

  final Future<Directory> Function() _getTemporaryDirectoryFn;
  final Future<Directory> Function() _getDocumentsDirFn;
  final CargaRegistryService _registry;

  /// Salva e conclui o pedido **apenas localmente no SQLite**, sem gerar pacote (.pac).
  ///
  /// O pedido fica gravado com:
  ///   - `ped00_sttdig = 1` (Digitado / Concluído)
  ///   - `ped00_sttenv = 0` (Não empacotado / Aguardando inclusão em pacote)
  ///   - `ped00_pacstr = ''` (Sem vínculo de pacote)
  Future<int> salvarPedidoConcluidoLocal({
    required PedidoVenda pedido,
    required String empresa,
    required int codigoEquipe,
  }) async {
    if (pedido.items.isEmpty) {
      throw Exception("Não é possível concluir um pedido sem itens.");
    }

    // 1. Recalcula totais
    pedido.calcularTotais();

    // 2. Persiste totais no cabeçalho SQLite (pckvendig000) com sttdig=1 e sttenv=0
    final db = await LocalSalesDatabaseService.getDatabase();
    try {
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
      try { await db.execute('CREATE VIEW IF NOT EXISTS dig00 AS SELECT * FROM pckvendig000'); } catch (_) {}
      try { await db.execute('CREATE VIEW IF NOT EXISTS dig01 AS SELECT * FROM pckvendig010'); } catch (_) {}

      await db.execute('''
          CREATE TABLE IF NOT EXISTS ESTFATCVD00 (
            fat00_codfil INTEGER,
            fat00_codmov INTEGER PRIMARY KEY,
            fat00_codrep INTEGER,
            fat00_codcli INTEGER,
            fat00_valtot REAL,
            fat00_datfat TEXT,
            fat00_subtot REAL,
            fat00_destot REAL
          )
        ''');
      await db.execute('''
          CREATE TABLE IF NOT EXISTS FINCAICVD00 (
            cai00_codfil INTEGER,
            cai00_codmov INTEGER PRIMARY KEY,
            cai00_codcli INTEGER,
            cai00_valtot REAL,
            cai00_datmov TEXT,
            cai00_codpla INTEGER
          )
        ''');
      await db.execute('''
          CREATE TABLE IF NOT EXISTS ESTPRO00 (
            pro00_codfil INTEGER,
            pro00_codpro TEXT,
            pro00_qtdest REAL DEFAULT 0,
            pro00_qtdpen REAL DEFAULT 0,
            PRIMARY KEY (pro00_codfil, pro00_codpro)
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
        // SPEC-042: Observação do Pedido (dig00_digobs)
        'ped00_digobs': 'TEXT',
        'dig00_digobs': 'TEXT',
        'ped00_obs': 'TEXT',
        'ped00_observ': 'TEXT',
      }.entries) {
        try { await db.execute('ALTER TABLE pckvendig000 ADD COLUMN ${e.key} ${e.value}'); } catch (_) {}
      }

      final List<Map<String, dynamic>> columns =
          await db.rawQuery('PRAGMA table_info(pckvendig000)');
      final colNames =
          columns.map((r) => r['name']?.toString().toLowerCase()).toSet();

      final List<String> updateParts = [];
      final List<dynamic> binds = [];

      void addUpdate(String col, dynamic val) {
        if (colNames.contains(col.toLowerCase())) {
          updateParts.add('$col = ?');
          binds.add(val);
        }
      }

      addUpdate('ped00_bontot', pedido.bontot);
      addUpdate('ped00_destot', pedido.destot);
      addUpdate('ped00_subtot', pedido.subtot);
      addUpdate('ped00_digtot', pedido.digtot);
      addUpdate('ped00_fattot', pedido.fattot);
      addUpdate('ped00_datsys', pedido.datSys);
      if (pedido.clides.isNotEmpty) addUpdate('ped00_clides', pedido.clides);
      if (pedido.lindes.isNotEmpty) addUpdate('ped00_lindes', pedido.lindes);
      if (pedido.plades.isNotEmpty) addUpdate('ped00_plades', pedido.plades);
      if (pedido.codTab != 0) addUpdate('ped00_digtab', pedido.codTab);
      addUpdate('ped00_bonfrcven', pedido.bonfrcven);
      addUpdate('ped00_sttdig', 1); // 1 = Digitado/Concluído
      addUpdate('ped00_status', 1);
      addUpdate('ped00_sttenv', 0); // 0 = Aguardando Pacote
      addUpdate('ped00_pacstr', '');
      addUpdate('ped00_pacote', '');
      addUpdate('ped00_codfil', pedido.codFil);
      addUpdate('ped00_codrep', pedido.codRep);
      addUpdate('ped00_digcob', pedido.tipoAgente);
      addUpdate('ped00_codagt', pedido.codAgt);
      addUpdate('ped00_agtcod', pedido.codAgt);
      addUpdate('ped00_codage', pedido.codAgt);
      addUpdate('ped00_digagt', pedido.codAgt);
      if (pedido.observacao.isNotEmpty) {
        addUpdate('ped00_digobs', pedido.observacao);
        addUpdate('dig00_digobs', pedido.observacao);
        addUpdate('ped00_obs', pedido.observacao);
        addUpdate('ped00_observ', pedido.observacao);
      }

      if (updateParts.isNotEmpty) {
        String colNum = 'ped00_numped';
        for (final c in ['ped00_numped', 'numped', 'ped00_codmov', 'codmov', 'ped00_pedcod', 'pedcod', 'id']) {
          if (colNames.contains(c.toLowerCase())) {
            colNum = c;
            break;
          }
        }
        await db.transaction((txn) async {
          final existing = await txn.rawQuery('SELECT $colNum FROM pckvendig000 WHERE $colNum = ? LIMIT 1', [pedido.codMov]);
          if (existing.isEmpty) {
            final insertCols = <String>[colNum];
            final insertVals = <dynamic>[pedido.codMov];
            for (int i = 0; i < updateParts.length; i++) {
              final col = updateParts[i].split('=')[0].trim();
              if (col.toLowerCase() != colNum.toLowerCase() && !insertCols.any((c) => c.toLowerCase() == col.toLowerCase())) {
                insertCols.add(col);
                insertVals.add(binds[i]);
              }
            }
            final placeholders = List.filled(insertCols.length, '?').join(', ');
            await txn.rawInsert('INSERT OR REPLACE INTO pckvendig000 (${insertCols.join(', ')}) VALUES ($placeholders)', insertVals);
          } else {
            final query = 'UPDATE pckvendig000 SET ${updateParts.join(', ')} WHERE $colNum = ?';
            final bindsWithId = [...binds, pedido.codMov];
            await txn.rawUpdate(query, bindsWithId);
          }
        });
      }
    } catch (e) {
      throw Exception('Falha ao persistir pedido no SQLite: $e');
    }

    try {
      await pedido.doUpdateStatistics();
    } catch (_) {}

    return pedido.codMov;
  }

  /// Gera e salva o pedido **localmente** (SQLite + arquivo XML em temp/).
  ///
  /// NÃO realiza upload FTP. O arquivo fica em `getTemporaryDirectory()`
  /// aguardando envio manual via Ferramentas → Dados → Subir Carga.
  ///
  /// Retorna o nome do arquivo gerado (ex: 'p71-1007') para uso posterior.
  Future<String> gerarESalvarPedidoLocal({
    required PedidoVenda pedido,
    required String empresa,
    required int codigoEquipe,
  }) async {
    if (pedido.items.isEmpty) {
      throw Exception("Não é possível concluir um pedido sem itens.");
    }

    // 1. Recalcula totais
    pedido.calcularTotais();

    // 1b. Define nome do arquivo PAC antes da transação (necessário para ped00_pacstr)
    final String fileName = FtpPathBuilder.getFileNamePedido(
      pedido.codRep,
      pedido.codMov,
    );

    // 2. Persiste totais no cabeçalho SQLite (pckvendig000) — transação com diagnóstico
    final db = await LocalSalesDatabaseService.getDatabase();
    try {
      // ── Garante tabelas e views (evita skip silencioso) ──
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
        try { await db.execute('CREATE VIEW IF NOT EXISTS dig00 AS SELECT * FROM pckvendig000'); } catch (_) {}
        try { await db.execute('CREATE VIEW IF NOT EXISTS dig01 AS SELECT * FROM pckvendig010'); } catch (_) {}

        // Garante tabelas acessórias para não falharem no doUpdateStatistics
        await db.execute('''
          CREATE TABLE IF NOT EXISTS ESTFATCVD00 (
            fat00_codfil INTEGER,
            fat00_codmov INTEGER PRIMARY KEY,
            fat00_codrep INTEGER,
            fat00_codcli INTEGER,
            fat00_valtot REAL,
            fat00_datfat TEXT,
            fat00_subtot REAL,
            fat00_destot REAL
          )
        ''');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS FINCAICVD00 (
            cai00_codfil INTEGER,
            cai00_codmov INTEGER PRIMARY KEY,
            cai00_codcli INTEGER,
            cai00_valtot REAL,
            cai00_datmov TEXT,
            cai00_codpla INTEGER
          )
        ''');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS ESTPRO00 (
            pro00_codfil INTEGER,
            pro00_codpro TEXT,
            pro00_qtdest REAL DEFAULT 0,
            pro00_qtdpen REAL DEFAULT 0,
            PRIMARY KEY (pro00_codfil, pro00_codpro)
          )
        ''');

        final List<Map<String, dynamic>> columns =
            await db.rawQuery('PRAGMA table_info(pckvendig000)');
        final colNames =
            columns.map((r) => r['name']?.toString().toLowerCase()).toSet();

        final List<String> updateParts = [];
        final List<dynamic> binds = [];

        void addUpdate(String col, dynamic val) {
          if (colNames.contains(col.toLowerCase())) {
            updateParts.add('$col = ?');
            binds.add(val);
          }
        }

        // Garante todas as colunas de cabeçalho e itens se ausentes no banco legado
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
          try { await db.execute('ALTER TABLE pckvendig000 ADD COLUMN ${e.key} ${e.value}'); } catch (_) {}
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
        }.entries) {
          try { await db.execute('ALTER TABLE pckvendig010 ADD COLUMN ${e.key} ${e.value}'); } catch (_) {}
        }

        // Re-ler colNames após ALTER
        final cols2 = await db.rawQuery('PRAGMA table_info(pckvendig000)');
        colNames.clear();
        colNames.addAll(cols2.map((r) => r['name']?.toString().toLowerCase() ?? ''));

        addUpdate('ped00_bontot', pedido.bontot);
        addUpdate('ped00_destot', pedido.destot);
        addUpdate('ped00_subtot', pedido.subtot);
        addUpdate('ped00_digtot', pedido.digtot);
        addUpdate('ped00_fattot', pedido.fattot);
        addUpdate('ped00_datsys', pedido.datSys);
        if (pedido.clides.isNotEmpty) addUpdate('ped00_clides', pedido.clides);
        if (pedido.lindes.isNotEmpty) addUpdate('ped00_lindes', pedido.lindes);
        if (pedido.plades.isNotEmpty) addUpdate('ped00_plades', pedido.plades);
        if (pedido.codTab != 0) addUpdate('ped00_digtab', pedido.codTab);
        addUpdate('ped00_bonfrcven', pedido.bonfrcven);
        addUpdate('ped00_sttdig', pedido.sttDig.value);
        addUpdate('ped00_status', pedido.sttDig.value);
        // Passo 3: já marca como Empacotado (1) no mesmo UPDATE para a tela Gerar Pacote localizar
        addUpdate('ped00_sttenv', 1);
        addUpdate('ped00_pacstr', fileName);
        addUpdate('ped00_pacote', fileName);
        addUpdate('ped00_codfil', pedido.codFil);
        addUpdate('ped00_codrep', pedido.codRep);
        addUpdate('ped00_digcob', pedido.tipoAgente);
        addUpdate('ped00_codagt', pedido.codAgt);
        addUpdate('ped00_agtcod', pedido.codAgt);
        addUpdate('ped00_codage', pedido.codAgt);
        addUpdate('ped00_digagt', pedido.codAgt);

        if (updateParts.isNotEmpty) {
          // Detecta coluna chave numérica de forma resiliente
          String colNum = 'ped00_numped';
          for (final c in ['ped00_numped', 'numped', 'ped00_codmov', 'codmov', 'ped00_pedcod', 'pedcod', 'id']) {
            if (colNames.contains(c.toLowerCase())) {
              colNum = c;
              break;
            }
          }
          // Usa transaction para garantir atomicidade; confirma INSERT em pckvendig000
          await db.transaction((txn) async {
            final existing = await txn.rawQuery('SELECT $colNum FROM pckvendig000 WHERE $colNum = ? LIMIT 1', [pedido.codMov]);
            if (existing.isEmpty) {
              // Fallback: INSERT OR REPLACE se ainda não existe (cobre caso salvarCarrinho falhou)
              final insertCols = <String>[colNum];
              final insertVals = <dynamic>[pedido.codMov];
              // Mapeia updateParts de volta para colunas/valores para INSERT
              for (int i = 0; i < updateParts.length; i++) {
                final col = updateParts[i].split('=')[0].trim();
                if (col.toLowerCase() != colNum.toLowerCase() && !insertCols.any((c) => c.toLowerCase() == col.toLowerCase())) {
                  insertCols.add(col);
                  insertVals.add(binds[i]);
                }
              }
              final placeholders = List.filled(insertCols.length, '?').join(', ');
              await txn.rawInsert('INSERT OR REPLACE INTO pckvendig000 (${insertCols.join(', ')}) VALUES ($placeholders)', insertVals);
            } else {
              final query = 'UPDATE pckvendig000 SET ${updateParts.join(', ')} WHERE $colNum = ?';
              final bindsWithId = [...binds, pedido.codMov];
              await txn.rawUpdate(query, bindsWithId);
            }
          });
        }
      } catch (e) {
        throw Exception('Falha ao persistir pedido no SQLite: $e');
      }

    // 3. Atualiza estatísticas locais (ESTFATCVD00, FINCAICVD00, ESTPRO00) — não bloqueia venda
    try {
      await pedido.doUpdateStatistics();
    } catch (_) {}

    // 4, 5 e 6. Desacoplamento da Geração do Pacote .pac
    // O pedido já foi COMMITADO com sucesso no SQLite no passo anterior.
    // Qualquer falha de arquivo/permissão aqui não invalida a gravação do pedido.
    try {
      final String xmlContent = PacXmlGeneratorService.generate(pedido);
      final pacBytes = PacXmlGeneratorService.compressXmlToPac(xmlContent);

      // Grava localmente: temp/ (fila de upload) e documents/ (backup)
      final tempDir = await _getTemporaryDirectoryFn();
      final localFile = File(p.join(tempDir.path, fileName));
      await localFile.parent.create(recursive: true);
      await localFile.writeAsBytes(pacBytes, flush: true);

      final docsDir = await _getDocumentsDirFn();
      final docsFile = File(p.join(docsDir.path, fileName));
      await docsFile.parent.create(recursive: true);
      await docsFile.writeAsBytes(pacBytes, flush: true);

      // Registra no manifesto a associação arquivo → id do pedido (em memória).
      await _registry.registrar(CargaRegistro(
        arquivo: fileName,
        tipo: TipoCarga.pedido,
        id: pedido.codMov,
      ));
    } catch (_) {}

    return fileName;
  }

  // ─── Upload FTP ─────────────────────────────────────────────────────────────
  // Chamado EXCLUSIVAMENTE por: AtualizarCargaWidget._startUpload()
  // via enviarArquivosPendentesFtp() em action_code/enviar_arquivos_pendentes_ftp.dart
  //
  // Para enviar pedidos acesse: Ferramentas → Dados → Subir Carga
  // ────────────────────────────────────────────────────────────────────────────

  /// Envia um pedido já gerado para o FTP.
  ///
  /// Normalmente NÃO é chamado diretamente — o envio em lote de todos os
  /// arquivos pendentes é feito por [enviarArquivosPendentesFtp].
  ///
  /// Use este método apenas para reenvio pontual de um pedido específico.
  Future<bool> enviarPedidoFtp({
    required PedidoVenda pedido,
    required String empresa,
    required int codigoEquipe,
  }) async {
    final String xmlContent = PacXmlGeneratorService.generate(pedido);
    final pacBytes = PacXmlGeneratorService.compressXmlToPac(xmlContent);
    final String fileName = FtpPathBuilder.getFileNamePedido(
      pedido.codRep,
      pedido.codMov,
    );

    final String remotePath = FtpPathBuilder.getRemotePath(
      empresa: empresa.trim().isEmpty ? 'diniz' : empresa.trim(),
      codReg: codigoEquipe,
      tipo: TipoCarga.pedido,
    );

    bool uploadSuccess = false;
    try {
      final FtpClient ftp = await FtpClient.connect();
      try {
        await ftp.cwd('/');
        final segmentos =
            remotePath.split('/').where((s) => s.trim().isNotEmpty);
        for (final seg in segmentos) {
          final s = seg.trim();
          try {
            await ftp.cwd(s);
          } catch (_) {
            try {
              await ftp.mkd(s);
              await ftp.cwd(s);
            } catch (_) {}
          }
        }
        await ftp.stor(fileName, pacBytes);
        uploadSuccess = true;
      } finally {
        await ftp.quit();
      }
    } catch (_) {
    }

    if (uploadSuccess) {
      // Atualiza status do pedido no SQLite para JEnviado (1)
      await StatusEnvioDb().marcarPedidoEnviado(pedido.codMov);

      // Deleta o arquivo temporário do pedido e remove do manifesto (auditoria
      // desnecessária — o guia manda deletar após upload bem-sucedido).
      await _limparTemporarioDoPedido(pedido.codMov);
    }

    return uploadSuccess;
  }

  /// Deleta os arquivos temporários registrados no manifesto para o pedido
  /// [codMov] e remove suas entradas, evitando reenvio duplicado.
  Future<void> _limparTemporarioDoPedido(int codMov) async {
    try {
      final tempDir = await _getTemporaryDirectoryFn();
      final registros = await _registry.listar();
      for (final reg in registros
          .where((r) => r.tipo == TipoCarga.pedido && r.id == codMov)) {
        final localFile = File(p.join(tempDir.path, reg.arquivo));
        if (await localFile.exists()) {
          await localFile.delete();
        }
        await _registry.remover(reg.arquivo);
      }
    } catch (_) {
    }
  }
}
