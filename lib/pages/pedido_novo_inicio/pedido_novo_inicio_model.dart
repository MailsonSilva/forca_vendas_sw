import '/core/app_util.dart';
import '/backend/schema/structs/index.dart';
import 'pedido_novo_inicio_widget.dart' show PedidoNovoInicioWidget;
import 'package:flutter/material.dart';

class PedidoNovoInicioModel extends AppModel<PedidoNovoInicioWidget> {
  // Page State Variables
  ClienteResultStruct? selectedCliente;
  ListaPadraoStruct? selectedLinha;
  ListaPadraoStruct? selectedPlano;

  // Data Lists retrieved from local database
  List<ClienteResultStruct> clientes = [];
  List<ListaPadraoStruct> linhas = [];
  List<ListaPadraoStruct> planos = [];

  bool isLoading = true;

  @override
  void initState(BuildContext context) {}

  @override
  void dispose() {}
}
