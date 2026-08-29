// PRD 1 §5A — retornaMil(): milissegundos curtos para nomenclatura c<rep>-<ms>.xml
// Legado C++/Qt retornava QTime::msec() curto; no Dart mapeamos para
// millisecondsSinceEpoch % 100000 (5 dígitos) ou % 1000000 se precisar maior range.
// Injetável via parâmetro now para testes determinísticos.

int retornaMil({DateTime? now}) {
  final dt = now ?? DateTime.now();
  // 5 dígitos curtos como no legado (0..99999)
  return dt.millisecondsSinceEpoch % 100000;
}

/// Variante com 6 dígitos se a retaguarda exigir mais unicidade.
int retornaMil6({DateTime? now}) {
  final dt = now ?? DateTime.now();
  return dt.millisecondsSinceEpoch % 1000000;
}
