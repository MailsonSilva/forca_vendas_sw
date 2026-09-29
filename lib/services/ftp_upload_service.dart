import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../app_state.dart';
import '../backend/ftp/ftp_client.dart';
import '../backend/ftp/ftp_transport.dart';
import '../backend/schema/structs/index.dart';
import '../data/repositories/cliente_repository.dart';
import 'cliente_ftp_sync_service.dart';
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
    String? pastaUploadTemplate,
    bool enviarClientes = true,
    bool enviarPedidos = true,
    List<String>? arquivosSelecionados,
    List<CargaRegistro>? registros,
    void Function(String nome, int index, int total, double arquivoProgress)?
        onProgress,
  }) async {
    final List<ItemUploadStruct> itens = [];

    // Fallback seguro caso equipe venha nula, zero ou vazia
    final int eqpSegura = codigoEquipe > 0 ? codigoEquipe : 1;

    try {
      final Directory tempDir = await _getTemporaryDirectoryFn();
      final List<File> arquivos = tempDir
          .listSync()
          .whereType<File>()
          .where((f) {
            final nome = p.basename(f.path);
            final lower = nome.toLowerCase();
            if (lower.startsWith('.')) return false;

            if (arquivosSelecionados != null &&
                arquivosSelecionados.isNotEmpty &&
                !arquivosSelecionados.contains(nome)) {
              return false;
            }

            final tipo = classificarTipoArquivo(lower);
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
        final String? template = (pastaUploadTemplate != null && pastaUploadTemplate.trim().isNotEmpty)
            ? pastaUploadTemplate.trim()
            : (AppState().pastaUpload0.isNotEmpty ? AppState().pastaUpload0.trim() : null);

        for (int i = 0; i < total; i++) {
          final File arquivo = arquivos[i];
          final String nome = p.basename(arquivo.path);
          final TipoCarga tipo = classificarTipoArquivo(nome);

          final String targetFolder;
          if (template != null &&
              (template.contains('{codigo_da_equipe}') || template.contains('{codigoEquipe}'))) {
            targetFolder = FtpPathBuilder.resolvePathFromTemplate(
              template: template,
              codigoEquipe: eqpSegura,
            );
          } else {
            targetFolder = FtpPathBuilder.getRemotePath(
              empresa: emp,
              codReg: eqpSegura,
              tipo: tipo,
            );
          }

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
            // marcar JEnviado (sttenv = 2) usando a lista em memória e por pacote.
            final registro = registrosMap[nome];
            if (registro != null) {
              if (registro.tipo == TipoCarga.pedido) {
                await _statusDb.marcarPedidoEnviado(registro.id);
              } else if (registro.tipo == TipoCarga.cliente) {
                await _statusDb.marcarClienteEnviado(registro.id);
              }
            }
            if (tipo == TipoCarga.pedido) {
              await _statusDb.marcarPacoteEnviado(nome);
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

  /// Realiza polling remoto no diretório do FTP aguardando o consumo/retorno do pacote
  /// pela retaguarda ERP Suportware (SPEC-056).
  ///
  /// Critérios de confirmação:
  ///   1. O arquivo `p<codrep>-<ipac>.pac` foi renomeado pela retaguarda (ex: .pro, .lid, sem extensão ou movido)
  ///   OU
  ///   2. Foi gerado o arquivo de retorno correspondente `r<codrep>-<ipac>.ret` (ou .xml / .crg).
  ///
  /// Ao confirmar:
  ///   - Atualiza pedidos locais vinculados para `dig00_sttenv = 3` (e `ped00_sttenv = 3`).
  /// Ao expirar timeout (padrão 60s):
  ///   - Retorna status timeout mantendo o lote como enviado (sttenv = 2) em segundo plano,
  ///     permitindo o retorno seguro sem reenvio.
  Future<PollingRetornoResult> aguardarRetornoPacote({
    required String empresa,
    required int codigoEquipe,
    required int codRep,
    required int ipac,
    String? dirPac,
    String? pastaUploadTemplate,
    Duration intervalo = const Duration(seconds: 5),
    Duration timeout = const Duration(seconds: 60),
    void Function(int tentativa, String mensagem)? onPoll,
  }) async {
    final String nomePacoteOriginal = 'p$codRep-$ipac.pac';
    final String prefixoPac = 'p$codRep-$ipac';
    final String prefixoRet = 'r$codRep-$ipac';

    final String emp = empresa.trim().isEmpty ? 'diniz' : empresa.trim();
    final int eqpSegura = codigoEquipe > 0 ? codigoEquipe : 1;
    final String? template = (pastaUploadTemplate != null && pastaUploadTemplate.trim().isNotEmpty)
        ? pastaUploadTemplate.trim()
        : (AppState().pastaUpload0.isNotEmpty ? AppState().pastaUpload0.trim() : null);

    final String targetFolder = (dirPac != null && dirPac.trim().isNotEmpty)
        ? dirPac.trim()
        : (template != null &&
                (template.contains('{codigo_da_equipe}') || template.contains('{codigoEquipe}'))
            ? FtpPathBuilder.resolvePathFromTemplate(
                template: template,
                codigoEquipe: eqpSegura,
              )
            : FtpPathBuilder.getRemotePath(
                empresa: emp,
                codReg: eqpSegura,
                tipo: TipoCarga.pedido,
              ));

    final DateTime start = DateTime.now();
    int tentativa = 0;

    FtpTransport? ftp;
    try {
      ftp = await _connectFtp();
      await _navegarFtpPasta(ftp, targetFolder);

      while (DateTime.now().difference(start) < timeout) {
        tentativa++;
        onPoll?.call(tentativa, 'Aguardando processamento da retaguarda (tentativa $tentativa)...');

        try {
          final List<String> remoteFiles = await ftp.nlst();
          final List<String> limpos = remoteFiles
              .map((f) => p.basename(f).toLowerCase())
              .toList();

          // 1. Verifica se foi gerado o arquivo de retorno (r<codrep>-<ipac>.ret / .xml)
          final String? retMatch = limpos.cast<String?>().firstWhere(
                (f) =>
                    f != null &&
                    f.startsWith(prefixoRet.toLowerCase()) &&
                    (f.endsWith('.ret') || f.endsWith('.xml') || f.endsWith('.crg')),
                orElse: () => null,
              );

          if (retMatch != null) {
            // Confirmado via arquivo de retorno!
            await _statusDb.marcarPacoteRecebido(nomePacoteOriginal);
            return PollingRetornoResult(
              status: PollingRetornoStatus.confirmado,
              mensagem: 'Processamento confirmado pela retaguarda. Arquivo de retorno detectado.',
              arquivoRetorno: retMatch,
            );
          }

          // 2. Verifica se o arquivo .pac original foi renomeado (ex: .pro, .lid, sem extensão ou outro sufixo)
          final bool existePacOriginal = limpos.contains(nomePacoteOriginal.toLowerCase());
          final bool existeRenomeado = limpos.any((f) =>
              f.startsWith(prefixoPac.toLowerCase()) && !f.endsWith('.pac'));

          if (existeRenomeado || (!existePacOriginal && tentativa > 1)) {
            // Confirmado via renomeação ou consumo do arquivo pela retaguarda!
            await _statusDb.marcarPacoteRecebido(nomePacoteOriginal);
            return const PollingRetornoResult(
              status: PollingRetornoStatus.confirmado,
              mensagem: 'Processamento confirmado pela retaguarda. Lote consumido/renomeado.',
            );
          }
        } catch (_) {
          // Em caso de oscilação transitória no nlst, aguarda e tenta novamente
        }

        await Future.delayed(intervalo);
      }

      // Timeout atingido
      return const PollingRetornoResult(
        status: PollingRetornoStatus.timeout,
        mensagem: 'Lote enviado, aguardando confirmação da retaguarda em segundo plano.',
      );
    } catch (e) {
      return PollingRetornoResult(
        status: PollingRetornoStatus.erro,
        mensagem: 'Erro durante o aguardo de retorno: $e',
      );
    } finally {
      try {
        await ftp?.quit();
      } catch (_) {}
    }
  }

  /// Realiza o envio via FTP dos novos clientes locais (cadclipre00) gerando
  /// arquivos XML puros no protocolo fcfPUTCAD = 10 para o diretório de cadastros.
  Future<UploadPendenteResultStruct> enviarNovosClientesFtp({
    required String codVendedor,
    String? empresa,
    int? codigoEquipe,
    String? dirCAD,
    String? pastaUploadTemplate,
    ClienteRepository? repository,
    void Function(String nome, int index, int total)? onProgress,
  }) async {
    final repo = repository ?? ClienteRepository();
    final novosClientes = await repo.listarNovosClientesPendentes();

    if (novosClientes.isEmpty) {
      return UploadPendenteResultStruct(
        success: true,
        message: 'Nenhum novo cliente pendente de envio.',
        enviados: [],
      );
    }

    final List<ItemUploadStruct> itens = [];
    final Directory tempDir = await _getTemporaryDirectoryFn();
    final String emp = (empresa != null && empresa.trim().isNotEmpty) ? empresa.trim() : 'diniz';
    final int eqp = (codigoEquipe != null && codigoEquipe > 0)
        ? codigoEquipe
        : (int.tryParse(codVendedor) ?? 1);

    final String? template = (pastaUploadTemplate != null && pastaUploadTemplate.trim().isNotEmpty)
        ? pastaUploadTemplate.trim()
        : (AppState().pastaUpload0.isNotEmpty ? AppState().pastaUpload0.trim() : null);

    final String targetFolder = (dirCAD != null && dirCAD.trim().isNotEmpty)
        ? dirCAD.trim()
        : (template != null &&
                (template.contains('{codigo_da_equipe}') || template.contains('{codigoEquipe}'))
            ? FtpPathBuilder.resolvePathFromTemplate(
                template: template,
                codigoEquipe: eqp,
              )
            : FtpPathBuilder.getRemotePath(
                empresa: emp,
                codReg: eqp,
                tipo: TipoCarga.cliente,
              ));

    FtpTransport? ftp;
    try {
      ftp = await _connectFtp();
      await _navegarFtpPasta(ftp, targetFolder);

      final int total = novosClientes.length;
      int sucessoContagem = 0;

      for (int i = 0; i < total; i++) {
        final cliente = novosClientes[i];
        final String xmlContent = ClienteFtpSyncService.gerarXmlNovoCliente(
          cliente: cliente,
          codVendedor: codVendedor,
        );

        final int ms = DateTime.now().millisecondsSinceEpoch % 1000000;
        final String nomeArquivo = 'c$codVendedor-$ms.xml';
        final File arquivoTemp = File(p.join(tempDir.path, nomeArquivo));
        await arquivoTemp.writeAsString(xmlContent, flush: true);

        onProgress?.call(nomeArquivo, i + 1, total);

        try {
          final bytes = await arquivoTemp.readAsBytes();
          await ftp.stor(nomeArquivo, bytes);

          final remoteSize = await ftp.size(nomeArquivo);
          if (remoteSize != bytes.length) {
            throw StateError('Tamanho remoto divergente: $remoteSize de ${bytes.length} bytes.');
          }

          if (cliente.codigo != null) {
            await repo.marcarClienteSincronizado(cliente.codigo!);
            await _statusDb.marcarClienteEnviado(cliente.codigo!);
          }

          itens.add(ItemUploadStruct(
            nome: nomeArquivo,
            sucesso: true,
            mensagem: 'Cliente enviado com sucesso via FTP.',
            bytesEnviados: bytes.length,
            caminhoLocal: arquivoTemp.path,
          ));
          sucessoContagem++;

          try {
            if (await arquivoTemp.exists()) {
              await arquivoTemp.delete();
            }
          } catch (_) {}
        } catch (e) {
          itens.add(ItemUploadStruct(
            nome: nomeArquivo,
            sucesso: false,
            mensagem: 'Falha no envio do cliente: $e',
            bytesEnviados: 0,
            caminhoLocal: arquivoTemp.path,
          ));
        }
      }

      return UploadPendenteResultStruct(
        success: sucessoContagem == total,
        message: '$sucessoContagem de $total novos clientes enviados com sucesso.',
        enviados: itens,
      );
    } catch (e) {
      return UploadPendenteResultStruct(
        success: false,
        message: 'Falha geral no envio de clientes: $e',
        enviados: itens,
      );
    } finally {
      try {
        await ftp?.quit();
      } catch (_) {}
    }
  }
}

/// Estado do polling de retorno da retaguarda ERP
enum PollingRetornoStatus {
  confirmado,
  timeout,
  erro,
}

/// Resultado do polling de retorno do pacote (SPEC-056)
class PollingRetornoResult {
  const PollingRetornoResult({
    required this.status,
    required this.mensagem,
    this.arquivoRetorno,
  });

  final PollingRetornoStatus status;
  final String mensagem;
  final String? arquivoRetorno;

  bool get isConfirmado => status == PollingRetornoStatus.confirmado;
  bool get isTimeout => status == PollingRetornoStatus.timeout;
}
