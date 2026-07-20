// Imports do app
import '/backend/schema/structs/index.dart';
import '/core/app_theme.dart';
import '/core/app_util.dart';
import '/action_code/index.dart'; // Imports other custom actions
import '/core/app_functions.dart'; // Imports custom functions
import 'package:flutter/material.dart';
// Begin custom action code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

// Imports do app
import '/backend/schema/structs/index.dart';
import '/core/app_theme.dart';
import '/core/app_util.dart';
import '/action_code/index.dart'; // Imports other custom actions
import '/core/app_functions.dart'; // Imports custom functions
import 'package:flutter/material.dart';
// Begin custom action code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

Future<bool> salvarItemPedido(
  String? codigoProduto,
  String? descricao,
  String? unidade,
  String? quantidadeStr,
  double? precoUnitario,
) async {
  try {
    final codigo = codigoProduto ?? '';
    final descricaoNormalizada = descricao ?? '';
    final unidadeNormalizada = unidade ?? '';
    final preco = precoUnitario ?? 0.0;
    if (codigo.isEmpty || preco <= 0) {
      return false;
    }

    final quantidade = double.tryParse(quantidadeStr ?? '') ?? 1.0;
    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, 'dbforcacad001.db');
    final Database db = await openDatabase(path);
    final totalItem = quantidade * preco;
    await db.rawInsert(
      'INSERT OR REPLACE INTO pckvendig010 '
      '(ped10_codprd, ped10_descri, ped10_unidpri, ped10_qtdped, ped10_pcosub, ped10_totprd) '
      'VALUES (?, ?, ?, ?, ?, ?)',
      [
        codigo,
        descricaoNormalizada,
        unidadeNormalizada,
        quantidade,
        preco,
        totalItem,
      ],
    );
    await db.close();
    return true;
  } catch (e) {
    print('Erro ao salvar item de pedido: $e');
    return false;
  }
}
