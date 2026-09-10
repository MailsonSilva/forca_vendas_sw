import '/core/formatters/currency_formatter.dart';

/// DSL custom function formatPreco
String? formatPreco(double? preco) {
  return formatMoeda(preco);
}
