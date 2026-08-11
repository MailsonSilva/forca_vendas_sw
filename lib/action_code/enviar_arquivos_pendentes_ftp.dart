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

import '../services/ftp_upload_service.dart';

/// Envia todos os arquivos em espera no `getTemporaryDirectory()` ao FTP.
///
/// Wrapper fino sobre [FtpUploadService]: a orquestração (conexão única,
/// navegação CWD/MKD, PUT, confirmação por SIZE, atualização do status no
/// SQLite para `JEnviado` e movimentação para `enviados/`) vive no serviço.
///
/// Aqui apenas os parâmetros globais da sessão são lidos de `AppState()` e o
/// progresso é espelhado em `dbSyncStatus`/`dbSyncProgress`/`dbSyncText` para
/// a UI reagir em tempo real.
///
/// Retorna `UploadPendenteResultStruct` com a lista de `ItemUploadStruct`
/// por arquivo (nome, sucesso, mensagem, bytesEnviados) para a UI detalhar.
Future<UploadPendenteResultStruct> enviarArquivosPendentesFtp({bool enviarClientes = true, bool enviarPedidos = true}) async {
  final List<ItemUploadStruct> itens = [];
  try {
    final String empresa = AppState().empresa_codigo.trim().isEmpty
        ? 'diniz'
        : AppState().empresa_codigo.trim();
    final int codigoEquipe = AppState().vendedor_equipe;

    AppState().update(() {
      AppState().dbSyncStatus = 'baixando';
      AppState().dbSyncProgress = 0.0;
      AppState().dbSyncText = 'Conectando ao servidor...';
    });

    final result = await FtpUploadService().enviarArquivosPendentes(
      empresa: empresa,
      codigoEquipe: codigoEquipe,
      enviarClientes: enviarClientes,
      enviarPedidos: enviarPedidos,
      onProgress: (nome, index, total, arquivoProgress) {
        AppState().update(() {
          AppState().dbSyncProgress =
              total > 0 ? (index - 1 + arquivoProgress) / total : 0.0;
          AppState().dbSyncText =
              '${_descricaoEnvio(nome)} ($index/$total)...';
        });
      },
    );

    itens
      ..clear()
      ..addAll(result.enviados);

    AppState().update(() {
      final bool vazio = result.success && result.enviados.isEmpty;
      AppState().dbSyncStatus = vazio ? 'idle' : (result.success ? 'complete' : 'error');
      AppState().dbSyncProgress = vazio ? 0.0 : 1.0;
      AppState().dbSyncText = result.message;
    });

    return result;
  } catch (e) {
    AppState().update(() {
      AppState().dbSyncStatus = 'error';
      AppState().dbSyncText = 'Erro de conexao: $e';
    });
    return UploadPendenteResultStruct(
      success: false,
      message: 'Falha de conexao: $e',
      enviados: itens,
    );
  }
}

String _descricaoEnvio(String nome) {
  final lower = nome.toLowerCase();
  if (lower.startsWith('cli_')) return 'Subindo cadastro $nome';
  if (lower.startsWith('ped') || lower.startsWith('pedido')) {
    return 'Subindo pedido $nome';
  }
  if (lower.contains('cliente')) return 'Subindo alteracao de cliente $nome';
  return 'Subindo arquivo $nome';
}
