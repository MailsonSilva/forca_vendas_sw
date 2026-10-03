import 'package:sqflite/sqflite.dart';
import '/backend/schema/structs/index.dart';
import '/domain/models/produto_lookup_dto.dart';
import '/domain/models/produto_card_dto.dart';
import '/domain/models/produto_detalhe_dto.dart';
import '/domain/services/produto_search_filter_builder.dart';
import '/domain/services/calculo_preco_produto_service.dart';
import '/data/services/local_sales_database_service.dart';
import '/app_state.dart';

class _ProdutoDbMeta {
  final Set<String> tabelas;
  final Set<String> proCols;
  final Set<String> estCols;
  final bool hasEmb;
  final bool hasEst;
  final bool hasReg;
  final bool hasPco;
  final bool hasPcopro;
  final bool hasMar;
  final bool hasFab;
  final String? tblPcopro;

  const _ProdutoDbMeta({
    required this.tabelas,
    required this.proCols,
    required this.estCols,
    required this.hasEmb,
    required this.hasEst,
    required this.hasReg,
    required this.hasPco,
    required this.hasPcopro,
    required this.hasMar,
    required this.hasFab,
    this.tblPcopro,
  });
}

/// Cache em memória de esquema SQLite para garantir buscas < 100ms sem PRAGMA repetido
class ProdutoMetadataCache {
  static final Map<int, _ProdutoDbMeta> _cache = {};

  static void reset() => _cache.clear();

  static Future<_ProdutoDbMeta> get(Database db) async {
    final key = db.hashCode;
    if (_cache.containsKey(key)) {
      return _cache[key]!;
    }
    Set<String> tabelas = {};
    Set<String> proCols = {};
    Set<String> estCols = {};
    try {
      final tRows = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table'");
      tabelas = tRows.map((r) => r['name']?.toString().toLowerCase() ?? '').toSet();
      final cRows = await db.rawQuery('PRAGMA table_info(cadpro00)');
      proCols = cRows.map((r) => r['name']?.toString().toLowerCase() ?? '').toSet();
      if (tabelas.contains('estpro00')) {
        final eRows = await db.rawQuery('PRAGMA table_info(estpro00)');
        estCols = eRows.map((r) => r['name']?.toString().toLowerCase() ?? '').toSet();
      }
    } catch (_) {}

    final info = _ProdutoDbMeta(
      tabelas: tabelas,
      proCols: proCols,
      estCols: estCols,
      hasEmb: tabelas.contains('cadproemb00'),
      hasEst: tabelas.contains('estpro00'),
      hasReg: tabelas.contains('estpcoreg00'),
      hasPco: tabelas.contains('estpcoregpco00'),
      hasPcopro: tabelas.contains('estpcopro00') || tabelas.contains('pcopro00'),
      hasMar: tabelas.contains('cadmar00'),
      hasFab: tabelas.contains('cadfor00'),
      tblPcopro: tabelas.contains('estpcopro00') ? 'estpcopro00' : (tabelas.contains('pcopro00') ? 'pcopro00' : null),
    );
    _cache[key] = info;
    return info;
  }
}

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

      final String colSub = pcoCols.contains('pro00_pcosub')
          ? 't.pro00_pcosub'
          : (pcoCols.contains('pcosub') ? 't.pcosub' : 'NULL');
      final String colPco = pcoCols.contains('pro00_preco')
          ? 't.pro00_preco'
          : (pcoCols.contains('preco') ? 't.preco' : 'NULL');

      final String expPrecoVenda =
          'COALESCE(NULLIF($colSub, 0.0), NULLIF($colPco, 0.0), 0.0)';

      selPreco = '''
        $expPrecoVenda AS pro00_pcomax,
        $expPrecoVenda AS pro00_pcomin,
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
      selEstoque = 'COALESCE($qtdExp - $penExp, 0.0) AS pro00_qtdest';
    }

    if (apenasEstoque == true) {
      if (temEstpro00) {
        final String penExp = estColsCard.contains('pro00_qtdpen') ? 'COALESCE(e.pro00_qtdpen, 0)' : '0';
        final String qtdExp = estColsCard.contains('pro00_qtdest') ? 'e.pro00_qtdest' : '0';
        condicoes.add('COALESCE($qtdExp - $penExp, 0.0) > 0');
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
    dynamic codpro,
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

      final String expPrecoVenda =
          'COALESCE(NULLIF(t.$colPcosub, 0.0), NULLIF($colPcoFallback, 0.0), 0.0)';

      final String expMin = hasPcocus
          ? 'COALESCE(NULLIF(t.$colPcocus, 0.0), $expPrecoVenda, 0.0)'
          : expPrecoVenda;

      final bool hasEstpcoregpco00 = tabelas.contains('estpcoregpco00');
      if (hasEstpcoreg00 && hasEstpcoregpco00) {
        joinPreco += '''
          LEFT JOIN (
            SELECT 
              reg.pro00_codpro,
              MAX(pco.pro00_pcomax) AS pcomax,
              MAX(pco.pro00_pcomin) AS pcomin
            FROM estpcoreg00 reg
            JOIN estpcoregpco00 pco 
              ON (pco.pro00_codseq = reg.pro00_codpco OR CAST(pco.pro00_codseq AS TEXT) = CAST(reg.pro00_codpco AS TEXT))
            WHERE (reg.pro00_codkey = 1 OR reg.pro00_codkey IS NULL)
              AND (reg.pro00_codpro = ? OR CAST(reg.pro00_codpro AS TEXT) = ?)
            GROUP BY reg.pro00_codpro
          ) pco_reg ON (pco_reg.pro00_codpro = sel.pro00_codigo OR CAST(pco_reg.pro00_codpro AS TEXT) = CAST(sel.pro00_codigo AS TEXT))
        ''';
        precoArgs.addAll([codpro, codpro.toString()]);
        selPreco = '''
          COALESCE(NULLIF(pco_reg.pcomax, 0.0), $expPrecoVenda) AS pro00_pcomax,
          COALESCE(NULLIF(pco_reg.pcomin, 0.0), $expMin) AS pro00_pcomin,
          COALESCE(NULLIF(pco_reg.pcomax, 0.0), $expPrecoVenda) AS preco_venda
        ''';
      } else {
        selPreco = '''
          $expPrecoVenda AS pro00_pcomax,
          $expMin AS pro00_pcomin,
          $expPrecoVenda AS preco_venda
        ''';
      }
    } else if (hasEstpcoreg00 && tabelas.contains('estpcoregpco00')) {
      joinPreco = '''
        LEFT JOIN (
          SELECT 
            reg.pro00_codpro,
            MAX(pco.pro00_pcomax) AS pcomax,
            MAX(pco.pro00_pcomin) AS pcomin
          FROM estpcoreg00 reg
          JOIN estpcoregpco00 pco 
            ON (pco.pro00_codseq = reg.pro00_codpco OR CAST(pco.pro00_codseq AS TEXT) = CAST(reg.pro00_codpco AS TEXT))
          WHERE (reg.pro00_codkey = 1 OR reg.pro00_codkey IS NULL)
            AND (reg.pro00_codpro = ? OR CAST(reg.pro00_codpro AS TEXT) = ?)
          GROUP BY reg.pro00_codpro
        ) pco_reg ON (pco_reg.pro00_codpro = sel.pro00_codigo OR CAST(pco_reg.pro00_codpro AS TEXT) = CAST(sel.pro00_codigo AS TEXT))
      ''';
      precoArgs.addAll([codpro, codpro.toString()]);
      selPreco = '''
        COALESCE(pco_reg.pcomax, 0.0) AS pro00_pcomax,
        COALESCE(pco_reg.pcomin, 0.0) AS pro00_pcomin,
        COALESCE(pco_reg.pcomax, 0.0) AS preco_venda
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
    final String fallbackQtd = proCols.contains('pro00_qtdest') ? 'sel.pro00_qtdest' : '0.0';
    String selEstoque = 'COALESCE($fallbackQtd, 0.0) AS pro00_qtdest';
    String selEstAtual = 'COALESCE($fallbackQtd, 0.0) AS estoque_atual';
    String selEstPen = '0.0 AS estoque_pendente';
    String selSaldoEst = 'COALESCE($fallbackQtd, 0.0) AS saldo_estoque';
    String selPrifil = "'S' AS pro00_prifil";

    if (hasEstpro00) {
      Set<String> estCols = {};
      try {
        final eRows = await db.rawQuery('PRAGMA table_info(estpro00)');
        estCols = eRows.map((r) => r['name']?.toString().toLowerCase() ?? '').toSet();
      } catch (_) {}

      final String penCol = estCols.contains('pro00_qtdpen') ? 'COALESCE(est.pro00_qtdpen, 0.0)' : '0.0';
      joinEstpro00 = '''
        LEFT JOIN estpro00 est 
               ON (est.pro00_codpro = sel.pro00_codigo 
                   OR CAST(est.pro00_codpro AS TEXT) = CAST(sel.pro00_codigo AS TEXT)
                   OR CAST(est.pro00_codpro AS INTEGER) = CAST(sel.pro00_codigo AS INTEGER))
              AND (CAST(est.pro00_codfil AS INTEGER) = ? OR CAST(est.pro00_codfil AS INTEGER) = 0)
      ''';

      selEstoque = 'COALESCE(est.pro00_qtdest - $penCol, 0.0) AS pro00_qtdest';
      selEstAtual = 'COALESCE(est.pro00_qtdest, 0.0) AS estoque_atual';
      selEstPen = 'COALESCE($penCol, 0.0) AS estoque_pendente';
      selSaldoEst = 'COALESCE(est.pro00_qtdest - $penCol, 0.0) AS saldo_estoque';

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
        $selEstAtual,
        $selEstPen,
        $selSaldoEst,
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

  /// Consulta rápida de produtos com precificação via estpcoreg00/estpcoregpco00
  /// e isolamento de filial dinâmica selecionada.
  Future<List<ProdutoResultStruct>> buscaProduto({
    String? filtro,
    String? ultimoDescri,
    String? filtroLinha,
    String? filtroGrupo,
    String? filtroFabricante,
    String? filtroMarca,
    bool? apenasEstoque,
    bool? apenasPromocao,
    int? codFilial,
    String? dataEntrada,
    int? codTabela,
    int? offset,
    int limit = 30,
    int? codPlano,
  }) async {
    final db = await _getDb();

    // 1. PARÂMETRO DINÂMICO DE FILIAL SELECIONADA:
    final int filialAtiva = (codFilial != null && codFilial > 0)
        ? codFilial
        : (AppState().codFilialAtiva > 0 ? AppState().codFilialAtiva : 1);

    // Inspeciona metadados em cache de alta velocidade
    final meta = await ProdutoMetadataCache.get(db);
    final proCols = meta.proCols;
    final bool hasEmb = meta.hasEmb;
    final bool hasEst = meta.hasEst;
    final bool hasReg = meta.hasReg;
    final bool hasPco = meta.hasPco;
    final bool hasPcopro = meta.hasPcopro;
    final bool hasMar = meta.hasMar;
    final bool hasFab = meta.hasFab;
    final estCols = meta.estCols;

    // Mapeamento dinâmico de colunas seguras da subquery cadpro00
    final String colUnid = proCols.contains('pro00_unidad')
        ? 'pro00_unidad'
        : (proCols.contains('unidade') ? 'unidade AS pro00_unidad' : "'UN' AS pro00_unidad");
    final String colCodbar = proCols.contains('pro00_codbar')
        ? 'pro00_codbar'
        : (proCols.contains('codbar') ? 'codbar AS pro00_codbar' : "'' AS pro00_codbar");
    final String colReffor = proCols.contains('pro00_reffor')
        ? 'pro00_reffor'
        : (proCols.contains('reffor') ? 'reffor AS pro00_reffor' : "'' AS pro00_reffor");
    final String colCodimg = proCols.contains('pro00_codimg')
        ? 'pro00_codimg'
        : (proCols.contains('codimg') ? 'codimg AS pro00_codimg' : '0 AS pro00_codimg');
    final String colCodemb = proCols.contains('pro00_codemb')
        ? 'pro00_codemb'
        : 'NULL AS pro00_codemb';
    final String colEmbala = proCols.contains('pro00_embala')
        ? 'pro00_embala'
        : (proCols.contains('embalagem') ? 'embalagem AS pro00_embala' : "'' AS pro00_embala");
    final String colPcomaxCad = proCols.contains('pro00_pcomax')
        ? 'pro00_pcomax'
        : '0.0 AS pro00_pcomax';
    final String colQtdestCad = proCols.contains('pro00_qtdest')
        ? 'pro00_qtdest'
        : '0.0 AS pro00_qtdest';
    final String colRef1 = proCols.contains('pro00_ref001')
        ? 'pro00_ref001'
        : "'' AS pro00_ref001";
    final String colRef2 = proCols.contains('pro00_ref002')
        ? 'pro00_ref002'
        : "'' AS pro00_ref002";
    final String colCodmar = proCols.contains('pro00_codmar')
        ? 'pro00_codmar'
        : 'NULL AS pro00_codmar';
    final String colCodfab = proCols.contains('pro00_codfab')
        ? 'pro00_codfab'
        : 'NULL AS pro00_codfab';

    // Monta WHERE interna e binds internos da subquery
    final List<String> condicoesInternas = [];
    final List<dynamic> bindsInternos = [];

    final String busca = (filtro ?? '').trim();
    if (busca.isNotEmpty) {
      final List<String> refs = [
        if (proCols.contains('pro00_ref001')) 'pro00_ref001',
        if (proCols.contains('pro00_ref002')) 'pro00_ref002',
        if (proCols.contains('pro00_reffor')) 'pro00_reffor',
      ];
      final buscaResult = ProdutoSearchFilterBuilder.build(
        input: busca,
        colDesc: 'pro00_descri',
        colCod: 'pro00_codigo',
        colCodbar: (proCols.contains('pro00_codbar') || proCols.contains('codbar')) ? 'pro00_codbar' : null,
        colRefs: refs,
      );
      if (buscaResult.hasFilter) {
        condicoesInternas.add(buscaResult.sql);
        bindsInternos.addAll(buscaResult.binds);
      }
    }

    if (filtroLinha != null && filtroLinha.trim().isNotEmpty && filtroLinha != 'Todas' && proCols.contains('pro00_codlin')) {
      final val = int.tryParse(filtroLinha.trim());
      if (val != null) {
        condicoesInternas.add('pro00_codlin = ?');
        bindsInternos.add(val);
      }
    }

    if (filtroGrupo != null && filtroGrupo.trim().isNotEmpty && filtroGrupo != 'Todas' && proCols.contains('pro00_codgrp')) {
      final val = int.tryParse(filtroGrupo.trim());
      if (val != null) {
        condicoesInternas.add('pro00_codgrp = ?');
        bindsInternos.add(val);
      }
    }

    if (filtroFabricante != null && filtroFabricante.trim().isNotEmpty && filtroFabricante != 'Todas') {
      final fabTermo = filtroFabricante.trim();
      final val = int.tryParse(fabTermo);
      if (hasFab && proCols.contains('pro00_codfab')) {
        condicoesInternas.add(
          '(pro00_codfab = ? OR pro00_codfab IN (SELECT for00_codigo FROM cadfor00 WHERE for00_descri = ?))',
        );
        bindsInternos.add(val ?? -1);
        bindsInternos.add(fabTermo);
      } else if (val != null && proCols.contains('pro00_codfab')) {
        condicoesInternas.add('pro00_codfab = ?');
        bindsInternos.add(val);
      }
    }

    if (filtroMarca != null && filtroMarca.trim().isNotEmpty && filtroMarca != 'Todas') {
      final marcaTermo = filtroMarca.trim();
      final val = int.tryParse(marcaTermo);
      if (hasMar && proCols.contains('pro00_codmar')) {
        condicoesInternas.add(
          '(pro00_codmar = ? OR pro00_codmar IN (SELECT mar00_codigo FROM cadmar00 WHERE mar00_descri = ?))',
        );
        bindsInternos.add(val ?? -1);
        bindsInternos.add(marcaTermo);
      } else if (val != null && proCols.contains('pro00_codmar')) {
        condicoesInternas.add('pro00_codmar = ?');
        bindsInternos.add(val);
      }
    }

    if (apenasEstoque == true) {
      if (hasEst) {
        final String penField = estCols.contains('pro00_qtdpen') ? 'COALESCE(pro00_qtdpen, 0)' : '0';
        condicoesInternas.add('''
          pro00_codigo IN (
            SELECT pro00_codpro FROM estpro00 
            WHERE (CAST(pro00_codfil AS INTEGER) = ? OR CAST(pro00_codfil AS INTEGER) = 0)
              AND (pro00_qtdest - $penField) > 0
          )
        ''');
        bindsInternos.add(filialAtiva);
      } else {
        condicoesInternas.add('pro00_qtdest > 0');
      }
    }

    final String whereInterna = condicoesInternas.isNotEmpty
        ? 'WHERE ${condicoesInternas.join(' AND ')}'
        : '';

    final int pageOffset = (offset != null && offset > 0) ? offset : 0;
    final int pageLimit = limit > 0 ? limit : 100;

    // Joins opcionais e seguros conforme tabelas existentes
    final String joinEmb = hasEmb
        ? 'LEFT JOIN cadproemb00 emb ON (emb.emb00_codseq = p.pro00_codemb OR CAST(emb.emb00_codseq AS TEXT) = CAST(p.pro00_codemb AS TEXT))'
        : '';
    final String selEmbalagem = hasEmb
        ? 'COALESCE(emb.emb00_embala, NULLIF(p.pro00_embala, \'\'), p.pro00_unidad) AS embalagem'
        : (proCols.contains('pro00_embala')
            ? 'COALESCE(NULLIF(p.pro00_embala, \'\'), p.pro00_unidad) AS embalagem'
            : 'p.pro00_unidad AS embalagem');

    final String joinEst = hasEst
        ? '''
          LEFT JOIN estpro00 est 
                 ON (est.pro00_codpro = p.pro00_codigo 
                     OR CAST(est.pro00_codpro AS TEXT) = CAST(p.pro00_codigo AS TEXT)
                     OR CAST(est.pro00_codpro AS INTEGER) = CAST(p.pro00_codigo AS INTEGER)) 
                AND (CAST(est.pro00_codfil AS INTEGER) = ? OR CAST(est.pro00_codfil AS INTEGER) = 0)
        '''
        : '';
    final String penExp = estCols.contains('pro00_qtdpen') ? 'COALESCE(est.pro00_qtdpen, 0.0)' : '0.0';
    final String selEstoque = hasEst
        ? 'COALESCE(MAX(est.pro00_qtdest - $penExp), 0.0) AS estoque_saldo'
        : 'COALESCE(p.pro00_qtdest, 0.0) AS estoque_saldo';
    final String selEstAtual = hasEst
        ? 'COALESCE(MAX(est.pro00_qtdest), 0.0) AS estoque_atual'
        : 'COALESCE(p.pro00_qtdest, 0.0) AS estoque_atual';
    final String selEstPen = hasEst
        ? 'COALESCE(MAX($penExp), 0.0) AS estoque_pendente'
        : '0.0 AS estoque_pendente';

    String joinPco = '';
    String fallbackPco = '0.0';

    if (hasPcopro) {
      final String tblP = meta.tblPcopro ?? 'estpcopro00';
      joinPco += '''
        LEFT JOIN $tblP pcopro 
               ON (pcopro.pro00_codpro = p.pro00_codigo OR CAST(pcopro.pro00_codpro AS TEXT) = CAST(p.pro00_codigo AS TEXT))
      ''';
      fallbackPco = 'COALESCE(NULLIF(MAX(pcopro.pro00_pcosub), 0.0), 0.0)';
    }

    String selPcomax = 'COALESCE($fallbackPco, 0.0) AS pcomax';
    String selPcomin = 'COALESCE($fallbackPco, 0.0) AS pcomin';

    if (hasReg && hasPco) {
      joinPco += '''
        LEFT JOIN estpcoreg00 reg 
               ON (reg.pro00_codpro = p.pro00_codigo OR CAST(reg.pro00_codpro AS TEXT) = CAST(p.pro00_codigo AS TEXT)) 
              AND reg.pro00_codkey = 1
        LEFT JOIN estpcoregpco00 pco 
               ON (pco.pro00_codseq = reg.pro00_codpco OR CAST(pco.pro00_codseq AS TEXT) = CAST(reg.pro00_codpco AS TEXT))
      ''';
      selPcomax = 'COALESCE(NULLIF(MAX(pco.pro00_pcomax), 0.0), $fallbackPco, 0.0) AS pcomax';
      selPcomin = 'COALESCE(NULLIF(MAX(pco.pro00_pcomin), 0.0), $fallbackPco, 0.0) AS pcomin';
    }

    final String joinMar = hasMar
        ? 'LEFT JOIN cadmar00 mar ON (mar.mar00_codigo = p.pro00_codmar OR CAST(mar.mar00_codigo AS TEXT) = CAST(p.pro00_codmar AS TEXT))'
        : '';
    final String selMarca = hasMar
        ? "COALESCE(mar.mar00_descri, 'SEM MARCA') AS marca_nome"
        : "'SEM MARCA' AS marca_nome";

    final String joinFab = hasFab
        ? 'LEFT JOIN cadfor00 fab ON (fab.for00_codigo = p.pro00_codfab OR CAST(fab.for00_codigo AS TEXT) = CAST(p.pro00_codfab AS TEXT))'
        : '';
    final String selFab = hasFab
        ? "COALESCE(fab.for00_descri, '') AS fabricante_nome"
        : "'' AS fabricante_nome";

    final String havingClause = apenasEstoque == true ? 'HAVING estoque_saldo > 0' : '';

    // 2. QUERY DE ALTA PERFORMANCE (SEM FULL SCAN, SEM ÍNDICES ADICIONAIS E SEM DUPLICAÇÃO)
    final String query = '''
      SELECT 
          p.pro00_codigo,
          p.pro00_descri,
          p.pro00_unidad,
          p.pro00_codbar,
          p.pro00_reffor,
          p.pro00_ref001,
          p.pro00_ref002,
          p.pro00_codimg,
          $selMarca,
          $selFab,
          $selEmbalagem,
          $selEstoque,
          $selEstAtual,
          $selEstPen,
          $selPcomax,
          $selPcomin
      FROM (
          SELECT pro00_codigo, pro00_descri, $colUnid, $colCodbar, $colReffor, $colRef1, $colRef2, $colCodimg, $colCodemb, $colEmbala, $colPcomaxCad, $colQtdestCad, $colCodmar, $colCodfab
          FROM cadpro00
          $whereInterna
          ORDER BY pro00_descri ASC
          LIMIT ? OFFSET ?
      ) p
      $joinEmb
      $joinEst
      $joinPco
      $joinMar
      $joinFab
      GROUP BY p.pro00_codigo
      $havingClause
      ORDER BY p.pro00_descri ASC;
    ''';

    // 3. ORDEM E BIND DOS ARGUMENTOS:
    // 1º Termos de busca da WHERE interna de 'cadpro00' (se houver).
    // 2º LIMIT e OFFSET da subquery interna.
    // 3º filialAtiva (para 'est.pro00_codfil = ?').
    final List<dynamic> args = [
      ...bindsInternos,
      pageLimit,
      pageOffset,
      if (hasEst) filialAtiva,
    ];

    final rows = await db.rawQuery(query, args);

    final int planoFinal = (codPlano != null && codPlano > 0) ? codPlano : AppState().planoAtivo;
    final double fatorPlano = await CalculoPrecoProdutoService.obterFatorPlano(planoFinal, db: db);

    // 4. MAPEAMENTO DE RETORNO (ProdutoResultStruct)
    return rows.map((m) {
      final double rawPmax = (m['pcomax'] as num?)?.toDouble() ?? 0.0;
      final double rawPmin = (m['pcomin'] as num?)?.toDouble() ?? rawPmax;
      final double saldo = (m['estoque_saldo'] as num?)?.toDouble() ?? 0.0;
      final double atual = (m['estoque_atual'] as num?)?.toDouble() ?? saldo;
      final double pendente = (m['estoque_pendente'] as num?)?.toDouble() ?? 0.0;

      final double pmax = (fatorPlano > 0 && fatorPlano != 1.0)
          ? CalculoPrecoProdutoService.arredondarMoeda(rawPmax * fatorPlano)
          : rawPmax;
      final double pmin = (fatorPlano > 0 && fatorPlano != 1.0)
          ? CalculoPrecoProdutoService.arredondarMoeda(rawPmin * fatorPlano)
          : rawPmin;

      return ProdutoResultStruct(
        codigo: (m['pro00_codigo'] ?? '').toString(),
        descricao: (m['pro00_descri'] ?? '').toString(),
        unidade: (m['pro00_unidad'] ?? 'UN').toString(),
        embalagem: (m['embalagem'] ?? 'UN').toString(),
        codbar: (m['pro00_codbar'] ?? '').toString(),
        reffor: (m['pro00_reffor'] ?? '').toString(),
        referencia1: (m['pro00_ref001'] ?? '').toString(),
        referencia2: (m['pro00_ref002'] ?? '').toString(),
        marca: (m['marca_nome'] ?? 'SEM MARCA').toString(),
        fabricante: (m['fabricante_nome'] ?? '').toString(),
        imagemId: (m['pro00_codimg'] as num?)?.toInt() ?? 0,
        saldoEstoque: saldo,
        estoqueAtual: atual,
        estoquePendente: pendente,
        preco: pmax,
        pcomax: pmax,
        pcomin: pmin,
      );
    }).toList();
  }
}
