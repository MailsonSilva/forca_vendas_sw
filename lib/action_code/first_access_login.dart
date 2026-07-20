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

import 'package:flutter/foundation.dart' show kIsWeb;
import '/data/repositories/sales_database_repository.dart';

/// Executa o primeiro acesso baixando a carga FTP e instalando o banco local.
///
/// A action atua como adaptador do FlutterFlow: valida argumentos, atualiza
/// AppState usado pela UI e delega FTP/CRG/SQLite ao repositorio.
Future<FirstAccessResultStruct> firstAccessLogin(
  String empresaCodigo,
  String vendedorCodigo,
) async {
  try {
    if (kIsWeb) {
      return FirstAccessResultStruct.fromMap({
        'success': false,
        'message':
            'O download via FTP nao funciona na Web. Teste no celular (APK) ou emulador.',
      });
    }

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

    final config = result.config;
    if (config != null) {
      AppState().pastaDownload0 = config.downloadPath;
      AppState().pastaUpload0 = config.uploadPath;
    }

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
