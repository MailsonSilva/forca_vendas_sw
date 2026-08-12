

/// Resolve o código da filial a partir do código da empresa.
int? resolverCodFilial(String? empresaCodigo) {
  if (empresaCodigo == null || empresaCodigo.isEmpty) {
    return 1;
  }
  final parsed = int.tryParse(empresaCodigo);
  return parsed ?? 1;
}
