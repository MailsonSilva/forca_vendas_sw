import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '/backend/schema/structs/index.dart';

Database? _dbClienteInstancia;

Future<Database> _getDbCliente() async {
  if (_dbClienteInstancia != null && _dbClienteInstancia!.isOpen) {
    return _dbClienteInstancia!;
  }
  final dbPath = join(await getDatabasesPath(), 'dbforcacad001.db');
  _dbClienteInstancia = await openDatabase(dbPath);
  return _dbClienteInstancia!;
}

Future<List<ClienteResultStruct>> pesquisaCliente(
  String? termo, [
  int? offset,
]) async {
  try {
    final db = await _getDbCliente();
    final String busca = (termo ?? '').trim();
    final String buscaLimpa = busca.replaceAll(RegExp(r'\D'), '');

    // Verificação de colunas em cadcli00 para retrocompatibilidade
    final pragma = await db.rawQuery('PRAGMA table_info(cadcli00)');
    final cols = pragma.map((e) => e['name']?.toString().toLowerCase() ?? '').toSet();

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
        'CAST(c.cli00_codigo AS TEXT) = ?',
      ];
      binds.add('%$busca%');
      binds.add(busca);

      if (cols.contains('cli00_fantas')) {
        orClauses.add('c.cli00_fantas LIKE ?');
        binds.add('%$busca%');
      }

      if (cols.contains('cli00_cpfcnp')) {
        if (buscaLimpa.isNotEmpty) {
          orClauses.add('c.cli00_cpfcnp LIKE ?');
          binds.add('$buscaLimpa%');
        } else {
          orClauses.add('c.cli00_cpfcnp LIKE ?');
          binds.add('$busca%');
        }
      }

      whereSql = 'WHERE (${orClauses.join(' OR ')})';
    }

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
        $selActive
      FROM cadcli00 c
      $whereSql
      ORDER BY c.cli00_descri ASC;
    ''';

    final rows = await db.rawQuery(sql, binds);

    return rows.map((m) {
      final int active = (m['cli00_active'] == 1 || m['cli00_active'] == true || m['cli00_active'] == null) ? 1 : 0;
      final double titven = (m['cli00_titven'] as num?)?.toDouble() ?? 0.0;
      final Color corBorda = active == 0
          ? const Color(0xFFD32F2F)
          : (titven > 0 ? const Color(0xFFFFD700) : const Color(0xFF10B981));

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
        success: true,
      );
    }).toList();
  } catch (e) {
    debugPrint('ERRO PESQUISA CLIENTE: $e');
    return [];
  }
}
