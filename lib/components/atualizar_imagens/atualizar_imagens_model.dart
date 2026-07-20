// ignore_for_file: unused_import

import '/core/app_icon_button.dart';
import '/core/app_theme.dart';
import '/core/app_util.dart';
import '/core/app_widgets.dart';
import 'dart:ui';
import '/action_code/index.dart' as actions;
import 'atualizar_imagens_widget.dart' show AtualizarImagensWidget;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:percent_indicator/percent_indicator.dart';
import 'package:provider/provider.dart';

class AtualizarImagensModel extends AppModel<AtualizarImagensWidget> {
  ///  Local state fields for this component.

  String? tipocargaImagen;

  bool carregando = false;

  ///  State fields for stateful widgets in this component.

  // Stores action output result for [Custom Action - sincronizarImagens] action in BtnBaixar widget.
  dynamic dados;
  // Stores action output result for [Custom Action - sincronizarImagens] action in BtnSubir widget.
  dynamic dadosCopy;

  @override
  void initState(BuildContext context) {}

  @override
  void dispose() {}
}
