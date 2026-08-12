// Imports do app
import '/backend/schema/structs/index.dart';
// Imports other custom actions
// Imports custom functions
// Begin custom action code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

// Imports do app
// Imports other custom actions
// Imports custom functions
// Begin custom action code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:io';

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
  String? dataEntrada,
) async {
  try {
    final dbPath = join(await getDatabasesPath(), 'dbforcacad001.db');
    print('DIAGNOSTICO: Caminho do banco: $dbPath');
    final exists = await File(dbPath).exists();
    print('DIAGNOSTICO: O arquivo do banco existe? $exists');

    if (!exists) {
      print(
          'DIAGNOSTICO: ERRO: O arquivo do banco de dados nao existe no caminho esperado.');
      return [];
    }

    final db = await openDatabase(dbPath);

    try {
      final countPro = Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM cadpro00'));
      print('DIAGNOSTICO: Registros em cadpro00 (produtos): $countPro');
      final countEst = Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM estpro00'));
      print('DIAGNOSTICO: Registros em estpro00 (estoque): $countEst');
    } catch (dbErr) {
      print(
          'DIAGNOSTICO: ERRO ao ler tabelas estruturais: $dbErr');
    }

    final String busca = filtro ?? '';
    final int currentOffset = offset ?? 0;
    final String linha = filtroLinha ?? '';
    final String grupo = filtroGrupo ?? '';
    final String fab = filtroFabricante ?? '';
    final String marca = filtroMarca ?? '';
    final bool estoqueOpt = apenasEstoque ?? false;
    final String dataEnt = dataEntrada ?? 'Todas';

    final int filial = (codFilial == null || codFilial == 0) ? 1 : codFilial;

    print(
        'DIAGNOSTICO: Parametros de busca -> busca: "$busca", linha: "$linha", grupo: "$grupo", filial: $filial, dataEntrada: "$dataEnt", promo: $apenasPromocao, estoque: $estoqueOpt');

    List<String> condicoes = [];
    List<dynamic> whereBinds = [];

    if (busca.trim().isNotEmpty) {
      final isNumeric = RegExp(r'^\d+$').hasMatch(busca.trim());
      if (isNumeric) {
        condicoes.add('(p.pro00_codigo = ? OR p.pro00_codbar = ?)');
        whereBinds.addAll([busca.trim(), busca.trim()]);
      } else {
        final termo = '%${busca.toUpperCase()}%';
        condicoes.add('UPPER(p.pro00_descri) LIKE ?');
        whereBinds.add(termo);
      }
    }

    if (linha.isNotEmpty) {
      condicoes.add('p.pro00_codlin = ?');
      whereBinds.add(int.parse(linha));
    }
    if (grupo.isNotEmpty) {
      condicoes.add('p.pro00_codgrp = ?');
      whereBinds.add(int.parse(grupo));
    }
    if (fab.isNotEmpty) {
      condicoes.add('p.pro00_codfab = ?');
      whereBinds.add(int.parse(fab));
    }
    if (marca.isNotEmpty) {
      condicoes.add('p.pro00_codmar = ?');
      whereBinds.add(int.parse(marca));
    }

    if (estoqueOpt) {
      condicoes.add(
          '(COALESCE(e.pro00_qtdest, 0) - COALESCE(e.pro00_qtdpen, 0)) > 0');
    }

    if (dataEnt != 'Todas') {
      DateTime targetDate;
      final now = DateTime.now();
      if (dataEnt == 'Hoje') {
        targetDate = DateTime(now.year, now.month, now.day);
      } else if (dataEnt == 'Ontem') {
        targetDate = DateTime(now.year, now.month, now.day)
            .subtract(const Duration(days: 1));
      } else {
        targetDate = DateTime(now.year, now.month, now.day)
            .subtract(const Duration(days: 7));
      }
      final dateStr =
          "${targetDate.year}-${targetDate.month.toString().padLeft(2, '0')}-${targetDate.day.toString().padLeft(2, '0')}";
      condicoes.add('d.pro00_entdat >= ?');
      whereBinds.add(dateStr);
    }

    if (apenasPromocao ?? false) {
      final dateStr =
          "${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}-${DateTime.now().day.toString().padLeft(2, '0')}";
      condicoes.add('? BETWEEN prm.pro00_prmini AND prm.pro00_prmfim');
      whereBinds.add(dateStr);
    }

    String whereClause =
        condicoes.isNotEmpty ? 'WHERE ${condicoes.join(' AND ')}' : '';

    List<dynamic> finalBinds = [filial, ...whereBinds, currentOffset];

    final String query =
        "SELECT DISTINCT p.pro00_codigo, p.pro00_descri, p.pro00_unidad, "
        "COALESCE(t.pro00_pcosub, 0) AS preco_venda, "
        "COALESCE(e.pro00_qtdest, 0) AS estoque_atual, "
        "COALESCE(e.pro00_qtdpen, 0) AS estoque_pendente, "
        "(COALESCE(e.pro00_qtdest, 0) - COALESCE(e.pro00_qtdpen, 0)) AS saldo "
        "FROM cadpro00 p "
        "LEFT JOIN estpcopro00 t ON t.pro00_codpro = p.pro00_codigo "
        "LEFT JOIN estpro00 e ON e.pro00_codpro = p.pro00_codigo AND e.pro00_codfil = ? "
        "LEFT JOIN estprodat00 d ON d.pro00_codpro = p.pro00_codigo "
        "LEFT JOIN estprmreg00 prm ON prm.pro00_codpro = p.pro00_codigo "
        " $whereClause "
        "ORDER BY p.pro00_descri "
        "LIMIT 500 OFFSET ?";

    print('DIAGNOSTICO: Executando query com binds: $finalBinds');
    final results = await db.rawQuery(query, finalBinds);
    print('DIAGNOSTICO: Query executada. Resultados encontrados: ${results.length}');
    await db.close();

    double parseDouble(dynamic val) {
      if (val == null) return 0.0;
      if (val is num) return val.toDouble();
      return double.tryParse(val.toString()) ?? 0.0;
    }

    return results
        .map((m) => ProdutoResultStruct(
              codigo: m['pro00_codigo']?.toString() ?? '',
              descricao: m['pro00_descri']?.toString() ?? '',
              unidade: m['pro00_unidad']?.toString() ?? '',
              preco: parseDouble(m['preco_venda']),
              saldoEstoque: parseDouble(m['saldo']),
              estoqueAtual: parseDouble(m['estoque_atual']),
              estoquePendente: parseDouble(m['estoque_pendente']),
            ))
        .toList();
  } catch (e) {
    print('DIAGNOSTICO: Erro fatal na busca do SQLite: $e');
    return [];
  }
}
