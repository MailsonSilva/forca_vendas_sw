import '/core/app_theme.dart';
import '/core/app_util.dart';
import '/core/app_widgets.dart';
import '/components/modal_selecao_filial/modal_selecao_filial_widget.dart';
import '/action_code/index.dart' as actions;
import '../../core/services/empresa_logo_service.dart';
import '/index.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '/services/filial_service.dart';
import '/data/services/local_sales_database_service.dart';
import '/services/acesso_ftp_service.dart';
import '/services/auth_service.dart';
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

    _model.empresaCodigoFieldTextController ??= TextEditingController(
      text: AppState().empresa_codigo,
    );
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

  Future<void> _exibirAlerta(String mensagem) async {
    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (alertDialogContext) {
        return AlertDialog(
          title: const Text('Atenção'),
          content: Text(mensagem),
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

  Future<void> _fazerLogin() async {
    final codigoEmpresaDigitado =
        _model.empresaCodigoFieldTextController?.text.trim() ?? '';
    final codigoVendedorDigitado =
        _model.vendedorCodigoFieldTextController?.text.trim() ?? '';

    if (codigoEmpresaDigitado.isEmpty) {
      await _exibirAlerta('Código de acesso da empresa não foi encontrado');
      return;
    }

    if (codigoVendedorDigitado.isEmpty) {
      await _exibirAlerta('Vendedor não encontrado');
      return;
    }

    AppState().is_loading = true;
    safeSetState(() {});

    try {
      // 1. Valida Empresa no JSON do FTP
      final configEmpresa =
          await AcessoFtpService().buscarConfigEmpresa(codigoEmpresaDigitado);
      if (configEmpresa == null) {
        AppState().is_loading = false;
        safeSetState(() {});
        await _exibirAlerta('Código de acesso da empresa não foi encontrado');
        return;
      }

      // 2. Valida Vendedor
      final authService = AuthService();
      final vendedorValido = await authService.validarVendedor(
        codigoVendedorDigitado,
        configEmpresa: configEmpresa,
      );
      if (!vendedorValido) {
        AppState().is_loading = false;
        safeSetState(() {});
        await _exibirAlerta('Vendedor não encontrado');
        return;
      }

      // 3. Sucesso: Grava parâmetros e avança
      await authService.iniciarSessao(codigoVendedorDigitado);
      await AppState().salvarConfigAcesso(
        configEmpresa,
        codigoEquipe: AppState().vendedor_equipe,
      );
      AppState().is_first_access = false;

      // SPEC-047 §1.1: Consulta filiais e processa seleção multi-filial antes de prosseguir
      await _processarFilialAposLogin();
      if (!mounted) return;

      AppState().is_loading = false;
      safeSetState(() {});

      context.pushNamed(HomePageWidget.routeName);
    } catch (e) {
      AppState().is_loading = false;
      safeSetState(() {});
      await _exibirAlerta('Falha ao validar acesso: $e');
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
                                        width: (MediaQuery.sizeOf(context).width *
                                                0.48)
                                            .clamp(160.0, 180.0),
                                        height: (MediaQuery.sizeOf(context).width *
                                                0.48)
                                            .clamp(160.0, 180.0),
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
                                          style: AppTheme.of(context).bodyMedium.copyWith(color: AppTheme.of(context).secondaryText, letterSpacing: 0.0),
                                        ),
                                      ].divide(const SizedBox(height: 4.0)),
                                    ),
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
                                        width: (MediaQuery.sizeOf(context).width *
                                                0.6)
                                            .clamp(200.0, 240.0),
                                        height: (MediaQuery.sizeOf(context).width *
                                                0.6)
                                            .clamp(200.0, 240.0),
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

