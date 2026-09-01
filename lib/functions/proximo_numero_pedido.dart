import 'package:sqflite/sqflite.dart';
import '../data/services/local_sales_database_service.dart';

/// Retorna o próximo código sequencial para um novo pedido, calculado como
/// `MAX(ped00_numped) + 1` na tabela `pckvendig000` do banco local.
///
/// Esse sequencial é usado como `codMov` do pedido e como segundo componente
/// do nome do arquivo `.pac` (ex.: `p71-32504.pac`), replicando o legado que
/// numerava os pedidos pela sequência do banco — não por milissegundos Unix.
///
/// Fallback seguro (padrão no-op): se o banco não existir, a tabela não
/// existir ou ocorrer erro, retorna `1` sem lançar exceção.
Future<int> obterProximoNumeroPedido({String? dbPath}) async {
  try {
    final bool isCustom = dbPath != null;
    final db = isCustom
        ? await openDatabase(dbPath)
        : await LocalSalesDatabaseService.getDatabase();

    try {
      final t = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND lower(name)='pckvendig000'",
      );
      if (t.isEmpty) return 1;

      final cols = await db.rawQuery('PRAGMA table_info(pckvendig000)');
      final colNames = cols.map((r) => r['name']?.toString().toLowerCase()).toSet();
      String colNum = 'ped00_numped';
      for (final c in ['ped00_numped', 'ped00_pedcod', 'ped00_codmov']) {
        if (colNames.contains(c.toLowerCase())) {
          colNum = c;
          break;
        }
      }

      final result = await db.rawQuery(
        'SELECT IFNULL(MAX($colNum), 0) AS maxval FROM pckvendig000',
      );
      if (result.isNotEmpty) {
        final val = result.first['maxval'];
        final n = (val is num) ? val.toInt() : (int.tryParse(val?.toString() ?? '') ?? 0);
        return n + 1;
      }

      return 1;
    } finally {
      if (isCustom) {
        await db.close();
      }
    }
  } catch (e) {
    print('Erro ao obter proximo numero pedido: $e');
    return 1;
  }
}