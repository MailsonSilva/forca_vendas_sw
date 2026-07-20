import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Responsavel pelo arquivo SQLite local da forca de vendas.
///
/// Mantem nomes de arquivos, gravacao temporaria e validacao da tabela critica
/// fora das actions para que a UI nao carregue regra de infraestrutura.
class LocalSalesDatabaseService {
  static const databaseName = 'dbforcacad001.db';
  static const _tempDatabaseName = 'temp_db.db';

  Future<File> get databaseFile async {
    final databasesPath = await getDatabasesPath();
    return File(p.join(databasesPath, databaseName));
  }

  Future<bool> exists() async {
    final file = await databaseFile;
    return await file.exists();
  }

  Future<List<int>> readDatabaseBytes() async {
    final file = await databaseFile;
    if (!await file.exists()) {
      throw const FileSystemException('Banco de dados local nao encontrado.');
    }
    return file.readAsBytes();
  }

  Future<void> replaceWithValidatedBytes(List<int> sqliteBytes) async {
    final databasesPath = await getDatabasesPath();
    final tempFile = File(p.join(databasesPath, _tempDatabaseName));
    final finalFile = File(p.join(databasesPath, databaseName));

    await tempFile.parent.create(recursive: true);
    await tempFile.writeAsBytes(sqliteBytes, flush: true);

    try {
      await _validateSalespersonTable(tempFile.path);
      if (await finalFile.exists()) {
        await finalFile.delete();
      }
      await tempFile.rename(finalFile.path);
    } finally {
      if (await tempFile.exists()) {
        await tempFile.delete();
      }
    }
  }

  Future<void> _validateSalespersonTable(String databasePath) async {
    Database? database;
    try {
      database = await openDatabase(databasePath, readOnly: true);
      final rows = await database.rawQuery('SELECT COUNT(*) FROM cadrep00');
      if (rows.isEmpty) {
        throw StateError('A tabela cadrep00 nao retornou dados de validacao.');
      }
    } finally {
      if (database != null && database.isOpen) {
        await database.close();
      }
    }
  }
}
