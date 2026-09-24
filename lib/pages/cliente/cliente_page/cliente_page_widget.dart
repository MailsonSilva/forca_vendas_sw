import '/backend/schema/structs/index.dart';
import '/components/loading/loading_widget.dart';
import '/core/app_icon_button.dart';
import '/core/app_theme.dart';
import '/core/app_util.dart';
import '/action_code/index.dart' as actions;
import '/index.dart';
import 'package:easy_debounce/easy_debounce.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:google_fonts/google_fonts.dart';
import 'cliente_page_model.dart';
export 'cliente_page_model.dart';

class ClientePageWidget extends StatefulWidget {
  const ClientePageWidget({super.key});

  static String routeName = 'ClientePage';
  static String routePath = '/clientePage';

  @override
  State<ClientePageWidget> createState() => _ClientePageWidgetState();
}

class _ClientePageWidgetState extends State<ClientePageWidget> {
  late ClientePageModel _model;
  final ScrollController _scrollController = ScrollController();
  bool _isLoadingMore = false;
  bool _hasMoreItems = true;

  final scaffoldKey = GlobalKey<ScaffoldState>();

  Future<void> _recarregarClientes() async {
    final termo = _model.buscaClienteFieldTextController?.text.trim() ?? '';
    final res = await actions.pesquisaCliente(termo, 0);
    safeSetState(() {
      _model.clientesIniciais = res;
      _model.clientesResultPage = res.toList().cast<ClienteResultStruct>();
      _hasMoreItems = false;
    });
  }

  Future<void> _carregarProximaPaginaClientes() async {
    if (_isLoadingMore || !_hasMoreItems) return;
    _isLoadingMore = true;
    safeSetState(() {});
    try {
      final termo = _model.buscaClienteFieldTextController?.text.trim() ?? '';
      final offset = _model.clientesResultPage.length;
      final novos = await actions.pesquisaCliente(termo, offset);
      if (novos.isEmpty || novos.length < 100) {
        _hasMoreItems = false;
      }
      _model.clientesResultPage.addAll(novos);
    } catch (_) {
      _hasMoreItems = false;
    } finally {
      _isLoadingMore = false;
      if (mounted) safeSetState(() {});
    }
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => ClientePageModel());

    _scrollController.addListener(() {
      if (_scrollController.hasClients &&
          _scrollController.position.pixels >=
              _scrollController.position.maxScrollExtent - 300) {
        if (!_isLoadingMore && _hasMoreItems) {
          _carregarProximaPaginaClientes();
        }
      }
    });

    // On page load action.
    SchedulerBinding.instance.addPostFrameCallback((_) async {
      await _recarregarClientes();
    });

    _model.buscaClienteFieldTextController ??= TextEditingController();
    _model.buscaClienteFieldFocusNode ??= FocusNode();
  }

  @override
  void dispose() {
    _scrollController.dispose();
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
          title: Row(
            mainAxisSize: MainAxisSize.max,
            children: [
              AppIconButton(
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
              Expanded(
                child: Text(
                  'Pesquisa de Clientes',
                  style: AppTheme.of(context).headlineMedium.override(
                        font: GoogleFonts.plusJakartaSans(
                          fontWeight: AppTheme.of(context)
                              .headlineMedium
                              .fontWeight,
                          fontStyle: AppTheme.of(context)
                              .headlineMedium
                              .fontStyle,
                        ),
                        color: Colors.white,
                        fontSize: 18.0,
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
              AppIconButton(
                borderColor: Colors.transparent,
                borderRadius: 30.0,
                borderWidth: 1.0,
                buttonSize: 60.0,
                icon: const Icon(
                  Icons.person_add_alt_1,
                  color: Colors.white,
                  size: 28.0,
                ),
                onPressed: () async {
                  await context.pushNamed(FormClientesPageWidget.routeName);
                  await _recarregarClientes();
                },
              ),
            ],
          ),
          actions: const [],
          centerTitle: true,
          elevation: 2.0,
        ),
        body: SafeArea(
          top: true,
          child: Column(
            mainAxisSize: MainAxisSize.max,
            children: [
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(0.0, 16.0, 0.0, 0.0),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppTheme.of(context).primaryBackground,
                  ),
                  child: Padding(
                    padding:
                        const EdgeInsetsDirectional.fromSTEB(16.0, 0.0, 16.0, 0.0),
                    child: TextFormField(
                      controller: _model.buscaClienteFieldTextController,
                      focusNode: _model.buscaClienteFieldFocusNode,
                      onChanged: (_) => EasyDebounce.debounce(
                        '_model.buscaClienteFieldTextController',
                        const Duration(milliseconds: 350),
                        () async {
                          _model.buscaCliente =
                              _model.buscaClienteFieldTextController.text;
                          safeSetState(() {});
                          _model.resultadoBusca = await actions.pesquisaCliente(
                            _model.buscaCliente,
                            0,
                          );
                          _model.clientesResultPage = _model.resultadoBusca!
                              .toList()
                              .cast<ClienteResultStruct>();
                          _hasMoreItems = false;
                          safeSetState(() {});
                        },
                      ),
                      textInputAction: TextInputAction.search,
                      obscureText: false,
                      decoration: InputDecoration(
                        labelText: 'Cliente',
                        labelStyle: AppTheme.of(context).bodyMedium.override(
                              color: AppTheme.of(context).secondaryText,
                            ),
                        hintText: 'Busque por código ou descrição...',
                        hintStyle: AppTheme.of(context).bodyMedium.override(
                              color: AppTheme.of(context).secondaryText,
                            ),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                            color: AppTheme.of(context).alternate,
                            width: 1.0,
                          ),
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                            color: AppTheme.of(context).primary,
                            width: 2.0,
                          ),
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                        errorBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                            color: AppTheme.of(context).error,
                            width: 1.0,
                          ),
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                        focusedErrorBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                            color: AppTheme.of(context).error,
                            width: 2.0,
                          ),
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                        filled: true,
                        fillColor: AppTheme.of(context).secondaryBackground,
                        prefixIcon: Icon(
                          Icons.search_rounded,
                          color: AppTheme.of(context).secondaryText,
                          size: 24.0,
                        ),
                        suffixIcon: _model.buscaClienteFieldTextController!.text
                                .isNotEmpty
                            ? InkWell(
                                onTap: () async {
                                  _model.buscaClienteFieldTextController
                                      ?.clear();
                                  _model.buscaCliente = _model
                                      .buscaClienteFieldTextController.text;
                                  safeSetState(() {});
                                  _model.resultadoBusca =
                                      await actions.pesquisaCliente(
                                    _model.buscaCliente,
                                    0,
                                  );
                                  _model.clientesResultPage = _model
                                      .resultadoBusca!
                                      .toList()
                                      .cast<ClienteResultStruct>();
                                  _hasMoreItems = false;
                                  safeSetState(() {});
                                },
                                child: Icon(
                                  Icons.clear_rounded,
                                  color: AppTheme.of(context).secondaryText,
                                  size: 20.0,
                                ),
                              )
                            : null,
                      ),
                      style: const TextStyle(),
                      maxLines: null,
                      validator: _model.buscaClienteFieldTextControllerValidator
                          .asValidator(context),
                    ),
                  ),
                ),
              ),
              Expanded(
                flex: 1,
                child: Builder(
                  builder: (context) {
                    if (_model.clientesResultPage.isNotEmpty) {
                      return Builder(
                        builder: (context) {
                          final listaCliente =
                              _model.clientesResultPage.toList();

                          return ListView.separated(
                            controller: _scrollController,
                            padding: const EdgeInsets.fromLTRB(
                              0,
                              0,
                              0,
                              16.0,
                            ),
                            primary: false,
                            shrinkWrap: false,
                            scrollDirection: Axis.vertical,
                            itemCount: listaCliente.length + (_isLoadingMore ? 1 : 0),
                            separatorBuilder: (_, __) => const SizedBox(height: 16.0),
                            itemBuilder: (context, listaClienteIndex) {
                              if (listaClienteIndex == listaCliente.length) {
                                return const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 16.0),
                                  child: Center(
                                    child: SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(strokeWidth: 2.0),
                                    ),
                                  ),
                                );
                              }
                              final listaClienteItem =
                                  listaCliente[listaClienteIndex];
                              return Padding(
                                padding: const EdgeInsetsDirectional.fromSTEB(
                                    16.0, 0.0, 16.0, 0.0),
                                child: Container(
                                  decoration: BoxDecoration(
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
                                    gradient: LinearGradient(
                                      colors: [
                                        valueOrDefault<Color>(
                                          listaClienteItem.corBorda,
                                          Colors.white,
                                        ),
                                        Colors.white
                                      ],
                                      stops: const [0.0, 0.04],
                                      begin: const AlignmentDirectional(-1.0, 0.0),
                                      end: const AlignmentDirectional(1.0, 0),
                                    ),
                                    borderRadius: BorderRadius.circular(8.0),
                                  ),
                                  child: InkWell(
                                    splashColor: Colors.transparent,
                                    focusColor: Colors.transparent,
                                    hoverColor: Colors.transparent,
                                    highlightColor: Colors.transparent,
                                    onTap: () async {
                                      await context.pushNamed(
                                        FormClientesPageWidget.routeName,
                                        queryParameters: {
                                          'clienteCodigo': serializeParam(
                                            listaClienteItem.cli00Codigo,
                                            ParamType.int,
                                          ),
                                        }.withoutNulls,
                                      );
                                      await _recarregarClientes();
                                    },
                                    child: Row(
                                      mainAxisSize: MainAxisSize.max,
                                      children: [
                                        Expanded(
                                          child: Padding(
                                            padding:
                                                const EdgeInsetsDirectional.fromSTEB(
                                                    16.0, 12.0, 0.0, 12.0),
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              mainAxisAlignment:
                                                  MainAxisAlignment.start,
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  valueOrDefault<String>(
                                                    listaClienteItem.cli00Codigo
                                                        .toString(),
                                                    '0000',
                                                  ),
                                                  maxLines: 1,
                                                  style: AppTheme.of(
                                                          context)
                                                      .bodyLarge
                                                      .override(
                                                        font: GoogleFonts.inter(
                                                          fontWeight:
                                                              FontWeight.w500,
                                                          fontStyle:
                                                              AppTheme.of(
                                                                      context)
                                                                  .bodyLarge
                                                                  .fontStyle,
                                                        ),
                                                        fontSize: 12.0,
                                                        letterSpacing: 0.0,
                                                        fontWeight:
                                                            FontWeight.w500,
                                                        fontStyle:
                                                            AppTheme.of(
                                                                    context)
                                                                .bodyLarge
                                                                .fontStyle,
                                                      ),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                                Text(
                                                  valueOrDefault<String>(
                                                    listaClienteItem
                                                        .cli00Descri,
                                                    'Descri',
                                                  ),
                                                  maxLines: 1,
                                                  style: AppTheme.of(
                                                          context)
                                                      .bodyLarge
                                                      .override(
                                                        font: GoogleFonts.inter(
                                                          fontWeight:
                                                              AppTheme.of(
                                                                      context)
                                                                  .bodyLarge
                                                                  .fontWeight,
                                                          fontStyle:
                                                              AppTheme.of(
                                                                      context)
                                                                  .bodyLarge
                                                                  .fontStyle,
                                                        ),
                                                        letterSpacing: 0.0,
                                                        fontWeight:
                                                            AppTheme.of(
                                                                    context)
                                                                .bodyLarge
                                                                .fontWeight,
                                                        fontStyle:
                                                            AppTheme.of(
                                                                    context)
                                                                .bodyLarge
                                                                .fontStyle,
                                                      ),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                                Row(
                                                  mainAxisSize:
                                                      MainAxisSize.max,
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.start,
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.center,
                                                  children: [
                                                    Expanded(
                                                      child: Text(
                                                        valueOrDefault<String>(
                                                          listaClienteItem
                                                              .cli00Fantas,
                                                          'Fantasia',
                                                        ),
                                                        maxLines: 1,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                        style: AppTheme.of(
                                                                context)
                                                            .bodySmall
                                                            .override(
                                                              font: GoogleFonts
                                                                  .inter(
                                                                fontWeight: AppTheme.of(
                                                                        context)
                                                                    .bodySmall
                                                                    .fontWeight,
                                                                fontStyle: AppTheme.of(
                                                                        context)
                                                                    .bodySmall
                                                                    .fontStyle,
                                                              ),
                                                              color: AppTheme.of(
                                                                      context)
                                                                  .secondaryText,
                                                              letterSpacing:
                                                                  0.0,
                                                              fontWeight: AppTheme.of(
                                                                      context)
                                                                  .bodySmall
                                                                  .fontWeight,
                                                              fontStyle: AppTheme.of(
                                                                      context)
                                                                  .bodySmall
                                                                  .fontStyle,
                                                            ),
                                                      ),
                                                    ),
                                                    Icon(
                                                      Icons.location_city,
                                                      color:
                                                          AppTheme.of(
                                                                  context)
                                                              .secondaryText,
                                                      size: 14.0,
                                                    ),
                                                    Text(
                                                      valueOrDefault<String>(
                                                        listaClienteItem
                                                            .cli00Estsgl,
                                                        'UF',
                                                      ),
                                                      maxLines: 1,
                                                      style:
                                                          AppTheme.of(
                                                                  context)
                                                              .bodySmall
                                                              .override(
                                                                font:
                                                                    GoogleFonts
                                                                        .inter(
                                                                  fontWeight: AppTheme.of(
                                                                          context)
                                                                      .bodySmall
                                                                      .fontWeight,
                                                                  fontStyle: AppTheme.of(
                                                                          context)
                                                                      .bodySmall
                                                                      .fontStyle,
                                                                ),
                                                                color: AppTheme.of(
                                                                        context)
                                                                    .secondaryText,
                                                                letterSpacing:
                                                                    0.0,
                                                                fontWeight: AppTheme.of(
                                                                        context)
                                                                    .bodySmall
                                                                    .fontWeight,
                                                                fontStyle: AppTheme.of(
                                                                        context)
                                                                    .bodySmall
                                                                    .fontStyle,
                                                              ),
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                  ].divide(
                                                      const SizedBox(width: 8.0)),
                                                ),
                                              ].divide(const SizedBox(height: 6.0)),
                                            ),
                                          ),
                                        ),
                                        Padding(
                                          padding:
                                              const EdgeInsetsDirectional.fromSTEB(
                                                  0.0, 0.0, 8.0, 0.0),
                                          child: Icon(
                                            Icons.chevron_right,
                                            color: AppTheme.of(context)
                                                .secondaryText,
                                            size: 24.0,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      );
                    } else {
                      return wrapWithModel(
                        model: _model.loadingModel,
                        updateCallback: () => safeSetState(() {}),
                        child: const LoadingWidget(),
                      );
                    }
                  },
                ),
              ),
            ].divide(const SizedBox(height: 16.0)).addToEnd(const SizedBox(height: 16.0)),
          ),
        ),
      ),
    );
  }
}
