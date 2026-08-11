// ignore_for_file: unused_import, duplicate_import, avoid_print

// Imports do app
import '/backend/schema/structs/index.dart';
import '/core/app_theme.dart';
import '/core/app_util.dart';
import '/action_code/index.dart'; // Imports other custom actions
import '/core/app_functions.dart'; // Imports custom functions
import 'package:flutter/material.dart';
// Begin custom action code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../data/services/cliente_xml_generator_service.dart';

/// Gera o XML do cliente no modelo `pckvencli00` da Suportware e o salva em
/// um arquivo temporario (UTF-8) pronto para subir ao FTP posteriormente.
///
/// A montagem do payload é delegada a `ClienteXmlGeneratorService.build`
/// (pura e testável); esta action apenas resolve o nome do arquivo e grava
/// em `getTemporaryDirectory()`.
///
/// Retorna o caminho absoluto do arquivo gerado, ou `null` em caso de erro.
Future<String?> gerarXmlCliente(
  ClienteResultStruct clienteData,
  String codigoVendedor,
) async {
  try {
    final String xml =
        ClienteXmlGeneratorService.build(clienteData, codigoVendedor);

    // Definir identificador unico para o nome do arquivo temporario
    final int codCliInt = clienteData.cli00Codigo;
    final String cpfCnpjLimpo =
        clienteData.cli00Cpfcnp.trim().replaceAll(RegExp(r'[^0-9]'), '');
    final String idArquivo =
        codCliInt == 0 ? 'novo_$cpfCnpjLimpo' : codCliInt.toString();

    final directory = await getTemporaryDirectory();
    final file = File('${directory.path}/cli_$idArquivo');
    await file.writeAsString(xml);

    return file.path;
  } catch (e) {
    print('Erro estrutural ao construir XML de Cliente: $e');
    return null;
  }
}
