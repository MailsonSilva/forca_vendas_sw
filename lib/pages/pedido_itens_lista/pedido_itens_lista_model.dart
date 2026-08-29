import '/core/app_util.dart';
import '/backend/schema/structs/index.dart';
import 'pedido_itens_lista_widget.dart' show PedidoItensListaWidget;
import 'package:flutter/material.dart';

class PedidoItensListaModel extends AppModel<PedidoItensListaWidget> {
  // Page State Variables
  List<ItemPedidoStruct> carrinhoItens = [];
  int totalItens = 0;
  double valorTotal = 0.0;

  List<ProdutoResultStruct> produtosPesquisados = [];
  bool isLoading = false;

  // Search Field Controller & FocusNode
  TextEditingController? searchController;
  FocusNode? searchFocusNode;

  @override
  void initState(BuildContext context) {
    searchController = TextEditingController();
    searchFocusNode = FocusNode();
  }

  @override
  void dispose() {
    searchController?.dispose();
    searchFocusNode?.dispose();
  }

  // Helper method to recalculate totals reatively
  void recalcularTotais() {
    totalItens = carrinhoItens.fold(0, (sum, item) {
      final q = item.isBonificacao ? item.quantidadeBonificada : item.quantidade;
      return sum + (q > 0 ? (q < 1 ? 1 : q.round()) : 0);
    });
    valorTotal = carrinhoItens.fold(0.0, (sum, item) => sum + item.totalItem);
  }

  double get totalGeral => valorTotal;
}
