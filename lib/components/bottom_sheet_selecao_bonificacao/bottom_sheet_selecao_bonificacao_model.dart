import '/core/app_util.dart';
import 'bottom_sheet_selecao_bonificacao_widget.dart' show BottomSheetSelecaoBonificacaoWidget;
import 'package:flutter/material.dart';

class BottomSheetSelecaoBonificacaoModel extends AppModel<BottomSheetSelecaoBonificacaoWidget> {
  /// Local state fields
  List<Map<String, dynamic>> regras = [];
  Map<String, dynamic>? selectedRegra;
  List<Map<String, dynamic>> produtosElegiveis = [];
  Map<String, double> quantidadesDigitadas = {};
  Map<String, double> estoquesDisponiveis = {};
  bool isBusy = false;

  @override
  void initState(BuildContext context) {}

  @override
  void dispose() {}
}
