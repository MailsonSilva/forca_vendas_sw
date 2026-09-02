import 'package:flutter/material.dart';
import '../../core/app_model.dart';
import '../../services/receber_duplicatas_service.dart';

class ReceberPageModel extends AppModel {
  TextEditingController? buscaTextController;
  FocusNode? buscaFocusNode;

  FiltroReceber filtroAtual = FiltroReceber.todos;
  OrdenacaoReceber ordenacaoAtual = OrdenacaoReceber.maiorAtraso;
  bool isLoading = true;

  List<ClienteReceberItem> todosClientes = [];
  List<ClienteReceberItem> clientesFiltrados = [];

  double totalGeralDevedor = 0.0;
  double totalGeralVencido = 0.0;
  double totalGeralAVencer = 0.0;
  int qtdClientesInadimplentes = 0;

  @override
  void initState(BuildContext context) {
    buscaTextController = TextEditingController();
    buscaFocusNode = FocusNode();
  }

  @override
  void dispose() {
    buscaTextController?.dispose();
    buscaFocusNode?.dispose();
  }
}
