import '/core/app_theme.dart';
import '/core/app_util.dart';
import '/core/app_widgets.dart';
import '/action_code/index.dart' as actions;
import '../../core/services/empresa_logo_service.dart';
import '/index.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:percent_indicator/percent_indicator.dart';
import 'package:provider/provider.dart';
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
              title: const Text('Falha na carga inicial'),
              content: Text(_model.firstAccessResult!.message),
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
                                        width: 260.0,
                                        height: 94.6,
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
                                        onFieldSubmitted: (_) => _fazerLogin(),
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
                                      keyboardType: TextInputType.number,
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
                                        height: 50.2,
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
                  child: CircularPercentIndicator(
                    percent: 0.0,
                    radius: 25.0,
                    lineWidth: 5.0,
                    animation: false,
                    animateFromLastPercent: true,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
