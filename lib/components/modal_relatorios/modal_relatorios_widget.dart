// ignore_for_file: unused_import, unnecessary_import, avoid_print, prefer_const_constructors, prefer_const_literals_to_create_immutables, deprecated_member_use

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

  Widget _buildReportItem({
    required IconData icon,
    required Color iconColor,
    required Color iconBgColor,
    required String title,
    required String description,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.of(context).secondaryBackground,
        boxShadow: const [
          BoxShadow(
            blurRadius: 4.0,
            color: Color(0x22000000),
            offset: Offset(0.0, 2.0),
          )
        ],
        borderRadius: BorderRadius.circular(12.0),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12.0),
        child: InkWell(
          borderRadius: BorderRadius.circular(12.0),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 12.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 52.0,
                  height: 52.0,
                  decoration: BoxDecoration(
                    color: iconBgColor,
                    borderRadius: BorderRadius.circular(10.0),
                  ),
                  child: Icon(
                    icon,
                    color: iconColor,
                    size: 28.0,
                  ),
                ),
                const SizedBox(width: 14.0),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: AppTheme.of(context).bodyMedium.override(
                              font: GoogleFonts.inter(
                                fontWeight: FontWeight.w600,
                              ),
                              fontSize: 15.0,
                              color: AppTheme.of(context).primaryText,
                            ),
                      ),
                      const SizedBox(height: 4.0),
                      Text(
                        description,
                        style: AppTheme.of(context).bodyMedium.override(
                              font: GoogleFonts.inter(
                                fontWeight: FontWeight.normal,
                              ),
                              fontSize: 12.0,
                              color: AppTheme.of(context).secondaryText,
                            ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8.0),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 16.0,
                  color: AppTheme.of(context).secondaryText.withOpacity(0.6),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: double.infinity,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.82,
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
                    color: Colors.grey.withOpacity(0.3),
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
                    Row(
                      children: [
                        Icon(
                          Icons.analytics_rounded,
                          color: AppTheme.of(context).primary,
                          size: 24.0,
                        ),
                        const SizedBox(width: 8.0),
                        Text(
                          'Menu de Relatórios',
                          style: AppTheme.of(context).titleLarge.override(
                                font: GoogleFonts.outfit(
                                  fontWeight: FontWeight.w600,
                                ),
                                color: AppTheme.of(context).primaryText,
                                fontSize: 20.0,
                              ),
                        ),
                      ],
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
              // Report items list
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsetsDirectional.fromSTEB(16.0, 14.0, 16.0, 20.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildReportItem(
                        icon: Icons.account_balance_wallet_rounded,
                        iconColor: AppTheme.of(context).primary,
                        iconBgColor: AppTheme.of(context).primary.withOpacity(0.12),
                        title: 'Conta-Corrente (CCV)',
                        description: 'Extrato de margens, créditos e débitos de Saldo Flex.',
                        onTap: () {
                          Navigator.pop(context);
                          context.pushNamed('ContaCorrentePage');
                        },
                      ),
                      const SizedBox(height: 12.0),
                      _buildReportItem(
                        icon: Icons.query_stats_rounded,
                        iconColor: const Color(0xFF24A148),
                        iconBgColor: const Color(0xFF24A148).withOpacity(0.12),
                        title: 'Resumo de Vendas e Comissões',
                        description: 'Apuração de vendas brutas, líquidas, devoluções e comissões.',
                        onTap: () {
                          Navigator.pop(context);
                          context.pushNamed('ResumoVendasPage');
                        },
                      ),
                      const SizedBox(height: 12.0),
                      _buildReportItem(
                        icon: Icons.route_rounded,
                        iconColor: const Color(0xFF0288D1),
                        iconBgColor: const Color(0xFF0288D1).withOpacity(0.12),
                        title: 'Roteiro de Visitas (Carteira)',
                        description: 'Planejamento de visitas por dia, alertas de crédito e navegação.',
                        onTap: () {
                          Navigator.pop(context);
                          context.pushNamed('CarteiraRoteirizacaoPage');
                        },
                      ),
                      const SizedBox(height: 12.0),
                      _buildReportItem(
                        icon: Icons.insights_rounded,
                        iconColor: const Color(0xFF7C3AED),
                        iconBgColor: const Color(0xFF7C3AED).withOpacity(0.12),
                        title: 'Faturamento e Metas',
                        description: 'Acompanhamento de metas mensais (PF e PJ) e limites de faturamento.',
                        onTap: () {
                          Navigator.pop(context);
                          context.pushNamed('FaturamentoMetasPage');
                        },
                      ),
                    ],
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
