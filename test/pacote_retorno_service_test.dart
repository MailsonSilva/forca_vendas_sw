import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:forca_de_vendas/backend/ftp/ftp_transport.dart';
import 'package:forca_de_vendas/data/services/pacote_retorno_service.dart';
import 'package:forca_de_vendas/services/status_envio_db.dart';

class _FakeRetornoFtp implements FtpTransport {
  final List<String> deletedFiles = [];
  final List<String> fileList;
  final Map<String, String> fileContents;

  _FakeRetornoFtp({
    required this.fileList,
    required this.fileContents,
  });

  @override
  Future<void> cwd(String path) async {}

  @override
  Future<void> mkd(String path) async {}

  @override
  Future<void> stor(String fileName, List<int> bytes, {void Function(int sent)? onProgress}) async {}

  @override
  Future<int> size(String fileName) async => fileContents[fileName]?.length ?? 0;

  @override
  Future<List<int>> retr(String fileName) async {
    final content = fileContents[fileName] ?? '';
    return utf8.encode(content);
  }

  @override
  Future<List<String>> nlst([String? path]) async => fileList;

  @override
  Future<void> dele(String fileName) async {
    deletedFiles.add(fileName);
  }

  @override
  Future<void> quit() async {}
}

class _FakeRetornoStatusDb extends StatusEnvioDb {
  final List<String> pacotesRecebidos = [];

  @override
  Future<void> marcarPacoteRecebido(String nomePacote) async {
    pacotesRecebidos.add(nomePacote);
  }
}

void main() {
  test('processarRetornos processa arquivos .ret e marca pacotes como recebidos', () async {
    final fakeFtp = _FakeRetornoFtp(
      fileList: ['r71-1001.ret', 'outro_arquivo.txt'],
      fileContents: {
        'r71-1001.ret': '<retorno><status>OK</status><nota>12345</nota></retorno>',
      },
    );
    final fakeStatusDb = _FakeRetornoStatusDb();

    final service = PacoteRetornoService(
      connectFtp: () async => fakeFtp,
      statusDb: fakeStatusDb,
    );

    final result = await service.processarRetornos(
      empresa: 'diniz',
      codRep: 71,
    );

    expect(result.sucesso, isTrue);
    expect(result.totalProcessados, 1);
    expect(result.arquivosProcessados, contains('r71-1001.ret'));
    expect(fakeStatusDb.pacotesRecebidos, contains('p71-1001.pac'));
    expect(fakeFtp.deletedFiles, contains('r71-1001.ret'));
  });

  test('processarRetornos identifica retorno rejeitado/com erro sem marcar como faturado', () async {
    final fakeFtp = _FakeRetornoFtp(
      fileList: ['r71-1002.ret'],
      fileContents: {
        'r71-1002.ret': '<retorno><status="rejeitado"><erro>Limite de crédito excedido</erro></retorno>',
      },
    );
    final fakeStatusDb = _FakeRetornoStatusDb();

    final service = PacoteRetornoService(
      connectFtp: () async => fakeFtp,
      statusDb: fakeStatusDb,
    );

    final result = await service.processarRetornos(
      empresa: 'diniz',
      codRep: 71,
    );

    expect(result.sucesso, isTrue);
    expect(result.totalProcessados, 1);
    expect(fakeStatusDb.pacotesRecebidos, isEmpty); // Não deve marcar como recebido/faturado
    expect(fakeFtp.deletedFiles, contains('r71-1002.ret'));
  });
}
