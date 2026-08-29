// DO NOT REMOVE OR MODIFY THE CODE ABOVE!
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import '/backend/schema/structs/lista_padrao_struct.dart';

class FilialInfo {
  FilialInfo({required this.codigo, required this.descricao});
  final String codigo;
  final String descricao;
}

class FiliaisResult {
  FiliaisResult({required this.count, required this.filiais});
  final int count;
  final List<FilialInfo> filiais;
}

/// PRD 1 §1.5 — conta cadfil00 e lista filiais disponíveis.
/// Tolerante a variações de nome de coluna/tabela (PRAGMA).
Future<FiliaisResult> contarFiliais({String? dbPathOverride}) async {
  try {
    final dbPath = dbPathOverride ?? p.join(await getDatabasesPath(), 'dbforcacad001.db');
    final db = await openDatabase(dbPath, readOnly: true);

    // Verifica se tabela existe (case-insensitive)
    final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND lower(name)='cadfil00'");
    if (tables.isEmpty) {
      await db.close();
      return FiliaisResult(count: 0, filiais: []);
    }

    final cols = await db.rawQuery('PRAGMA table_info(cadfil00)');
    final colNames = cols.map((r) => r['name']?.toString().toLowerCase()).toSet();

    String? codCol;
    String? descCol;
    // Candidatos código
    for (final c in ['fil00_codigo', 'fil00_codfil', 'fil00_cod', 'fil00_filcod']) {
      if (colNames.contains(c)) { codCol = c; break; }
    }
    // Candidatos descrição
    for (final c in ['fil00_descri', 'fil00_descricao', 'fil00_nome', 'fil00_fantas', 'fil00_razao']) {
      if (colNames.contains(c)) { descCol = c; break; }
    }
    // Fallback: primeiras duas colunas
    if (codCol == null || descCol == null) {
      if (cols.length >= 2) {
        codCol ??= cols[0]['name'].toString();
        descCol ??= cols[1]['name'].toString();
      } else if (cols.length == 1) {
        codCol ??= cols[0]['name'].toString();
        descCol = cols[0]['name'].toString();
      } else {
        await db.close();
        return FiliaisResult(count: 0, filiais: []);
      }
    }

    final rows = await db.rawQuery('SELECT $codCol as codigo, $descCol as descricao FROM cadfil00 ORDER BY $descCol');
    await db.close();

    final filiais = rows.map((r) {
      return FilialInfo(
        codigo: r['codigo']?.toString() ?? '',
        descricao: r['descricao']?.toString() ?? '',
      );
    }).toList();

    return FiliaisResult(count: filiais.length, filiais: filiais);
  } catch (e) {
    // Em caso de erro (DB ausente), retorna 0 para não bloquear login
    return FiliaisResult(count: 0, filiais: []);
  }
}

/// Helper para converter para ListaPadraoStruct (reuso de widgets existentes se necessário)
List<ListaPadraoStruct> filiaisToListaPadrao(List<FilialInfo> filiais) {
  return filiais.map((f) => ListaPadraoStruct(codigo: f.codigo, descricao: f.descricao)).toList();
}
