import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:forca_de_vendas/backend/ftp/ftp_transport.dart';
import 'package:forca_de_vendas/data/services/pacote_retorno_service.dart';
import 'package:forca_de_vendas/services/ftp_upload_service.dart';
import 'package:forca_de_vendas/services/status_envio_db.dart';

class _FakePollingFtp implements FtpTransport {
  final List<String> deletedFiles = [];
  final List<String> nlstFiles;
  final Map<String, String> fileContents;
  bool quitCalled = false;

  _FakePollingFtp({
    required this.nlstFiles,
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
  Future<List<String>> nlst([String? path]) async => nlstFiles;

  @override
  Future<void> dele(String fileName) async {
    deletedFiles.add(fileName);
  }

  @override
  Future<void> rename(String oldName, String newName) async {}

  @override
  Future<void> quit() async => quitCalled = true;
}

const String _xmlRetornoFixture = '''<?xml version="1.0" encoding="UTF-8"?>
<root>
	<ret00>
		<row dig00_digfil="1" dig00_digcod="42" dig00_fatmov="998877" dig00_fatdat="2026-10-06T15:00:00.000Z" dig00_fattot="250.50" dig00_fatobs="FATURADO COM SUCESSO"/>
	</ret00>
	<ret01>
		<row dig01_digfil="1" dig01_digcod="42" dig01_digitm="1" dig01_fatqtd="5" dig01_fatpco="50.10"/>
	</ret01>
	<ret03>
		<row pac00_codfil="1" pac00_codlot="881122"/>
	</ret03>
</root>''';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('aguardarRetornoPacote faz download do .ret, importa no SQLite e deleta do FTP (fcfRETPED = 11)', () async {
    final db = await openDatabase(
      inMemoryDatabasePath,
      version: 1,
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE pckvendig000 (
            ped00_numped INTEGER PRIMARY KEY,
            ped00_sttenv INTEGER DEFAULT 1,
            ped00_fatmov TEXT,
            ped00_fatdat TEXT,
            ped00_fattot REAL DEFAULT 0,
            ped00_fatobs TEXT,
            ped00_datret TEXT,
            ped00_pacstr TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE pckvendig010 (
            ped10_numped INTEGER,
            ped10_seq INTEGER,
            ped10_digitm INTEGER,
            ped10_fatqtd REAL DEFAULT 0,
            ped10_fatpco REAL DEFAULT 0
          )
        ''');
        await db.execute('''
          CREATE TABLE pac00 (
            pac00_pacsrc TEXT PRIMARY KEY,
            pac00_codlot TEXT,
            pac00_sttenv INTEGER DEFAULT 1
          )
        ''');

        await db.insert('pckvendig000', {'ped00_numped': 42, 'ped00_sttenv': 1, 'ped00_pacstr': 'p71-1005.pac'});
        await db.insert('pckvendig010', {'ped10_numped': 42, 'ped10_seq': 1, 'ped10_digitm': 1});
        await db.insert('pac00', {'pac00_pacsrc': 'p71-1005.pac', 'pac00_sttenv': 1});
      },
    );

    final fakeFtp = _FakePollingFtp(
      nlstFiles: ['r71-1005.ret'],
      fileContents: {
        'r71-1005.ret': _xmlRetornoFixture,
      },
    );

    final retornoService = PacoteRetornoService(
      getDatabase: () async => db,
    );

    final uploadService = FtpUploadService(
      connectFtp: () async => fakeFtp,
      pacoteRetornoService: retornoService,
    );

    final result = await uploadService.aguardarRetornoPacote(
      empresa: 'diniz',
      codigoEquipe: 71,
      codRep: 71,
      ipac: 1005,
      intervalo: const Duration(milliseconds: 10),
      timeout: const Duration(seconds: 2),
    );

    expect(result.isConfirmado, isTrue);
    expect(result.arquivoRetorno, 'r71-1005.ret');

    // 1. O arquivo remoto .ret deve ter sido deletado (fcfRETPED = 11)
    expect(fakeFtp.deletedFiles, contains('r71-1005.ret'));

    // 2. O pedido 42 deve estar atualizado no SQLite com status 3, nota fiscal e total
    final p42 = await db.query('pckvendig000', where: 'ped00_numped = ?', whereArgs: [42]);
    expect(p42.first['ped00_sttenv'], 3);
    expect(p42.first['ped00_fatmov'], '998877');
    expect(p42.first['ped00_fattot'], 250.50);
    expect(p42.first['ped00_fatobs'], 'FATURADO COM SUCESSO');

    // 3. Os itens do pedido devem ter recebido o preço e quantidade faturados
    final item = await db.query('pckvendig010', where: 'ped10_numped = ?', whereArgs: [42]);
    expect(item.first['ped10_fatqtd'], 5.0);
    expect(item.first['ped10_fatpco'], 50.10);

    // 4. O lote pac00 deve estar retornado
    final pac = await db.query('pac00', where: 'pac00_pacsrc = ?', whereArgs: ['p71-1005.pac']);
    expect(pac.first['pac00_sttenv'], 2);
    expect(pac.first['pac00_codlot'], '881122');

    await db.close();
  });
}
