// ignore_for_file: unused_import

// Imports do app
import '/backend/schema/structs/index.dart';
import '/core/app_theme.dart';
import '/core/app_util.dart';
import '/action_code/index.dart'; // Imports other custom actions
import '/core/app_functions.dart'; // Imports custom functions
import 'package:flutter/material.dart';
// Begin custom action code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import '/data/repositories/sales_database_repository.dart';

/// Baixa novamente a carga FTP e substitui o SQLite local apos validacao.
Future<FirstAccessResultStruct> downloadDatabaseFromFtp(
  String empresaCodigo,
  String vendedorCodigo,
) async {
  try {
    final empresa = empresaCodigo.trim().toUpperCase();
    final vendedor = vendedorCodigo.trim();
    if (empresa.isEmpty || vendedor.isEmpty) {
      return FirstAccessResultStruct.fromMap({
        'success': false,
        'message': 'Informe empresa e vendedor.',
      });
    }

    final result = await SalesDatabaseRepository().downloadAndInstall(
      companyCode: empresa,
      salespersonCode: vendedor,
    );

    return FirstAccessResultStruct.fromMap({
      'success': true,
      'message': result.message,
    });
  } catch (e) {
    return FirstAccessResultStruct.fromMap({
      'success': false,
      'message': 'Falha ao baixar carga: $e',
    });
  }
}
