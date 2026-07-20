import 'dart:convert';
import 'dart:io';

/// Codifica e decodifica arquivos `.crg` usados pelo ERP legado.
///
/// O formato observado tem duas camadas zlib, cada uma precedida por um
/// cabecalho de 4 bytes com o tamanho original da camada.
class CrgCodec {
  static const _sqliteHeader = 'SQLite format 3';

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

  List<int> encodeDatabase(List<int> databaseBytes) {
    final firstLayer = _compressLayer(databaseBytes);
    return _compressLayer(firstLayer);
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
