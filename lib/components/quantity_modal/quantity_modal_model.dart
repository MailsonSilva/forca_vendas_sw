import '/core/app_theme.dart';
import '/core/app_util.dart';
import '/core/app_widgets.dart';
import 'dart:ui';
import '/action_code/index.dart' as actions;
import 'quantity_modal_widget.dart' show QuantityModalWidget;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

class QuantityModalModel extends AppModel<QuantityModalWidget> {
  ///  State fields for stateful widgets in this component.

  // Stores action output result for [Custom Action - AjustarQuantidade] action in DecrementarButton widget.
  int? novaQtdMinus;
  // Stores action output result for [Custom Action - AjustarQuantidade] action in IncrementarButton widget.
  int? novaQtdPlus;
  // Stores action output result for [Custom Action - SalvarItemPedido] action in ConfirmarPedidoButton widget.
  bool? itemSalvo;

  @override
  void initState(BuildContext context) {}

  @override
  void dispose() {}
}
