
/// Feature flags Fase B — rollout gradual PRD.
const bool kEnableIcmsSt = true;
const bool kEnableBloqueioFinanceiro = true;
const bool kEnableCurrency2Casas = true;

/// PRD 1 §5A — quando true, gera <PacoteVendas> em vez de <root><pckvenpac00> legado.
/// Mantido false por decisão Q1 (legado default) até homologação retaguarda.
const bool kEnablePacoteVendasSchema = false;

abstract class AppConstants {
  static const List<String> sufixoList = [
    '',
    '_1',
    '_2',
    '_3',
    '_4',
    '_5',
    '_6'
  ];
}
