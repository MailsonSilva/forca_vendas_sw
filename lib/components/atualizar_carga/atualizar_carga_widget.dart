// ignore_for_file: unnecessary_import, prefer_const_constructors, prefer_const_literals_to_create_immutables, unnecessary_non_null_assertion, avoid_print

import '/core/app_icon_button.dart';
import '/core/app_theme.dart';
import '/core/app_util.dart';
import 'dart:ui';
import 'dart:async';
import '/action_code/index.dart' as actions;
import '/services/background_sync_service.dart';
import '/backend/schema/structs/index.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:percent_indicator/percent_indicator.dart';
import 'package:provider/provider.dart';
import 'atualizar_carga_model.dart';
export 'atualizar_carga_model.dart';

class AtualizarCargaWidget extends StatefulWidget {
  const AtualizarCargaWidget({
    super.key,
    required this.titulo,
    required this.descricao,
    required this.icon,
  });

  final String? titulo;
  final String? descricao;
  final Widget? icon;

  @override
  State<AtualizarCargaWidget> createState() => _AtualizarCargaWidgetState();
}

class _AtualizarCargaWidgetState extends State<AtualizarCargaWidget> {
  late AtualizarCargaModel _model;

  // ── Local DB sync state (polled from SharedPreferences) ───────────────────
  String _dbStatus = 'idle';
  double _dbProgress = 0.0;
  String _dbText = '';
  Timer? _pollTimer;

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => AtualizarCargaModel());

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final status = await BackgroundSyncService.instance.pollDbSyncStatus();
      if (status['status'] == 'complete' || status['status'] == 'error') {
        await BackgroundSyncService.instance.resetDbStatus();
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
    _pollTimer = Timer.periodic(const Duration(milliseconds: 250), (_) async {
      await _refreshStatus();
      if (_dbStatus == 'complete' || _dbStatus == 'error') {
        _pollTimer?.cancel();
        if (appNavigatorKey.currentContext != null) {
          ScaffoldMessenger.of(appNavigatorKey.currentContext!).showSnackBar(
            SnackBar(
              content: Text(_dbText),
              backgroundColor: _dbStatus == 'complete'
                  ? const Color(0xFF5CB85C)
                  : Colors.red,
            ),
          );
        }
      }
    });
  }

  Future<void> _refreshStatus() async {
    final status = await BackgroundSyncService.instance.pollDbSyncStatus();
    if (mounted) {
      safeSetState(() {
        _dbStatus = status['status'] as String;
        _dbProgress = status['progress'] as double;
        _dbText = status['text'] as String;
      });
    }
  }

  Future<void> _startDownload() async {
    final String empresa = AppState().empresa_codigo.trim().isEmpty
        ? 'DINIZ'
        : AppState().empresa_codigo.trim();
    final String vendedor = AppState().vendedor_codigo > 0
        ? AppState().vendedor_codigo.toString()
        : '1';

    safeSetState(() {
      _dbStatus = 'baixando';
      _dbProgress = 0.2;
      _dbText = 'Conectando ao FTP...';
    });

    try {
      safeSetState(() {
        _dbProgress = 0.5;
        _dbText = 'Baixando base de dados $empresa ($vendedor)...';
      });

      final result = await actions.downloadDatabaseFromFtp(empresa, vendedor);

      safeSetState(() {
        _dbStatus = result.success ? 'complete' : 'error';
        _dbProgress = 1.0;
        _dbText = result.message;
      });

      if (appNavigatorKey.currentContext != null) {
        ScaffoldMessenger.of(appNavigatorKey.currentContext!).showSnackBar(
          SnackBar(
            content: Text(result.message),
            backgroundColor:
                result.success ? const Color(0xFF5CB85C) : Colors.red,
          ),
        );
      }

      await Future.delayed(const Duration(seconds: 2));
      if (mounted) {
        safeSetState(() {
          _dbStatus = 'idle';
          _dbProgress = 0.0;
          _dbText = '';
        });
      }
    } catch (e) {
      safeSetState(() {
        _dbStatus = 'error';
        _dbProgress = 0.0;
        _dbText = 'Erro ao baixar carga: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    context.watch<AppState>();

    final bool isBusy = _dbStatus == 'baixando';
    final String empresa = AppState().empresa_codigo.trim().isEmpty ? 'DINIZ' : AppState().empresa_codigo.trim();
    final int vendedor = AppState().vendedor_codigo > 0 ? AppState().vendedor_codigo : 1;

    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(16.0, 0.0, 16.0, 0.0),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppTheme.of(context).secondaryBackground,
          boxShadow: const [
            BoxShadow(
              blurRadius: 6.0,
              color: Color(0x26000000),
              offset: Offset(0.0, 2.0),
            )
          ],
          borderRadius: BorderRadius.circular(12.0),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Header ──────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 0.0),
              child: Row(
                children: [
                  widget.icon ?? const Icon(Icons.storage_rounded, color: Color(0xFF3572F7)),
                  const SizedBox(width: 8.0),
                  Expanded(
                    child: Text(
                      valueOrDefault<String>(
                        widget.titulo,
                        'Carga de Dados',
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
            ),
            // ── Description ─────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16.0, 6.0, 16.0, 0.0),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  valueOrDefault<String>(
                    widget.descricao,
                    'Atualização da base de dados e tabelas comerciais com o servidor.',
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
                      ),
                ),
              ),
            ),

            // ── Info Card (Empresa & Representante) ───────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16.0, 12.0, 16.0, 0.0),
              child: Container(
                padding: const EdgeInsets.all(12.0),
                decoration: BoxDecoration(
                  color: AppTheme.of(context).primaryBackground,
                  borderRadius: BorderRadius.circular(8.0),
                  border: Border.all(color: AppTheme.of(context).alternate),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Column(
                      children: [
                        Text(
                          'Empresa',
                          style: TextStyle(fontSize: 11.0, color: Colors.grey[600]),
                        ),
                        const SizedBox(height: 2.0),
                        Text(
                          empresa,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.0),
                        ),
                      ],
                    ),
                    Container(height: 24.0, width: 1.0, color: AppTheme.of(context).alternate),
                    Column(
                      children: [
                        Text(
                          'Vendedor / Rep',
                          style: TextStyle(fontSize: 11.0, color: Colors.grey[600]),
                        ),
                        const SizedBox(height: 2.0),
                        Text(
                          '#$vendedor',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.0),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // ── Progress bar ─────────────────────────────────────────────────
            if (isBusy || _dbStatus == 'complete' || _dbStatus == 'error')
              Padding(
                padding:
                    const EdgeInsets.fromLTRB(16.0, 12.0, 16.0, 0.0),
                child: LinearPercentIndicator(
                  percent: _dbProgress.clamp(0.0, 1.0),
                  lineHeight: 20.0,
                  animation: true,
                  animateFromLastPercent: true,
                  progressColor: _dbStatus == 'error' ? Colors.red : AppTheme.of(context).primary,
                  backgroundColor: AppTheme.of(context).accent4,
                  center: Text(
                    _dbText,
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
                        ),
                  ),
                  barRadius: const Radius.circular(8.0),
                  padding: EdgeInsets.zero,
                ),
              ),

            // ── Footer: Action Button (Apenas Baixar Carga) ──────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 16.0),
              child: SizedBox(
                width: double.infinity,
                height: 48.0,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.of(context).primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                    elevation: 0,
                  ),
                  onPressed: isBusy ? null : _startDownload,
                  icon: isBusy
                      ? const SizedBox(
                          width: 18.0,
                          height: 18.0,
                          child: CircularProgressIndicator(strokeWidth: 2.0, color: Colors.white),
                        )
                      : const Icon(Icons.cloud_download_outlined, size: 20.0),
                  label: Text(
                    isBusy ? 'Baixando Carga...' : 'Baixar Carga',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15.0),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

