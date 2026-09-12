import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import '../../data/services/local_sales_database_service.dart';

/// Gerenciador centralizado da logomarca da empresa/distribuidora.
///
/// Responsável por extrair o binário de `cadace00.srv00_imglog`, armazená-lo em cache local
/// no disco (`empresa_logo.png`) e na memória, fornecer fallback para o asset oficial da Suportware,
/// e gerenciar as preferências de exibição da logomarca no PDF do pedido.
class EmpresaLogoService {
  static const String cacheFileName = 'empresa_logo.png';
  static const String fallbackAsset = 'assets/images/DentixIA_Logo_(500_x_500_px).png';
  static const String prefKeyExibirLogoPdf = 'config_exibir_logo_pdf';

  static final EmpresaLogoService _instance = EmpresaLogoService._internal();
  static EmpresaLogoService get instance => _instance;

  final String? _customCacheDir;
  Uint8List? _cachedLogoBytes;

  EmpresaLogoService({String? customCacheDir})
      : _customCacheDir = customCacheDir;

  EmpresaLogoService._internal() : _customCacheDir = null;

  /// Retorna o diretório onde o arquivo de cache da logo deve ser armazenado.
  Future<String> _getCacheDirectoryPath() async {
    if (_customCacheDir != null && _customCacheDir!.isNotEmpty) {
      return _customCacheDir!;
    }
    final dir = await getApplicationDocumentsDirectory();
    return dir.path;
  }

  /// Retorna a referência do arquivo em disco para o cache da imagem.
  Future<File> _getCacheFile() async {
    final dirPath = await _getCacheDirectoryPath();
    return File('$dirPath/$cacheFileName');
  }

  /// Decodifica com segurança o valor de `srv00_imglog` para [Uint8List].
  ///
  /// Trata:
  /// - String Base64 pura (com ou sem quebras de linha/espaços).
  /// - Data URI (ex: `data:image/png;base64,...`).
  /// - [Uint8List] ou [List<int>] contendo binário direto ou texto Base64 em bytes ASCII.
  /// Retorna `null` caso os dados sejam nulos, vazios ou inválidos.
  static Uint8List? decodificarBase64OuBinario(dynamic rawData) {
    if (rawData == null) return null;

    try {
      if (rawData is String) {
        String str = rawData.trim();
        if (str.isEmpty) return null;

        // Remove prefixo data URI se houver
        final commaIdx = str.indexOf(',');
        if (str.toLowerCase().startsWith('data:image/') && commaIdx != -1) {
          str = str.substring(commaIdx + 1);
        }

        // Remove quebras de linha e espaços
        str = str.replaceAll('\n', '').replaceAll('\r', '').replaceAll(' ', '').trim();
        if (str.isEmpty) return null;

        return Uint8List.fromList(base64Decode(str));
      }

      if (rawData is Uint8List) {
        if (rawData.isEmpty) return null;
        if (_pareceBase64Ascii(rawData)) {
          final decoded = _tentarDecodificarBytesComoStringBase64(rawData);
          if (decoded != null && decoded.isNotEmpty) return decoded;
        }
        return rawData;
      }

      if (rawData is List<int>) {
        if (rawData.isEmpty) return null;
        final uint8 = Uint8List.fromList(rawData);
        if (_pareceBase64Ascii(uint8)) {
          final decoded = _tentarDecodificarBytesComoStringBase64(uint8);
          if (decoded != null && decoded.isNotEmpty) return decoded;
        }
        return uint8;
      }
    } catch (_) {
      return null;
    }

    return null;
  }

  static bool _pareceBase64Ascii(Uint8List bytes) {
    if (bytes.length < 4) return false;
    // Se começar com assinaturas binárias de imagens conhecidas, não é texto base64
    // PNG: 0x89 0x50 0x4E 0x47
    if (bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E && bytes[3] == 0x47) return false;
    // JPEG: 0xFF 0xD8 0xFF
    if (bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) return false;
    // GIF: 'G' 'I' 'F' (0x47 0x49 0x46)
    if (bytes[0] == 0x47 && bytes[1] == 0x49 && bytes[2] == 0x46) return false;
    // WEBP: 'R' 'I' 'F' 'F'
    if (bytes[0] == 0x52 && bytes[1] == 0x49 && bytes[2] == 0x46 && bytes[3] == 0x46) return false;
    // BMP: 'B' 'M'
    if (bytes[0] == 0x42 && bytes[1] == 0x4D) return false;

    // Se os primeiros bytes são caracteres ASCII imprimíveis, pode ser texto base64
    final checkLen = bytes.length < 64 ? bytes.length : 64;
    for (int i = 0; i < checkLen; i++) {
      final b = bytes[i];
      if (b < 9 || (b > 13 && b < 32) || b > 126) {
        return false;
      }
    }
    return true;
  }

  static Uint8List? _tentarDecodificarBytesComoStringBase64(Uint8List bytes) {
    try {
      final str = utf8.decode(bytes, allowMalformed: false);
      return decodificarBase64OuBinario(str);
    } catch (_) {
      return null;
    }
  }

  /// Extrai o campo `srv00_imglog` da tabela `cadace00` no [db] informado,
  /// decodifica de Base64 para binário e persiste em arquivo local (`empresa_logo.png`).
  ///
  /// Se a tabela ou coluna não existir, ou se o valor for nulo/inválido,
  /// o cache anterior é descartado e retorna `null`.
  Future<Uint8List?> extrairLogoDaCarga(Database db) async {
    try {
      final tableCheck = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND lower(name)='cadace00'",
      );
      if (tableCheck.isEmpty) {
        await _limparCache();
        return null;
      }

      final rows = await db.rawQuery(
        'SELECT srv00_imglog FROM cadace00 WHERE srv00_imglog IS NOT NULL LIMIT 1',
      );

      if (rows.isEmpty || rows.first['srv00_imglog'] == null) {
        await _limparCache();
        return null;
      }

      final rawData = rows.first['srv00_imglog'];
      final bytes = decodificarBase64OuBinario(rawData);

      if (bytes != null && bytes.isNotEmpty) {
        _cachedLogoBytes = bytes;
        final file = await _getCacheFile();
        await file.parent.create(recursive: true);
        await file.writeAsBytes(bytes, flush: true);
        return bytes;
      } else {
        await _limparCache();
        return null;
      }
    } catch (_) {
      await _limparCache();
      return null;
    }
  }

  /// Limpa cache em memória e em disco.
  Future<void> _limparCache() async {
    _cachedLogoBytes = null;
    try {
      final file = await _getCacheFile();
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {}
  }

  /// Sincroniza a logomarca abrindo o banco SQLite local do aplicativo.
  Future<Uint8List?> sincronizarLogoDoBanco() async {
    Database? db;
    try {
      if (await LocalSalesDatabaseService().exists()) {
        db = await LocalSalesDatabaseService.getDatabase(readOnly: true);
        return await extrairLogoDaCarga(db);
      }
    } catch (_) {
    } finally {
      if (db != null && db.isOpen) {
        await db.close();
      }
    }
    return null;
  }

  /// Recupera os bytes da logomarca.
  ///
  /// Primeiro verifica o cache em memória, depois o arquivo em disco.
  /// Caso ainda não esteja em cache e uma instância de [db] seja informada
  /// (ou haja banco local disponível), tenta extrair e salvar em cache.
  Future<Uint8List?> obterLogoBytes({Database? db}) async {
    if (_cachedLogoBytes != null && _cachedLogoBytes!.isNotEmpty) {
      return _cachedLogoBytes;
    }

    try {
      final file = await _getCacheFile();
      if (await file.exists()) {
        final bytes = await file.readAsBytes();
        if (bytes.isNotEmpty) {
          _cachedLogoBytes = bytes;
          return bytes;
        }
      }
    } catch (_) {}

    if (db != null) {
      return await extrairLogoDaCarga(db);
    }

    // Tenta carregar do banco de dados local se existir
    return await sincronizarLogoDoBanco();
  }

  /// Retorna se a exibição do logotipo no PDF está habilitada.
  ///
  /// Padrão: `true`.
  Future<bool> isExibirLogoPdfHabilitado({SharedPreferences? prefs}) async {
    try {
      final sp = prefs ?? await SharedPreferences.getInstance();
      return sp.getBool(prefKeyExibirLogoPdf) ?? true;
    } catch (_) {
      return true;
    }
  }

  /// Define a preferência de exibição do logotipo no PDF.
  Future<void> setExibirLogoPdf(bool valor, {SharedPreferences? prefs}) async {
    try {
      final sp = prefs ?? await SharedPreferences.getInstance();
      await sp.setBool(prefKeyExibirLogoPdf, valor);
    } catch (_) {}
  }

  /// Retorna o Widget para a tela de Login/Acesso com fallback automático
  /// para o asset da Suportware quando não houver logo customizada.
  Widget obterLogoLoginWidget({
    double? width = 260.0,
    double? height = 94.6,
    BoxFit fit = BoxFit.cover,
    BorderRadius? borderRadius,
  }) {
    return FutureBuilder<Uint8List?>(
      future: obterLogoBytes(),
      builder: (context, snapshot) {
        final bytes = snapshot.data;
        Widget imageWidget;

        if (bytes != null && bytes.isNotEmpty) {
          imageWidget = Image.memory(
            bytes,
            width: width,
            height: height,
            fit: fit,
            errorBuilder: (context, error, stackTrace) => Image.asset(
              fallbackAsset,
              width: width,
              height: height,
              fit: fit,
            ),
          );
        } else {
          imageWidget = Image.asset(
            fallbackAsset,
            width: width,
            height: height,
            fit: fit,
          );
        }

        if (borderRadius != null) {
          return ClipRRect(
            borderRadius: borderRadius,
            child: imageWidget,
          );
        }

        return imageWidget;
      },
    );
  }
}
