import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import '/backend/schema/structs/index.dart';
import '../data/services/local_sales_database_service.dart';

Future<Database> _getDbCliente() async {
  return LocalSalesDatabaseService.getDatabase();
}

/// Cache em memória dos metadados de colunas de clientes para evitar PRAGMAs repetidos
class ClienteDbMetadata {
  static Set<String>? colsCadcli;
  static bool? hasCadclipre;

  static void reset() {
    colsCadcli = null;
    hasCadclipre = null;
  }
}

Future<List<ClienteResultStruct>> pesquisaCliente(
  String? termo, [
  int? offset,
  int? limit,
]) async {
  try {
    final db = await _getDbCliente();
    final String busca = (termo ?? '').trim();
    final String buscaLimpa = busca.replaceAll(RegExp(r'\D'), '');

    final int pageLimit = (limit != null && limit > 0) ? limit : 100;
    final int pageOffset = (offset != null && offset >= 0) ? offset : 0;

    // 1. Verificação dinâmica de colunas em cadcli00
    Set<String> cols = {};
    try {
      final pragma = await db.rawQuery('PRAGMA table_info(cadcli00)');
      cols = pragma.map((e) => e['name']?.toString().toLowerCase() ?? '').toSet();
    } catch (_) {
      cols = {};
    }

    final String selFantas = cols.contains('cli00_fantas')
        ? "COALESCE(c.cli00_fantas, c.cli00_descri) AS cli00_fantas"
        : "c.cli00_descri AS cli00_fantas";
    final String selCpf = cols.contains('cli00_cpfcnp')
        ? "COALESCE(c.cli00_cpfcnp, '') AS cli00_cpfcnp"
        : "'' AS cli00_cpfcnp";
    final String selEndere = cols.contains('cli00_endere')
        ? "COALESCE(c.cli00_endere, '') AS cli00_endere"
        : "'' AS cli00_endere";
    final String selCiddes = cols.contains('cli00_ciddes')
        ? "COALESCE(c.cli00_ciddes, '') AS cli00_ciddes"
        : "'' AS cli00_ciddes";
    final String selEstsgl = cols.contains('cli00_estsgl')
        ? "COALESCE(c.cli00_estsgl, '') AS cli00_estsgl"
        : "'' AS cli00_estsgl";
    final String selFonddd = cols.contains('cli00_fonddd')
        ? "COALESCE(c.cli00_fonddd, '') AS cli00_fonddd"
        : "'' AS cli00_fonddd";
    final String selFonnum = cols.contains('cli00_fonnum')
        ? "COALESCE(c.cli00_fonnum, '') AS cli00_fonnum"
        : "'' AS cli00_fonnum";
    final String selCrelim = cols.contains('cli00_crelim')
        ? "COALESCE(c.cli00_crelim, 0.0) AS cli00_crelim"
        : "0.0 AS cli00_crelim";
    final String selCreatu = cols.contains('cli00_creatu')
        ? "COALESCE(c.cli00_creatu, 0.0) AS cli00_creatu"
        : "0.0 AS cli00_creatu";
    final String selTitven = cols.contains('cli00_titven')
        ? "COALESCE(c.cli00_titven, 0.0) AS cli00_titven"
        : "0.0 AS cli00_titven";
    final String selActive = cols.contains('cli00_active')
        ? "COALESCE(c.cli00_active, 1) AS cli00_active"
        : "1 AS cli00_active";

    String whereSql = '';
    final List<dynamic> binds = [];

    if (busca.isNotEmpty) {
      final List<String> orClauses = [
        'c.cli00_descri LIKE ?',
        'CAST(c.cli00_codigo AS TEXT) LIKE ?',
      ];
      binds.add('%$busca%');
      binds.add('%$busca%');

      final intCodigo = int.tryParse(busca);
      if (intCodigo != null) {
        orClauses.add('c.cli00_codigo = ?');
        binds.add(intCodigo);
        orClauses.add('CAST(c.cli00_codigo AS INTEGER) = ?');
        binds.add(intCodigo);
      }

      if (cols.contains('cli00_codigo16')) {
        orClauses.add('c.cli00_codigo16 LIKE ?');
        binds.add('%$busca%');
      }

      if (cols.contains('cli00_fantas')) {
        orClauses.add('c.cli00_fantas LIKE ?');
        binds.add('%$busca%');
      }

      final tokens = busca.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
      if (tokens.length > 1) {
        final tokenAnds = <String>[];
        for (final token in tokens) {
          final tokenOrs = <String>['c.cli00_descri LIKE ?'];
          binds.add('%$token%');
          if (cols.contains('cli00_fantas')) {
            tokenOrs.add('c.cli00_fantas LIKE ?');
            binds.add('%$token%');
          }
          tokenAnds.add('(${tokenOrs.join(' OR ')})');
        }
        orClauses.add('(${tokenAnds.join(' AND ')})');
      }

      if (cols.contains('cli00_cpfcnp')) {
        final bool isApenasDocumento = RegExp(r'^[0-9\.\-\/]+$').hasMatch(busca);
        if (isApenasDocumento && buscaLimpa.isNotEmpty) {
          orClauses.add("REPLACE(REPLACE(REPLACE(c.cli00_cpfcnp, '.', ''), '-', ''), '/', '') LIKE ?");
          binds.add('$buscaLimpa%');
        } else {
          orClauses.add('c.cli00_cpfcnp LIKE ?');
          binds.add('%$busca%');
        }
      }

      whereSql = 'WHERE (${orClauses.join(' OR ')})';
    }

    // 2. Query paginada com LIMIT e OFFSET para resposta instantânea
    final sql = '''
      SELECT 
        c.cli00_codigo,
        c.cli00_descri,
        $selFantas,
        $selCpf,
        $selEndere,
        $selCiddes,
        $selEstsgl,
        $selFonddd,
        $selFonnum,
        $selCrelim,
        $selCreatu,
        $selTitven,
        $selActive,
        0 AS is_novo_local
      FROM cadcli00 c
      $whereSql
      ORDER BY c.cli00_descri ASC
      LIMIT ? OFFSET ?;
    ''';

    final args = [...binds, pageLimit, pageOffset];
    final rows = await db.rawQuery(sql, args);
    final List<Map<String, dynamic>> combinedRows = List.from(rows);

    // 3. Clientes locais em cadclipre00 (apenas na primeira página para priorizar novos locais)
    if (pageOffset == 0) {
      try {
        final preCheck = await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND name='cadclipre00'",
        );
        final bool hasPre = preCheck.isNotEmpty;

        if (hasPre) {
          String wherePre = '';
          final List<dynamic> bindsPre = [];
          if (busca.isNotEmpty) {
            final List<String> orClauses = [
              'cli00_descri LIKE ?',
              'CAST(cli00_codigo AS TEXT) LIKE ?',
              'cli00_fantas LIKE ?',
            ];
            bindsPre.add('%$busca%');
            bindsPre.add('%$busca%');
            bindsPre.add('%$busca%');

            final intCod = int.tryParse(busca);
            if (intCod != null) {
              orClauses.add('cli00_codigo = ?');
              bindsPre.add(intCod);
            }

            final bool isApenasDoc = RegExp(r'^[0-9\.\-\/]+$').hasMatch(busca);
            if (isApenasDoc && buscaLimpa.isNotEmpty) {
              orClauses.add("REPLACE(REPLACE(REPLACE(cli00_cpfcnp, '.', ''), '-', ''), '/', '') LIKE ?");
              bindsPre.add('$buscaLimpa%');
            } else {
              orClauses.add('cli00_cpfcnp LIKE ?');
              bindsPre.add('%$busca%');
            }
            wherePre = 'WHERE (${orClauses.join(' OR ')})';
          }
          final preRows = await db.rawQuery('''
            SELECT 
              cli00_codigo,
              cli00_descri,
              cli00_fantas,
              cli00_cpfcnp,
              cli00_endere,
              cli00_ciddes,
              cli00_estsgl,
              cli00_fonddd,
              cli00_fonnum,
              cli00_crelim,
              cli00_creatu,
              cli00_titven,
              cli00_active,
              1 AS is_novo_local
            FROM cadclipre00
            $wherePre
            ORDER BY cli00_descri ASC
            LIMIT 50
          ''', bindsPre);
          combinedRows.addAll(preRows);
        }
      } catch (_) {}
    }

    combinedRows.sort((a, b) =>
        (a['cli00_descri']?.toString() ?? '')
            .compareTo(b['cli00_descri']?.toString() ?? ''));

    return combinedRows.map((m) {
      final int active = (m['cli00_active'] == 1 || m['cli00_active'] == true || m['cli00_active'] == null) ? 1 : 0;
      final double titven = (m['cli00_titven'] as num?)?.toDouble() ?? 0.0;
      final Color corBorda = active == 0
          ? const Color(0xFFD32F2F)
          : (titven > 0 ? const Color(0xFFFFD700) : const Color(0xFF10B981));
      final bool isNovo = (m['is_novo_local'] == 1 || m['is_novo_local'] == true);

      return ClienteResultStruct(
        cli00Codigo: (m['cli00_codigo'] as num?)?.toInt() ?? int.tryParse(m['cli00_codigo']?.toString() ?? '0') ?? 0,
        cli00Descri: (m['cli00_descri'] ?? '').toString(),
        cli00Fantas: (m['cli00_fantas'] ?? '').toString(),
        cli00Cpfcnp: (m['cli00_cpfcnp'] ?? '').toString(),
        cli00Endere: (m['cli00_endere'] ?? '').toString(),
        cli00Ciddes: (m['cli00_ciddes'] ?? '').toString(),
        cli00Estsgl: (m['cli00_estsgl'] ?? '').toString(),
        cli00Fonddd: (m['cli00_fonddd'] ?? '').toString(),
        cli00Fonnum: '${m['cli00_fonddd'] ?? ''}${m['cli00_fonnum'] ?? ''}',
        cli00Crelim: (m['cli00_crelim'] as num?)?.toDouble() ?? 0.0,
        cli00Creatu: (m['cli00_creatu'] as num?)?.toDouble() ?? 0.0,
        cli00Titven: titven,
        cli00Active: active,
        corBorda: corBorda,
        isNovoCliente: isNovo,
        success: true,
      );
    }).toList();
  } catch (e) {
    debugPrint('ERRO PESQUISA CLIENTE: $e');
    return [];
  }
}
