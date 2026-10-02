import '/components/classification_row2/classification_row2_widget.dart';
import '/components/inventory_stat2/inventory_stat2_widget.dart';
import '/core/app_icon_button.dart';
import '/core/app_theme.dart';
import '/core/app_util.dart';
import '/action_code/index.dart' as actions;
import '/core/app_functions.dart' as functions;
import '/widgets/index.dart' as custom_widgets;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:google_fonts/google_fonts.dart';
import 'detalhe_produto_page_model.dart';
export 'detalhe_produto_page_model.dart';

class DetalheProdutoPageWidget extends StatefulWidget {
  const DetalheProdutoPageWidget({
    super.key,
    required this.produtoRef,
    this.planoCodigo,
    this.tabelaPreco,
    this.precoInicial,
  });

  final String? produtoRef;
  final String? planoCodigo;
  final String? tabelaPreco;
  final double? precoInicial;

  static String routeName = 'DetalheProdutoPage';
  static String routePath = '/detalheProdutoPage';

  @override
  State<DetalheProdutoPageWidget> createState() =>
      _DetalheProdutoPageWidgetState();
}

class _DetalheProdutoPageWidgetState extends State<DetalheProdutoPageWidget> {
  late DetalheProdutoPageModel _model;
  bool _carregando = true;

  final scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => DetalheProdutoPageModel());

    final int? codPlano = int.tryParse(widget.planoCodigo ?? '') ??
        (AppState().planoAtivo > 0 ? AppState().planoAtivo : null);
    final int? codTabela = int.tryParse(widget.tabelaPreco ?? '') ??
        (AppState().tabelaPrecoAtiva > 0 ? AppState().tabelaPrecoAtiva : null);

    // On page load action.
    SchedulerBinding.instance.addPostFrameCallback((_) async {
      try {
        _model.resultadoBanco = await actions.carregarProdutoDetalhe(
          widget.produtoRef,
          codPlano,
          codTabela,
        );
        _model.produtoResult = _model.resultadoBanco;

        if (_model.produtoResult != null &&
            (_model.produtoResult!.preco <= 0) &&
            widget.precoInicial != null &&
            widget.precoInicial! > 0) {
          _model.produtoResult!.preco = widget.precoInicial!;
          _model.produtoResult!.pcomax = widget.precoInicial!;
          _model.produtoResult!.pcomin = widget.precoInicial!;
        }
      } catch (e) {
        debugPrint('Erro ao carregar detalhes do produto: $e');
      } finally {
        _carregando = false;
        if (mounted) safeSetState(() {});
      }
    });
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
            icon: const Icon(
              Icons.arrow_back_rounded,
              color: Colors.white,
              size: 30.0,
            ),
            onPressed: () async {
              context.pop();
            },
          ),
          title: Text(
            'Informações do Produto',
            style: AppTheme.of(context).headlineMedium.override(
                  font: GoogleFonts.plusJakartaSans(
                    fontWeight:
                        AppTheme.of(context).headlineMedium.fontWeight,
                    fontStyle:
                        AppTheme.of(context).headlineMedium.fontStyle,
                  ),
                  color: Colors.white,
                  fontSize: 22.0,
                  letterSpacing: 0.0,
                  fontWeight:
                      AppTheme.of(context).headlineMedium.fontWeight,
                  fontStyle:
                      AppTheme.of(context).headlineMedium.fontStyle,
                ),
          ),
          actions: const [],
          centerTitle: true,
          elevation: 2.0,
        ),
        body: _carregando
            ? Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(
                    AppTheme.of(context).primary,
                  ),
                ),
              )
            : (_model.produtoResult == null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.info_outline_rounded,
                            size: 48.0,
                            color: AppTheme.of(context).secondaryText,
                          ),
                          const SizedBox(height: 12.0),
                          Text(
                            'Produto não localizado',
                            style: AppTheme.of(context).titleMedium,
                          ),
                          const SizedBox(height: 8.0),
                          Text(
                            'Não foi possível carregar as informações deste produto no banco de dados local.',
                            textAlign: TextAlign.center,
                            style: AppTheme.of(context).bodyMedium.override(
                                  color: AppTheme.of(context).secondaryText,
                                ),
                          ),
                        ],
                      ),
                    ),
                  )
                : Column(
                    mainAxisSize: MainAxisSize.max,
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
            Expanded(
              flex: 1,
              child: SafeArea(
                top: false,
                child: SingleChildScrollView(
                  primary: false,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 24.0),
                        child: Container(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.start,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  color: AppTheme.of(context)
                                      .secondaryBackground,
                                  borderRadius: BorderRadius.circular(16.0),
                                  shape: BoxShape.rectangle,
                                  border: Border.all(
                                    color:
                                        AppTheme.of(context).alternate,
                                    width: 1.0,
                                  ),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Container(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      mainAxisAlignment:
                                          MainAxisAlignment.start,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      children: [
                                        Container(
                                          width: double.infinity,
                                          height: 140.0,
                                          decoration: const BoxDecoration(),
                                          child: Align(
                                            alignment:
                                                const AlignmentDirectional(0.0, 0.0),
                                            child: Builder(
                                              builder: (context) {
                                                final listaDeImagens = _model
                                                        .resultadoBanco
                                                        ?.fotosProduto
                                                        .map((e) => e)
                                                        .toList()
                                                        .toList() ??
                                                    [];

                                                return ListView.separated(
                                                  padding: EdgeInsets.zero,
                                                  shrinkWrap: true,
                                                  scrollDirection:
                                                      Axis.horizontal,
                                                  itemCount:
                                                      listaDeImagens.length,
                                                  separatorBuilder: (_, __) =>
                                                      const SizedBox(width: 16.0),
                                                  itemBuilder: (context,
                                                      listaDeImagensIndex) {
                                                    final listaDeImagensItem =
                                                        listaDeImagens[
                                                            listaDeImagensIndex];
                                                    return SizedBox(
                                                      width: 140.0,
                                                      height: 140.0,
                                                      child: custom_widgets
                                                          .ImagemLocalWidget(
                                                        width: 140.0,
                                                        height: 140.0,
                                                        caminhoArquivo:
                                                            listaDeImagensItem,
                                                        titulo: _model
                                                            .produtoResult
                                                            ?.descricao,
                                                        subtitulo:
                                                            'Cód: ${_model.produtoResult?.codigo} • ${(_model.produtoResult?.preco ?? 0.0).toMoeda()}',
                                                      ),
                                                    );
                                                  },
                                                );
                                              },
                                            ),
                                          ),
                                        ),
                                        Text(
                                          valueOrDefault<String>(
                                            _model.produtoResult?.codigo,
                                            '#00000',
                                          ),
                                          style: AppTheme.of(context)
                                              .labelMedium
                                              .override(
                                                font: GoogleFonts.inter(
                                                  fontWeight:
                                                      AppTheme.of(
                                                              context)
                                                          .labelMedium
                                                          .fontWeight,
                                                  fontStyle:
                                                      AppTheme.of(
                                                              context)
                                                          .labelMedium
                                                          .fontStyle,
                                                ),
                                                color:
                                                    AppTheme.of(context)
                                                        .secondaryText,
                                                letterSpacing: 0.0,
                                                fontWeight:
                                                    AppTheme.of(context)
                                                        .labelMedium
                                                        .fontWeight,
                                                fontStyle:
                                                    AppTheme.of(context)
                                                        .labelMedium
                                                        .fontStyle,
                                                lineHeight: 1.2,
                                              ),
                                        ),
                                        Text(
                                          valueOrDefault<String>(
                                            _model.produtoResult?.descricao,
                                            'Descrição',
                                          ),
                                          textAlign: TextAlign.center,
                                          style: AppTheme.of(context)
                                              .titleLarge
                                              .override(
                                                font:
                                                    GoogleFonts.plusJakartaSans(
                                                  fontWeight:
                                                      AppTheme.of(
                                                              context)
                                                          .titleLarge
                                                          .fontWeight,
                                                  fontStyle:
                                                      AppTheme.of(
                                                              context)
                                                          .titleLarge
                                                          .fontStyle,
                                                ),
                                                color:
                                                    AppTheme.of(context)
                                                        .primaryText,
                                                letterSpacing: 0.0,
                                                fontWeight:
                                                    AppTheme.of(context)
                                                        .titleLarge
                                                        .fontWeight,
                                                fontStyle:
                                                    AppTheme.of(context)
                                                        .titleLarge
                                                        .fontStyle,
                                                lineHeight: 1.3,
                                              ),
                                        ),
                                        Row(
                                          mainAxisSize: MainAxisSize.max,
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.center,
                                          children: [
                                            Container(
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFF1F3F9),
                                                borderRadius:
                                                    BorderRadius.circular(8.0),
                                                shape: BoxShape.rectangle,
                                              ),
                                              child: Padding(
                                                padding: const EdgeInsetsDirectional
                                                    .fromSTEB(
                                                        16.0, 8.0, 16.0, 8.0),
                                                child: Container(
                                                  child: Column(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    mainAxisAlignment:
                                                        MainAxisAlignment.start,
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .center,
                                                    children: [
                                                      Text(
                                                        'Unidade',
                                                        style:
                                                            AppTheme.of(
                                                                    context)
                                                                .labelSmall
                                                                .override(
                                                                  font:
                                                                      GoogleFonts
                                                                          .inter(
                                                                    fontWeight: AppTheme.of(
                                                                            context)
                                                                        .labelSmall
                                                                        .fontWeight,
                                                                    fontStyle: AppTheme.of(
                                                                            context)
                                                                        .labelSmall
                                                                        .fontStyle,
                                                                  ),
                                                                  color: AppTheme.of(
                                                                          context)
                                                                      .secondaryText,
                                                                  letterSpacing:
                                                                      0.0,
                                                                  fontWeight: AppTheme.of(
                                                                          context)
                                                                      .labelSmall
                                                                      .fontWeight,
                                                                  fontStyle: AppTheme.of(
                                                                          context)
                                                                      .labelSmall
                                                                      .fontStyle,
                                                                  lineHeight:
                                                                      1.2,
                                                                ),
                                                      ),
                                                      Text(
                                                        valueOrDefault<String>(
                                                          _model.produtoResult
                                                              ?.unidade,
                                                          'UN',
                                                        ),
                                                        style:
                                                            AppTheme.of(
                                                                    context)
                                                                .labelLarge
                                                                .override(
                                                                  font:
                                                                      GoogleFonts
                                                                          .inter(
                                                                    fontWeight: AppTheme.of(
                                                                            context)
                                                                        .labelLarge
                                                                        .fontWeight,
                                                                    fontStyle: AppTheme.of(
                                                                            context)
                                                                        .labelLarge
                                                                        .fontStyle,
                                                                  ),
                                                                  color: AppTheme.of(
                                                                          context)
                                                                      .primaryText,
                                                                  letterSpacing:
                                                                      0.0,
                                                                  fontWeight: AppTheme.of(
                                                                          context)
                                                                      .labelLarge
                                                                      .fontWeight,
                                                                  fontStyle: AppTheme.of(
                                                                          context)
                                                                      .labelLarge
                                                                      .fontStyle,
                                                                  lineHeight:
                                                                      1.2,
                                                                ),
                                                      ),
                                                    ].divide(
                                                        const SizedBox(height: 4.0)),
                                                  ),
                                                ),
                                              ),
                                            ),
                                            Container(
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFF1F3F9),
                                                borderRadius:
                                                    BorderRadius.circular(8.0),
                                                shape: BoxShape.rectangle,
                                              ),
                                              child: Padding(
                                                padding: const EdgeInsetsDirectional
                                                    .fromSTEB(
                                                        16.0, 8.0, 16.0, 8.0),
                                                child: Container(
                                                  child: Column(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    mainAxisAlignment:
                                                        MainAxisAlignment.start,
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .center,
                                                    children: [
                                                      Text(
                                                        'Cód. Barras',
                                                        style:
                                                            AppTheme.of(
                                                                    context)
                                                                .labelSmall
                                                                .override(
                                                                  font:
                                                                      GoogleFonts
                                                                          .inter(
                                                                    fontWeight: AppTheme.of(
                                                                            context)
                                                                        .labelSmall
                                                                        .fontWeight,
                                                                    fontStyle: AppTheme.of(
                                                                            context)
                                                                        .labelSmall
                                                                        .fontStyle,
                                                                  ),
                                                                  color: AppTheme.of(
                                                                          context)
                                                                      .secondaryText,
                                                                  letterSpacing:
                                                                      0.0,
                                                                  fontWeight: AppTheme.of(
                                                                          context)
                                                                      .labelSmall
                                                                      .fontWeight,
                                                                  fontStyle: AppTheme.of(
                                                                          context)
                                                                      .labelSmall
                                                                      .fontStyle,
                                                                  lineHeight:
                                                                      1.2,
                                                                ),
                                                      ),
                                                      Text(
                                                        valueOrDefault<String>(
                                                          _model.produtoResult
                                                              ?.codbar,
                                                          '#0000',
                                                        ),
                                                        style:
                                                            AppTheme.of(
                                                                    context)
                                                                .labelLarge
                                                                .override(
                                                                  font:
                                                                      GoogleFonts
                                                                          .inter(
                                                                    fontWeight: AppTheme.of(
                                                                            context)
                                                                        .labelLarge
                                                                        .fontWeight,
                                                                    fontStyle: AppTheme.of(
                                                                            context)
                                                                        .labelLarge
                                                                        .fontStyle,
                                                                  ),
                                                                  color: AppTheme.of(
                                                                          context)
                                                                      .primaryText,
                                                                  letterSpacing:
                                                                      0.0,
                                                                  fontWeight: AppTheme.of(
                                                                          context)
                                                                      .labelLarge
                                                                      .fontWeight,
                                                                  fontStyle: AppTheme.of(
                                                                          context)
                                                                      .labelLarge
                                                                      .fontStyle,
                                                                  lineHeight:
                                                                      1.2,
                                                                ),
                                                      ),
                                                    ].divide(
                                                        const SizedBox(height: 4.0)),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ].divide(const SizedBox(width: 16.0)),
                                        ),
                                      ].divide(const SizedBox(height: 16.0)),
                                    ),
                                  ),
                                ),
                              ),
                              Container(
                                decoration: BoxDecoration(
                                  color: AppTheme.of(context)
                                      .secondaryBackground,
                                  borderRadius: BorderRadius.circular(16.0),
                                  shape: BoxShape.rectangle,
                                  border: Border.all(
                                    color:
                                        AppTheme.of(context).alternate,
                                    width: 1.0,
                                  ),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Container(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      mainAxisAlignment:
                                          MainAxisAlignment.start,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        Row(
                                          mainAxisSize: MainAxisSize.max,
                                          mainAxisAlignment:
                                              MainAxisAlignment.start,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.inventory_2_rounded,
                                              color:
                                                  AppTheme.of(context)
                                                      .primary,
                                              size: 20.0,
                                            ),
                                            Text(
                                              'Estoque',
                                              style:
                                                  AppTheme.of(context)
                                                      .titleMedium
                                                      .override(
                                                        font: GoogleFonts
                                                            .plusJakartaSans(
                                                          fontWeight:
                                                              AppTheme.of(
                                                                      context)
                                                                  .titleMedium
                                                                  .fontWeight,
                                                          fontStyle:
                                                              AppTheme.of(
                                                                      context)
                                                                  .titleMedium
                                                                  .fontStyle,
                                                        ),
                                                        color:
                                                            AppTheme.of(
                                                                    context)
                                                                .primaryText,
                                                        letterSpacing: 0.0,
                                                        fontWeight:
                                                            AppTheme.of(
                                                                    context)
                                                                .titleMedium
                                                                .fontWeight,
                                                        fontStyle:
                                                            AppTheme.of(
                                                                    context)
                                                                .titleMedium
                                                                .fontStyle,
                                                        lineHeight: 1.4,
                                                      ),
                                            ),
                                          ].divide(const SizedBox(width: 8.0)),
                                        ),
                                        Row(
                                          mainAxisSize: MainAxisSize.max,
                                          mainAxisAlignment:
                                              MainAxisAlignment.start,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.center,
                                          children: [
                                            Expanded(
                                              flex: 1,
                                              child: wrapWithModel(
                                                model:
                                                    _model.inventoryStatModel1,
                                                updateCallback: () =>
                                                    safeSetState(() {}),
                                                child: InventoryStat2Widget(
                                                  bgTint: const Color(0x1A00C2FF),
                                                  label: 'Atual',
                                                  textColor:
                                                      AppTheme.of(context)
                                                          .primaryText,
                                                  value: valueOrDefault<String>(
                                                    functions.formatQuantity(
                                                      _model.produtoResult?.estoqueAtual,
                                                      unidade: _model.produtoResult?.unidade,
                                                    ),
                                                    '0',
                                                  ),
                                                  bg: const Color(0x1A10B981),
                                                  color: AppTheme.of(
                                                          context)
                                                      .success,
                                                ),
                                              ),
                                            ),
                                            Expanded(
                                              flex: 1,
                                              child: wrapWithModel(
                                                model:
                                                    _model.inventoryStatModel2,
                                                updateCallback: () =>
                                                    safeSetState(() {}),
                                                child: InventoryStat2Widget(
                                                  bgTint: const Color(0x1A00C2FF),
                                                  label: 'Pendente',
                                                  textColor:
                                                      AppTheme.of(
                                                              context)
                                                          .primaryText,
                                                  value: valueOrDefault<String>(
                                                    functions.formatQuantity(
                                                      _model.produtoResult?.estoquePendente,
                                                      unidade: _model.produtoResult?.unidade,
                                                    ),
                                                    '0',
                                                  ),
                                                  bg: const Color(0x1A10B981),
                                                  color: AppTheme.of(
                                                          context)
                                                      .success,
                                                ),
                                              ),
                                            ),
                                            Expanded(
                                              flex: 1,
                                              child: wrapWithModel(
                                                model:
                                                    _model.inventoryStatModel3,
                                                updateCallback: () =>
                                                    safeSetState(() {}),
                                                child: InventoryStat2Widget(
                                                  bgTint: const Color(0x1A00C2FF),
                                                  label: 'Disponível',
                                                  textColor:
                                                      AppTheme.of(
                                                              context)
                                                          .success,
                                                  value: valueOrDefault<String>(
                                                    functions.formatQuantity(
                                                      _model.produtoResult?.saldoEstoque,
                                                      unidade: _model.produtoResult?.unidade,
                                                    ),
                                                    '0',
                                                  ),
                                                  bg: const Color(0x1A10B981),
                                                  color: AppTheme.of(
                                                          context)
                                                      .success,
                                                ),
                                              ),
                                            ),
                                          ].divide(const SizedBox(width: 8.0)),
                                        ),
                                      ].divide(const SizedBox(height: 16.0)),
                                    ),
                                  ),
                                ),
                              ),
                              Container(
                                decoration: BoxDecoration(
                                  color: AppTheme.of(context)
                                      .secondaryBackground,
                                  borderRadius: BorderRadius.circular(16.0),
                                  shape: BoxShape.rectangle,
                                  border: Border.all(
                                    color:
                                        AppTheme.of(context).alternate,
                                    width: 1.0,
                                  ),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Container(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      mainAxisAlignment:
                                          MainAxisAlignment.start,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        Row(
                                          mainAxisSize: MainAxisSize.max,
                                          mainAxisAlignment:
                                              MainAxisAlignment.start,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.payments_rounded,
                                              color:
                                                  AppTheme.of(context)
                                                      .primary,
                                              size: 20.0,
                                            ),
                                            Text(
                                              'Preço',
                                              style:
                                                  AppTheme.of(context)
                                                      .titleMedium
                                                      .override(
                                                        font: GoogleFonts
                                                            .plusJakartaSans(
                                                          fontWeight:
                                                              AppTheme.of(
                                                                      context)
                                                                  .titleMedium
                                                                  .fontWeight,
                                                          fontStyle:
                                                              AppTheme.of(
                                                                      context)
                                                                  .titleMedium
                                                                  .fontStyle,
                                                        ),
                                                        color:
                                                            AppTheme.of(
                                                                    context)
                                                                .primaryText,
                                                        letterSpacing: 0.0,
                                                        fontWeight:
                                                            AppTheme.of(
                                                                    context)
                                                                .titleMedium
                                                                .fontWeight,
                                                        fontStyle:
                                                            AppTheme.of(
                                                                    context)
                                                                .titleMedium
                                                                .fontStyle,
                                                        lineHeight: 1.4,
                                                      ),
                                            ),
                                          ].divide(const SizedBox(width: 8.0)),
                                        ),
                                        Row(
                                          mainAxisSize: MainAxisSize.max,
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.center,
                                          children: [
                                            Text(
                                              'Tabela padrão',
                                              style:
                                                  AppTheme.of(context)
                                                      .bodyMedium
                                                      .override(
                                                        font: GoogleFonts.inter(
                                                          fontWeight:
                                                              AppTheme.of(
                                                                      context)
                                                                  .bodyMedium
                                                                  .fontWeight,
                                                          fontStyle:
                                                              AppTheme.of(
                                                                      context)
                                                                  .bodyMedium
                                                                  .fontStyle,
                                                        ),
                                                        color:
                                                            AppTheme.of(
                                                                    context)
                                                                .secondaryText,
                                                        letterSpacing: 0.0,
                                                        fontWeight:
                                                            AppTheme.of(
                                                                    context)
                                                                .bodyMedium
                                                                .fontWeight,
                                                        fontStyle:
                                                            AppTheme.of(
                                                                    context)
                                                                .bodyMedium
                                                                .fontStyle,
                                                        lineHeight: 1.5,
                                                      ),
                                            ),
                                            Text(
                                              ((_model.produtoResult?.preco ?? 0.0) > 0)
                                                  ? (_model.produtoResult!.preco).toMoeda()
                                                  : 'Sob Consulta',
                                              style: AppTheme.of(
                                                      context)
                                                  .headlineSmall
                                                  .override(
                                                    font: GoogleFonts
                                                        .plusJakartaSans(
                                                      fontWeight:
                                                          FontWeight.w800,
                                                      fontStyle:
                                                          AppTheme.of(
                                                                  context)
                                                              .headlineSmall
                                                              .fontStyle,
                                                    ),
                                                    color: ((_model.produtoResult?.preco ?? 0) > 0)
                                                        ? const Color(0xFF2E7D32)
                                                        : AppTheme.of(context).secondaryText,
                                                    letterSpacing: 0.0,
                                                    fontWeight: FontWeight.w800,
                                                    fontStyle:
                                                        AppTheme.of(
                                                                context)
                                                            .headlineSmall
                                                            .fontStyle,
                                                    lineHeight: 1.3,
                                                  ),
                                            ),
                                          ],
                                        ),
                                      ].divide(const SizedBox(height: 16.0)),
                                    ),
                                  ),
                                ),
                              ),
                              Container(
                                decoration: BoxDecoration(
                                  color: AppTheme.of(context)
                                      .secondaryBackground,
                                  borderRadius: BorderRadius.circular(16.0),
                                  shape: BoxShape.rectangle,
                                  border: Border.all(
                                    color:
                                        AppTheme.of(context).alternate,
                                    width: 1.0,
                                  ),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Container(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      mainAxisAlignment:
                                          MainAxisAlignment.start,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        Row(
                                          mainAxisSize: MainAxisSize.max,
                                          mainAxisAlignment:
                                              MainAxisAlignment.start,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.layers_rounded,
                                              color:
                                                  AppTheme.of(context)
                                                      .primary,
                                              size: 20.0,
                                            ),
                                            Text(
                                              'Classificação',
                                              style:
                                                  AppTheme.of(context)
                                                      .titleMedium
                                                      .override(
                                                        font: GoogleFonts
                                                            .plusJakartaSans(
                                                          fontWeight:
                                                              AppTheme.of(
                                                                      context)
                                                                  .titleMedium
                                                                  .fontWeight,
                                                          fontStyle:
                                                              AppTheme.of(
                                                                      context)
                                                                  .titleMedium
                                                                  .fontStyle,
                                                        ),
                                                        color:
                                                            AppTheme.of(
                                                                    context)
                                                                .primaryText,
                                                        letterSpacing: 0.0,
                                                        fontWeight:
                                                            AppTheme.of(
                                                                    context)
                                                                .titleMedium
                                                                .fontWeight,
                                                        fontStyle:
                                                            AppTheme.of(
                                                                    context)
                                                                .titleMedium
                                                                .fontStyle,
                                                        lineHeight: 1.4,
                                                      ),
                                            ),
                                          ].divide(const SizedBox(width: 8.0)),
                                        ),
                                        Column(
                                          mainAxisSize: MainAxisSize.min,
                                          mainAxisAlignment:
                                              MainAxisAlignment.start,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.stretch,
                                          children: [
                                            wrapWithModel(
                                              model: _model
                                                  .classificationRowModel1,
                                              updateCallback: () =>
                                                  safeSetState(() {}),
                                              child: ClassificationRow2Widget(
                                                label: 'Linha',
                                                value: valueOrDefault<String>(
                                                  _model.produtoResult?.linha,
                                                  'Linha',
                                                ),
                                              ),
                                            ),
                                            wrapWithModel(
                                              model: _model
                                                  .classificationRowModel2,
                                              updateCallback: () =>
                                                  safeSetState(() {}),
                                              child: ClassificationRow2Widget(
                                                label: 'Grupo',
                                                value: valueOrDefault<String>(
                                                  _model.produtoResult?.grupo,
                                                  'Grupo',
                                                ),
                                              ),
                                            ),
                                            wrapWithModel(
                                              model: _model
                                                  .classificationRowModel3,
                                              updateCallback: () =>
                                                  safeSetState(() {}),
                                              child: ClassificationRow2Widget(
                                                label: 'Fabricante',
                                                value: valueOrDefault<String>(
                                                  _model.produtoResult
                                                      ?.fabricante,
                                                  'Fabricante',
                                                ),
                                              ),
                                            ),
                                            wrapWithModel(
                                              model: _model
                                                  .classificationRowModel4,
                                              updateCallback: () =>
                                                  safeSetState(() {}),
                                              child: ClassificationRow2Widget(
                                                label: 'Marca',
                                                value: valueOrDefault<String>(
                                                  _model.produtoResult?.marca,
                                                  'Marca',
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ].divide(const SizedBox(height: 16.0)),
                                    ),
                                  ),
                                ),
                              ),
                            ].divide(const SizedBox(height: 16.0)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        )),
      ),
    );
  }
}
