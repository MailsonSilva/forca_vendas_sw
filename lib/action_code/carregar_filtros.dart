// Imports do app
import '/backend/schema/structs/index.dart';
// Imports other custom actions
// Imports custom functions
// Begin custom action code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

// Imports do app
// Imports other custom actions
// Imports custom functions
// Begin custom action code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

// Imports necessários
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

Future<List<ListaPadraoStruct>> carregarFiltros(String tabela) async {
  Database? db;
  try {
    db = await openDatabase(join(await getDatabasesPath(), 'dbforcacad001.db'));

    // Força o texto para minúsculo para evitar problemas de digitação
    final t = tabela.toLowerCase().trim();

    String nomeTabelaReal = '';
    String colCodigo = '';
    String colDescri = '';

    if (t.contains('lin')) {
      nomeTabelaReal = 'cadlin00';
      colCodigo = 'lin00_codigo';
      colDescri = 'lin00_descri';
    } else if (t.contains('gru')) {
      nomeTabelaReal = 'cadgru00';
      colCodigo = 'gru00_codigo';
      colDescri = 'gru00_descri';
    } else if (t.contains('for') || t.contains('fab')) {
      nomeTabelaReal =
          'cadfor00'; // ou 'fornecedores' se o nome físico for este
      colCodigo = 'for00_codigo';
      colDescri = 'for00_descri';
    } else {
      nomeTabelaReal = 'cadmar00';
      colCodigo = 'mar00_codigo';
      colDescri = 'mar00_descri';
    }

    final List<Map<String, dynamic>> maps = await db.rawQuery(
        'SELECT $colCodigo, $colDescri FROM $nomeTabelaReal ORDER BY $colDescri');

    await db.close();

    return maps.map((m) {
      final codigo = m[colCodigo]?.toString() ?? '';
      final descri = m[colDescri]?.toString() ?? '';

      return ListaPadraoStruct(
        descricao: '$codigo - $descri',
        codigo: codigo,
      );
    }).toList();
  } catch (e) {
    print('ERRO CARREGAR FILTROS ($tabela): $e');
    if (db != null && db.isOpen) {
      await db.close();
    }
    return [];
  }
}
