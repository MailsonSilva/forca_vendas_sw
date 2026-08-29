import '/core/app_theme.dart';
import '/core/app_util.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'inventory_stat2_model.dart';
export 'inventory_stat2_model.dart';

class InventoryStat2Widget extends StatefulWidget {
  const InventoryStat2Widget({
    super.key,
    Color? bgTint,
    String? label,
    Color? textColor,
    String? value,
    Color? bg,
    Color? color,
  })  : bgTint = bgTint ?? const Color(0x00000000),
        label = label ?? 'Atual',
        textColor = textColor ?? const Color(0x00000000),
        value = value ?? '1',
        bg = bg ?? const Color(0x1A5D65AB),
        color = color ?? const Color(0xFF1A1C2E);

  final Color bgTint;
  final String label;
  final Color textColor;
  final String value;
  final Color bg;
  final Color color;

  @override
  State<InventoryStat2Widget> createState() => _InventoryStat2WidgetState();
}

class _InventoryStat2WidgetState extends State<InventoryStat2Widget> {
  late InventoryStat2Model _model;

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => InventoryStat2Model());
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
          widget.bgTint,
          AppTheme.of(context).primary,
        ),
        borderRadius: BorderRadius.circular(12.0),
        shape: BoxShape.rectangle,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 10.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                valueOrDefault<String>(
                  widget.label,
                  'Atual',
                ),
                maxLines: 1,
                style: AppTheme.of(context).labelSmall.override(
                      font: GoogleFonts.inter(
                        fontWeight:
                            AppTheme.of(context).labelSmall.fontWeight,
                        fontStyle:
                            AppTheme.of(context).labelSmall.fontStyle,
                      ),
                      color: AppTheme.of(context).secondaryText,
                      letterSpacing: 0.0,
                      fontWeight:
                          AppTheme.of(context).labelSmall.fontWeight,
                      fontStyle:
                          AppTheme.of(context).labelSmall.fontStyle,
                      lineHeight: 1.2,
                    ),
              ),
            ),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                valueOrDefault<String>(
                  widget.value,
                  '1',
                ),
                maxLines: 1,
                style: AppTheme.of(context).titleLarge.override(
                      font: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.bold,
                        fontStyle:
                            AppTheme.of(context).titleLarge.fontStyle,
                      ),
                      color: valueOrDefault<Color>(
                        widget.textColor,
                        const Color(0x00000000),
                      ),
                      letterSpacing: 0.0,
                      fontWeight: FontWeight.bold,
                      fontStyle:
                          AppTheme.of(context).titleLarge.fontStyle,
                      lineHeight: 1.3,
                    ),
              ),
            ),
          ].divide(const SizedBox(height: 4.0)),
        ),
      ),
    );
  }
}
