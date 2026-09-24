import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '/domain/models/produto_lookup_dto.dart';
import '/domain/models/produto_card_dto.dart';
import '/domain/models/produto_detalhe_dto.dart';

/// Repositório de dados para consulta e seleção de produtos.
/// Implementa a estratégia em duas etapas da SPEC-052 e método Tcadpro00::cload de usysctr00.cpp.
class ProdutoRepository {
  ProdutoRepository({Database? db}) : _db = db;

  final Database? _db;

  Future<Database> _getDb() async {
    if (_db != null) return _db!;
    final dbPath = join(await getDatabasesPath(), 'dbforcacad001.db');
    return await openDatabase(dbPath, readOnly: true, singleInstance: false);
  }

  /// QUERY 1: LISTAGEM LEVE DO CARD (Pesquisa / Scroll Infinito)
  ///
  /// Executa consulta ultra-rápida trazendo estritamente os campos visuais do card
  /// e o saldo físico disponível da filial ativa (pro00_qtdest - pro00_qtdpen).
  Future<List<ProdutoCardDTO>> listarProdutosCard({
    String? termo,
    String? cursorDescri,
    required int filialAtiva,
    int codTabela = 1,
    int limit = 100,
    int offset = 0,
  }) async {
    final db = await _getDb();

    final bool temTermo = termo != null && termo.trim().isNotEmpty;
    final String termoTrim = temTermo ? termo.trim() : '';
    final bool temCursor = cursorDescri != null && cursorDescri.trim().isNotEmpty;

    bool temEstpcopro00 = false;
    try {
      final r = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table' AND name='estpcopro00'");
      temEstpcopro00 = r.isNotEmpty;
    } catch (_) {}

    final List<String> condicoes = [];
    final List<dynamic> args = [filialAtiva];
    if (temEstpcopro00) {
      args.add(codTabela);
    }

    if (temTermo) {
      condicoes.add('(p.pro00_descri LIKE ? OR CAST(p.pro00_codigo AS TEXT) = ? OR p.pro00_codbar = ?)');
      args.add('%$termoTrim%');
      args.add(termoTrim);
      args.add(termoTrim);
    }
    if (temCursor) {
      condicoes.add('p.pro00_descri > ?');
      args.add(cursorDescri.trim());
    }

    final String whereClause = condicoes.isNotEmpty ? 'WHERE ${condicoes.join(' AND ')}' : '';

    String limitClause = '';
    if (limit > 0) {
      limitClause = 'LIMIT ? OFFSET ?';
      args.add(limit);
      args.add(offset);
    }

    final joinPreco = temEstpcopro00
        ? '''LEFT JOIN estpcopro00 t 
                   ON t.pro00_codpro = p.pro00_codigo 
                  AND t.pro00_codtab = ?'''
        : '';
    final selPreco = temEstpcopro00
        ? 'COALESCE(t.pro00_pcosub, t.pro00_preco, 0.0) AS pro00_pcomax'
        : '0.0 AS pro00_pcomax';

    final sql = '''
      SELECT 
        p.pro00_codigo,
        p.pro00_descri,
        COALESCE(p.pro00_unidad, 'UN') AS pro00_unidad,
        COALESCE(p.pro00_codbar, '') AS pro00_codbar,
        p.pro00_codimg,
        $selPreco,
        COALESCE(e.pro00_qtdest - COALESCE(e.pro00_qtdpen, 0), 0) AS pro00_qtdest
      FROM cadpro00 p
      LEFT JOIN estpro00 e 
             ON e.pro00_codpro = p.pro00_codigo 
            AND e.pro00_codfil = ?
      $joinPreco
      $whereClause
      ORDER BY p.pro00_descri ASC
      $limitClause;
    ''';

    final rows = await db.rawQuery(sql, args);
    return rows.map((r) => ProdutoCardDTO.fromMap(r)).toList();
  }

  /// QUERY 2: DETALHE COMPLETO SOB DEMANDA (Tcadpro00::cload de usysctr00.cpp)
  ///
  /// Executada estritamente sob demanda ao clicar no card de um produto.
  /// Carrega todas as 26 colunas canônicas e amarrações relacionais do legado:
  /// cadpro02, estpro00, cadprofra00, cadprobon00, cadproemb00 e estprodat00.
  Future<ProdutoDetalheDTO?> obterDetalhesProduto(
    int codpro,
    int filialAtiva,
  ) async {
    final db = await _getDb();

    const sql = '''
      SELECT DISTINCT
        sel.pro00_codigo,
        sel.pro00_codbar,
        sel.pro00_descri,
        sel.pro00_deslon,
        sel.pro00_unidad,
        sel.pro00_codimg,
        emb.emb00_embala,
        fra.fra00_indfra,
        fra.fra00_peso,
        sel.pro00_codfab,
        sel.pro00_codmar,
        sel.pro00_codgrp,
        sel.pro00_codsgr,
        sel.pro00_coddep,
        sel.pro00_codsec,
        sel.pro00_codlin,
        sel.pro00_codtrb,
        sel.pro00_pesbru,
        sel.pro00_pesliq,
        bon.bon00_defbon,
        bon.bon00_defbonven,
        ed0.pro00_entdat,
        est.pro00_prifil,
        COALESCE(est.pro00_qtdest - est.pro00_qtdpen, 0) AS pro00_qtdest,
        COALESCE(pr2.pro02_mulemb, 1)                    AS pro02_mulemb,
        COALESCE(pr2.pro02_mulven, 1.0)                  AS pro02_mulven
      FROM cadpro00 sel
      LEFT JOIN cadpro02    pr2 ON pr2.pro02_codpro = sel.pro00_codigo
      LEFT JOIN estpro00    est ON est.pro00_codfil = ? 
                               AND est.pro00_codpro = sel.pro00_codigo
      LEFT JOIN cadprofra00 fra ON fra.fra00_codpro = sel.pro00_codigo
      LEFT JOIN cadprobon00 bon ON bon.bon00_codpro = sel.pro00_codigo
      LEFT JOIN cadproemb00 emb ON emb.emb00_codseq = sel.pro00_codemb
      LEFT JOIN estprodat00 ed0 ON ed0.pro00_codfil = ? 
                               AND ed0.pro00_codpro = sel.pro00_codigo
      WHERE sel.pro00_codigo = ?;
    ''';

    final rows = await db.rawQuery(sql, [filialAtiva, filialAtiva, codpro]);
    if (rows.isEmpty) return null;
    return ProdutoDetalheDTO.fromMap(rows.first);
  }

  /// Realiza a busca multifiltro por EAN, Marca, Referência 1, Referência 2 ou Descrição.
  Future<List<ProdutoLookupDTO>> buscarProdutos(
    String? query, {
    int limit = 100,
    int offset = 0,
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
        COALESCE(p.pro00_qtdest, 0.0)         AS estoque_saldo,
        0.0                                   AS preco_tabela,
        p.pro00_codimg   AS imagem_id
      FROM cadpro00 p
      LEFT JOIN cadmar00 m ON m.mar00_codigo = p.pro00_codmar
      LEFT JOIN cadfor00 f ON f.for00_codigo = p.pro00_codfab
      $whereClause
      ORDER BY p.pro00_descri ASC
      LIMIT ? OFFSET ?
    ''';

    binds.addAll([limit, offset]);

    final rows = await db.rawQuery(sql, binds);
    return rows.map((row) => ProdutoLookupDTO.fromMap(row)).toList();
  }
}
