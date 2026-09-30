import '../../backend/schema/structs/validation_result_struct.dart';
import '../../data/services/local_sales_database_service.dart';

/// Modelo com faixas de preço extraídas hierarquicamente (estpcoregpco00 / estpcopro00 / cadpro00)
class FaixaPrecoProduto {
  final double pcomin;
  final double pcomax;
  final double commax;
  final double precoBase;
  final bool freadpco;
  final String tabelaOrigem;

  const FaixaPrecoProduto({
    required this.pcomin,
    required this.pcomax,
    required this.commax,
    required this.precoBase,
    required this.freadpco,
    this.tabelaOrigem = 'cadpro00',
  });
}

/// PRD B6 & Seção 1 — ValidePCOValues / ValideQTDValues e hierarquia de faixas de preço
class ValidePcoService {
  static ValidationResultStruct validePCOValues({
    required double pcomin,
    required double pcomax,
    required double commax,
    required double digpco,
    required double destot,
    required bool freadpco,
    bool isEdicaoManual = false,
  }) {
    if (digpco <= 0) {
      return ValidationResultStruct(
        valido: false,
        mensagem: 'Preço unitário inválido!',
      );
    }
    if (isEdicaoManual && !freadpco) {
      return ValidationResultStruct(
        valido: false,
        mensagem: 'Representante sem permissão para alteração de preços!',
      );
    }
    if (pcomin > 0 && digpco < pcomin) {
      return ValidationResultStruct(
        valido: false,
        mensagem: 'Preço digitado abaixo do preço mínimo permitido!',
      );
    }
    if (pcomax > 0 && digpco > pcomax) {
      return ValidationResultStruct(
        valido: false,
        mensagem: 'Preço digitado acima do preço máximo de tabela!',
      );
    }
    if (commax > 0 && destot > commax) {
      return ValidationResultStruct(
        valido: false,
        mensagem: 'Desconto excede a flexibilidade permitida!',
      );
    }
    return ValidationResultStruct(valido: true, mensagem: '');
  }

  static ValidationResultStruct valideQTDValues({
    required double quantidade,
    required double saldo,
  }) {
    if (quantidade <= 0) {
      return ValidationResultStruct(valido: false, mensagem: 'Quantidade inválida');
    }
    if (quantidade > saldo) {
      return ValidationResultStruct(valido: false, mensagem: 'Estoque insuficiente');
    }
    return ValidationResultStruct(valido: true, mensagem: '');
  }

  /// Obtém as faixas de preço conforme a resolução canônica da SPEC-058:
  /// 1. estpcoreg00 (cruzamento produto + tabela + regiao -> classe)
  /// 2. estpcopro00 (valor pcosub como pcomax, pcocus/pcosub como pcomin)
  /// 3. Fallback estpcoregpco00 se existir (legado)
  static Future<FaixaPrecoProduto> obterFaixasPreco(
    String codProduto, {
    int? codTabela,
    int? codRegiao,
    int? codFilial,
    int? codClasse,
  }) async {
    try {
      final db = await LocalSalesDatabaseService.getDatabase();
      final tablesQuery = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table'");
      final tables = tablesQuery.map((r) => r['name']?.toString().toLowerCase() ?? '').toSet();

      final int tab = codTabela ?? 0;
      final int reg = codRegiao ?? 0;
      final int? intVal = int.tryParse(codProduto);

      // 1. Resolução Canônica SPEC-058: estpcoreg00 -> estpcopro00
      if (tables.contains('estpcopro00')) {
        int? resolvedCls = codClasse;

        // Se houver tabela de amarração regional estpcoreg00, consulta a classe de preço
        if (tables.contains('estpcoreg00')) {
          try {
            final colsReg = await db.rawQuery('PRAGMA table_info(estpcoreg00)');
            final colNamesReg = colsReg.map((r) => r['name']?.toString().toLowerCase() ?? '').toSet();

            String codCol = colNamesReg.contains('pro00_codpro') ? 'pro00_codpro' : 'codpro';
            String tabCol = colNamesReg.contains('pro00_codtab') ? 'pro00_codtab' : 'codtab';
            String regCol = colNamesReg.contains('pro00_codreg') ? 'pro00_codreg' : 'codreg';
            String clsCol = colNamesReg.contains('pro00_codcls')
                ? 'pro00_codcls'
                : (colNamesReg.contains('pro00_codpco') ? 'pro00_codpco' : 'codcls');

            String queryReg = 'SELECT $clsCol AS cls FROM estpcoreg00 WHERE ($codCol = ? OR $codCol = ?)';
            List<dynamic> argsReg = [codProduto, intVal ?? -1];

            if (tab > 0 && colNamesReg.contains(tabCol)) {
              queryReg += ' AND $tabCol = ?';
              argsReg.add(tab);
            }
            if (reg > 0 && colNamesReg.contains(regCol)) {
              queryReg += ' AND $regCol = ?';
              argsReg.add(reg);
            }
            queryReg += ' LIMIT 1';

            final rowsReg = await db.rawQuery(queryReg, argsReg);
            if (rowsReg.isNotEmpty && rowsReg.first['cls'] != null) {
              resolvedCls = int.tryParse(rowsReg.first['cls'].toString());
            }
          } catch (_) {}
        }

        // Consulta estpcopro00
        try {
          final colsPco = await db.rawQuery('PRAGMA table_info(estpcopro00)');
          final colNamesPco = colsPco.map((r) => r['name']?.toString().toLowerCase() ?? '').toSet();

          String codCol = colNamesPco.contains('pro00_codpro')
              ? 'pro00_codpro'
              : (colNamesPco.contains('pro00_codigo') ? 'pro00_codigo' : 'codpro');
          String clsCol = colNamesPco.contains('pro00_codcls')
              ? 'pro00_codcls'
              : (colNamesPco.contains('pro00_codpco') ? 'pro00_codpco' : 'codcls');
          String tabCol = colNamesPco.contains('pro00_codtab') ? 'pro00_codtab' : 'codtab';
          String subCol = colNamesPco.contains('pro00_pcosub')
              ? 'pro00_pcosub'
              : (colNamesPco.contains('pro00_preco') ? 'pro00_preco' : 'preco');
          String cusCol = colNamesPco.contains('pro00_pcocus') ? 'pro00_pcocus' : 'pcocus';
          String minCol = colNamesPco.contains('pro00_pcomin') ? 'pro00_pcomin' : 'pcomin';
          String maxCol = colNamesPco.contains('pro00_pcomax') ? 'pro00_pcomax' : 'pcomax';
          String comCol = colNamesPco.contains('pro00_commax') ? 'pro00_commax' : 'commax';

          String queryPco = 'SELECT * FROM estpcopro00 WHERE ($codCol = ? OR $codCol = ?)';
          List<dynamic> argsPco = [codProduto, intVal ?? -1];

          if (resolvedCls != null && resolvedCls > 0 && colNamesPco.contains(clsCol)) {
            queryPco += ' AND $clsCol = ?';
            argsPco.add(resolvedCls);
          } else if (tab > 0 && colNamesPco.contains(tabCol)) {
            queryPco += ' AND $tabCol = ?';
            argsPco.add(tab);
          }
          queryPco += ' LIMIT 1';

          final rowsPco = await db.rawQuery(queryPco, argsPco);
          if (rowsPco.isNotEmpty) {
            final r = rowsPco.first;
            final double sub = colNamesPco.contains(subCol) ? _parseDouble(r[subCol]) : 0.0;
            final double cus = colNamesPco.contains(cusCol) ? _parseDouble(r[cusCol]) : 0.0;
            final double explicitMin = colNamesPco.contains(minCol) ? _parseDouble(r[minCol]) : 0.0;
            final double explicitMax = colNamesPco.contains(maxCol) ? _parseDouble(r[maxCol]) : 0.0;
            final double cmax = colNamesPco.contains(comCol) ? _parseDouble(r[comCol]) : 100.0;

            final double pmax = explicitMax > 0 ? explicitMax : sub;
            final double pmin = explicitMin > 0 ? explicitMin : (cus > 0 ? cus : sub);

            if (pmax > 0 || pmin > 0) {
              return FaixaPrecoProduto(
                pcomin: pmin,
                pcomax: pmax > 0 ? pmax : 999999.0,
                commax: cmax > 0 ? cmax : 100.0,
                precoBase: sub > 0 ? sub : pmax,
                freadpco: true,
                tabelaOrigem: 'estpcopro00',
              );
            }
          }
        } catch (_) {}
      }

      // 2. Fallback Legado: estpcoregpco00 (Faixas Regionais diretas)
      if (tables.contains('estpcoregpco00')) {
        try {
          final cols = await db.rawQuery('PRAGMA table_info(estpcoregpco00)');
          final colNames = cols.map((r) => r['name']?.toString().toLowerCase() ?? '').toSet();

          String codCol = colNames.contains('pco00_codpro') ? 'pco00_codpro' : 'codpro';
          String tabCol = colNames.contains('pco00_codtab') ? 'pco00_codtab' : 'codtab';
          String regCol = colNames.contains('pco00_codreg') ? 'pco00_codreg' : 'codreg';
          String minCol = colNames.contains('pco00_pcomin') ? 'pco00_pcomin' : 'pcomin';
          String maxCol = colNames.contains('pco00_pcomax') ? 'pco00_pcomax' : 'pcomax';

          String query = 'SELECT * FROM estpcoregpco00 WHERE ($codCol = ? OR $codCol = ?)';
          List<dynamic> args = [codProduto, intVal ?? -1];

          if (tab > 0 && colNames.contains(tabCol)) {
            query += ' AND $tabCol = ?';
            args.add(tab);
          }
          if (reg > 0 && colNames.contains(regCol)) {
            query += ' AND $regCol = ?';
            args.add(reg);
          }
          query += ' LIMIT 1';

          final rows = await db.rawQuery(query, args);
          if (rows.isNotEmpty) {
            final r = rows.first;
            final double pmin = _parseDouble(r[minCol]);
            final double pmax = _parseDouble(r[maxCol]);
            if (pmin > 0 || pmax > 0) {
              return FaixaPrecoProduto(
                pcomin: pmin,
                pcomax: pmax > 0 ? pmax : 999999.0,
                commax: 100.0,
                precoBase: pmax > 0 ? pmax : pmin,
                freadpco: true,
                tabelaOrigem: 'estpcoregpco00',
              );
            }
          }
        } catch (_) {}
      }

      // 3. Fallback Legado: cadpro00 (apenas se tiver colunas explícitas de faixa pcomin/pcomax)
      if (tables.contains('cadpro00') || tables.contains('pro00')) {
        final tbl = tables.contains('cadpro00') ? 'cadpro00' : 'pro00';
        try {
          final cols = await db.rawQuery('PRAGMA table_info($tbl)');
          final colNames = cols.map((r) => r['name']?.toString().toLowerCase() ?? '').toSet();

          String codCol = colNames.contains('pro00_codigo') ? 'pro00_codigo' : 'codigo';
          String subCol = colNames.contains('pro00_pcosub') ? 'pro00_pcosub' : 'pcosub';
          String minCol = colNames.contains('pro00_pcomin') ? 'pro00_pcomin' : 'pcomin';
          String maxCol = colNames.contains('pro00_pcomax') ? 'pro00_pcomax' : 'pcomax';
          String comCol = colNames.contains('pro00_commax') ? 'pro00_commax' : 'commax';
          String frdCol = colNames.contains('pro00_freadpco') ? 'pro00_freadpco' : 'freadpco';

          if (colNames.contains(minCol) || colNames.contains(maxCol) || colNames.contains(subCol)) {
            final rows = await db.rawQuery(
              'SELECT * FROM $tbl WHERE ($codCol = ? OR $codCol = ?) LIMIT 1',
              [codProduto, intVal ?? -1],
            );
            if (rows.isNotEmpty) {
              final r = rows.first;
              final double base = colNames.contains(subCol) ? _parseDouble(r[subCol]) : 0.0;
              final double pmin = colNames.contains(minCol) ? _parseDouble(r[minCol]) : 0.0;
              final double pmax = colNames.contains(maxCol) ? _parseDouble(r[maxCol]) : 0.0;
              final double cmax = colNames.contains(comCol) ? _parseDouble(r[comCol]) : 100.0;
              final bool frd = colNames.contains(frdCol) && r[frdCol] != null ? (_parseDouble(r[frdCol]) != 0.0) : true;

              if (pmin > 0 || pmax > 0 || base > 0) {
                return FaixaPrecoProduto(
                  pcomin: pmin > 0 ? pmin : (base > 0 ? base : 0.0),
                  pcomax: pmax > 0 ? pmax : (base > 0 ? base : 999999.0),
                  commax: cmax > 0 ? cmax : 100.0,
                  precoBase: base,
                  freadpco: frd,
                  tabelaOrigem: tbl,
                );
              }
            }
          }
        } catch (_) {}
      }
    } catch (_) {}

    return const FaixaPrecoProduto(
      pcomin: 0.0,
      pcomax: 999999.0,
      commax: 100.0,
      precoBase: 0.0,
      freadpco: true,
      tabelaOrigem: 'default',
    );
  }

  static double _parseDouble(dynamic val) {
    if (val == null) return 0.0;
    if (val is num) return val.toDouble();
    return double.tryParse(val.toString()) ?? 0.0;
  }
}
