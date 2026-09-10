import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:intl/intl.dart';
import '/app_state.dart';
import '/data/services/local_sales_database_service.dart';
import '/functions/proximo_numero_pedido.dart';

class PedidoClonadoInfo {
  PedidoClonadoInfo({
    required this.novoPedidoId,
    required this.clienteCodigo,
    required this.clienteNome,
    required this.linhaCodigo,
    required this.planoCodigo,
    required this.linhaDescricao,
    required this.planoDescricao,
    this.clienteCnpj = '',
    this.clienteCidade = '',
    this.clienteLimite = '',
    this.clienteEndereco = '',
    this.clienteFantasia = '',
  });

  final int novoPedidoId;
  final int clienteCodigo;
  final String clienteNome;
  final String linhaCodigo;
  final String planoCodigo;
  final String linhaDescricao;
  final String planoDescricao;
  final String clienteCnpj;
  final String clienteCidade;
  final String clienteLimite;
  final String clienteEndereco;
  final String clienteFantasia;
}

class PacoteItem {
  PacoteItem({
    required this.nomeArquivo,
    required this.totalPedidos,
    required this.pedidosIds,
    required this.data,
    required this.sttEnv,
    required this.tamanhoBytes,
    required this.totalValor,
    required this.existeEmTemp,
    required this.caminhoArquivo,
  });

  final String nomeArquivo;
  final int totalPedidos;
  final List<int> pedidosIds;
  final String data;
  final int sttEnv; // 1 = Pendente / Empacotado, 2 = Enviado / Confirmado
  final int tamanhoBytes;
  final double totalValor;
  final bool existeEmTemp;
  final String caminhoArquivo;

  bool get isPendente => sttEnv == 1 || existeEmTemp;
  bool get isEnviado => sttEnv == 2 && !existeEmTemp;

  PacoteItem copyWith({
    String? nomeArquivo,
    int? totalPedidos,
    List<int>? pedidosIds,
    String? data,
    int? sttEnv,
    int? tamanhoBytes,
    double? totalValor,
    bool? existeEmTemp,
    String? caminhoArquivo,
  }) {
    return PacoteItem(
      nomeArquivo: nomeArquivo ?? this.nomeArquivo,
      totalPedidos: totalPedidos ?? this.totalPedidos,
      pedidosIds: pedidosIds ?? this.pedidosIds,
      data: data ?? this.data,
      sttEnv: sttEnv ?? this.sttEnv,
      tamanhoBytes: tamanhoBytes ?? this.tamanhoBytes,
      totalValor: totalValor ?? this.totalValor,
      existeEmTemp: existeEmTemp ?? this.existeEmTemp,
      caminhoArquivo: caminhoArquivo ?? this.caminhoArquivo,
    );
  }
}


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
    this.clienteCnpj = '',
    this.clienteCidade = '',
    this.clienteLimite = '',
    this.clienteEndereco = '',
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
  final String clienteCnpj;
  final String clienteCidade;
  final String clienteLimite;
  final String clienteEndereco;

  bool get isRascunho => sttDig == 0;
  bool get isPendentePacote => sttDig == 1 && (sttEnv == 0 || nomePacote.isEmpty);
  bool get isEmpacotado => sttDig == 1 && sttEnv == 1 && nomePacote.isNotEmpty;
  bool get isTransmitido => sttEnv == 2;
  bool get isFaturado => sttEnv == 3;
  bool get isInconsistente => sttEnv >= 4;

  /// Indica se o pedido está concluído e livre para ser incluído em um novo pacote
  bool get podeEmpacotar => sttDig == 1 && sttEnv == 0 && nomePacote.isEmpty;
  bool get isProntoEnvio => isPendentePacote;
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

          final sDig = _getInt(r, ['ped00_sttdig', 'ped00_status', 'ped00_sitped', 'sttdig', 'status']);
          final sEnv = _getInt(r, ['ped00_sttenv', 'ped00_enviado', 'ped00_flgenv', 'sttenv', 'enviado']);
          final pac = _getString(r, ['ped00_pacstr', 'ped00_pacote', 'pacstr', 'pacote']).trim();

          // Exibe apenas pedidos concluídos (sttdig == 1) e que ainda NÃO foram empacotados (sttenv == 0 e pac vazio)
          if (sDig == 1 && sEnv == 0 && pac.isEmpty) {
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
      } else if ((filtroStatus == 'pronto' || filtroStatus == 'pendente') && (sDig == 0 || sEnv >= 1 || pacStr.isNotEmpty)) {
        continue;
      } else if (filtroStatus == 'empacotado' && (sEnv != 1 || pacStr.isEmpty)) {
        continue;
      } else if (filtroStatus == 'transmitido' && sEnv != 2) {
        continue;
      } else if (filtroStatus == 'faturado' && sEnv != 3) {
        continue;
      } else if (filtroStatus == 'inconsistente' && sEnv < 4) {
        continue;
      }

      // Resolve descrições locais e dados do cliente
      String cliNome = _getString(m, ['ped00_clides', 'clides']);
      String cliFantasia = '';
      String cliCnpj = '';
      String cliCidade = '';
      String cliLimite = '';
      String cliEndereco = '';

      if (cliCod != 0) {
        try {
          final cr = await db.rawQuery('SELECT * FROM cadcli00 WHERE cli00_codigo = ? LIMIT 1', [cliCod]);
          if (cr.isNotEmpty) {
            final cMap = cr.first;
            if (cliNome.isEmpty) {
              cliNome = _getString(cMap, ['cli00_descri', 'descri', 'cli00_fantasi', 'cli00_fantas', 'nome']);
            }
            cliFantasia = _getString(cMap, ['cli00_fantasi', 'cli00_fantas', 'fantasia', 'fantas']);
            cliCnpj = _getString(cMap, ['cli00_cpfcnp', 'cli00_cgc', 'cli00_cpf', 'cli00_cnpj', 'cpfcnp', 'cgc', 'cpf', 'cnpj']);
            
            final cid = _getString(cMap, ['cli00_ciddes', 'cli00_cidade', 'cli00_cidcod', 'cidade']);
            final uf = _getString(cMap, ['cli00_estsgl', 'cli00_uf', 'uf']);
            if (cid.isNotEmpty && uf.isNotEmpty) {
              cliCidade = '$cid - $uf';
            } else if (cid.isNotEmpty) {
              cliCidade = cid;
            }

            final end = _getString(cMap, ['cli00_endere', 'cli00_endereco', 'endereco']);
            final num = _getString(cMap, ['cli00_endnum', 'numero']);
            final bai = _getString(cMap, ['cli00_bairro', 'bairro']);
            String fullEnd = end;
            if (num.isNotEmpty) fullEnd += ', $num';
            if (bai.isNotEmpty) fullEnd += ' - $bai';
            cliEndereco = fullEnd;

            final lim = _getDouble(cMap, ['cli00_crelim', 'cli00_limite', 'cli00_limcre', 'crelim', 'limite', 'limcre']);
            if (lim > 0) {
              cliLimite = lim.toStringAsFixed(2).replaceAll('.', ',');
            }
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
        clienteCnpj: cliCnpj,
        clienteCidade: cliCidade,
        clienteLimite: cliLimite,
        clienteEndereco: cliEndereco,
      ));
    }

    print('DEBUG HISTORICO QUERY: Encontrados ${list.length} pedidos no banco');
    return list;
  } catch (e) {
    print('Erro ao listar pedidos historico: $e');
    return [];
  }
}

dynamic _getVal(Map<String, dynamic> map, List<String> candidateKeys) {
  for (final k in candidateKeys) {
    if (map.containsKey(k) && map[k] != null) {
      if (map[k] is String && (map[k] as String).trim().isEmpty) {
        // Ignora string vazia e tenta próxima chave candidata
      } else {
        return map[k];
      }
    }
    final lowerK = k.toLowerCase();
    for (final entry in map.entries) {
      if (entry.key.toLowerCase() == lowerK && entry.value != null) {
        if (entry.value is String && (entry.value as String).trim().isEmpty) {
          // Ignora string vazia e tenta próxima chave candidata
        } else {
          return entry.value;
        }
      }
    }
  }
  return null;
}

int _getInt(Map<String, dynamic> map, List<String> candidateKeys, [int def = 0]) {
  int? firstFound;
  for (final k in candidateKeys) {
    dynamic val;
    if (map.containsKey(k) && map[k] != null) {
      val = map[k];
    } else {
      final lowerK = k.toLowerCase();
      for (final entry in map.entries) {
        if (entry.key.toLowerCase() == lowerK && entry.value != null) {
          val = entry.value;
          break;
        }
      }
    }
    if (val != null) {
      int i = def;
      if (val is int) {
        i = val;
      } else if (val is num) {
        i = val.toInt();
      } else {
        i = int.tryParse(val.toString()) ?? def;
      }
      if (i != 0) return i;
      firstFound ??= i;
    }
  }
  return firstFound ?? def;
}

double _getDouble(Map<String, dynamic> map, List<String> candidateKeys, [double def = 0.0]) {
  double? firstFound;
  for (final k in candidateKeys) {
    dynamic val;
    if (map.containsKey(k) && map[k] != null) {
      val = map[k];
    } else {
      final lowerK = k.toLowerCase();
      for (final entry in map.entries) {
        if (entry.key.toLowerCase() == lowerK && entry.value != null) {
          val = entry.value;
          break;
        }
      }
    }
    if (val != null) {
      double d = def;
      if (val is double) {
        d = val;
      } else if (val is num) {
        d = val.toDouble();
      } else {
        d = double.tryParse(val.toString()) ?? def;
      }
      if (d != 0.0) return d;
      firstFound ??= d;
    }
  }
  return firstFound ?? def;
}

String _getString(Map<String, dynamic> map, List<String> candidateKeys, [String def = '']) {
  final v = _getVal(map, candidateKeys);
  if (v == null) return def;
  return v.toString();
}

/// Exclui um pedido e seus itens do SQLite local
Future<bool> excluirPedidoLocal(int pedidoId) async {
  try {
    final db = await LocalSalesDatabaseService.getDatabase();

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
  }
}

/// Clona um pedido criando um novo número incremental e copiando cabeçalho + itens em rascunho (em aberto)
Future<PedidoClonadoInfo?> clonarPedidoLocal(int pedidoOrigemId) async {
  try {
    final db = await LocalSalesDatabaseService.getDatabase();
    final novoId = await obterProximoNumeroPedido();

    // 1. Identifica colunas de pckvendig000 e busca pedido original
    final headerCols = await db.rawQuery('PRAGMA table_info(pckvendig000)');
    final headerColNames = headerCols.map((r) => r['name']?.toString().toLowerCase()).toSet();

    String colNum0 = 'ped00_numped';
    for (final c in ['ped00_numped', 'ped00_pedcod', 'ped00_codmov', 'numped']) {
      if (headerColNames.contains(c)) { colNum0 = c; break; }
    }

    final headerRows = await db.rawQuery('SELECT * FROM pckvendig000 WHERE $colNum0 = ? LIMIT 1', [pedidoOrigemId]);
    if (headerRows.isEmpty) {
      print('Erro clonar: pedido original #$pedidoOrigemId não encontrado no SQLite');
      return null;
    }

    final origHeader = Map<String, dynamic>.from(headerRows.first);

    // Identifica campos do cliente, linha e plano
    final cliCod = _getInt(origHeader, ['ped00_codcli', 'ped00_clicod', 'codcli']);
    String cliNome = _getString(origHeader, ['ped00_clides', 'clides']);
    final linCod = _getString(origHeader, ['ped00_codlin', 'ped00_lincod', 'codlin']);
    String linDes = _getString(origHeader, ['ped00_lindes', 'lindes']);
    final plaCod = _getString(origHeader, ['ped00_codpla', 'ped00_codpag', 'codpla', 'codpag']);
    String plaDes = _getString(origHeader, ['ped00_plades', 'plades']);

    String cliCnpj = '';
    String cliCidade = '';
    String cliLimite = '';
    String cliEndereco = '';
    String cliFantasia = '';

    // Busca detalhes completos do cliente em cadcli00
    if (cliCod != 0) {
      try {
        final cr = await db.rawQuery('SELECT * FROM cadcli00 WHERE cli00_codigo = ? LIMIT 1', [cliCod]);
        if (cr.isNotEmpty) {
          final cMap = cr.first;
          if (cliNome.isEmpty) {
            cliNome = _getString(cMap, ['cli00_descri', 'descri', 'cli00_fantasi', 'cli00_fantas', 'nome']);
          }
          cliFantasia = _getString(cMap, ['cli00_fantasi', 'cli00_fantas', 'fantasia']);
          cliCnpj = _getString(cMap, ['cli00_cpfcnp', 'cli00_cgc', 'cli00_cpf', 'cli00_cnpj', 'cpfcnp', 'cgc', 'cpf', 'cnpj']);
          
          final cid = _getString(cMap, ['cli00_ciddes', 'cli00_cidade', 'cli00_cidcod', 'cidade']);
          final uf = _getString(cMap, ['cli00_estsgl', 'cli00_uf', 'uf']);
          if (cid.isNotEmpty && uf.isNotEmpty) {
            cliCidade = '$cid - $uf';
          } else if (cid.isNotEmpty) {
            cliCidade = cid;
          }

          final end = _getString(cMap, ['cli00_endere', 'cli00_endereco', 'endereco']);
          final num = _getString(cMap, ['cli00_endnum', 'numero']);
          final bai = _getString(cMap, ['cli00_bairro', 'bairro']);
          String fullEnd = end;
          if (num.isNotEmpty) fullEnd += ', $num';
          if (bai.isNotEmpty) fullEnd += ' - $bai';
          cliEndereco = fullEnd;

          final lim = _getDouble(cMap, ['cli00_crelim', 'cli00_limite', 'cli00_limcre', 'crelim', 'limite', 'limcre']);
          if (lim > 0) {
            cliLimite = lim.toStringAsFixed(2).replaceAll('.', ',');
          }
        }
      } catch (_) {}
    }

    if (linDes.isEmpty && linCod.isNotEmpty) {
      try {
        final lr = await db.rawQuery('SELECT lin00_descri FROM cadlin00 WHERE lin00_codigo = ? LIMIT 1', [int.tryParse(linCod) ?? 0]);
        if (lr.isNotEmpty) linDes = _getString(lr.first, ['lin00_descri', 'descri']);
      } catch (_) {}
    }

    if (plaDes.isEmpty && plaCod.isNotEmpty) {
      try {
        final pr = await db.rawQuery('SELECT pla00_descri FROM cadpla00 WHERE pla00_codigo = ? LIMIT 1', [int.tryParse(plaCod) ?? 0]);
        if (pr.isNotEmpty) plaDes = _getString(pr.first, ['pla00_descri', 'descri']);
      } catch (_) {}
    }

    // 2. Busca itens do pedido original
    final itemCols = await db.rawQuery('PRAGMA table_info(pckvendig010)');
    final itemColNames = itemCols.map((r) => r['name']?.toString().toLowerCase()).toSet();

    String colNum10 = 'ped10_numped';
    for (final c in ['ped10_numped', 'ped10_pedcod', 'ped10_codmov', 'numped']) {
      if (itemColNames.contains(c)) { colNum10 = c; break; }
    }

    final itemsRows = await db.rawQuery('SELECT * FROM pckvendig010 WHERE $colNum10 = ?', [pedidoOrigemId]);

    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());

    // 3. Monta cabeçalho clonado
    final cloneHeader = Map<String, dynamic>.from(origHeader);
    for (final c in ['ped00_numped', 'ped00_pedcod', 'ped00_codmov', 'numped', 'pedcod', 'codmov']) {
      if (cloneHeader.containsKey(c)) cloneHeader[c] = novoId;
    }
    cloneHeader['ped00_numped'] = novoId;

    // Status: 0 = Em Aberto / Rascunho / Em Digitação
    for (final c in ['ped00_sttdig', 'ped00_status', 'ped00_sitped', 'sttdig', 'status']) {
      if (cloneHeader.containsKey(c)) cloneHeader[c] = 0;
    }
    cloneHeader['ped00_sttdig'] = 0;

    // Status envio: 0 = Não enviado / Aguardando Pacote
    for (final c in ['ped00_sttenv', 'ped00_enviado', 'ped00_flgenv', 'sttenv', 'enviado']) {
      if (cloneHeader.containsKey(c)) cloneHeader[c] = 0;
    }
    cloneHeader['ped00_sttenv'] = 0;

    // Limpa identificador de pacote
    for (final c in ['ped00_pacstr', 'ped00_pacote', 'pacstr', 'pacote']) {
      if (cloneHeader.containsKey(c)) cloneHeader[c] = '';
    }

    // Atualiza datas
    for (final c in ['ped00_datsys', 'ped00_datemi', 'ped00_datcad', 'datsys', 'datemi', 'datcad']) {
      if (cloneHeader.containsKey(c)) cloneHeader[c] = todayStr;
    }

    if (cliNome.isNotEmpty && cloneHeader.containsKey('ped00_clides')) cloneHeader['ped00_clides'] = cliNome;
    if (linDes.isNotEmpty && cloneHeader.containsKey('ped00_lindes')) cloneHeader['ped00_lindes'] = linDes;
    if (plaDes.isNotEmpty && cloneHeader.containsKey('ped00_plades')) cloneHeader['ped00_plades'] = plaDes;

    // 4. Executa inserção atômica
    await db.transaction((txn) async {
      final hCols = cloneHeader.keys.join(', ');
      final hPlaceholders = List.filled(cloneHeader.length, '?').join(', ');
      await txn.rawInsert(
        'INSERT OR REPLACE INTO pckvendig000 ($hCols) VALUES ($hPlaceholders)',
        cloneHeader.values.toList(),
      );

      for (final itemMap in itemsRows) {
        final im = Map<String, dynamic>.from(itemMap);
        for (final c in ['ped10_numped', 'ped10_pedcod', 'ped10_codmov', 'numped', 'pedcod', 'codmov']) {
          if (im.containsKey(c)) im[c] = novoId;
        }
        im['ped10_numped'] = novoId;

        // Garante consistência de colunas canônicas
        final codP = _getString(im, ['ped10_codprd', 'ped10_codpro', 'ped10_procod', 'codprd', 'codpro']);
        final desP = _getString(im, ['ped10_descri', 'ped10_descricao', 'ped10_prodes', 'descri', 'prodes']);
        final uniP = _getString(im, ['ped10_unidpri', 'ped10_unidade', 'ped10_unimed', 'unidpri', 'unimed']);
        final qtdP = _getDouble(im, ['ped10_qtdped', 'ped10_qtd', 'ped10_quantidade', 'qtdped', 'qtd']);
        final pcoP = _getDouble(im, ['ped10_pcosub', 'ped10_prcuni', 'ped10_vlruni', 'ped10_preco', 'pcosub', 'vlruni']);
        final totP = _getDouble(im, ['ped10_totprd', 'ped10_totite', 'ped10_valtot', 'ped10_vlrtot', 'totprd']);

        if (im.containsKey('ped10_codprd') && (im['ped10_codprd'] == null || im['ped10_codprd'] == '')) im['ped10_codprd'] = codP;
        if (im.containsKey('ped10_descri') && (im['ped10_descri'] == null || im['ped10_descri'] == '')) im['ped10_descri'] = desP;
        if (im.containsKey('ped10_unidpri') && (im['ped10_unidpri'] == null || im['ped10_unidpri'] == '')) im['ped10_unidpri'] = uniP.isNotEmpty ? uniP : 'UN';
        if (im.containsKey('ped10_qtdped') && (_getDouble(im, ['ped10_qtdped']) == 0.0)) im['ped10_qtdped'] = qtdP;
        if (im.containsKey('ped10_pcosub') && (_getDouble(im, ['ped10_pcosub']) == 0.0)) im['ped10_pcosub'] = pcoP;
        if (im.containsKey('ped10_totprd') && (_getDouble(im, ['ped10_totprd']) == 0.0)) im['ped10_totprd'] = totP > 0 ? totP : (qtdP * pcoP);

        final iCols = im.keys.join(', ');
        final iPlaceholders = List.filled(im.length, '?').join(', ');
        await txn.rawInsert(
          'INSERT OR REPLACE INTO pckvendig010 ($iCols) VALUES ($iPlaceholders)',
          im.values.toList(),
        );
      }
    });

    final info = PedidoClonadoInfo(
      novoPedidoId: novoId,
      clienteCodigo: cliCod,
      clienteNome: cliNome,
      linhaCodigo: linCod,
      planoCodigo: plaCod,
      linhaDescricao: linDes,
      planoDescricao: plaDes,
      clienteCnpj: cliCnpj,
      clienteCidade: cliCidade,
      clienteLimite: cliLimite,
      clienteEndereco: cliEndereco,
      clienteFantasia: cliFantasia,
    );

    print('[clonarPedidoLocal] Pedido #$pedidoOrigemId clonado com sucesso para #${info.novoPedidoId} (${itemsRows.length} itens, sttdig=0, sttenv=0)');
    return info;
  } catch (e, stack) {
    print('Erro ao clonar pedido: $e\n$stack');
    return null;
  }
}

/// Consulta estruturada de todos os lotes de pacotes (.pac) no SQLite e disco
Future<List<PacoteItem>> listarPacotesAgrupados({String filtro = 'todos'}) async {
  try {
    final Map<String, PacoteItem> pacotesMap = {};

    // 1. Inspeciona o diretório temporário (fila ativa de envio)
    final tempDir = await getTemporaryDirectory();
    final tempFiles = tempDir
        .listSync()
        .whereType<File>()
        .where((f) {
          final name = p.basename(f.path).toLowerCase();
          return name.startsWith('p') && name.endsWith('.pac');
        })
        .toList();

    for (final tf in tempFiles) {
      final name = p.basename(tf.path);
      final stat = tf.statSync();
      final dateStr = DateFormat('yyyy-MM-dd HH:mm').format(stat.modified);
      pacotesMap[name] = PacoteItem(
        nomeArquivo: name,
        totalPedidos: 0,
        pedidosIds: [],
        data: dateStr,
        sttEnv: 1, // Fila temp = pendente de envio
        tamanhoBytes: stat.size,
        totalValor: 0.0,
        existeEmTemp: true,
        caminhoArquivo: tf.path,
      );
    }

    // 2. Inspeciona os registros em SQLite (pckvendig000)
    try {
      final db = await LocalSalesDatabaseService.getDatabase();
      final t = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND lower(name)='pckvendig000'",
      );
      if (t.isNotEmpty) {
        final cols = await db.rawQuery('PRAGMA table_info(pckvendig000)');
        final colNames = cols.map((r) => r['name']?.toString().toLowerCase()).toSet();

        String? colPac;
        for (final c in ['ped00_pacstr', 'ped00_pacote', 'pacstr', 'pacote']) {
          if (colNames.contains(c)) { colPac = c; break; }
        }

        String colNum = 'ped00_numped';
        for (final c in ['ped00_numped', 'ped00_pedcod', 'ped00_codmov', 'numped']) {
          if (colNames.contains(c)) { colNum = c; break; }
        }

        if (colPac != null) {
          final rows = await db.rawQuery('''
            SELECT 
              $colPac as pac_nome,
              MIN(ped00_sttenv) as min_sttenv,
              MAX(ped00_sttenv) as max_sttenv,
              COUNT(DISTINCT $colNum) as total_ped,
              GROUP_CONCAT(DISTINCT $colNum) as ids_str,
              MAX(ped00_datsys) as max_dat,
              SUM(ped_val) as total_val
            FROM (
              SELECT 
                $colPac,
                $colNum,
                MIN(ped00_sttenv) as ped00_sttenv,
                MAX(ped00_datsys) as ped00_datsys,
                MAX(CASE WHEN ped00_fattot > 0 THEN ped00_fattot ELSE ped00_digtot END) as ped_val
              FROM pckvendig000 
              WHERE $colPac IS NOT NULL AND TRIM($colPac) != ''
              GROUP BY $colPac, $colNum
            )
            GROUP BY $colPac
          ''');

          for (final r in rows) {
            final pacNome = r['pac_nome']?.toString().trim() ?? '';
            if (pacNome.isEmpty) continue;

            final idsStr = r['ids_str']?.toString() ?? '';
            final ids = idsStr
                .split(',')
                .map((s) => int.tryParse(s.trim()) ?? 0)
                .where((id) => id > 0)
                .toSet()
                .toList();
            final totalPed = ids.isNotEmpty ? ids.length : ((r['total_ped'] is num) ? (r['total_ped'] as num).toInt() : 0);
            final maxDat = r['max_dat']?.toString() ?? '';
            final totalVal = (r['total_val'] is num) ? (r['total_val'] as num).toDouble() : 0.0;
            final minEnv = (r['min_sttenv'] is num) ? (r['min_sttenv'] as num).toInt() : 0;
            final maxEnv = (r['max_sttenv'] is num) ? (r['max_sttenv'] as num).toInt() : 0;

            final bool inTemp = pacotesMap.containsKey(pacNome);
            // Se está no temp, sttEnv é 1 (Pendente). Se saiu do temp e maxEnv >= 2, é 2 (Enviado).
            final int sEnv = inTemp ? 1 : (maxEnv >= 2 ? 2 : (minEnv >= 1 ? 1 : 1));

            int sizeBytes = 0;
            String path = '';
            if (inTemp) {
              sizeBytes = pacotesMap[pacNome]!.tamanhoBytes;
              path = pacotesMap[pacNome]!.caminhoArquivo;
            } else {
              try {
                final docsDir = await getApplicationDocumentsDirectory();
                final docFile = File(p.join(docsDir.path, pacNome));
                if (docFile.existsSync()) {
                  sizeBytes = docFile.lengthSync();
                  path = docFile.path;
                }
              } catch (_) {}
            }

            pacotesMap[pacNome] = PacoteItem(
              nomeArquivo: pacNome,
              totalPedidos: totalPed,
              pedidosIds: ids,
              data: maxDat.isNotEmpty ? maxDat : (pacotesMap[pacNome]?.data ?? ''),
              sttEnv: sEnv,
              tamanhoBytes: sizeBytes,
              totalValor: totalVal,
              existeEmTemp: inTemp,
              caminhoArquivo: path,
            );
          }
        }
      }

      // 2.1 Enriquece com dados de pac00 caso exista
      try {
        final pac00Check = await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND lower(name)='pac00'",
        );
        if (pac00Check.isNotEmpty) {
          final pacRows = await db.rawQuery('''
            SELECT 
              pac00_pacsrc as pac_nome,
              pac00_pacqtd as total_ped,
              pac00_pactot as total_val,
              pac00_pacdat as pac_dat,
              pac00_sttenv as stt_env
            FROM pac00
            WHERE pac00_pacsrc IS NOT NULL AND TRIM(pac00_pacsrc) != ''
          ''');
          for (final pr in pacRows) {
            final pName = pr['pac_nome']?.toString().trim() ?? '';
            if (pName.isEmpty) continue;
            final qtd = (pr['total_ped'] is num) ? (pr['total_ped'] as num).toInt() : 0;
            final val = (pr['total_val'] is num) ? (pr['total_val'] as num).toDouble() : 0.0;
            final dat = pr['pac_dat']?.toString() ?? '';

            if (pacotesMap.containsKey(pName)) {
              final existing = pacotesMap[pName]!;
              pacotesMap[pName] = existing.copyWith(
                totalPedidos: existing.totalPedidos > 0 ? existing.totalPedidos : qtd,
                totalValor: existing.totalValor > 0 ? existing.totalValor : val,
                data: existing.data.isNotEmpty ? existing.data : dat,
              );
            }
          }
        }
      } catch (_) {}
    } catch (e) {
      print('Erro ao consultar pacotes no SQLite: $e');
    }


    // 3. Inspeciona o diretório de documentos para pacotes históricos transmitidos
    try {
      final docsDir = await getApplicationDocumentsDirectory();
      final docFiles = docsDir
          .listSync()
          .whereType<File>()
          .where((f) {
            final name = p.basename(f.path).toLowerCase();
            return name.startsWith('p') && name.endsWith('.pac');
          })
          .toList();

      for (final df in docFiles) {
        final name = p.basename(df.path);
        if (!pacotesMap.containsKey(name)) {
          final stat = df.statSync();
          final dateStr = DateFormat('yyyy-MM-dd HH:mm').format(stat.modified);
          pacotesMap[name] = PacoteItem(
            nomeArquivo: name,
            totalPedidos: 1,
            pedidosIds: [],
            data: dateStr,
            sttEnv: 2, // Se está apenas em documents, foi transmitido
            tamanhoBytes: stat.size,
            totalValor: 0.0,
            existeEmTemp: false,
            caminhoArquivo: df.path,
          );
        }
      }
    } catch (_) {}

    var lista = pacotesMap.values.toList();

    // Filtros
    if (filtro == 'pendentes') {
      lista = lista.where((p) => p.isPendente).toList();
    } else if (filtro == 'enviados') {
      lista = lista.where((p) => p.isEnviado).toList();
    }

    // Ordena pelo nome do pacote decrescente (ex: p71-10.pac antes de p71-2.pac)
    lista.sort((a, b) {
      int getSeq(String name) {
        try {
          final clean = name.replaceAll(RegExp(r'[^0-9\-]'), '');
          final parts = clean.split('-');
          if (parts.length >= 2) return int.tryParse(parts.last) ?? 0;
          return int.tryParse(clean) ?? 0;
        } catch (_) {
          return 0;
        }
      }
      return getSeq(b.nomeArquivo).compareTo(getSeq(a.nomeArquivo));
    });

    return lista;
  } catch (e) {
    print('Erro em listarPacotesAgrupados: $e');
    return [];
  }
}
