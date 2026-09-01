import '/backend/schema/structs/index.dart';
import '../data/services/local_sales_database_service.dart';

class DadosPedidoNovoResult {
  final List<ClienteResultStruct> clientes;
  final List<ListaPadraoStruct> linhas;
  final List<ListaPadraoStruct> planos;

  DadosPedidoNovoResult({
    required this.clientes,
    required this.linhas,
    required this.planos,
  });
}

/// Carrega clientes, linhas e planos (filtrados por cliente se fornecido).
Future<DadosPedidoNovoResult> obterDadosPedidoNovo({int? clienteCodigo}) async {
  List<ClienteResultStruct> clientes = [];
  List<ListaPadraoStruct> linhas = [];
  List<ListaPadraoStruct> planos = [];

  try {
    final db = await LocalSalesDatabaseService.getDatabase();

    // 1. Clientes
    try {
      final List<Map<String, dynamic>> resClientes = await db.rawQuery('''
        SELECT 
          cli00_codigo, 
          cli00_descri, 
          cli00_fantas, 
          cli00_ciddes, 
          cli00_cpfcnp, 
          cli00_crelim 
        FROM cadcli00 
        WHERE cli00_active in (0,1) 
        ORDER BY cli00_descri
      ''');
      clientes = resClientes.map((m) {
        return ClienteResultStruct(
          cli00Codigo: m['cli00_codigo'] as int?,
          cli00Descri: m['cli00_descri']?.toString() ?? '',
          cli00Fantas: m['cli00_fantas']?.toString() ?? '',
          cli00Ciddes: m['cli00_ciddes']?.toString() ?? '',
          cli00Cpfcnp: m['cli00_cpfcnp']?.toString() ?? '',
          cli00Crelim: (m['cli00_crelim'] as num?)?.toDouble() ?? 0.0,
          success: true,
        );
      }).toList();
    } catch (e) {
      print('Erro ao carregar clientes do SQLite: $e');
    }

    // 2. Linhas
    try {
      final List<Map<String, dynamic>> resLinhas = await db.rawQuery('''
        SELECT lin00_codigo, lin00_descri FROM cadlin00 ORDER BY lin00_descri
      ''');
      linhas = resLinhas.map((m) {
        return ListaPadraoStruct(
          codigo: m['lin00_codigo']?.toString() ?? '',
          descricao: m['lin00_descri']?.toString() ?? '',
        );
      }).toList();
    } catch (e) {
      print('Erro ao carregar linhas do SQLite: $e');
    }

    // 3. Planos de Pagamento (com filtragem relacional se clienteCodigo != null)
    planos = await carregarPlanosDisponiveisCliente(clienteCodigo: clienteCodigo);
  } catch (e) {
    print('Erro geral no SQLite ao obter dados de novo pedido: $e');
  }

  return DadosPedidoNovoResult(
    clientes: clientes,
    linhas: linhas,
    planos: planos,
  );
}

/// PRD Seção 2 — Consulta relacional cruzada de planos de pagamento por cliente:
/// cadpla00 cruzando com cadcli00, cadcliage00, cadprz00 e cadprz02
Future<List<ListaPadraoStruct>> carregarPlanosDisponiveisCliente({int? clienteCodigo}) async {
  try {
    final db = await LocalSalesDatabaseService.getDatabase();

    // 1. Verifica existência de tabelas no SQLite
    final tTables = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table'");
    final tableNames = tTables.map((r) => r['name']?.toString().toLowerCase() ?? '').toSet();

    if (!tableNames.contains('cadpla00')) {
      return [];
    }

    final bool hasCadprz00 = tableNames.contains('cadprz00');
    final bool hasCadcliage00 = tableNames.contains('cadcliage00');
    final bool hasCadprz02 = tableNames.contains('cadprz02');

    // 2. Coleta dados de classificação do cliente se fornecido
    int codcls = 0;
    int codscl = 0;
    int codmod = 0;
    int codreg = 0;
    int codtyp = 0;
    bool clientePossuiVinculoAgente = false;

    if (clienteCodigo != null && clienteCodigo > 0) {
      try {
        final colsCli = await db.rawQuery('PRAGMA table_info(cadcli00)');
        final cliColNames = colsCli.map((r) => r['name']?.toString().toLowerCase() ?? '').toSet();

        final cliRows = await db.rawQuery('SELECT * FROM cadcli00 WHERE cli00_codigo = ? LIMIT 1', [clienteCodigo]);
        if (cliRows.isNotEmpty) {
          final c = cliRows.first;
          if (cliColNames.contains('cli00_codcls')) codcls = _parseInt(c['cli00_codcls']);
          if (cliColNames.contains('cli00_codscl')) codscl = _parseInt(c['cli00_codscl']);
          if (cliColNames.contains('cli00_codmod')) codmod = _parseInt(c['cli00_codmod']);
          if (cliColNames.contains('cli00_codreg')) codreg = _parseInt(c['cli00_codreg']);
          if (cliColNames.contains('cli00_codtyp')) codtyp = _parseInt(c['cli00_codtyp']);
        }
      } catch (_) {}

      if (hasCadcliage00) {
        try {
          final agtRows = await db.rawQuery('SELECT 1 FROM cadcliage00 WHERE age00_codcli = ? LIMIT 1', [clienteCodigo]);
          clientePossuiVinculoAgente = agtRows.isNotEmpty;
        } catch (_) {}
      }
    }

    // 3. Monta colunas e JOINs
    final colsPla = await db.rawQuery('PRAGMA table_info(cadpla00)');
    final plaColNames = colsPla.map((r) => r['name']?.toString().toLowerCase() ?? '').toSet();

    final String selVlrMin = plaColNames.contains('pla00_vlrmin') ? 'COALESCE(pl.pla00_vlrmin, 0)' : '0';
    final String orderBy = plaColNames.contains('pla00_codseq') ? 'pl.pla00_codseq, pl.pla00_descri' : 'pl.pla00_descri';

    String joinPrz00 = '';
    if (hasCadprz00) {
      joinPrz00 = '''
        LEFT JOIN cadprz00 p0 ON p0.prz00_codprz = pl.pla00_codigo
      ''';
    }

    // 4. Cláusulas WHERE
    List<String> whereClauses = [];
    List<dynamic> binds = [];

    if (clienteCodigo != null && clienteCodigo > 0) {
      // Filtragem por classificação regional se houver no cadastro de planos
      if (codcls > 0 && plaColNames.contains('pla00_codcls')) {
        whereClauses.add('(pl.pla00_codcls = ? OR pl.pla00_codcls IS NULL OR pl.pla00_codcls = 0)');
        binds.add(codcls);
      }
      if (codscl > 0 && plaColNames.contains('pla00_codscl')) {
        whereClauses.add('(pl.pla00_codscl = ? OR pl.pla00_codscl IS NULL OR pl.pla00_codscl = 0)');
        binds.add(codscl);
      }
      if (codmod > 0 && plaColNames.contains('pla00_codmod')) {
        whereClauses.add('(pl.pla00_codmod = ? OR pl.pla00_codmod IS NULL OR pl.pla00_codmod = 0)');
        binds.add(codmod);
      }
      if (codreg > 0 && plaColNames.contains('pla00_codreg')) {
        whereClauses.add('(pl.pla00_codreg = ? OR pl.pla00_codreg IS NULL OR pl.pla00_codreg = 0)');
        binds.add(codreg);
      }
      if (codtyp > 0 && plaColNames.contains('pla00_codtyp')) {
        whereClauses.add('(pl.pla00_codtyp = ? OR pl.pla00_codtyp IS NULL OR pl.pla00_codtyp = 0)');
        binds.add(codtyp);
      }

      // Camada 2: Autorização Financeira via Cliente (EXISTS cadcliage00 x cadprz02)
      if (hasCadcliage00 && hasCadprz02 && clientePossuiVinculoAgente) {
        whereClauses.add('''
          EXISTS (
            SELECT 1 FROM cadcliage00 sel
            INNER JOIN cadprz02 age ON age.prz02_codagt = sel.age00_codage
                                   AND age.prz02_codprz = pl.pla00_codigo
            WHERE sel.age00_codcli = ?
          )
        ''');
        binds.add(clienteCodigo);
      }
    }

    final String whereSql = whereClauses.isNotEmpty ? 'WHERE ${whereClauses.join(' AND ')}' : '';

    final String sql = '''
      SELECT DISTINCT 
        pl.pla00_codigo, 
        pl.pla00_descri, 
        $selVlrMin AS pla00_vlrmin
      FROM cadpla00 pl
      $joinPrz00
      $whereSql
      ORDER BY $orderBy
    ''';

    final List<Map<String, dynamic>> resPlanos = await db.rawQuery(sql, binds);

    // Se o filtro restritivo retornou vazio por divergência de bases legadas sem amarrações cadprz02,
    // realiza fallback inteligente para não bloquear a digitação
    if (resPlanos.isEmpty && whereClauses.isNotEmpty) {
      final fallbackRows = await db.rawQuery('SELECT pla00_codigo, pla00_descri, $selVlrMin AS pla00_vlrmin FROM cadpla00 ORDER BY $orderBy');
      return fallbackRows.map((m) {
        return ListaPadraoStruct(
          codigo: m['pla00_codigo']?.toString() ?? '',
          descricao: m['pla00_descri']?.toString() ?? '',
          vlrmin: _parseDouble(m['pla00_vlrmin']),
        );
      }).toList();
    }

    return resPlanos.map((m) {
      return ListaPadraoStruct(
        codigo: m['pla00_codigo']?.toString() ?? '',
        descricao: m['pla00_descri']?.toString() ?? '',
        vlrmin: _parseDouble(m['pla00_vlrmin']),
      );
    }).toList();
  } catch (e) {
    print('Erro ao carregar planos de pagamento cruzados: $e');
    return [];
  }
}

int _parseInt(dynamic val) {
  if (val == null) return 0;
  if (val is int) return val;
  if (val is num) return val.toInt();
  return int.tryParse(val.toString()) ?? 0;
}

double _parseDouble(dynamic val) {
  if (val == null) return 0.0;
  if (val is num) return val.toDouble();
  return double.tryParse(val.toString()) ?? 0.0;
}
