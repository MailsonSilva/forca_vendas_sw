// ignore_for_file: unnecessary_import, prefer_const_constructors, prefer_const_literals_to_create_immutables, unnecessary_non_null_assertion

import '/core/app_icon_button.dart';
import '/core/app_theme.dart';
import '/core/app_util.dart';
import 'dart:ui';
import 'dart:async';
import '/services/background_sync_service.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:percent_indicator/percent_indicator.dart';
import 'package:provider/provider.dart';
import 'atualizar_imagens_model.dart';
export 'atualizar_imagens_model.dart';

class AtualizarImagensWidget extends StatefulWidget {
  const AtualizarImagensWidget({
    super.key,
    required this.titulo,
    required this.descricao,
    required this.icon,
  });

  final String? titulo;
  final String? descricao;
  final Widget? icon;

  @override
  State<AtualizarImagensWidget> createState() => _AtualizarImagensWidgetState();
}

class _AtualizarImagensWidgetState extends State<AtualizarImagensWidget> {
  late AtualizarImagensModel _model;

  // ── Local sync state (polled from SharedPreferences) ──────────────────────
  String _imgStatus = 'idle';
  double _imgProgress = 0.0;
  String _imgText = '';
  Timer? _pollTimer;

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => AtualizarImagensModel());

    // If a previous sync completed/failed, reset for a clean slate
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final status = await BackgroundSyncService.instance.pollImageSyncStatus();
      if (status['status'] == 'complete' || status['status'] == 'error') {
        await BackgroundSyncService.instance.resetImageStatus();
      } else if (status['status'] == 'baixando') {
        _startPolling();
      }
      _refreshStatus();
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _model.maybeDispose();
    super.dispose();
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(milliseconds: 50), (_) async {
      await _refreshStatus();
      if (_imgStatus == 'complete' || _imgStatus == 'error') {
        _pollTimer?.cancel();
      }
    });
  }

  Future<void> _refreshStatus() async {
    final status = await BackgroundSyncService.instance.pollImageSyncStatus();
    if (mounted) {
      safeSetState(() {
        _imgStatus = status['status'] as String;
        _imgProgress = status['progress'] as double;
        _imgText = status['text'] as String;
      });
    }
  }

  Future<void> _startSync(String modo) async {
    // Optimistically show loading state immediately
    safeSetState(() {
      _imgStatus = 'baixando';
      _imgProgress = 0.0;
      _imgText = 'Iniciando download em background...';
    });

    await BackgroundSyncService.instance.startImageSync(modo);
    _startPolling();
  }

  @override
  Widget build(BuildContext context) {
    context.watch<AppState>();

    final bool isDownloading = _imgStatus == 'baixando';

    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(16.0, 0.0, 16.0, 0.0),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppTheme.of(context).secondaryBackground,
          boxShadow: const [
            BoxShadow(
              blurRadius: 4.0,
              color: Color(0x33000000),
              offset: Offset(0.0, 2.0),
            )
          ],
          borderRadius: BorderRadius.circular(12.0),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Header ────────────────────────────────────────────────────
              Row(
                children: [
                  widget.icon!,
                  const SizedBox(width: 8.0),
                  Expanded(
                    child: Text(
                      valueOrDefault<String>(
                        widget.titulo,
                        'Imagens dos Produtos',
                      ),
                      style: AppTheme.of(context).bodyMedium.override(
                            font: GoogleFonts.inter(
                              fontWeight: FontWeight.w600,
                              fontStyle:
                                  AppTheme.of(context).bodyMedium.fontStyle,
                            ),
                            fontSize: 16.0,
                            letterSpacing: 0.0,
                            fontWeight: FontWeight.w600,
                            fontStyle:
                                AppTheme.of(context).bodyMedium.fontStyle,
                          ),
                    ),
                  ),
                  AppIconButton(
                    borderColor: const Color(0xFFE0E3E7),
                    borderRadius: 12.0,
                    borderWidth: 1.0,
                    buttonSize: 36.0,
                    icon: Icon(
                      Icons.close_rounded,
                      color: AppTheme.of(context).primaryText,
                      size: 18.0,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 8.0),

              // ── Description ───────────────────────────────────────────────
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  valueOrDefault<String>(
                    widget.descricao,
                    'Parcial: atualização rápida. Total: baixa tudo e atualiza todas as imagens.',
                  ),
                  maxLines: 2,
                  style: AppTheme.of(context).bodyMedium.override(
                        font: GoogleFonts.inter(
                          fontWeight:
                              AppTheme.of(context).bodyMedium.fontWeight,
                          fontStyle:
                              AppTheme.of(context).bodyMedium.fontStyle,
                        ),
                        color: AppTheme.of(context).secondaryText,
                        letterSpacing: 0.0,
                        fontWeight:
                            AppTheme.of(context).bodyMedium.fontWeight,
                        fontStyle: AppTheme.of(context).bodyMedium.fontStyle,
                      ),
                ),
              ),
              const SizedBox(height: 16.0),

              // ── Progress bar (visible while downloading) ──────────────────
              if (isDownloading)
                Row(
                  children: [
                    Expanded(
                      child: LinearPercentIndicator(
                        percent: _imgProgress.clamp(0.0, 1.0),
                        lineHeight: 20.0,
                        animation: true,
                        animateFromLastPercent: true,
                        progressColor: AppTheme.of(context).primary,
                        backgroundColor: AppTheme.of(context).accent4,
                        center: Text(
                          _imgText,
                          style: AppTheme.of(context).headlineSmall.override(
                                font: GoogleFonts.plusJakartaSans(
                                  fontWeight: AppTheme.of(context)
                                      .headlineSmall
                                      .fontWeight,
                                  fontStyle: AppTheme.of(context)
                                      .headlineSmall
                                      .fontStyle,
                                ),
                                color: AppTheme.of(context).primaryText,
                                fontSize: 12.0,
                                letterSpacing: 0.0,
                                fontWeight: AppTheme.of(context)
                                    .headlineSmall
                                    .fontWeight,
                                fontStyle: AppTheme.of(context)
                                    .headlineSmall
                                    .fontStyle,
                              ),
                        ),
                        barRadius: const Radius.circular(8.0),
                        padding: EdgeInsets.zero,
                      ),
                    ),
                    const SizedBox(width: 8.0),
                    AppIconButton(
                      borderColor: Colors.transparent,
                      borderRadius: 8.0,
                      borderWidth: 1.0,
                      buttonSize: 36.0,
                      fillColor: AppTheme.of(context).accent4,
                      icon: Icon(
                        Icons.cancel_outlined,
                        color: AppTheme.of(context).error,
                        size: 20.0,
                      ),
                      onPressed: () async {
                        _pollTimer?.cancel();
                        await BackgroundSyncService.instance.resetImageStatus();
                        safeSetState(() {
                          _imgStatus = 'idle';
                          _imgProgress = 0.0;
                          _imgText = '';
                        });
                      },
                    ),
                  ],
                ),

              // ── Background indicator (task registered, not yet started) ───
              if (_imgStatus == 'idle' && _imgText.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline_rounded,
                          color: AppTheme.of(context).secondaryText, size: 16),
                      const SizedBox(width: 6.0),
                      Expanded(
                        child: Text(
                          'Download registrado em background. Pode continuar usando o app.',
                          style: AppTheme.of(context).bodySmall.override(
                                font: GoogleFonts.inter(
                                  color: AppTheme.of(context).secondaryText,
                                ),
                                fontSize: 12.0,
                              ),
                        ),
                      ),
                    ],
                  ),
                ),

              // ── Action buttons ─────────────────────────────────────────────
              if (!isDownloading)
                Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      height: 44.0,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.of(context).primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                          elevation: 0,
                        ),
                        onPressed: () => _startSync('parcial'),
                        icon: const Icon(Icons.cloud_sync_outlined, size: 20.0),
                        label: Text(
                          'Atualização Parcial',
                          style: AppTheme.of(context).titleSmall.override(
                                font: GoogleFonts.inter(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8.0),
                    SizedBox(
                      width: double.infinity,
                      height: 44.0,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: AppTheme.of(context).primary,
                          side: BorderSide(
                              color: AppTheme.of(context).primary, width: 1.5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                          elevation: 0,
                        ),
                        onPressed: () => _startSync('total'),
                        icon: Icon(Icons.cloud_download_outlined,
                            size: 20.0, color: AppTheme.of(context).primary),
                        label: Text(
                          'Atualização Total',
                          style: AppTheme.of(context).titleSmall.override(
                                font: GoogleFonts.inter(
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.of(context).primary,
                                ),
                              ),
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
