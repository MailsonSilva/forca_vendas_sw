import '/backend/schema/structs/index.dart';
import '/core/app_drop_down.dart';
import '/core/app_theme.dart';
import '/core/app_util.dart';
import '/core/app_widgets.dart';
import '/core/form_field_controller.dart';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'drop_down_model.dart';
export 'drop_down_model.dart';

class DropDownWidget extends StatefulWidget {
  const DropDownWidget({
    super.key,
    required this.titulo,
    required this.placeHolder,
    this.listaFiltro,
  });

  final String? titulo;
  final String? placeHolder;
  final List<ListaPadraoStruct>? listaFiltro;

  @override
  State<DropDownWidget> createState() => _DropDownWidgetState();
}

class _DropDownWidgetState extends State<DropDownWidget> {
  late DropDownModel _model;

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => DropDownModel());
  }

  @override
  void dispose() {
    _model.maybeDispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          valueOrDefault<String>(
            widget!.titulo,
            'titulo',
          ),
          style: AppTheme.of(context).labelMedium.override(
                font: GoogleFonts.inter(
                  fontWeight:
                      AppTheme.of(context).labelMedium.fontWeight,
                  fontStyle: AppTheme.of(context).labelMedium.fontStyle,
                ),
                color: AppTheme.of(context).secondaryText,
                letterSpacing: 0.0,
                fontWeight: AppTheme.of(context).labelMedium.fontWeight,
                fontStyle: AppTheme.of(context).labelMedium.fontStyle,
                lineHeight: 1.38,
              ),
        ),
        AppDropDown<String>(
          controller: _model.dropDownValueController ??=
              FormFieldController<String>(
            _model.dropDownValue ??=
                widget!.listaFiltro != null && (widget!.listaFiltro)!.isNotEmpty
                    ? widget!.placeHolder
                    : '\"\"',
          ),
          options: List<String>.from(
              widget!.listaFiltro!.map((e) => e.codigo).toList()),
          optionLabels: widget!.listaFiltro!.map((e) => e.descricao).toList(),
          onChanged: (val) => safeSetState(() => _model.dropDownValue = val),
          width: 250.0,
          height: 40.0,
          textStyle: AppTheme.of(context).bodyMedium.override(
                font: GoogleFonts.inter(
                  fontWeight:
                      AppTheme.of(context).bodyMedium.fontWeight,
                  fontStyle: AppTheme.of(context).bodyMedium.fontStyle,
                ),
                letterSpacing: 0.0,
                fontWeight: AppTheme.of(context).bodyMedium.fontWeight,
                fontStyle: AppTheme.of(context).bodyMedium.fontStyle,
              ),
          hintText: widget!.placeHolder,
          icon: Icon(
            Icons.keyboard_arrow_down_rounded,
            color: AppTheme.of(context).secondaryText,
            size: 24.0,
          ),
          fillColor: AppTheme.of(context).secondaryBackground,
          elevation: 2.0,
          borderColor: AppTheme.of(context).secondaryText,
          borderWidth: 1.0,
          borderRadius: 8.0,
          margin: EdgeInsetsDirectional.fromSTEB(12.0, 0.0, 12.0, 0.0),
          hidesUnderline: true,
          isOverButton: false,
          isSearchable: false,
          isMultiSelect: false,
        ),
      ].divide(SizedBox(height: 4.0)),
    );
  }
}
