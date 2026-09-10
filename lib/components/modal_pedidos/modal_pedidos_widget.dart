// ignore_for_file: unused_import, unnecessary_import, avoid_print, prefer_const_constructors, prefer_const_literals_to_create_immutables

import '/core/app_icon_button.dart';
import '/core/app_theme.dart';
import '/core/app_util.dart';
import '/core/app_widgets.dart';
import 'dart:ui';
import '/index.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'modal_pedidos_model.dart';
export 'modal_pedidos_model.dart';

class ModalPedidosWidget extends StatefulWidget {
  const ModalPedidosWidget({super.key});

  @override
  State<ModalPedidosWidget> createState() => _ModalPedidosWidgetState();
}

class _ModalPedidosWidgetState extends State<ModalPedidosWidget> {
  late ModalPedidosModel _model;

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => ModalPedidosModel());
  }

  @override
  void dispose() {
    _model.maybeDispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      heightFactor: 1.0,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600.0),
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: double.infinity,
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.85,
            ),
            decoration: BoxDecoration(
              color: AppTheme.of(context).primaryBackground,
              boxShadow: const [
                BoxShadow(
                  blurRadius: 10.0,
                  color: Color(0x33000000),
                  offset: Offset(0.0, -2.0),
                )
              ],
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20.0),
                topRight: Radius.circular(20.0),
              ),
            ),
            child: SafeArea(
              top: false,
              bottom: true,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Drag handle
                  Padding(
                    padding: const EdgeInsets.only(top: 10.0, bottom: 4.0),
                    child: Container(
                      width: 40.0,
                      height: 4.0,
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(2.0),
                      ),
                    ),
                  ),
                  // Header
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Icon(
                                Icons.shopping_cart_outlined,
                                color: AppTheme.of(context).primary,
                                size: 24.0,
                              ),
                              const SizedBox(width: 8.0),
                              Expanded(
                                child: Text(
                                  'Pedidos',
                                  style: AppTheme.of(context).titleLarge.override(
                                        font: GoogleFonts.outfit(
                                          fontWeight: FontWeight.w600,
                                        ),
                                        color: AppTheme.of(context).primaryText,
                                        fontSize: 20.0,
                                      ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        AppIconButton(
                          borderColor: const Color(0xFFE0E3E7),
                          borderRadius: 12.0,
                          borderWidth: 1.0,
                          buttonSize: 38.0,
                          icon: Icon(
                            Icons.close_rounded,
                            color: AppTheme.of(context).primaryText,
                            size: 18.0,
                          ),
                          onPressed: () async {
                            Navigator.pop(context);
                          },
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1.0, thickness: 1.0),
                  Flexible(
                    fit: FlexFit.loose,
                    child: SingleChildScrollView(
                      child: Padding(
                        padding: const EdgeInsetsDirectional.fromSTEB(16.0, 12.0, 16.0, 16.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                      Padding(
                        padding:
                            EdgeInsetsDirectional.fromSTEB(2.0, 0.0, 2.0, 0.0),
                        child: Container(
                          decoration: BoxDecoration(
                          color: AppTheme.of(context).secondaryBackground,
                          boxShadow: [
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
                          padding: EdgeInsets.all(8.0),
                          child: InkWell(
                            splashColor: Colors.transparent,
                            focusColor: Colors.transparent,
                            hoverColor: Colors.transparent,
                            highlightColor: Colors.transparent,
                            onTap: () async {
                              Navigator.pop(context);
                              context.pushNamed(PedidoNovoInicioWidget.routeName);
                            },
                            child: Row(
                              mainAxisSize: MainAxisSize.max,
                              mainAxisAlignment: MainAxisAlignment.start,
                              children: [
                                AppIconButton(
                                  borderRadius: 8.0,
                                  buttonSize: 60.0,
                                  fillColor: Color(0x333572F7),
                                  icon: Icon(
                                    Icons.add_shopping_cart_rounded,
                                    color: AppTheme.of(context).primary,
                                    size: 32.0,
                                  ),
                                  onPressed: () {
                                    print('IconButton pressed ...');
                                  },
                                ),
                                Expanded(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.max,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Novo Pedido',
                                        style: AppTheme.of(context)
                                            .bodyMedium
                                            .override(
                                              font: GoogleFonts.inter(
                                                fontWeight: FontWeight.w600,
                                                fontStyle: AppTheme.of(context)
                                                    .bodyMedium
                                                    .fontStyle,
                                              ),
                                              fontSize: 16.0,
                                              letterSpacing: 0.0,
                                              fontWeight: FontWeight.w600,
                                              fontStyle: AppTheme.of(context)
                                                  .bodyMedium
                                                  .fontStyle,
                                            ),
                                      ),
                                      Text(
                                        'Iniciar a digitação de um novo pedido de vendas.',
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
                              ].divide(SizedBox(width: 12.0)),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding:
                          EdgeInsetsDirectional.fromSTEB(2.0, 0.0, 2.0, 0.0),
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppTheme.of(context).secondaryBackground,
                          boxShadow: [
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
                          padding: EdgeInsets.all(8.0),
                          child: InkWell(
                            splashColor: Colors.transparent,
                            focusColor: Colors.transparent,
                            hoverColor: Colors.transparent,
                            highlightColor: Colors.transparent,
                            onTap: () async {
                              Navigator.pop(context);
                              context.pushNamed(PedidosRascunhosPageWidget.routeName);
                            },
                            child: Row(
                              mainAxisSize: MainAxisSize.max,
                              mainAxisAlignment: MainAxisAlignment.start,
                              children: [
                                AppIconButton(
                                  borderRadius: 8.0,
                                  buttonSize: 60.0,
                                  fillColor: Color(0x333572F7),
                                  icon: Icon(
                                    Icons.history_rounded,
                                    color: AppTheme.of(context).primary,
                                    size: 32.0,
                                  ),
                                  onPressed: () {
                                    print('IconButton pressed ...');
                                  },
                                ),
                                Expanded(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.max,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Retorno / Rascunhos',
                                        style: AppTheme.of(context)
                                            .bodyMedium
                                            .override(
                                              font: GoogleFonts.inter(
                                                fontWeight: FontWeight.w600,
                                                fontStyle: AppTheme.of(context)
                                                    .bodyMedium
                                                    .fontStyle,
                                              ),
                                              fontSize: 16.0,
                                              letterSpacing: 0.0,
                                              fontWeight: FontWeight.w600,
                                              fontStyle: AppTheme.of(context)
                                                  .bodyMedium
                                                  .fontStyle,
                                            ),
                                      ),
                                      Text(
                                        'Visualizar pedidos salvos localmente ou aguardando envio.',
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
                              ].divide(SizedBox(width: 12.0)),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ]
                      .divide(SizedBox(height: 16.0))
                      .addToStart(SizedBox(height: 12.0)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  ),
),
);
  }
}
