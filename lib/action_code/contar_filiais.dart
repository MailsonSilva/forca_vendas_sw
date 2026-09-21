// DO NOT REMOVE OR MODIFY THE CODE ABOVE!
import 'package:sqflite/sqflite.dart';
import '/backend/schema/structs/lista_padrao_struct.dart';
import '/data/services/local_sales_database_service.dart';

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

/// SPEC-047 §1.1 — conta cadfil00 (WHERE fil00_active = 1) e lista filiais ativas disponíveis.
/// Tolerante a variações de nome de coluna/tabela (PRAGMA).
/// Utiliza a conexão singleton ativa sem fechamento prematuro (INVARIANT 1).
Future<FiliaisResult> contarFiliais({String? dbPathOverride, Database? customDb}) async {
  Database? db;
  bool shouldClose = false;
  try {
    if (customDb != null) {
      db = customDb;
    } else if (dbPathOverride != null) {
      db = await openDatabase(dbPathOverride);
      shouldClose = true;
    } else {
      db = await LocalSalesDatabaseService.getDatabase();
    }

    // Verifica se tabela existe (case-insensitive)
    final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND lower(name)='cadfil00'");
    if (tables.isEmpty) {
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
        return FiliaisResult(count: 0, filiais: []);
      }
    }

    // Identifica coluna de filial ativa (SPEC-047: WHERE fil00_active = 1)
    String? activeCol;
    for (final c in ['fil00_active', 'fil00_ativo', 'fil00_sttfil', 'fil00_status', 'active', 'ativo']) {
      if (colNames.contains(c)) {
        activeCol = c;
        break;
      }
    }

    final String whereClause = activeCol != null ? 'WHERE ($activeCol = 1 OR $activeCol = "1")' : '';
    final rows = await db.rawQuery('SELECT $codCol as codigo, $descCol as descricao FROM cadfil00 $whereClause ORDER BY $descCol');

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
  } finally {
    if (shouldClose && db != null && db.isOpen) {
      await db.close();
    }
  }
}

/// Helper para converter para ListaPadraoStruct (reuso de widgets existentes se necessário)
List<ListaPadraoStruct> filiaisToListaPadrao(List<FilialInfo> filiais) {
  return filiais.map((f) => ListaPadraoStruct(codigo: f.codigo, descricao: f.descricao)).toList();
}
