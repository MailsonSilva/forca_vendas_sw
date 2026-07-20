import '/core/app_theme.dart';
import '/core/app_util.dart';
import '/core/app_widgets.dart';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
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
  })  : this.bgTint = bgTint ?? const Color(0x00000000),
        this.label = label ?? 'Atual',
        this.textColor = textColor ?? const Color(0x00000000),
        this.value = value ?? '1',
        this.bg = bg ?? const Color(0x1A5D65AB),
        this.color = color ?? const Color(0xFF1A1C2E);

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
          widget!.bgTint,
          AppTheme.of(context).primary,
        ),
        borderRadius: BorderRadius.circular(12.0),
        shape: BoxShape.rectangle,
      ),
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Container(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                valueOrDefault<String>(
                  widget!.label,
                  'Atual',
                ),
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
              Text(
                valueOrDefault<String>(
                  widget!.value,
                  '1',
                ),
                style: AppTheme.of(context).titleLarge.override(
                      font: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.bold,
                        fontStyle:
                            AppTheme.of(context).titleLarge.fontStyle,
                      ),
                      color: valueOrDefault<Color>(
                        widget!.textColor,
                        Color(0x00000000),
                      ),
                      letterSpacing: 0.0,
                      fontWeight: FontWeight.bold,
                      fontStyle:
                          AppTheme.of(context).titleLarge.fontStyle,
                      lineHeight: 1.3,
                    ),
              ),
            ].divide(SizedBox(height: 4.0)),
          ),
        ),
      ),
    );
  }
}
