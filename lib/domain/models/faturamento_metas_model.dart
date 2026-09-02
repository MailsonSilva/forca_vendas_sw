library;

/// Modelos de domínio para o Módulo de Faturamento, Metas e Desempenho do Vendedor
/// Mapeia a tabela `estfatcvd00` / `relestfatcvd00` e data de sincronização `estfatdat00`.

class ResultadoValidacaoLimitePF {
  final bool valido;
  final double limiteTotal;
  final double totalAcumulado;
  final double valorPedido;
  final double limiteRestante;
  final String? mensagemBloqueio;

  const ResultadoValidacaoLimitePF({
    required this.valido,
    this.limiteTotal = 0.0,
    this.totalAcumulado = 0.0,
    this.valorPedido = 0.0,
    this.limiteRestante = 0.0,
    this.mensagemBloqueio,
  });

  factory ResultadoValidacaoLimitePF.liberado({
    double limiteTotal = 0.0,
    double totalAcumulado = 0.0,
    double valorPedido = 0.0,
    double limiteRestante = 0.0,
  }) {
    return ResultadoValidacaoLimitePF(
      valido: true,
      limiteTotal: limiteTotal,
      totalAcumulado: totalAcumulado,
      valorPedido: valorPedido,
      limiteRestante: limiteRestante,
    );
  }

  factory ResultadoValidacaoLimitePF.bloqueado({
    required double limiteTotal,
    required double totalAcumulado,
    required double valorPedido,
    required double limiteRestante,
    required String mensagem,
  }) {
    return ResultadoValidacaoLimitePF(
      valido: false,
      limiteTotal: limiteTotal,
      totalAcumulado: totalAcumulado,
      valorPedido: valorPedido,
      limiteRestante: limiteRestante,
      mensagemBloqueio: mensagem,
    );
  }
}

class MetaSegmentoModel {
  final int codFil;
  final int codVen;
  final int tipoPessoa; // 1 = Pessoa Física, 2 = Pessoa Jurídica
  final String descricaoSegmento; // "Fisica", "Juridica"
  final double valorMeta; // fat00_vlrcalven
  final double faturadoErp; // fat00_vlrfatven
  final double digitadoTransito; // fat00_vlrdigven (sttenv in (1, 2))
  final double rascunhoLocal; // fat00_vlrdigloc (sttenv = 0)
  final double totalConsolidado; // fat00_vlrtotven = faturadoErp + digitadoTransito + rascunhoLocal
  final double percentualAtingido; // fat00_vlrtotper = (totalConsolidado / valorMeta) * 100
  final double limiteLiberadoPf; // fat00_vlrtotlib (específico de PF)
  final double limiteRestantePf; // fat00_vlrtotlib - totalConsolidado

  const MetaSegmentoModel({
    required this.codFil,
    required this.codVen,
    required this.tipoPessoa,
    required this.descricaoSegmento,
    required this.valorMeta,
    required this.faturadoErp,
    required this.digitadoTransito,
    required this.rascunhoLocal,
    required this.totalConsolidado,
    required this.percentualAtingido,
    this.limiteLiberadoPf = 0.0,
    this.limiteRestantePf = 0.0,
  });

  bool get isPessoaFisica => tipoPessoa == 1;
  bool get isPessoaJuridica => tipoPessoa == 2;
  bool get metaAtingida => percentualAtingido >= 100.0;

  factory MetaSegmentoModel.empty({
    int codFil = 1,
    int codVen = 0,
    int tipoPessoa = 1,
    String? descricao,
  }) {
    final desc = descricao ?? (tipoPessoa == 1 ? 'Fisica' : 'Juridica');
    return MetaSegmentoModel(
      codFil: codFil,
      codVen: codVen,
      tipoPessoa: tipoPessoa,
      descricaoSegmento: desc,
      valorMeta: 0.0,
      faturadoErp: 0.0,
      digitadoTransito: 0.0,
      rascunhoLocal: 0.0,
      totalConsolidado: 0.0,
      percentualAtingido: 0.0,
      limiteLiberadoPf: 0.0,
      limiteRestantePf: 0.0,
    );
  }

  factory MetaSegmentoModel.fromMap(
    Map<String, dynamic> map, {
    double digitadoTransito = 0.0,
    double rascunhoLocal = 0.0,
  }) {
    final codFil = (map['fat00_codfil'] as num?)?.toInt() ?? 1;
    final codVen = (map['fat00_codven'] as num?)?.toInt() ?? 0;
    final tipoPessoa = (map['fat00_clityp'] as num?)?.toInt() ?? 1;
    final descricao = map['fat00_clides']?.toString() ?? (tipoPessoa == 1 ? 'Fisica' : 'Juridica');
    final vlrMeta = (map['fat00_vlrcalven'] as num?)?.toDouble() ?? 0.0;
    final vlrFatErp = (map['fat00_vlrfatven'] as num?)?.toDouble() ?? 0.0;
    final vlrTotLib = (map['fat00_vlrtotlib'] as num?)?.toDouble() ?? 0.0;

    final transito = digitadoTransito != 0.0
        ? digitadoTransito
        : ((map['digitado_transito'] as num?)?.toDouble() ??
            (map['fat00_vlrdigven'] as num?)?.toDouble() ??
            0.0);

    final rascunho = rascunhoLocal != 0.0
        ? rascunhoLocal
        : ((map['rascunho_local'] as num?)?.toDouble() ??
            (map['fat00_vlrdigloc'] as num?)?.toDouble() ??
            0.0);

    final totalConsolidado = vlrFatErp + transito + rascunho;
    final percentual = vlrMeta > 0.0 ? (totalConsolidado / vlrMeta) * 100.0 : 0.0;
    final limiteRestante = vlrTotLib > 0.0 ? (vlrTotLib - totalConsolidado) : 0.0;

    return MetaSegmentoModel(
      codFil: codFil,
      codVen: codVen,
      tipoPessoa: tipoPessoa,
      descricaoSegmento: descricao,
      valorMeta: vlrMeta,
      faturadoErp: vlrFatErp,
      digitadoTransito: transito,
      rascunhoLocal: rascunho,
      totalConsolidado: totalConsolidado,
      percentualAtingido: percentual,
      limiteLiberadoPf: vlrTotLib,
      limiteRestantePf: limiteRestante,
    );
  }
}

class FaturamentoConsolidadoResumo {
  final MetaSegmentoModel pessoaFisica;
  final MetaSegmentoModel pessoaJuridica;
  final double totalGeralMeta;
  final double totalGeralRealizado;
  final double percentualGeralAtingido;
  final String? dataSincronizacao;

  const FaturamentoConsolidadoResumo({
    required this.pessoaFisica,
    required this.pessoaJuridica,
    required this.totalGeralMeta,
    required this.totalGeralRealizado,
    required this.percentualGeralAtingido,
    this.dataSincronizacao,
  });

  factory FaturamentoConsolidadoResumo.empty({int codFil = 1, int codVen = 0}) {
    return FaturamentoConsolidadoResumo(
      pessoaFisica: MetaSegmentoModel.empty(codFil: codFil, codVen: codVen, tipoPessoa: 1),
      pessoaJuridica: MetaSegmentoModel.empty(codFil: codFil, codVen: codVen, tipoPessoa: 2),
      totalGeralMeta: 0.0,
      totalGeralRealizado: 0.0,
      percentualGeralAtingido: 0.0,
    );
  }

  factory FaturamentoConsolidadoResumo.calcular({
    required MetaSegmentoModel pf,
    required MetaSegmentoModel pj,
    String? dataSincronizacao,
  }) {
    final metaTotal = pf.valorMeta + pj.valorMeta;
    final realizadoTotal = pf.totalConsolidado + pj.totalConsolidado;
    final percentualGeral = metaTotal > 0.0 ? (realizadoTotal / metaTotal) * 100.0 : 0.0;

    return FaturamentoConsolidadoResumo(
      pessoaFisica: pf,
      pessoaJuridica: pj,
      totalGeralMeta: metaTotal,
      totalGeralRealizado: realizadoTotal,
      percentualGeralAtingido: percentualGeral,
      dataSincronizacao: dataSincronizacao,
    );
  }
}
