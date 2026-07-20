import '/core/app_theme.dart';
import '/core/app_util.dart';
import '/core/app_widgets.dart';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'checkbox_model.dart';
export 'checkbox_model.dart';

class CheckboxWidget extends StatefulWidget {
  const CheckboxWidget({
    super.key,
    String? label,
    String? subtitle,
    Color? color,
    bool? isChecked,
    bool? hasSubtitle,
    bool? disabled,
  })  : this.label = label ?? 'Usar Endereço de Entrega',
        this.subtitle = subtitle ?? 'Receive weekly updates',
        this.color = color ?? const Color(0x00000000),
        this.isChecked = isChecked ?? false,
        this.hasSubtitle = hasSubtitle ?? false,
        this.disabled = disabled ?? false;

  final String label;
  final String subtitle;
  final Color color;
  final bool isChecked;
  final bool hasSubtitle;
  final bool disabled;

  @override
  State<CheckboxWidget> createState() => _CheckboxWidgetState();
}

class _CheckboxWidgetState extends State<CheckboxWidget> {
  late CheckboxModel _model;

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => CheckboxModel());
  }

  @override
  void dispose() {
    _model.maybeDispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: valueOrDefault<double>(
        valueOrDefault<bool>(
          widget!.disabled,
          false,
        )
            ? 0.55
            : 1.0,
        1.0,
      ),
      child: Container(
        child: Container(
          child: Padding(
            padding: EdgeInsetsDirectional.fromSTEB(0.0, 8.0, 0.0, 8.0),
            child: Container(
              child: Row(
                mainAxisSize: MainAxisSize.max,
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Padding(
                    padding: EdgeInsetsDirectional.fromSTEB(
                        valueOrDefault<double>(
                          valueOrDefault<bool>(
                            widget!.hasSubtitle,
                            false,
                          )
                              ? 0.0
                              : 0.0,
                          0.0,
                        ),
                        valueOrDefault<double>(
                          valueOrDefault<bool>(
                            widget!.hasSubtitle,
                            false,
                          )
                              ? 3.0
                              : 0.0,
                          0.0,
                        ),
                        valueOrDefault<double>(
                          valueOrDefault<bool>(
                            widget!.hasSubtitle,
                            false,
                          )
                              ? 0.0
                              : 0.0,
                          0.0,
                        ),
                        valueOrDefault<double>(
                          valueOrDefault<bool>(
                            widget!.hasSubtitle,
                            false,
                          )
                              ? 0.0
                              : 0.0,
                          0.0,
                        )),
                    child: Container(
                      child: Container(
                        width: 20.0,
                        height: 20.0,
                        decoration: BoxDecoration(
                          color: valueOrDefault<Color>(
                            valueOrDefault<bool>(
                              widget!.isChecked,
                              false,
                            )
                                ? Color(0x00000000)
                                : Colors.transparent,
                            Colors.transparent,
                          ),
                          borderRadius: BorderRadius.circular(4.0),
                          shape: BoxShape.rectangle,
                          border: Border.all(
                            color: Colors.transparent,
                            width: 0.0,
                          ),
                        ),
                        alignment: AlignmentDirectional(0.0, 0.0),
                        child: Visibility(
                          visible: valueOrDefault<bool>(
                            valueOrDefault<bool>(
                              widget!.isChecked,
                              false,
                            )
                                ? true
                                : false,
                            false,
                          ),
                          child: Icon(
                            Icons.check_rounded,
                            color: AppTheme.of(context).onPrimary,
                            size: 16.0,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 1,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          valueOrDefault<String>(
                            widget!.label,
                            'Usar Endereço de Entrega',
                          ),
                          maxLines: 1,
                          style: AppTheme.of(context)
                              .bodyMedium
                              .override(
                                font: GoogleFonts.inter(
                                  fontWeight: AppTheme.of(context)
                                      .bodyMedium
                                      .fontWeight,
                                  fontStyle: AppTheme.of(context)
                                      .bodyMedium
                                      .fontStyle,
                                ),
                                color: AppTheme.of(context).primaryText,
                                letterSpacing: 0.0,
                                fontWeight: AppTheme.of(context)
                                    .bodyMedium
                                    .fontWeight,
                                fontStyle: AppTheme.of(context)
                                    .bodyMedium
                                    .fontStyle,
                                lineHeight: 1.47,
                              ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (valueOrDefault<bool>(
                          valueOrDefault<bool>(
                            widget!.hasSubtitle,
                            false,
                          )
                              ? true
                              : false,
                          false,
                        ))
                          Container(
                            child: Container(
                              child: Text(
                                valueOrDefault<String>(
                                  widget!.subtitle,
                                  'Receive weekly updates',
                                ),
                                maxLines: 3,
                                style: AppTheme.of(context)
                                    .bodySmall
                                    .override(
                                      font: GoogleFonts.inter(
                                        fontWeight: AppTheme.of(context)
                                            .bodySmall
                                            .fontWeight,
                                        fontStyle: AppTheme.of(context)
                                            .bodySmall
                                            .fontStyle,
                                      ),
                                      color: AppTheme.of(context)
                                          .secondaryText,
                                      letterSpacing: 0.0,
                                      fontWeight: AppTheme.of(context)
                                          .bodySmall
                                          .fontWeight,
                                      fontStyle: AppTheme.of(context)
                                          .bodySmall
                                          .fontStyle,
                                      lineHeight: 1.38,
                                    ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ].divide(SizedBox(width: 16.0)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
