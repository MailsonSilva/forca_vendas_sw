import '/backend/schema/structs/lista_padrao_struct.dart';
import '../domain/models/agente_cobrador.dart';
import '../data/services/local_sales_database_service.dart';

// PRD 1 §2 & PRD Funcional — codage00 definitivo, cadagt00, cadage00, cadcob00 fallback compat.
Future<List<ListaPadraoStruct>> carregarAgentesCobrador() async {
  try {
    final db = await LocalSalesDatabaseService.getDatabase();

    // 1. Busca todas as tabelas candidatas de agentes no SQLite
    final candidateTables = [
      'codage00',
      'cadagt00',
      'cadage00',
      'cadcob00',
      'codcob00',
      'cadcob000',
      'cadage000',
      'cadagt000',
      'codage000',
      'age00',
      'agt00',
    ];

    String? tabelaEncontrada;
    for (final cand in candidateTables) {
      final t = await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND lower(name)=?",
          [cand.toLowerCase()]);
      if (t.isNotEmpty) {
        tabelaEncontrada = t.first['name']?.toString() ?? cand;
        break;
      }
    }

    // Se nenhuma tabela candidata direta for encontrada, busca por similaridade
    if (tabelaEncontrada == null) {
      final allTables = await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND (lower(name) LIKE '%age%' OR lower(name) LIKE '%agt%' OR lower(name) LIKE '%cob%')");
      if (allTables.isNotEmpty) {
        tabelaEncontrada = allTables.first['name']?.toString();
      }
    }

    if (tabelaEncontrada == null) {
      return [];
    }

    final cols = await db.rawQuery('PRAGMA table_info($tabelaEncontrada)');
    final colNames = cols.map((r) => r['name']?.toString().toLowerCase()).toSet();

    String? codCol;
    String? descCol;

    for (final c in [
      'age00_codigo',
      'agt00_codigo',
      'agt00_codage',
      'agt00_codagt',
      'age00_cod',
      'agt00_cod',
      'cob00_codigo',
      'cob00_codcob',
      'cob00_cod',
      'cad00_codigo',
      'codigo',
      'cod'
    ]) {
      if (colNames.contains(c.toLowerCase())) {
        codCol = cols.firstWhere((r) => r['name'].toString().toLowerCase() == c.toLowerCase())['name'].toString();
        break;
      }
    }

    for (final c in [
      'age00_descri',
      'agt00_descri',
      'agt00_descricao',
      'agt00_nome',
      'age00_descricao',
      'age00_nome',
      'cob00_descri',
      'cob00_descricao',
      'cob00_nome',
      'descricao',
      'descri',
      'nome'
    ]) {
      if (colNames.contains(c.toLowerCase())) {
        descCol = cols.firstWhere((r) => r['name'].toString().toLowerCase() == c.toLowerCase())['name'].toString();
        break;
      }
    }

    if (codCol == null || descCol == null) {
      if (cols.length >= 2) {
        codCol ??= cols[0]['name'].toString();
        descCol ??= cols[1]['name'].toString();
      } else {
        return [];
      }
    }

    final rows = await db.rawQuery(
        'SELECT $codCol as codigo, $descCol as descricao FROM $tabelaEncontrada ORDER BY $descCol');

    return rows.map((r) {
      return ListaPadraoStruct(
        codigo: r['codigo']?.toString().trim() ?? '',
        descricao: r['descricao']?.toString().trim() ?? '',
      );
    }).toList();
  } catch (e) {
    print('Erro ao carregar agentes cobrador: $e');
    return [];
  }
}

/// Carrega lista tipada com `tipo` (age00_tipo / agt00_tipo) para gravar dig00_digcob.
Future<List<AgenteCobrador>> carregarAgentesCobradoresTipados() async {
  try {
    final db = await LocalSalesDatabaseService.getDatabase();

    final candidateTables = [
      'codage00',
      'cadagt00',
      'cadage00',
      'cadcob00',
      'codcob00',
      'cadcob000',
      'cadage000',
      'cadagt000',
      'codage000',
      'age00',
      'agt00',
    ];

    String? tabelaEncontrada;
    for (final cand in candidateTables) {
      final t = await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND lower(name)=?",
          [cand.toLowerCase()]);
      if (t.isNotEmpty) {
        tabelaEncontrada = t.first['name']?.toString() ?? cand;
        break;
      }
    }

    if (tabelaEncontrada == null) {
      final allTables = await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND (lower(name) LIKE '%age%' OR lower(name) LIKE '%agt%' OR lower(name) LIKE '%cob%')");
      if (allTables.isNotEmpty) {
        tabelaEncontrada = allTables.first['name']?.toString();
      }
    }

    if (tabelaEncontrada == null) {
      return [];
    }

    final rows = await db.rawQuery('SELECT * FROM $tabelaEncontrada ORDER BY 2');
    return rows.map((m) => AgenteCobrador.fromMap(m)).toList();
  } catch (e) {
    print('Erro ao carregar agentes tipados: $e');
    return [];
  }
}

