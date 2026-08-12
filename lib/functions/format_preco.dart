

/// DSL custom function formatPreco
String? formatPreco(double? preco) {
  return 'R\$ ${(preco ?? 0.0).toStringAsFixed(2).replaceAll('.', ',')}';
}
