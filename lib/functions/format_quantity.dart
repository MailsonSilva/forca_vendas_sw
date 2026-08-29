/// Formata quantidades e estoques de produtos de acordo com as regras de negócio:
/// - Unidades não-fracionadas (UN, CX, PC, FD, etc. ou indfra = false): formatação inteira (ex: "14").
/// - Unidades fracionadas (KG, MT, LT, etc. ou indfra = true): formatação com 3 casas decimais (ex: "1,450").
String formatQuantity(
  num? value, {
  String? unidade,
  bool isFracionado = false,
}) {
  if (value == null) return '0';
  final double val = value.toDouble();

  final u = (unidade ?? '').trim().toUpperCase();
  final fractionalUnits = {'KG', 'MT', 'LT', 'M', 'L', 'M2', 'M3', 'G', 'ML'};

  final bool fracionado = isFracionado || fractionalUnits.contains(u);

  if (!fracionado) {
    return val.toInt().toString();
  } else {
    // 3 casas decimais
    return val.toStringAsFixed(3).replaceAll('.', ',');
  }
}
