import '/core/app_theme.dart';
import '/core/app_util.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'tab_item_model.dart';
export 'tab_item_model.dart';

class TabItemWidget extends StatefulWidget {
  const TabItemWidget({
    super.key,
    String? label,
    bool? selected,
  })  : label = label ?? 'Principal',
        selected = selected ?? false;

  final String label;
  final bool selected;

  @override
  State<TabItemWidget> createState() => _TabItemWidgetState();
}

class _TabItemWidgetState extends State<TabItemWidget> {
  late TabItemModel _model;

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => TabItemModel());
  }

  @override
  void dispose() {
    _model.maybeDispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: valueOrDefault<Color>(
          valueOrDefault<bool>(
            widget.selected,
            false,
          )
              ? AppTheme.of(context).secondary20
              : Colors.transparent,
          Colors.transparent,
        ),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(valueOrDefault<double>(
            valueOrDefault<bool>(
              widget.selected,
              false,
            )
                ? 4.0
                : 8.0,
            8.0,
          )),
          topRight: Radius.circular(valueOrDefault<double>(
            valueOrDefault<bool>(
              widget.selected,
              false,
            )
                ? 4.0
                : 8.0,
            8.0,
          )),
          bottomLeft: Radius.circular(valueOrDefault<double>(
            valueOrDefault<bool>(
              widget.selected,
              false,
            )
                ? 4.0
                : 8.0,
            8.0,
          )),
          bottomRight: Radius.circular(valueOrDefault<double>(
            valueOrDefault<bool>(
              widget.selected,
              false,
            )
                ? 4.0
                : 8.0,
            8.0,
          )),
        ),
        shape: BoxShape.rectangle,
        border: Border.all(
          color: Colors.transparent,
          width: 1.0,
        ),
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(16.0, 8.0, 16.0, 8.0),
        child: Container(
          child: Align(
            alignment: const AlignmentDirectional(0.0, 0.0),
            child: Text(
              valueOrDefault<String>(
                widget.label,
                'Principal',
              ),
              textAlign: TextAlign.center,
              style: AppTheme.of(context).labelMedium.override(
                    font: GoogleFonts.inter(
                      fontWeight:
                          AppTheme.of(context).labelMedium.fontWeight,
                      fontStyle:
                          AppTheme.of(context).labelMedium.fontStyle,
                    ),
                    color: valueOrDefault<Color>(
                      valueOrDefault<bool>(
                        widget.selected,
                        false,
                      )
                          ? AppTheme.of(context).onSurface
                          : AppTheme.of(context).secondaryText,
                      AppTheme.of(context).secondaryText,
                    ),
                    letterSpacing: 0.0,
                    fontWeight:
                        AppTheme.of(context).labelMedium.fontWeight,
                    fontStyle:
                        AppTheme.of(context).labelMedium.fontStyle,
                    lineHeight: 1.38,
                  ),
            ),
          ),
        ),
      ),
    );
  }
}
