import 'package:flutter_test/flutter_test.dart';
import 'package:forca_de_vendas/modules/pdf/dtos/espelho_pedido_dto.dart';

void main() {
  group('ItemEspelhoDTO', () {
    test('corte returns difference between quantidadeDigitada and quantidadeFaturada', () {
      final item = ItemEspelhoDTO(
        sequencial: 1,
        codigoProduto: 100,
        codigoEAN: '7891234567890',
        descricao: 'Produto Teste',
        marca: 'Marca X',
        quantidadeDigitada: 10,
        quantidadeFaturada: 7,
        precoUnitario: 25.50,
        valorTotal: 178.50,
      );

      expect(item.corte, 3.0);
    });

    test('corte returns zero when fully fulfilled', () {
      final item = ItemEspelhoDTO(
        sequencial: 1,
        codigoProduto: 200,
        codigoEAN: '7891234567891',
        descricao: 'Produto Completo',
        marca: 'Marca Y',
        quantidadeDigitada: 5,
        quantidadeFaturada: 5,
        precoUnitario: 10.0,
        valorTotal: 50.0,
      );

      expect(item.corte, 0.0);
    });

    test('corte returns full quantity when nothing was fulfilled', () {
      final item = ItemEspelhoDTO(
        sequencial: 2,
        codigoProduto: 300,
        codigoEAN: '7891234567892',
        descricao: 'Produto Sem Faturamento',
        marca: '',
        quantidadeDigitada: 20,
        quantidadeFaturada: 0,
        precoUnitario: 5.0,
        valorTotal: 100.0,
      );

      expect(item.corte, 20.0);
    });
  });

  group('DuplicataEspelhoDTO', () {
    test('stores parcela data correctly', () {
      final dup = DuplicataEspelhoDTO(
        numeroParcela: 1,
        dataVencimento: DateTime(2026, 10, 15),
        valor: 1500.0,
      );

      expect(dup.numeroParcela, 1);
      expect(dup.dataVencimento, DateTime(2026, 10, 15));
      expect(dup.valor, 1500.0);
    });
  });

  group('EspelhoPedidoDTO', () {
    test('stores all order data correctly', () {
      final pedido = EspelhoPedidoDTO(
        numeroPedido: 12345,
        numeroNotaFiscal: 'NF-001',
        dataEmissao: DateTime(2026, 9, 10, 14, 30),
        vendedorCodigo: 'V001',
        vendedorNome: 'João Silva',
        clienteCodigo: 'C001',
        clienteRazaoSocial: 'Empresa ABC Ltda',
        clienteNomeFantasia: 'ABC Store',
        clienteCpfCnpj: '12.345.678/0001-90',
        clienteIE: '123456789',
        clienteEndereco: 'Rua das Flores, 123 - São Paulo/SP',
        planoPagamento: '30/60/90',
        linhaProduto: 'Linha Premium',
        agenteCobrador: 'Agente Carlos',
        status: 'Transmitido',
        observacao: 'Entregar no período da manhã',
        valorTotalDigitado: 5000.0,
        valorTotalFaturado: 4500.0,
        valorTotalBonificado: 200.0,
        valorSubstituicaoTributaria: 150.0,
        valorDescontoTotal: 50.0,
        itens: [
          ItemEspelhoDTO(
            sequencial: 1,
            codigoProduto: 100,
            codigoEAN: '7891234567890',
            descricao: 'Produto A',
            marca: 'Marca X',
            quantidadeDigitada: 10,
            quantidadeFaturada: 8,
            precoUnitario: 50.0,
            valorTotal: 400.0,
          ),
        ],
        duplicatas: [
          DuplicataEspelhoDTO(
            numeroParcela: 1,
            dataVencimento: DateTime(2026, 10, 10),
            valor: 2250.0,
          ),
        ],
      );

      expect(pedido.numeroPedido, 12345);
      expect(pedido.itens.length, 1);
      expect(pedido.duplicatas.length, 1);
      expect(pedido.valorDescontoTotal, 50.0);
    });

    test('duplicatas defaults to empty list', () {
      final pedido = EspelhoPedidoDTO(
        numeroPedido: 1,
        numeroNotaFiscal: '',
        dataEmissao: DateTime(2026, 1, 1),
        vendedorCodigo: '',
        vendedorNome: '',
        clienteCodigo: '',
        clienteRazaoSocial: '',
        clienteNomeFantasia: '',
        clienteCpfCnpj: '',
        clienteIE: '',
        clienteEndereco: '',
        planoPagamento: '',
        linhaProduto: '',
        agenteCobrador: '',
        status: '',
        observacao: '',
        valorTotalDigitado: 0,
        valorTotalFaturado: 0,
        valorTotalBonificado: 0,
        valorSubstituicaoTributaria: 0,
        itens: [],
      );

      expect(pedido.duplicatas, isEmpty);
      expect(pedido.valorDescontoTotal, 0.0);
    });

    test('supports new detailed fields and calculated totals matching pre-pedido layout', () {
      final item1 = ItemEspelhoDTO(
        sequencial: 1,
        codigoProduto: 39892,
        codigoEAN: '',
        descricao: 'BIELA COMPLETA',
        marca: 'AOLX',
        unidade: 'PC',
        quantidadeDigitada: 4,
        quantidadeFaturada: 4,
        precoUnitario: 43.51,
        valorTotal: 174.04,
      );

      final item2 = ItemEspelhoDTO(
        sequencial: 2,
        codigoProduto: 38592,
        codigoEAN: '',
        descricao: 'CHAVE IGN',
        marca: 'RT',
        unidade: 'UN',
        quantidadeDigitada: 10,
        quantidadeFaturada: 10,
        precoUnitario: 18.95,
        valorTotal: 189.50,
      );

      final pedido = EspelhoPedidoDTO(
        numeroPedido: 32062,
        numeroNotaFiscal: '4462889',
        numeroPacote: 'p22-1065',
        dataEmissao: DateTime(2026, 5, 8),
        vendedorCodigo: '22',
        vendedorNome: 'GRACILENE',
        empresaEndereco: 'AV. LOURENÇO VIEIRA DA SILVA, 16 - QUADRA 56',
        empresaBairroCep: 'BAIRRO: SÃO CRISTOVAO - CEP: 65055-310',
        empresaCidadeUf: 'CIDADE: SÃO LUIS - UF: MA',
        empresaTelefone: 'FONE: (98) 3302-6091 - HELPDESK: (98) 3302-6091',
        clienteCodigo: '6',
        clienteRazaoSocial: 'S SANTOS LTDA',
        clienteNomeFantasia: 'ULTRA MOTO BIKE',
        clienteCpfCnpj: '03.850.194/0001-02',
        clienteIE: '121.762.645',
        clienteEndereco: 'AVENIDA 04/ AV ISABEL CAFETEIRA',
        clienteNumero: '120',
        clienteBairro: 'JARDIM AMERICA',
        clienteCep: '65058-324',
        clienteCidade: 'SAO LUIS',
        clienteUf: 'MA',
        clienteTelefone: '(98) 85566673',
        planoPagamento: '15 DIAS',
        linhaProduto: 'LINHA GERAL',
        agenteCobrador: 'PROMISSORIA',
        status: 'Faturado',
        observacao: '',
        valorTotalDigitado: 363.54,
        valorTotalFaturado: 363.54,
        valorTotalBonificado: 0,
        valorSubstituicaoTributaria: 0,
        valorDescontoTotal: 0,
        itens: [item1, item2],
      );

      expect(item1.unidade, equals('PC'));
      expect(item2.unidade, equals('UN'));
      expect(pedido.numeroPacote, equals('p22-1065'));
      expect(pedido.empresaEndereco, contains('AV. LOURENÇO'));
      expect(pedido.clienteNumero, equals('120'));
      expect(pedido.clienteBairro, equals('JARDIM AMERICA'));
      expect(pedido.clienteCep, equals('65058-324'));
      expect(pedido.clienteCidade, equals('SAO LUIS'));
      expect(pedido.clienteUf, equals('MA'));
      expect(pedido.clienteTelefone, equals('(98) 85566673'));

      // Calculated totals
      expect(pedido.totalItens, equals(2));
      expect(pedido.totalQtdPedido, equals(14.0));
      expect(pedido.totalQtdFatura, equals(14.0));
      expect(pedido.valorLiquido, equals(363.54));
    });
  });

  group('FiltroItensPdf', () {
    test('enum has all 4 expected values', () {
      expect(FiltroItensPdf.values.length, 4);
      expect(FiltroItensPdf.values, contains(FiltroItensPdf.todos));
      expect(FiltroItensPdf.values, contains(FiltroItensPdf.apenasCortes));
      expect(FiltroItensPdf.values, contains(FiltroItensPdf.semCortes));
      expect(FiltroItensPdf.values, contains(FiltroItensPdf.apenasBonificados));
    });
  });
}
