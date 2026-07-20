import '/core/app_theme.dart';
import '/core/app_util.dart';
import '/core/app_widgets.dart';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'pedidos_rascunhos_page_model.dart';
export 'pedidos_rascunhos_page_model.dart';

/// Area futura de pedidos e rascunhos.
class PedidosRascunhosPageWidget extends StatefulWidget {
  const PedidosRascunhosPageWidget({super.key});

  static String routeName = 'PedidosRascunhosPage';
  static String routePath = '/pedidos';

  @override
  State<PedidosRascunhosPageWidget> createState() =>
      _PedidosRascunhosPageWidgetState();
}

class _PedidosRascunhosPageWidgetState
    extends State<PedidosRascunhosPageWidget> {
  late PedidosRascunhosPageModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => PedidosRascunhosPageModel());
  }

  @override
  void dispose() {
    _model.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
        FocusManager.instance.primaryFocus?.unfocus();
      },
      child: Scaffold(
        key: scaffoldKey,
        backgroundColor: AppTheme.of(context).primaryBackground,
        appBar: AppBar(
          backgroundColor: AppTheme.of(context).primaryBackground,
          automaticallyImplyLeading: true,
          title: Text(
            'Pedidos / Rascunhos',
            style: AppTheme.of(context).titleLarge.override(
                  font: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w600,
                    fontStyle:
                        AppTheme.of(context).titleLarge.fontStyle,
                  ),
                  fontSize: 22.0,
                  letterSpacing: 0.0,
                  fontWeight: FontWeight.w600,
                  fontStyle: AppTheme.of(context).titleLarge.fontStyle,
                ),
          ),
          actions: [],
          centerTitle: true,
          elevation: 0.0,
        ),
        body: SafeArea(
          top: true,
          child: Container(
            decoration: BoxDecoration(
              color: AppTheme.of(context).primaryBackground,
            ),
            alignment: AlignmentDirectional(0.0, 0.0),
            child: Padding(
              padding: EdgeInsets.all(24.0),
              child: Container(
                width: 420.0,
                decoration: BoxDecoration(
                  color: AppTheme.of(context).secondaryBackground,
                  borderRadius: BorderRadius.circular(12.0),
                  boxShadow: [
                    BoxShadow(
                      blurRadius: 4.0,
                      color: const Color(0x1A000000),
                      offset: const Offset(0.0, 2.0),
                      spreadRadius: 0.0,
                    )
                  ],
                ),
                child: Padding(
                  padding: EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.shopping_cart_rounded,
                        color: AppTheme.of(context).primary,
                        size: 48.0,
                      ),
                      Text(
                        'Pedidos / Rascunhos',
                        style: AppTheme.of(context).titleLarge.override(
                              font: GoogleFonts.plusJakartaSans(
                                fontWeight: AppTheme.of(context)
                                    .titleLarge
                                    .fontWeight,
                                fontStyle: AppTheme.of(context)
                                    .titleLarge
                                    .fontStyle,
                              ),
                              color: AppTheme.of(context).primaryText,
                              letterSpacing: 0.0,
                              fontWeight: AppTheme.of(context)
                                  .titleLarge
                                  .fontWeight,
                              fontStyle: AppTheme.of(context)
                                  .titleLarge
                                  .fontStyle,
                            ),
                      ),
                      Text(
                        'Pedidos em andamento',
                        textAlign: TextAlign.center,
                        style: AppTheme.of(context).bodyMedium.override(
                              font: GoogleFonts.inter(
                                fontWeight: AppTheme.of(context)
                                    .bodyMedium
                                    .fontWeight,
                                fontStyle: AppTheme.of(context)
                                    .bodyMedium
                                    .fontStyle,
                              ),
                              color: AppTheme.of(context).secondaryText,
                              letterSpacing: 0.0,
                              fontWeight: AppTheme.of(context)
                                  .bodyMedium
                                  .fontWeight,
                              fontStyle: AppTheme.of(context)
                                  .bodyMedium
                                  .fontStyle,
                            ),
                      ),
                    ].divide(SizedBox(height: 12.0)),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
