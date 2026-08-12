import '/core/app_util.dart';
import 'package:flutter/material.dart';
import 'bottom_sheet_combos_widget.dart' show BottomSheetCombosWidget;

class BottomSheetCombosModel extends AppModel<BottomSheetCombosWidget> {
  ///  State fields for stateful widgets in this component.

  // State field(s) for ListView combos
  String? selectedComboId;
  String? selectedComboDesc;

  // Lista de combos
  List<Map<String, dynamic>> listaCombos = [];
  
  // Lista de itens do combo
  List<Map<String, dynamic>> listaItensCombo = [];

  // State field(s) for TextField widget.
  TextEditingController? txtQtdCombosController;
  String? Function(BuildContext, String?)? txtQtdCombosControllerValidator;

  bool isLoading = false;
  bool isSearching = false;

  @override
  void initState(BuildContext context) {}

  @override
  void dispose() {
    txtQtdCombosController?.dispose();
  }

  /// Action blocks are added here.
  /// Additional helper methods are added here.
}
