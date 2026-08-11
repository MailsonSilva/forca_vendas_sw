import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../backend/ftp/ftp_client.dart';
import '../backend/ftp/ftp_transport.dart';
import '../backend/schema/structs/index.dart';
import 'carga_registry_service.dart';
import 'ftp_path_builder.dart';
import 'status_envio_db.dart';

/// Orquestração do upload em lote de cargas FTP (pedidos PAC, clientes CAD e
/// arquivos genéricos), equivalente ao `ftpUploadService` do spec.
///
/// Responsabilidades (conforme o guia `docs/Guia_Upload_FTP_Flutter.md`):
///   1. Listar os arquivos pendentes em `getTemporaryDirectory()`.
///   2. Abrir UMA única conexão FTP (via [FtpTransport]).
///   3. Navegar para o caminho dinâmico (`FtpPathBuilder.getRemotePath`).
///   4. Enviar (PUT) com confirmação de tamanho via `SIZE`.
///   5. Em sucesso: **autorizar** o repositório (`StatusEnvioDb`) a marcar as
///      flags como JEnviado usando a lista em memória (`CargaRegistro`), depois
///      **deletar** o arquivo temporário e remover do manifesto.
///   6. Em falha: manter o arquivo na fila (retry na próxima sincronização).
///
/// A responsabilidade de saber O QUE está sendo enviado (arquivo → id) fica na
/// camada de geração, que popula o manifesto [CargaRegistryService]. A camada
/// de FTP apenas transporta e, mediante sucesso (sem exceção), autoriza a
/// atualização das flags no banco.
///
/// As dependências (conexão, diretório temporário, banco e manifesto) são
/// injetáveis para permitir testes sem rede.
class FtpUploadService {
  FtpUploadService({
    Future<FtpTransport> Function()? connectFtp,
    Future<Directory> Function()? getTemporaryDirectoryFn,
    StatusEnvioDb? statusDb,
    CargaRegistryService? registry,
  })  : _connectFtp = connectFtp ?? (() => FtpClient.connect()),
        _getTemporaryDirectoryFn =
            getTemporaryDirectoryFn ?? getTemporaryDirectory,
        _statusDb = statusDb ?? StatusEnvioDb(),
        _registry = registry ?? CargaRegistryService();

  final Future<FtpTransport> Function() _connectFtp;
  final Future<Directory> Function() _getTemporaryDirectoryFn;
  final StatusEnvioDb _statusDb;
  final CargaRegistryService _registry;

  /// Classifica o arquivo pelo nome conforme a nomenclatura do protocolo:
  ///   - `cli_...` ou `c...`  → [TipoCarga.cliente]  (Customer/)
  ///   - `p...` ou `ped...`   → [TipoCarga.pedido]   (Externo/)
  ///   - demais               → [TipoCarga.uploadGeral] (Upload/)
  static TipoCarga classificarTipoArquivo(String nome) {
    final lower = nome.toLowerCase();
    if (lower.startsWith('cli') || lower.startsWith('c')) {
      return TipoCarga.cliente;
    }
    if (lower.startsWith('p') || lower.startsWith('ped')) {
      return TipoCarga.pedido;
    }
    return TipoCarga.uploadGeral;
  }

  /// Envia todos os arquivos pendentes ao FTP.
  ///
  /// [enviarClientes]/[enviarPedidos] controlam quais tipos entram na fila.
  /// [registros] é a lista em memória (manifesto) que associa cada arquivo ao
  /// seu id; usada para autorizar a marcação de JEnviado após o transporte.
  /// [onProgress] é disparado a cada avanço de um arquivo com o nome, posição
  /// (1-based), total e progresso (0.0–1.0) da transferência atual.
  Future<UploadPendenteResultStruct> enviarArquivosPendentes({
    required String empresa,
    required int codigoEquipe,
    bool enviarClientes = true,
    bool enviarPedidos = true,
    List<CargaRegistro>? registros,
    void Function(String nome, int index, int total, double arquivoProgress)?
        onProgress,
  }) async {
    final List<ItemUploadStruct> itens = [];

    try {
      final Directory tempDir = await _getTemporaryDirectoryFn();
      final List<File> arquivos = tempDir
          .listSync()
          .whereType<File>()
          .where((f) {
            final nome = p.basename(f.path).toLowerCase();
            if (nome.startsWith('.')) return false;

            final tipo = classificarTipoArquivo(nome);
            if (tipo == TipoCarga.cliente && !enviarClientes) return false;
            if (tipo == TipoCarga.pedido && !enviarPedidos) return false;
            return true;
          })
          .toList();

      if (arquivos.isEmpty) {
        return UploadPendenteResultStruct(
          success: true,
          message: 'Nenhum arquivo em espera para envio.',
          enviados: [],
        );
      }

      final registrosMap = <String, CargaRegistro>{
        for (final r in (registros ?? await _registry.listar())) r.arquivo: r,
      };

      for (final f in arquivos) {
        itens.add(ItemUploadStruct(
          nome: p.basename(f.path),
          sucesso: false,
          mensagem: 'Aguardando envio.',
          bytesEnviados: 0,
          caminhoLocal: f.path,
        ));
      }

      final FtpTransport ftp = await _connectFtp();
      try {
        final int total = arquivos.length;
        int sucessoContagem = 0;

        final String emp = empresa.trim().isEmpty ? 'diniz' : empresa.trim();

        for (int i = 0; i < total; i++) {
          final File arquivo = arquivos[i];
          final String nome = p.basename(arquivo.path);
          final TipoCarga tipo = classificarTipoArquivo(nome);

          final String targetFolder = FtpPathBuilder.getRemotePath(
            empresa: emp,
            codReg: codigoEquipe,
            tipo: tipo,
          );

          await _navegarFtpPasta(ftp, targetFolder);

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
                onProgress?.call(
                  nome,
                  i + 1,
                  total,
                  bytes.isEmpty ? 1.0 : (sent / bytes.length).clamp(0.0, 1.0),
                );
              },
            );

            final remoteSize = await ftp.size(nome);
            if (remoteSize != bytes.length) {
              throw StateError(
                'Tamanho remoto divergente: $remoteSize de ${bytes.length} bytes.',
              );
            }

            // Transporte confirmado (sem exceção) → autoriza o repositório a
            // marcar JEnviado usando a lista em memória.
            final registro = registrosMap[nome];
            if (registro != null) {
              if (registro.tipo == TipoCarga.pedido) {
                await _statusDb.marcarPedidoEnviado(registro.id);
              } else if (registro.tipo == TipoCarga.cliente) {
                await _statusDb.marcarClienteEnviado(registro.id);
              }
            }

            itens[i] = ItemUploadStruct(
              nome: nome,
              sucesso: true,
              mensagem: 'Enviado com sucesso. FTP confirmado.',
              bytesEnviados: bytes.length,
              caminhoLocal: arquivo.path,
            );
            sucessoContagem++;

            await _deletarAposEnvio(tempDir, arquivo, nome, registro);
          } catch (e) {
            itens[i] = ItemUploadStruct(
              nome: nome,
              sucesso: false,
              mensagem: 'Falha: $e',
              bytesEnviados: 0,
              caminhoLocal: arquivo.path,
            );
          }
        }

        return UploadPendenteResultStruct(
          success: sucessoContagem == total,
          message: '$sucessoContagem de $total arquivos enviados.',
          enviados: itens,
        );
      } finally {
        await ftp.quit();
      }
    } catch (e) {
      return UploadPendenteResultStruct(
        success: false,
        message: 'Falha de conexao: $e',
        enviados: itens,
      );
    }
  }

  Future<void> _navegarFtpPasta(FtpTransport ftp, String pasta) async {
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

  /// Deleta o arquivo temporário após upload bem-sucedido (guia: passo 6
  /// "Limpeza"). Se houver registro no manifesto, remove a entrada para que a
  /// marcação JEnviado não seja reaplicada em sincronizações futuras.
  Future<void> _deletarAposEnvio(
    Directory tempDir,
    File arquivo,
    String nome,
    CargaRegistro? registro,
  ) async {
    try {
      if (await arquivo.exists()) {
        await arquivo.delete();
      }
      if (registro != null) {
        await _registry.remover(registro.arquivo);
      }
    } catch (e) {
      // Falha na limpeza não deve reprovar o upload já confirmado.
    }
  }
}
