import 'package:sqflite/sqflite.dart';
import '../data/services/local_sales_database_service.dart';

class PedidoResumoData {
  PedidoResumoData({
    required this.numeroPedido,
    required this.dataEmissao,
    required this.clienteCodigo,
    required this.clienteNome,
    required this.planoCodigo,
    required this.planoDescricao,
    required this.linhaCodigo,
    required this.linhaDescricao,
    required this.agenteCodigo,
    required this.agenteDescricao,
    required this.quantidadeItens,
    required this.valorBonus,
    required this.valorProdutos,
    required this.valorSubstituicao,
    required this.totalFatura,
    required this.observacao,
  });

  final int numeroPedido;
  final String dataEmissao;
  final int clienteCodigo;
  final String clienteNome;
  final String planoCodigo;
  final String planoDescricao;
  final String linhaCodigo;
  final String linhaDescricao;
  final String agenteCodigo;
  final String agenteDescricao;
  final int quantidadeItens;
  final double valorBonus;
  final double valorProdutos;
  final double valorSubstituicao;
  final double totalFatura;
  final String observacao;
}

/// Carrega os 12 indicadores canônicos do resumo do pedido conforme SPEC-047 (item 2.2).
/// Utiliza a conexão singleton ativa sem fechamento indevido (INVARIANT 1).
Future<PedidoResumoData?> carregarPedidoResumo(int pedidoId, {Database? customDb}) async {
  try {
    final db = customDb ?? await LocalSalesDatabaseService.getDatabase();

    // 1. Localiza registro do pedido em pckvendig000
    Map<String, dynamic>? foundRow;

    final t = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table' AND lower(name)='pckvendig000'");
    if (t.isNotEmpty) {
      try {
        final rows = await db.rawQuery(
          'SELECT * FROM pckvendig000 WHERE ped00_numped = ? OR dig00_digcod = ? LIMIT 1',
          [pedidoId, pedidoId],
        );
        if (rows.isNotEmpty) {
          foundRow = rows.first;
        }
      } catch (_) {}

      if (foundRow == null) {
        final allRows = await db.rawQuery('SELECT * FROM pckvendig000');
        for (final r in allRows) {
          final id = _getInt(r, ['dig00_digcod', 'ped00_numped', 'ped00_pedcod', 'ped00_codmov', 'numped', 'pedcod', 'codmov']);
          if (id == pedidoId) {
            foundRow = r;
            break;
          }
        }
      }
    }

    if (foundRow == null) {
      return null;
    }

    final m = foundRow;

    // 2. Extração dos 12 campos canônicos conforme SPEC-047 item 2.2
    final int numPedido = _getInt(m, ['dig00_digcod', 'ped00_numped', 'ped00_pedcod', 'ped00_codmov'], pedidoId);
    final String datSys = _getString(m, ['dig00_datsys', 'ped00_datsys', 'ped00_datemi', 'ped00_datcad', 'datsys', 'datemi']);
    final int cliCod = _getInt(m, ['dig00_clicod', 'ped00_codcli', 'ped00_clicod', 'codcli', 'clicod']);
    final String plaCod = _getString(m, ['dig00_placod', 'ped00_codpla', 'ped00_codpag', 'ped00_placod', 'ped00_digtab', 'codpla', 'codpag']);
    final String linCod = _getString(m, ['dig00_lincod', 'ped00_codlin', 'ped00_lincod', 'codlin']);
    final String agtCod = _getString(m, ['dig00_digagt', 'ped00_digagt', 'ped00_codagt', 'ped00_agtcod', 'ped00_codage', 'codagt', 'agtcod']);
    final double bontot = _getDouble(m, ['dig00_bontot', 'ped00_bontot', 'ped00_bonval', 'bontot']);
    final double digtot = _getDouble(m, ['dig00_digtot', 'ped00_digtot', 'ped00_totprd', 'ped00_valtot', 'ped00_totger', 'digtot']);
    final double subtot = _getDouble(m, ['dig00_subtot', 'ped00_subtot', 'ped00_subval', 'subtot']);
    final double fattotRaw = _getDouble(m, ['dig00_fattot', 'ped00_fattot', 'ped00_totfat', 'fattot'], digtot - subtot);
    final int qtdItm = _getInt(m, ['dig00_qtditm', 'ped00_qtditm', 'ped00_qtdite']);
    final String obs = _getString(m, ['dig00_digobs', 'ped00_digobs', 'digobs', 'ped00_observ', 'ped00_obs', 'ped00_observacao', 'observ', 'obs']);

    // Validação complementar de itens e totais via pckvendig010 se necessário
    int qtdItensFinal = qtdItm;
    double digtotFinal = digtot;
    double bontotFinal = bontot;
    try {
      final t10 = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table' AND lower(name)='pckvendig010'");
      if (t10.isNotEmpty) {
        final cnt = await db.rawQuery(
          'SELECT COUNT(*) as c, SUM(ped10_totprd) as tot, SUM(ped10_qtdbon) as qb FROM pckvendig010 WHERE ped10_numped = ?',
          [pedidoId],
        );
        if (cnt.isNotEmpty) {
          final rowC = cnt.first;
          final cVal = _getInt(rowC, ['c']);
          if (qtdItensFinal == 0 && cVal > 0) qtdItensFinal = cVal;
          if (digtotFinal == 0.0 && rowC['tot'] != null) {
            digtotFinal = _getDouble(rowC, ['tot']);
          }
        }
      }
    } catch (_) {}

    // Resolução de nomes descritivos
    String clienteNome = _getString(m, ['ped00_clides', 'clides']);
    String planoDesc = _getString(m, ['ped00_plades', 'plades']);
    String linhaDesc = _getString(m, ['ped00_lindes', 'lindes']);
    String agenteDesc = '';

    if (clienteNome.isEmpty && cliCod != 0) {
      try {
        final cliRows = await db.rawQuery('SELECT * FROM cadcli00 WHERE cli00_codigo = ? LIMIT 1', [cliCod]);
        if (cliRows.isNotEmpty) {
          clienteNome = _getString(cliRows.first, ['cli00_descri', 'cli00_fantasi', 'cli00_fantas', 'descri', 'nome']);
        }
      } catch (_) {}
    }

    if (planoDesc.isEmpty && plaCod.isNotEmpty) {
      try {
        final plaRows = await db.rawQuery("SELECT * FROM cadpla00 WHERE pla00_codigo = ? LIMIT 1", [plaCod]);
        if (plaRows.isNotEmpty) planoDesc = _getString(plaRows.first, ['pla00_descri', 'descri', 'descricao']);
      } catch (_) {}
    }

    if (linhaDesc.isEmpty && linCod.isNotEmpty) {
      try {
        final linRows = await db.rawQuery("SELECT * FROM cadlin00 WHERE lin00_codigo = ? LIMIT 1", [linCod]);
        if (linRows.isNotEmpty) linhaDesc = _getString(linRows.first, ['lin00_descri', 'descri', 'descricao']);
      } catch (_) {}
    }

    if (agtCod.isNotEmpty) {
      for (final tbl in ['cadagt00', 'codage00', 'cadage00', 'cadcob00', 'codcob00']) {
        try {
          final exists = await db.rawQuery(
              "SELECT name FROM sqlite_master WHERE type='table' AND lower(name)=?", [tbl]);
          if (exists.isEmpty) continue;
          final colsA = await db.rawQuery('PRAGMA table_info($tbl)');
          final cnA = colsA.map((r) => r['name'].toString().toLowerCase()).toSet();
          String? codColA;
          String? descColA;
          for (final c in ['agt00_codigo', 'age00_codigo', 'agt00_codage', 'agt00_codagt', 'cob00_codigo', 'cob00_codcob', 'codigo']) {
            if (cnA.contains(c)) { codColA = c; break; }
          }
          for (final c in ['agt00_descri', 'agt00_descricao', 'agt00_nome', 'age00_descri', 'cob00_descri', 'descricao', 'descri', 'nome']) {
            if (cnA.contains(c)) { descColA = c; break; }
          }
          if (codColA == null || descColA == null) continue;
          final agtRows = await db.rawQuery('SELECT $descColA as d FROM $tbl WHERE $codColA = ? LIMIT 1', [agtCod]);
          if (agtRows.isNotEmpty && agtRows.first['d'] != null) {
            agenteDesc = agtRows.first['d'].toString();
            break;
          }
        } catch (_) {}
      }
    }

    final double finalFatTot = fattotRaw != 0 ? fattotRaw : (digtotFinal - subtot);

    return PedidoResumoData(
      numeroPedido: numPedido,
      dataEmissao: datSys.isNotEmpty ? datSys : DateTime.now().toString().split(' ').first,
      clienteCodigo: cliCod,
      clienteNome: clienteNome.isNotEmpty ? clienteNome : 'Cliente $cliCod',
      planoCodigo: plaCod,
      planoDescricao: planoDesc.isNotEmpty ? planoDesc : (plaCod.isNotEmpty ? 'Plano $plaCod' : 'À Vista'),
      linhaCodigo: linCod,
      linhaDescricao: linhaDesc.isNotEmpty ? linhaDesc : (linCod.isNotEmpty ? 'Linha $linCod' : 'Padrão'),
      agenteCodigo: agtCod,
      agenteDescricao: agenteDesc.isNotEmpty ? agenteDesc : (agtCod.isNotEmpty ? 'Agente $agtCod' : 'Carteira'),
      quantidadeItens: qtdItensFinal,
      valorBonus: bontotFinal,
      valorProdutos: digtotFinal,
      valorSubstituicao: subtot,
      totalFatura: finalFatTot,
      observacao: obs,
    );
  } catch (e) {
    print('Erro ao carregar pedido resumo: $e');
    return null;
  }
}

dynamic _getVal(Map<String, dynamic> map, List<String> candidateKeys) {
  for (final k in candidateKeys) {
    dynamic val;
    if (map.containsKey(k)) {
      val = map[k];
    } else {
      final lowerK = k.toLowerCase();
      for (final entry in map.entries) {
        if (entry.key.toLowerCase() == lowerK) {
          val = entry.value;
          break;
        }
      }
    }
    if (val != null && val.toString().trim().isNotEmpty) {
      return val;
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
