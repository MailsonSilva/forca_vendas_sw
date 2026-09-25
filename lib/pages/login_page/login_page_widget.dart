import '/core/app_theme.dart';
import '/core/app_util.dart';
import '/core/app_widgets.dart';
import '/components/modal_selecao_filial/modal_selecao_filial_widget.dart';
import '/action_code/index.dart' as actions;
import '../../core/services/empresa_logo_service.dart';
import '/index.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '/services/filial_service.dart';
import '/data/services/local_sales_database_service.dart';
import '/data/repositories/sales_database_repository.dart';
import 'dart:async';
import 'login_page_model.dart';
export 'login_page_model.dart';

/// Tela de Login do Representante de Vendas offline.
class LoginPageWidget extends StatefulWidget {
  const LoginPageWidget({super.key});

  static String routeName = 'LoginPage';
  static String routePath = '/login';

  @override
  State<LoginPageWidget> createState() => _LoginPageWidgetState();
}

class _LoginPageWidgetState extends State<LoginPageWidget> {
  late LoginPageModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => LoginPageModel());

    // On page load action.
    SchedulerBinding.instance.addPostFrameCallback((_) async {
      AppState().codFilialAtiva = 0;
      AppState().filialAtivaDes = '';
      _model.dbExists = await actions.checkDatabaseExists();
      AppState().is_first_access = !_model.dbExists!;
      safeSetState(() {});
    });

    _model.empresaCodigoFieldTextController ??= TextEditingController();
    _model.empresaCodigoFieldFocusNode ??= FocusNode();

    _model.vendedorCodigoFieldTextController ??= TextEditingController();
    _model.vendedorCodigoFieldFocusNode ??= FocusNode();
  }

  @override
  void dispose() {
    _model.dispose();

    super.dispose();
  }

  Future<void> _processarFilialAposLogin() async {
    try {
      final db = await LocalSalesDatabaseService.getDatabase();
      int venSelfil = 0;
      int venCodfil = 1;

      try {
        final cols = await db.rawQuery('PRAGMA table_info(cadrep00)');
        final colNames = cols.map((r) => r['name']?.toString().toLowerCase()).toSet();
        final rows = await db.rawQuery(
          'SELECT * FROM cadrep00 WHERE ven00_codigo = ? LIMIT 1',
          [AppState().vendedor_codigo],
        );
        final row = rows.isNotEmpty
            ? rows.first
            : (await db.rawQuery('SELECT * FROM cadrep00 LIMIT 1')).firstOrNull;
        if (row != null) {
          if (colNames.contains('ven00_selfil') && row['ven00_selfil'] != null) {
            venSelfil = (row['ven00_selfil'] as num).toInt();
          }
          if (colNames.contains('ven00_codfil') && row['ven00_codfil'] != null) {
            venCodfil = (row['ven00_codfil'] as num).toInt();
          }
        }
      } catch (_) {}

      final filiaisEstoque = await FilialService.obterFiliaisDistintasEstoque(db);
      final decisao = avaliarRegraSelecaoFilial(
        venSelfil: venSelfil,
        venCodfil: venCodfil,
        filiaisEstoque: filiaisEstoque,
      );

      if (!mounted) return;

      if (!decisao.precisaAbrirModal) {
        final cod = decisao.filialDefinida ?? 1;
        AppState().codFilialAtiva = cod;
        AppState().filialAtivaDes = 'Filial $cod';
        try {
          final filList = await FilialService.obterFiliaisComDescricao(db, [cod.toString()]);
          if (filList.isNotEmpty) {
            AppState().filialAtivaDes = filList.first.descricao;
          }
        } catch (_) {}
        safeSetState(() {});
      } else {
        // Cenário 2 (Multi-Empresa): abre compulsoriamente ModalSelecaoFilialWidget
        final filiaisModal = await FilialService.obterFiliaisComDescricao(
          db,
          decisao.filiaisDisponiveis,
        );
        if (!mounted) return;
        final codEscolhido = await showAppModalBottomSheet<String>(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          isDismissible: false,
          enableDrag: false,
          builder: (ctx) => SafeArea(
            bottom: true,
            child: ModalSelecaoFilialWidget(filiais: filiaisModal),
          ),
        );
        if (codEscolhido != null && codEscolhido.isNotEmpty) {
          final cod = int.tryParse(codEscolhido) ?? 1;
          AppState().codFilialAtiva = cod;
          final f = filiaisModal.firstWhere(
            (x) => x.codigo == codEscolhido,
            orElse: () => filiaisModal.first,
          );
          AppState().filialAtivaDes = f.descricao;
          safeSetState(() {});
        }
      }
    } catch (_) {}
  }

  Future<void> _fazerLogin() async {
    AppState().is_loading = true;
    safeSetState(() {});
    if (AppState().is_first_access) {
      _model.firstAccessResult = await actions.firstAccessLogin(
        _model.empresaCodigoFieldTextController.text,
        _model.vendedorCodigoFieldTextController.text,
      );
      if (!mounted) return;
      if (_model.firstAccessResult!.success) {
        AppState().is_first_access = false;
        safeSetState(() {});
        _model.firstAccessLogin = await actions.offlineLogin(
          _model.vendedorCodigoFieldTextController.text,
        );
        if (!mounted) return;
        if (_model.firstAccessLogin!.success) {
          AppState().vendedor_codigo = _model.firstAccessLogin!.vendedorCodigo;
          safeSetState(() {});
          AppState().vendedor_nome = _model.firstAccessLogin!.vendedorNome;
          safeSetState(() {});
          AppState().vendedor_equipe = _model.firstAccessLogin!.vendedorEquipe;
          safeSetState(() {});
          final empTxt = _model.empresaCodigoFieldTextController.text.trim();
          if (empTxt.isNotEmpty) {
            AppState().empresa_codigo = empTxt;
            safeSetState(() {});
          }

          // SPEC-047 §1.1: Consulta filiais e processa seleção multi-filial antes de prosseguir
          await _processarFilialAposLogin();
          if (!mounted) return;

          AppState().is_loading = false;
          safeSetState(() {});

          context.pushNamed(HomePageWidget.routeName);
        } else {
          AppState().is_loading = false;
          safeSetState(() {});
          await showDialog(
            context: context,
            builder: (alertDialogContext) {
              return AlertDialog(
                title: const Text('Login nao validado'),
                content: const Text('Vendedor nao encontrado no banco local.'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(alertDialogContext),
                    child: const Text('OK'),
                  ),
                ],
              );
            },
          );
        }
      } else {
        AppState().is_loading = false;
        safeSetState(() {});
        await showDialog(
          context: context,
          builder: (alertDialogContext) {
            return AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.cloud_off_rounded, color: Colors.orange, size: 28),
                  SizedBox(width: 8),
                  Text('Carga Inicial'),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Não foi possível obter a carga inicial de dados. Verifique sua conexão com a internet ou entre em contato com a equipe de suporte técnico.',
                    style: TextStyle(fontSize: 14.0),
                  ),
                  const SizedBox(height: 16.0),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF25D366),
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 44.0),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                    ),
                    icon: const FaIcon(FontAwesomeIcons.whatsapp, size: 20.0),
                    label: const Text(
                      'Falar com o Suporte',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    onPressed: () async {
                      final uri = Uri.parse(
                        'https://wa.me/559881283380?text=Ol%C3%A1%2C%20ocorreu%20uma%20falha%20ao%20baixar%20a%20carga%20inicial%20no%20app',
                      );
                      try {
                        await launchUrl(uri, mode: LaunchMode.externalApplication);
                      } catch (_) {
                        try {
                          await launchUrl(uri);
                        } catch (_) {}
                      }
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(alertDialogContext),
                  child: const Text('OK'),
                ),
              ],
            );
          },
        );
      }

    } else {
      _model.offlineLogin = await actions.offlineLogin(
        _model.vendedorCodigoFieldTextController.text,
      );
      if (!mounted) return;
      if (_model.offlineLogin!.success) {
        AppState().vendedor_codigo = _model.offlineLogin!.vendedorCodigo;
        safeSetState(() {});
        AppState().vendedor_nome = _model.offlineLogin!.vendedorNome;
        safeSetState(() {});
        AppState().vendedor_equipe = _model.offlineLogin!.vendedorEquipe;
        safeSetState(() {});
        final empTxt = _model.empresaCodigoFieldTextController.text.trim();
        if (empTxt.isNotEmpty) {
          AppState().empresa_codigo = empTxt;
          safeSetState(() {});
        }

        // Sincroniza o nome da empresa a partir do arquivo /config/acesso do FTP caso esteja vazio
        if (AppState().empresaNome.trim().isEmpty && AppState().empresa_codigo.trim().isNotEmpty) {
          unawaited(SalesDatabaseRepository().sincronizarNomeEmpresaDoAcessoFtp(AppState().empresa_codigo));
        }

        // SPEC-047 §1.1: Consulta filiais e processa seleção multi-filial antes de prosseguir
        await _processarFilialAposLogin();
        if (!mounted) return;

        AppState().is_loading = false;
        safeSetState(() {});

        context.pushNamed(HomePageWidget.routeName);
      } else {
        AppState().is_loading = false;
        safeSetState(() {});
        await showDialog(
          context: context,
          builder: (alertDialogContext) {
            return AlertDialog(
              title: const Text('Login nao validado'),
              content: const Text('Vendedor nao encontrado no banco local.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(alertDialogContext),
                  child: const Text('OK'),
                ),
              ],
            );
          },
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    context.watch<AppState>();

    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
        FocusManager.instance.primaryFocus?.unfocus();
      },
      child: Scaffold(
        key: scaffoldKey,
        backgroundColor: AppTheme.of(context).primaryBackground,
        body: SafeArea(
          top: true,
          child: Stack(
            alignment: const AlignmentDirectional(0.0, 0.0),
            children: [
              Container(
                width: double.infinity,
                height: double.infinity,
                decoration: BoxDecoration(
                  color: AppTheme.of(context).primaryBackground,
                ),
                alignment: const AlignmentDirectional(0.0, 0.0),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.max,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 420.0),
                          child: Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: AppTheme.of(context).secondaryBackground,
                              borderRadius: BorderRadius.circular(16.0),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(24.0),
                              child: SingleChildScrollView(
                                primary: false,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Padding(
                                      padding:
                                          const EdgeInsetsDirectional.fromSTEB(
                                              0.0, 0.0, 0.0, 18.0),
                                      child: EmpresaLogoService.instance
                                          .obterLogoLoginWidget(
                                        width: 160.0,
                                        height: 160.0,
                                        fit: BoxFit.contain,
                                        borderRadius:
                                            BorderRadius.circular(8.0),
                                      ),
                                    ),
                                    Column(
                                      mainAxisSize: MainAxisSize.min,
                                      mainAxisAlignment:
                                          MainAxisAlignment.start,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      children: [
                                        Text(
                                          'Login de Acesso',
                                          style: AppTheme.of(context)
                                              .bodyMedium
                                              .override(
                                                font: GoogleFonts.inter(
                                                  fontWeight:
                                                      AppTheme.of(context)
                                                          .bodyMedium
                                                          .fontWeight,
                                                  fontStyle:
                                                      AppTheme.of(context)
                                                          .bodyMedium
                                                          .fontStyle,
                                                ),
                                                color: AppTheme.of(context)
                                                    .secondaryText,
                                                letterSpacing: 0.0,
                                                fontWeight: AppTheme.of(context)
                                                    .bodyMedium
                                                    .fontWeight,
                                                fontStyle: AppTheme.of(context)
                                                    .bodyMedium
                                                    .fontStyle,
                                              ),
                                        ),
                                      ].divide(const SizedBox(height: 4.0)),
                                    ),
                                    if (AppState().is_first_access)
                                      TextFormField(
                                        controller: _model
                                            .empresaCodigoFieldTextController,
                                        focusNode:
                                            _model.empresaCodigoFieldFocusNode,
                                        textInputAction: TextInputAction.next,
                                        onFieldSubmitted: (_) =>
                                            FocusScope.of(context).requestFocus(
                                                _model
                                                    .vendedorCodigoFieldFocusNode),
                                        inputFormatters: [
                                          UpperCaseTextFormatter(),
                                        ],
                                        obscureText: false,
                                        decoration: const InputDecoration(
                                          labelText: 'Código da Empresa',
                                          hintText:
                                              'Digite o código da empresa',
                                          enabledBorder: OutlineInputBorder(
                                            borderSide: BorderSide(
                                              color: Color(0x00000000),
                                              width: 1.0,
                                            ),
                                            borderRadius: BorderRadius.only(
                                              topLeft: Radius.circular(4.0),
                                              topRight: Radius.circular(4.0),
                                            ),
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderSide: BorderSide(
                                              color: Color(0x00000000),
                                              width: 1.0,
                                            ),
                                            borderRadius: BorderRadius.only(
                                              topLeft: Radius.circular(4.0),
                                              topRight: Radius.circular(4.0),
                                            ),
                                          ),
                                          errorBorder: OutlineInputBorder(
                                            borderSide: BorderSide(
                                              color: Color(0x00000000),
                                              width: 1.0,
                                            ),
                                            borderRadius: BorderRadius.only(
                                              topLeft: Radius.circular(4.0),
                                              topRight: Radius.circular(4.0),
                                            ),
                                          ),
                                          focusedErrorBorder:
                                              OutlineInputBorder(
                                            borderSide: BorderSide(
                                              color: Color(0x00000000),
                                              width: 1.0,
                                            ),
                                            borderRadius: BorderRadius.only(
                                              topLeft: Radius.circular(4.0),
                                              topRight: Radius.circular(4.0),
                                            ),
                                          ),
                                          filled: true,
                                        ),
                                        style: const TextStyle(),
                                        maxLines: null,
                                        validator: _model
                                            .empresaCodigoFieldTextControllerValidator
                                            .asValidator(context),
                                      ),
                                    TextFormField(
                                      controller: _model
                                          .vendedorCodigoFieldTextController,
                                      focusNode:
                                          _model.vendedorCodigoFieldFocusNode,
                                      textInputAction: TextInputAction.go,
                                      onFieldSubmitted: (_) => _fazerLogin(),
                                      inputFormatters: [
                                        UpperCaseTextFormatter(),
                                      ],
                                      obscureText: false,
                                      decoration: const InputDecoration(
                                        labelText: 'Código do Vendedor',
                                        hintText: 'Digite o código do vendedor',
                                        enabledBorder: OutlineInputBorder(
                                          borderSide: BorderSide(
                                            color: Color(0x00000000),
                                            width: 1.0,
                                          ),
                                          borderRadius: BorderRadius.only(
                                            topLeft: Radius.circular(4.0),
                                            topRight: Radius.circular(4.0),
                                          ),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderSide: BorderSide(
                                            color: Color(0x00000000),
                                            width: 1.0,
                                          ),
                                          borderRadius: BorderRadius.only(
                                            topLeft: Radius.circular(4.0),
                                            topRight: Radius.circular(4.0),
                                          ),
                                        ),
                                        errorBorder: OutlineInputBorder(
                                          borderSide: BorderSide(
                                            color: Color(0x00000000),
                                            width: 1.0,
                                          ),
                                          borderRadius: BorderRadius.only(
                                            topLeft: Radius.circular(4.0),
                                            topRight: Radius.circular(4.0),
                                          ),
                                        ),
                                        focusedErrorBorder: OutlineInputBorder(
                                          borderSide: BorderSide(
                                            color: Color(0x00000000),
                                            width: 1.0,
                                          ),
                                          borderRadius: BorderRadius.only(
                                            topLeft: Radius.circular(4.0),
                                            topRight: Radius.circular(4.0),
                                          ),
                                        ),
                                        filled: true,
                                      ),
                                      style: const TextStyle(),
                                      maxLines: null,
                                      validator: _model
                                          .vendedorCodigoFieldTextControllerValidator
                                          .asValidator(context),
                                    ),
                                    AppButtonWidget(
                                      onPressed: _fazerLogin,
                                      text: 'ENTRAR',
                                      options: AppButtonOptions(
                                        width: double.infinity,
                                        height: 50.0,
                                        padding: const EdgeInsetsDirectional
                                            .fromSTEB(0.0, 0.0, 0.0, 0.0),
                                        iconPadding: const EdgeInsetsDirectional
                                            .fromSTEB(0.0, 0.0, 0.0, 0.0),
                                        color: AppTheme.of(context).primary,
                                        textStyle: TextStyle(
                                          color: AppTheme.of(context)
                                              .secondaryBackground,
                                        ),
                                        borderRadius:
                                            BorderRadius.circular(8.0),
                                      ),
                                    ),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(8.0),
                                      child: Image.asset(
                                        'assets/images/logo-empresa.png',
                                        width: 200.0,
                                        height: 100.0,
                                        fit: BoxFit.contain,
                                      ),
                                    ),
                                  ].divide(const SizedBox(height: 20.0)),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (AppState().is_loading)
                Container(
                  width: double.infinity,
                  height: double.infinity,
                  decoration: const BoxDecoration(
                    color: Color(0x80000000),
                  ),
                  alignment: const AlignmentDirectional(0.0, 0.0),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24.0, vertical: 20.0),
                    decoration: BoxDecoration(
                      color: AppTheme.of(context).secondaryBackground,
                      borderRadius: BorderRadius.circular(12.0),
                      boxShadow: const [
                        BoxShadow(
                          blurRadius: 10.0,
                          color: Color(0x33000000),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                            AppTheme.of(context).primary,
                          ),
                        ),
                        const SizedBox(height: 16.0),
                        Text(
                          'Atualizando Carga Inicial...',
                          style: AppTheme.of(context).bodyMedium.override(
                                font: GoogleFonts.inter(
                                  fontWeight: FontWeight.w600,
                                ),
                                fontSize: 15.0,
                              ),
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

