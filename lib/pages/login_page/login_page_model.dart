import '/backend/schema/structs/index.dart';
import '/core/app_util.dart';
import '/index.dart';
import 'login_page_widget.dart' show LoginPageWidget;
import 'package:flutter/material.dart';

class LoginPageModel extends AppModel<LoginPageWidget> {
  ///  State fields for stateful widgets in this page.

  // Stores action output result for [Custom Action - CheckDatabaseExists] action in LoginPage widget.
  bool? dbExists;
  // State field(s) for empresaCodigoField widget.
  FocusNode? empresaCodigoFieldFocusNode;
  TextEditingController? empresaCodigoFieldTextController;
  String? Function(BuildContext, String?)?
      empresaCodigoFieldTextControllerValidator;
  // State field(s) for vendedorCodigoField widget.
  FocusNode? vendedorCodigoFieldFocusNode;
  TextEditingController? vendedorCodigoFieldTextController;
  String? Function(BuildContext, String?)?
      vendedorCodigoFieldTextControllerValidator;
  // Stores action output result for [Custom Action - firstAccessLogin] action in EntrarButton widget.
  FirstAccessResultStruct? firstAccessResult;
  // Stores action output result for [Custom Action - OfflineLogin] action in EntrarButton widget.
  LoginResultStruct? firstAccessLogin;
  // Stores action output result for [Custom Action - OfflineLogin] action in EntrarButton widget.
  LoginResultStruct? offlineLogin;

  @override
  void initState(BuildContext context) {}

  @override
  void dispose() {
    empresaCodigoFieldFocusNode?.dispose();
    empresaCodigoFieldTextController?.dispose();

    vendedorCodigoFieldFocusNode?.dispose();
    vendedorCodigoFieldTextController?.dispose();
  }
}
