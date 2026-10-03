/// Resultado do parsing e montagem do filtro de busca refinada de produtos.
class ProdutoSearchFilterResult {
  /// Expressão SQL (sem WHERE ou AND inicial, ex: "(p.pro00_descri LIKE ? OR ...)")
  final String sql;

  /// Parâmetros posicionais correspondentes às interrogações `?` na expressão SQL.
  final List<dynamic> binds;

  const ProdutoSearchFilterResult({
    required this.sql,
    required this.binds,
  });

  /// Indica se algum filtro SQL foi gerado.
  bool get hasFilter => sql.isNotEmpty;
}

/// Construtor de filtros SQL para o motor de busca refinada de produtos.
///
/// Regras atendidas:
/// 1. Pesquisa por Nome (Termo simples): Início da palavra ou termo prefixado.
/// 2. Pesquisa por Curinga '%': Padrão contendo múltiplos termos ordenados (%termo1%termo2%).
/// 3. Pesquisa Numérica pura: Código do produto (ou código de barras / EAN).
/// 4. Pesquisa por Referência com Prefixo '@': Referências cadastradas (ref001, ref002, reffor).
class ProdutoSearchFilterBuilder {
  static ProdutoSearchFilterResult build({
    required String? input,
    String colDesc = 'p.pro00_descri',
    String colCod = 'p.pro00_codigo',
    String? colCodbar = 'p.pro00_codbar',
    List<String> colRefs = const [
      'p.pro00_ref001',
      'p.pro00_ref002',
      'p.pro00_reffor',
    ],
  }) {
    final String termo = (input ?? '').trim();
    if (termo.isEmpty) {
      return const ProdutoSearchFilterResult(sql: '', binds: []);
    }

    // --- CASO 1: PESQUISA POR REFERÊNCIA COM '@' ---
    if (termo.startsWith('@')) {
      final refTermo = termo.substring(1).trim();
      if (refTermo.isEmpty) {
        return const ProdutoSearchFilterResult(sql: '', binds: []);
      }

      final validRefs = colRefs
          .where((col) => col.trim().isNotEmpty && col != "''")
          .toList();

      if (validRefs.isEmpty) {
        return const ProdutoSearchFilterResult(sql: '', binds: []);
      }

      final String sql = validRefs.length == 1
          ? '${validRefs.first} LIKE ?'
          : '(${validRefs.map((col) => '$col LIKE ?').join(' OR ')})';
      final List<dynamic> binds = List.filled(validRefs.length, '$refTermo%');

      return ProdutoSearchFilterResult(sql: sql, binds: binds);
    }

    // --- CASO 2: DIGITAÇÃO PURAMENTE NUMÉRICA -> CÓDIGO DO PRODUTO (OU EAN) ---
    if (RegExp(r'^\d+$').hasMatch(termo)) {
      final List<String> orClauses = ['CAST($colCod AS TEXT) = ?'];
      final List<dynamic> binds = [termo];

      if (colCodbar != null && colCodbar.trim().isNotEmpty && colCodbar != "''") {
        orClauses.add('$colCodbar = ?');
        binds.add(termo);
      }

      final String sql = orClauses.length == 1
          ? orClauses.first
          : '(${orClauses.join(' OR ')})';

      return ProdutoSearchFilterResult(sql: sql, binds: binds);
    }

    // --- CASO 3: TERMO COM CURINGA '%' (Ex: Luva%azul) ---
    if (termo.contains('%')) {
      final partes = termo
          .split('%')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();

      if (partes.length >= 2) {
        final pattern = '%${partes.join('%')}%';
        return ProdutoSearchFilterResult(
          sql: '$colDesc LIKE ?',
          binds: [pattern],
        );
      } else if (partes.length == 1) {
        return ProdutoSearchFilterResult(
          sql: '$colDesc LIKE ?',
          binds: ['${partes.first}%'],
        );
      } else {
        return const ProdutoSearchFilterResult(sql: '', binds: []);
      }
    }

    // --- CASO 4: PESQUISA EXATA / PREFIXADA POR NOME (Ex: "Luva" ou "Luva azul") ---
    // Traz "Luva de borracha", "Luva azul", etc.
    // Não traz "Mangueira luva..." (sufixo no meio de palavra)
    final palavras = termo
        .split(RegExp(r'\s+'))
        .where((w) => w.trim().isNotEmpty)
        .toList();

    if (palavras.length <= 1) {
      return ProdutoSearchFilterResult(
        sql: '($colDesc LIKE ? OR $colDesc LIKE ?)',
        binds: ['$termo%', '% $termo%'],
      );
    }

    final List<String> clauses = [];
    final List<dynamic> binds = [];
    for (final palavra in palavras) {
      clauses.add('($colDesc LIKE ? OR $colDesc LIKE ?)');
      binds.add('$palavra%');
      binds.add('% $palavra%');
    }

    return ProdutoSearchFilterResult(
      sql: '(${clauses.join(' AND ')})',
      binds: binds,
    );
  }
}

