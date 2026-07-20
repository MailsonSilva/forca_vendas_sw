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

/// Compacta o banco SQLite local em `.crg` e envia ao FTP.
Future<FirstAccessResultStruct> uploadDatabaseToFtp(
  String vendedorCodigo,
) async {
  try {
    final vendedor = vendedorCodigo.trim();
    if (vendedor.isEmpty) {
      return FirstAccessResultStruct.fromMap({
        'success': false,
        'message': 'Codigo do vendedor nao informado.',
      });
    }

    await SalesDatabaseRepository().uploadLocalDatabase(
      salespersonCode: vendedor,
    );

    return FirstAccessResultStruct.fromMap({
      'success': true,
      'message': 'Banco de dados enviado com sucesso.',
    });
  } catch (e) {
    return FirstAccessResultStruct.fromMap({
      'success': false,
      'message': 'Falha ao subir carga: $e',
    });
  }
}
