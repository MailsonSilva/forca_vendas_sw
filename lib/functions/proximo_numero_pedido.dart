import 'dart:io';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

/// Retorna o próximo código sequencial para um novo pedido, calculado como
/// `MAX(ped00_numped) + 1` na tabela `pckvendig000` do banco local.
///
/// Esse sequencial é usado como `codMov` do pedido e como segundo componente
/// do nome do arquivo `.pac` (ex.: `p71-32504.pac`), replicando o legado que
/// numerava os pedidos pela sequência do banco — não por milissegundos Unix.
///
/// Fallback seguro (padrão no-op): se o banco não existir, a tabela não
/// existir ou ocorrer erro, retorna `1` sem lançar exceção.
Future<int> obterProximoNumeroPedido() async {
  try {
    final dbPath = join(await getDatabasesPath(), 'dbforcacad001.db');
    if (!await File(dbPath).exists()) return 1;

    final db = await openDatabase(dbPath);
    try {
      final result = await db.rawQuery(
        'SELECT IFNULL(MAX(ped00_numped), 0) + 1 AS proximo FROM pckvendig000',
      );
      if (result.isEmpty) return 1;
      return (result.first['proximo'] as num).toInt();
    } finally {
      await db.close();
    }
  } catch (_) {
    return 1;
  }
}