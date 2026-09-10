import '/core/app_theme.dart';
import '/core/app_util.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'botao_menu_home_model.dart';
export 'botao_menu_home_model.dart';

class BotaoMenuHomeWidget extends StatefulWidget {
  const BotaoMenuHomeWidget({
    super.key,
    String? description,
    required this.icon,
  }) : description = description ?? 'Menu';

  final String description;
  final Widget? icon;

  @override
  State<BotaoMenuHomeWidget> createState() => _BotaoMenuHomeWidgetState();
}

class _BotaoMenuHomeWidgetState extends State<BotaoMenuHomeWidget> {
  late BotaoMenuHomeModel _model;

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => BotaoMenuHomeModel());
  }

  @override
  void dispose() {
    _model.maybeDispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 120.0,
      decoration: BoxDecoration(
        color: AppTheme.of(context).secondaryBackground,
        boxShadow: const [
          BoxShadow(
            blurRadius: 4.0,
            color: Color(0x33000000),
            offset: Offset(
              0.0,
              2.0,
            ),
          )
        ],
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          mainAxisSize: MainAxisSize.max,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 50.0,
              height: 50.0,
              decoration: BoxDecoration(
                color: const Color(0x2A0087B9),
                borderRadius: BorderRadius.circular(4.0),
              ),
              child: widget.icon!,
            ),
            Text(
              widget.description,
              style: AppTheme.of(context).bodyMedium.override(
                    font: GoogleFonts.inter(
                      fontWeight: FontWeight.w500,
                      fontStyle:
                          AppTheme.of(context).bodyMedium.fontStyle,
                    ),
                    fontSize: 16.0,
                    letterSpacing: 0.0,
                    fontWeight: FontWeight.w500,
                    fontStyle:
                        AppTheme.of(context).bodyMedium.fontStyle,
                  ),
            ),
          ].divide(const SizedBox(height: 12.0)),
        ),
      ),
    );
  }
}
