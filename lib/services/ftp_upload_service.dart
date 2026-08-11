import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../backend/ftp/ftp_client.dart';
import '../backend/ftp/ftp_transport.dart';
import '../backend/schema/structs/index.dart';
import 'ftp_path_builder.dart';
import 'status_envio_db.dart';

/// Orquestração do upload em lote de cargas FTP (pedidos PAC, clientes CAD e
/// arquivos genéricos), equivalente ao `ftpUploadService` do spec.
///
/// Responsabilidades:
///   1. Listar os arquivos pendentes em `getTemporaryDirectory()`.
///   2. Abrir UMA única conexão FTP (via [FtpTransport]).
///   3. Navegar para o caminho dinâmico (`FtpPathBuilder.getRemotePath`).
///   4. Enviar (PUT) com confirmação de tamanho via `SIZE`.
///   5. Em sucesso: atualizar status no SQLite (`StatusEnvioDb`, lifecycle
///      NEnviado → JEnviado) e mover o arquivo para `enviados/`.
///   6. Em falha: manter o arquivo na fila (retry na próxima sincronização).
///
/// As dependências (conexão, diretório temporário e banco) são injetáveis para
/// permitir testes sem rede.
class FtpUploadService {
  FtpUploadService({
    Future<FtpTransport> Function()? connectFtp,
    Future<Directory> Function()? getTemporaryDirectoryFn,
    StatusEnvioDb? statusDb,
  })  : _connectFtp = connectFtp ?? (() => FtpClient.connect()),
        _getTemporaryDirectoryFn =
            getTemporaryDirectoryFn ?? getTemporaryDirectory,
        _statusDb = statusDb ?? StatusEnvioDb();

  final Future<FtpTransport> Function() _connectFtp;
  final Future<Directory> Function() _getTemporaryDirectoryFn;
  final StatusEnvioDb _statusDb;

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
  /// [onProgress] é disparado a cada avanço de um arquivo com o nome, posição
  /// (1-based), total e progresso (0.0–1.0) da transferência atual.
  Future<UploadPendenteResultStruct> enviarArquivosPendentes({
    required String empresa,
    required int codigoEquipe,
    bool enviarClientes = true,
    bool enviarPedidos = true,
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

            await _registrarEnvio(nome);

            itens[i] = ItemUploadStruct(
              nome: nome,
              sucesso: true,
              mensagem: 'Enviado com sucesso. FTP confirmado.',
              bytesEnviados: bytes.length,
              caminhoLocal: arquivo.path,
            );
            sucessoContagem++;

            await _moverParaEnviados(tempDir, arquivo, nome);
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

  /// Atualiza o lifecycle local conforme o tipo do arquivo:
  ///   - pedido `p<rep>-<codMov>`  → `pckvendig000` (JEnviado = 1)
  ///   - cliente `cli_<id>`/`c<rep>-<id>` → `cadcli00` (JEnviado = 1)
  ///
  /// Nomes que não carregam identificador (ex.: inclusão `cli_novo_<cpf>`,
  /// arquivos genéricos) são ignorados — no-op seguro.
  Future<void> _registrarEnvio(String nome) async {
    final tipo = classificarTipoArquivo(nome);
    if (tipo == TipoCarga.pedido) {
      final codMov = int.tryParse(nome.split('-').last);
      if (codMov != null) await _statusDb.marcarPedidoEnviado(codMov);
    } else if (tipo == TipoCarga.cliente) {
      final id = nome
          .replaceFirst(RegExp(r'^cli_', caseSensitive: false), '')
          .split('-')
          .last;
      final codCli = int.tryParse(id);
      if (codCli != null) await _statusDb.marcarClienteEnviado(codCli);
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

  Future<void> _moverParaEnviados(
    Directory tempDir,
    File arquivo,
    String nome,
  ) async {
    final Directory enviadosDir = Directory(p.join(tempDir.path, 'enviados'));
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
      await arquivo.copy(destino.path);
      await arquivo.delete();
    }
  }
}
