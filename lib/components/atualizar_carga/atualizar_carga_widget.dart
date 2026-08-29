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

  // ── Collapse/Expand state ─────────────────────────────────────────────────
  // Por padrão: colapsado = exibe apenas "Pedidos em Espera"
  bool _detalhesExpandidos = false;

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  Future<void> _carregarPendentes() async {
    final itens = await actions.listarArquivosPendentes('*');
    safeSetState(() {
      _model.arquivos = itens;
    });
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => AtualizarCargaModel());
    // Inicializa filtro em 'espera' para mostrar apenas pedidos aguardando envio
    _model.filtroStatus = 'espera';
    unawaited(_carregarPendentes());

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
        // Reload pending files list after sync completes
        await _carregarPendentes();
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

      await _carregarPendentes();

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
                  widget.icon!,
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
                    'Sincronização de dados com o servidor.',
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

            // ── Progress bar ─────────────────────────────────────────────────
            if (isBusy)
              Padding(
                padding:
                    const EdgeInsets.fromLTRB(16.0, 12.0, 16.0, 0.0),
                child: LinearPercentIndicator(
                  percent: _dbProgress.clamp(0.0, 1.0),
                  lineHeight: 20.0,
                  animation: true,
                  animateFromLastPercent: true,
                  progressColor: AppTheme.of(context).primary,
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

            // ── Collapse/Expand toggle ───────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16.0, 12.0, 16.0, 0.0),
              child: InkWell(
                onTap: () {
                  safeSetState(() {
                    _detalhesExpandidos = !_detalhesExpandidos;
                    // Ao colapsar volta para 'espera'; ao expandir vai para 'Todos'
                    if (!_detalhesExpandidos) {
                      _model.filtroStatus = 'espera';
                    } else {
                      _model.filtroStatus = '*';
                    }
                  });
                },
                borderRadius: BorderRadius.circular(8.0),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                  decoration: BoxDecoration(
                    color: AppTheme.of(context).accent1,
                    borderRadius: BorderRadius.circular(8.0),
                    border: Border.all(
                      color: AppTheme.of(context).alternate,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            _detalhesExpandidos
                                ? Icons.inbox_outlined
                                : Icons.hourglass_top_rounded,
                            size: 16.0,
                            color: AppTheme.of(context).primary,
                          ),
                          const SizedBox(width: 6.0),
                          Text(
                            _detalhesExpandidos
                                ? 'Todos os arquivos'
                                : 'Pedidos em Espera',
                            style: AppTheme.of(context).bodySmall.override(
                                  font: GoogleFonts.inter(
                                    fontWeight: FontWeight.w600,
                                    fontStyle: AppTheme.of(context).bodySmall.fontStyle,
                                  ),
                                  color: AppTheme.of(context).primary,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Text(
                            _detalhesExpandidos ? 'Ocultar' : 'Ver detalhes',
                            style: AppTheme.of(context).bodySmall.override(
                                  font: GoogleFonts.inter(
                                    fontStyle: AppTheme.of(context).bodySmall.fontStyle,
                                  ),
                                  color: AppTheme.of(context).secondaryText,
                                ),
                          ),
                          const SizedBox(width: 4.0),
                          AnimatedRotation(
                            turns: _detalhesExpandidos ? 0.5 : 0.0,
                            duration: const Duration(milliseconds: 200),
                            child: Icon(
                              Icons.keyboard_arrow_down_rounded,
                              size: 18.0,
                              color: AppTheme.of(context).secondaryText,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // ── Filter chips (visíveis apenas quando expandido) ───────────────
            if (_detalhesExpandidos)
              Padding(
                padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 0.0),
                child: Wrap(
                  spacing: 6.0,
                  runSpacing: 6.0,
                  children: [
                    _FiltroStatusChip(
                      label: 'Todos',
                      selected: _model.filtroStatus == '*',
                      onSelected: () =>
                          safeSetState(() => _model.filtroStatus = '*'),
                    ),
                    _FiltroStatusChip(
                      label: 'Em espera',
                      selected: _model.filtroStatus == 'espera',
                      onSelected: () =>
                          safeSetState(() => _model.filtroStatus = 'espera'),
                    ),
                    _FiltroStatusChip(
                      label: 'Enviados',
                      selected: _model.filtroStatus == 'enviados',
                      onSelected: () =>
                          safeSetState(() => _model.filtroStatus = 'enviados'),
                    ),
                    _FiltroStatusChip(
                      label: 'Erro',
                      selected: _model.filtroStatus == 'erro',
                      onSelected: () =>
                          safeSetState(() => _model.filtroStatus = 'erro'),
                    ),
                  ],
                ),
              ),

            // ── File list ────────────────────────────────────────────────────
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 60.0, maxHeight: 220.0),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 0.0),
                child: _arquivosFiltrados.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Text(
                            _detalhesExpandidos
                                ? 'Nenhum arquivo para este status.'
                                : 'Nenhum arquivo aguardando envio.',
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
                                ),
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: EdgeInsets.zero,
                        shrinkWrap: true,
                        itemCount: _arquivosFiltrados.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 6.0),
                        itemBuilder: (context, i) {
                          final item = _arquivosFiltrados[i];
                          final enviando = isBusy &&
                              !item.sucesso &&
                              item.mensagem != 'Aguardando envio.' &&
                              item.mensagem != 'Enviado com sucesso.';
                          return _LinhaArquivo(
                            item: item,
                            enviando: enviando,
                          );
                        },
                      ),
              ),
            ),

            // ── Footer: Action Button (Apenas Baixar Carga) ──────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16.0, 12.0, 16.0, 16.0),
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
                  icon: const Icon(Icons.cloud_download_outlined, size: 20.0),
                  label: const Text(
                    'Baixar Carga',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15.0),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<ItemUploadStruct> get _arquivosEmEspera => _model.arquivos
      .where((item) => !item.sucesso && !item.mensagem.startsWith('Falha'))
      .toList();

  List<ItemUploadStruct> get _arquivosFiltrados {
    switch (_model.filtroStatus) {
      case 'espera':
        return _arquivosEmEspera;
      case 'enviados':
        return _model.arquivos.where((item) => item.sucesso).toList();
      case 'erro':
        return _model.arquivos
            .where((item) => item.mensagem.startsWith('Falha'))
            .toList();
      default:
        return _model.arquivos;
    }
  }
}

class _FiltroStatusChip extends StatelessWidget {
  const _FiltroStatusChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
      selectedColor: AppTheme.of(context).primary,
      backgroundColor: AppTheme.of(context).accent1,
      labelStyle: AppTheme.of(context).bodySmall.override(
            font: GoogleFonts.inter(
              fontWeight: FontWeight.w600,
              fontStyle: AppTheme.of(context).bodySmall.fontStyle,
            ),
            color: selected ? Colors.white : AppTheme.of(context).primaryText,
            letterSpacing: 0.0,
            fontWeight: FontWeight.w600,
            fontStyle: AppTheme.of(context).bodySmall.fontStyle,
          ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8.0),
      ),
    );
  }
}

class _LinhaArquivo extends StatelessWidget {
  const _LinhaArquivo({required this.item, required this.enviando});

  final ItemUploadStruct item;
  final bool enviando;

  @override
  Widget build(BuildContext context) {
    Widget leading;
    Color stateColor;

    if (item.sucesso) {
      leading = const Icon(Icons.check_circle_rounded, size: 22.0);
      stateColor = const Color(0xFF2E7D32);
    } else if (enviando) {
      leading = const SizedBox(
        width: 18.0,
        height: 18.0,
        child: CircularProgressIndicator(strokeWidth: 2.5),
      );
      stateColor = AppTheme.of(context).primary;
    } else if (item.mensagem.startsWith('Falha')) {
      leading = const Icon(Icons.error_outline_rounded, size: 22.0);
      stateColor = const Color(0xFFC62828);
    } else {
      leading = const Icon(Icons.hourglass_empty_rounded, size: 22.0);
      stateColor = AppTheme.of(context).secondaryText;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
      decoration: BoxDecoration(
        color: AppTheme.of(context).accent1,
        borderRadius: BorderRadius.circular(6.0),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.max,
        children: [
          ColorFiltered(
            colorFilter: ColorFilter.mode(stateColor, BlendMode.srcIn),
            child: leading,
          ),
          const SizedBox(width: 8.0),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.nome,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.of(context).bodyMedium.override(
                        font: GoogleFonts.inter(
                          fontWeight: FontWeight.w600,
                          fontStyle:
                              AppTheme.of(context).bodyMedium.fontStyle,
                        ),
                        fontSize: 13.0,
                        letterSpacing: 0.0,
                        fontWeight: FontWeight.w600,
                        fontStyle: AppTheme.of(context).bodyMedium.fontStyle,
                      ),
                ),
                Text(
                  item.mensagem,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.of(context).bodySmall.override(
                        font: GoogleFonts.inter(
                          fontWeight:
                              AppTheme.of(context).bodySmall.fontWeight,
                          fontStyle:
                              AppTheme.of(context).bodySmall.fontStyle,
                        ),
                        color: stateColor,
                        fontSize: 11.0,
                        letterSpacing: 0.0,
                      ),
                ),
              ],
            ),
          ),
          if (item.bytesEnviados > 0)
            Text(
              '${(item.bytesEnviados / 1024).toStringAsFixed(1)} KB',
              style: AppTheme.of(context).bodySmall.override(
                    font: GoogleFonts.inter(
                      fontWeight: AppTheme.of(context).bodySmall.fontWeight,
                      fontStyle: AppTheme.of(context).bodySmall.fontStyle,
                    ),
                    color: AppTheme.of(context).secondaryText,
                    fontSize: 11.0,
                    letterSpacing: 0.0,
                  ),
            ),
        ],
      ),
    );
  }
}
