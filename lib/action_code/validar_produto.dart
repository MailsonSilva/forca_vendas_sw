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

import '/backend/schema/structs/index.dart';

Future<ValidationResultStruct> validarProduto(
  double precoUnitario,
  double saldoEstoque,
) async {
  if (precoUnitario <= 0) {
    return ValidationResultStruct(
      valido: false,
      mensagem: 'Produto indisponível: Produto sem preço de venda definido.',
    );
  }
  if (saldoEstoque <= 0) {
    return ValidationResultStruct(
      valido: false,
      mensagem: 'Estoque esgotado: O produto está com saldo zerado no momento.',
    );
  }
  return ValidationResultStruct(
    valido: true,
    mensagem: '',
  );
}
