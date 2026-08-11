import '/backend/schema/structs/index.dart';
import '/core/app_theme.dart';
import '/core/app_util.dart';
import '/core/app_widgets.dart';
import 'dart:ui';
import '/action_code/index.dart' as actions;
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
            alignment: AlignmentDirectional(0.0, 0.0),
            children: [
              Container(
                width: double.infinity,
                height: double.infinity,
                decoration: BoxDecoration(
                  color: AppTheme.of(context).primaryBackground,
                ),
                alignment: AlignmentDirectional(0.0, 0.0),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.max,
                    children: [
                      Padding(
                        padding: EdgeInsets.all(24.0),
                        child: Container(
                          width: 400.0,
                          decoration: BoxDecoration(
                            color: AppTheme.of(context)
                                .secondaryBackground,
                            borderRadius: BorderRadius.circular(16.0),
                          ),
                          child: Padding(
                            padding: EdgeInsets.all(24.0),
                            child: SingleChildScrollView(
                              primary: false,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                mainAxisAlignment: MainAxisAlignment.start,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Padding(
                                    padding: EdgeInsetsDirectional.fromSTEB(
                                        0.0, 0.0, 0.0, 18.0),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(8.0),
                                      child: Image.asset(
                                        'assets/images/DentixIA_Logo_(500_x_500_px).png',
                                        width: 260.0,
                                        height: 94.6,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
                                  Column(
                                    mainAxisSize: MainAxisSize.min,
                                    mainAxisAlignment: MainAxisAlignment.start,
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
                                              color:
                                                  AppTheme.of(context)
                                                      .secondaryText,
                                              letterSpacing: 0.0,
                                              fontWeight:
                                                  AppTheme.of(context)
                                                      .bodyMedium
                                                      .fontWeight,
                                              fontStyle:
                                                  AppTheme.of(context)
                                                      .bodyMedium
                                                      .fontStyle,
                                            ),
                                      ),
                                    ].divide(SizedBox(height: 4.0)),
                                  ),
                                  if (AppState().is_first_access)
                                    TextFormField(
                                      controller: _model
                                          .empresaCodigoFieldTextController,
                                      focusNode:
                                          _model.empresaCodigoFieldFocusNode,
                                      textInputAction: TextInputAction.next,
                                      obscureText: false,
                                      decoration: InputDecoration(
                                        labelText: 'Código da Empresa',
                                        hintText: 'Digite o código da empresa',
                                        enabledBorder: OutlineInputBorder(
                                          borderSide: BorderSide(
                                            color: Color(0x00000000),
                                            width: 1.0,
                                          ),
                                          borderRadius: const BorderRadius.only(
                                            topLeft: Radius.circular(4.0),
                                            topRight: Radius.circular(4.0),
                                          ),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderSide: BorderSide(
                                            color: Color(0x00000000),
                                            width: 1.0,
                                          ),
                                          borderRadius: const BorderRadius.only(
                                            topLeft: Radius.circular(4.0),
                                            topRight: Radius.circular(4.0),
                                          ),
                                        ),
                                        errorBorder: OutlineInputBorder(
                                          borderSide: BorderSide(
                                            color: Color(0x00000000),
                                            width: 1.0,
                                          ),
                                          borderRadius: const BorderRadius.only(
                                            topLeft: Radius.circular(4.0),
                                            topRight: Radius.circular(4.0),
                                          ),
                                        ),
                                        focusedErrorBorder: OutlineInputBorder(
                                          borderSide: BorderSide(
                                            color: Color(0x00000000),
                                            width: 1.0,
                                          ),
                                          borderRadius: const BorderRadius.only(
                                            topLeft: Radius.circular(4.0),
                                            topRight: Radius.circular(4.0),
                                          ),
                                        ),
                                        filled: true,
                                      ),
                                      style: TextStyle(),
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
                                    obscureText: false,
                                    decoration: InputDecoration(
                                      labelText: 'Código do Vendedor',
                                      hintText: 'Digite o código do vendedor',
                                      enabledBorder: OutlineInputBorder(
                                        borderSide: BorderSide(
                                          color: Color(0x00000000),
                                          width: 1.0,
                                        ),
                                        borderRadius: const BorderRadius.only(
                                          topLeft: Radius.circular(4.0),
                                          topRight: Radius.circular(4.0),
                                        ),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderSide: BorderSide(
                                          color: Color(0x00000000),
                                          width: 1.0,
                                        ),
                                        borderRadius: const BorderRadius.only(
                                          topLeft: Radius.circular(4.0),
                                          topRight: Radius.circular(4.0),
                                        ),
                                      ),
                                      errorBorder: OutlineInputBorder(
                                        borderSide: BorderSide(
                                          color: Color(0x00000000),
                                          width: 1.0,
                                        ),
                                        borderRadius: const BorderRadius.only(
                                          topLeft: Radius.circular(4.0),
                                          topRight: Radius.circular(4.0),
                                        ),
                                      ),
                                      focusedErrorBorder: OutlineInputBorder(
                                        borderSide: BorderSide(
                                          color: Color(0x00000000),
                                          width: 1.0,
                                        ),
                                        borderRadius: const BorderRadius.only(
                                          topLeft: Radius.circular(4.0),
                                          topRight: Radius.circular(4.0),
                                        ),
                                      ),
                                      filled: true,
                                    ),
                                    style: TextStyle(),
                                    maxLines: null,
                                    keyboardType: TextInputType.number,
                                    validator: _model
                                        .vendedorCodigoFieldTextControllerValidator
                                        .asValidator(context),
                                  ),
                                  AppButtonWidget(
                                    onPressed: () async {
                                      AppState().is_loading = true;
                                      safeSetState(() {});
                                      if (AppState().is_first_access) {
                                        _model.firstAccessResult =
                                            await actions.firstAccessLogin(
                                          _model
                                              .empresaCodigoFieldTextController
                                              .text,
                                          _model
                                              .vendedorCodigoFieldTextController
                                              .text,
                                        );
                                        if (_model.firstAccessResult!.success) {
                                          AppState().is_first_access = false;
                                          safeSetState(() {});
                                          _model.firstAccessLogin =
                                              await actions.offlineLogin(
                                            _model
                                                .vendedorCodigoFieldTextController
                                                .text,
                                          );
                                          if (_model
                                              .firstAccessLogin!.success) {
                                            AppState().vendedor_codigo =
                                                _model.firstAccessLogin!
                                                    .vendedorCodigo;
                                            safeSetState(() {});
                                            AppState().vendedor_nome = _model
                                                .firstAccessLogin!.vendedorNome;
                                            safeSetState(() {});
                                            AppState().vendedor_equipe = _model
                                                .firstAccessLogin!.vendedorEquipe;
                                            safeSetState(() {});
                                            AppState().empresa_codigo = _model
                                                .empresaCodigoFieldTextController
                                                .text;
                                            safeSetState(() {});
                                            AppState().is_loading = false;
                                            safeSetState(() {});

                                            context.pushNamed(
                                                HomePageWidget.routeName);
                                          } else {
                                            AppState().is_loading = false;
                                            safeSetState(() {});
                                            await showDialog(
                                              context: context,
                                              builder: (alertDialogContext) {
                                                return AlertDialog(
                                                  title: Text(
                                                      'Login nao validado'),
                                                  content: Text(
                                                      'Vendedor nao encontrado no banco local.'),
                                                  actions: [
                                                    TextButton(
                                                      onPressed: () =>
                                                          Navigator.pop(
                                                              alertDialogContext),
                                                      child: Text('OK'),
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
                                                title: Text(
                                                    'Falha na carga inicial'),
                                                content: Text(_model
                                                    .firstAccessResult!
                                                    .message),
                                                actions: [
                                                  TextButton(
                                                    onPressed: () =>
                                                        Navigator.pop(
                                                            alertDialogContext),
                                                    child: Text('OK'),
                                                  ),
                                                ],
                                              );
                                            },
                                          );
                                        }
                                      } else {
                                        _model.offlineLogin =
                                            await actions.offlineLogin(
                                          _model
                                              .vendedorCodigoFieldTextController
                                              .text,
                                        );
                                        if (_model.offlineLogin!.success) {
                                          AppState().vendedor_codigo = _model
                                              .offlineLogin!.vendedorCodigo;
                                          safeSetState(() {});
                                          AppState().vendedor_nome =
                                              _model.offlineLogin!.vendedorNome;
                                          safeSetState(() {});
                                          AppState().vendedor_equipe =
                                              _model.offlineLogin!.vendedorEquipe;
                                          safeSetState(() {});
                                          AppState().empresa_codigo = _model
                                              .empresaCodigoFieldTextController
                                              .text;
                                          safeSetState(() {});
                                          AppState().is_loading = false;
                                          safeSetState(() {});

                                          context.pushNamed(
                                              HomePageWidget.routeName);
                                        } else {
                                          AppState().is_loading = false;
                                          safeSetState(() {});
                                          await showDialog(
                                            context: context,
                                            builder: (alertDialogContext) {
                                              return AlertDialog(
                                                title:
                                                    Text('Login nao validado'),
                                                content: Text(
                                                    'Vendedor nao encontrado no banco local.'),
                                                actions: [
                                                  TextButton(
                                                    onPressed: () =>
                                                        Navigator.pop(
                                                            alertDialogContext),
                                                    child: Text('OK'),
                                                  ),
                                                ],
                                              );
                                            },
                                          );
                                        }
                                      }

                                      safeSetState(() {});
                                    },
                                    text: 'ENTRAR',
                                    options: AppButtonOptions(
                                      width: double.infinity,
                                      height: 50.0,
                                      padding: EdgeInsetsDirectional.fromSTEB(
                                          0.0, 0.0, 0.0, 0.0),
                                      iconPadding:
                                          EdgeInsetsDirectional.fromSTEB(
                                              0.0, 0.0, 0.0, 0.0),
                                      color:
                                          AppTheme.of(context).primary,
                                      textStyle: TextStyle(
                                        color: AppTheme.of(context)
                                            .secondaryBackground,
                                      ),
                                      borderRadius: BorderRadius.circular(8.0),
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
                                ].divide(SizedBox(height: 20.0)),
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
                  decoration: BoxDecoration(
                    color: Color(0x80000000),
                  ),
                  alignment: AlignmentDirectional(0.0, 0.0),
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
