// ignore_for_file: unused_import, unnecessary_import, avoid_print, prefer_const_constructors, prefer_const_literals_to_create_immutables

import '/components/atualizar_carga/atualizar_carga_widget.dart';
import '/components/atualizar_imagens/atualizar_imagens_widget.dart';
import '/core/app_icon_button.dart';
import '/core/app_theme.dart';
import '/core/app_util.dart';
import '/core/app_widgets.dart';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'ferramentas_page_model.dart';
export 'ferramentas_page_model.dart';

class FerramentasPageWidget extends StatefulWidget {
  const FerramentasPageWidget({super.key});

  static String routeName = 'FerramentasPage';
  static String routePath = '/ferramentasPage';

  @override
  State<FerramentasPageWidget> createState() => _FerramentasPageWidgetState();
}

class _FerramentasPageWidgetState extends State<FerramentasPageWidget> {
  late FerramentasPageModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => FerramentasPageModel());
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
          backgroundColor: AppTheme.of(context).primary,
          automaticallyImplyLeading: false,
          leading: AppIconButton(
            borderColor: Colors.transparent,
            borderRadius: 30.0,
            borderWidth: 1.0,
            buttonSize: 60.0,
            icon: Icon(
              Icons.arrow_back_rounded,
              color: Colors.white,
              size: 30.0,
            ),
            onPressed: () async {
              context.pop();
            },
          ),
          title: Text(
            'Ferramentas',
            style: AppTheme.of(context).headlineMedium.override(
                  font: GoogleFonts.plusJakartaSans(
                    fontWeight: AppTheme.of(context).headlineMedium.fontWeight,
                    fontStyle: AppTheme.of(context).headlineMedium.fontStyle,
                  ),
                  color: Colors.white,
                  fontSize: 22.0,
                  letterSpacing: 0.0,
                  fontWeight: AppTheme.of(context).headlineMedium.fontWeight,
                  fontStyle: AppTheme.of(context).headlineMedium.fontStyle,
                ),
          ),
          actions: [],
          centerTitle: true,
          elevation: 2.0,
        ),
        body: SafeArea(
          top: true,
          child: Column(
            mainAxisSize: MainAxisSize.max,
            children: [
              Padding(
                padding: EdgeInsetsDirectional.fromSTEB(16.0, 0.0, 16.0, 0.0),
                child: Container(
                  width: double.infinity,
                  height: 80.0,
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
                  child: Builder(
                    builder: (context) => Padding(
                      padding: EdgeInsets.all(12.0),
                      child: InkWell(
                        splashColor: Colors.transparent,
                        focusColor: Colors.transparent,
                        hoverColor: Colors.transparent,
                        highlightColor: Colors.transparent,
                        onTap: () async {
                          await showDialog(
                            context: context,
                            builder: (dialogContext) {
                              return Dialog(
                                elevation: 0,
                                insetPadding: EdgeInsets.zero,
                                backgroundColor: Colors.transparent,
                                alignment: AlignmentDirectional(0.0, 0.0)
                                    .resolve(Directionality.of(context)),
                                child: GestureDetector(
                                  onTap: () {
                                    FocusScope.of(dialogContext).unfocus();
                                    FocusManager.instance.primaryFocus
                                        ?.unfocus();
                                  },
                                  child: AtualizarImagensWidget(
                                    titulo: 'Imagens dos Produtos',
                                    descricao:
                                        'Parcial: atualização rápida. Total: baixa tudo e atualiza todas as imagens.',
                                    icon: Icon(
                                      Icons.image_outlined,
                                    ),
                                  ),
                                ),
                              );
                            },
                          );
                        },
                        child: Row(
                          mainAxisSize: MainAxisSize.max,
                          children: [
                            AppIconButton(
                              borderRadius: 8.0,
                              buttonSize: 63.04,
                              fillColor: Color(0x403572F7),
                              icon: Icon(
                                Icons.downloading_rounded,
                                color: AppTheme.of(context).primary,
                                size: 38.0,
                              ),
                              onPressed: () {
                                print('IconButton pressed ...');
                              },
                            ),
                            Expanded(
                              child: Column(
                                mainAxisSize: MainAxisSize.max,
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceEvenly,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Imagens',
                                    style: AppTheme.of(context)
                                        .bodyMedium
                                        .override(
                                          font: GoogleFonts.plusJakartaSans(
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
                                    'Baixar imagens',
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
                                          color: AppTheme.of(context)
                                              .secondaryText,
                                          fontSize: 12.0,
                                          letterSpacing: 0.0,
                                          fontWeight: AppTheme.of(context)
                                              .bodyMedium
                                              .fontWeight,
                                          fontStyle: AppTheme.of(context)
                                              .bodyMedium
                                              .fontStyle,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.keyboard_arrow_right,
                              color: AppTheme.of(context).secondary,
                              size: 28.0,
                            ),
                          ].divide(SizedBox(width: 8.0)),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsetsDirectional.fromSTEB(16.0, 0.0, 16.0, 0.0),
                child: Container(
                  width: double.infinity,
                  height: 80.0,
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
                  child: Builder(
                    builder: (context) => Padding(
                      padding: EdgeInsets.all(12.0),
                      child: InkWell(
                        splashColor: Colors.transparent,
                        focusColor: Colors.transparent,
                        hoverColor: Colors.transparent,
                        highlightColor: Colors.transparent,
                        onTap: () async {
                          await showDialog(
                            context: context,
                            builder: (dialogContext) {
                              return Dialog(
                                elevation: 0,
                                insetPadding: EdgeInsets.zero,
                                backgroundColor: Colors.transparent,
                                alignment: AlignmentDirectional(0.0, 0.0)
                                    .resolve(Directionality.of(context)),
                                child: GestureDetector(
                                  onTap: () {
                                    FocusScope.of(dialogContext).unfocus();
                                    FocusManager.instance.primaryFocus
                                        ?.unfocus();
                                  },
                                  child: AtualizarCargaWidget(
                                    titulo: 'Carga de Dados',
                                    descricao:
                                        'Sincronização de dados com o servidor.',
                                    icon: Icon(
                                      Icons.storage_sharp,
                                    ),
                                  ),
                                ),
                              );
                            },
                          );
                        },
                        child: Row(
                          mainAxisSize: MainAxisSize.max,
                          children: [
                            AppIconButton(
                              borderRadius: 8.0,
                              buttonSize: 63.04,
                              fillColor: Color(0x403572F7),
                              icon: Icon(
                                Icons.repeat_sharp,
                                color: AppTheme.of(context).primary,
                                size: 38.0,
                              ),
                              onPressed: () {
                                print('IconButton pressed ...');
                              },
                            ),
                            Expanded(
                              child: Column(
                                mainAxisSize: MainAxisSize.max,
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceEvenly,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Dados',
                                    style: AppTheme.of(context)
                                        .bodyMedium
                                        .override(
                                          font: GoogleFonts.plusJakartaSans(
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
                                    'Sincronizar dados',
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
                                          color: AppTheme.of(context)
                                              .secondaryText,
                                          fontSize: 12.0,
                                          letterSpacing: 0.0,
                                          fontWeight: AppTheme.of(context)
                                              .bodyMedium
                                              .fontWeight,
                                          fontStyle: AppTheme.of(context)
                                              .bodyMedium
                                              .fontStyle,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.keyboard_arrow_right,
                              color: AppTheme.of(context).secondary,
                              size: 28.0,
                            ),
                          ].divide(SizedBox(width: 8.0)),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

            ]
                .divide(SizedBox(height: 12.0))
                .addToStart(SizedBox(height: 16.0))
                .addToEnd(SizedBox(height: 16.0)),
          ),
        ),
      ),
    );
  }
}
