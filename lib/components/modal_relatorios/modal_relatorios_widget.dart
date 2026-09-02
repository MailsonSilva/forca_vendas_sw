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
import 'modal_relatorios_model.dart';
export 'modal_relatorios_model.dart';

class ModalRelatoriosWidget extends StatefulWidget {
  const ModalRelatoriosWidget({super.key});

  @override
  State<ModalRelatoriosWidget> createState() => _ModalRelatoriosWidgetState();
}

class _ModalRelatoriosWidgetState extends State<ModalRelatoriosWidget> {
  late ModalRelatoriosModel _model;

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => ModalRelatoriosModel());
  }

  @override
  void dispose() {
    _model.maybeDispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: double.infinity,
        height: 300.0,
        decoration: const BoxDecoration(
          color: Colors.white,
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
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(12.0),
            topRight: Radius.circular(12.0),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(18.0),
          child: Column(
            mainAxisSize: MainAxisSize.max,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisSize: MainAxisSize.max,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Relatórios',
                    style: AppTheme.of(context).titleLarge.override(
                          font: GoogleFonts.outfit(
                            fontWeight: FontWeight.w500,
                            fontStyle: AppTheme.of(context).titleLarge.fontStyle,
                          ),
                          color: const Color(0xFF14181B),
                          fontSize: 22.0,
                          letterSpacing: 0.0,
                          fontWeight: FontWeight.w500,
                          fontStyle: AppTheme.of(context).titleLarge.fontStyle,
                        ),
                  ),
                  AppIconButton(
                    borderColor: const Color(0xFFE0E3E7),
                    borderRadius: 12.0,
                    borderWidth: 1.0,
                    buttonSize: 44.0,
                    icon: const Icon(
                      Icons.close_rounded,
                      color: Color(0xFF14181B),
                      size: 20.0,
                    ),
                    onPressed: () async {
                      Navigator.pop(context);
                    },
                  ),
                ],
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(0.0, 12.0, 0.0, 0.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.max,
                    children: [
                      Padding(
                        padding: const EdgeInsetsDirectional.fromSTEB(2.0, 0.0, 2.0, 0.0),
                        child: Container(
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
                            padding: const EdgeInsets.all(8.0),
                            child: InkWell(
                              splashColor: Colors.transparent,
                              focusColor: Colors.transparent,
                              hoverColor: Colors.transparent,
                              highlightColor: Colors.transparent,
                              onTap: () async {
                                Navigator.pop(context);
                                context.pushNamed('ContaCorrentePage');
                              },
                              child: Row(
                                mainAxisSize: MainAxisSize.max,
                                mainAxisAlignment: MainAxisAlignment.start,
                                children: [
                                  AppIconButton(
                                    borderRadius: 8.0,
                                    buttonSize: 60.0,
                                    fillColor: const Color(0x333572F7),
                                    icon: Icon(
                                      Icons.account_balance_wallet_rounded,
                                      color: AppTheme.of(context).primary,
                                      size: 32.0,
                                    ),
                                    onPressed: () {
                                      Navigator.pop(context);
                                      context.pushNamed('ContaCorrentePage');
                                    },
                                  ),
                                  Expanded(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.max,
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Conta-Corrente (CCV)',
                                          style: AppTheme.of(context).bodyMedium.override(
                                                font: GoogleFonts.inter(
                                                  fontWeight: FontWeight.w600,
                                                  fontStyle: AppTheme.of(context).bodyMedium.fontStyle,
                                                ),
                                                fontSize: 16.0,
                                                letterSpacing: 0.0,
                                                fontWeight: FontWeight.w600,
                                                fontStyle: AppTheme.of(context).bodyMedium.fontStyle,
                                              ),
                                        ),
                                        Text(
                                          'Extrato de margens, créditos e débitos de Saldo Flex.',
                                          style: AppTheme.of(context).bodyMedium.override(
                                                font: GoogleFonts.inter(
                                                  fontWeight: AppTheme.of(context).bodyMedium.fontWeight,
                                                  fontStyle: AppTheme.of(context).bodyMedium.fontStyle,
                                                ),
                                                letterSpacing: 0.0,
                                                color: AppTheme.of(context).secondaryText,
                                                fontWeight: AppTheme.of(context).bodyMedium.fontWeight,
                                                fontStyle: AppTheme.of(context).bodyMedium.fontStyle,
                                              ),
                                        ),
                                      ].divide(const SizedBox(height: 8.0)),
                                    ),
                                  ),
                                ].divide(const SizedBox(width: 12.0)),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsetsDirectional.fromSTEB(2.0, 0.0, 2.0, 0.0),
                        child: Container(
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
                            padding: const EdgeInsets.all(8.0),
                            child: InkWell(
                              splashColor: Colors.transparent,
                              focusColor: Colors.transparent,
                              hoverColor: Colors.transparent,
                              highlightColor: Colors.transparent,
                              onTap: () async {
                                Navigator.pop(context);
                                context.pushNamed('ResumoVendasPage');
                              },
                              child: Row(
                                mainAxisSize: MainAxisSize.max,
                                mainAxisAlignment: MainAxisAlignment.start,
                                children: [
                                  AppIconButton(
                                    borderRadius: 8.0,
                                    buttonSize: 60.0,
                                    fillColor: const Color(0x3324A148),
                                    icon: const Icon(
                                      Icons.query_stats_rounded,
                                      color: Color(0xFF24A148),
                                      size: 32.0,
                                    ),
                                    onPressed: () {
                                      Navigator.pop(context);
                                      context.pushNamed('ResumoVendasPage');
                                    },
                                  ),
                                  Expanded(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.max,
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Resumo de Vendas e Comissões',
                                          style: AppTheme.of(context).bodyMedium.override(
                                                font: GoogleFonts.inter(
                                                  fontWeight: FontWeight.w600,
                                                  fontStyle: AppTheme.of(context).bodyMedium.fontStyle,
                                                ),
                                                fontSize: 16.0,
                                                letterSpacing: 0.0,
                                                fontWeight: FontWeight.w600,
                                                fontStyle: AppTheme.of(context).bodyMedium.fontStyle,
                                              ),
                                        ),
                                        Text(
                                          'Apuração de vendas brutas, líquidas, devoluções e comissões.',
                                          style: AppTheme.of(context).bodyMedium.override(
                                                font: GoogleFonts.inter(
                                                  fontWeight: AppTheme.of(context).bodyMedium.fontWeight,
                                                  fontStyle: AppTheme.of(context).bodyMedium.fontStyle,
                                                ),
                                                letterSpacing: 0.0,
                                                color: AppTheme.of(context).secondaryText,
                                                fontWeight: AppTheme.of(context).bodyMedium.fontWeight,
                                                fontStyle: AppTheme.of(context).bodyMedium.fontStyle,
                                              ),
                                        ),
                                      ].divide(const SizedBox(height: 8.0)),
                                    ),
                                  ),
                                ].divide(const SizedBox(width: 12.0)),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsetsDirectional.fromSTEB(2.0, 0.0, 2.0, 0.0),
                        child: Container(
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
                            padding: const EdgeInsets.all(8.0),
                            child: InkWell(
                              splashColor: Colors.transparent,
                              focusColor: Colors.transparent,
                              hoverColor: Colors.transparent,
                              highlightColor: Colors.transparent,
                              onTap: () async {
                                Navigator.pop(context);
                                context.pushNamed('CarteiraRoteirizacaoPage');
                              },
                              child: Row(
                                mainAxisSize: MainAxisSize.max,
                                mainAxisAlignment: MainAxisAlignment.start,
                                children: [
                                  AppIconButton(
                                    borderRadius: 8.0,
                                    buttonSize: 60.0,
                                    fillColor: const Color(0x333572F7),
                                    icon: const Icon(
                                      Icons.route_rounded,
                                      color: Color(0xFF3572F7),
                                      size: 32.0,
                                    ),
                                    onPressed: () {
                                      Navigator.pop(context);
                                      context.pushNamed('CarteiraRoteirizacaoPage');
                                    },
                                  ),
                                  Expanded(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.max,
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Roteiro de Visitas (Carteira)',
                                          style: AppTheme.of(context).bodyMedium.override(
                                                font: GoogleFonts.inter(
                                                  fontWeight: FontWeight.w600,
                                                  fontStyle: AppTheme.of(context).bodyMedium.fontStyle,
                                                ),
                                                fontSize: 16.0,
                                                letterSpacing: 0.0,
                                                fontWeight: FontWeight.w600,
                                                fontStyle: AppTheme.of(context).bodyMedium.fontStyle,
                                              ),
                                        ),
                                        Text(
                                          'Planejamento de visitas por dia, alertas de crédito e navegação.',
                                          style: AppTheme.of(context).bodyMedium.override(
                                                font: GoogleFonts.inter(
                                                  fontWeight: AppTheme.of(context).bodyMedium.fontWeight,
                                                  fontStyle: AppTheme.of(context).bodyMedium.fontStyle,
                                                ),
                                                letterSpacing: 0.0,
                                                color: AppTheme.of(context).secondaryText,
                                                fontWeight: AppTheme.of(context).bodyMedium.fontWeight,
                                                fontStyle: AppTheme.of(context).bodyMedium.fontStyle,
                                              ),
                                        ),
                                      ].divide(const SizedBox(height: 8.0)),
                                    ),
                                  ),
                                ].divide(const SizedBox(width: 12.0)),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ].divide(const SizedBox(height: 16.0)).addToStart(const SizedBox(height: 12.0)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
