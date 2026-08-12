import '/core/app_theme.dart';
import '/core/app_util.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'text_field_model.dart';
export 'text_field_model.dart';

class TextFieldWidget extends StatefulWidget {
  const TextFieldWidget({
    super.key,
    String? label,
    bool? labelPresent,
    String? helper,
    bool? helperPresent,
    this.leadingIcon,
    bool? leadingIconPresent,
    this.trailingIcon,
    bool? trailingIconPresent,
    String? hint,
    String? value,
    String? variant,
    bool? error,
  })  : label = label ?? '',
        labelPresent = labelPresent ?? false,
        helper = helper ?? '',
        helperPresent = helperPresent ?? false,
        leadingIconPresent = leadingIconPresent ?? false,
        trailingIconPresent = trailingIconPresent ?? false,
        hint = hint ?? 'SlotValue(\$hint)',
        value = value ?? '',
        variant = variant ?? 'outlined',
        error = error ?? false;

  final String label;
  final bool labelPresent;
  final String helper;
  final bool helperPresent;
  final Widget? leadingIcon;
  final bool leadingIconPresent;
  final Widget? trailingIcon;
  final bool trailingIconPresent;
  final String hint;
  final String value;
  final String variant;
  final bool error;

  @override
  State<TextFieldWidget> createState() => _TextFieldWidgetState();
}

class _TextFieldWidgetState extends State<TextFieldWidget> {
  late TextFieldModel _model;

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => TextFieldModel());

    _model.inputTextController ??= TextEditingController(text: widget.value);
    _model.inputFocusNode ??= FocusNode();
  }

  @override
  void dispose() {
    _model.maybeDispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (valueOrDefault<bool>(
            widget.labelPresent,
            false,
          ))
            Text(
              widget.label,
              style: AppTheme.of(context).labelMedium.override(
                    font: GoogleFonts.inter(
                      fontWeight:
                          AppTheme.of(context).labelMedium.fontWeight,
                      fontStyle:
                          AppTheme.of(context).labelMedium.fontStyle,
                    ),
                    color: valueOrDefault<Color>(
                      valueOrDefault<bool>(
                        widget.error,
                        false,
                      )
                          ? AppTheme.of(context).error
                          : AppTheme.of(context).primaryText,
                      AppTheme.of(context).primaryText,
                    ),
                    letterSpacing: 0.0,
                    fontWeight:
                        AppTheme.of(context).labelMedium.fontWeight,
                    fontStyle:
                        AppTheme.of(context).labelMedium.fontStyle,
                    lineHeight: 1.38,
                  ),
            ),
          Container(
            height: 40.0,
            decoration: BoxDecoration(
              color: valueOrDefault<Color>(
                () {
                  if (valueOrDefault<String>(
                        widget.variant,
                        'outlined',
                      ) ==
                      'filled') {
                    return AppTheme.of(context).secondaryBackground;
                  } else if (valueOrDefault<String>(
                        widget.variant,
                        'outlined',
                      ) ==
                      'ghost') {
                    return Colors.transparent;
                  } else {
                    return Colors.transparent;
                  }
                }(),
                Colors.transparent,
              ),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(valueOrDefault<double>(
                  () {
                    if (valueOrDefault<String>(
                          widget.variant,
                          'outlined',
                        ) ==
                        'filled') {
                      return 4.0;
                    } else if (valueOrDefault<String>(
                          widget.variant,
                          'outlined',
                        ) ==
                        'ghost') {
                      return 4.0;
                    } else {
                      return 4.0;
                    }
                  }(),
                  4.0,
                )),
                topRight: Radius.circular(valueOrDefault<double>(
                  () {
                    if (valueOrDefault<String>(
                          widget.variant,
                          'outlined',
                        ) ==
                        'filled') {
                      return 4.0;
                    } else if (valueOrDefault<String>(
                          widget.variant,
                          'outlined',
                        ) ==
                        'ghost') {
                      return 4.0;
                    } else {
                      return 4.0;
                    }
                  }(),
                  4.0,
                )),
                bottomLeft: Radius.circular(valueOrDefault<double>(
                  () {
                    if (valueOrDefault<String>(
                          widget.variant,
                          'outlined',
                        ) ==
                        'filled') {
                      return 4.0;
                    } else if (valueOrDefault<String>(
                          widget.variant,
                          'outlined',
                        ) ==
                        'ghost') {
                      return 4.0;
                    } else {
                      return 4.0;
                    }
                  }(),
                  4.0,
                )),
                bottomRight: Radius.circular(valueOrDefault<double>(
                  () {
                    if (valueOrDefault<String>(
                          widget.variant,
                          'outlined',
                        ) ==
                        'filled') {
                      return 4.0;
                    } else if (valueOrDefault<String>(
                          widget.variant,
                          'outlined',
                        ) ==
                        'ghost') {
                      return 4.0;
                    } else {
                      return 4.0;
                    }
                  }(),
                  4.0,
                )),
              ),
              shape: BoxShape.rectangle,
              border: Border.all(
                color: valueOrDefault<Color>(
                  () {
                    if (valueOrDefault<bool>(
                      widget.error,
                      false,
                    )) {
                      return AppTheme.of(context).error;
                    } else if (valueOrDefault<String>(
                          widget.variant,
                          'outlined',
                        ) ==
                        'filled') {
                      return Colors.transparent;
                    } else if (valueOrDefault<String>(
                          widget.variant,
                          'outlined',
                        ) ==
                        'ghost') {
                      return Colors.transparent;
                    } else {
                      return AppTheme.of(context).alternate;
                    }
                  }(),
                  AppTheme.of(context).alternate,
                ),
                width: valueOrDefault<double>(
                  () {
                    if (valueOrDefault<bool>(
                      widget.error,
                      false,
                    )) {
                      return 1.0;
                    } else if (valueOrDefault<String>(
                          widget.variant,
                          'outlined',
                        ) ==
                        'filled') {
                      return 1.0;
                    } else if (valueOrDefault<String>(
                          widget.variant,
                          'outlined',
                        ) ==
                        'ghost') {
                      return 0.0;
                    } else {
                      return 1.0;
                    }
                  }(),
                  1.0,
                ),
              ),
            ),
            child: Padding(
              padding: EdgeInsetsDirectional.fromSTEB(
                  valueOrDefault<double>(
                    () {
                      if (valueOrDefault<String>(
                            widget.variant,
                            'outlined',
                          ) ==
                          'filled') {
                        return 8.0;
                      } else if (valueOrDefault<String>(
                            widget.variant,
                            'outlined',
                          ) ==
                          'ghost') {
                        return 8.0;
                      } else {
                        return 8.0;
                      }
                    }(),
                    8.0,
                  ),
                  valueOrDefault<double>(
                    () {
                      if (valueOrDefault<String>(
                            widget.variant,
                            'outlined',
                          ) ==
                          'filled') {
                        return 8.0;
                      } else if (valueOrDefault<String>(
                            widget.variant,
                            'outlined',
                          ) ==
                          'ghost') {
                        return 8.0;
                      } else {
                        return 8.0;
                      }
                    }(),
                    8.0,
                  ),
                  valueOrDefault<double>(
                    () {
                      if (valueOrDefault<String>(
                            widget.variant,
                            'outlined',
                          ) ==
                          'filled') {
                        return 8.0;
                      } else if (valueOrDefault<String>(
                            widget.variant,
                            'outlined',
                          ) ==
                          'ghost') {
                        return 8.0;
                      } else {
                        return 8.0;
                      }
                    }(),
                    8.0,
                  ),
                  valueOrDefault<double>(
                    () {
                      if (valueOrDefault<String>(
                            widget.variant,
                            'outlined',
                          ) ==
                          'filled') {
                        return 8.0;
                      } else if (valueOrDefault<String>(
                            widget.variant,
                            'outlined',
                          ) ==
                          'ghost') {
                        return 8.0;
                      } else {
                        return 8.0;
                      }
                    }(),
                    8.0,
                  )),
              child: Row(
                mainAxisSize: MainAxisSize.max,
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (valueOrDefault<bool>(
                    widget.leadingIconPresent,
                    false,
                  ))
                    widget.leadingIcon!,
                  Expanded(
                    flex: 1,
                    child: TextFormField(
                      controller: _model.inputTextController,
                      focusNode: _model.inputFocusNode,
                      obscureText: false,
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: valueOrDefault<String>(
                          widget.hint,
                          'SlotValue(\$hint)',
                        ),
                        hintStyle: AppTheme.of(context)
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
                              color: valueOrDefault<Color>(
                                () {
                                  if (valueOrDefault<String>(
                                        widget.variant,
                                        'outlined',
                                      ) ==
                                      'filled') {
                                    return AppTheme.of(context).accent3;
                                  } else if (valueOrDefault<String>(
                                        widget.variant,
                                        'outlined',
                                      ) ==
                                      'ghost') {
                                    return AppTheme.of(context).accent3;
                                  } else {
                                    return AppTheme.of(context).accent3;
                                  }
                                }(),
                                AppTheme.of(context).accent3,
                              ),
                              letterSpacing: 0.0,
                              fontWeight: AppTheme.of(context)
                                  .bodyMedium
                                  .fontWeight,
                              fontStyle: AppTheme.of(context)
                                  .bodyMedium
                                  .fontStyle,
                              lineHeight: 1.47,
                            ),
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        errorBorder: InputBorder.none,
                        focusedErrorBorder: InputBorder.none,
                      ),
                      style: AppTheme.of(context).bodyMedium.override(
                            font: GoogleFonts.inter(
                              fontWeight: AppTheme.of(context)
                                  .bodyMedium
                                  .fontWeight,
                              fontStyle: AppTheme.of(context)
                                  .bodyMedium
                                  .fontStyle,
                            ),
                            color: valueOrDefault<Color>(
                              () {
                                if (valueOrDefault<String>(
                                      widget.variant,
                                      'outlined',
                                    ) ==
                                    'filled') {
                                  return AppTheme.of(context)
                                      .primaryText;
                                } else if (valueOrDefault<String>(
                                      widget.variant,
                                      'outlined',
                                    ) ==
                                    'ghost') {
                                  return AppTheme.of(context)
                                      .primaryText;
                                } else {
                                  return AppTheme.of(context)
                                      .primaryText;
                                }
                              }(),
                              AppTheme.of(context).primaryText,
                            ),
                            letterSpacing: 0.0,
                            fontWeight: AppTheme.of(context)
                                .bodyMedium
                                .fontWeight,
                            fontStyle: AppTheme.of(context)
                                .bodyMedium
                                .fontStyle,
                            lineHeight: 1.47,
                          ),
                      validator: _model.inputTextControllerValidator
                          .asValidator(context),
                    ),
                  ),
                  if (valueOrDefault<bool>(
                    widget.trailingIconPresent,
                    false,
                  ))
                    widget.trailingIcon!,
                ],
              ),
            ),
          ),
          if (valueOrDefault<bool>(
            widget.helperPresent,
            false,
          ))
            Text(
              widget.helper,
              style: AppTheme.of(context).bodySmall.override(
                    font: GoogleFonts.inter(
                      fontWeight:
                          AppTheme.of(context).bodySmall.fontWeight,
                      fontStyle:
                          AppTheme.of(context).bodySmall.fontStyle,
                    ),
                    color: valueOrDefault<Color>(
                      valueOrDefault<bool>(
                        widget.error,
                        false,
                      )
                          ? AppTheme.of(context).error
                          : AppTheme.of(context).secondaryText,
                      AppTheme.of(context).secondaryText,
                    ),
                    letterSpacing: 0.0,
                    fontWeight:
                        AppTheme.of(context).bodySmall.fontWeight,
                    fontStyle: AppTheme.of(context).bodySmall.fontStyle,
                    lineHeight: 1.38,
                  ),
            ),
        ].divide(const SizedBox(height: 6.0)),
      ),
    );
  }
}
