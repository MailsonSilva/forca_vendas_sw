import 'dart:convert';

import '/app_state.dart';
import '/backend/ftp/ftp_client.dart';
import '/core/services/empresa_logo_service.dart';
import '/data/services/crg_codec.dart';
import '/data/services/local_sales_database_service.dart';
import '/domain/models/sales_access_config.dart';
import '/domain/models/sales_database_install_result.dart';

/// Repositorio da carga de vendas.
///
/// Orquestra FTP, conversao `.crg` e persistencia local. As actions chamam este
/// repositorio como uma fachada, sem conhecer detalhes de transporte ou arquivo.
class SalesDatabaseRepository {
  SalesDatabaseRepository({
    CrgCodec? crgCodec,
    LocalSalesDatabaseService? localDatabase,
  })  : _crgCodec = crgCodec ?? CrgCodec(),
        _localDatabase = localDatabase ?? LocalSalesDatabaseService();

  final CrgCodec _crgCodec;
  final LocalSalesDatabaseService _localDatabase;

  Future<SalesDatabaseInstallResult> downloadAndInstall({
    required String companyCode,
    required String salespersonCode,
  }) async {
    FtpClient? ftp;
    try {
      // 1. Garante que os diretórios locais e paths do SQLite estejam criados
      try {
        final databasesPath = await _localDatabase.databaseFile;
        await databasesPath.parent.create(recursive: true);
      } catch (_) {}

      ftp = await FtpClient.connect();
      final config = await _readAccessConfig(ftp, companyCode);
      if (!config.hasDownloadConfig) {
        return SalesDatabaseInstallResult(
          message: 'Configuracao de download incompleta.',
          config: config,
          success: false,
        );
      }

      await _changeDirectory(ftp, config.downloadPath);

      final crgName = '${config.databaseFilePrefix}$salespersonCode.crg';

      // 2. Verificação de carga remota no FTP antes do download
      List<String> remoteFiles = [];
      try {
        remoteFiles = await ftp.nlst();
      } catch (_) {}

      final bool arquivoEncontrado = remoteFiles.isEmpty ||
          remoteFiles.any((f) {
            final nomeLimpo = f.replaceAll('\\', '/').split('/').last.trim().toLowerCase();
            return nomeLimpo == crgName.toLowerCase();
          });

      if (remoteFiles.isNotEmpty && !arquivoEncontrado) {
        return SalesDatabaseInstallResult(
          message: 'Não há carga disponível para download no momento.',
          config: config,
          success: false,
        );
      }

      // 3. Download do arquivo com proteção de erro
      List<int> crgBytes;
      try {
        crgBytes = await ftp.retr(crgName);
      } catch (_) {
        return SalesDatabaseInstallResult(
          message: 'Não há carga disponível para download no momento.',
          config: config,
          success: false,
        );
      }

      if (crgBytes.isEmpty) {
        return SalesDatabaseInstallResult(
          message: 'Não há carga disponível para download no momento.',
          config: config,
          success: false,
        );
      }

      final databaseBytes = _crgCodec.decodeDatabase(crgBytes);
      await _localDatabase.replaceWithValidatedBytes(databaseBytes);

      try {
        await EmpresaLogoService.instance.sincronizarLogoDoBanco();
      } catch (_) {}

      // Renomeia o arquivo original no FTP (removendo qualquer extensão antiga e formatando ven[cod].[YYYY-MM-DD] [HH-mm-ss])
      try {
        final novoNomeCrg = gerarNomeArquivoRenomeado(crgName, DateTime.now());
        await ftp.rename(crgName, novoNomeCrg);
      } catch (_) {}

      AppState().dataHoraUltimaCarga = DateTime.now();

      return SalesDatabaseInstallResult(
        message: 'Base local atualizada.',
        config: config,
        success: true,
      );
    } catch (e) {
      return SalesDatabaseInstallResult(
        message: 'Falha ao baixar carga: $e',
        success: false,
      );
    } finally {
      await ftp?.quit();
    }
  }

  /// Gera a nomenclatura pós-download exigida pelo servidor FTP:
  /// ven[codVendedor].[YYYY-MM-DD] [HH-mm-ss] (data e hora separados por traço)
  /// Exemplo exato: ven268.2025-03-07 14-08-02
  /// Remove qualquer extensão antiga (.db, .tmp, .crg, etc.)
  static String gerarNomeArquivoRenomeado(String nomeArquivoOriginal, DateTime dataHora) {
    final dotIndex = nomeArquivoOriginal.indexOf('.');
    final base = dotIndex != -1 ? nomeArquivoOriginal.substring(0, dotIndex) : nomeArquivoOriginal;
    final y = dataHora.year.toString().padLeft(4, '0');
    final m = dataHora.month.toString().padLeft(2, '0');
    final d = dataHora.day.toString().padLeft(2, '0');
    final h = dataHora.hour.toString().padLeft(2, '0');
    final min = dataHora.minute.toString().padLeft(2, '0');
    final s = dataHora.second.toString().padLeft(2, '0');
    return '$base.$y-$m-$d $h-$min-$s';
  }

  /// Gera o nome do arquivo remoto renomeado no FTP conforme SPEC-047 (ISO compacto sem extensão):
  /// <nomeOriginalSemExtensao>_<YYYYMMDD_HHmmss>
  /// Exemplo: carga_105.db -> carga_105_20260917_092247
  static String gerarNomeArquivoRenomeadoIso(String nomeArquivoOriginal, DateTime dataHora) {
    final dotIndex = nomeArquivoOriginal.lastIndexOf('.');
    final base = dotIndex != -1 ? nomeArquivoOriginal.substring(0, dotIndex) : nomeArquivoOriginal;
    final y = dataHora.year.toString().padLeft(4, '0');
    final m = dataHora.month.toString().padLeft(2, '0');
    final d = dataHora.day.toString().padLeft(2, '0');
    final h = dataHora.hour.toString().padLeft(2, '0');
    final min = dataHora.minute.toString().padLeft(2, '0');
    final s = dataHora.second.toString().padLeft(2, '0');
    return '${base}_$y$m${d}_$h$min$s';
  }

  Future<void> uploadLocalDatabase({
    required String salespersonCode,
    String? companyCode,
    String? teamCode,
    String? targetPath,
  }) async {
    final emp = (companyCode ?? AppState().empresa_codigo).trim().toLowerCase();
    final empPath = emp.isEmpty ? 'diniz' : emp;
    final eqCode = (teamCode ?? salespersonCode).trim().padLeft(2, '0');
    final path = targetPath ?? '/$empPath/$eqCode/Upload';

    FtpClient? ftp;
    try {
      final databaseBytes = await _localDatabase.readDatabaseBytes();
      final crgBytes = _crgCodec.encodeDatabase(databaseBytes);

      ftp = await FtpClient.connect();
      await _changeDirectory(ftp, path);
      await ftp.stor('ven$salespersonCode.crg', crgBytes);
    } finally {
      await ftp?.quit();
    }
  }

  Future<SalesAccessConfig> _readAccessConfig(
    FtpClient ftp,
    String companyCode,
  ) async {
    await ftp.cwd('/config/');
    final accessBytes = await ftp.retr('acesso');
    final decoded = jsonDecode(utf8.decode(accessBytes));
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Arquivo acesso invalido.');
    }

    Map<String, dynamic>? rawConfig;
    final cleanCode = companyCode.trim();

    if (cleanCode.isNotEmpty && decoded.containsKey(cleanCode)) {
      rawConfig = decoded[cleanCode] as Map<String, dynamic>?;
    } else if (cleanCode.isNotEmpty) {
      for (final k in decoded.keys) {
        if (k.toString().toUpperCase() == cleanCode.toUpperCase() ||
            k.toString().toLowerCase() == cleanCode.toLowerCase()) {
          rawConfig = decoded[k] as Map<String, dynamic>?;
          break;
        }
      }
    }

    // Fallback 1: se não encontrou pelo código exato, procura por correspondência parcial de chaves
    if (rawConfig == null && cleanCode.isNotEmpty) {
      for (final k in decoded.keys) {
        final kStr = k.toString().toLowerCase();
        final cStr = cleanCode.toLowerCase();
        if (kStr.contains(cStr) || cStr.contains(kStr)) {
          rawConfig = decoded[k] as Map<String, dynamic>?;
          break;
        }
      }
    }

    // Fallback 2: se ainda não encontrou, tenta a primeira empresa válida do JSON de acesso
    if (rawConfig == null && decoded.isNotEmpty) {
      for (final v in decoded.values) {
        if (v is Map<String, dynamic> &&
            (v.containsKey('caminho_download') || v.containsKey('pasta_download'))) {
          rawConfig = v;
          break;
        }
      }
    }

    // Fallback 3: constrói configuração padrão de contingência sem estourar StateError
    if (rawConfig == null) {
      final empFallback = cleanCode.isNotEmpty ? cleanCode.toLowerCase() : 'diniz';
      rawConfig = {
        'empresa': empFallback,
        'caminho_download': '/$empFallback/Download/',
        'caminho_upload': '/$empFallback/Upload/',
        'prefixo_arquivo': 'ven',
      };
    }

    final config = SalesAccessConfig.fromMap(rawConfig);
    if (config.nomeEmpresa.isNotEmpty) {
      AppState().empresaNome = config.nomeEmpresa;
    }
    return config;
  }

  /// Consulta o arquivo de configuração no FTP ('/config/acesso') para o [companyCode]
  /// informado (ou AppState().empresa_codigo) e atualiza AppState().empresaNome
  Future<String?> sincronizarNomeEmpresaDoAcessoFtp([String? companyCode]) async {
    final code = (companyCode != null && companyCode.trim().isNotEmpty)
        ? companyCode.trim()
        : AppState().empresa_codigo.trim();
    if (code.isEmpty) return null;

    FtpClient? ftp;
    try {
      ftp = await FtpClient.connect();
      final config = await _readAccessConfig(ftp, code);
      if (config.nomeEmpresa.isNotEmpty) {
        AppState().empresaNome = config.nomeEmpresa;
        return config.nomeEmpresa;
      }
    } catch (_) {
    } finally {
      await ftp?.quit();
    }
    return null;
  }

  Future<void> _changeDirectory(FtpClient ftp, String path) async {
    await ftp.cwd('/');
    final segments =
        path.split('/').where((segment) => segment.trim().isNotEmpty);
    for (final segment in segments) {
      final seg = segment.trim();
      try {
        await ftp.cwd(seg);
      } catch (_) {
        try {
          await ftp.mkd(seg);
          await ftp.cwd(seg);
        } catch (_) {}
      }
    }
  }
}
