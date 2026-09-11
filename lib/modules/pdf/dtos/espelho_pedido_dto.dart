import 'dart:typed_data';

/// Filtros disponíveis para os itens no PDF do espelho de venda.
///
/// Preserva a regra de negócio do sistema legado C++/Qt:
/// - [todos]: Exibe todos os itens sem restrição.
/// - [apenasCortes]: Exibe apenas itens com corte (qtdDigitada > qtdFaturada).
/// - [semCortes]: Exibe apenas itens sem corte (qtdDigitada == qtdFaturada).
/// - [apenasBonificados]: Exibe apenas itens marcados como bonificação.
enum FiltroItensPdf { todos, apenasCortes, semCortes, apenasBonificados }

/// Representa um item do pedido no espelho de venda.
class ItemEspelhoDTO {
  final int sequencial;
  final int codigoProduto;
  final String codigoEAN;
  final String descricao;
  final String marca;
  final String unidade;
  final double quantidadeDigitada;
  final double quantidadeFaturada;
  final double precoUnitario;
  final double descontoPercentual;
  final double valorTotal;
  final bool isBonificacao;

  ItemEspelhoDTO({
    required this.sequencial,
    required this.codigoProduto,
    required this.codigoEAN,
    required this.descricao,
    required this.marca,
    this.unidade = 'UN',
    required this.quantidadeDigitada,
    required this.quantidadeFaturada,
    required this.precoUnitario,
    this.descontoPercentual = 0.0,
    required this.valorTotal,
    this.isBonificacao = false,
  });

  /// Diferença entre quantidade digitada e faturada.
  /// Indica itens que foram cortados no faturamento.
  double get corte => quantidadeDigitada - quantidadeFaturada;
}

/// Representa uma parcela/duplicata do pedido.
class DuplicataEspelhoDTO {
  final int numeroParcela;
  final DateTime dataVencimento;
  final double valor;

  DuplicataEspelhoDTO({
    required this.numeroParcela,
    required this.dataVencimento,
    required this.valor,
  });
}

/// DTO completo do espelho de venda, agregando cabeçalho, cliente,
/// itens, duplicatas e resumo financeiro.
class EspelhoPedidoDTO {
  final int numeroPedido;
  final String numeroNotaFiscal;
  final String numeroPacote;
  final DateTime dataEmissao;
  final String vendedorCodigo;
  final String vendedorNome;

  // Dados da Empresa / Filial (Cabeçalho Central)
  final String empresaEndereco;
  final String empresaBairroCep;
  final String empresaCidadeUf;
  final String empresaTelefone;

  // Dados do Cliente
  final String clienteCodigo;
  final String clienteRazaoSocial;
  final String clienteNomeFantasia;
  final String clienteCpfCnpj;
  final String clienteIE;
  final String clienteEndereco;
  final String clienteNumero;
  final String clienteBairro;
  final String clienteCep;
  final String clienteCidade;
  final String clienteUf;
  final String clienteTelefone;
  final Uint8List? clienteFotoBytes;

  // Condições Comerciais
  final String planoPagamento;
  final String linhaProduto;
  final String agenteCobrador;
  final String status;
  final String observacao;

  // Resumo Financeiro
  final double valorTotalDigitado;
  final double valorTotalFaturado;
  final double valorTotalBonificado;
  final double valorSubstituicaoTributaria;
  final double valorDescontoTotal;
  final List<ItemEspelhoDTO> itens;
  final List<DuplicataEspelhoDTO> duplicatas;

  EspelhoPedidoDTO({
    required this.numeroPedido,
    required this.numeroNotaFiscal,
    this.numeroPacote = '',
    required this.dataEmissao,
    required this.vendedorCodigo,
    required this.vendedorNome,
    this.empresaEndereco = 'AV. LOURENÇO VIEIRA DA SILVA, 16 - QUADRA 56',
    this.empresaBairroCep = 'BAIRRO: SÃO CRISTOVAO - CEP: 65055-310',
    this.empresaCidadeUf = 'CIDADE: SÃO LUIS - UF: MA',
    this.empresaTelefone = 'FONE: (98) 3302-6091 - HELPDESK: (98) 3302-6091',
    required this.clienteCodigo,
    required this.clienteRazaoSocial,
    required this.clienteNomeFantasia,
    required this.clienteCpfCnpj,
    required this.clienteIE,
    required this.clienteEndereco,
    this.clienteNumero = '',
    this.clienteBairro = '',
    this.clienteCep = '',
    this.clienteCidade = '',
    this.clienteUf = '',
    this.clienteTelefone = '',
    this.clienteFotoBytes,
    required this.planoPagamento,
    required this.linhaProduto,
    required this.agenteCobrador,
    required this.status,
    required this.observacao,
    required this.valorTotalDigitado,
    required this.valorTotalFaturado,
    required this.valorTotalBonificado,
    required this.valorSubstituicaoTributaria,
    this.valorDescontoTotal = 0.0,
    required this.itens,
    this.duplicatas = const [],
  });

  // Getters para campos calculados do rodapé de totais
  int get totalItens => itens.length;
  double get totalQtdPedido => itens.fold(0.0, (sum, i) => sum + i.quantidadeDigitada);
  double get totalQtdFatura => itens.fold(0.0, (sum, i) => sum + i.quantidadeFaturada);
  double get valorLiquido => valorTotalFaturado > 0 ? valorTotalFaturado : (valorTotalDigitado - valorDescontoTotal);
}
