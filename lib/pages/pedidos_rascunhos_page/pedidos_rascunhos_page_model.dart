import '/core/app_util.dart';
import 'pedidos_rascunhos_page_widget.dart' show PedidosRascunhosPageWidget;
import 'package:flutter/material.dart';
import '/action_code/listar_pedidos_pendentes.dart';

class PedidosRascunhosPageModel
    extends AppModel<PedidosRascunhosPageWidget> {
  TextEditingController? searchController;
  FocusNode? searchFocusNode;

  String filtroPeriodo = 'todos'; // todos, hoje, semana, mes
  String filtroStatus = 'todos';  // todos, rascunho, pronto, transmitido, faturado, inconsistente
  bool isLoading = true;
  List<PedidoHistoricoItem> pedidos = [];
  Set<int> selectedPedidos = {};
  bool isSpeedDialOpen = false;

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
}
