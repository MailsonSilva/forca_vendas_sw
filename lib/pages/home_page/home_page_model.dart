import '/components/botao_menu_home/botao_menu_home_widget.dart';
import '/components/modal_cliente/modal_cliente_widget.dart';
import '/core/app_theme.dart';
import '/core/app_util.dart';
import '/core/app_widgets.dart';
import 'dart:ui';
import '/index.dart';
import 'home_page_widget.dart' show HomePageWidget;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

class HomePageModel extends AppModel<HomePageWidget> {
  ///  State fields for stateful widgets in this page.

  // Model for botaoMenuHome component.
  late BotaoMenuHomeModel botaoMenuHomeModel1;
  // Model for botaoMenuHome component.
  late BotaoMenuHomeModel botaoMenuHomeModel2;
  // Model for botaoMenuHome component.
  late BotaoMenuHomeModel botaoMenuHomeModel3;
  // Model for botaoMenuHome component.
  late BotaoMenuHomeModel botaoMenuHomeModel4;

  @override
  void initState(BuildContext context) {
    botaoMenuHomeModel1 = createModel(context, () => BotaoMenuHomeModel());
    botaoMenuHomeModel2 = createModel(context, () => BotaoMenuHomeModel());
    botaoMenuHomeModel3 = createModel(context, () => BotaoMenuHomeModel());
    botaoMenuHomeModel4 = createModel(context, () => BotaoMenuHomeModel());
  }

  @override
  void dispose() {
    botaoMenuHomeModel1.dispose();
    botaoMenuHomeModel2.dispose();
    botaoMenuHomeModel3.dispose();
    botaoMenuHomeModel4.dispose();
  }
}
