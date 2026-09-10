import 'package:intl/intl.dart';

/// Formatador monetário brasileiro oficial (R$ #.##0,00).
final NumberFormat _ptBrCurrencyFormat = NumberFormat.currency(
  locale: 'pt_BR',
  symbol: 'R\$',
  decimalDigits: 2,
);

final NumberFormat _ptBrDecimalFormat = NumberFormat.currency(
  locale: 'pt_BR',
  symbol: '',
  decimalDigits: 2,
);

/// Formata um número para o padrão monetário brasileiro: `R$ 1.250,50` ou `1.250,50`.
String formatMoeda(num? valor, {bool incluirSimbolo = true, String valorPadrao = 'R\$ 0,00'}) {
  if (valor == null) return valorPadrao;
  if (incluirSimbolo) {
    return _ptBrCurrencyFormat.format(valor).replaceAll('\u00A0', ' ').trim();
  }
  return _ptBrDecimalFormat.format(valor).replaceAll('\u00A0', ' ').trim();
}

/// Extensão para formatação monetária direta em numéricos: `preco.toMoeda()`.
extension MoedaFormattingExtension on num? {
  /// Retorna o valor formatado como moeda brasileira (ex: `R$ 10,50`).
  /// Caso o valor seja nulo, retorna `R$ 0,00`.
  String toMoeda({bool incluirSimbolo = true}) {
    if (this == null) {
      return incluirSimbolo ? 'R\$ 0,00' : '0,00';
    }
    return formatMoeda(this, incluirSimbolo: incluirSimbolo);
  }
}
