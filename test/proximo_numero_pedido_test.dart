import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:forca_de_vendas/functions/proximo_numero_pedido.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late Directory dbDir;

  setUp(() async {
    dbDir = await Directory.systemTemp.createTemp('seq_pedido_');
  });

  tearDown(() {
    if (dbDir.existsSync()) dbDir.deleteSync(recursive: true);
  });

  Future<String> createDb(List<int> numeds) async {
    final path = p.join(dbDir.path, 'dbforcacad001.db');
    final db = await databaseFactory.openDatabase(path);
    await db.execute(
        'CREATE TABLE pckvendig000 (ped00_numped INTEGER PRIMARY KEY)');
    for (final n in numeds) {
      await db.insert('pckvendig000', {'ped00_numped': n});
    }
    await db.close();
    return path;
  }

  test('retorna MAX(ped00_numped)+1 em banco populado', () async {
    final path = await createDb([100, 120, 110]);
    expect(await obterProximoNumeroPedido(dbPath: path), 121);
  });

  test('retorna 1 em banco vazio', () async {
    final path = await createDb([]);
    expect(await obterProximoNumeroPedido(dbPath: path), 1);
  });

  test('retorna 1 quando o banco não existe (no-op seguro)', () async {
    expect(await obterProximoNumeroPedido(dbPath: 'sem/arquivo.db'), 1);
  });
}