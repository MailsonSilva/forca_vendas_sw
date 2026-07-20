// Imports do app
import '/backend/schema/structs/index.dart';
import '/core/app_theme.dart';
import '/core/app_util.dart';
import '/action_code/index.dart'; // Imports other custom actions
import '/core/app_functions.dart'; // Imports custom functions
import 'package:flutter/material.dart';
// Begin custom action code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

// Set your action name, define your arguments and return parameter,
// and then add the boilerplate code using the `</>` button on the right!
import '/app_state.dart';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:convert';
import 'dart:isolate';
import 'dart:async';

class _SyncTaskArgs {
  final SendPort sendPort;
  final String modo;
  final String baseUrl;
  final String documentsDirPath;
  final String subdir;

  _SyncTaskArgs({
    required this.sendPort,
    required this.modo,
    required this.baseUrl,
    required this.documentsDirPath,
    required this.subdir,
  });
}

/// Função isolada que roda na thread de segundo plano (Background Isolate)
void _backgroundSyncTask(_SyncTaskArgs args) async {
  final sendPort = args.sendPort;
  final modo = args.modo;
  final baseUrl = args.baseUrl;
  final documentsDirPath = args.documentsDirPath;
  final subdir = args.subdir;

  int total = 0;
  int ok = 0;
  int falhas = 0;

  try {
    // 1. Cria a pasta física de destino se não existir
    final targetDir = Directory('$documentsDirPath/$subdir');
    if (!await targetDir.exists()) {
      await targetDir.create(recursive: true);
    }

    // 2. Define o arquivo de manifesto correto baseado no parâmetro 'modo'
    // Se o modo for 'novas', lê o arquivo parcial, caso contrário lê o full.
    final String manifestoFile =
        (modo == 'parcial') ? '_partial.txt' : '_full.txt';
    final String manifestoUrl = '$baseUrl/$manifestoFile';

    final response = await http.get(Uri.parse(manifestoUrl)).timeout(
          const Duration(seconds: 15),
        );

    if (response.statusCode != 200) {
      throw Exception(
          "Erro ao buscar manifesto no servidor (Status: ${response.statusCode} em $manifestoFile)");
    }

    // Como o manifesto agora é um arquivo de texto (.txt), dividimos o conteúdo linha por linha
    final List<String> listaImagens = response.body
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();

    total = listaImagens.length;

    // Envia o estado inicial para a UI
    sendPort.send({
      'status': 'baixando',
      'total': total,
      'ok': ok,
      'modo': modo,
      'falhas': falhas,
    });

    int lastSentOk = 0;
    // 3. Loop de download das imagens por demanda
    for (var imgName in listaImagens) {
      bool statusChanged = false;
      try {
        final file = File('${targetDir.path}/$imgName');

        // Se o modo for inteligente (apenas novas) e o arquivo já existe fisicamente, pula o download
        if (modo == 'parcial' && await file.exists()) {
          ok++;
          if (ok - lastSentOk >= 50) {
            statusChanged = true;
          }
        } else {
          // Executa o download da imagem física individual
          final imgResponse =
              await http.get(Uri.parse('$baseUrl/$imgName')).timeout(
                    const Duration(seconds: 10),
                  );

          if (imgResponse.statusCode == 200) {
            await file.writeAsBytes(imgResponse.bodyBytes);
            ok++;
          } else {
            falhas++;
          }
          statusChanged = true;
        }
      } catch (_) {
        falhas++;
        statusChanged = true;
      }

      // Envia atualização de progresso contínuo para a UI principal
      if (statusChanged || ok == total) {
        lastSentOk = ok;
        sendPort.send({
          'status': 'baixando',
          'total': total,
          'ok': ok,
          'modo': modo,
          'falhas': falhas,
        });
      }
    }

    // Notifica conclusão com sucesso
    sendPort.send({
      'status': 'complete',
      'total': total,
      'ok': ok,
      'modo': modo,
      'falhas': falhas,
    });
  } catch (e) {
    sendPort.send({
      'status': 'error',
      'total': total,
      'ok': ok,
      'modo': modo,
      'erro_fatal': e.toString(),
      'falhas': falhas,
    });
  }
}

Future<dynamic> sincronizarImagens(
  BuildContext context,
  String modo,
) async {
  final String baseUrl = "http://heh08x312dp.sn.mynetname.net:8080/catalogo";
  final String subdir = "images/catalogo_imagens";

  final directory = await getApplicationDocumentsDirectory();
  final documentsDirPath = directory.path;

  final receivePort = ReceivePort();
  final completer = Completer<dynamic>();

  final args = _SyncTaskArgs(
    sendPort: receivePort.sendPort,
    modo: modo,
    baseUrl: baseUrl,
    documentsDirPath: documentsDirPath,
    subdir: subdir,
  );

  // Inicializa o estado reativo global de forma segura usando mutação nativa do Flutter
  AppState().update(() {
    AppState().imgSyncStatus = 'baixando';
    AppState().imgSyncProgress = 0.0;
    AppState().imgSyncText = "Preparando carga de fotos...";
  });

  // Dispara a Thread separada (Isolate)
  await Isolate.spawn(_backgroundSyncTask, args);

  // Ouve os eventos disparados de dentro da thread em segundo plano
  receivePort.listen((msg) {
    if (msg is Map<String, dynamic>) {
      final String status = msg['status'] ?? 'idle';
      final int total = msg['total'] ?? 0;
      final int ok = msg['ok'] ?? 0;

      if (status == 'baixando' && total > 0) {
        // Atualiza a barra de progresso continuamente
        AppState().update(() {
          AppState().imgSyncProgress = ok / total;
          AppState().imgSyncText = "Baixando imagem $ok de $total...";
        });
      } else if (status == 'complete') {
        AppState().update(() {
          AppState().imgSyncStatus = 'complete';
          AppState().imgSyncProgress = 1.0;
          AppState().imgSyncText = "Concluído! $ok fotos salvas.";
        });
        receivePort.close();
        completer.complete(true);

        if (appNavigatorKey.currentContext != null) {
          ScaffoldMessenger.of(appNavigatorKey.currentContext!).showSnackBar(
            SnackBar(
              content: Text(
                "Todas as $ok imagens do catálogo foram atualizadas com sucesso!",
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              backgroundColor: const Color(0xFF5CB85C),
            ),
          );
        }
      } else if (status == 'error') {
        AppState().update(() {
          AppState().imgSyncStatus = 'error';
          AppState().imgSyncProgress = 0.0;
          AppState().imgSyncText = "Falha ao baixar imagens.";
        });
        receivePort.close();
        completer.completeError(msg['erro_fatal'] ?? 'Erro desconhecido');

        if (appNavigatorKey.currentContext != null) {
          ScaffoldMessenger.of(appNavigatorKey.currentContext!).showSnackBar(
            SnackBar(
              content: Text("Erro na sincronização: ${msg['erro_fatal']}"),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  });

  return completer.future;
}
