import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import '/backend/schema/structs/index.dart';
import '/data/repositories/produto_repository.dart';
import '/data/services/local_sales_database_service.dart';

Database? _dbProdutoInstancia;

/// Cache em memória dos metadados de tabelas e colunas mantido para retrocompatibilidade.
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
  static String? pcoClsCol;
  static String? tblMar;
  static String? tblFor;

  static void reset() {
    loaded = false;
    _dbProdutoInstancia = null;
    tabelaPro = 'cadpro00';
    proCols = {};
    hasEst = false;
    hasQtdpen = false;
    tblPco = null;
    pcoCodCol = null;
    pcoTabCol = null;
    pcoPrecoCol = null;
    pcoClsCol = null;
    tblMar = null;
    tblFor = null;
  }
}

Future<Database> _getDbProduto() async {
  if (_dbProdutoInstancia != null && _dbProdutoInstancia!.isOpen) {
    return _dbProdutoInstancia!;
  }
  _dbProdutoInstancia = await LocalSalesDatabaseService.getDatabase();
  return _dbProdutoInstancia!;
}

/// Busca de produtos rápida e otimizada com precificação via estpcoreg00/estpcoregpco00
/// e filial dinâmica selecionada.
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
  int? limit = 30,
  int? codPlano,
]) async {
  try {
    final db = await _getDbProduto();
    final repo = ProdutoRepository(db: db);
    return await repo.buscaProduto(
      filtro: filtro,
      ultimoDescri: ultimoDescri,
      filtroLinha: filtroLinha,
      filtroGrupo: filtroGrupo,
      filtroFabricante: filtroFabricante,
      filtroMarca: filtroMarca,
      apenasEstoque: apenasEstoque,
      apenasPromocao: apenasPromocao,
      codFilial: codFilial,
      dataEntrada: dataEntrada,
      codTabela: codTabela,
      offset: offset,
      limit: (limit != null && limit > 0) ? limit : 30,
      codPlano: codPlano,
    );
  } catch (e, stack) {
    debugPrint('ERRO BUSCA PRODUTO: $e');
    debugPrint(stack.toString());
    return [];
  }
}
