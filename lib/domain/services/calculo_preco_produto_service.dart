import 'package:sqflite/sqflite.dart';
import '../../data/services/local_sales_database_service.dart';
import 'valide_pco_service.dart';

/// Resultado encapsulado do cálculo unificado de preços de produto.
class PrecoCalculadoResult {
  final double precoBase;
  final double fatorPlano;
  final double precoComFator;
  final double desconto;
  final double precoEfetivo;
  final double pcomin;
  final double pcomax;
  final double multiplicadorEmbalagem;
  final bool atingiuPrecoMinimo;
  final bool isBonificacao;

  const PrecoCalculadoResult({
    required this.precoBase,
    required this.fatorPlano,
    required this.precoComFator,
    required this.desconto,
    required this.precoEfetivo,
    required this.pcomin,
    required this.pcomax,
    required this.multiplicadorEmbalagem,
    required this.atingiuPrecoMinimo,
    this.isBonificacao = false,
  });

  /// Total monetário para uma quantidade específica respeitando precisão comercial
  double precoTotal(double quantidade) {
    if (isBonificacao) return 0.0;
    return CalculoPrecoProdutoService.arredondarMoeda(precoEfetivo * quantidade);
  }
}

/// Serviço puro de domínio para unificação do cálculo de preços de produtos.
///
/// Implementa a fórmula descrita no PROJECT_BRAIN.md e SPEC-058:
/// Preço Efetivo = (Preço Base da Tabela x Fator do Plano cadpla00) - Descontos,
/// respeitando o multiplicador de embalagem e a trava impeditiva de pro00_pcomin.
class CalculoPrecoProdutoService {
  /// Arredondamento comercial para 2 casas decimais
  static double arredondarMoeda(double valor) {
    return double.parse(valor.toStringAsFixed(2));
  }

  /// Consulta o fator financeiro do plano de pagamento (cadpla00.pla00_fator)
  static Future<double> obterFatorPlano(int? codPlano, {Database? db}) async {
    if (codPlano == null || codPlano <= 0) return 1.0;
    try {
      final database = db ?? await LocalSalesDatabaseService.getDatabase(readOnly: true);
      final tables = await database.rawQuery("SELECT name FROM sqlite_master WHERE type='table' AND lower(name)='cadpla00'");
      if (tables.isEmpty) return 1.0;

      final cols = await database.rawQuery('PRAGMA table_info(cadpla00)');
      final colNames = cols.map((r) => r['name']?.toString().toLowerCase() ?? '').toSet();
      if (!colNames.contains('pla00_fator')) return 1.0;

      final rows = await database.rawQuery(
        'SELECT pla00_fator FROM cadpla00 WHERE pla00_codigo = ? LIMIT 1',
        [codPlano],
      );
      if (rows.isNotEmpty && rows.first['pla00_fator'] != null) {
        final val = rows.first['pla00_fator'];
        final fator = (val is num) ? val.toDouble() : (double.tryParse(val.toString()) ?? 1.0);
        return fator > 0 ? fator : 1.0;
      }
    } catch (_) {}
    return 1.0;
  }

  /// Consulta o multiplicador de venda / embalagem (cadproemb02 / cadpro02 / cadpro00)
  static Future<double> obterMultiplicadorEmbalagem(dynamic codProduto, {Database? db}) async {
    if (codProduto == null) return 1.0;
    final int? codInt = int.tryParse(codProduto.toString());
    try {
      final database = db ?? await LocalSalesDatabaseService.getDatabase(readOnly: true);
      final tablesQuery = await database.rawQuery("SELECT name FROM sqlite_master WHERE type='table'");
      final tables = tablesQuery.map((r) => r['name']?.toString().toLowerCase() ?? '').toSet();

      // 1. Tabela dedicada de embalagens secundárias cadproemb02 (pro02_mulven)
      if (tables.contains('cadproemb02')) {
        try {
          final rows = await database.rawQuery(
            'SELECT pro02_mulven FROM cadproemb02 WHERE pro02_codprd = ? OR CAST(pro02_codprd AS TEXT) = ? LIMIT 1',
            [codInt ?? -1, codProduto.toString()],
          );
          if (rows.isNotEmpty && rows.first['pro02_mulven'] != null) {
            final val = rows.first['pro02_mulven'];
            final mul = (val is num) ? val.toDouble() : (double.tryParse(val.toString()) ?? 1.0);
            if (mul > 0) return mul;
          }
        } catch (_) {}
      }

      // 2. Tabela cadpro02 (pro02_mulven)
      if (tables.contains('cadpro02')) {
        try {
          final rows = await database.rawQuery(
            'SELECT pro02_mulven FROM cadpro02 WHERE pro02_codpro = ? OR CAST(pro02_codpro AS TEXT) = ? LIMIT 1',
            [codInt ?? -1, codProduto.toString()],
          );
          if (rows.isNotEmpty && rows.first['pro02_mulven'] != null) {
            final val = rows.first['pro02_mulven'];
            final mul = (val is num) ? val.toDouble() : (double.tryParse(val.toString()) ?? 1.0);
            if (mul > 0) return mul;
          }
        } catch (_) {}
      }

      // 3. Tabela cadpro00 (pro00_mulver / pro02_mulven)
      if (tables.contains('cadpro00')) {
        try {
          final cols = await database.rawQuery('PRAGMA table_info(cadpro00)');
          final colNames = cols.map((r) => r['name']?.toString().toLowerCase() ?? '').toSet();
          String? mulCol;
          if (colNames.contains('pro02_mulven')) mulCol = 'pro02_mulven';
          else if (colNames.contains('pro00_mulver')) mulCol = 'pro00_mulver';
          else if (colNames.contains('mulver')) mulCol = 'mulver';

          if (mulCol != null) {
            final rows = await database.rawQuery(
              'SELECT $mulCol FROM cadpro00 WHERE pro00_codigo = ? OR CAST(pro00_codigo AS TEXT) = ? LIMIT 1',
              [codInt ?? -1, codProduto.toString()],
            );
            if (rows.isNotEmpty && rows.first[mulCol] != null) {
              final val = rows.first[mulCol];
              final mul = (val is num) ? val.toDouble() : (double.tryParse(val.toString()) ?? 1.0);
              if (mul > 0) return mul;
            }
          }
        } catch (_) {}
      }
    } catch (_) {}
    return 1.0;
  }

  /// Método puro para cálculo de preço a partir de valores fornecidos
  static PrecoCalculadoResult calcularPreco({
    required double precoBase,
    double fatorPlano = 1.0,
    double desconto = 0.0,
    double? pcomin,
    double? pcomax,
    double multiplicadorEmbalagem = 1.0,
    bool isBonificacao = false,
  }) {
    if (isBonificacao) {
      return PrecoCalculadoResult(
        precoBase: precoBase,
        fatorPlano: fatorPlano,
        precoComFator: 0.0,
        desconto: 0.0,
        precoEfetivo: 0.0,
        pcomin: 0.0,
        pcomax: pcomax ?? precoBase,
        multiplicadorEmbalagem: multiplicadorEmbalagem > 0 ? multiplicadorEmbalagem : 1.0,
        atingiuPrecoMinimo: false,
        isBonificacao: true,
      );
    }

    final double fator = fatorPlano > 0 ? fatorPlano : 1.0;
    final double precoComFator = precoBase * fator;
    final double baseMin = (pcomin != null && pcomin > 0) ? pcomin : 0.0;
    final double baseMax = (pcomax != null && pcomax > 0) ? pcomax : precoBase;

    // Fator do plano incide proporcionalmente no patamar de preço
    final double minPermitido = baseMin > 0 ? (baseMin * fator) : 0.0;
    final double maxPermitido = baseMax > 0 ? (baseMax * fator) : 999999.0;

    double precoAposDesconto = precoComFator - desconto;
    bool atingiuMinimo = false;

    // Trava de pro00_pcomin (Preço não pode ser inferior ao mínimo)
    if (minPermitido > 0 && precoAposDesconto < (minPermitido - 0.001)) {
      precoAposDesconto = minPermitido;
      atingiuMinimo = true;
    }

    final double mul = multiplicadorEmbalagem > 0 ? multiplicadorEmbalagem : 1.0;
    final double precoEfetivoFinal = arredondarMoeda(precoAposDesconto);

    return PrecoCalculadoResult(
      precoBase: arredondarMoeda(precoBase),
      fatorPlano: fator,
      precoComFator: arredondarMoeda(precoComFator),
      desconto: arredondarMoeda(desconto),
      precoEfetivo: precoEfetivoFinal,
      pcomin: arredondarMoeda(minPermitido > 0 ? minPermitido : baseMin),
      pcomax: arredondarMoeda(maxPermitido),
      multiplicadorEmbalagem: mul,
      atingiuPrecoMinimo: atingiuMinimo,
      isBonificacao: false,
    );
  }

  /// Calcula o preço completo com leitura da hierarquia canônica do banco local
  static Future<PrecoCalculadoResult> calcularPrecoCompleto({
    required String codProduto,
    int? codTabela,
    int? codPlano,
    int? codFilial,
    int? codRegiao,
    int? codClasseCliente,
    double desconto = 0.0,
    bool isBonificacao = false,
    Database? db,
  }) async {
    final faixa = await ValidePcoService.obterFaixasPreco(
      codProduto,
      codTabela: codTabela,
      codRegiao: codRegiao,
      codFilial: codFilial,
      codClasseCliente: codClasseCliente,
    );

    final fator = await obterFatorPlano(codPlano, db: db);
    final mul = await obterMultiplicadorEmbalagem(codProduto, db: db);

    return calcularPreco(
      precoBase: faixa.precoBase,
      fatorPlano: fator,
      desconto: desconto,
      pcomin: faixa.pcomin,
      pcomax: faixa.pcomax,
      multiplicadorEmbalagem: mul,
      isBonificacao: isBonificacao,
    );
  }
}
