// ignore_for_file: unused_import

import '/backend/schema/structs/index.dart';
import '/core/app_icon_button.dart';
import '/core/app_theme.dart';
import '/core/app_util.dart';
import '/core/app_widgets.dart';
import 'dart:ui';
import '/action_code/index.dart' as actions;
import 'atualizar_carga_widget.dart' show AtualizarCargaWidget;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:percent_indicator/percent_indicator.dart';
import 'package:provider/provider.dart';

class AtualizarCargaModel extends AppModel<AtualizarCargaWidget> {
  ///  Local state fields for this component.

  bool carregando = false;
  bool uploadClientes = true;
  bool uploadPedidos = true;
  List<ItemUploadStruct> arquivos = [];
  String filtroStatus = '*';

  ///  State fields for stateful widgets in this component.

  dynamic downloadDadosResult;

  dynamic uploadArquivosResult;

  @override
  void initState(BuildContext context) {}

  @override
  void dispose() {}
}
