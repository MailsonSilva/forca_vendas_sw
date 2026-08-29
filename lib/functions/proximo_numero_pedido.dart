import 'dart:io';
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
    final List<String> pathsToCheck = [];
    if (dbPath != null) {
      pathsToCheck.add(dbPath);
    } else {
      pathsToCheck.addAll(await LocalSalesDatabaseService.getTargetDatabasePaths());
    }

    int maxFound = 0;
    for (final path in pathsToCheck) {
      if (!await File(path).exists()) continue;
      try {
        final db = await openDatabase(path, readOnly: true);
        try {
          final t = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table' AND lower(name)='pckvendig000'");
          if (t.isEmpty) continue;

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
            if (n > maxFound) maxFound = n;
          }
        } finally {
          await db.close();
        }
      } catch (_) {}
    }

    return maxFound + 1;
  } catch (e) {
    print('Erro ao obter proximo numero pedido: $e');
    return 1;
  }
}