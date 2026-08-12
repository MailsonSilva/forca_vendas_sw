import 'dart:convert';

import '/backend/schema/structs/index.dart';

/// DSL custom function parseClientes
List<ClienteResultStruct>? parseClientes(String? jsonStr) {
  if (jsonStr == null || jsonStr.isEmpty) return [];
  try {
    final decoded = jsonDecode(jsonStr);
    if (decoded is! List) return [];
    return decoded
        .map((item) => ClienteResultStruct.fromMap({
              'codigo': item['codigo']?.toString() ?? '',
              'nome': item['nome']?.toString() ?? '',
              'cpfCnpj': item['cpfCnpj']?.toString() ?? '',
              'cidade': item['cidade']?.toString() ?? '',
              'uf': item['uf']?.toString() ?? '',
            }))
        .toList();
  } catch (e) {
    return [];
  }
}
