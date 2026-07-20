import '/components/text_field/text_field_widget.dart';
import '/core/app_theme.dart';
import '/core/app_util.dart';
import '/core/app_widgets.dart';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'form_field_model.dart';
export 'form_field_model.dart';

class FormFieldWidget extends StatefulWidget {
  const FormFieldWidget({
    super.key,
    String? hint,
    String? label,
  })  : this.hint = hint ?? 'Razão Social',
        this.label = label ?? 'Razão Social';

  final String hint;
  final String label;

  @override
  State<FormFieldWidget> createState() => _FormFieldWidgetState();
}

class _FormFieldWidgetState extends State<FormFieldWidget> {
  late FormFieldModel _model;

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => FormFieldModel());
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
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          valueOrDefault<String>(
            widget!.label,
            'Razão Social',
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
        wrapWithModel(
          model: _model.textFieldModel,
          updateCallback: () => safeSetState(() {}),
          child: TextFieldWidget(
            label: '',
            labelPresent: false,
            helper: '',
            helperPresent: false,
            leadingIconPresent: false,
            trailingIconPresent: false,
            hint: valueOrDefault<String>(
              widget!.hint,
              'Razão Social',
            ),
            value: '',
            variant: 'outlined',
            error: false,
          ),
        ),
      ].divide(SizedBox(height: 4.0)),
    );
  }
}
