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
import 'modal_cliente_model.dart';
export 'modal_cliente_model.dart';

class ModalClienteWidget extends StatefulWidget {
  const ModalClienteWidget({super.key});

  @override
  State<ModalClienteWidget> createState() => _ModalClienteWidgetState();
}

class _ModalClienteWidgetState extends State<ModalClienteWidget> {
  late ModalClienteModel _model;

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => ModalClienteModel());
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
                                Icons.people_outline_rounded,
                                color: AppTheme.of(context).primary,
                                size: 24.0,
                              ),
                              const SizedBox(width: 8.0),
                              Expanded(
                                child: Text(
                                  'Clientes',
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
                              context.pushNamed(ClientePageWidget.routeName);
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
                                    Icons.search,
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
                                        'Consultar Clientes',
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
                                        'Pesquisar clientes cadastrados',
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
                              context.pushNamed(ClientePageWidget.routeName);
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
                                    Icons.person_pin_circle_outlined,
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
                                        'Rotas / Visitas',
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
                                        'Planejar visitas e rotas de clientes',
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
                              context.pushNamed(
                                FormClientesPageWidget.routeName,
                              );
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
                                    Icons.person_add_alt,
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
                                        'Novo Cadastro',
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
                                        'Adicionar novo cliente ao sistema',
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
                              context.pushNamed(ReceberPageWidget.routeName);
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
                                    Icons.receipt_long_rounded,
                                    color: AppTheme.of(context).primary,
                                    size: 32.0,
                                  ),
                                  onPressed: () {
                                    Navigator.pop(context);
                                    context.pushNamed(ReceberPageWidget.routeName);
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
                                        'Contas a Receber',
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
                                        'Consultar duplicatas e inadimplência',
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
