// ignore_for_file: unnecessary_import

import '/core/app_icon_button.dart';
import '/core/app_theme.dart';
import '/core/app_util.dart';
import '/backend/schema/structs/index.dart';
import 'dart:ui';
import 'dart:async';
import '/action_code/index.dart' as actions;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:percent_indicator/percent_indicator.dart';
import 'package:provider/provider.dart';
import 'envio_detalhes_model.dart';
export 'envio_detalhes_model.dart';

/// Dialog detalhado que lista arquivos de sincronizacao.
///
/// Cada arquivo e exibido como uma linha com nome + estado visual
/// (pendente / sucesso / erro). O envio fica no card Dados.
class EnvioDetalhesWidget extends StatefulWidget {
  const EnvioDetalhesWidget({
    super.key,
    this.titulo = 'Status dos arquivos',
    this.descricao = 'Acompanhe arquivos em espera, enviados e com falha.',
    this.padraoArquivo = '*',
  });

  final String? titulo;
  final String? descricao;
  final String? padraoArquivo;

  @override
  State<EnvioDetalhesWidget> createState() => _EnvioDetalhesWidgetState();
}

class _EnvioDetalhesWidgetState extends State<EnvioDetalhesWidget> {
  late EnvioDetalhesModel _model;

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => EnvioDetalhesModel());
    // Lista pendentes ja na inicializacao para feedback imediato.
    _model.arquivos = [];
    _model.enviando = false;
    unawaited(_carregarPendentes());
  }

  Future<void> _carregarPendentes() async {
    final itens = await actions.listarArquivosPendentes(widget.padraoArquivo!);
    safeSetState(() {
      _model.arquivos = itens;
      _model.resultado = null;
    });
  }

  @override
  void dispose() {
    _model.maybeDispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    context.watch<AppState>();
    final arquivosFiltrados = _arquivosFiltrados;

    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(16.0, 0.0, 16.0, 0.0),
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(maxHeight: 520.0),
        decoration: BoxDecoration(
          color: AppTheme.of(context).secondaryBackground,
          boxShadow: const [
            BoxShadow(
              blurRadius: 4.0,
              color: Color(0x33000000),
              offset: Offset(0.0, 2.0),
            )
          ],
          borderRadius: BorderRadius.circular(8.0),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Cabecalho (titulo + fechar).
              Row(
                mainAxisSize: MainAxisSize.max,
                children: [
                  Icon(
                    Icons.upload_file,
                    color: AppTheme.of(context).primary,
                    size: 24.0,
                  ),
                  Expanded(
                    child: Text(
                      widget.titulo!,
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
                    icon: const Icon(
                      Icons.close_rounded,
                      color: Color(0xFF14181B),
                      size: 18.0,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                ].divide(const SizedBox(width: 8.0)),
              ),
              // Descricao.
              Align(
                alignment: const AlignmentDirectional(-1.0, 0.0),
                child: Padding(
                  padding:
                      const EdgeInsetsDirectional.fromSTEB(0.0, 0.0, 0.0, 8.0),
                  child: Text(
                    widget.descricao!,
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
              ),
              // Barra de progresso global (visivel durante envio).
              if (AppState().imgSyncStatus == 'baixando' || _model.enviando)
                Padding(
                  padding:
                      const EdgeInsetsDirectional.fromSTEB(0.0, 0.0, 0.0, 8.0),
                  child: LinearPercentIndicator(
                    percent: AppState().imgSyncProgress,
                    lineHeight: 18.0,
                    animation: true,
                    animateFromLastPercent: true,
                    progressColor: AppTheme.of(context).primary,
                    backgroundColor: AppTheme.of(context).accent4,
                    center: Text(
                      AppState().imgSyncText,
                      style: AppTheme.of(context).bodySmall.override(
                            font: GoogleFonts.inter(
                              fontWeight:
                                  AppTheme.of(context).bodySmall.fontWeight,
                              fontStyle:
                                  AppTheme.of(context).bodySmall.fontStyle,
                            ),
                            fontSize: 10.0,
                            letterSpacing: 0.0,
                            fontWeight:
                                AppTheme.of(context).bodySmall.fontWeight,
                            fontStyle: AppTheme.of(context).bodySmall.fontStyle,
                          ),
                    ),
                    barRadius: const Radius.circular(8.0),
                    padding: EdgeInsets.zero,
                  ),
                ),
              Padding(
                padding:
                    const EdgeInsetsDirectional.fromSTEB(0.0, 0.0, 0.0, 8.0),
                child: Wrap(
                  spacing: 6.0,
                  runSpacing: 6.0,
                  children: [
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
                    _FiltroStatusChip(
                      label: 'Todos',
                      selected: _model.filtroStatus == 'todos',
                      onSelected: () =>
                          safeSetState(() => _model.filtroStatus = 'todos'),
                    ),
                  ],
                ),
              ),
              // Lista de arquivos pendentes com estado visual por item.
              Flexible(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 280.0),
                  child: arquivosFiltrados.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Text(
                              _model.enviando
                                  ? 'Preparando lista...'
                                  : 'Nenhum arquivo para este status.',
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
                          ),
                        )
                      : ListView.separated(
                          padding: EdgeInsets.zero,
                          shrinkWrap: true,
                          itemCount: arquivosFiltrados.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 6.0),
                          itemBuilder: (context, i) {
                            final item = arquivosFiltrados[i];
                            final enviando = _model.enviando &&
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
            ],
          ),
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

/// Linha individual de arquivo dentro do dialog. Mostra nome + estado
/// visual animado (pendente -> enviando -> sucesso/erro).
class _LinhaArquivo extends StatelessWidget {
  const _LinhaArquivo({required this.item, required this.enviando});

  final ItemUploadStruct item;
  final bool enviando;

  @override
  Widget build(BuildContext context) {
    // Estado visual: pendente / enviando / sucesso / erro.
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
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            transitionBuilder: (child, anim) =>
                ScaleTransition(scale: anim, child: child),
            child: ColorFiltered(
              colorFilter: ColorFilter.mode(stateColor, BlendMode.srcIn),
              child: leading,
            ).animate().fade(
                  duration: const Duration(milliseconds: 250),
                ),
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
                          fontStyle: AppTheme.of(context).bodyMedium.fontStyle,
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
                          fontWeight: AppTheme.of(context).bodySmall.fontWeight,
                          fontStyle: AppTheme.of(context).bodySmall.fontStyle,
                        ),
                        color: stateColor,
                        fontSize: 11.0,
                        letterSpacing: 0.0,
                        fontWeight: AppTheme.of(context).bodySmall.fontWeight,
                        fontStyle: AppTheme.of(context).bodySmall.fontStyle,
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
                    fontWeight: AppTheme.of(context).bodySmall.fontWeight,
                    fontStyle: AppTheme.of(context).bodySmall.fontStyle,
                  ),
            ),
        ],
      ),
    ).animate().fade(duration: const Duration(milliseconds: 200));
  }
}
