import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart' as p;
import 'package:forca_de_vendas/action_code/pesquisa_cliente.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('Pesquisa de Clientes - Paginação e Performance', () {
    late String dbPath;

    setUp(() async {
      dbPath = p.join(await getDatabasesPath(), 'dbforcacad001.db');
      final db = await openDatabase(dbPath);

      await db.execute('DROP TABLE IF EXISTS cadcli00');
      await db.execute('DROP TABLE IF EXISTS cadclipre00');

      await db.execute('''
        CREATE TABLE cadcli00 (
          cli00_codigo INTEGER PRIMARY KEY,
          cli00_descri TEXT,
          cli00_fantas TEXT,
          cli00_cpfcnp TEXT,
          cli00_endere TEXT,
          cli00_ciddes TEXT,
          cli00_estsgl TEXT,
          cli00_fonddd TEXT,
          cli00_fonnum TEXT,
          cli00_crelim REAL DEFAULT 0,
          cli00_creatu REAL DEFAULT 0,
          cli00_titven REAL DEFAULT 0,
          cli00_active INTEGER DEFAULT 1
        )
      ''');

      await db.execute('''
        CREATE TABLE cadclipre00 (
          cli00_codigo INTEGER PRIMARY KEY,
          cli00_descri TEXT,
          cli00_fantas TEXT,
          cli00_cpfcnp TEXT,
          cli00_endere TEXT,
          cli00_ciddes TEXT,
          cli00_estsgl TEXT,
          cli00_fonddd TEXT,
          cli00_fonnum TEXT,
          cli00_crelim REAL DEFAULT 0,
          cli00_creatu REAL DEFAULT 0,
          cli00_titven REAL DEFAULT 0,
          cli00_active INTEGER DEFAULT 1,
          novo_local INTEGER DEFAULT 1,
          status_envio TEXT DEFAULT 'pendente_envio'
        )
      ''');

      // Inserir 150 clientes na carga externa cadcli00
      final batch = db.batch();
      for (int i = 1; i <= 150; i++) {
        final codFormat = i.toString().padLeft(4, '0');
        batch.insert('cadcli00', {
          'cli00_codigo': i,
          'cli00_descri': 'CLIENTE CARGA $codFormat',
          'cli00_fantas': 'FANTASIA $codFormat',
          'cli00_cpfcnp': '00000000$codFormat',
          'cli00_ciddes': 'CIDADE $codFormat',
          'cli00_estsgl': 'SP',
          'cli00_active': 1,
        });
      }
      await batch.commit(noResult: true);
      await db.close();
    });

    test('pesquisaCliente aplica LIMIT e OFFSET corretamente para paginação', () async {
      // Primeira página (offset 0, limit 100 por padrão)
      final p1 = await pesquisaCliente('', 0, 100);
      expect(p1.length, equals(100));
      expect(p1.first.cli00Descri, equals('CLIENTE CARGA 0001'));
      expect(p1.last.cli00Descri, equals('CLIENTE CARGA 0100'));

      // Segunda página (offset 100, limit 100)
      final p2 = await pesquisaCliente('', 100, 100);
      expect(p2.length, equals(50));
      expect(p2.first.cli00Descri, equals('CLIENTE CARGA 0101'));
      expect(p2.last.cli00Descri, equals('CLIENTE CARGA 0150'));
    });

    test('pesquisaCliente busca por termo filtrado respeitando limit e offset', () async {
      final resultado = await pesquisaCliente('CLIENTE CARGA 001', 0, 50);
      expect(resultado, isNotEmpty);
      expect(resultado.every((c) => c.cli00Descri.contains('001')), isTrue);
    });

    test('pesquisaCliente retorna lista vazia rapidamente quando nenhum cliente encontrado', () async {
      final resultado = await pesquisaCliente('TERMO INEXISTENTE 99999', 0, 50);
      expect(resultado, isEmpty);
    });
  });
}
