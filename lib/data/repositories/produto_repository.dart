import 'package:sqflite/sqflite.dart';
import '/domain/models/produto_lookup_dto.dart';
import '/data/services/local_sales_database_service.dart';

/// Repositório de dados para consulta e seleção de produtos.
///
/// Implementa a busca multifiltro com LEFT JOIN em cadmar00 e cadfor00
/// conforme a especificação técnica 00_ESPECIFICACAO_PESQUISA_PRODUTOS_EAN_MARCA_REFERENCIA.md.
class ProdutoRepository {
  ProdutoRepository({Database? db}) : _db = db;

  final Database? _db;

  Future<Database> _getDb() async {
    if (_db != null) return _db!;
    return await LocalSalesDatabaseService.getDatabase();
  }

  /// Realiza a busca multifiltro por EAN, Marca, Referência 1, Referência 2 ou Descrição.
  Future<List<ProdutoLookupDTO>> buscarProdutos(
    String? query, {
    int limit = 100,
    int offset = 0,
  }) async {
    final db = await _getDb();
    final termo = (query ?? '').trim();

    String whereClause = '';
    List<dynamic> binds = [];

    if (termo.isNotEmpty) {
      final likeTermo = '%$termo%';
      whereClause = '''
        WHERE (
          p.pro00_descri LIKE ? OR
          p.pro00_codbar LIKE ? OR
          p.pro00_ref001 LIKE ? OR
          p.pro00_ref002 LIKE ? OR
          m.mar00_descri LIKE ?
        )
      ''';
      binds.addAll([likeTermo, likeTermo, likeTermo, likeTermo, likeTermo]);
    }

    final sql = '''
      SELECT 
        p.pro00_codigo   AS produto_id,
        p.pro00_descri   AS descricao,
        p.pro00_codbar   AS ean,
        COALESCE(m.mar00_descri, 'SEM MARCA') AS marca_nome,
        p.pro00_ref001   AS referencia_1,
        p.pro00_ref002   AS referencia_2,
        COALESCE(f.for00_descri, '')          AS fabricante_nome,
        COALESCE(p.pro00_embala, p.pro00_unidad, 'UN') AS embalagem,
        COALESCE(p.pro00_unidad, 'UN')        AS unidade,
        COALESCE(p.pro00_qtdest, 0.0)         AS estoque_saldo,
        0.0                                   AS preco_tabela,
        p.pro00_codimg   AS imagem_id
      FROM cadpro00 p
      LEFT JOIN cadmar00 m ON m.mar00_codigo = p.pro00_codmar
      LEFT JOIN cadfor00 f ON f.for00_codigo = p.pro00_codfab
      $whereClause
      ORDER BY p.pro00_descri ASC
      LIMIT ? OFFSET ?
    ''';

    binds.addAll([limit, offset]);

    final rows = await db.rawQuery(sql, binds);
    return rows.map((row) => ProdutoLookupDTO.fromMap(row)).toList();
  }
}
