

import '../app_state.dart';

/// Resolve o código da filial a partir do código da empresa.
/// PRD 1 §1.5: prioriza filial ativa selecionada no login quando count(cadfil00) > 1.
int? resolverCodFilial(String? empresaCodigo) {
  // Prioriza filial ativa escolhida no modal pós-login
  try {
    final ativa = AppState().codFilialAtiva;
    if (ativa != 0) return ativa;
  } catch (_) {}
  if (empresaCodigo == null || empresaCodigo.isEmpty) {
    return 1;
  }
  final parsed = int.tryParse(empresaCodigo);
  return parsed ?? 1;
}
