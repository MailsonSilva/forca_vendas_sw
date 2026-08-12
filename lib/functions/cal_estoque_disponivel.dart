

double calEstoqueDisponivel(
  double? estoqueAtual,
  double? estoquePendente,
) {
  double atual = estoqueAtual ?? 0.0;

  double pendente = estoquePendente ?? 0.0;

  return atual - pendente;
}
