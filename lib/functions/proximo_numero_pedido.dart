import 'package:sqflite/sqflite.dart';
import '../app_state.dart';
import '../data/services/local_sales_database_service.dart';
import '../services/sequence_generator_service.dart';

/// Retorna o próximo código sequencial para um novo pedido, calculado conforme
/// SPEC-046 / ffrmdiggerpac00.cpp via [SequenceGeneratorService].
///
/// Consulta: `SELECT COALESCE(MAX(dig00_digcod), 0) + 1 FROM pckvendig00 WHERE dig00_digfil = :filial`
///
/// Fallback seguro: se o banco não existir ou ocorrer erro, retorna `1` sem lançar exceção.
Future<int> obterProximoNumeroPedido({
  String? dbPath,
  int? codFilial,
  int? codVendedor,
}) async {
  try {
    final bool isCustom = dbPath != null;
    final db = isCustom
        ? await openDatabase(dbPath)
        : await LocalSalesDatabaseService.getDatabase();

    try {
      final filial = codFilial ?? (AppState().codFilialAtiva != 0 ? AppState().codFilialAtiva : 1);
      final vendedor = codVendedor ?? AppState().vendedor_codigo;

      final service = SequenceGeneratorService(db);
      return await service.obterProximoCodigoPedido(filial, vendedor);
    } finally {
      if (isCustom) {
        await db.close();
      }
    }
  } catch (e) {
    print('Erro ao obter proximo numero pedido: $e');
    return 1;
  }
}