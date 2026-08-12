import '/backend/schema/structs/index.dart';
import '/components/loading/loading_widget.dart';
import '/core/app_util.dart';
import '/index.dart';
import 'cliente_page_widget.dart' show ClientePageWidget;
import 'package:flutter/material.dart';

class ClientePageModel extends AppModel<ClientePageWidget> {
  ///  Local state fields for this page.

  List<ClienteResultStruct> clientesResultPage = [];
  void addToClientesResultPage(ClienteResultStruct item) =>
      clientesResultPage.add(item);
  void removeFromClientesResultPage(ClienteResultStruct item) =>
      clientesResultPage.remove(item);
  void removeAtIndexFromClientesResultPage(int index) =>
      clientesResultPage.removeAt(index);
  void insertAtIndexInClientesResultPage(int index, ClienteResultStruct item) =>
      clientesResultPage.insert(index, item);
  void updateClientesResultPageAtIndex(
          int index, Function(ClienteResultStruct) updateFn) =>
      clientesResultPage[index] = updateFn(clientesResultPage[index]);

  String? buscaCliente;

  ///  State fields for stateful widgets in this page.

  // Stores action output result for [Custom Action - pesquisaCliente] action in ClientePage widget.
  List<ClienteResultStruct>? clientesIniciais;
  // State field(s) for BuscaClienteField widget.
  FocusNode? buscaClienteFieldFocusNode;
  TextEditingController? buscaClienteFieldTextController;
  String? Function(BuildContext, String?)?
      buscaClienteFieldTextControllerValidator;
  // Stores action output result for [Custom Action - pesquisaCliente] action in BuscaClienteField widget.
  List<ClienteResultStruct>? resultadoBusca;
  // Model for Loading component.
  late LoadingModel loadingModel;

  @override
  void initState(BuildContext context) {
    loadingModel = createModel(context, () => LoadingModel());
  }

  @override
  void dispose() {
    buscaClienteFieldFocusNode?.dispose();
    buscaClienteFieldTextController?.dispose();

    loadingModel.dispose();
  }
}
