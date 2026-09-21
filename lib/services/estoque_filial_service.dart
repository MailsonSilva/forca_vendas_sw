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
}
