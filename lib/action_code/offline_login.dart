// Imports do app
import '/backend/schema/structs/index.dart';
// Imports other custom actions
// Imports custom functions
// Begin custom action code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

// Imports do app
// Imports other custom actions
// Imports custom functions
// Begin custom action code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

Future<LoginResultStruct> offlineLogin(String vendedorCodigo) async {
  try {
    final codigo = int.tryParse(vendedorCodigo.trim());
    if (codigo == null) {
      return LoginResultStruct.fromMap({
        'success': false,
        'vendedor_codigo': 0,
        'vendedor_nome': '',
      });
    }

    final databasesPath = await getDatabasesPath();
    final db = await openDatabase(
      p.join(databasesPath, 'dbforcacad001.db'),
      readOnly: true,
    );
    final rows = await db.rawQuery(
      'SELECT ven00_codigo, ven00_descri, ven00_codeqp FROM cadrep00 WHERE ven00_codigo = ?',
      [codigo],
    );
    await db.close();

    if (rows.isEmpty) {
      return LoginResultStruct.fromMap({
        'success': false,
        'vendedor_codigo': 0,
        'vendedor_nome': '',
      });
    }

    final row = rows.first;
    return LoginResultStruct.fromMap({
      'success': true,
      'vendedor_codigo': (row['ven00_codigo'] as num?)?.toInt() ?? codigo,
      'vendedor_nome': row['ven00_descri']?.toString() ?? '',
      'vendedor_equipe': (row['ven00_codeqp'] as num?)?.toInt() ?? 0,
    });
  } catch (e) {
    return LoginResultStruct.fromMap({
      'success': false,
      'vendedor_codigo': 0,
      'vendedor_nome': '',
    });
  }
}
