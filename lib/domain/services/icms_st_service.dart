import '../../app_constants.dart';

/// PRD B5 & Fase 3 — Motor Fiscal de ICMS-ST (Tsysfis00ICMSSubst)
class IcmsStService {
  /// Base ST = (Valor Item + Frete + Despesas - Descontos) * (1 + MVA)
  static double calcBaseST({
    required double base,
    required double mva,
    double frete = 0.0,
    double despesas = 0.0,
    double descontos = 0.0,
  }) {
    if (!kEnableIcmsSt) return base;
    final baseLiquida = base + frete + despesas - descontos;
    if (baseLiquida <= 0) return 0.0;
    return baseLiquida * (1.0 + mva);
  }

  /// Compat: calcBASE alias (PRD nomenclatura)
  static double calcBASE({
    required double base,
    required double mva,
    double frete = 0.0,
    double despesas = 0.0,
    double descontos = 0.0,
  }) =>
      calcBaseST(
        base: base,
        mva: mva,
        frete: frete,
        despesas: despesas,
        descontos: descontos,
      );

  /// ICMS Próprio = Valor Item * Alíquota Interestadual/Interna
  static double calcIcmsProprio({
    required double valorItem,
    required double aliqPropria,
  }) {
    if (!kEnableIcmsSt) return 0.0;
    return valorItem * aliqPropria;
  }

  /// ICMS-ST = (Base ST * Alíquota Destino) - ICMS Próprio (se > 0, senão 0)
  static double calcIcmsST({
    required double baseST,
    required double aliqDestino,
    required double icmsProprio,
  }) {
    if (!kEnableIcmsSt) return 0.0;
    final st = (baseST * aliqDestino) - icmsProprio;
    return st > 0 ? st : 0.0;
  }

  /// Substituição = (Base ST * Alíquota Destino) - (Base Própria * Alíquota Própria)
  static double calcSubs({
    required double baseST,
    required double aliqExt,
    required double baseProp,
    required double aliqInt,
  }) {
    if (!kEnableIcmsSt) return 0.0;
    final icmsProprio = calcIcmsProprio(valorItem: baseProp, aliqPropria: aliqInt);
    return calcIcmsST(
      baseST: baseST,
      aliqDestino: aliqExt,
      icmsProprio: icmsProprio,
    );
  }

  /// Cálculo completo e dinâmico da Substituição Tributária por item:
  /// Base ST = (Valor Item + Frete + Despesas - Descontos) * (1 + MVA)
  /// ICMS Próprio = Valor Item * Alíquota Própria
  /// ICMS-ST = (Base ST * Alíquota Destino) - ICMS Próprio (se > 0, senão 0)
  static double calcularItem({
    required double valorItem,
    double frete = 0.0,
    double despesas = 0.0,
    double descontos = 0.0,
    required double mva,
    required double aliqPropria,
    required double aliqDestino,
  }) {
    if (!kEnableIcmsSt) return 0.0;
    final baseST = calcBaseST(
      base: valorItem,
      mva: mva,
      frete: frete,
      despesas: despesas,
      descontos: descontos,
    );
    final icmsProprio = calcIcmsProprio(
      valorItem: valorItem,
      aliqPropria: aliqPropria,
    );
    return calcIcmsST(
      baseST: baseST,
      aliqDestino: aliqDestino,
      icmsProprio: icmsProprio,
    );
  }

  /// Verifica se há substituição tributária para o produto/cliente.
  static bool isSubstituicaoPCO({required int codtrb, required int cliest}) {
    if (!kEnableIcmsSt) return false;
    return codtrb != 0;
  }
}
