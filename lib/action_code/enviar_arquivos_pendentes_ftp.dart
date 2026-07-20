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
import '/backend/ftp/ftp_client.dart';
import '../services/ftp_path_builder.dart';

/// Envia todos os arquivos em espera no `getTemporaryDirectory()` ao FTP em
/// `AppState().pastaUpload0` (preenchido no primeiro acesso).
///
/// Usa UMA unica conexao FTP para subir todos os arquivos. Atualiza
/// `AppState().dbSyncStatus`, `dbSyncProgress` e `dbSyncText` para
/// a UI reagir em tempo real.
///
/// Arquivos enviados com sucesso sao movidos para `getTemporaryDirectory()/enviados/`
/// para evitar reenvio no proximo acionamento e manter auditoria local.
///
/// Retorna `UploadPendenteResultStruct` com a lista de `ItemUploadStruct`
/// por arquivo (nome, sucesso, mensagem, bytesEnviados) para a UI detalhar.
Future<UploadPendenteResultStruct> enviarArquivosPendentesFtp({bool enviarClientes = true, bool enviarPedidos = true}) async {
  final List<ItemUploadStruct> itens = [];
  try {
    // 1. Lista todos os arquivos em espera na raiz temporaria.
    final Directory tempDir = await getTemporaryDirectory();
    final List<FileSystemEntity> arquivos = tempDir
        .listSync()
        .whereType<File>()
        .where((f) {
          final nome = p.basename(f.path).toLowerCase();
          if (nome.startsWith('.')) return false;
          
          bool isCliente = nome.contains('cli') || nome.startsWith('c');
          bool isPedido = nome.contains('ped') || nome.startsWith('p');
          
          // Se for cliente, sobe se enviarClientes for true
          // Se for pedido, sobe se enviarPedidos for true
          // Se não for nenhum dos dois, sobe por padrão (outros arquivos)
          if (isCliente && !enviarClientes) return false;
          if (isPedido && !enviarPedidos) return false;
          
          return true;
        })
        .toList();

    if (arquivos.isEmpty) {
      AppState().dbSyncStatus = 'idle';
      AppState().dbSyncProgress = 0.0;
      AppState().dbSyncText = 'Nenhum arquivo em espera para envio.';
      return UploadPendenteResultStruct(
        success: true,
        message: 'Nenhum arquivo em espera para envio.',
        enviados: [],
      );
    }

    // Pre-popula lista de itens como "pendentes" para a UI ja mostrar.
    for (final f in arquivos) {
      itens.add(ItemUploadStruct(
        nome: p.basename(f.path),
        sucesso: false,
        mensagem: 'Aguardando envio.',
        bytesEnviados: 0,
        caminhoLocal: f.path,
      ));
    }

    AppState().update(() {
      AppState().dbSyncStatus = 'baixando';
      AppState().dbSyncProgress = 0.0;
      AppState().dbSyncText = 'Conectando ao servidor...';
    });

    // 2. Abre UMA unica conexao FTP (credenciais centralizadas em FtpConfig).
    final FtpClient ftp = await FtpClient.connect();

    try {
      final int total = arquivos.length;
      int sucessoContagem = 0;

      final String emp = AppState().empresa_codigo.trim().isEmpty
          ? 'diniz'
          : AppState().empresa_codigo.trim();
      final int eqCode = AppState().vendedor_codigo;

      for (int i = 0; i < total; i++) {
        final File arquivo = arquivos[i] as File;
        final String nome = p.basename(arquivo.path);
        final String lowerNome = nome.toLowerCase();

        TipoCarga tipo;
        if (lowerNome.contains('cli') || lowerNome.startsWith('c')) {
          tipo = TipoCarga.cliente;
        } else if (lowerNome.startsWith('p') || lowerNome.contains('ped')) {
          tipo = TipoCarga.pedido;
        } else {
          tipo = TipoCarga.uploadGeral;
        }

        final targetFolder = FtpPathBuilder.getRemotePath(
          empresa: emp,
          codReg: eqCode,
          tipo: tipo,
        );

        await _navegarFtpPasta(ftp, targetFolder);

        AppState().update(() {
          AppState().dbSyncProgress = total > 1 ? i / total : 0.0;
          AppState().dbSyncText =
              '${_descricaoEnvio(nome)} (${i + 1}/$total)...';
        });

        final bytes = await arquivo.readAsBytes();
        try {
          await ftp.stor(
            nome,
            bytes,
            onProgress: (sent) {
              itens[i] = ItemUploadStruct(
                nome: nome,
                sucesso: false,
                mensagem: 'Enviando...',
                bytesEnviados: sent,
                caminhoLocal: arquivo.path,
              );
              AppState().update(() {
                final arquivoProgress =
                    bytes.isEmpty ? 1.0 : sent / bytes.length;
                AppState().dbSyncProgress =
                    (i + arquivoProgress.clamp(0.0, 1.0)) / total;
                AppState().dbSyncText =
                    '${_descricaoEnvio(nome)} (${i + 1}/$total)...';
              });
            },
          );

          final remoteSize = await ftp.size(nome);
          if (remoteSize != bytes.length) {
            throw StateError(
              'Tamanho remoto divergente: $remoteSize de ${bytes.length} bytes.',
            );
          }

          itens[i] = ItemUploadStruct(
            nome: nome,
            sucesso: true,
            mensagem: 'Enviado com sucesso. FTP confirmado.',
            bytesEnviados: bytes.length,
            caminhoLocal: arquivo.path,
          );
          sucessoContagem++;

          // 6. Move o arquivo para enviados/ (auditoria + evita reenvio).
          final Directory enviadosDir =
              Directory(p.join(tempDir.path, 'enviados'));
          if (!await enviadosDir.exists()) {
            await enviadosDir.create(recursive: true);
          }
          final File destino = File(p.join(enviadosDir.path, nome));
          if (await destino.exists()) {
            await destino.delete();
          }
          try {
            await arquivo.rename(destino.path);
          } on FileSystemException {
            // Em algumas plataformas o rename cross-device falha; copia+deleta.
            await arquivo.copy(destino.path);
            await arquivo.delete();
          }
        } catch (e) {
          itens[i] = ItemUploadStruct(
            nome: nome,
            sucesso: false,
            mensagem: 'Falha: $e',
            bytesEnviados: 0,
            caminhoLocal: arquivo.path,
          );
          print('Erro ao subir $nome: $e');
        }
      }

      AppState().update(() {
        AppState().dbSyncProgress = 1.0;
        AppState().dbSyncText = '$sucessoContagem de $total enviados.';
        AppState().dbSyncStatus =
            sucessoContagem == total ? 'complete' : 'error';
      });

      return UploadPendenteResultStruct(
        success: sucessoContagem == total,
        message: '$sucessoContagem de $total arquivos enviados.',
        enviados: itens,
      );
    } finally {
      await ftp.quit();
    }
  } catch (e) {
    AppState().update(() {
      AppState().dbSyncStatus = 'error';
      AppState().dbSyncText = 'Erro de conexao: $e';
    });
    print('Erro critico no envio de pendentes: $e');
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

Future<void> _navegarFtpPasta(FtpClient ftp, String pasta) async {
  await ftp.cwd('/');
  final segmentos = pasta.split('/').where((s) => s.trim().isNotEmpty);
  for (final seg in segmentos) {
    final s = seg.trim();
    try {
      await ftp.cwd(s);
    } catch (_) {
      try {
        await ftp.mkd(s);
        await ftp.cwd(s);
      } catch (_) {}
    }
  }
}

