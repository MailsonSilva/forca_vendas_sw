import 'package:flutter_test/flutter_test.dart';
import 'package:forca_de_vendas/domain/models/produto_lookup_dto.dart';

void main() {
  group('ProdutoLookupDTO Tests', () {
    test('cria instância com todos os campos e formata referências com ambas preenchidas', () {
      const dto = ProdutoLookupDTO(
        id: 101,
        descricao: 'BISCOITO WAFER CHOCOLATE 110G',
        ean: '7891000241501',
        marca: 'NESTLÉ',
        referencia1: 'REF-7890-A',
        referencia2: 'FAB-99',
        fabricante: 'NESTLE BRASIL',
        embalagem: 'CX 24 UN',
        unidade: 'UN',
        estoqueSaldo: 142.0,
        precoTabela: 4.85,
        imagemId: 10,
      );

      expect(dto.id, equals(101));
      expect(dto.descricao, equals('BISCOITO WAFER CHOCOLATE 110G'));
      expect(dto.ean, equals('7891000241501'));
      expect(dto.marca, equals('NESTLÉ'));
      expect(dto.referencia1, equals('REF-7890-A'));
      expect(dto.referencia2, equals('FAB-99'));
      expect(dto.fabricante, equals('NESTLE BRASIL'));
      expect(dto.embalagem, equals('CX 24 UN'));
      expect(dto.unidade, equals('UN'));
      expect(dto.estoqueSaldo, equals(142.0));
      expect(dto.precoTabela, equals(4.85));
      expect(dto.imagemId, equals(10));
      expect(dto.referenciaFormatada, equals('REF-7890-A / FAB-99'));
    });

    test('referenciaFormatada retorna apenas referencia1 quando referencia2 for nula ou vazia', () {
      const dto1 = ProdutoLookupDTO(
        id: 102,
        descricao: 'PRODUTO 2',
        marca: 'BAMBINO',
        referencia1: 'REF-123',
        referencia2: null,
        embalagem: 'UN',
        unidade: 'UN',
        estoqueSaldo: 10.0,
        precoTabela: 15.0,
      );
      expect(dto1.referenciaFormatada, equals('REF-123'));

      final dto2 = dto1.copyWith(referencia1: 'REF-XYZ', referencia2: '   ');
      expect(dto2.referenciaFormatada, equals('REF-XYZ'));
    });

    test('referenciaFormatada retorna apenas referencia2 quando referencia1 for nula ou vazia', () {
      const dto = ProdutoLookupDTO(
        id: 103,
        descricao: 'PRODUTO 3',
        marca: 'SEM MARCA',
        referencia1: '',
        referencia2: 'REF-FAB-99',
        embalagem: 'UN',
        unidade: 'UN',
        estoqueSaldo: 5.0,
        precoTabela: 20.0,
      );
      expect(dto.referenciaFormatada, equals('REF-FAB-99'));
    });

    test('referenciaFormatada retorna N/A quando ambas as referências forem nulas ou vazias', () {
      const dto = ProdutoLookupDTO(
        id: 104,
        descricao: 'PRODUTO 4',
        marca: 'SEM MARCA',
        referencia1: null,
        referencia2: null,
        embalagem: 'UN',
        unidade: 'UN',
        estoqueSaldo: 0.0,
        precoTabela: 1.0,
      );
      expect(dto.referenciaFormatada, equals('N/A'));

      final dtoVazio = dto.copyWith(referencia1: '  ', referencia2: '');
      expect(dtoVazio.referenciaFormatada, equals('N/A'));
    });

    test('fromMap e toMap realizam a serialização correta', () {
      final map = {
        'produto_id': 105,
        'descricao': 'PRODUTO MAP',
        'ean': '7890000000001',
        'marca_nome': 'MARCA X',
        'referencia_1': 'REF1',
        'referencia_2': 'REF2',
        'fabricante_nome': 'FAB X',
        'embalagem': 'CX 10',
        'unidade': 'CX',
        'estoque_saldo': 50.5,
        'preco_tabela': 12.34,
        'imagem_id': 7,
      };

      final dto = ProdutoLookupDTO.fromMap(map);
      expect(dto.id, equals(105));
      expect(dto.descricao, equals('PRODUTO MAP'));
      expect(dto.ean, equals('7890000000001'));
      expect(dto.marca, equals('MARCA X'));
      expect(dto.referencia1, equals('REF1'));
      expect(dto.referencia2, equals('REF2'));
      expect(dto.fabricante, equals('FAB X'));
      expect(dto.embalagem, equals('CX 10'));
      expect(dto.unidade, equals('CX'));
      expect(dto.estoqueSaldo, equals(50.5));
      expect(dto.precoTabela, equals(12.34));
      expect(dto.imagemId, equals(7));

      final serialized = dto.toMap();
      expect(serialized['produto_id'], equals(105));
      expect(serialized['descricao'], equals('PRODUTO MAP'));
      expect(serialized['ean'], equals('7890000000001'));
      expect(serialized['marca_nome'], equals('MARCA X'));
      expect(serialized['referencia_1'], equals('REF1'));
      expect(serialized['referencia_2'], equals('REF2'));
      expect(serialized['fabricante_nome'], equals('FAB X'));
      expect(serialized['embalagem'], equals('CX 10'));
      expect(serialized['unidade'], equals('CX'));
      expect(serialized['estoque_saldo'], equals(50.5));
      expect(serialized['preco_tabela'], equals(12.34));
      expect(serialized['imagem_id'], equals(7));
    });
  });
}
