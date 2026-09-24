import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '/backend/schema/structs/index.dart';
import '../app_state.dart';

Database? _dbProdutoInstancia;

/// Cache em memória dos metadados de tabelas e colunas para evitar consultas
/// repetidas a 'PRAGMA table_info' e 'sqlite_master' a cada digitação do usuário.
class ProductDbMetadata {
  static bool loaded = false;
  static String tabelaPro = 'cadpro00';
  static Set<String> proCols = {};
  static bool hasEst = false;
  static bool hasQtdpen = false;
  static String? tblPco;
  static String? pcoCodCol;
  static String? pcoTabCol;
  static String? pcoPrecoCol;
  static String? tblMar;
  static String? tblFor;

  static void reset() {
    loaded = false;
    tabelaPro = 'cadpro00';
    proCols = {};
    hasEst = false;
    hasQtdpen = false;
    tblPco = null;
    pcoCodCol = null;
    pcoTabCol = null;
    pcoPrecoCol = null;
    tblMar = null;
    tblFor = null;
  }

  static Future<void> ensureLoaded(Database db) async {
    if (loaded) {
      try {
        await db.rawQuery("SELECT 1 FROM $tabelaPro LIMIT 1");
      } catch (_) {
        loaded = false;
      }
    }
    if (loaded) return;

    try {
      final t = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table'");
      final allTables = t.map((r) => r['name']?.toString().toLowerCase() ?? '').toSet();

      tabelaPro = allTables.contains('cadpro00') ? 'cadpro00' : (allTables.contains('pro00') ? 'pro00' : 'cadpro00');

      final cols = await db.rawQuery('PRAGMA table_info($tabelaPro)');
      proCols = cols.map((r) => r['name']?.toString().toLowerCase() ?? '').toSet();

      hasEst = allTables.contains('estpro00');
      if (hasEst) {
        final estCols = (await db.rawQuery('PRAGMA table_info(estpro00)')).map((r) => r['name']?.toString().toLowerCase() ?? '').toSet();
        hasQtdpen = estCols.contains('pro00_qtdpen');
      } else {
        hasQtdpen = false;
      }

      if (allTables.contains('estpcopro00')) {
        tblPco = 'estpcopro00';
      } else if (allTables.contains('pcopro00')) {
        tblPco = 'pcopro00';
      }

      if (tblPco != null) {
        final pCols = (await db.rawQuery('PRAGMA table_info($tblPco)')).map((r) => r['name']?.toString().toLowerCase() ?? '').toSet();
        for (final c in ['pro00_codpro', 'pro00_codigo', 'pcopro00_codpro', 'codpro']) {
          if (pCols.contains(c)) { pcoCodCol = c; break; }
        }
        for (final c in ['pro00_codtab', 'pcopro00_codtab', 'codtab']) {
          if (pCols.contains(c)) { pcoTabCol = c; break; }
        }
        for (final c in ['pro00_pcosub', 'pro00_preco', 'pcopro00_pcosub', 'preco']) {
          if (pCols.contains(c)) { pcoPrecoCol = c; break; }
        }
      }

      if (allTables.contains('cadmar00')) {
        tblMar = 'cadmar00';
      } else if (allTables.contains('mar00')) {
        tblMar = 'mar00';
      }

      if (allTables.contains('cadfor00')) {
        tblFor = 'cadfor00';
      } else if (allTables.contains('for00')) {
        tblFor = 'for00';
      }

      loaded = true;
    } catch (_) {}
  }
}

Future<Database> _getDbProduto() async {
  if (_dbProdutoInstancia != null && _dbProdutoInstancia!.isOpen) {
    return _dbProdutoInstancia!;
  }
  final dbPath = join(await getDatabasesPath(), 'dbforcacad001.db');
  _dbProdutoInstancia = await openDatabase(dbPath);
  ProductDbMetadata.reset();
  return _dbProdutoInstancia!;
}

/// Busca de produtos rápida e otimizada trazendo Preço, Marca e Estoque,
/// armazenando metadados de estrutura e conexão do banco em memória.
Future<List<ProdutoResultStruct>> buscaProduto(
  String? filtro,
  String? ultimoDescri,
  String? filtroLinha,
  String? filtroGrupo,
  String? filtroFabricante,
  String? filtroMarca,
  bool? apenasEstoque,
  bool? apenasPromocao,
  int? codFilial,
  String? dataEntrada, [
  int? codTabela,
  int? offset,
]) async {
  try {
    final db = await _getDbProduto();
    await ProductDbMetadata.ensureLoaded(db);

    final String busca = (filtro ?? '').trim();
    final int filial = (codFilial != null && codFilial > 0)
        ? codFilial
        : (AppState().codFilialAtiva != 0 ? AppState().codFilialAtiva : 1);
    final int tab = (codTabela != null && codTabela > 0) ? codTabela : 1;

    // 1. Projeção de colunas de produto
    final String colCod = ProductDbMetadata.proCols.contains('pro00_codigo')
        ? 'pro00_codigo'
        : (ProductDbMetadata.proCols.contains('codigo') ? 'codigo' : 'rowid');

    final String colDesc = ProductDbMetadata.proCols.contains('pro00_descri')
        ? 'pro00_descri'
        : (ProductDbMetadata.proCols.contains('descri') ? 'descri' : 'descricao');

    final String colUnid = ProductDbMetadata.proCols.contains('pro00_unidad')
        ? 'p.pro00_unidad'
        : (ProductDbMetadata.proCols.contains('unidade') ? 'p.unidade' : "'UN'");

    final String colEmbala = ProductDbMetadata.proCols.contains('pro00_embala')
        ? 'p.pro00_embala'
        : colUnid;

    final String colCodbar = ProductDbMetadata.proCols.contains('pro00_codbar')
        ? 'p.pro00_codbar'
        : (ProductDbMetadata.proCols.contains('codbar') ? 'p.codbar' : "''");

    final String colRef1 = ProductDbMetadata.proCols.contains('pro00_ref001') ? 'p.pro00_ref001' : "''";
    final String colRef2 = ProductDbMetadata.proCols.contains('pro00_ref002') ? 'p.pro00_ref002' : "''";
    final String colRefFor = ProductDbMetadata.proCols.contains('pro00_reffor') ? 'p.pro00_reffor' : "''";
    final String colImg = ProductDbMetadata.proCols.contains('pro00_codimg') ? 'p.pro00_codimg' : '0';

    final String colQtdEst = ProductDbMetadata.proCols.contains('pro00_qtdest')
        ? 'p.pro00_qtdest'
        : (ProductDbMetadata.proCols.contains('qtdest') ? 'p.qtdest' : '0.0');

    final String colPrecoBase = ProductDbMetadata.proCols.contains('pro00_preco')
        ? 'p.pro00_preco'
        : (ProductDbMetadata.proCols.contains('pro00_pcomax')
            ? 'p.pro00_pcomax'
            : (ProductDbMetadata.proCols.contains('preco') ? 'p.preco' : '0.0'));

    final List<dynamic> binds = [];

    // 2. Junção de Marca
    String joinMarca = '';
    String selMarca = "'SEM MARCA' AS marca_nome";
    if (ProductDbMetadata.tblMar != null && ProductDbMetadata.proCols.contains('pro00_codmar')) {
      joinMarca = 'LEFT JOIN ${ProductDbMetadata.tblMar} m ON m.mar00_codigo = p.pro00_codmar';
      selMarca = "COALESCE(m.mar00_descri, 'SEM MARCA') AS marca_nome";
    }

    // 3. Junção de Fabricante
    String joinFab = '';
    String selFab = "'' AS fabricante_nome";
    if (ProductDbMetadata.tblFor != null && ProductDbMetadata.proCols.contains('pro00_codfab')) {
      joinFab = 'LEFT JOIN ${ProductDbMetadata.tblFor} f ON f.for00_codigo = p.pro00_codfab';
      selFab = "COALESCE(f.for00_descri, '') AS fabricante_nome";
    }

    // 4. Junção de Estoque por Filial
    String joinEst = '';
    String selEst = "COALESCE($colQtdEst, 0.0) AS saldo";
    if (ProductDbMetadata.hasEst) {
      joinEst = '''
        LEFT JOIN estpro00 e 
               ON (e.pro00_codpro = p.$colCod OR CAST(e.pro00_codpro AS INTEGER) = CAST(p.$colCod AS INTEGER))
              AND CAST(e.pro00_codfil AS INTEGER) = ?
      ''';
      if (ProductDbMetadata.hasQtdpen) {
        selEst = "COALESCE(e.pro00_qtdest - COALESCE(e.pro00_qtdpen, 0.0), 0.0) AS saldo";
      } else {
        selEst = "COALESCE(e.pro00_qtdest, 0.0) AS saldo";
      }
      binds.add(filial);
    }

    // 5. Junção de Preço por Tabela com fallback
    String joinPco = '';
    String selPco = "COALESCE($colPrecoBase, 0.0) AS preco_venda";
    if (ProductDbMetadata.tblPco != null &&
        ProductDbMetadata.pcoCodCol != null &&
        ProductDbMetadata.pcoPrecoCol != null) {
      if (ProductDbMetadata.pcoTabCol != null) {
        joinPco = 'LEFT JOIN ${ProductDbMetadata.tblPco} t ON (t.${ProductDbMetadata.pcoCodCol} = p.$colCod OR CAST(t.${ProductDbMetadata.pcoCodCol} AS INTEGER) = CAST(p.$colCod AS INTEGER)) AND CAST(t.${ProductDbMetadata.pcoTabCol} AS INTEGER) = ?';
        binds.add(tab);
      } else {
        joinPco = 'LEFT JOIN ${ProductDbMetadata.tblPco} t ON (t.${ProductDbMetadata.pcoCodCol} = p.$colCod OR CAST(t.${ProductDbMetadata.pcoCodCol} AS INTEGER) = CAST(p.$colCod AS INTEGER))';
      }
      selPco = "COALESCE(t.${ProductDbMetadata.pcoPrecoCol}, $colPrecoBase, 0.0) AS preco_venda";
    }

    // 6. Montagem de filtros
    final List<String> condicoes = [];

    if (busca.isNotEmpty) {
      final List<String> orClauses = [
        'p.$colDesc LIKE ?',
        'CAST(p.$colCod AS TEXT) = ?',
      ];
      binds.add('%$busca%');
      binds.add(busca);

      if (ProductDbMetadata.proCols.contains('pro00_codbar') || ProductDbMetadata.proCols.contains('codbar')) {
        orClauses.add('$colCodbar = ?');
        binds.add(busca);
      }
      if (ProductDbMetadata.proCols.contains('pro00_ref001')) {
        orClauses.add('$colRef1 LIKE ?');
        binds.add('%$busca%');
      }
      if (ProductDbMetadata.proCols.contains('pro00_ref002')) {
        orClauses.add('$colRef2 LIKE ?');
        binds.add('%$busca%');
      }
      if (ProductDbMetadata.proCols.contains('pro00_reffor')) {
        orClauses.add('$colRefFor LIKE ?');
        binds.add('%$busca%');
      }
      if (joinMarca.isNotEmpty) {
        orClauses.add('m.mar00_descri LIKE ?');
        binds.add('%$busca%');
      }

      condicoes.add('(${orClauses.join(' OR ')})');
    }

    if (filtroLinha != null && filtroLinha.trim().isNotEmpty && filtroLinha != 'Todas' && ProductDbMetadata.proCols.contains('pro00_codlin')) {
      final val = int.tryParse(filtroLinha.trim());
      if (val != null) {
        condicoes.add('p.pro00_codlin = ?');
        binds.add(val);
      }
    }

    if (filtroGrupo != null && filtroGrupo.trim().isNotEmpty && filtroGrupo != 'Todas' && ProductDbMetadata.proCols.contains('pro00_codgrp')) {
      final val = int.tryParse(filtroGrupo.trim());
      if (val != null) {
        condicoes.add('p.pro00_codgrp = ?');
        binds.add(val);
      }
    }

    if (filtroFabricante != null && filtroFabricante.trim().isNotEmpty && filtroFabricante != 'Todas' && ProductDbMetadata.proCols.contains('pro00_codfab')) {
      final val = int.tryParse(filtroFabricante.trim());
      if (val != null) {
        condicoes.add('p.pro00_codfab = ?');
        binds.add(val);
      }
    }

    if (filtroMarca != null && filtroMarca.trim().isNotEmpty && filtroMarca != 'Todas') {
      if (joinMarca.isNotEmpty) {
        condicoes.add('(m.mar00_descri = ? OR CAST(p.pro00_codmar AS TEXT) = ?)');
        binds.add(filtroMarca.trim());
        binds.add(filtroMarca.trim());
      } else if (ProductDbMetadata.proCols.contains('pro00_codmar')) {
        final val = int.tryParse(filtroMarca.trim());
        if (val != null) {
          condicoes.add('p.pro00_codmar = ?');
          binds.add(val);
        }
      }
    }

    if (apenasEstoque == true) {
      if (ProductDbMetadata.hasEst) {
        if (ProductDbMetadata.hasQtdpen) {
          condicoes.add('COALESCE(e.pro00_qtdest - COALESCE(e.pro00_qtdpen, 0.0), 0.0) > 0');
        } else {
          condicoes.add('COALESCE(e.pro00_qtdest, 0.0) > 0');
        }
      } else {
        condicoes.add('COALESCE($colQtdEst, 0.0) > 0');
      }
    }

    final String whereSql = condicoes.isNotEmpty ? 'WHERE ${condicoes.join(' AND ')}' : '';

    final int pageOffset = (offset != null && offset > 0) ? offset : 0;
    final String limitSql = 'LIMIT 100 OFFSET $pageOffset';

    // 7. Consulta SQL direta com índices ativos
    final String query = '''
      SELECT 
        p.$colCod AS codigo,
        p.$colDesc AS descricao,
        COALESCE($colUnid, 'UN') AS unidade,
        COALESCE($colEmbala, 'UN') AS embalagem,
        COALESCE($colCodbar, '') AS codbar,
        COALESCE($colRef1, '') AS ref001,
        COALESCE($colRef2, '') AS ref002,
        COALESCE($colRefFor, '') AS reffor,
        COALESCE($colImg, 0) AS imagem_id,
        $selMarca,
        $selFab,
        $selEst,
        $selPco
      FROM ${ProductDbMetadata.tabelaPro} p
      $joinEst
      $joinPco
      $joinMarca
      $joinFab
      $whereSql
      ORDER BY p.$colDesc ASC
      $limitSql;
    ''';

    final rows = await db.rawQuery(query, binds);

    return rows.map((m) {
      final double preco = (m['preco_venda'] as num?)?.toDouble() ?? 0.0;
      final double saldo = (m['saldo'] as num?)?.toDouble() ?? 0.0;
      return ProdutoResultStruct(
        codigo: (m['codigo'] ?? '').toString(),
        descricao: (m['descricao'] ?? '').toString(),
        unidade: (m['unidade'] ?? 'UN').toString(),
        embalagem: (m['embalagem'] ?? 'UN').toString(),
        codbar: (m['codbar'] ?? '').toString(),
        marca: (m['marca_nome'] ?? 'SEM MARCA').toString(),
        fabricante: (m['fabricante_nome'] ?? '').toString(),
        referencia1: m['ref001']?.toString() ?? '',
        referencia2: m['ref002']?.toString() ?? '',
        reffor: m['reffor']?.toString() ?? '',
        imagemId: (m['imagem_id'] as num?)?.toInt() ?? 0,
        saldoEstoque: saldo,
        estoqueAtual: saldo,
        preco: preco,
        pcomax: preco,
      );
    }).toList();
  } catch (e, stack) {
    debugPrint('ERRO BUSCA PRODUTO: $e');
    debugPrint(stack.toString());
    return [];
  }
}
