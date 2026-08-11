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
import '../services/carga_registry_service.dart';
import '../services/ftp_path_builder.dart';

/// Gera o XML do cliente no modelo `pckvencli00` da Suportware e o salva em
/// um arquivo temporario (UTF-8) pronto para subir ao FTP posteriormente.
///
/// A montagem do payload é delegada a `ClienteXmlGeneratorService.build`
/// (pura e testável); esta action apenas resolve o nome do arquivo, grava em
/// `getTemporaryDirectory()` e registra no manifesto a associação arquivo → id
/// (quem sabe o que está sendo enviado é esta camada de geração).
///
/// Retorna o caminho absoluto do arquivo gerado, ou `null` em caso de erro.
Future<String?> gerarXmlCliente(
  ClienteResultStruct clienteData,
  String codigoVendedor,
) async {
  try {
    final String xml =
        ClienteXmlGeneratorService.build(clienteData, codigoVendedor);

    // Nomenclatura legada do guia:
    //   inclusão (cli00_codigo == 0) → c{codRep}-{ms}.xml
    //   edição                      → c{codRep}-{cli00_codigo}.xml
    final int codRep = int.tryParse(codigoVendedor.trim()) ?? 0;
    final int codCliInt = clienteData.cli00Codigo;
    final String fileName = codCliInt == 0
        ? FtpPathBuilder.getFileNameCliente(
            codRep,
            DateTime.now().millisecondsSinceEpoch,
          )
        : FtpPathBuilder.getFileNameCliente(codRep, codCliInt);

    final directory = await getTemporaryDirectory();
    final file = File('${directory.path}/$fileName');
    await file.writeAsString(xml);

    await CargaRegistryService().registrar(CargaRegistro(
      arquivo: fileName,
      tipo: TipoCarga.cliente,
      id: codCliInt == 0 ? DateTime.now().millisecondsSinceEpoch : codCliInt,
    ));

    return file.path;
  } catch (e) {
    print('Erro estrutural ao construir XML de Cliente: $e');
    return null;
  }
}
