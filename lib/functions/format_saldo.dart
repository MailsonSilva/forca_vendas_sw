

/// DSL custom function formatSaldo
String? formatSaldo(
  double? saldo,
  String? unidade,
) {
  return 'Saldo: ${saldo ?? 0.0} ${unidade ?? ""}';
}
