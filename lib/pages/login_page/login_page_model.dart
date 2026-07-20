import '/backend/schema/structs/index.dart';
import '/core/app_theme.dart';
import '/core/app_util.dart';
import '/core/app_widgets.dart';
import 'dart:ui';
import '/action_code/index.dart' as actions;
import '/index.dart';
import 'login_page_widget.dart' show LoginPageWidget;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:percent_indicator/percent_indicator.dart';
import 'package:provider/provider.dart';

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
