import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// Codifica e decodifica arquivos `.crg` e streams compactados usados pelo ERP legado.
///
/// O formato observado possui camadas zlib, cada uma precedida por um
/// cabeçalho de 4 bytes (Big-Endian) com o tamanho original da camada.
class CrgCodec {
  static const _sqliteHeader = 'SQLite format 3';

  /// Decodifica a base de dados SQLite do formato `.crg`.
  List<int> decodeDatabase(List<int> crgBytes) {
    if (crgBytes.length < 5) {
      throw const FormatException('Arquivo .crg muito pequeno.');
    }

    final firstLayer = zlib.decode(crgBytes.sublist(4));
    if (_hasSqliteHeader(firstLayer)) {
      return firstLayer;
    }

    if (firstLayer.length < 5) {
      throw const FormatException('Segunda camada do .crg muito pequena.');
    }

    final databaseBytes = zlib.decode(firstLayer.sublist(4));
    if (!_hasSqliteHeader(databaseBytes)) {
      throw const FormatException('Banco SQLite final invalido ou corrompido.');
    }

    return databaseBytes;
  }

  /// Codifica a base de dados SQLite no formato `.crg` (2 camadas).
  List<int> encodeDatabase(List<int> databaseBytes) {
    final firstLayer = _compressLayer(databaseBytes);
    return _compressLayer(firstLayer);
  }

  /// Compacta uma sequência de bytes arbitrária no padrão de cabeçalho de 4 bytes + Zlib.
  Uint8List compressBytes(List<int> data, {int layers = 2}) {
    List<int> current = data;
    for (int i = 0; i < layers; i++) {
      current = _compressLayer(current);
    }
    return Uint8List.fromList(current);
  }

  /// Descompacta bytes compactados no padrão de cabeçalho de 4 bytes + Zlib (1 ou 2 camadas).
  List<int> decompressBytes(List<int> compressedData) {
    if (compressedData.length < 5) {
      throw const FormatException('Arquivo compactado muito pequeno.');
    }

    final first = zlib.decode(compressedData.sublist(4));
    if (first.length >= 5) {
      try {
        final second = zlib.decode(first.sublist(4));
        return second;
      } catch (_) {
        return first;
      }
    }
    return first;
  }

  /// Compacta uma String de texto comum no padrão `.crg` (4-byte header + Zlib).
  Uint8List compressText(
    String text, {
    int layers = 2,
    Encoding encoding = utf8,
  }) {
    final bytes = encoding.encode(text);
    return compressBytes(bytes, layers: layers);
  }

  /// Descompacta bytes no padrão `.crg` e retorna a String de texto decodificada.
  String decompressText(
    List<int> compressedData, {
    Encoding encoding = utf8,
  }) {
    final rawBytes = decompressBytes(compressedData);
    return encoding.decode(rawBytes);
  }

  bool _hasSqliteHeader(List<int> bytes) {
    final header = utf8.decode(bytes.take(16).toList(), allowMalformed: true);
    return header.contains(_sqliteHeader);
  }

  List<int> _compressLayer(List<int> data) {
    final compressed = zlib.encode(data);
    final length = data.length;
    return [
      (length >> 24) & 0xFF,
      (length >> 16) & 0xFF,
      (length >> 8) & 0xFF,
      length & 0xFF,
      ...compressed,
    ];
  }
}
