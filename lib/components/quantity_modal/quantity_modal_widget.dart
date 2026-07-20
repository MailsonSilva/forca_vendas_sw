import '/core/app_theme.dart';
import '/core/app_util.dart';
import '/core/app_widgets.dart';
import 'dart:ui';
import '/action_code/index.dart' as actions;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'quantity_modal_model.dart';
export 'quantity_modal_model.dart';

/// Modal centralizado de confirmação de quantidade para inclusão de produto
/// no pedido com stepper +/-.
class QuantityModalWidget extends StatefulWidget {
  const QuantityModalWidget({
    super.key,
    this.codigoProduto,
    this.descricaoProduto,
    this.unidadeProduto,
    this.precoUnitario,
    this.saldoDisponivel,
  });

  final String? codigoProduto;
  final String? descricaoProduto;
  final String? unidadeProduto;
  final double? precoUnitario;
  final double? saldoDisponivel;

  @override
  State<QuantityModalWidget> createState() => _QuantityModalWidgetState();
}

class _QuantityModalWidgetState extends State<QuantityModalWidget> {
  late QuantityModalModel _model;

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => QuantityModalModel());
  }

  @override
  void dispose() {
    _model.maybeDispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    context.watch<AppState>();

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.of(context).secondaryBackground,
        borderRadius: BorderRadius.circular(16.0),
      ),
      child: Padding(
        padding: EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              alignment: AlignmentDirectional(0.0, 0.0),
              child: Container(
                width: 40.0,
                height: 4.0,
                decoration: BoxDecoration(
                  color: AppTheme.of(context).alternate,
                  borderRadius: BorderRadius.circular(2.0),
                ),
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget!.descricaoProduto!,
                  maxLines: 2,
                  style: AppTheme.of(context).titleMedium.override(
                        font: GoogleFonts.plusJakartaSans(
                          fontWeight: AppTheme.of(context)
                              .titleMedium
                              .fontWeight,
                          fontStyle: AppTheme.of(context)
                              .titleMedium
                              .fontStyle,
                        ),
                        color: AppTheme.of(context).primaryText,
                        letterSpacing: 0.0,
                        fontWeight:
                            AppTheme.of(context).titleMedium.fontWeight,
                        fontStyle:
                            AppTheme.of(context).titleMedium.fontStyle,
                      ),
                  overflow: TextOverflow.ellipsis,
                ),
                Row(
                  mainAxisSize: MainAxisSize.max,
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      'Cód: ',
                      style: AppTheme.of(context).bodySmall.override(
                            font: GoogleFonts.inter(
                              fontWeight: AppTheme.of(context)
                                  .bodySmall
                                  .fontWeight,
                              fontStyle: AppTheme.of(context)
                                  .bodySmall
                                  .fontStyle,
                            ),
                            color: AppTheme.of(context).secondaryText,
                            letterSpacing: 0.0,
                            fontWeight: AppTheme.of(context)
                                .bodySmall
                                .fontWeight,
                            fontStyle: AppTheme.of(context)
                                .bodySmall
                                .fontStyle,
                          ),
                    ),
                    Text(
                      widget!.codigoProduto!,
                      style: AppTheme.of(context).bodySmall.override(
                            font: GoogleFonts.inter(
                              fontWeight: AppTheme.of(context)
                                  .bodySmall
                                  .fontWeight,
                              fontStyle: AppTheme.of(context)
                                  .bodySmall
                                  .fontStyle,
                            ),
                            color: AppTheme.of(context).secondaryText,
                            letterSpacing: 0.0,
                            fontWeight: AppTheme.of(context)
                                .bodySmall
                                .fontWeight,
                            fontStyle: AppTheme.of(context)
                                .bodySmall
                                .fontStyle,
                          ),
                    ),
                    Text(
                      ' | Un: ',
                      style: AppTheme.of(context).bodySmall.override(
                            font: GoogleFonts.inter(
                              fontWeight: AppTheme.of(context)
                                  .bodySmall
                                  .fontWeight,
                              fontStyle: AppTheme.of(context)
                                  .bodySmall
                                  .fontStyle,
                            ),
                            color: AppTheme.of(context).secondaryText,
                            letterSpacing: 0.0,
                            fontWeight: AppTheme.of(context)
                                .bodySmall
                                .fontWeight,
                            fontStyle: AppTheme.of(context)
                                .bodySmall
                                .fontStyle,
                          ),
                    ),
                    Text(
                      widget!.unidadeProduto!,
                      style: AppTheme.of(context).bodySmall.override(
                            font: GoogleFonts.inter(
                              fontWeight: AppTheme.of(context)
                                  .bodySmall
                                  .fontWeight,
                              fontStyle: AppTheme.of(context)
                                  .bodySmall
                                  .fontStyle,
                            ),
                            color: AppTheme.of(context).secondaryText,
                            letterSpacing: 0.0,
                            fontWeight: AppTheme.of(context)
                                .bodySmall
                                .fontWeight,
                            fontStyle: AppTheme.of(context)
                                .bodySmall
                                .fontStyle,
                          ),
                    ),
                  ].divide(SizedBox(width: 6.0)),
                ),
              ].divide(SizedBox(height: 4.0)),
            ),
            Container(
              decoration: BoxDecoration(
                color: AppTheme.of(context).primaryBackground,
                borderRadius: BorderRadius.circular(8.0),
              ),
              child: Padding(
                padding: EdgeInsetsDirectional.fromSTEB(12.0, 10.0, 12.0, 10.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.max,
                      mainAxisAlignment: MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          'Preço Unitário: ',
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
                                color:
                                    AppTheme.of(context).secondaryText,
                                letterSpacing: 0.0,
                                fontWeight: AppTheme.of(context)
                                    .bodyMedium
                                    .fontWeight,
                                fontStyle: AppTheme.of(context)
                                    .bodyMedium
                                    .fontStyle,
                              ),
                        ),
                        Text(
                          widget!.precoUnitario!.toString(),
                          style:
                              AppTheme.of(context).titleMedium.override(
                                    font: GoogleFonts.plusJakartaSans(
                                      fontWeight: AppTheme.of(context)
                                          .titleMedium
                                          .fontWeight,
                                      fontStyle: AppTheme.of(context)
                                          .titleMedium
                                          .fontStyle,
                                    ),
                                    color: AppTheme.of(context).primary,
                                    letterSpacing: 0.0,
                                    fontWeight: AppTheme.of(context)
                                        .titleMedium
                                        .fontWeight,
                                    fontStyle: AppTheme.of(context)
                                        .titleMedium
                                        .fontStyle,
                                  ),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.max,
                      mainAxisAlignment: MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          'Saldo Disponível: ',
                          style: AppTheme.of(context)
                              .bodySmall
                              .override(
                                font: GoogleFonts.inter(
                                  fontWeight: AppTheme.of(context)
                                      .bodySmall
                                      .fontWeight,
                                  fontStyle: AppTheme.of(context)
                                      .bodySmall
                                      .fontStyle,
                                ),
                                color:
                                    AppTheme.of(context).secondaryText,
                                letterSpacing: 0.0,
                                fontWeight: AppTheme.of(context)
                                    .bodySmall
                                    .fontWeight,
                                fontStyle: AppTheme.of(context)
                                    .bodySmall
                                    .fontStyle,
                              ),
                        ),
                        Text(
                          widget!.saldoDisponivel!.toString(),
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
                                color: AppTheme.of(context).primaryText,
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
                  ].divide(SizedBox(height: 4.0)),
                ),
              ),
            ),
            Container(
              height: 1.0,
              decoration: BoxDecoration(
                color: AppTheme.of(context).alternate,
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  'Quantidade',
                  style: AppTheme.of(context).labelMedium.override(
                        font: GoogleFonts.inter(
                          fontWeight: AppTheme.of(context)
                              .labelMedium
                              .fontWeight,
                          fontStyle: AppTheme.of(context)
                              .labelMedium
                              .fontStyle,
                        ),
                        color: AppTheme.of(context).primaryText,
                        letterSpacing: 0.0,
                        fontWeight:
                            AppTheme.of(context).labelMedium.fontWeight,
                        fontStyle:
                            AppTheme.of(context).labelMedium.fontStyle,
                      ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.max,
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    AppButtonWidget(
                      onPressed: () async {
                        _model.novaQtdMinus = await actions.ajustarQuantidade(
                          AppState().quantidade_item,
                          -1,
                        );
                        AppState().quantidade_item = _model.novaQtdMinus!;
                        safeSetState(() {});

                        safeSetState(() {});
                      },
                      text: '-',
                      options: AppButtonOptions(
                        width: 48.0,
                        height: 48.0,
                        padding:
                            EdgeInsetsDirectional.fromSTEB(0.0, 0.0, 0.0, 0.0),
                        iconPadding:
                            EdgeInsetsDirectional.fromSTEB(0.0, 0.0, 0.0, 0.0),
                        color: AppTheme.of(context).primaryBackground,
                        textStyle: TextStyle(
                          color: AppTheme.of(context).primaryText,
                        ),
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                    ),
                    Expanded(
                      flex: 1,
                      child: Container(
                        alignment: AlignmentDirectional(0.0, 0.0),
                        child: Text(
                          AppState().quantidade_item.toString(),
                          style: AppTheme.of(context)
                              .headlineMedium
                              .override(
                                font: GoogleFonts.plusJakartaSans(
                                  fontWeight: AppTheme.of(context)
                                      .headlineMedium
                                      .fontWeight,
                                  fontStyle: AppTheme.of(context)
                                      .headlineMedium
                                      .fontStyle,
                                ),
                                color: AppTheme.of(context).primaryText,
                                letterSpacing: 0.0,
                                fontWeight: AppTheme.of(context)
                                    .headlineMedium
                                    .fontWeight,
                                fontStyle: AppTheme.of(context)
                                    .headlineMedium
                                    .fontStyle,
                              ),
                        ),
                      ),
                    ),
                    AppButtonWidget(
                      onPressed: () async {
                        _model.novaQtdPlus = await actions.ajustarQuantidade(
                          AppState().quantidade_item,
                          1,
                        );
                        AppState().quantidade_item = _model.novaQtdPlus!;
                        safeSetState(() {});

                        safeSetState(() {});
                      },
                      text: '+',
                      options: AppButtonOptions(
                        width: 48.0,
                        height: 48.0,
                        padding:
                            EdgeInsetsDirectional.fromSTEB(0.0, 0.0, 0.0, 0.0),
                        iconPadding:
                            EdgeInsetsDirectional.fromSTEB(0.0, 0.0, 0.0, 0.0),
                        color: AppTheme.of(context).primary,
                        textStyle: TextStyle(
                          color:
                              AppTheme.of(context).secondaryBackground,
                        ),
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                    ),
                  ].divide(SizedBox(width: 12.0)),
                ),
              ].divide(SizedBox(height: 8.0)),
            ),
            AppButtonWidget(
              onPressed: () async {
                AppState().is_loading = true;
                safeSetState(() {});
                _model.itemSalvo = await actions.salvarItemPedido(
                  widget!.codigoProduto,
                  widget!.descricaoProduto,
                  widget!.unidadeProduto,
                  AppState().quantidade_item.toString(),
                  widget!.precoUnitario,
                );
                AppState().is_loading = false;
                safeSetState(() {});
                if (_model.itemSalvo!) {
                  AppState().quantidade_item = 1;
                  safeSetState(() {});
                  await showDialog(
                    context: context,
                    builder: (alertDialogContext) {
                      return AlertDialog(
                        title: Text('Pedido'),
                        content: Text('Item adicionado ao pedido com sucesso!'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(alertDialogContext),
                            child: Text('OK'),
                          ),
                        ],
                      );
                    },
                  );
                } else {
                  await showDialog(
                    context: context,
                    builder: (alertDialogContext) {
                      return AlertDialog(
                        title: Text('Erro'),
                        content: Text(
                            'Não foi possível adicionar o item. Tente novamente.'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(alertDialogContext),
                            child: Text('OK'),
                          ),
                        ],
                      );
                    },
                  );
                }

                safeSetState(() {});
              },
              text: 'CONFIRMAR PEDIDO',
              options: AppButtonOptions(
                width: double.infinity,
                height: 52.0,
                padding: EdgeInsetsDirectional.fromSTEB(0.0, 0.0, 0.0, 0.0),
                iconPadding: EdgeInsetsDirectional.fromSTEB(0.0, 0.0, 0.0, 0.0),
                color: AppTheme.of(context).primary,
                textStyle: TextStyle(
                  color: AppTheme.of(context).secondaryBackground,
                ),
                borderRadius: BorderRadius.circular(8.0),
              ),
            ),
          ].divide(SizedBox(height: 16.0)),
        ),
      ),
    );
  }
}
