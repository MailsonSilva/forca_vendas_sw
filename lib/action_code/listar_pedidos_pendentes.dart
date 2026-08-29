import 'package:sqflite/sqflite.dart';
import 'package:intl/intl.dart';
import '/app_state.dart';
import '/data/services/local_sales_database_service.dart';
import '/functions/proximo_numero_pedido.dart';

class PedidoPendente {
  PedidoPendente({
    required this.pedidoId,
    required this.clienteCodigo,
    required this.clienteNome,
    required this.data,
    required this.planoDescricao,
    required this.linhaDescricao,
  });
  final int pedidoId;
  final int clienteCodigo;
  final String clienteNome;
  final String data;
  final String planoDescricao;
  final String linhaDescricao;
}

class PedidoHistoricoItem {
  PedidoHistoricoItem({
    required this.pedidoId,
    required this.clienteCodigo,
    required this.clienteNome,
    required this.clienteFantasia,
    required this.dataEmissao,
    required this.planoCodigo,
    required this.planoDescricao,
    required this.linhaCodigo,
    required this.linhaDescricao,
    required this.agenteCodigo,
    required this.agenteDescricao,
    required this.valorProdutos,
    required this.valorSubstituicao,
    required this.valorBonus,
    required this.totalFatura,
    required this.quantidadeItens,
    required this.observacao,
    required this.sttDig,
    required this.sttEnv,
    required this.nomePacote,
  });

  final int pedidoId;
  final int clienteCodigo;
  final String clienteNome;
  final String clienteFantasia;
  final String dataEmissao;
  final String planoCodigo;
  final String planoDescricao;
  final String linhaCodigo;
  final String linhaDescricao;
  final String agenteCodigo;
  final String agenteDescricao;
  final double valorProdutos;
  final double valorSubstituicao;
  final double valorBonus;
  final double totalFatura;
  final double quantidadeItens;
  final String observacao;
  final int sttDig; // 0 = Rascunho / Em Digitação, 1 = Digitado / Concluído
  final int sttEnv; // 0 = Digitado / Rascunho, 1 = Empacotado, 2 = Transmitido (JEnviado), 3 = Recebido / Faturado
  final String nomePacote;

  bool get isRascunho => sttDig == 0;
  bool get isProntoEnvio => sttDig == 1 && sttEnv < 2;
  bool get isEmpacotado => sttEnv == 1;
  bool get isTransmitido => sttEnv == 2;
  bool get isFaturado => sttEnv == 3;
  bool get isInconsistente => sttEnv >= 4;
}

/// Consulta pedidos pendentes para a tela de Geração de Pacotes (.pac)
Future<List<PedidoPendente>> listarPedidosPendentes() async {
  Database? db;
  try {
    final targetPaths = await LocalSalesDatabaseService.getTargetDatabasePaths();
    final dbPath = await LocalSalesDatabaseService.getDatabasePath();
    db = await openDatabase(dbPath, readOnly: true);

    final List<Map<String, dynamic>> rows = [];
    final Set<int> seenIds = {};

    final int codRep = AppState().vendedor_codigo;
    final dynamic bindRep = codRep > 0 ? codRep : null;

    for (final path in targetPaths) {
      Database? d;
      try {
        d = (path == dbPath) ? db : await openDatabase(path, readOnly: true);
        final t = await d.rawQuery("SELECT name FROM sqlite_master WHERE type='table' AND lower(name)='pckvendig000'");
        if (t.isEmpty) continue;

        final cols = await d.rawQuery('PRAGMA table_info(pckvendig000)');
        final colNames = cols.map((r) => r['name']?.toString().toLowerCase()).toSet();

        String colNum = 'ped00_numped';
        for (final c in ['ped00_numped', 'ped00_pedcod', 'ped00_codmov', 'numped']) {
          if (colNames.contains(c)) { colNum = c; break; }
        }

        String colRepName = 'ped00_codrep';
        for (final c in ['ped00_codrep', 'ped00_repcod', 'ped00_vencod', 'codrep']) {
          if (colNames.contains(c)) { colRepName = c; break; }
        }

        List<Map<String, dynamic>> rws;
        if (colNames.contains(colRepName.toLowerCase())) {
          rws = await d.rawQuery(
            'SELECT * FROM pckvendig000 WHERE ($colNum > 0) AND ($colRepName = ? OR CAST($colRepName AS TEXT) = CAST(? AS TEXT) OR ? IS NULL OR $colRepName = 0 OR $colRepName IS NULL) ORDER BY $colNum DESC',
            [bindRep, bindRep, bindRep],
          );
        } else {
          rws = await d.rawQuery(
            'SELECT * FROM pckvendig000 WHERE ($colNum > 0) ORDER BY $colNum DESC',
          );
        }

        for (final r in rws) {
          final id = _getInt(r, ['ped00_numped', 'ped00_pedcod', 'ped00_codmov', 'numped', 'pedcod', 'codmov']);
          if (id == 0 || seenIds.contains(id)) continue;

          final sEnv = _getInt(r, ['ped00_sttenv', 'ped00_enviado', 'ped00_flgenv', 'sttenv', 'enviado']);

          // Exibe pedidos pendentes de transmissão (sttenv < 2)
          if (sEnv < 2) {
            seenIds.add(id);
            rows.add(r);
          }
        }
      } catch (e) {
        print('Erro em listarPedidosPendentes para $path: $e');
      } finally {
        if (d != null && d != db && d.isOpen) {
          await d.close();
        }
      }
    }

    List<PedidoPendente> result = [];
    for (final m in rows) {
      final id = _getInt(m, ['ped00_numped', 'ped00_pedcod', 'ped00_codmov', 'numped', 'pedcod', 'codmov']);
      final cliCod = _getInt(m, ['ped00_codcli', 'ped00_clicod', 'codcli', 'clicod']);
      final plaCod = _getString(m, ['ped00_codpla', 'ped00_codpag', 'ped00_placod', 'codpla', 'codpag']);
      final linCod = _getString(m, ['ped00_codlin', 'ped00_lincod', 'codlin']);
      final dat = _getString(m, ['ped00_datsys', 'ped00_datemi', 'ped00_datcad', 'datsys', 'datemi']);

      String cliNome = _getString(m, ['ped00_clides', 'clides']);
      String plaDesc = _getString(m, ['ped00_plades', 'plades']);
      String linDesc = _getString(m, ['ped00_lindes', 'lindes']);

      try {
        if (cliNome.isEmpty && cliCod != 0) {
          final c = await db.rawQuery('SELECT * FROM cadcli00 WHERE cli00_codigo = ? LIMIT 1', [cliCod]);
          if (c.isNotEmpty) {
            cliNome = _getString(c.first, ['cli00_descri', 'cli00_fantasi', 'cli00_fantas', 'descri', 'nome']);
          }
        }
      } catch (_) {}
      try {
        if (plaDesc.isEmpty && plaCod.isNotEmpty) {
          final pr = await db.rawQuery('SELECT * FROM cadpla00 WHERE pla00_codigo = ? LIMIT 1', [plaCod]);
          if (pr.isNotEmpty) {
            plaDesc = _getString(pr.first, ['pla00_descri', 'descri', 'descricao']);
          }
        }
      } catch (_) {}
      try {
        if (linDesc.isEmpty && linCod.isNotEmpty) {
          final lr = await db.rawQuery('SELECT * FROM cadlin00 WHERE lin00_codigo = ? LIMIT 1', [linCod]);
          if (lr.isNotEmpty) {
            linDesc = _getString(lr.first, ['lin00_descri', 'descri', 'descricao']);
          }
        }
      } catch (_) {}

      result.add(PedidoPendente(
        pedidoId: id,
        clienteCodigo: cliCod,
        clienteNome: cliNome.isNotEmpty ? cliNome : 'Cliente $cliCod',
        data: dat,
        planoDescricao: plaDesc.isNotEmpty ? plaDesc : plaCod,
        linhaDescricao: linDesc.isNotEmpty ? linDesc : linCod,
      ));
    }

    print('DEBUG HISTORICO QUERY: Encontrados ${result.length} pedidos pendentes no banco');
    return result;
  } catch (e) {
    print('Erro listar pedidos pendentes: $e');
    return [];
  } finally {
    if (db != null && db.isOpen) {
      await db.close();
    }
  }
}

/// Consulta estruturada de todos os pedidos locais para a tela de histórico / extrato / rascunhos
Future<List<PedidoHistoricoItem>> listarPedidosHistorico({
  String filtroTexto = '',
  String filtroStatus = 'todos',
  String filtroPeriodo = 'todos',
}) async {
  Database? db;
  try {
    final targetPaths = await LocalSalesDatabaseService.getTargetDatabasePaths();
    final dbPath = await LocalSalesDatabaseService.getDatabasePath();
    db = await openDatabase(dbPath);
    print('[listarPedidosHistorico] Banco principal: $dbPath');

    // Garante que pckvendig000 e pckvendig010 existam para evitar exceptions em bancos novos
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
    try { await db.execute('ALTER TABLE pckvendig000 ADD COLUMN ped00_pacstr TEXT'); } catch (_) {}
    // Unificação leitura/gravação: dig00 é VIEW perfeita de pckvendig000, recriada para refletir ALTERs
    try { await db.execute('DROP VIEW IF EXISTS dig00'); } catch (_) {}
    try { await db.execute('CREATE VIEW dig00 AS SELECT * FROM pckvendig000'); } catch (_) {}
    try { await db.execute('DROP VIEW IF EXISTS dig01'); } catch (_) {}
    try { await db.execute('CREATE VIEW dig01 AS SELECT * FROM pckvendig010'); } catch (_) {}

    final List<Map<String, dynamic>> rows = [];
    final Set<int> seenIds = {};

    final int codRep = AppState().vendedor_codigo;
    final dynamic bindRep = codRep > 0 ? codRep : null;

    for (final path in targetPaths) {
      Database? d;
      try {
        d = (path == dbPath) ? db : await openDatabase(path, readOnly: true);
        final t = await d.rawQuery("SELECT name FROM sqlite_master WHERE type='table' AND lower(name)='pckvendig000'");
        if (t.isEmpty) {
          print('[listarPedidosHistorico] Tabela pckvendig000 não encontrada em: $path');
          continue;
        }

        final cols = await d.rawQuery('PRAGMA table_info(pckvendig000)');
        final colNames = cols.map((r) => r['name']?.toString().toLowerCase()).toSet();

        String colNum = 'ped00_numped';
        for (final c in ['ped00_numped', 'ped00_pedcod', 'ped00_codmov', 'numped']) {
          if (colNames.contains(c)) { colNum = c; break; }
        }

        String colRepName = 'ped00_codrep';
        for (final c in ['ped00_codrep', 'ped00_repcod', 'ped00_vencod', 'codrep']) {
          if (colNames.contains(c)) { colRepName = c; break; }
        }

        List<Map<String, dynamic>> rws;
        if (colNames.contains(colRepName.toLowerCase())) {
          rws = await d.rawQuery(
            'SELECT * FROM pckvendig000 WHERE ($colNum > 0) AND ($colRepName = ? OR CAST($colRepName AS TEXT) = CAST(? AS TEXT) OR ? IS NULL OR $colRepName = 0 OR $colRepName IS NULL) ORDER BY $colNum DESC',
            [bindRep, bindRep, bindRep],
          );
        } else {
          rws = await d.rawQuery(
            'SELECT * FROM pckvendig000 WHERE ($colNum > 0) ORDER BY $colNum DESC',
          );
        }

        print('[listarPedidosHistorico] Lido ${rws.length} registro(s) de: $path');
        for (final r in rws) {
          final id = _getInt(r, ['ped00_numped', 'ped00_pedcod', 'ped00_codmov', 'numped', 'pedcod', 'codmov']);
          if (id != 0 && !seenIds.contains(id)) {
            seenIds.add(id);
            rows.add(r);
          }
        }
      } catch (e) {
        print('[listarPedidosHistorico] Erro lendo pedidos de $path: $e');
      } finally {
        if (d != null && d != db && d.isOpen) {
          await d.close();
        }
      }
    }

    // Ordena por ID decrescente
    rows.sort((a, b) {
      final idA = _getInt(a, ['ped00_numped', 'ped00_pedcod', 'ped00_codmov', 'numped']);
      final idB = _getInt(b, ['ped00_numped', 'ped00_pedcod', 'ped00_codmov', 'numped']);
      return idB.compareTo(idA);
    });

    final List<PedidoHistoricoItem> list = [];

    final now = DateTime.now();
    final todayStr = DateFormat('yyyy-MM-dd').format(now);
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final weekStartStr = DateFormat('yyyy-MM-dd').format(weekStart);
    final monthStartStr = DateFormat('yyyy-MM-01').format(now);

    for (final m in rows) {
      final id = _getInt(m, ['ped00_numped', 'ped00_pedcod', 'ped00_codmov', 'numped', 'pedcod', 'codmov']);
      final cliCod = _getInt(m, ['ped00_codcli', 'ped00_clicod', 'codcli', 'clicod']);
      final plaCod = _getString(m, ['ped00_codpla', 'ped00_codpag', 'ped00_placod', 'ped00_digtab', 'codpla', 'codpag']);
      final linCod = _getString(m, ['ped00_codlin', 'ped00_lincod', 'codlin']);
      final dat = _getString(m, ['ped00_datsys', 'ped00_datemi', 'ped00_datcad', 'datsys', 'datemi']);
      final agtCod = _getString(m, ['ped00_codagt', 'ped00_agtcod', 'ped00_codage', 'ped00_digagt', 'codagt', 'agtcod']);
      final digTot = _getDouble(m, ['ped00_digtot', 'ped00_subtot', 'ped00_totprd', 'ped00_valtot', 'ped00_totger', 'digtot']);
      final subTot = _getDouble(m, ['ped00_subtot', 'ped00_subval', 'subtot']);
      final bonTot = _getDouble(m, ['ped00_bontot', 'ped00_bonval', 'bontot']);
      final fatTot = _getDouble(m, ['ped00_fattot', 'ped00_totfat', 'fattot'], digTot);
      final sDig = _getInt(m, ['ped00_sttdig', 'ped00_status', 'ped00_sitped', 'sttdig', 'status']);
      final sEnv = _getInt(m, ['ped00_sttenv', 'ped00_enviado', 'ped00_flgenv', 'sttenv', 'enviado']);
      final pacStr = _getString(m, ['ped00_pacstr', 'ped00_pacote', 'ped00_paccod', 'pacstr', 'pacote']);
      final obsStr = _getString(m, ['ped00_observ', 'ped00_obs', 'ped00_observacao', 'observ', 'obs']);

      // Filtro de período
      if (filtroPeriodo == 'hoje' && dat.isNotEmpty && !dat.startsWith(todayStr)) {
        continue;
      } else if (filtroPeriodo == 'semana' && dat.isNotEmpty && dat.compareTo(weekStartStr) < 0) {
        continue;
      } else if (filtroPeriodo == 'mes' && dat.isNotEmpty && dat.compareTo(monthStartStr) < 0) {
        continue;
      }

      // Filtro de status
      if (filtroStatus == 'rascunho' && sDig != 0) {
        continue;
      } else if (filtroStatus == 'pronto' && (sDig == 0 || sEnv >= 2)) {
        continue;
      } else if (filtroStatus == 'empacotado' && sEnv != 1) {
        continue;
      } else if (filtroStatus == 'transmitido' && sEnv != 2) {
        continue;
      } else if (filtroStatus == 'faturado' && sEnv != 3) {
        continue;
      } else if (filtroStatus == 'inconsistente' && sEnv < 4) {
        continue;
      }

      // Resolve descrições locais
      String cliNome = _getString(m, ['ped00_clides', 'clides']);
      String cliFantasia = '';
      if (cliNome.isEmpty && cliCod != 0) {
        try {
          final cr = await db.rawQuery('SELECT * FROM cadcli00 WHERE cli00_codigo = ? LIMIT 1', [cliCod]);
          if (cr.isNotEmpty) {
            cliNome = _getString(cr.first, ['cli00_descri', 'cli00_fantasi', 'cli00_fantas', 'descri', 'nome']);
            cliFantasia = _getString(cr.first, ['cli00_fantasi', 'cli00_fantas', 'fantasia', 'fantas']);
          }
        } catch (_) {}
      }
      if (cliNome.isEmpty) cliNome = 'Cliente #$cliCod';

      String plaDesc = _getString(m, ['ped00_plades', 'plades']);
      if (plaDesc.isEmpty && plaCod.isNotEmpty) {
        try {
          final pr = await db.rawQuery('SELECT * FROM cadpla00 WHERE pla00_codigo = ? LIMIT 1', [plaCod]);
          if (pr.isNotEmpty) {
            plaDesc = _getString(pr.first, ['pla00_descri', 'descri', 'descricao']);
          }
        } catch (_) {}
      }

      String linDesc = _getString(m, ['ped00_lindes', 'lindes']);
      if (linDesc.isEmpty && linCod.isNotEmpty) {
        try {
          final lr = await db.rawQuery('SELECT * FROM cadlin00 WHERE lin00_codigo = ? LIMIT 1', [linCod]);
          if (lr.isNotEmpty) {
            linDesc = _getString(lr.first, ['lin00_descri', 'descri', 'descricao']);
          }
        } catch (_) {}
      }

      String agtDesc = '';
      if (agtCod.isNotEmpty) {
        for (final tbl in ['codage00', 'cadagt00', 'cadage00', 'cadcob00', 'codcob00']) {
          try {
            final t = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table' AND lower(name)=?", [tbl]);
            if (t.isEmpty) continue;
            final agtCols = await db.rawQuery('PRAGMA table_info($tbl)');
            final cnA = agtCols.map((r) => r['name'].toString().toLowerCase()).toSet();
            String? cCod;
            String? cDesc;
            for (final c in ['age00_codigo', 'agt00_codigo', 'agt00_codage', 'cob00_codigo', 'codigo']) {
              if (cnA.contains(c)) { cCod = c; break; }
            }
            for (final c in ['age00_descri', 'agt00_descri', 'agt00_descricao', 'cob00_descri', 'descricao']) {
              if (cnA.contains(c)) { cDesc = c; break; }
            }
            if (cCod != null && cDesc != null) {
              final r = await db.rawQuery('SELECT $cDesc as d FROM $tbl WHERE $cCod = ? LIMIT 1', [agtCod]);
              if (r.isNotEmpty && r.first['d'] != null) {
                agtDesc = r.first['d'].toString();
                break;
              }
            }
          } catch (_) {}
        }
      }

      // Conta quantidade total de itens de pckvendig010
      double totalQtd = 0.0;
      try {
        final tItems = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table' AND lower(name)='pckvendig010'");
        if (tItems.isNotEmpty) {
          final qRow = await db.rawQuery(
            'SELECT SUM(ped10_qtdped) as q, SUM(ped10_qtdbon) as b FROM pckvendig010 WHERE ped10_numped = ?',
            [id],
          );
          if (qRow.isNotEmpty) {
            final q = (qRow.first['q'] is num) ? (qRow.first['q'] as num).toDouble() : 0.0;
            final b = (qRow.first['b'] is num) ? (qRow.first['b'] as num).toDouble() : 0.0;
            totalQtd = q + b;
          }
        }
      } catch (_) {}

      // Filtro de texto por cliente/pedido
      if (filtroTexto.trim().isNotEmpty) {
        final term = filtroTexto.trim().toLowerCase();
        final match = id.toString().contains(term) ||
            cliCod.toString().contains(term) ||
            cliNome.toLowerCase().contains(term) ||
            cliFantasia.toLowerCase().contains(term) ||
            linDesc.toLowerCase().contains(term) ||
            plaDesc.toLowerCase().contains(term);
        if (!match) continue;
      }

      list.add(PedidoHistoricoItem(
        pedidoId: id,
        clienteCodigo: cliCod,
        clienteNome: cliNome,
        clienteFantasia: cliFantasia,
        dataEmissao: dat,
        planoCodigo: plaCod,
        planoDescricao: plaDesc,
        linhaCodigo: linCod,
        linhaDescricao: linDesc,
        agenteCodigo: agtCod,
        agenteDescricao: agtDesc,
        valorProdutos: digTot,
        valorSubstituicao: subTot,
        valorBonus: bonTot,
        totalFatura: fatTot,
        quantidadeItens: totalQtd,
        observacao: obsStr,
        sttDig: sDig,
        sttEnv: sEnv,
        nomePacote: pacStr,
      ));
    }

    print('DEBUG HISTORICO QUERY: Encontrados ${list.length} pedidos no banco');
    return list;
  } catch (e) {
    print('Erro ao listar pedidos historico: $e');
    return [];
  } finally {
    if (db != null && db.isOpen) {
      await db.close();
    }
  }
}

dynamic _getVal(Map<String, dynamic> map, List<String> candidateKeys) {
  for (final k in candidateKeys) {
    if (map.containsKey(k)) return map[k];
    final lowerK = k.toLowerCase();
    for (final entry in map.entries) {
      if (entry.key.toLowerCase() == lowerK) {
        return entry.value;
      }
    }
  }
  return null;
}

int _getInt(Map<String, dynamic> map, List<String> candidateKeys, [int def = 0]) {
  final v = _getVal(map, candidateKeys);
  if (v == null) return def;
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString()) ?? def;
}

double _getDouble(Map<String, dynamic> map, List<String> candidateKeys, [double def = 0.0]) {
  final v = _getVal(map, candidateKeys);
  if (v == null) return def;
  if (v is double) return v;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString()) ?? def;
}

String _getString(Map<String, dynamic> map, List<String> candidateKeys, [String def = '']) {
  final v = _getVal(map, candidateKeys);
  if (v == null) return def;
  return v.toString();
}

/// Exclui um pedido e seus itens do SQLite local
Future<bool> excluirPedidoLocal(int pedidoId) async {
  Database? db;
  try {
    final dbPath = await LocalSalesDatabaseService.getDatabasePath();
    db = await openDatabase(dbPath);

    await db.transaction((txn) async {
      try {
        await txn.rawDelete('DELETE FROM pckvendig010 WHERE ped10_numped = ?', [pedidoId]);
      } catch (_) {}
      try {
        await txn.rawDelete('DELETE FROM pckvendig000 WHERE ped00_numped = ?', [pedidoId]);
      } catch (_) {}
    });

    return true;
  } catch (e) {
    print('Erro ao excluir pedido: $e');
    return false;
  } finally {
    if (db != null && db.isOpen) {
      await db.close();
    }
  }
}

/// Clona um pedido criando um novo número incremental
Future<int?> clonarPedidoLocal(int pedidoOrigemId) async {
  Database? db;
  try {
    final dbPath = await LocalSalesDatabaseService.getDatabasePath();
    db = await openDatabase(dbPath);

    final novoId = await obterProximoNumeroPedido(dbPath: dbPath);

    await db.transaction((txn) async {
      // 1. Clona cabeçalho
      final headerRows = await txn.rawQuery('SELECT * FROM pckvendig000 WHERE ped00_numped = ? LIMIT 1', [pedidoOrigemId]);
      if (headerRows.isNotEmpty) {
        final map = Map<String, dynamic>.from(headerRows.first);
        map['ped00_numped'] = novoId;
        map['ped00_datsys'] = DateFormat('yyyy-MM-dd').format(DateTime.now());
        map['ped00_sttdig'] = 0; // Rascunho
        map['ped00_sttenv'] = 0; // Não enviado
        if (map.containsKey('ped00_pacstr')) map['ped00_pacstr'] = '';

        final cols = map.keys.join(', ');
        final placeholders = List.filled(map.length, '?').join(', ');
        await txn.rawInsert('INSERT INTO pckvendig000 ($cols) VALUES ($placeholders)', map.values.toList());
      }

      // 2. Clona itens
      final itemsRows = await txn.rawQuery('SELECT * FROM pckvendig010 WHERE ped10_numped = ?', [pedidoOrigemId]);
      for (final itemMap in itemsRows) {
        final im = Map<String, dynamic>.from(itemMap);
        im['ped10_numped'] = novoId;
        final cols = im.keys.join(', ');
        final placeholders = List.filled(im.length, '?').join(', ');
        await txn.rawInsert('INSERT INTO pckvendig010 ($cols) VALUES ($placeholders)', im.values.toList());
      }
    });

    return novoId;
  } catch (e) {
    print('Erro ao clonar pedido: $e');
    return null;
  } finally {
    if (db != null && db.isOpen) {
      await db.close();
    }
  }
}
