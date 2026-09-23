import 'dart:io';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '/backend/schema/structs/index.dart';
import '../app_state.dart';

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
  Database? db;
  try {
    final dbPath = join(await getDatabasesPath(), 'dbforcacad001.db');
    if (!await File(dbPath).exists()) return [];

    db = await openDatabase(dbPath, readOnly: true, singleInstance: false);

    final int filial = (codFilial == null || codFilial == 0)
        ? (AppState().codFilialAtiva != 0 ? AppState().codFilialAtiva : 1)
        : codFilial;

    final int pageOffset = offset ?? 0;
    final String termo = (filtro ?? '').trim();
    final bool temTermo = termo.isNotEmpty;

    // Introspecção de tabelas e colunas para tolerância a variações de schema
    final pragmaPro = await db.rawQuery('PRAGMA table_info(cadpro00)');
    final colsPro = pragmaPro.map((e) => e['name'] as String).toSet();

    final pragmaEst = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table' AND name='estpro00'");
    final bool temEstoque = pragmaEst.isNotEmpty;

    Set<String> colsEst = {};
    if (temEstoque) {
      final pragmaColsEst = await db.rawQuery('PRAGMA table_info(estpro00)');
      colsEst = pragmaColsEst.map((e) => e['name'] as String).toSet();
    }
    final bool hasQtdpen = colsEst.contains('pro00_qtdpen');

    final pragmaMar = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table' AND name='cadmar00'");
    final bool temMarca = pragmaMar.isNotEmpty;

    final pragmaFab = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table' AND name='cadfor00'");
    final bool temFab = pragmaFab.isNotEmpty;

    final bool usaMarca = temMarca && colsPro.contains('pro00_codmar');
    final bool usaFab = temFab && colsPro.contains('pro00_codfab');

    final bool hasRef1 = colsPro.contains('pro00_ref001');
    final bool hasRef2 = colsPro.contains('pro00_ref002');
    final bool hasRefFor = colsPro.contains('pro00_reffor');
    final bool hasEmbala = colsPro.contains('pro00_embala');
    final bool hasImg = colsPro.contains('pro00_codimg');

    final List<String> condicoes = [];
    final List<dynamic> binds = [];

    // 1. Join Binds (Estoque)
    if (temEstoque) {
      binds.add(filial);
    }

    final bool temCursor = (ultimoDescri != null && ultimoDescri.trim().isNotEmpty && pageOffset == 0);

    // 2. Filtro Termo de Busca
    if (temTermo) {
      final List<String> orClauses = [
        'p.pro00_descri LIKE ?',
        'p.pro00_codbar = ?',
        'CAST(p.pro00_codigo AS TEXT) = ?',
      ];
      binds.add('%$termo%');
      binds.add(termo);
      binds.add(termo);

      if (hasRef1) {
        orClauses.add('p.pro00_ref001 LIKE ?');
        binds.add('%$termo%');
      }
      if (hasRef2) {
        orClauses.add('p.pro00_ref002 LIKE ?');
        binds.add('%$termo%');
      }
      if (usaMarca) {
        orClauses.add('m.mar00_descri LIKE ?');
        binds.add('%$termo%');
      }

      condicoes.add('(${orClauses.join(' OR ')})');
    }

    // 3. Paginação Keyset Cursor
    if (temCursor) {
      condicoes.add('p.pro00_descri > ?');
      binds.add(ultimoDescri.trim());
    }

    // 4. Filtros Avançados
    if (usaMarca && filtroMarca != null && filtroMarca.isNotEmpty && filtroMarca != 'Todas') {
      condicoes.add('m.mar00_descri = ?');
      binds.add(filtroMarca);
    }

    if (apenasEstoque == true) {
      if (temEstoque) {
        if (hasQtdpen) {
          condicoes.add('COALESCE(e.pro00_qtdest - COALESCE(e.pro00_qtdpen, 0), 0) > 0');
        } else {
          condicoes.add('COALESCE(e.pro00_qtdest, 0) > 0');
        }
      } else if (colsPro.contains('pro00_qtdest')) {
        condicoes.add('COALESCE(p.pro00_qtdest, 0) > 0');
      }
    }

    final String whereSql = condicoes.isNotEmpty ? 'WHERE ${condicoes.join(' AND ')}' : '';

    // 4. Limit e Offset Binds
    binds.add(100);
    binds.add(pageOffset);

    // Definição de projeção dinâmica
    final String selRef1 = hasRef1 ? "COALESCE(p.pro00_ref001, '') AS ref001" : "'' AS ref001";
    final String selRef2 = hasRef2 ? "COALESCE(p.pro00_ref002, '') AS ref002" : "'' AS ref002";
    final String selRefFor = hasRefFor ? "COALESCE(p.pro00_reffor, '') AS reffor" : "'' AS reffor";
    final String selEmbala = hasEmbala
        ? "COALESCE(p.pro00_embala, p.pro00_unidad, 'UN') AS embalagem"
        : "COALESCE(p.pro00_unidad, 'UN') AS embalagem";
    final String selImg = hasImg ? "p.pro00_codimg" : "NULL AS pro00_codimg";

    final String selPreco;
    if (colsPro.contains('pro00_preco')) {
      selPreco = "COALESCE(p.pro00_preco, 0.0) AS preco_venda";
    } else if (colsPro.contains('pro00_pcomax')) {
      selPreco = "COALESCE(p.pro00_pcomax, 0.0) AS preco_venda";
    } else {
      selPreco = "0.0 AS preco_venda";
    }

    final String selEstoque = temEstoque
        ? (hasQtdpen
            ? 'COALESCE(MAX(e.pro00_qtdest - COALESCE(e.pro00_qtdpen, 0)), 0) AS pro00_qtdest'
            : 'COALESCE(MAX(e.pro00_qtdest), 0) AS pro00_qtdest')
        : (colsPro.contains('pro00_qtdest')
            ? 'COALESCE(MAX(p.pro00_qtdest), 0) AS pro00_qtdest'
            : '0.0 AS pro00_qtdest');

    final String joinEst = temEstoque
        ? '''LEFT JOIN estpro00 e 
               ON (e.pro00_codpro = p.pro00_codigo OR CAST(e.pro00_codpro AS INTEGER) = p.pro00_codigo)
              AND CAST(e.pro00_codfil AS INTEGER) = ?'''
        : '';

    final String joinMar = usaMarca
        ? 'LEFT JOIN cadmar00 m ON m.mar00_codigo = p.pro00_codmar'
        : '';

    final String joinFab = usaFab
        ? 'LEFT JOIN cadfor00 f ON f.for00_codigo = p.pro00_codfab'
        : '';

    final String selMarca = usaMarca
        ? "COALESCE(m.mar00_descri, 'SEM MARCA') AS marca_nome"
        : "'SEM MARCA' AS marca_nome";

    final String selFab = usaFab
        ? "COALESCE(f.for00_descri, '') AS fabricante_nome"
        : "'' AS fabricante_nome";

    final String query = '''
      SELECT 
        p.pro00_codigo,
        p.pro00_descri,
        COALESCE(p.pro00_unidad, 'UN') AS pro00_unidad,
        COALESCE(p.pro00_codbar, '')   AS pro00_codbar,
        $selImg,
        $selPreco,
        $selEstoque,
        $selRef1,
        $selRef2,
        $selRefFor,
        $selEmbala,
        $selMarca,
        $selFab
      FROM cadpro00 p
      $joinEst
      $joinMar
      $joinFab
      $whereSql
      GROUP BY p.pro00_codigo
      ORDER BY p.pro00_descri ASC
      LIMIT ? OFFSET ?;
    ''';

    final List<Map<String, dynamic>> rows = await db.rawQuery(query, binds);

    return rows.map((m) {
      final double qtd = (m['pro00_qtdest'] as num?)?.toDouble() ?? 0.0;
      final double precoVenda = (m['preco_venda'] as num?)?.toDouble() ?? 0.0;

      return ProdutoResultStruct(
        codigo: (m['pro00_codigo'] ?? '').toString(),
        descricao: (m['pro00_descri'] ?? '').toString(),
        unidade: (m['pro00_unidad'] ?? 'UN').toString(),
        codbar: (m['pro00_codbar'] ?? '').toString(),
        imagemId: (m['pro00_codimg'] as num?)?.toInt() ?? 0,
        saldoEstoque: qtd,
        estoqueAtual: qtd,
        preco: precoVenda,
        pcomax: precoVenda,
        embalagem: (m['embalagem'] ?? m['pro00_unidad'] ?? 'UN').toString(),
        marca: (m['marca_nome'] ?? 'SEM MARCA').toString(),
        fabricante: (m['fabricante_nome'] ?? '').toString(),
        referencia1: (m['ref001'] ?? '').toString(),
        referencia2: (m['ref002'] ?? '').toString(),
        reffor: (m['reffor'] ?? '').toString(),
      );
    }).toList();
  } catch (e) {
    print('ERRO BUSCA PRODUTO: $e');
    return [];
  } finally {
    await db?.close();
  }
}

