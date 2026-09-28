import 'package:sqflite/sqflite.dart';
import '../data/services/local_sales_database_service.dart';

/// Serviço responsável pelo cálculo e validação de estoque particionado por filial
/// conforme regras da SPEC-047 (item 3.2: ffrmdigvenmov07::validaEstoque).
class EstoqueFilialService {
  EstoqueFilialService({Database? database}) : _database = database;

  final Database? _database;

  Future<Database> _getDb() async {
    return _database ?? await LocalSalesDatabaseService.getDatabase();
  }

  /// Retorna o estoque físico disponível da filial ativa com fallback para cadpro00.
  ///
  /// Conforme SPEC-047 item 3.2:
  /// ```sql
  /// SELECT COALESCE(e.pro00_qtdest, p.pro00_qtdest, 0.0) AS estoque_disponivel
  /// FROM cadpro00 p
  /// LEFT JOIN estpro00 e ON e.pro00_codpro = p.pro00_codigo
  ///                     AND e.pro00_codfil = :filialAtiva
  /// WHERE p.pro00_codigo = :codigoProduto;
  /// ```
  Future<double> obterEstoqueDisponivel({
    required dynamic codigoProduto,
    required int filialAtiva,
  }) async {
    final db = await _getDb();
    final codStr = codigoProduto.toString().trim();
    final codInt = int.tryParse(codStr) ?? 0;

    try {
      final rows = await db.rawQuery(
        '''
        SELECT COALESCE(e.pro00_qtdest, p.pro00_qtdest, 0.0) AS estoque_disponivel
        FROM cadpro00 p
        LEFT JOIN estpro00 e ON (e.pro00_codpro = ? OR e.pro00_codpro = ?)
                            AND e.pro00_codfil = ?
        WHERE p.pro00_codigo = ? OR p.pro00_codigo = ?
        LIMIT 1
        ''',
        [codStr, codInt.toString(), filialAtiva, codInt, codStr],
      );

      if (rows.isNotEmpty) {
        final val = rows.first['estoque_disponivel'];
        if (val is num) return val.toDouble();
        return double.tryParse(val?.toString() ?? '') ?? 0.0;
      }
      return 0.0;
    } catch (_) {
      // Fallback defensivo caso a tabela ou formato de dados varie
      try {
        final rEst = await db.rawQuery(
          'SELECT pro00_qtdest FROM estpro00 WHERE (pro00_codpro = ? OR pro00_codpro = ?) AND pro00_codfil = ? LIMIT 1',
          [codStr, codInt.toString(), filialAtiva],
        );
        if (rEst.isNotEmpty && rEst.first['pro00_qtdest'] != null) {
          final v = rEst.first['pro00_qtdest'];
          return (v is num) ? v.toDouble() : (double.tryParse(v.toString()) ?? 0.0);
        }

        final rCad = await db.rawQuery(
          'SELECT pro00_qtdest FROM cadpro00 WHERE pro00_codigo = ? OR pro00_codigo = ? LIMIT 1',
          [codInt, codStr],
        );
        if (rCad.isNotEmpty && rCad.first['pro00_qtdest'] != null) {
          final v = rCad.first['pro00_qtdest'];
          return (v is num) ? v.toDouble() : (double.tryParse(v.toString()) ?? 0.0);
        }
      } catch (_) {}
      return 0.0;
    }
  }

  /// Valida se a quantidade digitada pode ser vendida de acordo com a regra de venda negativa
  /// conforme SPEC-047 (item 3.2):
  /// Caso o parâmetro de controle de venda negativa esteja bloqueado (ven00_estneg == false),
  /// impede a confirmação caso a quantidade digitada supere o estoque disponível.
  bool validarVendaEstoque({
    required double quantidadeDigitada,
    required double estoqueDisponivel,
    required bool permiteVendaNegativa,
  }) {
    if (permiteVendaNegativa) {
      return true;
    }
    return quantidadeDigitada <= estoqueDisponivel;
  }

  /// Executa baixa do estoque local em `estpro00` e `cadpro00` na criação/confirmação do pedido:
  ///
  /// ```sql
  /// UPDATE estpro00 
  /// SET pro00_qtdest = MAX(0.0, pro00_qtdest - ?) 
  /// WHERE pro00_codpro = ? AND pro00_codfil = ?;
  /// ```
  /// E se a base mantiver saldo direto em `cadpro00.pro00_qtdest`, abater proporcionalmente
  /// para refletir imediatamente na consulta de catálogo:
  /// ```sql
  /// UPDATE cadpro00 
  /// SET pro00_qtdest = MAX(0.0, pro00_qtdest - ?) 
  /// WHERE pro00_codigo = ?;
  /// ```
  static Future<void> baixarEstoquePedido({
    required Database db,
    required int codFil,
    required List<ItemBaixaEstoque> itens,
  }) async {
    if (itens.isEmpty) return;

    // 1. Inspeciona tabelas e colunas
    final tables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND lower(name) IN ('estpro00', 'cadpro00')",
    );
    final tableNames = tables.map((r) => r['name']?.toString().toLowerCase()).toSet();

    final bool hasEstpro = tableNames.contains('estpro00');
    final bool hasCadpro = tableNames.contains('cadpro00');

    Set<String> estCols = {};
    if (hasEstpro) {
      final cols = await db.rawQuery('PRAGMA table_info(estpro00)');
      estCols = cols.map((r) => r['name']?.toString().toLowerCase() ?? '').toSet();
    }

    Set<String> cadCols = {};
    if (hasCadpro) {
      final cols = await db.rawQuery('PRAGMA table_info(cadpro00)');
      cadCols = cols.map((r) => r['name']?.toString().toLowerCase() ?? '').toSet();
    }

    final String colEstPro = estCols.contains('pro00_codpro')
        ? 'pro00_codpro'
        : (estCols.contains('pro00_codigo') ? 'pro00_codigo' : 'pro00_codpro');

    final String colCadPro = cadCols.contains('pro00_codigo')
        ? 'pro00_codigo'
        : (cadCols.contains('pro00_codpro') ? 'pro00_codpro' : 'pro00_codigo');

    final bool estTemQtdEst = estCols.contains('pro00_qtdest');
    final bool estTemQtdPen = estCols.contains('pro00_qtdpen');
    final bool cadTemQtdEst = cadCols.contains('pro00_qtdest');

    for (final item in itens) {
      final codStr = item.codPro.toString().trim();
      final codInt = int.tryParse(codStr);
      final qtd = item.quantidade;
      if (qtd <= 0) continue;

      // 2. Baixa em estpro00
      if (hasEstpro && estTemQtdEst) {
        try {
          if (estTemQtdPen) {
            await db.rawUpdate(
              '''
              UPDATE estpro00 
              SET pro00_qtdest = MAX(0.0, COALESCE(pro00_qtdest, 0.0) - ?),
                  pro00_qtdpen = COALESCE(pro00_qtdpen, 0.0) + ?
              WHERE ($colEstPro = ? OR $colEstPro = ?) AND pro00_codfil = ?
              ''',
              [qtd, qtd, codStr, codInt?.toString() ?? codStr, codFil],
            );
          } else {
            await db.rawUpdate(
              '''
              UPDATE estpro00 
              SET pro00_qtdest = MAX(0.0, COALESCE(pro00_qtdest, 0.0) - ?) 
              WHERE ($colEstPro = ? OR $colEstPro = ?) AND pro00_codfil = ?
              ''',
              [qtd, codStr, codInt?.toString() ?? codStr, codFil],
            );
          }
        } catch (_) {}
      }

      // 3. Baixa em cadpro00 (refletir imediatamente na consulta de catálogo)
      if (hasCadpro && cadTemQtdEst) {
        try {
          await db.rawUpdate(
            '''
            UPDATE cadpro00 
            SET pro00_qtdest = MAX(0.0, COALESCE(pro00_qtdest, 0.0) - ?) 
            WHERE $colCadPro = ? OR $colCadPro = ?
            ''',
            [qtd, codStr, codInt?.toString() ?? codStr],
          );
        } catch (_) {}
      }
    }
  }
}

/// Item para execução de baixa de estoque na confirmação do pedido.
class ItemBaixaEstoque {
  const ItemBaixaEstoque({
    required this.codPro,
    required this.quantidade,
  });

  final dynamic codPro;
  final double quantidade;
}
