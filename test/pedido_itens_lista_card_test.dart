import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forca_de_vendas/backend/schema/structs/item_pedido_struct.dart';
import 'package:forca_de_vendas/pages/pedido_itens_lista/widgets/item_pedido_card_widget.dart';

void main() {
  group('ItemPedidoCardWidget Tests', () {
    testWidgets('exibe Marca, Referencia, Embalagem, EAN e Total no formato solicitado', (tester) async {
      final item = ItemPedidoStruct(
        codigoProduto: '9901',
        descricao: 'ABA LATERAL TANQUE BROS-125/150 PT 09/13',
        unidade: 'PC',
        embalagem: 'PC',
        precoUnitario: 51.03,
        quantidade: 1.0,
        totalItem: 51.03,
        marca: 'HONDA',
        referencia: '17500-KRE-B00',
        codbar: '7891000241501',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ItemPedidoCardWidget(
              item: item,
              onRemover: () {},
              onIncrementar: () {},
              onDecrementar: () {},
              onEditarPreco: () {},
            ),
          ),
        ),
      );

      // 1. Título do produto
      expect(find.text('ABA LATERAL TANQUE BROS-125/150 PT 09/13'), findsOneWidget);

      // 2. Linha 2: Marca: HONDA  |  Ref: 17500-KRE-B00
      expect(find.textContaining('Marca: HONDA'), findsOneWidget);
      expect(find.textContaining('Ref: 17500-KRE-B00'), findsOneWidget);

      // 3. Linha 3: Emb: PC  |  EAN: 7891000241501
      expect(find.textContaining('Emb: PC'), findsOneWidget);
      expect(find.textContaining('EAN: 7891000241501'), findsOneWidget);

      // 4. Linha 4 e 5: Preço unitário e Total R$ 51,03
      expect(find.textContaining('Total'), findsOneWidget);
    });

    testWidgets('exibe fallback SEM MARCA e N/A quando atributos forem vazios', (tester) async {
      final itemSemMarca = ItemPedidoStruct(
        codigoProduto: '9902',
        descricao: 'PRODUTO GENERICO',
        unidade: 'UN',
        embalagem: 'UN',
        precoUnitario: 10.0,
        quantidade: 1.0,
        totalItem: 10.0,
        marca: '',
        referencia: '',
        codbar: '',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ItemPedidoCardWidget(
              item: itemSemMarca,
              onRemover: () {},
              onIncrementar: () {},
              onDecrementar: () {},
              onEditarPreco: () {},
            ),
          ),
        ),
      );

      // Fallbacks
      expect(find.textContaining('Marca: SEM MARCA'), findsOneWidget);
      expect(find.textContaining('Ref: N/A'), findsOneWidget);
      expect(find.textContaining('Emb: UN'), findsOneWidget);
    });
  });
}
