import 'dart:convert';
import 'dart:typed_data';
import 'package:path/path.dart' as p;
import '../../backend/ftp/ftp_client.dart';
import '../../backend/ftp/ftp_transport.dart';
import '../../services/ftp_path_builder.dart';
import '../../services/status_envio_db.dart';

/// Resultado do processamento de arquivos de retorno da retaguarda ERP
class ProcessarRetornoResult {
  ProcessarRetornoResult({
    required this.sucesso,
    required this.totalProcessados,
    required this.arquivosProcessados,
    this.mensagem = '',
  });

  final bool sucesso;
  final int totalProcessados;
  final List<String> arquivosProcessados;
  final String mensagem;
}

/// Serviço responsável pelo download, leitura e confirmação de arquivos de
/// retorno de vendas (`r<codRep>-<seq>.ret` / `fcfGETRET = 6`) gerados pela retaguarda ERP.
///
/// Fluxo:
///   1. Conecta ao FTP e navega para o diretório de pacotes (`dirPAC`).
///   2. Lista arquivos remotos iniciados com `r<codRep>-` e com extensão `.ret` ou `.xml`.
///   3. Baixa e interpreta o conteúdo do retorno.
///   4. Transita o status do pedido / pacote para `pvddeRECEBIDO (3)` / `pvpseRetornad (2)`.
///   5. Confirma a leitura com a retaguarda (`fcfRETPED = 11`) ou remove o arquivo de retorno remoto.
class PacoteRetornoService {
  PacoteRetornoService({
    Future<FtpTransport> Function()? connectFtp,
    StatusEnvioDb? statusDb,
  })  : _connectFtp = connectFtp ?? (() => FtpClient.connect()),
        _statusDb = statusDb ?? StatusEnvioDb();

  final Future<FtpTransport> Function() _connectFtp;
  final StatusEnvioDb _statusDb;

  /// Processa todos os arquivos de retorno pendentes no servidor FTP para o representante.
  Future<ProcessarRetornoResult> processarRetornos({
    required String empresa,
    required int codRep,
    int? codReg,
  }) async {
    final List<String> processados = [];

    try {
      final FtpTransport ftp = await _connectFtp();
      try {
        final String emp = empresa.trim().isEmpty ? 'diniz' : empresa.trim();
        final String targetFolder = FtpPathBuilder.getRemotePath(
          empresa: emp,
          codReg: codReg ?? codRep,
          tipo: TipoCarga.pedido,
        );

        // Navega para a pasta remota do lote de pedidos
        await ftp.cwd('/');
        final segmentos = targetFolder.split('/').where((s) => s.trim().isNotEmpty);
        for (final seg in segmentos) {
          try {
            await ftp.cwd(seg.trim());
          } catch (_) {}
        }

        // Lista arquivos remotos no diretório
        final List<String> fileNames = await ftp.nlst();
        final prefixoRetorno = 'r$codRep-'.toLowerCase();

        final List<String> arquivosRetorno = fileNames.where((name) {
          final n = p.basename(name).toLowerCase();
          return n.startsWith(prefixoRetorno) &&
              (n.endsWith('.ret') || n.endsWith('.xml') || n.endsWith('.txt'));
        }).toList();

        if (arquivosRetorno.isEmpty) {
          return ProcessarRetornoResult(
            sucesso: true,
            totalProcessados: 0,
            arquivosProcessados: [],
            mensagem: 'Nenhum arquivo de retorno pendente no servidor.',
          );
        }

        for (final fileName in arquivosRetorno) {
          try {
            final rawBytes = await ftp.retr(fileName);
            final Uint8List bytes = Uint8List.fromList(rawBytes);
            final String conteudo = utf8.decode(bytes, allowMalformed: true);

            // Mapeia o nome do pacote correspondente: r105-1001.ret -> p105-1001.pac
            final String baseName = p.basenameWithoutExtension(fileName);
            final String seqStr = baseName.replaceFirst(RegExp(r'^r[0-9]+-'), '');
            final String pacOriginal = 'p$codRep-$seqStr.pac';

            // Interpreta o retorno: se contém erro fiscal ou se foi aprovado
            final bool isRejeitado = conteudo.toLowerCase().contains('<erro>') ||
                conteudo.toLowerCase().contains('status="rejeitado"') ||
                conteudo.toLowerCase().contains('inconsistencia');

            if (isRejeitado) {
              // Mantém em estado de inconsistência ou notifica
              print('Aviso: Pacote $pacOriginal retornou com inconsistência: $conteudo');
            } else {
              // Marca lote e pedidos como recebidos / confirmados (sttenv = 3)
              await _statusDb.marcarPacoteRecebido(pacOriginal);
            }

            processados.add(fileName);

            // Confirmação de leitura: remove o arquivo de retorno remoto para liberar espaço
            try {
              await ftp.dele(fileName);
            } catch (_) {}
          } catch (e) {
            print('Erro ao processar arquivo de retorno $fileName: $e');
          }
        }

        return ProcessarRetornoResult(
          sucesso: true,
          totalProcessados: processados.length,
          arquivosProcessados: processados,
          mensagem: '${processados.length} arquivo(s) de retorno processado(s) com sucesso.',
        );
      } finally {
        await ftp.quit();
      }
    } catch (e) {
      return ProcessarRetornoResult(
        sucesso: false,
        totalProcessados: processados.length,
        arquivosProcessados: processados,
        mensagem: 'Falha ao buscar retornos do FTP: $e',
      );
    }
  }
}

