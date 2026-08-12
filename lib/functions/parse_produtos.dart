import 'dart:convert';

import '/backend/schema/structs/index.dart';

/// DSL custom function parseProdutos
List<ProdutoResultStruct>? parseProdutos(String? jsonStr) {
  if (jsonStr == null || jsonStr.isEmpty) return [];
  try {
    final decoded = jsonDecode(jsonStr);
    if (decoded is! List) return [];
    return decoded
        .map((item) => ProdutoResultStruct.fromMap({
              'codigo': item['codigo']?.toString() ?? '',
              'descricao': item['descricao']?.toString() ?? '',
              'preco': (item['preco'] as num?)?.toDouble() ?? 0.0,
              'saldo_estoque':
                  (item['saldo_estoque'] as num?)?.toDouble() ?? 0.0,
              'unidade': item['unidade']?.toString() ?? '',
            }))
        .toList();
  } catch (e) {
    return [];
  }
}
