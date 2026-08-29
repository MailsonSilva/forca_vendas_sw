/// PRD §2.C — helper unificado de formatação monetária.
/// Sempre 2 casas por padrão (CCur). Quando [casas] informado, respeita.
String fmtCurrency(double v, {int casas = 2}) => v.toStringAsFixed(casas);

/// Valor formatado para XML PAC — respeita flag kEnableCurrency2Casas.
/// Mantido como helper para substituir toStringAsFixed disperso.
String fmtCurrencyPac(double v) => v.toStringAsFixed(2);
