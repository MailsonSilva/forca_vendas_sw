import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../backend/ftp/ftp_client.dart';
import '../domain/models/config_empresa_acesso.dart';

/// Serviço responsável por obter e validar a configuração de acesso da empresa
/// a partir do arquivo remoto `ftp://ftp.suportware.com.br/config/acesso.json`.
///
/// Possui cache local para resiliência offline e suporta injeção para testes.
class AcessoFtpService {
  static const String prefKeyCacheAcessoJson = 'cache_acesso_ftp_json';
  static const String prefKeyCacheTimestamp = 'cache_acesso_ftp_timestamp';
  static const Duration defaultTtl = Duration(hours: 1);

  final Future<String> Function()? _baixarConteudoFtpFn;
  final Duration cacheTtl;

  AcessoFtpService({
    Future<String> Function()? baixarConteudoFtpFn,
    this.cacheTtl = defaultTtl,
  }) : _baixarConteudoFtpFn = baixarConteudoFtpFn;

  /// Obtém o JSON do FTP ou do cache local.
  Future<Map<String, dynamic>?> obterJsonAcesso({bool forcarAtualizacao = false}) async {
    SharedPreferences? prefs;
    try {
      prefs = await SharedPreferences.getInstance();
    } catch (_) {}

    // 1. Tenta usar o cache se válido e não forçado
    if (!forcarAtualizacao && prefs != null) {
      final cachedJsonStr = prefs.getString(prefKeyCacheAcessoJson);
      final cachedTimestamp = prefs.getInt(prefKeyCacheTimestamp);
      if (cachedJsonStr != null && cachedTimestamp != null) {
        final dataCache = DateTime.fromMillisecondsSinceEpoch(cachedTimestamp);
        if (DateTime.now().difference(dataCache) < cacheTtl) {
          try {
            final decoded = jsonDecode(cachedJsonStr);
            if (decoded is Map<String, dynamic>) {
              return decoded;
            }
          } catch (_) {}
        }
      }
    }

    // 2. Tenta download remoto do FTP
    try {
      final String jsonRaw;
      final fn = _baixarConteudoFtpFn;
      if (fn != null) {
        jsonRaw = await fn();
      } else {
        jsonRaw = await _baixarAcessoDoFtp();
      }

      final decoded = jsonDecode(jsonRaw);
      if (decoded is Map<String, dynamic>) {
        // Grava no cache
        if (prefs != null) {
          try {
            await prefs.setString(prefKeyCacheAcessoJson, jsonRaw);
            await prefs.setInt(prefKeyCacheTimestamp, DateTime.now().millisecondsSinceEpoch);
          } catch (_) {}
        }
        return decoded;
      }
    } catch (e) {
      debugPrint('[AcessoFtpService] Erro ao baixar acesso.json do FTP: $e');
      // 3. Fallback offline: se falhou o download, usa cache mesmo que expirado
      if (prefs != null) {
        final fallbackCacheStr = prefs.getString(prefKeyCacheAcessoJson);
        if (fallbackCacheStr != null) {
          try {
            final decoded = jsonDecode(fallbackCacheStr);
            if (decoded is Map<String, dynamic>) {
              debugPrint('[AcessoFtpService] Utilizando cache offline de acesso.json.');
              return decoded;
            }
          } catch (_) {}
        }
      }
      rethrow;
    }

    return null;
  }

  /// Baixa o conteúdo do arquivo `acesso.json` (ou fallback `acesso`) do FTP.
  Future<String> _baixarAcessoDoFtp() async {
    FtpClient? ftp;
    try {
      ftp = await FtpClient.connect();
      await ftp.cwd('/config/');

      List<int>? bytes;
      // Tenta prioritariamente acesso.json
      try {
        bytes = await ftp.retr('acesso.json');
      } catch (_) {
        // Fallback para arquivo acesso sem extensão se não existir acesso.json
        try {
          bytes = await ftp.retr('acesso');
        } catch (_) {}
      }

      if (bytes == null || bytes.isEmpty) {
        throw const FormatException('Arquivo acesso.json vazio ou não encontrado no FTP.');
      }

      return utf8.decode(bytes);
    } finally {
      await ftp?.quit();
    }
  }

  /// Busca a configuração de uma empresa pelo código (`codigoEmpresa`).
  ///
  /// Retorna [ConfigEmpresaAcesso] se o código constar nas chaves do JSON,
  /// ou `null` caso contrário.
  Future<ConfigEmpresaAcesso?> buscarConfigEmpresa(String codigoEmpresa) async {
    final cleanCode = codigoEmpresa.trim();
    if (cleanCode.isEmpty) return null;

    Map<String, dynamic>? dadosJson;
    try {
      dadosJson = await obterJsonAcesso();
    } catch (e) {
      debugPrint('[AcessoFtpService] Não foi possível obter JSON de acesso: $e');
      return null;
    }

    if (dadosJson == null || dadosJson.isEmpty) {
      return null;
    }

    // Busca exata ou case-insensitive nas chaves superiores
    String? chaveEncontrada;
    if (dadosJson.containsKey(cleanCode)) {
      chaveEncontrada = cleanCode;
    } else {
      for (final key in dadosJson.keys) {
        if (key.toString().trim().toUpperCase() == cleanCode.toUpperCase()) {
          chaveEncontrada = key;
          break;
        }
      }
    }

    if (chaveEncontrada == null) {
      return null;
    }

    final rawVal = dadosJson[chaveEncontrada];
    if (rawVal is Map<String, dynamic>) {
      return ConfigEmpresaAcesso.fromJson(chaveEncontrada, rawVal);
    } else if (rawVal is Map) {
      return ConfigEmpresaAcesso.fromJson(
        chaveEncontrada,
        Map<String, dynamic>.from(rawVal),
      );
    }

    return null;
  }
}
