import 'dart:io';
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

Future<PedidoResumoData?> carregarPedidoResumo(int pedidoId) async {
  try {
    final pathsToCheck = await LocalSalesDatabaseService.getTargetDatabasePaths();

    Map<String, dynamic>? foundRow;
    Database? activeDb;

    for (final path in pathsToCheck) {
      Database? d;
      try {
        d = await openDatabase(path);
        final t = await d.rawQuery("SELECT name FROM sqlite_master WHERE type='table' AND lower(name)='pckvendig000'");
        if (t.isNotEmpty) {
          final rows = await d.rawQuery('SELECT * FROM pckvendig000');
          for (final r in rows) {
            final id = _getInt(r, ['ped00_numped', 'ped00_pedcod', 'ped00_codmov', 'numped', 'pedcod', 'codmov']);
            if (id == pedidoId) {
              foundRow = r;
              activeDb = d;
              d = null; // transfere responsabilidade do close para activeDb
              break;
            }
          }
        }
        if (foundRow != null) break;
      } catch (e) {
        print('[carregarPedidoResumo] Erro buscando pedido $pedidoId em $path: $e');
      } finally {
        // Fecha 'd' somente se não foi transferido para activeDb
        if (d != null && d.isOpen) await d.close();
      }
    }

    if (foundRow == null || activeDb == null) {
      return null;
    }

    final m = foundRow;
    final db = activeDb;

    final cliCod = _getInt(m, ['ped00_codcli', 'ped00_clicod', 'codcli', 'clicod']);
    final plaCod = _getString(m, ['ped00_codpla', 'ped00_codpag', 'ped00_placod', 'ped00_digtab', 'codpla', 'codpag']);
    final linCod = _getString(m, ['ped00_codlin', 'ped00_lincod', 'codlin']);
    final agtCod = _getString(m, ['ped00_codagt', 'ped00_agtcod', 'ped00_codage', 'ped00_digagt', 'codagt', 'agtcod']);
    final datSys = _getString(m, ['ped00_datsys', 'ped00_datemi', 'ped00_datcad', 'datsys', 'datemi']);
    final bontot = _getDouble(m, ['ped00_bontot', 'ped00_bonval', 'bontot']);
    final digtot = _getDouble(m, ['ped00_digtot', 'ped00_subtot', 'ped00_totprd', 'ped00_valtot', 'ped00_totger', 'digtot']);
    final subtot = _getDouble(m, ['ped00_subtot', 'ped00_subval', 'subtot']);
    final fattot = _getDouble(m, ['ped00_fattot', 'ped00_totfat', 'fattot'], digtot - subtot);
    final qtdItm = _getInt(m, ['ped00_qtditm', 'ped00_qtdite']);
    final obs = _getString(m, ['ped00_observ', 'ped00_obs', 'ped00_observacao', 'observ', 'obs']);

    // tentar buscar quantidade real de itens e totais se colunas estiverem zeradas
    int qtdItensFinal = qtdItm;
    double digtotFinal = digtot;
    double bontotFinal = bontot;
    try {
      final t10 = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table' AND lower(name)='pckvendig010'");
      if (t10.isNotEmpty) {
        final cnt = await db.rawQuery(
          'SELECT COUNT(*) as c, SUM(ped10_qtdped) as q, SUM(ped10_qtdbon) as qb, SUM(ped10_totprd) as tot FROM pckvendig010 WHERE ped10_numped = ?',
          [pedidoId],
        );
        if (cnt.isNotEmpty) {
          final rowC = cnt.first;
          final cVal = _getInt(rowC, ['c']);
          if (qtdItensFinal == 0) qtdItensFinal = cVal;
          if (digtotFinal == 0.0) {
            digtotFinal = _getDouble(rowC, ['tot']);
          }
        }
      }
    } catch (_) {}

    String clienteNome = _getString(m, ['ped00_clides', 'clides']);
    String planoDesc = _getString(m, ['ped00_plades', 'plades']);
    String linhaDesc = _getString(m, ['ped00_lindes', 'lindes']);
    String agenteDesc = '';

    // Busca cadastros no banco principal se necessário
    Database? catDb = db;
    bool openedCatDb = false;
    try {
      final mainPath = await LocalSalesDatabaseService.getDatabasePath();
      if (db.path != mainPath && await File(mainPath).exists()) {
        catDb = await openDatabase(mainPath, readOnly: true);
        openedCatDb = true;
      }

      if (clienteNome.isEmpty && cliCod != 0) {
        try {
          final cliRows = await catDb.rawQuery('SELECT * FROM cadcli00 WHERE cli00_codigo = ? LIMIT 1', [cliCod]);
          if (cliRows.isNotEmpty) {
            clienteNome = _getString(cliRows.first, ['cli00_descri', 'cli00_fantasi', 'cli00_fantas', 'descri', 'nome']);
          }
        } catch (_) {}
      }

      if (planoDesc.isEmpty && plaCod.isNotEmpty) {
        try {
          final plaRows = await catDb.rawQuery("SELECT * FROM cadpla00 WHERE pla00_codigo = ? LIMIT 1", [plaCod]);
          if (plaRows.isNotEmpty) planoDesc = _getString(plaRows.first, ['pla00_descri', 'descri', 'descricao']);
        } catch (_) {}
      }

      if (linhaDesc.isEmpty && linCod.isNotEmpty) {
        try {
          final linRows = await catDb.rawQuery("SELECT * FROM cadlin00 WHERE lin00_codigo = ? LIMIT 1", [linCod]);
          if (linRows.isNotEmpty) linhaDesc = _getString(linRows.first, ['lin00_descri', 'descri', 'descricao']);
        } catch (_) {}
      }

      if (agtCod.isNotEmpty) {
        for (final tbl in ['codage00', 'cadagt00', 'cadage00', 'cadcob00', 'codcob00']) {
          try {
            final exists = await catDb.rawQuery(
                "SELECT name FROM sqlite_master WHERE type='table' AND lower(name)=?", [tbl]);
            if (exists.isEmpty) continue;
            final colsA = await catDb.rawQuery('PRAGMA table_info($tbl)');
            final cnA = colsA.map((r) => r['name'].toString().toLowerCase()).toSet();
            String? codColA;
            String? descColA;
            for (final c in ['age00_codigo', 'agt00_codigo', 'agt00_codage', 'agt00_codagt', 'cob00_codigo', 'cob00_codcob', 'cad00_codigo', 'codigo']) {
              if (cnA.contains(c)) { codColA = c; break; }
            }
            for (final c in ['age00_descri', 'agt00_descri', 'agt00_descricao', 'agt00_nome', 'age00_descricao', 'age00_nome', 'cob00_descri', 'cob00_descricao', 'cob00_nome', 'descricao', 'descri', 'nome']) {
              if (cnA.contains(c)) { descColA = c; break; }
            }
            if (codColA == null || descColA == null) continue;
            final agtRows = await catDb.rawQuery('SELECT $descColA as d FROM $tbl WHERE $codColA = ? LIMIT 1', [agtCod]);
            if (agtRows.isNotEmpty && agtRows.first['d'] != null) {
              agenteDesc = agtRows.first['d'].toString();
              break;
            }
          } catch (_) {}
        }
      }
    } finally {
      if (openedCatDb && catDb != null && catDb.isOpen) {
        await catDb.close();
      }
    }

    await db.close();

    final finalFatTot = fattot != 0 ? fattot : (digtotFinal - subtot);

    return PedidoResumoData(
      numeroPedido: pedidoId,
      dataEmissao: datSys.isNotEmpty ? datSys : DateTime.now().toString().split(' ').first,
      clienteCodigo: cliCod,
      clienteNome: clienteNome.isNotEmpty ? clienteNome : 'Cliente $cliCod',
      planoCodigo: plaCod,
      planoDescricao: planoDesc.isNotEmpty ? planoDesc : plaCod,
      linhaCodigo: linCod,
      linhaDescricao: linhaDesc.isNotEmpty ? linhaDesc : linCod,
      agenteCodigo: agtCod,
      agenteDescricao: agenteDesc.isNotEmpty ? agenteDesc : agtCod,
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
