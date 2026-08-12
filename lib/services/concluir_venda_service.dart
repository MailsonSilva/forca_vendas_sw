// ignore_for_file: avoid_print
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import '../backend/ftp/ftp_client.dart';
import '../domain/models/pedido_venda.dart';
import '../data/services/pac_xml_generator_service.dart';
import 'carga_registry_service.dart';
import 'ftp_path_builder.dart';
import 'status_envio_db.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ConcluirVendaService — separação de responsabilidades:
//
//   ┌─ gerarESalvarPedidoLocal() ─────────────────────────────────────────────┐
//   │  Chamado ao finalizar/salvar um pedido (concluir_venda_process.dart).   │
//   │  Responsabilidades:                                                     │
//   │    1. Recalcula totais do pedido                                        │
//   │    2. Persiste totais no SQLite (pckvendig000)                          │
//   │    3. Atualiza estatísticas locais                                      │
//   │    4. Gera conteúdo XML (PAC)                                           │
//   │    5. Salva arquivo localmente (temp/ e documents/)                     │
//   │  NÃO faz nenhuma chamada de rede/FTP.                                   │
//   └─────────────────────────────────────────────────────────────────────────┘
//
//   ┌─ enviarPedidoFtp() ─────────────────────────────────────────────────────┐
//   │  Chamado EXCLUSIVAMENTE por: Ferramentas → Dados → Subir Carga          │
//   │  (AtualizarCargaWidget._startUpload via enviarArquivosPendentesFtp).   │
//   │  Responsabilidades:                                                     │
//   │    1. Upload do arquivo XML gerado para o FTP                           │
//   │    2. Atualiza status do pedido no SQLite após envio                    │
//   │    3. Move arquivo da temp/ para enviados/ (auditoria)                 │
//   └─────────────────────────────────────────────────────────────────────────┘
// ─────────────────────────────────────────────────────────────────────────────

class ConcluirVendaService {
  /// Gera e salva o pedido **localmente** (SQLite + arquivo XML em temp/).
  ///
  /// NÃO realiza upload FTP. O arquivo fica em `getTemporaryDirectory()`
  /// aguardando envio manual via Ferramentas → Dados → Subir Carga.
  ///
  /// Retorna o nome do arquivo gerado (ex: 'p71-1007') para uso posterior.
  Future<String> gerarESalvarPedidoLocal({
    required PedidoVenda pedido,
    required String empresa,
    required int codigoEquipe,
  }) async {
    if (pedido.items.isEmpty) {
      throw Exception("Não é possível concluir um pedido sem itens.");
    }

    // 1. Recalcula totais
    pedido.calcularTotais();

    // 2. Persiste totais no cabeçalho SQLite (pckvendig000)
    final dbPath = p.join(await getDatabasesPath(), 'dbforcacad001.db');
    if (await File(dbPath).exists()) {
      final db = await openDatabase(dbPath);
      try {
        final List<Map<String, dynamic>> columns =
            await db.rawQuery('PRAGMA table_info(pckvendig000)');
        final colNames =
            columns.map((r) => r['name']?.toString().toLowerCase()).toSet();

        final List<String> updateParts = [];
        final List<dynamic> binds = [];

        void addUpdate(String col, dynamic val) {
          if (colNames.contains(col.toLowerCase())) {
            updateParts.add('$col = ?');
            binds.add(val);
          }
        }

        addUpdate('ped00_bontot', pedido.bontot);
        addUpdate('ped00_destot', pedido.destot);
        addUpdate('ped00_subtot', pedido.subtot);
        addUpdate('ped00_digtot', pedido.digtot);
        addUpdate('ped00_datsys', pedido.datSys);

        if (updateParts.isNotEmpty) {
          binds.add(pedido.codMov);
          final query =
              'UPDATE pckvendig000 SET ${updateParts.join(', ')} WHERE ped00_numped = ?';
          await db.rawUpdate(query, binds);
        }
      } catch (e) {
        print('Aviso ao persistir totais no SQLite: $e');
      } finally {
        await db.close();
      }
    }

    // 3. Atualiza estatísticas locais (ESTFATCVD00, FINCAICVD00, ESTPRO00)
    await pedido.doUpdateStatistics();

    // 4. Monta o conteúdo XML da carga (PAC) e compacta em ZIP (.pac)
    final String xmlContent = PacXmlGeneratorService.generate(pedido);
    final pacBytes = PacXmlGeneratorService.compressXmlToPac(xmlContent);

    // 5. Define nome do arquivo conforme protocolo legado do guia:
    //    p{codRep}-{codigoSequencialPacote}.pac  ex: p71-32504.pac
    //    A sequência vem de MAX(ped00_numped)+1 do banco local (via codMov).
    final String fileName = FtpPathBuilder.getFileNamePedido(
      pedido.codRep,
      pedido.codMov,
    );

    // 6. Grava localmente: temp/ (fila de upload) e documents/ (backup)
    final tempDir = await getTemporaryDirectory();
    final localFile = File(p.join(tempDir.path, fileName));
    await localFile.writeAsBytes(pacBytes, flush: true);

    final docsDir = await getApplicationDocumentsDirectory();
    final docsFile = File(p.join(docsDir.path, fileName));
    await docsFile.writeAsBytes(pacBytes, flush: true);

    // 7. Registra no manifesto a associação arquivo → id do pedido (em memória).
    //    A camada de FTP só transporta; quem sabe o que está sendo enviado é
    //    esta camada de geração, e o repositório usa esta lista para marcar
    //    JEnviado após o transporte bem-sucedido.
    await CargaRegistryService().registrar(CargaRegistro(
      arquivo: fileName,
      tipo: TipoCarga.pedido,
      id: pedido.codMov,
    ));

    print('[ConcluirVendaService] Pedido #${pedido.codMov} salvo em: ${localFile.path}');
    print('[ConcluirVendaService] FTP pendente — use Ferramentas → Dados → Subir Carga.');

    return fileName;
  }

  // ─── Upload FTP ─────────────────────────────────────────────────────────────
  // Chamado EXCLUSIVAMENTE por: AtualizarCargaWidget._startUpload()
  // via enviarArquivosPendentesFtp() em action_code/enviar_arquivos_pendentes_ftp.dart
  //
  // Para enviar pedidos acesse: Ferramentas → Dados → Subir Carga
  // ────────────────────────────────────────────────────────────────────────────

  /// Envia um pedido já gerado para o FTP.
  ///
  /// Normalmente NÃO é chamado diretamente — o envio em lote de todos os
  /// arquivos pendentes é feito por [enviarArquivosPendentesFtp].
  ///
  /// Use este método apenas para reenvio pontual de um pedido específico.
  Future<bool> enviarPedidoFtp({
    required PedidoVenda pedido,
    required String empresa,
    required int codigoEquipe,
  }) async {
    final String xmlContent = PacXmlGeneratorService.generate(pedido);
    final pacBytes = PacXmlGeneratorService.compressXmlToPac(xmlContent);
    final String fileName = FtpPathBuilder.getFileNamePedido(
      pedido.codRep,
      pedido.codMov,
    );

    final String remotePath = FtpPathBuilder.getRemotePath(
      empresa: empresa.trim().isEmpty ? 'diniz' : empresa.trim(),
      codReg: codigoEquipe,
      tipo: TipoCarga.pedido,
    );

    bool uploadSuccess = false;
    try {
      final FtpClient ftp = await FtpClient.connect();
      try {
        await ftp.cwd('/');
        final segmentos =
            remotePath.split('/').where((s) => s.trim().isNotEmpty);
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
        await ftp.stor(fileName, pacBytes);
        uploadSuccess = true;
        print('[ConcluirVendaService] Upload FTP OK: $remotePath$fileName');
      } finally {
        await ftp.quit();
      }
    } catch (e) {
      print('[ConcluirVendaService] Upload FTP falhou ($e). '
          'Arquivo permanece em temp/ — reenvie via Ferramentas → Dados → Subir Carga.');
    }

    if (uploadSuccess) {
      // Atualiza status do pedido no SQLite para JEnviado (1)
      await StatusEnvioDb().marcarPedidoEnviado(pedido.codMov);

      // Deleta o arquivo temporário do pedido e remove do manifesto (auditoria
      // desnecessária — o guia manda deletar após upload bem-sucedido).
      await _limparTemporarioDoPedido(pedido.codMov);
    }

    return uploadSuccess;
  }

  /// Deleta os arquivos temporários registrados no manifesto para o pedido
  /// [codMov] e remove suas entradas, evitando reenvio duplicado.
  Future<void> _limparTemporarioDoPedido(int codMov) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final registry = CargaRegistryService();
      final registros = await registry.listar();
      for (final reg in registros
          .where((r) => r.tipo == TipoCarga.pedido && r.id == codMov)) {
        final localFile = File(p.join(tempDir.path, reg.arquivo));
        if (await localFile.exists()) {
          await localFile.delete();
        }
        await registry.remover(reg.arquivo);
      }
    } catch (e) {
      print('Aviso ao limpar arquivos temporários do pedido: $e');
    }
  }
}
