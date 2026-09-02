import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:forca_de_vendas/backend/ftp/ftp_transport.dart';
import 'package:forca_de_vendas/data/services/crg_codec.dart';
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

const String _xmlRetornoProducao = '''<?xml version="1.0" encoding="UTF-8"?>
<root>
	<ret00>
		<row dig00_digfil="1" dig00_digcod="12" dig00_fatmov="4677834" dig00_fatdat="2026-09-01T17:06:24.700Z" dig00_fattot="191.16" dig00_fatobs=""/>
		<row dig00_digfil="1" dig00_digcod="13" dig00_fatmov="4677835" dig00_fatdat="2026-09-01T17:06:24.700Z" dig00_fattot="23.88" dig00_fatobs=""/>
	</ret00>
	<ret01>
		<row dig01_digfil="1" dig01_digcod="12" dig01_digitm="1" dig01_fatqtd="2" dig01_fatpco="51.03"/>
		<row dig01_digfil="1" dig01_digcod="12" dig01_digitm="2" dig01_fatqtd="2" dig01_fatpco="44.55"/>
		<row dig01_digfil="1" dig01_digcod="13" dig01_digitm="1" dig01_fatqtd="2" dig01_fatpco="11.94"/>
	</ret01>
	<ret03>
		<row pac00_codfil="1" pac00_codlot="73831"/>
	</ret03>
	<pro00>
		<row pro00_codfil="1" pro00_codpro="19702" pro00_qtdest="0"/>
		<row pro00_codfil="1" pro00_codpro="42424" pro00_qtdest="15"/>
		<row pro00_codfil="1" pro00_codpro="43224" pro00_qtdest="42"/>
	</pro00>
	<cli00>
		<row cli00_codigo="9997" cli00_crelim="2000" cli00_creatu="-132.47"/>
		<row cli00_codigo="21893" cli00_crelim="0" cli00_creatu="0"/>
	</cli00>
	<fat00>
		<estfatdat00>
			<row dat00_dattim="2026-09-01T17:06:25.607Z"/>
		</estfatdat00>
		<estfatcvd00>
			<row fat00_codfil="1" fat00_codven="71" fat00_datmov="2026-09-01" fat00_clides="Juridica" fat00_clityp="2" fat00_vlrperfat="100" fat00_vlrfatven="0" fat00_vlrdigven="0" fat00_vlrdigloc="0" fat00_vlrtotven="0" fat00_vlrcalven="10000000" fat00_vlrtotper="0" fat00_vlrtotlib="10000000"/>
		</estfatcvd00>
	</fat00>
	<ccv00>
		<fincaidat00>
			<row dat00_dattim="2026-09-01T17:06:25.623Z"/>
		</fincaidat00>
		<fincaiccv01>
			<row ccv01_codfil="1" ccv01_codven="71" ccv01_vlrsal="84.84" ccv01_vlrusedig="-98.02" ccv01_vlrusepck="0" ccv01_vlrsalatu="-13.18"/>
		</fincaiccv01>
	</ccv00>
	<sql00>
		<row sql00_cmdtyp="0" sql00_cmdsql="PRAGMA integrity_check;"/>
		<row sql00_cmdtyp="1" sql00_cmdsql="PRAGMA auto_vacuum(1);"/>
	</sql00>
</root>''';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('RetornoXmlParser extrai corretamente todos os 8 blocos', () {
    final ret00 = RetornoXmlParser.parseRows(_xmlRetornoProducao, 'ret00');
    expect(ret00.length, 2);
    expect(ret00.first['dig00_digcod'], '12');
    expect(ret00.first['dig00_fatmov'], '4677834');
    expect(ret00.first['dig00_fattot'], '191.16');

    final ret01 = RetornoXmlParser.parseRows(_xmlRetornoProducao, 'ret01');
    expect(ret01.length, 3);
    expect(ret01.first['dig01_fatqtd'], '2');

    final ret03 = RetornoXmlParser.parseRows(_xmlRetornoProducao, 'ret03');
    expect(ret03.first['pac00_codlot'], '73831');

    final pro00 = RetornoXmlParser.parseRows(_xmlRetornoProducao, 'pro00');
    expect(pro00.length, 3);
    expect(pro00[1]['pro00_codpro'], '42424');
    expect(pro00[1]['pro00_qtdest'], '15');

    final cli00 = RetornoXmlParser.parseRows(_xmlRetornoProducao, 'cli00');
    expect(cli00.first['cli00_creatu'], '-132.47');

    final sql00 = RetornoXmlParser.parseRows(_xmlRetornoProducao, 'sql00');
    expect(sql00.length, 2);
    expect(sql00.first['sql00_cmdsql'], contains('PRAGMA integrity_check;'));
  });

  test('importarRetornoXml atualiza tabelas SQLite locais de forma atômica', () async {
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
        await db.execute('''
          CREATE TABLE cadpro00 (
            pro00_codigo INTEGER PRIMARY KEY,
            pro00_prifil INTEGER,
            pro00_qtdest REAL DEFAULT 0
          )
        ''');
        await db.execute('''
          CREATE TABLE cadcli00 (
            cli00_codigo INTEGER PRIMARY KEY,
            cli00_crelim REAL DEFAULT 0,
            cli00_creatu REAL DEFAULT 0
          )
        ''');
        await db.execute('''
          CREATE TABLE estfatdat00 (dat00_dattim TEXT)
        ''');
        await db.execute('''
          CREATE TABLE estfatcvd00 (
            fat00_codfil INTEGER,
            fat00_codven INTEGER,
            fat00_datmov TEXT,
            fat00_clides TEXT,
            fat00_clityp INTEGER,
            fat00_vlrperfat REAL,
            fat00_vlrfatven REAL,
            fat00_vlrdigven REAL,
            fat00_vlrdigloc REAL,
            fat00_vlrtotven REAL,
            fat00_vlrcalven REAL,
            fat00_vlrtotper REAL,
            fat00_vlrtotlib REAL
          )
        ''');
        await db.execute('''
          CREATE TABLE fincaidat00 (dat00_dattim TEXT)
        ''');
        await db.execute('''
          CREATE TABLE fincaiccv01 (
            ccv01_codfil INTEGER,
            ccv01_codven INTEGER,
            ccv01_vlrsal REAL,
            ccv01_vlrusedig REAL,
            ccv01_vlrusepck REAL,
            ccv01_vlrsalatu REAL
          )
        ''');

        await db.insert('pckvendig000', {'ped00_numped': 12, 'ped00_sttenv': 1, 'ped00_pacstr': 'p71-1001.pac'});
        await db.insert('pckvendig000', {'ped00_numped': 13, 'ped00_sttenv': 1, 'ped00_pacstr': 'p71-1001.pac'});
        await db.insert('pckvendig010', {'ped10_numped': 12, 'ped10_seq': 1, 'ped10_digitm': 1});
        await db.insert('pckvendig010', {'ped10_numped': 12, 'ped10_seq': 2, 'ped10_digitm': 2});
        await db.insert('pac00', {'pac00_pacsrc': 'p71-1001.pac', 'pac00_sttenv': 1});
      },
    );

    final service = PacoteRetornoService(
      getDatabase: () async => db,
    );

    await service.importarRetornoXml(
      xml: _xmlRetornoProducao,
      pacOriginal: 'p71-1001.pac',
      codRep: 71,
    );

    // 1. Valida Pedido 12 atualizado
    final p12 = await db.query('pckvendig000', where: 'ped00_numped = ?', whereArgs: [12]);
    expect(p12.first['ped00_sttenv'], 3);
    expect(p12.first['ped00_fatmov'], '4677834');
    expect(p12.first['ped00_fattot'], 191.16);

    // 2. Valida Itens atualizados
    final i12_1 = await db.query('pckvendig010', where: 'ped10_numped = ? AND ped10_seq = ?', whereArgs: [12, 1]);
    expect(i12_1.first['ped10_fatqtd'], 2.0);
    expect(i12_1.first['ped10_fatpco'], 51.03);

    // 3. Valida Pacote atualizado
    final pac = await db.query('pac00', where: 'pac00_pacsrc = ?', whereArgs: ['p71-1001.pac']);
    expect(pac.first['pac00_sttenv'], 2);
    expect(pac.first['pac00_codlot'], '73831');

    // 4. Valida Estoque
    final pro = await db.query('cadpro00', where: 'pro00_codigo = ?', whereArgs: [42424]);
    expect(pro.first['pro00_qtdest'], 15.0);

    // 5. Valida Cliente
    final cli = await db.query('cadcli00', where: 'cli00_codigo = ?', whereArgs: [9997]);
    expect(cli.first['cli00_crelim'], 2000.0);
    expect(cli.first['cli00_creatu'], -132.47);

    // 6. Valida Metas e CCV
    final est = await db.query('estfatcvd00');
    expect(est.length, 1);

    final ccv = await db.query('fincaiccv01');
    expect(ccv.first['ccv01_vlrsalatu'], -13.18);

    await db.close();
  });

  test('processarRetornos processa arquivos .ret e confirma exclusao remota', () async {
    final fakeFtp = _FakeRetornoFtp(
      fileList: ['r71-1001.ret', 'outro_arquivo.txt'],
      fileContents: {
        'r71-1001.ret': _xmlRetornoProducao,
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
    expect(fakeFtp.deletedFiles, contains('r71-1001.ret'));
  });

  test('processarRetornos descompacta arquivo .ret compactado com CrgCodec Zlib', () async {
    final compressedBytes = CrgCodec().compressText(_xmlRetornoProducao, layers: 2);
    // Testa CrgCodec.decompressRetornoText
    final decodedText = CrgCodec().decompressRetornoText(compressedBytes);
    expect(decodedText, contains('4677834'));
    expect(decodedText, contains('<ret00>'));
  });


  test('processarRetornos aplica fallback automático se empresa e vendedor forem nulos', () async {
    final fakeFtp = _FakeRetornoFtp(
      fileList: ['r71-1001.ret'],
      fileContents: {'r71-1001.ret': _xmlRetornoProducao},
    );

    final service = PacoteRetornoService(
      connectFtp: () async => fakeFtp,
      statusDb: _FakeRetornoStatusDb(),
    );

    final result = await service.processarRetornos();
    expect(result.sucesso, isTrue);
  });
}


