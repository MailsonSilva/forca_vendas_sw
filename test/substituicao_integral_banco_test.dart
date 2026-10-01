import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart' as p;
import 'package:forca_de_vendas/data/services/local_sales_database_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('Substituição Integral do Banco de Dados SQLite', () {
    late Directory tempDir;
    late String finalDbPath;
    late LocalSalesDatabaseService service;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('sqflite_subst_test_');
      LocalSalesDatabaseService.setCustomDatabasesPathForTesting(tempDir.path);
      finalDbPath = p.join(tempDir.path, LocalSalesDatabaseService.databaseName);
      service = LocalSalesDatabaseService();
    });

    tearDown(() async {
      LocalSalesDatabaseService.setCustomDatabasesPathForTesting(null);
      await LocalSalesDatabaseService.closeAndResetConnectionPool();
      try {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      } catch (_) {}
    });

    test('deleta e substitui integralmente o arquivo do banco com os novos bytes da carga', () async {
      // 1. Cria uma base antiga contendo cadrep00 com um representante inicial
      final oldDb = await openDatabase(finalDbPath);
      await oldDb.execute('CREATE TABLE cadrep00 (ven00_codigo INTEGER PRIMARY KEY, ven00_nome TEXT)');
      await oldDb.insert('cadrep00', {'ven00_codigo': 1, 'ven00_nome': 'REP ANTIGO'});
      await oldDb.close();

      expect(await File(finalDbPath).exists(), isTrue);

      // 2. Cria em arquivo temporário a "nova carga baixada"
      final newTempDbPath = p.join(tempDir.path, 'temp_nova_carga.db');
      final newTempFile = File(newTempDbPath);
      if (await newTempFile.exists()) await newTempFile.delete();

      final newDb = await openDatabase(newTempDbPath);
      await newDb.execute('CREATE TABLE cadrep00 (ven00_codigo INTEGER PRIMARY KEY, ven00_nome TEXT)');
      await newDb.insert('cadrep00', {'ven00_codigo': 2, 'ven00_nome': 'REP NOVO DA CARGA'});
      await newDb.close();

      final novosBytes = await newTempFile.readAsBytes();
      await newTempFile.delete();

      // 3. Executa a substituição integral
      await service.replaceWithValidatedBytes(novosBytes);

      // 4. Valida se o banco no disco foi substituído de forma integral
      final dbVerificacao = await openDatabase(finalDbPath, readOnly: true);
      final rows = await dbVerificacao.query('cadrep00');
      await dbVerificacao.close();

      expect(rows.length, 1);
      expect(rows.first['ven00_codigo'], 2);
      expect(rows.first['ven00_nome'], 'REP NOVO DA CARGA');
    });
  });
}
