import '/core/app_theme.dart';
import '/core/app_util.dart';
import '/core/app_widgets.dart';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'classification_row2_model.dart';
export 'classification_row2_model.dart';

class ClassificationRow2Widget extends StatefulWidget {
  const ClassificationRow2Widget({
    super.key,
    String? label,
    String? value,
  })  : this.label = label ?? 'Linha',
        this.value = value ?? 'LINHA GERAL';

  final String label;
  final String value;

  @override
  State<ClassificationRow2Widget> createState() =>
      _ClassificationRow2WidgetState();
}

class _ClassificationRow2WidgetState extends State<ClassificationRow2Widget> {
  late ClassificationRow2Model _model;

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => ClassificationRow2Model());
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
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Padding(
          padding: EdgeInsetsDirectional.fromSTEB(16.0, 0.0, 16.0, 0.0),
          child: Row(
            mainAxisSize: MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                valueOrDefault<String>(
                  widget!.label,
                  'Linha',
                ),
                style: AppTheme.of(context).bodyMedium.override(
                      font: GoogleFonts.inter(
                        fontWeight:
                            AppTheme.of(context).bodyMedium.fontWeight,
                        fontStyle:
                            AppTheme.of(context).bodyMedium.fontStyle,
                      ),
                      color: AppTheme.of(context).secondaryText,
                      letterSpacing: 0.0,
                      fontWeight:
                          AppTheme.of(context).bodyMedium.fontWeight,
                      fontStyle:
                          AppTheme.of(context).bodyMedium.fontStyle,
                      lineHeight: 1.5,
                    ),
              ),
              Expanded(
                flex: 1,
                child: Text(
                  valueOrDefault<String>(
                    widget!.value,
                    'LINHA GERAL',
                  ),
                  textAlign: TextAlign.end,
                  maxLines: 2,
                  style: AppTheme.of(context).labelLarge.override(
                        font: GoogleFonts.inter(
                          fontWeight: AppTheme.of(context)
                              .labelLarge
                              .fontWeight,
                          fontStyle:
                              AppTheme.of(context).labelLarge.fontStyle,
                        ),
                        color: AppTheme.of(context).primaryText,
                        letterSpacing: 0.0,
                        fontWeight:
                            AppTheme.of(context).labelLarge.fontWeight,
                        fontStyle:
                            AppTheme.of(context).labelLarge.fontStyle,
                        lineHeight: 1.2,
                      ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: EdgeInsetsDirectional.fromSTEB(0.0, 8.0, 0.0, 8.0),
          child: Container(
            child: Divider(
              height: 16.0,
              thickness: 1.0,
              indent: 0.0,
              endIndent: 0.0,
              color: AppTheme.of(context).alternate,
            ),
          ),
        ),
      ],
    );
  }
}
