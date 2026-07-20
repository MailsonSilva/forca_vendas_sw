import '/backend/schema/structs/index.dart';
import '/components/loading/loading_widget.dart';
import '/core/app_icon_button.dart';
import '/core/app_theme.dart';
import '/core/app_util.dart';
import '/core/app_widgets.dart';
import 'dart:ui';
import '/action_code/index.dart' as actions;
import '/index.dart';
import 'cliente_page_widget.dart' show ClientePageWidget;
import 'package:easy_debounce/easy_debounce.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

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
