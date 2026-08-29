// Imports do app
// Imports other custom actions
// Imports custom functions
// Begin custom action code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

// Imports do app
// Imports other custom actions
// Imports custom functions
// Begin custom action code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

/// PRD C5: higienizado — requer ped10_numped. Sem numped o insert é bloqueado.
Future<bool> salvarItemPedido(
  String? codigoProduto,
  String? descricao,
  String? unidade,
  String? quantidadeStr,
  double? precoUnitario, [
  int? pedidoId,
]) async {
  // Compat: se chamado sem pedidoId, log deprecado e aborta (não faz DELETE sem WHERE)
  if (pedidoId == null) {
    print('[salvarItemPedido] DEPRECATED: sem ped10_numped — use salvarCarrinhoPedido. Abortado.');
    return false;
  }
  try {
    final codigo = codigoProduto ?? '';
    final descricaoNormalizada = descricao ?? '';
    final unidadeNormalizada = unidade ?? '';
    final preco = precoUnitario ?? 0.0;
    if (codigo.isEmpty || preco <= 0) {
      return false;
    }

    final quantidade = double.tryParse(quantidadeStr ?? '') ?? 1.0;
    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, 'dbforcacad001.db');
    final Database db = await openDatabase(path);
    final cols = await db.rawQuery('PRAGMA table_info(pckvendig010)');
    final colNames = cols.map((r) => r['name']?.toString().toLowerCase()).toSet();
    final totalItem = quantidade * preco;
    // Monta insert dinâmico com ped10_numped obrigatório
    final insertCols = <String>[];
    final placeholders = <String>[];
    final binds = <dynamic>[];
    void add(String col, dynamic val) {
      if (colNames.contains(col.toLowerCase())) {
        insertCols.add(col);
        placeholders.add('?');
        binds.add(val);
      }
    }
    add('ped10_numped', pedidoId);
    add('ped10_codprd', codigo);
    add('ped10_descri', descricaoNormalizada);
    add('ped10_unidpri', unidadeNormalizada);
    add('ped10_qtdped', quantidade);
    add('ped10_pcosub', preco);
    add('ped10_totprd', totalItem);
    if (insertCols.isEmpty) {
      await db.close();
      return false;
    }
    await db.rawInsert(
      'INSERT OR REPLACE INTO pckvendig010 (${insertCols.join(', ')}) VALUES (${placeholders.join(', ')})',
      binds,
    );
    await db.close();
    return true;
  } catch (e) {
    print('Erro ao salvar item de pedido: $e');
    return false;
  }
}
