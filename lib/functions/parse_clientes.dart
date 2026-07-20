import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:timeago/timeago.dart' as timeago;
import '/core/app_functions.dart';
import '/core/lat_lng.dart';
import '/core/place.dart';
import '/core/uploaded_file.dart';
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
