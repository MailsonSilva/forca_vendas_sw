import 'package:flutter/foundation.dart';
import '/backend/schema/structs/index.dart';
import '/data/services/local_sales_database_service.dart';

Future<List<ListaPadraoStruct>> carregarFiltros(String tabela) async {
  try {
    final db = await LocalSalesDatabaseService.getDatabase();

    final t = tabela.toLowerCase().trim();
    String nomeTabelaReal = '';
    String colCodigo = '';
    String colDescri = '';

    if (t.contains('lin')) {
      nomeTabelaReal = 'cadlin00';
      colCodigo = 'lin00_codigo';
      colDescri = 'lin00_descri';
    } else if (t.contains('gru')) {
      nomeTabelaReal = 'cadgru00';
      colCodigo = 'gru00_codigo';
      colDescri = 'gru00_descri';
    } else if (t.contains('for') || t.contains('fab')) {
      nomeTabelaReal = 'cadfor00';
      colCodigo = 'for00_codigo';
      colDescri = 'for00_descri';
    } else {
      nomeTabelaReal = 'cadmar00';
      colCodigo = 'mar00_codigo';
      colDescri = 'mar00_descri';
    }

    final hasTable = (await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name = ?",
      [nomeTabelaReal],
    )).isNotEmpty;

    if (!hasTable) return [];

    final List<Map<String, dynamic>> maps = await db.rawQuery(
        'SELECT $colCodigo, $colDescri FROM $nomeTabelaReal ORDER BY $colDescri');

    return maps.map((m) {
      final codigo = m[colCodigo]?.toString() ?? '';
      final descri = m[colDescri]?.toString() ?? '';

      return ListaPadraoStruct(
        descricao: '$codigo - $descri',
        codigo: codigo,
      );
    }).toList();
  } catch (e) {
    debugPrint('ERRO CARREGAR FILTROS ($tabela): $e');
    return [];
  }
}
