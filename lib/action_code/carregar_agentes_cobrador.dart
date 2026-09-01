import '/backend/schema/structs/lista_padrao_struct.dart';
import '../domain/models/agente_cobrador.dart';
import '../data/services/local_sales_database_service.dart';

/// PRD Seção 2.4 — Carrega cobradores com filtragem estrita:
/// Intersecção entre Agentes Homologados do Cliente (cadcliage00) e Permitidos para o Plano (cadprz02)
Future<List<ListaPadraoStruct>> carregarAgentesCobrador({
  int? clienteCodigo,
  int? planoCodigo,
}) async {
  try {
    final db = await LocalSalesDatabaseService.getDatabase();

    // 1. Busca todas as tabelas candidatas de agentes no SQLite
    final candidateTables = [
      'cadage00',
      'codage00',
      'cadagt00',
      'cadcob00',
      'codcob00',
      'cadcob000',
      'cadage000',
      'cadagt000',
      'codage000',
      'age00',
      'agt00',
    ];

    final tTables = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table'");
    final tableNames = tTables.map((r) => r['name']?.toString().toLowerCase() ?? '').toSet();

    String? tabelaEncontrada;
    for (final cand in candidateTables) {
      if (tableNames.contains(cand.toLowerCase())) {
        tabelaEncontrada = cand;
        break;
      }
    }

    if (tabelaEncontrada == null) {
      for (final t in tableNames) {
        if (t.contains('age') || t.contains('agt') || t.contains('cob')) {
          tabelaEncontrada = t;
          break;
        }
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

    final bool hasCadcliage00 = tableNames.contains('cadcliage00');
    final bool hasCadprz02 = tableNames.contains('cadprz02');

    bool clienteTemRestricao = false;
    if (hasCadcliage00 && clienteCodigo != null && clienteCodigo > 0) {
      try {
        final r = await db.rawQuery('SELECT 1 FROM cadcliage00 WHERE age00_codcli = ? LIMIT 1', [clienteCodigo]);
        clienteTemRestricao = r.isNotEmpty;
      } catch (_) {}
    }

    bool planoTemRestricao = false;
    if (hasCadprz02 && planoCodigo != null && planoCodigo > 0) {
      try {
        final r = await db.rawQuery('SELECT 1 FROM cadprz02 WHERE prz02_codprz = ? LIMIT 1', [planoCodigo]);
        planoTemRestricao = r.isNotEmpty;
      } catch (_) {}
    }

    List<Map<String, dynamic>> rows = [];

    // 2. Aplicação da Regra de Intersecção Tripla (Seção 2.4)
    if (clienteTemRestricao && planoTemRestricao) {
      try {
        rows = await db.rawQuery('''
          SELECT DISTINCT a.$codCol as codigo, a.$descCol as descricao 
          FROM $tabelaEncontrada a
          INNER JOIN cadcliage00 ca ON (ca.age00_codage = a.$codCol OR ca.age00_codage = CAST(a.$codCol AS INTEGER))
          INNER JOIN cadprz02 cp ON (cp.prz02_codagt = a.$codCol OR cp.prz02_codagt = CAST(a.$codCol AS INTEGER))
          WHERE ca.age00_codcli = ? AND cp.prz02_codprz = ?
          ORDER BY a.$descCol
        ''', [clienteCodigo, planoCodigo]);
      } catch (e) {
        print('Erro na consulta tripla de cobradores: $e');
      }
    } else if (clienteTemRestricao) {
      try {
        rows = await db.rawQuery('''
          SELECT DISTINCT a.$codCol as codigo, a.$descCol as descricao 
          FROM $tabelaEncontrada a
          INNER JOIN cadcliage00 ca ON (ca.age00_codage = a.$codCol OR ca.age00_codage = CAST(a.$codCol AS INTEGER))
          WHERE ca.age00_codcli = ?
          ORDER BY a.$descCol
        ''', [clienteCodigo]);
      } catch (e) {
        print('Erro na consulta de cobradores por cliente: $e');
      }
    } else if (planoTemRestricao) {
      try {
        rows = await db.rawQuery('''
          SELECT DISTINCT a.$codCol as codigo, a.$descCol as descricao 
          FROM $tabelaEncontrada a
          INNER JOIN cadprz02 cp ON (cp.prz02_codagt = a.$codCol OR cp.prz02_codagt = CAST(a.$codCol AS INTEGER))
          WHERE cp.prz02_codprz = ?
          ORDER BY a.$descCol
        ''', [planoCodigo]);
      } catch (e) {
        print('Erro na consulta de cobradores por plano: $e');
      }
    }

    // 3. Fallback seguro se não houver amarrações restritivas cadastradas
    if (rows.isEmpty) {
      rows = await db.rawQuery(
          'SELECT $codCol as codigo, $descCol as descricao FROM $tabelaEncontrada ORDER BY $descCol');
    }

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
Future<List<AgenteCobrador>> carregarAgentesCobradoresTipados({
  int? clienteCodigo,
  int? planoCodigo,
}) async {
  try {
    final db = await LocalSalesDatabaseService.getDatabase();

    final candidateTables = [
      'cadage00',
      'codage00',
      'cadagt00',
      'cadcob00',
      'codcob00',
      'cadcob000',
      'cadage000',
      'cadagt000',
      'codage000',
      'age00',
      'agt00',
    ];

    final tTables = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table'");
    final tableNames = tTables.map((r) => r['name']?.toString().toLowerCase() ?? '').toSet();

    String? tabelaEncontrada;
    for (final cand in candidateTables) {
      if (tableNames.contains(cand.toLowerCase())) {
        tabelaEncontrada = cand;
        break;
      }
    }

    if (tabelaEncontrada == null) {
      for (final t in tableNames) {
        if (t.contains('age') || t.contains('agt') || t.contains('cob')) {
          tabelaEncontrada = t;
          break;
        }
      }
    }

    if (tabelaEncontrada == null) {
      return [];
    }

    final cols = await db.rawQuery('PRAGMA table_info($tabelaEncontrada)');
    final colNames = cols.map((r) => r['name']?.toString().toLowerCase()).toSet();

    String codCol = 'age00_codigo';
    for (final c in ['age00_codigo', 'agt00_codigo', 'agt00_codage', 'agt00_codagt', 'cob00_codigo', 'codigo']) {
      if (colNames.contains(c)) {
        codCol = c;
        break;
      }
    }

    final bool hasCadcliage00 = tableNames.contains('cadcliage00');
    final bool hasCadprz02 = tableNames.contains('cadprz02');

    bool clienteTemRestricao = false;
    if (hasCadcliage00 && clienteCodigo != null && clienteCodigo > 0) {
      try {
        final r = await db.rawQuery('SELECT 1 FROM cadcliage00 WHERE age00_codcli = ? LIMIT 1', [clienteCodigo]);
        clienteTemRestricao = r.isNotEmpty;
      } catch (_) {}
    }

    bool planoTemRestricao = false;
    if (hasCadprz02 && planoCodigo != null && planoCodigo > 0) {
      try {
        final r = await db.rawQuery('SELECT 1 FROM cadprz02 WHERE prz02_codprz = ? LIMIT 1', [planoCodigo]);
        planoTemRestricao = r.isNotEmpty;
      } catch (_) {}
    }

    List<Map<String, dynamic>> rows = [];

    if (clienteTemRestricao && planoTemRestricao) {
      try {
        rows = await db.rawQuery('''
          SELECT DISTINCT a.* 
          FROM $tabelaEncontrada a
          INNER JOIN cadcliage00 ca ON (ca.age00_codage = a.$codCol OR ca.age00_codage = CAST(a.$codCol AS INTEGER))
          INNER JOIN cadprz02 cp ON (cp.prz02_codagt = a.$codCol OR cp.prz02_codagt = CAST(a.$codCol AS INTEGER))
          WHERE ca.age00_codcli = ? AND cp.prz02_codprz = ?
          ORDER BY 2
        ''', [clienteCodigo, planoCodigo]);
      } catch (_) {}
    } else if (clienteTemRestricao) {
      try {
        rows = await db.rawQuery('''
          SELECT DISTINCT a.* 
          FROM $tabelaEncontrada a
          INNER JOIN cadcliage00 ca ON (ca.age00_codage = a.$codCol OR ca.age00_codage = CAST(a.$codCol AS INTEGER))
          WHERE ca.age00_codcli = ?
          ORDER BY 2
        ''', [clienteCodigo]);
      } catch (_) {}
    } else if (planoTemRestricao) {
      try {
        rows = await db.rawQuery('''
          SELECT DISTINCT a.* 
          FROM $tabelaEncontrada a
          INNER JOIN cadprz02 cp ON (cp.prz02_codagt = a.$codCol OR cp.prz02_codagt = CAST(a.$codCol AS INTEGER))
          WHERE cp.prz02_codprz = ?
          ORDER BY 2
        ''', [planoCodigo]);
      } catch (_) {}
    }

    if (rows.isEmpty) {
      rows = await db.rawQuery('SELECT * FROM $tabelaEncontrada ORDER BY 2');
    }

    return rows.map((m) => AgenteCobrador.fromMap(m)).toList();
  } catch (e) {
    print('Erro ao carregar agentes tipados: $e');
    return [];
  }
}
