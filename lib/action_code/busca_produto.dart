// Imports do app
import '/backend/schema/structs/index.dart';
// Imports other custom actions
// Imports custom functions
// Begin custom action code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:io';
import '../app_state.dart';

Future<List<ProdutoResultStruct>> buscaProduto(
  String? filtro,
  int? offset,
  String? filtroLinha,
  String? filtroGrupo,
  String? filtroFabricante,
  String? filtroMarca,
  bool? apenasEstoque,
  bool? apenasPromocao,
  int? codFilial,
  String? dataEntrada, [
  int? codTabela,
]) async {
  try {
    final dbPath = join(await getDatabasesPath(), 'dbforcacad001.db');
    print('DIAGNOSTICO: Caminho do banco: $dbPath');

    if (!await File(dbPath).exists()) {
      print('DIAGNOSTICO: ERRO: O arquivo do banco de dados nao existe no caminho esperado.');
      return [];
    }

    final db = await openDatabase(dbPath, readOnly: true);

    try {
      final String busca = (filtro ?? '').trim();
      final int currentOffset = offset ?? 0;
      final String linha = (filtroLinha ?? '').trim();
      final String grupo = (filtroGrupo ?? '').trim();
      final String fab = (filtroFabricante ?? '').trim();
      final String marca = (filtroMarca ?? '').trim();
      final bool estoqueOpt = apenasEstoque ?? false;
      final String dataEnt = dataEntrada ?? 'Todas';

      final int filial = (codFilial == null || codFilial == 0)
          ? (AppState().codFilialAtiva != 0 ? AppState().codFilialAtiva : 1)
          : codFilial;

      final int tab = (codTabela != null && codTabela > 0) ? codTabela : 0;

      print(
          'DIAGNOSTICO: Parametros de busca -> busca: "$busca", linha: "$linha", grupo: "$grupo", filial: $filial, tabela: $tab, dataEntrada: "$dataEnt", promo: $apenasPromocao, estoque: $estoqueOpt');

      // 1. Descobre tabelas presentes no banco de dados local
      Set<String> allTables = {};
      try {
        final t = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table'");
        allTables = t.map((r) => r['name']?.toString().toLowerCase() ?? '').toSet();
      } catch (_) {}

      final bool hasPro = allTables.contains('cadpro00') || allTables.contains('pro00');
      if (!hasPro) {
        print('DIAGNOSTICO: Tabela cadpro00 não encontrada.');
        return [];
      }

      final String tabelaPro = allTables.contains('cadpro00') ? 'cadpro00' : 'pro00';

      // 2. Mapeamento de colunas de cadpro00
      Set<String> proCols = {};
      try {
        final cols = await db.rawQuery('PRAGMA table_info($tabelaPro)');
        proCols = cols.map((r) => r['name']?.toString().toLowerCase() ?? '').toSet();
      } catch (_) {}

      String colProCod = proCols.contains('pro00_codigo')
          ? 'pro00_codigo'
          : (proCols.contains('pro00_codpro') ? 'pro00_codpro' : 'codigo');
      String colProDesc = proCols.contains('pro00_descri')
          ? 'pro00_descri'
          : (proCols.contains('pro00_descricao') ? 'pro00_descricao' : 'descri');
      String colProUnid = proCols.contains('pro00_unidad')
          ? 'pro00_unidad'
          : (proCols.contains('pro00_unidade') ? 'pro00_unidade' : 'unidade');
      String colProBar = proCols.contains('pro00_codbar')
          ? 'pro00_codbar'
          : (proCols.contains('pro00_barcode') ? 'pro00_barcode' : 'codbar');

      // 3. Mapeamento de estpcopro00 (Preço)
      final bool hasPco = allTables.contains('estpcopro00') || allTables.contains('pcopro00');
      final String tblPco = allTables.contains('estpcopro00') ? 'estpcopro00' : 'pcopro00';
      Set<String> pcoCols = {};
      if (hasPco) {
        try {
          final cols = await db.rawQuery('PRAGMA table_info($tblPco)');
          pcoCols = cols.map((r) => r['name']?.toString().toLowerCase() ?? '').toSet();
        } catch (_) {}
      }

      String? pcoCodCol;
      for (final c in ['pro00_codpro', 'pro00_codigo', 'pcopro00_codpro', 'codpro']) {
        if (pcoCols.contains(c)) { pcoCodCol = c; break; }
      }
      String? pcoTabCol;
      for (final c in ['pro00_codtab', 'pcopro00_codtab', 'codtab']) {
        if (pcoCols.contains(c)) { pcoTabCol = c; break; }
      }
      String? pcoPrecoCol;
      for (final c in ['pro00_pcosub', 'pro00_preco', 'pcopro00_pcosub', 'preco']) {
        if (pcoCols.contains(c)) { pcoPrecoCol = c; break; }
      }

      // 4. Mapeamento de estpro00 (Estoque)
      final bool hasEst = allTables.contains('estpro00');
      Set<String> estCols = {};
      if (hasEst) {
        try {
          final cols = await db.rawQuery('PRAGMA table_info(estpro00)');
          estCols = cols.map((r) => r['name']?.toString().toLowerCase() ?? '').toSet();
        } catch (_) {}
      }

      String? estCodCol;
      for (final c in ['pro00_codpro', 'pro00_codigo', 'est00_codpro', 'codpro']) {
        if (estCols.contains(c)) { estCodCol = c; break; }
      }
      String? estFilCol;
      for (final c in ['pro00_codfil', 'est00_codfil', 'codfil']) {
        if (estCols.contains(c)) { estFilCol = c; break; }
      }
      String? estQtdCol;
      for (final c in ['pro00_qtdest', 'est00_qtdest', 'qtdest']) {
        if (estCols.contains(c)) { estQtdCol = c; break; }
      }
      String? estPenCol;
      for (final c in ['pro00_qtdpen', 'est00_qtdpen', 'qtdpen']) {
        if (estCols.contains(c)) { estPenCol = c; break; }
      }

      // 5. Mapeamento de tabelas auxiliares
      final bool hasDat = allTables.contains('estprodat00');
      final bool hasPrm = allTables.contains('estprmreg00');
      final bool hasPckItem = allTables.contains('pckvendig010');
      final bool hasPckHeader = allTables.contains('pckvendig000');

      // 6. Subquery segura de rascunhos em digitação
      String subqueryRascunho = '0';
      if (hasPckItem) {
        try {
          final colsItm = await db.rawQuery('PRAGMA table_info(pckvendig010)');
          final itemCols = colsItm.map((r) => r['name']?.toString().toLowerCase() ?? '').toSet();

          String? itmCod;
          for (final c in ['codpro', 'dig01_codpro', 'ped10_codprd', 'pro00_codigo']) {
            if (itemCols.contains(c)) { itmCod = c; break; }
          }

          if (itmCod != null) {
            if (itemCols.contains('sttdig')) {
              String itmQtdDirect = itemCols.contains('dig01_digqtd')
                  ? 'dig01_digqtd'
                  : (itemCols.contains('ped10_qtdped')
                      ? '(COALESCE(ped10_qtdped, 0) + COALESCE(ped10_qtdbon, 0))'
                      : 'ped10_qtdped');
              subqueryRascunho =
                  '(SELECT COALESCE(SUM($itmQtdDirect), 0) FROM pckvendig010 WHERE sttdig = 0 AND $itmCod = p.$colProCod)';
            } else if (hasPckHeader) {
              final colsHdr = await db.rawQuery('PRAGMA table_info(pckvendig000)');
              final hdrCols = colsHdr.map((r) => r['name']?.toString().toLowerCase() ?? '').toSet();

              String? hdrNum = hdrCols.contains('ped00_numped') ? 'ped00_numped' : (hdrCols.contains('numped') ? 'numped' : null);
              String? itmNum = itemCols.contains('ped10_numped') ? 'ped10_numped' : (itemCols.contains('numped') ? 'numped' : null);
              String? hdrStt = hdrCols.contains('ped00_sttdig') ? 'ped00_sttdig' : (hdrCols.contains('sttdig') ? 'sttdig' : null);

              if (hdrNum != null && itmNum != null && hdrStt != null) {
                String itmQtdAliased = itemCols.contains('dig01_digqtd')
                    ? 'i.dig01_digqtd'
                    : (itemCols.contains('ped10_qtdped')
                        ? '(COALESCE(i.ped10_qtdped, 0) + COALESCE(i.ped10_qtdbon, 0))'
                        : 'i.ped10_qtdped');

                subqueryRascunho =
                    '(SELECT COALESCE(SUM($itmQtdAliased), 0) FROM pckvendig010 i LEFT JOIN pckvendig000 h ON h.$hdrNum = i.$itmNum WHERE COALESCE(h.$hdrStt, 0) = 0 AND i.$itmCod = p.$colProCod)';
              }
            }
          }
        } catch (_) {}
      }

      // 7. Cláusulas de Filtro (WHERE)
      List<String> condicoes = [];
      List<dynamic> whereBinds = [];

      if (busca.isNotEmpty) {
        final isNumeric = RegExp(r'^\d+$').hasMatch(busca);
        if (isNumeric) {
          if (proCols.contains(colProBar)) {
            condicoes.add('(p.$colProCod = ? OR p.$colProBar = ?)');
            whereBinds.addAll([busca, busca]);
          } else {
            condicoes.add('p.$colProCod = ?');
            whereBinds.add(busca);
          }
        } else {
          final termo = '%${busca.toUpperCase()}%';
          condicoes.add('UPPER(p.$colProDesc) LIKE ?');
          whereBinds.add(termo);
        }
      }

      if (linha.isNotEmpty && proCols.contains('pro00_codlin')) {
        final val = int.tryParse(linha);
        if (val != null) { condicoes.add('p.pro00_codlin = ?'); whereBinds.add(val); }
      }
      if (grupo.isNotEmpty && proCols.contains('pro00_codgrp')) {
        final val = int.tryParse(grupo);
        if (val != null) { condicoes.add('p.pro00_codgrp = ?'); whereBinds.add(val); }
      }
      if (fab.isNotEmpty && proCols.contains('pro00_codfab')) {
        final val = int.tryParse(fab);
        if (val != null) { condicoes.add('p.pro00_codfab = ?'); whereBinds.add(val); }
      }
      if (marca.isNotEmpty && proCols.contains('pro00_codmar')) {
        final val = int.tryParse(marca);
        if (val != null) { condicoes.add('p.pro00_codmar = ?'); whereBinds.add(val); }
      }

      if (estoqueOpt && hasEst && estQtdCol != null) {
        final pen = estPenCol != null ? 'COALESCE(e.$estPenCol, 0)' : '0';
        condicoes.add('(COALESCE(e.$estQtdCol, 0) - $pen - $subqueryRascunho) > 0');
      }

      if (dataEnt != 'Todas' && hasDat) {
        DateTime targetDate;
        final now = DateTime.now();
        if (dataEnt == 'Hoje') {
          targetDate = DateTime(now.year, now.month, now.day);
        } else if (dataEnt == 'Ontem') {
          targetDate = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 1));
        } else {
          targetDate = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 7));
        }
        final dateStr =
            "${targetDate.year}-${targetDate.month.toString().padLeft(2, '0')}-${targetDate.day.toString().padLeft(2, '0')}";
        condicoes.add('d.pro00_entdat >= ?');
        whereBinds.add(dateStr);
      }

      if ((apenasPromocao ?? false) && hasPrm) {
        final dateStr =
            "${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}-${DateTime.now().day.toString().padLeft(2, '0')}";
        condicoes.add('? BETWEEN prm.pro00_prmini AND prm.pro00_prmfim');
        whereBinds.add(dateStr);
      }

      final String whereClause = condicoes.isNotEmpty ? 'WHERE ${condicoes.join(' AND ')}' : '';

      // 8. Construção de JOINs e binds ordenados estritamente
      List<dynamic> finalBinds = [];

      String joinTabela = '';
      if (hasPco && pcoCodCol != null) {
        if (tab > 0 && pcoTabCol != null) {
          joinTabela = 'LEFT JOIN $tblPco t ON t.$pcoCodCol = p.$colProCod AND t.$pcoTabCol = ? ';
          finalBinds.add(tab);
        } else {
          joinTabela = 'LEFT JOIN $tblPco t ON t.$pcoCodCol = p.$colProCod ';
        }
      }

      String joinEstoque = '';
      if (hasEst && estCodCol != null) {
        if (estFilCol != null) {
          joinEstoque = 'LEFT JOIN estpro00 e ON e.$estCodCol = p.$colProCod AND e.$estFilCol = ? ';
          finalBinds.add(filial);
        } else {
          joinEstoque = 'LEFT JOIN estpro00 e ON e.$estCodCol = p.$colProCod ';
        }
      }

      String joinData = (hasDat && dataEnt != 'Todas')
          ? 'LEFT JOIN estprodat00 d ON d.pro00_codpro = p.$colProCod '
          : '';
      String joinPrm = (hasPrm && (apenasPromocao ?? false))
          ? 'LEFT JOIN estprmreg00 prm ON prm.pro00_codpro = p.$colProCod '
          : '';

      finalBinds.addAll(whereBinds);
      finalBinds.add(currentOffset);

      // 9. Colunas opcionais PRD B4
      String selMulver = proCols.contains('pro00_mulver') ? 'COALESCE(p.pro00_mulver, 1) AS mulver' : '1 AS mulver';
      String selPcomin = proCols.contains('pro00_pcomin') ? 'COALESCE(p.pro00_pcomin, 0) AS pcomin' : '0 AS pcomin';
      String selPcomax = proCols.contains('pro00_pcomax') ? 'COALESCE(p.pro00_pcomax, 999999) AS pcomax' : '999999 AS pcomax';
      String selCommax = proCols.contains('pro00_commax') ? 'COALESCE(p.pro00_commax, 100) AS commax' : '100 AS commax';
      String selCodtrb = proCols.contains('pro00_codtrb') ? 'COALESCE(p.pro00_codtrb, 0) AS codtrb' : '0 AS codtrb';
      String selFreadpco = proCols.contains('pro00_freadpco') ? 'COALESCE(p.pro00_freadpco, 1) AS freadpco' : '1 AS freadpco';

      String selPreco = (hasPco && pcoPrecoCol != null)
          ? 'COALESCE(t.$pcoPrecoCol, 0) AS preco_venda'
          : (proCols.contains('pro00_pcosub')
              ? 'COALESCE(p.pro00_pcosub, 0) AS preco_venda'
              : (proCols.contains('pro00_preco')
                  ? 'COALESCE(p.pro00_preco, 0) AS preco_venda'
                  : '0 AS preco_venda'));

      String selEstAtual = (hasEst && estQtdCol != null)
          ? 'COALESCE(e.$estQtdCol, 0) AS estoque_atual'
          : '0 AS estoque_atual';

      String selEstPen = (hasEst && estPenCol != null)
          ? 'COALESCE(e.$estPenCol, 0) AS estoque_pendente'
          : '0 AS estoque_pendente';

      String selSaldo = (hasEst && estQtdCol != null)
          ? '(COALESCE(e.$estQtdCol, 0) - ${estPenCol != null ? 'COALESCE(e.$estPenCol, 0)' : '0'} - $subqueryRascunho) AS saldo'
          : '0 AS saldo';

      final String query =
          "SELECT DISTINCT p.$colProCod AS pro00_codigo, p.$colProDesc AS pro00_descri, p.$colProUnid AS pro00_unidad, "
          "$selPreco, $selEstAtual, $selEstPen, $selSaldo, "
          "$selMulver, $selPcomin, $selPcomax, $selCommax, $selCodtrb, $selFreadpco "
          "FROM $tabelaPro p "
          "$joinTabela "
          "$joinEstoque "
          "$joinData "
          "$joinPrm "
          " $whereClause "
          "ORDER BY p.$colProDesc "
          "LIMIT 500 OFFSET ?";

      print('DIAGNOSTICO: Executando query com binds: $finalBinds');

      List<Map<String, dynamic>> results = [];
      try {
        results = await db.rawQuery(query, finalBinds);
      } catch (queryErr) {
        print('DIAGNOSTICO: Aviso ao executar query complexa: $queryErr. Tentando fallback seguro.');
        // Fallback resiliente: busca simples diretamente em cadpro00
        final fallbackQuery = "SELECT p.* FROM $tabelaPro p $whereClause ORDER BY p.$colProDesc LIMIT 500 OFFSET ?";
        final fallbackBinds = [...whereBinds, currentOffset];
        results = await db.rawQuery(fallbackQuery, fallbackBinds);
      }

      print('DIAGNOSTICO: Query executada com sucesso. Resultados encontrados: ${results.length}');

      double parseDouble(dynamic val) {
        if (val == null) return 0.0;
        if (val is num) return val.toDouble();
        return double.tryParse(val.toString()) ?? 0.0;
      }

      int parseInt(dynamic val) {
        if (val == null) return 0;
        if (val is int) return val;
        if (val is num) return val.toInt();
        return int.tryParse(val.toString()) ?? 0;
      }

      return results
          .map((m) => ProdutoResultStruct(
                codigo: (m['pro00_codigo'] ?? m['codigo'] ?? '').toString(),
                descricao: (m['pro00_descri'] ?? m['descricao'] ?? m['descri'] ?? '').toString(),
                unidade: (m['pro00_unidad'] ?? m['unidade'] ?? 'UN').toString(),
                preco: parseDouble(m['preco_venda'] ?? m['pro00_pcosub'] ?? m['pro00_preco']),
                saldoEstoque: parseDouble(m['saldo'] ?? m['pro00_qtdest']),
                estoqueAtual: parseDouble(m['estoque_atual'] ?? m['pro00_qtdest']),
                estoquePendente: parseDouble(m['estoque_pendente'] ?? m['pro00_qtdpen']),
                mulver: parseDouble(m['mulver']),
                pcomin: parseDouble(m['pcomin']),
                pcomax: parseDouble(m['pcomax'] ?? 999999),
                commax: parseDouble(m['commax'] ?? 100),
                codtrb: parseInt(m['codtrb']),
                freadpco: (parseInt(m['freadpco'] ?? 1) != 0),
              ))
          .toList();
    } finally {
      await db.close();
    }
  } catch (e) {
    print('DIAGNOSTICO: Erro fatal na busca do SQLite: $e');
    return [];
  }
}
