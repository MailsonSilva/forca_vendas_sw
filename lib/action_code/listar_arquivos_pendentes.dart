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
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Lista arquivos de sincronizacao no diretorio temporario.
///
/// Quando [prefixo] esta vazio ou `*`, lista todos os arquivos em espera. Os
/// arquivos ja enviados sao lidos de `getTemporaryDirectory()/enviados/` para
/// alimentar o filtro de status da UI.
Future<List<ItemUploadStruct>> listarArquivosPendentes(
  String prefixo,
) async {
  try {
    final Directory tempDir = await getTemporaryDirectory();
    final Directory enviadosDir = Directory(p.join(tempDir.path, 'enviados'));
    final prefix = prefixo.trim();
    final listarTodos = prefix.isEmpty || prefix == '*';

    bool matches(File file) {
      final nome = p.basename(file.path);
      if (nome.startsWith('.')) return false;
      if (listarTodos) return true;
      return nome.startsWith(prefix);
    }

    final List<ItemUploadStruct> itens = [];

    itens.addAll(tempDir
        .listSync()
        .whereType<File>()
        .where(matches)
        .map((f) => ItemUploadStruct(
              nome: p.basename(f.path),
              sucesso: false,
              mensagem: 'Aguardando envio.',
              bytesEnviados: 0,
              caminhoLocal: f.path,
            )));

    if (await enviadosDir.exists()) {
      itens.addAll(enviadosDir
          .listSync()
          .whereType<File>()
          .where(matches)
          .map((f) => ItemUploadStruct(
                nome: p.basename(f.path),
                sucesso: true,
                mensagem: 'Enviado com sucesso.',
                bytesEnviados: f.lengthSync(),
                caminhoLocal: f.path,
              )));
    }

    itens.sort((a, b) => a.nome.toLowerCase().compareTo(b.nome.toLowerCase()));
    return itens;
  } catch (e) {
    print('Erro ao listar pendentes: $e');
    return [];
  }
}
