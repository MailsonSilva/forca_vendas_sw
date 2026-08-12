

/// removerCaracteresEspeciais
String removerCaracteresEspeciais(String campo) {
  return campo.replaceAll(RegExp(r'\D'), '');
}
