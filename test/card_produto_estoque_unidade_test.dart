import 'package:flutter_test/flutter_test.dart';
import 'package:forca_de_vendas/backend/schema/structs/produto_result_struct.dart';
import 'package:forca_de_vendas/core/app_functions.dart' as functions;

void main() {
  group('Exibição de Estoque e Unidade Comercial', () {
    test('formata a quantidade pura do estoque sem sufixos fixos de unidade', () {
      final produtoPC = ProdutoResultStruct(
        codigo: '1001',
        descricao: 'PECA TESTE',
        unidade: 'PC',
        saldoEstoque: 15.0,
        estoqueAtual: 15.0,
      );

      final textoEstoque = functions.formatQuantity(
        produtoPC.saldoEstoque,
        unidade: produtoPC.unidade,
      );

      // Deve ser exatamente '15', sem ' PC', ' PR' ou qualquer sigla concatenada
      expect(textoEstoque, '15');
      expect(textoEstoque.contains('PC'), isFalse);
      expect(textoEstoque.contains('PR'), isFalse);
    });

    test('exibe a unidade comercial diretamente de pro00_unidad separada do estoque', () {
      final produto = ProdutoResultStruct(
        codigo: '1002',
        descricao: 'PARAFUSO',
        unidade: 'PC',
        embalagem: 'CX 100',
        saldoEstoque: 25.0,
      );

      // Quantidade pura do estoque
      final qtdPura = functions.formatQuantity(produto.saldoEstoque, unidade: produto.unidade);
      expect(qtdPura, '25');

      // Unidade comercial pura do campo pro00_unidad
      final unidadeComercial = produto.unidade.trim().isNotEmpty ? produto.unidade.trim() : 'UN';
      expect(unidadeComercial, 'PC');
    });

    test('formata estoque fracionado com 3 casas decimais mantendo quantidade pura', () {
      final produtoKG = ProdutoResultStruct(
        codigo: '1003',
        descricao: 'PRODUTO QUILO',
        unidade: 'KG',
        saldoEstoque: 4.75,
      );

      final textoEstoque = functions.formatQuantity(
        produtoKG.saldoEstoque,
        unidade: produtoKG.unidade,
      );

      expect(textoEstoque, '4,750');
      expect(textoEstoque.contains('KG'), isFalse);
    });
  });
}
