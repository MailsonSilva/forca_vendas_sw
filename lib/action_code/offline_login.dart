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
import '../app_state.dart';

Future<LoginResultStruct> offlineLogin(String vendedorCodigo, {String? dbPath}) async {
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
    final path = dbPath ?? p.join(databasesPath, 'dbforcacad001.db');
    Database? db;
    try {
      db = await openDatabase(
        path,
        readOnly: true,
      );
      final rows = await db.rawQuery(
        'SELECT * FROM cadrep00 WHERE ven00_codigo = ?',
        [codigo],
      );

      if (rows.isEmpty) {
        return LoginResultStruct.fromMap({
          'success': false,
          'vendedor_codigo': 0,
          'vendedor_nome': '',
        });
      }

      final row = rows.first;
      // Carregar filial padrão do perfil do representante (ven00_codfil)
      try {
        final codfil = row['ven00_codfil'];
        int filVal = (codfil is num) ? codfil.toInt() : (int.tryParse(codfil?.toString() ?? '') ?? 1);
        if (filVal <= 0) filVal = 1;
        AppState().codFilialAtiva = filVal;
        AppState().filialAtivaDes = 'Filial $filVal';

        // Busca descrição em cadfil00 se existir
        try {
          final tFil = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table' AND lower(name)='cadfil00'");
          if (tFil.isNotEmpty) {
            final filRows = await db.rawQuery('SELECT fil00_descri FROM cadfil00 WHERE fil00_codigo = ? LIMIT 1', [filVal]);
            if (filRows.isNotEmpty && filRows.first['fil00_descri'] != null) {
              AppState().filialAtivaDes = filRows.first['fil00_descri'].toString();
            } else {
              final filFirst = await db.rawQuery('SELECT fil00_codigo, fil00_descri FROM cadfil00 LIMIT 1');
              if (filFirst.isNotEmpty) {
                if (AppState().codFilialAtiva == 1 && filFirst.first['fil00_codigo'] != null) {
                  AppState().codFilialAtiva = int.tryParse(filFirst.first['fil00_codigo'].toString()) ?? 1;
                }
                if (filFirst.first['fil00_descri'] != null) {
                  AppState().filialAtivaDes = filFirst.first['fil00_descri'].toString();
                }
              }
            }
          }
        } catch (_) {}
      } catch (_) {
        if (AppState().codFilialAtiva == 0) {
          AppState().codFilialAtiva = 1;
          AppState().filialAtivaDes = 'Filial Padrão';
        }
      }

      // PRD B4/C3/Carga Completa: carregar parâmetros do representante
      try {
        final cols = await db.rawQuery('PRAGMA table_info(cadrep00)');
        final cn = cols.map((r) => r['name'].toString().toLowerCase()).toSet();
        if (cn.contains('ven00_chkest')) {
          final v = row['ven00_chkest'];
          if (v != null) AppState().ven_chkest = (v as num).toInt();
        }
        if (cn.contains('ven00_selfil')) {
          final v = row['ven00_selfil'];
          if (v != null) AppState().ven_selfil = (v as num).toInt();
        }
        if (cn.contains('ven00_estneg')) {
          final v = row['ven00_estneg'];
          if (v != null) AppState().ven_estneg = (v as num).toInt();
        }
        if (cn.contains('ven00_gerbonfor')) {
          final v = row['ven00_gerbonfor'];
          if (v != null) AppState().ven_gerbonfor = (v as num).toInt();
        }
        if (cn.contains('ven00_chkage')) {
          final v = row['ven00_chkage'];
          if (v != null) AppState().ven_chkage = (v as num).toInt();
        }
        if (cn.contains('ven00_ignlimfis')) {
          final v = row['ven00_ignlimfis'];
          if (v != null) AppState().ven_ignlimfis = (v as num).toInt();
        }
        if (cn.contains('ven00_maxitmdig')) {
          final v = row['ven00_maxitmdig'];
          if (v != null) AppState().ven_maxitmdig = (v as num).toInt();
        }
        if (cn.contains('ven00_passet')) {
          final v = row['ven00_passet'];
          if (v != null) AppState().ven_passet = v.toString().trim();
        }

        // fallback: cadven00
        try {
          final t = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table' AND name='cadven00'");
          if (t.isNotEmpty) {
            final r2 = await db.rawQuery('SELECT * FROM cadven00 LIMIT 1');
            if (r2.isNotEmpty) {
              final m = r2.first;
              if (m['ven00_chkest'] != null && AppState().ven_chkest == 1) AppState().ven_chkest = (m['ven00_chkest'] as num).toInt();
              if (m['ven00_selfil'] != null && AppState().ven_selfil == 0) AppState().ven_selfil = (m['ven00_selfil'] as num).toInt();
              if (m['ven00_gerbonfor'] != null && AppState().ven_gerbonfor == 0) AppState().ven_gerbonfor = (m['ven00_gerbonfor'] as num).toInt();
              if (m['ven00_chkage'] != null && AppState().ven_chkage == 0) AppState().ven_chkage = (m['ven00_chkage'] as num).toInt();
              if (m['ven00_ignlimfis'] != null && AppState().ven_ignlimfis == 0) AppState().ven_ignlimfis = (m['ven00_ignlimfis'] as num).toInt();
              if (m['ven00_maxitmdig'] != null && AppState().ven_maxitmdig == 0) AppState().ven_maxitmdig = (m['ven00_maxitmdig'] as num).toInt();
              if (m['ven00_passet'] != null && AppState().ven_passet.isEmpty) AppState().ven_passet = m['ven00_passet'].toString().trim();
            }
          }
        } catch (_) {}
      } catch (_) {}

      return LoginResultStruct.fromMap({
        'success': true,
        'vendedor_codigo': (row['ven00_codigo'] as num?)?.toInt() ?? codigo,
        'vendedor_nome': row['ven00_descri']?.toString() ?? '',
        'vendedor_equipe': (row['ven00_codeqp'] as num?)?.toInt() ?? 0,
      });
    } finally {
      if (db != null && db.isOpen) {
        await db.close();
      }
    }
  } catch (e) {
    return LoginResultStruct.fromMap({
      'success': false,
      'vendedor_codigo': 0,
      'vendedor_nome': '',
    });
  }
}
