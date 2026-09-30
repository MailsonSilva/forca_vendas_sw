import 'package:sqflite/sqflite.dart';
import '/domain/models/produto_lookup_dto.dart';
import '/domain/models/produto_card_dto.dart';
import '/domain/models/produto_detalhe_dto.dart';
import '/domain/services/produto_search_filter_builder.dart';
import '/data/services/local_sales_database_service.dart';
import '/app_state.dart';

/// Repositório de dados para consulta e seleção de produtos.
/// Implementa a estratégia em duas etapas da SPEC-052 e método Tcadpro00::cload de usysctr00.cpp.
class ProdutoRepository {
  ProdutoRepository({Database? db}) : _db = db;

  final Database? _db;

  Future<Database> _getDb() async {
    if (_db != null) return _db!;
    return await LocalSalesDatabaseService.getDatabase();
  }

  /// QUERY 1: LISTAGEM LEVE DO CARD (Pesquisa / Scroll Infinito)
  ///
  /// Executa consulta ultra-rápida trazendo estritamente os campos visuais do card
  /// e o saldo físico disponível da filial ativa (pro00_qtdest - pro00_qtdpen).
  Future<List<ProdutoCardDTO>> listarProdutosCard({
    String? termo,
    String? cursorDescri,
    required int filialAtiva,
    int? codTabela,
    int? codRegiao,
    int? codClasseCliente,
    bool? apenasEstoque,
    int limit = 100,
    int offset = 0,
  }) async {
    final db = await _getDb();

    final int filial = filialAtiva > 0
        ? filialAtiva
        : (AppState().codFilialAtiva > 0 ? AppState().codFilialAtiva : 1);
    final int tabela = (codTabela != null && codTabela > 0)
        ? codTabela
        : (AppState().tabelaPrecoAtiva > 0 ? AppState().tabelaPrecoAtiva : 1);
    final int regiao = codRegiao ?? (AppState().clienteSelecionado?.codRegiao ?? 0);
    final int classe = codClasseCliente ?? (AppState().clienteSelecionado?.codTipoPreco ?? 0);

    final bool temTermo = termo != null && termo.trim().isNotEmpty;
    final String termoTrim = temTermo ? termo.trim() : '';
    final bool temCursor = cursorDescri != null && cursorDescri.trim().isNotEmpty;

    bool temEstpcopro00 = false;
    bool temEstpcoreg00 = false;
    bool temPcopro00 = false;
    bool temEstpro00 = false;
    Set<String> estColsCard = {};
    try {
      final t = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table'");
      final tableNames = t.map((r) => r['name']?.toString().toLowerCase() ?? '').toSet();
      temEstpcopro00 = tableNames.contains('estpcopro00');
      temEstpcoreg00 = tableNames.contains('estpcoreg00');
      temPcopro00 = tableNames.contains('pcopro00');
      temEstpro00 = tableNames.contains('estpro00');
      if (temEstpro00) {
        final ec = await db.rawQuery('PRAGMA table_info(estpro00)');
        estColsCard = ec.map((r) => r['name']?.toString().toLowerCase() ?? '').toSet();
      }
    } catch (_) {}

    final String? tblPco = temEstpcopro00 ? 'estpcopro00' : (temPcopro00 ? 'pcopro00' : null);
    String joinPreco = '';
    String selPreco = '0.0 AS pro00_pcomax, 0.0 AS pro00_pcomin, 0.0 AS preco_venda';
    final List<dynamic> precoBinds = [];

    if (tblPco != null) {
      Set<String> pcoCols = {};
      try {
        final pRows = await db.rawQuery('PRAGMA table_info($tblPco)');
        pcoCols = pRows.map((r) => r['name']?.toString().toLowerCase() ?? '').toSet();
      } catch (_) {}

      final bool hasCls = pcoCols.contains('pro00_codcls') || pcoCols.contains('codcls');
      final bool hasTab = pcoCols.contains('pro00_codtab') || pcoCols.contains('codtab');
      final String colPcosub = pcoCols.contains('pro00_pcosub')
          ? 'pro00_pcosub'
          : (pcoCols.contains('pro00_preco') ? 'pro00_preco' : 'preco');
      final bool hasPcocus = pcoCols.contains('pro00_pcocus') || pcoCols.contains('pcocus');
      final String colPcocus = pcoCols.contains('pro00_pcocus') ? 'pro00_pcocus' : 'pcocus';

      if (temEstpcoreg00 && hasCls) {
        Set<String> regCols = {};
        try {
          final rCols = await db.rawQuery('PRAGMA table_info(estpcoreg00)');
          regCols = rCols.map((r) => r['name']?.toString().toLowerCase() ?? '').toSet();
        } catch (_) {}
        final String colRegCls = regCols.contains('pro00_codpco')
            ? 'pro00_codpco'
            : (regCols.contains('pro00_codcls') ? 'pro00_codcls' : 'pro00_codpco');

        joinPreco = '''
          LEFT JOIN estpcoreg00 reg 
                 ON reg.pro00_codpro = p.pro00_codigo 
                AND reg.pro00_codtab = ? 
                AND reg.pro00_codreg = ?
          LEFT JOIN $tblPco t 
                 ON t.pro00_codpro = p.pro00_codigo 
                AND (
                  (reg.$colRegCls IS NOT NULL AND t.pro00_codcls = reg.$colRegCls)
                  OR (reg.$colRegCls IS NULL AND (t.pro00_codcls = ? OR ? = 0))
                )
        ''';
        precoBinds.addAll([tabela, regiao, classe, classe]);
      } else if (hasCls) {
        joinPreco = '''
          LEFT JOIN $tblPco t 
                 ON t.pro00_codpro = p.pro00_codigo 
                AND (t.pro00_codcls = ? OR ? = 0)
        ''';
        precoBinds.addAll([classe, classe]);
      } else if (hasTab) {
        joinPreco = '''
          LEFT JOIN $tblPco t 
                 ON t.pro00_codpro = p.pro00_codigo 
                AND t.pro00_codtab = ?
        ''';
        precoBinds.add(tabela);
      } else {
        joinPreco = '''
          LEFT JOIN $tblPco t 
                 ON t.pro00_codpro = p.pro00_codigo
        ''';
      }

      final String colPcoFallback = pcoCols.contains('pro00_preco')
          ? 't.pro00_preco'
          : (pcoCols.contains('preco') ? 't.preco' : '0.0');

      final String expPrecoVenda = 'COALESCE(t.$colPcosub, $colPcoFallback, 0.0)';

      final String expMin = hasPcocus
          ? 'COALESCE(NULLIF(t.$colPcocus, 0.0), $expPrecoVenda, 0.0)'
          : expPrecoVenda;

      selPreco = '''
        $expPrecoVenda AS pro00_pcomax,
        $expMin AS pro00_pcomin,
        $expPrecoVenda AS preco_venda
      ''';
    }

    final List<String> condicoes = [];
    final List<dynamic> filtroBinds = [];

    if (temTermo) {
      Set<String> colunas = {};
      try {
        final cp = await db.rawQuery('PRAGMA table_info(cadpro00)');
        colunas = cp.map((r) => r['name']?.toString().toLowerCase() ?? '').toSet();
      } catch (_) {}

      final List<String> refs = [
        if (colunas.isEmpty || colunas.contains('pro00_ref001')) 'p.pro00_ref001',
        if (colunas.isEmpty || colunas.contains('pro00_ref002')) 'p.pro00_ref002',
        if (colunas.contains('pro00_reffor')) 'p.pro00_reffor',
      ];

      final filtro = ProdutoSearchFilterBuilder.build(
        input: termoTrim,
        colDesc: 'p.pro00_descri',
        colCod: 'p.pro00_codigo',
        colCodbar: (colunas.isEmpty || colunas.contains('pro00_codbar')) ? 'p.pro00_codbar' : null,
        colRefs: refs,
      );
      if (filtro.hasFilter) {
        condicoes.add(filtro.sql);
        filtroBinds.addAll(filtro.binds);
      }
    }
    if (temCursor) {
      condicoes.add('p.pro00_descri > ?');
      filtroBinds.add(cursorDescri.trim());
    }

    String joinEstpro00 = '';
    String selEstoque = 'COALESCE(p.pro00_qtdest, 0.0) AS pro00_qtdest';
    final List<dynamic> filialBinds = [];

    if (temEstpro00) {
      joinEstpro00 = '''
        LEFT JOIN estpro00 e 
               ON e.pro00_codpro = p.pro00_codigo 
              AND e.pro00_codfil = ?
      ''';
      filialBinds.add(filial);
      final String penExp = estColsCard.contains('pro00_qtdpen') ? 'COALESCE(e.pro00_qtdpen, 0)' : '0';
      final String qtdExp = estColsCard.contains('pro00_qtdest') ? 'e.pro00_qtdest' : '0';
      selEstoque = 'COALESCE($qtdExp - $penExp, p.pro00_qtdest, 0.0) AS pro00_qtdest';
    }

    if (apenasEstoque == true) {
      if (temEstpro00) {
        final String penExp = estColsCard.contains('pro00_qtdpen') ? 'COALESCE(e.pro00_qtdpen, 0)' : '0';
        final String qtdExp = estColsCard.contains('pro00_qtdest') ? 'e.pro00_qtdest' : '0';
        condicoes.add('COALESCE($qtdExp - $penExp, p.pro00_qtdest, 0.0) > 0');
      } else {
        condicoes.add('COALESCE(p.pro00_qtdest, 0.0) > 0');
      }
    }

    final String whereClause = condicoes.isNotEmpty ? 'WHERE ${condicoes.join(' AND ')}' : '';

    String limitClause = '';
    final List<dynamic> limitBinds = [];
    if (limit > 0) {
      limitClause = 'LIMIT ? OFFSET ?';
      limitBinds.add(limit);
      limitBinds.add(offset);
    }

    final sql = '''
      SELECT 
        p.pro00_codigo,
        p.pro00_descri,
        COALESCE(p.pro00_unidad, 'UN') AS pro00_unidad,
        COALESCE(p.pro00_codbar, '') AS pro00_codbar,
        p.pro00_codimg,
        $selPreco,
        $selEstoque
      FROM cadpro00 p
      $joinEstpro00
      $joinPreco
      $whereClause
      ORDER BY p.pro00_descri ASC
      $limitClause;
    ''';

    final List<dynamic> allArgs = [
      ...filialBinds,
      ...precoBinds,
      ...filtroBinds,
      ...limitBinds,
    ];

    final rows = await db.rawQuery(sql, allArgs);
    return rows.map((r) => ProdutoCardDTO.fromMap(r)).toList();
  }

  /// QUERY 2: DETALHE COMPLETO SOB DEMANDA (Tcadpro00::cload de usysctr00.cpp)
  ///
  /// Executada estritamente sob demanda ao clicar no card de um produto.
  /// Carrega todas as 26 colunas canônicas e amarrações relacionais do legado:
  /// cadpro02, estpro00, cadprofra00, cadprobon00, cadproemb00 e estprodat00.
  /// Preços calculados em cascata SPEC-058 (estpcoreg00 -> estpcopro00).
  Future<ProdutoDetalheDTO?> obterDetalhesProduto(
    int codpro,
    int filialAtiva, [
    int? codTabela,
    int? codRegiao,
    int? codClasseCliente,
  ]) async {
    final db = await _getDb();

    final int filial = filialAtiva > 0
        ? filialAtiva
        : (AppState().codFilialAtiva > 0 ? AppState().codFilialAtiva : 1);
    final int tabela = (codTabela != null && codTabela > 0)
        ? codTabela
        : (AppState().tabelaPrecoAtiva > 0 ? AppState().tabelaPrecoAtiva : 1);
    final int regiao = codRegiao ?? (AppState().clienteSelecionado?.codRegiao ?? 0);
    final int classe = codClasseCliente ?? (AppState().clienteSelecionado?.codTipoPreco ?? 0);

    // 1. Inspeciona tabelas disponíveis no banco SQLite
    Set<String> tabelas = {};
    try {
      final tRows = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table'");
      tabelas = tRows.map((r) => r['name']?.toString().toLowerCase() ?? '').toSet();
    } catch (_) {}

    // 2. Inspeciona colunas de cadpro00
    Set<String> proCols = {};
    try {
      final cRows = await db.rawQuery('PRAGMA table_info(cadpro00)');
      proCols = cRows.map((r) => r['name']?.toString().toLowerCase() ?? '').toSet();
    } catch (_) {}

    final bool hasCadpro02 = tabelas.contains('cadpro02');
    final bool hasEstpro00 = tabelas.contains('estpro00');
    final bool hasCadprofra00 = tabelas.contains('cadprofra00');
    final bool hasCadprobon00 = tabelas.contains('cadprobon00');
    final bool hasCadproemb00 = tabelas.contains('cadproemb00') && proCols.contains('pro00_codemb');
    final bool hasEstprodat00 = tabelas.contains('estprodat00');
    final bool hasEstpcoreg00 = tabelas.contains('estpcoreg00');
    final bool hasEstpcopro00 = tabelas.contains('estpcopro00');
    final bool hasPcopro00 = tabelas.contains('pcopro00');
    final String? tblPco = hasEstpcopro00 ? 'estpcopro00' : (hasPcopro00 ? 'pcopro00' : null);

    final List<dynamic> precoArgs = [];
    String joinPreco = '';
    String selPreco = '0.0 AS pro00_pcomax, 0.0 AS pro00_pcomin, 0.0 AS preco_venda';

    if (tblPco != null) {
      Set<String> pcoCols = {};
      try {
        final pRows = await db.rawQuery('PRAGMA table_info($tblPco)');
        pcoCols = pRows.map((r) => r['name']?.toString().toLowerCase() ?? '').toSet();
      } catch (_) {}

      final bool hasCls = pcoCols.contains('pro00_codcls') || pcoCols.contains('codcls');
      final bool hasTab = pcoCols.contains('pro00_codtab') || pcoCols.contains('codtab');
      final String colPcosub = pcoCols.contains('pro00_pcosub')
          ? 'pro00_pcosub'
          : (pcoCols.contains('pro00_preco') ? 'pro00_preco' : 'preco');
      final bool hasPcocus = pcoCols.contains('pro00_pcocus') || pcoCols.contains('pcocus');
      final String colPcocus = pcoCols.contains('pro00_pcocus') ? 'pro00_pcocus' : 'pcocus';

      if (hasEstpcoreg00 && hasCls) {
        Set<String> regCols = {};
        try {
          final rCols = await db.rawQuery('PRAGMA table_info(estpcoreg00)');
          regCols = rCols.map((r) => r['name']?.toString().toLowerCase() ?? '').toSet();
        } catch (_) {}
        final String colRegCls = regCols.contains('pro00_codpco')
            ? 'pro00_codpco'
            : (regCols.contains('pro00_codcls') ? 'pro00_codcls' : 'pro00_codpco');

        joinPreco = '''
          LEFT JOIN estpcoreg00 reg 
                 ON reg.pro00_codpro = sel.pro00_codigo 
                AND reg.pro00_codtab = ? 
                AND reg.pro00_codreg = ?
          LEFT JOIN $tblPco t 
                 ON t.pro00_codpro = sel.pro00_codigo 
                AND (
                  (reg.$colRegCls IS NOT NULL AND t.pro00_codcls = reg.$colRegCls)
                  OR (reg.$colRegCls IS NULL AND (t.pro00_codcls = ? OR ? = 0))
                )
        ''';
        precoArgs.addAll([tabela, regiao, classe, classe]);
      } else if (hasCls) {
        joinPreco = '''
          LEFT JOIN $tblPco t 
                 ON t.pro00_codpro = sel.pro00_codigo 
                AND (t.pro00_codcls = ? OR ? = 0)
        ''';
        precoArgs.addAll([classe, classe]);
      } else if (hasTab) {
        joinPreco = '''
          LEFT JOIN $tblPco t 
                 ON t.pro00_codpro = sel.pro00_codigo 
                AND t.pro00_codtab = ?
        ''';
        precoArgs.add(tabela);
      } else {
        joinPreco = '''
          LEFT JOIN $tblPco t 
                 ON t.pro00_codpro = sel.pro00_codigo
        ''';
      }

      final String colPcoFallback = pcoCols.contains('pro00_preco')
          ? 't.pro00_preco'
          : (pcoCols.contains('preco') ? 't.preco' : '0.0');

      final String expPrecoVenda = 'COALESCE(t.$colPcosub, $colPcoFallback, 0.0)';

      final String expMin = hasPcocus
          ? 'COALESCE(NULLIF(t.$colPcocus, 0.0), $expPrecoVenda, 0.0)'
          : expPrecoVenda;

      selPreco = '''
        $expPrecoVenda AS pro00_pcomax,
        $expMin AS pro00_pcomin,
        $expPrecoVenda AS preco_venda
      ''';
    }

    // Junções e projeções condicionais
    final String joinCadpro02 = hasCadpro02
        ? 'LEFT JOIN cadpro02 pr2 ON pr2.pro02_codpro = sel.pro00_codigo'
        : '';
    final String selMulemb = hasCadpro02
        ? 'COALESCE(pr2.pro02_mulemb, 1) AS pro02_mulemb'
        : '1 AS pro02_mulemb';
    final String selMulven = hasCadpro02
        ? 'COALESCE(pr2.pro02_mulven, 1.0) AS pro02_mulven'
        : '1.0 AS pro02_mulven';

    String joinEstpro00 = '';
    String selEstoque = proCols.contains('pro00_qtdest')
        ? 'COALESCE(sel.pro00_qtdest, 0) AS pro00_qtdest'
        : '0 AS pro00_qtdest';
    String selPrifil = "'S' AS pro00_prifil";
    if (hasEstpro00) {
      Set<String> estCols = {};
      try {
        final eRows = await db.rawQuery('PRAGMA table_info(estpro00)');
        estCols = eRows.map((r) => r['name']?.toString().toLowerCase() ?? '').toSet();
      } catch (_) {}

      joinEstpro00 = '''
        LEFT JOIN estpro00 est 
               ON est.pro00_codfil = ? 
              AND est.pro00_codpro = sel.pro00_codigo
      ''';
      final String fallbackQtd = proCols.contains('pro00_qtdest') ? 'sel.pro00_qtdest' : '0';
      final String penCol = estCols.contains('pro00_qtdpen') ? 'COALESCE(est.pro00_qtdpen, 0)' : '0';
      final String qtdCol = estCols.contains('pro00_qtdest') ? 'est.pro00_qtdest' : fallbackQtd;
      selEstoque = 'COALESCE($qtdCol - $penCol, $fallbackQtd, 0) AS pro00_qtdest';
      selPrifil = estCols.contains('pro00_prifil')
          ? "COALESCE(est.pro00_prifil, 'S') AS pro00_prifil"
          : "'S' AS pro00_prifil";
    }

    final String joinCadprofra00 = hasCadprofra00
        ? 'LEFT JOIN cadprofra00 fra ON fra.fra00_codpro = sel.pro00_codigo'
        : '';
    final String selIndfra = hasCadprofra00 ? 'fra.fra00_indfra' : 'NULL AS fra00_indfra';
    final String selPeso = hasCadprofra00 ? 'fra.fra00_peso' : 'NULL AS fra00_peso';

    final String joinCadprobon00 = hasCadprobon00
        ? 'LEFT JOIN cadprobon00 bon ON bon.bon00_codpro = sel.pro00_codigo'
        : '';
    final String selDefbon = hasCadprobon00 ? 'bon.bon00_defbon' : 'NULL AS bon00_defbon';
    final String selDefbonven = hasCadprobon00 ? 'bon.bon00_defbonven' : 'NULL AS bon00_defbonven';

    final String joinCadproemb00 = hasCadproemb00
        ? 'LEFT JOIN cadproemb00 emb ON emb.emb00_codseq = sel.pro00_codemb'
        : '';
    final String selEmbala = hasCadproemb00
        ? 'emb.emb00_embala'
        : (proCols.contains('pro00_embala')
            ? 'sel.pro00_embala AS emb00_embala'
            : (proCols.contains('embalagem') ? 'sel.embalagem AS emb00_embala' : 'NULL AS emb00_embala'));

    String joinEstprodat00 = '';
    String selEntdat = 'NULL AS pro00_entdat';
    if (hasEstprodat00) {
      joinEstprodat00 = '''
        LEFT JOIN estprodat00 ed0 
               ON ed0.pro00_codfil = ? 
              AND ed0.pro00_codpro = sel.pro00_codigo
      ''';
      selEntdat = 'ed0.pro00_entdat';
    }

    // Colunas de cadpro00 protegidas
    final String selCodbar = proCols.contains('pro00_codbar')
        ? 'sel.pro00_codbar'
        : (proCols.contains('codbar') ? 'sel.codbar AS pro00_codbar' : 'NULL AS pro00_codbar');
    final String selDeslon = proCols.contains('pro00_deslon') ? 'sel.pro00_deslon' : 'NULL AS pro00_deslon';
    final String selUnidad = proCols.contains('pro00_unidad')
        ? "COALESCE(sel.pro00_unidad, 'UN') AS pro00_unidad"
        : (proCols.contains('unidade') ? "COALESCE(sel.unidade, 'UN') AS pro00_unidad" : "'UN' AS pro00_unidad");
    final String selCodimg = proCols.contains('pro00_codimg') ? 'sel.pro00_codimg' : 'NULL AS pro00_codimg';
    final String selCodfab = proCols.contains('pro00_codfab') ? 'sel.pro00_codfab' : 'NULL AS pro00_codfab';
    final String selCodmar = proCols.contains('pro00_codmar') ? 'sel.pro00_codmar' : 'NULL AS pro00_codmar';
    final String selCodgrp = proCols.contains('pro00_codgrp') ? 'sel.pro00_codgrp' : 'NULL AS pro00_codgrp';
    final String selCodsgr = proCols.contains('pro00_codsgr') ? 'sel.pro00_codsgr' : 'NULL AS pro00_codsgr';
    final String selCoddep = proCols.contains('pro00_coddep') ? 'sel.pro00_coddep' : 'NULL AS pro00_coddep';
    final String selCodsec = proCols.contains('pro00_codsec') ? 'sel.pro00_codsec' : 'NULL AS pro00_codsec';
    final String selCodlin = proCols.contains('pro00_codlin') ? 'sel.pro00_codlin' : 'NULL AS pro00_codlin';
    final String selCodtrb = proCols.contains('pro00_codtrb') ? 'sel.pro00_codtrb' : 'NULL AS pro00_codtrb';
    final String selPesbru = proCols.contains('pro00_pesbru') ? 'sel.pro00_pesbru' : 'NULL AS pro00_pesbru';
    final String selPesliq = proCols.contains('pro00_pesliq') ? 'sel.pro00_pesliq' : 'NULL AS pro00_pesliq';

    final sql = '''
      SELECT DISTINCT
        sel.pro00_codigo,
        $selCodbar,
        sel.pro00_descri,
        $selPreco,
        $selDeslon,
        $selUnidad,
        $selCodimg,
        $selEmbala,
        $selIndfra,
        $selPeso,
        $selCodfab,
        $selCodmar,
        $selCodgrp,
        $selCodsgr,
        $selCoddep,
        $selCodsec,
        $selCodlin,
        $selCodtrb,
        $selPesbru,
        $selPesliq,
        $selDefbon,
        $selDefbonven,
        $selEntdat,
        $selPrifil,
        $selEstoque,
        $selMulemb,
        $selMulven
      FROM cadpro00 sel
      $joinPreco
      $joinCadpro02
      $joinEstpro00
      $joinCadprofra00
      $joinCadprobon00
      $joinCadproemb00
      $joinEstprodat00
      WHERE (sel.pro00_codigo = ? OR CAST(sel.pro00_codigo AS TEXT) = ?);
    ''';

    final List<dynamic> args = [
      ...precoArgs,
      if (hasEstpro00) filial,
      if (hasEstprodat00) filial,
      codpro,
      codpro.toString(),
    ];

    final rows = await db.rawQuery(sql, args);
    if (rows.isEmpty) return null;
    return ProdutoDetalheDTO.fromMap(rows.first);
  }

  /// Realiza a busca multifiltro por EAN, Marca, Referência 1, Referência 2 ou Descrição.
  Future<List<ProdutoLookupDTO>> buscarProdutos(
    String? query, {
    int limit = 100,
    int offset = 0,
    int? codFilial,
  }) async {
    final db = await _getDb();
    final termo = (query ?? '').trim();

    String whereClause = '';
    List<dynamic> binds = [];

    if (termo.isNotEmpty) {
      final likeTermo = '%$termo%';
      whereClause = '''
        WHERE (
          p.pro00_descri LIKE ? OR
          p.pro00_codbar LIKE ? OR
          p.pro00_ref001 LIKE ? OR
          p.pro00_ref002 LIKE ? OR
          m.mar00_descri LIKE ?
        )
      ''';
      binds.addAll([likeTermo, likeTermo, likeTermo, likeTermo, likeTermo]);
    }

    final int filialAtiva = (codFilial != null && codFilial > 0)
        ? codFilial
        : (AppState().codFilialAtiva > 0 ? AppState().codFilialAtiva : 1);

    bool temEstpro00 = false;
    try {
      final r = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table' AND lower(name)='estpro00'");
      temEstpro00 = r.isNotEmpty;
    } catch (_) {}

    final joinEst = temEstpro00
        ? 'LEFT JOIN estpro00 e ON e.pro00_codpro = p.pro00_codigo AND e.pro00_codfil = ?'
        : '';
    final selEst = temEstpro00
        ? 'COALESCE(e.pro00_qtdest - COALESCE(e.pro00_qtdpen, 0.0), p.pro00_qtdest, 0.0) AS estoque_saldo'
        : 'COALESCE(p.pro00_qtdest, 0.0) AS estoque_saldo';

    final sql = '''
      SELECT 
        p.pro00_codigo   AS produto_id,
        p.pro00_descri   AS descricao,
        p.pro00_codbar   AS ean,
        COALESCE(m.mar00_descri, 'SEM MARCA') AS marca_nome,
        p.pro00_ref001   AS referencia_1,
        p.pro00_ref002   AS referencia_2,
        COALESCE(f.for00_descri, '')          AS fabricante_nome,
        COALESCE(p.pro00_embala, p.pro00_unidad, 'UN') AS embalagem,
        COALESCE(p.pro00_unidad, 'UN')        AS unidade,
        $selEst,
        0.0                                   AS preco_tabela,
        p.pro00_codimg   AS imagem_id
      FROM cadpro00 p
      $joinEst
      LEFT JOIN cadmar00 m ON m.mar00_codigo = p.pro00_codmar
      LEFT JOIN cadfor00 f ON f.for00_codigo = p.pro00_codfab
      $whereClause
      ORDER BY p.pro00_descri ASC
      LIMIT ? OFFSET ?
    ''';

    if (temEstpro00) {
      binds.insert(0, filialAtiva);
    }
    binds.addAll([limit, offset]);

    final rows = await db.rawQuery(sql, binds);
    return rows.map((row) => ProdutoLookupDTO.fromMap(row)).toList();
  }
}
