import '/components/botao_menu_home/botao_menu_home_widget.dart';
import '/core/app_util.dart';
import '/index.dart';
import 'home_page_widget.dart' show HomePageWidget;
import 'package:flutter/material.dart';

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
  // Model for botaoMenuHome component (Relatórios).
  late BotaoMenuHomeModel botaoMenuHomeModel5;

  @override
  void initState(BuildContext context) {
    botaoMenuHomeModel1 = createModel(context, () => BotaoMenuHomeModel());
    botaoMenuHomeModel2 = createModel(context, () => BotaoMenuHomeModel());
    botaoMenuHomeModel3 = createModel(context, () => BotaoMenuHomeModel());
    botaoMenuHomeModel4 = createModel(context, () => BotaoMenuHomeModel());
    botaoMenuHomeModel5 = createModel(context, () => BotaoMenuHomeModel());
  }

  @override
  void dispose() {
    botaoMenuHomeModel1.dispose();
    botaoMenuHomeModel2.dispose();
    botaoMenuHomeModel3.dispose();
    botaoMenuHomeModel4.dispose();
    botaoMenuHomeModel5.dispose();
  }
}
