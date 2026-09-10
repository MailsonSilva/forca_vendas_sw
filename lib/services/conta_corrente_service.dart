import 'package:sqflite/sqflite.dart';
import '../app_state.dart';
import '../data/services/local_sales_database_service.dart';
import '../domain/models/conta_corrente_model.dart';

/// Serviço responsável por gerenciar a persistência, consultas e regras
/// de negócio do Conta-Corrente do Vendedor (CCV / Saldo Flex).
class ContaCorrenteService {
  /// Obtém o saldo consolidado de CCV do vendedor (`fincaiccv01` e `fincaidat00`).
  static Future<ContaCorrenteSaldo> obterSaldoConsolidado({
    int? codVen,
    int? codFil,
    Database? customDb,
  }) async {
    final db = customDb ?? await LocalSalesDatabaseService.getDatabase();
    final repCod = codVen ?? AppState().vendedor_codigo;
    final filCod = codFil ?? AppState().codFilialAtiva;

    String? dataSinc;
    try {
      final syncRows = await db.rawQuery('SELECT dat00_dattim FROM fincaidat00 LIMIT 1');
      if (syncRows.isNotEmpty && syncRows.first['dat00_dattim'] != null) {
        dataSinc = syncRows.first['dat00_dattim'].toString();
      }
    } catch (_) {}

    try {
      // Busca específica por vendedor e filial
      var rows = await db.rawQuery(
        'SELECT * FROM fincaiccv01 WHERE ccv01_codven = ? AND ccv01_codfil = ? LIMIT 1',
        [repCod, filCod],
      );

      // Fallback para vendedor se multi-filial não tiver registro específico
      if (rows.isEmpty && repCod > 0) {
        rows = await db.rawQuery(
          'SELECT * FROM fincaiccv01 WHERE ccv01_codven = ? LIMIT 1',
          [repCod],
        );
      }

      // Fallback para primeiro registro se ainda não encontrado
      if (rows.isEmpty) {
        rows = await db.rawQuery('SELECT * FROM fincaiccv01 LIMIT 1');
      }

      if (rows.isNotEmpty) {
        return ContaCorrenteSaldo.fromMap(rows.first, dataSincronizacao: dataSinc);
      }
    } catch (_) {}

    return ContaCorrenteSaldo.empty(codFil: filCod, codVen: repCod);
  }

  /// Obtém o histórico analítico de movimentações de CCV (`fincaimovccv00`).
  static Future<List<ContaCorrenteMovimentacao>> obterMovimentacoes({
    int? codVen,
    int? codFil,
    String? filtroTipo, // 'C', 'D' ou null/empty (todos)
    String? busca,
    Database? customDb,
  }) async {
    final db = customDb ?? await LocalSalesDatabaseService.getDatabase();
    final repCod = codVen ?? AppState().vendedor_codigo;
    final filCod = codFil ?? AppState().codFilialAtiva;

    try {
      final whereClauses = <String>[];
      final whereArgs = <dynamic>[];

      if (repCod > 0) {
        whereClauses.add('(ccv00_codven = ? OR ccv00_codven = 0 OR ccv00_codven IS NULL)');
        whereArgs.add(repCod);
      }

      if (filCod > 0) {
        whereClauses.add('(ccv00_codfil = ? OR ccv00_codfil = 0 OR ccv00_codfil IS NULL)');
        whereArgs.add(filCod);
      }

      if (filtroTipo != null && filtroTipo.trim().isNotEmpty && filtroTipo.toUpperCase() != 'TODOS') {
        whereClauses.add('UPPER(ccv00_typmov) = ?');
        whereArgs.add(filtroTipo.toUpperCase());
      }

      if (busca != null && busca.trim().isNotEmpty) {
        whereClauses.add('ccv00_observ LIKE ?');
        whereArgs.add('%${busca.trim()}%');
      }

      final whereSql = whereClauses.isNotEmpty ? 'WHERE ${whereClauses.join(' AND ')}' : '';
      final query = 'SELECT * FROM fincaimovccv00 $whereSql ORDER BY id DESC, ccv00_datmov DESC';

      final rows = await db.rawQuery(query, whereArgs);
      return rows.map((r) => ContaCorrenteMovimentacao.fromMap(r)).toList();
    } catch (_) {
      return [];
    }
  }

  /// Calcula o valor de CCV gerado ou consumido por uma linha de produto.
  /// Fórmula: (digpco - pcomax) * digqtd
  /// Se precoPraticado < precoTabela: resultado negativo (Débito/Consumo).
  /// Se precoPraticado >= precoTabela: resultado positivo ou zero (Crédito comercial).
  static double calcularItemCcv({
    required double precoPraticado,
    required double precoTabela,
    required double quantidade,
  }) {
    final diferenca = precoPraticado - precoTabela;
    return diferenca * quantidade;
  }

  /// Calcula o somatório de CCV de todos os itens ativos de um pedido.
  static double calcularPedidoCcv(List<Map<String, dynamic>> itens) {
    double total = 0.0;
    for (final item in itens) {
      final pcoPrat = (item['digpco'] as num?)?.toDouble() ?? (item['preco_praticado'] as num?)?.toDouble() ?? 0.0;
      final pcoTab = (item['pcomax'] as num?)?.toDouble() ?? (item['preco_tabela'] as num?)?.toDouble() ?? 0.0;
      final qtd = (item['digqtd'] as num?)?.toDouble() ?? (item['quantidade'] as num?)?.toDouble() ?? 0.0;
      total += calcularItemCcv(precoPraticado: pcoPrat, precoTabela: pcoTab, quantidade: qtd);
    }
    return total;
  }

  /// Valida se o saldo disponível de CCV é suficiente para cobrir o desconto concedido.
  /// Equação: `saldoAtual + ccvPedido >= 0`
  static bool validarSaldoCcv({
    required double saldoAtual,
    required double ccvPedido,
  }) {
    return (saldoAtual + ccvPedido) >= 0.0;
  }

  /// Insere uma movimentação de teste/lançamento de CCV (útil para homologação ou estornos).
  static Future<int> registrarMovimentacao({
    required int codFil,
    required int codVen,
    required String dataMovimento,
    required String tipoMovimento,
    required double valorMovimento,
    required double saldoAcumulado,
    required String observacao,
    Database? customDb,
  }) async {
    final db = customDb ?? await LocalSalesDatabaseService.getDatabase();
    return await db.rawInsert('''
      INSERT INTO fincaimovccv00 (
        ccv00_codfil, ccv00_codven, ccv00_datmov, ccv00_typmov,
        ccv00_vlrmov, ccv00_vlrsal, ccv00_observ
      ) VALUES (?, ?, ?, ?, ?, ?, ?)
    ''', [
      codFil,
      codVen,
      dataMovimento,
      tipoMovimento.toUpperCase(),
      valorMovimento.abs(),
      saldoAcumulado,
      observacao,
    ]);
  }
}
