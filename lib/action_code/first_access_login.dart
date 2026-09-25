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
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import '../app_state.dart';
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
      if (config.nomeEmpresa.isNotEmpty) {
        AppState().empresaNome = config.nomeEmpresa;
      }
    }
    AppState().empresa_codigo = empresa;
    // PRD B4/C3: carregar ven00_chkest/gerbonfor após instalação
    try {
      final dbPath = p.join(await getDatabasesPath(), 'dbforcacad001.db');
      final db = await openDatabase(dbPath, readOnly: true);
      final cols = await db.rawQuery('PRAGMA table_info(cadrep00)');
      final cn = cols.map((r) => r['name'].toString().toLowerCase()).toSet();
      final vid = int.tryParse(vendedor) ?? 0;
      if (cn.contains('ven00_chkest') || cn.contains('ven00_gerbonfor')) {
        final rows = await db.rawQuery('SELECT ven00_chkest, ven00_gerbonfor FROM cadrep00 WHERE ven00_codigo = ? LIMIT 1', [vid]);
        if (rows.isNotEmpty) {
          final m = rows.first;
          if (m['ven00_chkest'] != null) AppState().ven_chkest = (m['ven00_chkest'] as num).toInt();
          if (m['ven00_gerbonfor'] != null) AppState().ven_gerbonfor = (m['ven00_gerbonfor'] as num).toInt();
        }
      }
      await db.close();
    } catch (_) {}

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
