import '/core/app_util.dart';
import '/core/form_field_controller.dart';
import 'drop_down_widget.dart' show DropDownWidget;
import 'package:flutter/material.dart';

class DropDownModel extends AppModel<DropDownWidget> {
  ///  State fields for stateful widgets in this component.

  // State field(s) for DropDown widget.
  String? dropDownValue;
  FormFieldController<String>? dropDownValueController;

  @override
  void initState(BuildContext context) {}

  @override
  void dispose() {}
}
