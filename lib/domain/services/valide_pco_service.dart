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

  /// Obtém as faixas de preço conforme a hierarquia da Seção 1.2 da spec:
  /// 1. estpcoregpco00 (faixas regionais/tabela)
  /// 2. estpcopro00 (tabela de preço padrão)
  /// 3. cadpro00 (cadastro base de produto)
  static Future<FaixaPrecoProduto> obterFaixasPreco(
    String codProduto, {
    int? codTabela,
    int? codRegiao,
    int? codFilial,
  }) async {
    try {
      final db = await LocalSalesDatabaseService.getDatabase();
      final tablesQuery = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table'");
      final tables = tablesQuery.map((r) => r['name']?.toString().toLowerCase() ?? '').toSet();

      final int tab = codTabela ?? 0;
      final int reg = codRegiao ?? 0;
      final int? intVal = int.tryParse(codProduto);

      // 1. Hierarquia 1: estpcoregpco00 (Faixas Regionais)
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

      // 2. Hierarquia 2: estpcopro00 (Preço por tabela)
      if (tables.contains('estpcopro00') || tables.contains('pcopro00')) {
        final tbl = tables.contains('estpcopro00') ? 'estpcopro00' : 'pcopro00';
        try {
          final cols = await db.rawQuery('PRAGMA table_info($tbl)');
          final colNames = cols.map((r) => r['name']?.toString().toLowerCase() ?? '').toSet();

          String codCol = colNames.contains('pro00_codpro')
              ? 'pro00_codpro'
              : (colNames.contains('pro00_codigo') ? 'pro00_codigo' : 'codpro');
          String tabCol = colNames.contains('pro00_codtab') ? 'pro00_codtab' : 'codtab';
          String pcoCol = colNames.contains('pro00_pcosub')
              ? 'pro00_pcosub'
              : (colNames.contains('pro00_preco') ? 'pro00_preco' : 'preco');
          String minCol = colNames.contains('pro00_pcomin') ? 'pro00_pcomin' : 'pcomin';
          String maxCol = colNames.contains('pro00_pcomax') ? 'pro00_pcomax' : 'pcomax';
          String comCol = colNames.contains('pro00_commax') ? 'pro00_commax' : 'commax';

          String query = 'SELECT * FROM $tbl WHERE ($codCol = ? OR $codCol = ?)';
          List<dynamic> args = [codProduto, intVal ?? -1];

          if (tab > 0 && colNames.contains(tabCol)) {
            query += ' AND $tabCol = ?';
            args.add(tab);
          }
          query += ' LIMIT 1';

          final rows = await db.rawQuery(query, args);
          if (rows.isNotEmpty) {
            final r = rows.first;
            final double base = _parseDouble(r[pcoCol]);
            final double pmin = _parseDouble(r[minCol]);
            final double pmax = _parseDouble(r[maxCol]);
            final double cmax = _parseDouble(r[comCol]);

            return FaixaPrecoProduto(
              pcomin: pmin > 0 ? pmin : (base > 0 ? base : 0.0),
              pcomax: pmax > 0 ? pmax : (base > 0 ? base : 999999.0),
              commax: cmax > 0 ? cmax : 100.0,
              precoBase: base,
              freadpco: true,
              tabelaOrigem: tbl,
            );
          }
        } catch (_) {}
      }

      // 3. Hierarquia 3: cadpro00
      if (tables.contains('cadpro00') || tables.contains('pro00')) {
        final tbl = tables.contains('cadpro00') ? 'cadpro00' : 'pro00';
        try {
          final cols = await db.rawQuery('PRAGMA table_info($tbl)');
          final colNames = cols.map((r) => r['name']?.toString().toLowerCase() ?? '').toSet();

          String codCol = colNames.contains('pro00_codigo') ? 'pro00_codigo' : 'codigo';
          String pcoCol = colNames.contains('pro00_pcosub')
              ? 'pro00_pcosub'
              : (colNames.contains('pro00_preco') ? 'pro00_preco' : 'preco');
          String minCol = colNames.contains('pro00_pcomin') ? 'pro00_pcomin' : 'pcomin';
          String maxCol = colNames.contains('pro00_pcomax') ? 'pro00_pcomax' : 'pcomax';
          String comCol = colNames.contains('pro00_commax') ? 'pro00_commax' : 'commax';
          String frdCol = colNames.contains('pro00_freadpco') ? 'pro00_freadpco' : 'freadpco';

          final rows = await db.rawQuery(
            'SELECT * FROM $tbl WHERE ($codCol = ? OR $codCol = ?) LIMIT 1',
            [codProduto, intVal ?? -1],
          );
          if (rows.isNotEmpty) {
            final r = rows.first;
            final double base = _parseDouble(r[pcoCol]);
            final double pmin = _parseDouble(r[minCol]);
            final double pmax = _parseDouble(r[maxCol]);
            final double cmax = _parseDouble(r[comCol]);
            final bool frd = r[frdCol] != null ? (_parseDouble(r[frdCol]) != 0.0) : true;

            return FaixaPrecoProduto(
              pcomin: pmin > 0 ? pmin : (base > 0 ? base : 0.0),
              pcomax: pmax > 0 ? pmax : (base > 0 ? base : 999999.0),
              commax: cmax > 0 ? cmax : 100.0,
              precoBase: base,
              freadpco: frd,
              tabelaOrigem: tbl,
            );
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
