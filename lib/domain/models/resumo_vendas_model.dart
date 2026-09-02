library;

/// Modelos de domínio para o Relatório de Resumo de Vendas Diário e Apuração de Comissões (`ffrmrelresven00`).
/// Mapeia tabelas de pedidos (`pckvendig000`), itens (`pckvendig010`) e alíquotas de produtos (`cadpro00`).

class ResumoVendasItemComissao {
  final int itemIndex;
  final String codigoProduto;
  final String descricaoProduto;
  final double quantidadeDigitada;
  final double quantidadeFaturada;
  final double precoUnitario;
  final double percentualComissao; // pro00_commax
  final bool isBonificado; // bontyp > 0
  final double valorItemTotal;
  final double valorComissao;

  const ResumoVendasItemComissao({
    required this.itemIndex,
    required this.codigoProduto,
    required this.descricaoProduto,
    required this.quantidadeDigitada,
    required this.quantidadeFaturada,
    required this.precoUnitario,
    required this.percentualComissao,
    required this.isBonificado,
    required this.valorItemTotal,
    required this.valorComissao,
  });

  factory ResumoVendasItemComissao.fromMap(Map<String, dynamic> map) {
    final idx = (map['ped10_item'] as num?)?.toInt() ?? 1;
    final codPro = map['ped10_codpro']?.toString() ?? map['pro00_codigo']?.toString() ?? '';
    final descPro = map['pro00_descri']?.toString() ?? 'Produto $codPro';
    final qtdDig = (map['ped10_digqtd'] as num?)?.toDouble() ?? 0.0;
    final qtdFat = (map['ped10_fatqtd'] as num?)?.toDouble() ?? 0.0;
    final pcoFat = (map['ped10_fatpco'] as num?)?.toDouble() ?? 0.0;
    final pcoDig = (map['ped10_digpco'] as num?)?.toDouble() ?? 0.0;
    final preco = pcoFat > 0.0 ? pcoFat : pcoDig;
    final comMax = (map['pro00_commax'] as num?)?.toDouble() ?? 0.0;
    final bonTyp = (map['ped10_bontyp'] as num?)?.toInt() ?? 0;
    final isBon = bonTyp > 0;

    // Se faturado > 0 usa faturado, senão usa digitado (previsto)
    final qtdEfetiva = qtdFat > 0.0 ? qtdFat : qtdDig;
    final totalItem = qtdEfetiva * preco;

    // Bonificação tem comissão zerada
    final comissao = isBon ? 0.0 : (totalItem * (comMax / 100.0));

    return ResumoVendasItemComissao(
      itemIndex: idx,
      codigoProduto: codPro,
      descricaoProduto: descPro,
      quantidadeDigitada: qtdDig,
      quantidadeFaturada: qtdFat,
      precoUnitario: preco,
      percentualComissao: comMax,
      isBonificado: isBon,
      valorItemTotal: totalItem,
      valorComissao: comissao,
    );
  }
}

class ResumoVendasPedidoItem {
  final int numeroPedido;
  final int codigoCliente;
  final String nomeCliente;
  final String dataEmissao; // yyyy-MM-dd
  final double valorBruto; // dig00_digtot
  final double valorFaturado; // dig00_fattot
  final double valorDevolucaoCortes; // dig00_digtot - dig00_fattot
  final double valorLiquido; // Venda líquida real
  final double valorComissao; // Somatório das comissões dos itens
  final int statusEnvio; // 0=rascunho, 1=empacotado, 2=enviado, 3=recebido/faturado
  final List<ResumoVendasItemComissao> itens;

  const ResumoVendasPedidoItem({
    required this.numeroPedido,
    required this.codigoCliente,
    required this.nomeCliente,
    required this.dataEmissao,
    required this.valorBruto,
    required this.valorFaturado,
    required this.valorDevolucaoCortes,
    required this.valorLiquido,
    required this.valorComissao,
    required this.statusEnvio,
    this.itens = const [],
  });

  bool get isFaturado => statusEnvio == 3;
  bool get hasCortes => valorDevolucaoCortes > 0.0;

  String get statusDescricao {
    switch (statusEnvio) {
      case 0:
        return 'Rascunho Local';
      case 1:
        return 'Empacotado (.pac)';
      case 2:
        return 'Enviado FTP';
      case 3:
        return 'Faturado ERP';
      default:
        return 'Digitado';
    }
  }

  factory ResumoVendasPedidoItem.fromMap(
    Map<String, dynamic> map, {
    List<ResumoVendasItemComissao> itens = const [],
  }) {
    final numPed = (map['ped00_numped'] as num?)?.toInt() ?? 0;
    final codCli = (map['ped00_codcli'] as num?)?.toInt() ?? 0;
    final nomeCli = map['cli00_descri']?.toString() ??
        map['ped00_clides']?.toString() ??
        'Cliente #$codCli';
    final data = map['ped00_datsys']?.toString() ?? '';
    final sttEnv = (map['ped00_sttenv'] as num?)?.toInt() ?? 0;

    final vlrBruto = (map['ped00_digtot'] as num?)?.toDouble() ?? 0.0;
    final vlrFatRaw = (map['ped00_fattot'] as num?)?.toDouble() ?? 0.0;

    // Se já faturado, fattot é oficial. Se ainda em trânsito/rascunho, líquido previsto = bruto.
    final vlrFat = (sttEnv == 3 && vlrFatRaw > 0) ? vlrFatRaw : vlrBruto;
    final vlrCortes = sttEnv == 3 ? (vlrBruto > vlrFat ? vlrBruto - vlrFat : 0.0) : 0.0;
    final vlrLiq = sttEnv == 3 ? vlrFat : vlrBruto;

    // Calcula comissão acumulada a partir dos itens
    final comissaoTotal = itens.fold(0.0, (sum, i) => sum + i.valorComissao);

    return ResumoVendasPedidoItem(
      numeroPedido: numPed,
      codigoCliente: codCli,
      nomeCliente: nomeCli,
      dataEmissao: data,
      valorBruto: vlrBruto,
      valorFaturado: vlrFat,
      valorDevolucaoCortes: vlrCortes,
      valorLiquido: vlrLiq,
      valorComissao: comissaoTotal,
      statusEnvio: sttEnv,
      itens: itens,
    );
  }
}

class ResumoVendasDia {
  final String data; // yyyy-MM-dd
  final double totalBruto;
  final double totalDevolucoes;
  final double totalLiquido;
  final double totalComissao;
  final List<ResumoVendasPedidoItem> pedidos;

  const ResumoVendasDia({
    required this.data,
    required this.totalBruto,
    required this.totalDevolucoes,
    required this.totalLiquido,
    required this.totalComissao,
    required this.pedidos,
  });

  factory ResumoVendasDia.fromPedidos(String data, List<ResumoVendasPedidoItem> pedidos) {
    double bruto = 0.0;
    double devolucoes = 0.0;
    double liquido = 0.0;
    double comissao = 0.0;

    for (final p in pedidos) {
      bruto += p.valorBruto;
      devolucoes += p.valorDevolucaoCortes;
      liquido += p.valorLiquido;
      comissao += p.valorComissao;
    }

    return ResumoVendasDia(
      data: data,
      totalBruto: bruto,
      totalDevolucoes: devolucoes,
      totalLiquido: liquido,
      totalComissao: comissao,
      pedidos: pedidos,
    );
  }
}

class ResumoVendasConsolidado {
  final DateTime dataInicio;
  final DateTime dataFim;
  final double totalVendaBruta; // c2_venval
  final double totalDevolucoes; // c2_devval
  final double totalVendaLiquida; // c2_totval
  final double totalComissao; // c2_comval
  final int totalPedidos;
  final List<ResumoVendasDia> dias;

  const ResumoVendasConsolidado({
    required this.dataInicio,
    required this.dataFim,
    required this.totalVendaBruta,
    required this.totalDevolucoes,
    required this.totalVendaLiquida,
    required this.totalComissao,
    required this.totalPedidos,
    required this.dias,
  });

  factory ResumoVendasConsolidado.empty({
    required DateTime dataInicio,
    required DateTime dataFim,
  }) {
    return ResumoVendasConsolidado(
      dataInicio: dataInicio,
      dataFim: dataFim,
      totalVendaBruta: 0.0,
      totalDevolucoes: 0.0,
      totalVendaLiquida: 0.0,
      totalComissao: 0.0,
      totalPedidos: 0,
      dias: const [],
    );
  }

  factory ResumoVendasConsolidado.fromDias({
    required DateTime dataInicio,
    required DateTime dataFim,
    required List<ResumoVendasDia> dias,
  }) {
    double bruto = 0.0;
    double devolucoes = 0.0;
    double liquido = 0.0;
    double comissao = 0.0;
    int pedidosCount = 0;

    for (final d in dias) {
      bruto += d.totalBruto;
      devolucoes += d.totalDevolucoes;
      liquido += d.totalLiquido;
      comissao += d.totalComissao;
      pedidosCount += d.pedidos.length;
    }

    return ResumoVendasConsolidado(
      dataInicio: dataInicio,
      dataFim: dataFim,
      totalVendaBruta: bruto,
      totalDevolucoes: devolucoes,
      totalVendaLiquida: liquido,
      totalComissao: comissao,
      totalPedidos: pedidosCount,
      dias: dias,
    );
  }
}
