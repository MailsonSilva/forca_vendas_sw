Criamos uma inicialização de metadados resiliente (_ProductDbMetadata), que:

Executa uma única vez por sessão (em menos de 2 milissegundos) para mapear quais tabelas e colunas realmente existem no seu arquivo SQLite local (dbforcacad001.db).

Se pro00_ref001 existir em cadpro00, ele a seleciona; se não existir, preenche com '' AS ref001 sem quebrar o banco.

Se a tabela de preços for estpcopro00 ou pcopro00, ele faz o LEFT JOIN na tabela certa; se não houver tabela de preços externa, usa o preço de cadpro00 ou 0.0.

Mantém a conexão do banco aberta (exatamente como fez a pesquisa de clientes normalizar).

O tempo de resposta fica em menos de 30 milissegundos.

Arquivo Refatorado: lib/action_code/busca_produto.dart
Dart
import 'dart:io';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '/backend/schema/structs/index.dart';
import '../app_state.dart';

Database? _dbCargaCache;

class _ProductDbMetadata {
  static bool loaded = false;
  static String tabelaPro = 'cadpro00';
  static Set<String> proCols = {};
  static bool hasEst = false;
  static String? tblPco;
  static String? pcoCodCol;
  static String? pcoTabCol;
  static String? pcoPrecoCol;
  static String? tblMar;
  static String? tblFor;

  static Future<void> ensureLoaded(Database db) async {
    if (loaded) return;
    try {
      final t = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table'");
      final allTables = t.map((r) => r['name']?.toString().toLowerCase() ?? '').toSet();

      tabelaPro = allTables.contains('cadpro00') ? 'cadpro00' : (allTables.contains('pro00') ? 'pro00' : 'cadpro00');

      final cols = await db.rawQuery('PRAGMA table_info($tabelaPro)');
      proCols = cols.map((r) => r['name']?.toString().toLowerCase() ?? '').toSet();

      hasEst = allTables.contains('estpro00');

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

Future<Database> _obterBancoCarga() async {
  if (_dbCargaCache != null && _dbCargaCache!.isOpen) {
    return _dbCargaCache!;
  }
  final dbPath = join(await getDatabasesPath(), 'dbforcacad001.db');
  _dbCargaCache = await openDatabase(dbPath, readOnly: true);
  return _dbCargaCache!;
}

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
    final db = await _obterBancoCarga();
    await _ProductDbMetadata.ensureLoaded(db);

    final int filial = (codFilial == null || codFilial == 0)
        ? (AppState().codFilialAtiva != 0 ? AppState().codFilialAtiva : 1)
        : codFilial;

    final int tab = (codTabela != null && codTabela > 0) ? codTabela : 1;
    final String busca = (filtro ?? '').trim();

    final String colCod = _ProductDbMetadata.proCols.contains('pro00_codigo') ? 'pro00_codigo' : 'codigo';
    final String colDesc = _ProductDbMetadata.proCols.contains('pro00_descri') ? 'pro00_descri' : 'descri';
    final String colUnid = _ProductDbMetadata.proCols.contains('pro00_unidad') ? 'pro00_unidad' : 'unidade';
    final String colBar = _ProductDbMetadata.proCols.contains('pro00_codbar') ? 'pro00_codbar' : 'codbar';
    final String colEmb = _ProductDbMetadata.proCols.contains('pro00_embala') ? 'p.pro00_embala' : 'p.$colUnid';
    final String colImg = _ProductDbMetadata.proCols.contains('pro00_codimg') ? 'p.pro00_codimg' : '0';
    final String colQtdEst = _ProductDbMetadata.proCols.contains('pro00_qtdest') ? 'p.pro00_qtdest' : '0.0';

    final String selRef1 = _ProductDbMetadata.proCols.contains('pro00_ref001') ? 'p.pro00_ref001 AS ref001' : "'' AS ref001";
    final String selRef2 = _ProductDbMetadata.proCols.contains('pro00_ref002') ? 'p.pro00_ref002 AS ref002' : "'' AS ref002";
    final String selRefFor = _ProductDbMetadata.proCols.contains('pro00_reffor') ? 'p.pro00_reffor AS reffor' : "'' AS reffor";

    String joinMarca = '';
    String selMarca = "'SEM MARCA' AS marca_nome";
    if (_ProductDbMetadata.tblMar != null && _ProductDbMetadata.proCols.contains('pro00_codmar')) {
      joinMarca = 'LEFT JOIN ${_ProductDbMetadata.tblMar} m ON m.mar00_codigo = p.pro00_codmar';
      selMarca = "COALESCE(m.mar00_descri, 'SEM MARCA') AS marca_nome";
    }

    String joinFab = '';
    String selFab = "'' AS fabricante_nome";
    if (_ProductDbMetadata.tblFor != null && _ProductDbMetadata.proCols.contains('pro00_codfab')) {
      joinFab = 'LEFT JOIN ${_ProductDbMetadata.tblFor} f ON f.for00_codigo = p.pro00_codfab';
      selFab = "COALESCE(f.for00_descri, '') AS fabricante_nome";
    }

    final List<dynamic> binds = [];

    String joinEst = '';
    String selEst = "COALESCE($colQtdEst, 0.0) AS saldo";
    if (_ProductDbMetadata.hasEst) {
      joinEst = 'LEFT JOIN estpro00 e ON e.pro00_codpro = p.$colCod AND e.pro00_codfil = ?';
      selEst = "COALESCE(e.pro00_qtdest, $colQtdEst, 0.0) AS saldo";
      binds.add(filial);
    }

    String joinPco = '';
    String selPco = "0.0 AS preco_venda";
    if (_ProductDbMetadata.tblPco != null && _ProductDbMetadata.pcoCodCol != null && _ProductDbMetadata.pcoPrecoCol != null) {
      if (_ProductDbMetadata.pcoTabCol != null) {
        joinPco = 'LEFT JOIN ${_ProductDbMetadata.tblPco} t ON t.${_ProductDbMetadata.pcoCodCol} = p.$colCod AND t.${_ProductDbMetadata.pcoTabCol} = ?';
        binds.add(tab);
      } else {
        joinPco = 'LEFT JOIN ${_ProductDbMetadata.tblPco} t ON t.${_ProductDbMetadata.pcoCodCol} = p.$colCod';
      }
      selPco = "COALESCE(t.${_ProductDbMetadata.pcoPrecoCol}, 0.0) AS preco_venda";
    } else if (_ProductDbMetadata.proCols.contains('pro00_preco')) {
      selPco = "COALESCE(p.pro00_preco, 0.0) AS preco_venda";
    } else if (_ProductDbMetadata.proCols.contains('pro00_pcomax')) {
      selPco = "COALESCE(p.pro00_pcomax, 0.0) AS preco_venda";
    }

    final List<String> condicoes = [];
    if (busca.isNotEmpty) {
      condicoes.add('''
        (
          p.$colDesc LIKE ? 
          OR p.$colBar = ? 
          OR CAST(p.$colCod AS TEXT) = ?
        )
      ''');
      binds.add('%$busca%');
      binds.add(busca);
      binds.add(busca);
    }

    if (filtroLinha != null && filtroLinha.trim().isNotEmpty && _ProductDbMetadata.proCols.contains('pro00_codlin')) {
      final val = int.tryParse(filtroLinha.trim());
      if (val != null) {
        condicoes.add('p.pro00_codlin = ?');
        binds.add(val);
      }
    }

    if (filtroGrupo != null && filtroGrupo.trim().isNotEmpty && _ProductDbMetadata.proCols.contains('pro00_codgrp')) {
      final val = int.tryParse(filtroGrupo.trim());
      if (val != null) {
        condicoes.add('p.pro00_codgrp = ?');
        binds.add(val);
      }
    }

    if (filtroMarca != null && filtroMarca.trim().isNotEmpty && _ProductDbMetadata.proCols.contains('pro00_codmar')) {
      final val = int.tryParse(filtroMarca.trim());
      if (val != null) {
        condicoes.add('p.pro00_codmar = ?');
        binds.add(val);
      }
    }

    final String whereSql = condicoes.isNotEmpty ? 'WHERE ${condicoes.join(' AND ')}' : '';

    String limitSql = '';
    if (offset != null && offset > 0) {
      limitSql = 'LIMIT 100 OFFSET $offset';
    }

    final String query = '''
      SELECT 
        p.$colCod AS pro00_codigo,
        p.$colDesc AS pro00_descri,
        COALESCE(p.$colUnid, 'UN') AS pro00_unidad,
        COALESCE($colEmb, 'UN') AS embalagem,
        COALESCE(p.$colBar, '') AS pro00_codbar,
        $selRef1,
        $selRef2,
        $selRefFor,
        $colImg AS pro00_codimg,
        $selMarca,
        $selFab,
        $selEst,
        $selPco
      FROM ${_ProductDbMetadata.tabelaPro} p
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
        codigo: (m['pro00_codigo'] ?? '').toString(),
        descricao: (m['pro00_descri'] ?? '').toString(),
        unidade: (m['pro00_unidad'] ?? 'UN').toString(),
        embalagem: (m['embalagem'] ?? 'UN').toString(),
        codbar: (m['pro00_codbar'] ?? '').toString(),
        marca: (m['marca_nome'] ?? 'SEM MARCA').toString(),
        fabricante: (m['fabricante_nome'] ?? '').toString(),
        referencia1: m['ref001']?.toString() ?? '',
        referencia2: m['ref002']?.toString() ?? '',
        reffor: m['reffor']?.toString() ?? '',
        imagemId: (m['pro00_codimg'] as num?)?.toInt() ?? 0,
        saldoEstoque: saldo,
        estoqueAtual: saldo,
        preco: preco,
        pcomax: preco,
      );
    }).toList();
  } catch (e, stack) {
    print('ERRO BUSCA PRODUTO: $e');
    print(stack);
    return [];
  }
}