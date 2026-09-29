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
import 'package:shared_preferences/shared_preferences.dart';
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

  bool _isDispositivoVinculado = false;
  String? _codigoVendedorVinculado;
  String? _codigoEmpresaVinculada;

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => LoginPageModel());

    _model.empresaCodigoFieldTextController ??= TextEditingController(
      text: AppState().empresa_codigo,
    );
    _model.empresaCodigoFieldFocusNode ??= FocusNode();

    _model.vendedorCodigoFieldTextController ??= TextEditingController();
    _model.vendedorCodigoFieldFocusNode ??= FocusNode();

    // Carrega antecipadamente o vínculo persistido do dispositivo
    _verificarVinculacaoDispositivo();

    // On page load action.
    SchedulerBinding.instance.addPostFrameCallback((_) async {
      AppState().codFilialAtiva = 0;
      AppState().filialAtivaDes = '';
      _model.dbExists = await actions.checkDatabaseExists();
      AppState().is_first_access = !_model.dbExists!;
      await _verificarVinculacaoDispositivo();
      safeSetState(() {});
    });
  }

  Future<void> _verificarVinculacaoDispositivo() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final emp = prefs.getString('codigo_empresa') ??
          prefs.getString('app_empresa_codigo') ??
          (AppState().empresa_codigo.isNotEmpty ? AppState().empresa_codigo : null);
      final vend = prefs.getString('codigo_vendedor_vinculado');

      if (emp != null && emp.trim().isNotEmpty && vend != null && vend.trim().isNotEmpty) {
        _codigoEmpresaVinculada = emp.trim();
        _codigoVendedorVinculado = vend.trim();
        _isDispositivoVinculado = true;
        _model.empresaCodigoFieldTextController?.text = _codigoEmpresaVinculada!;
        AppState().empresa_codigo = _codigoEmpresaVinculada!;
      } else {
        _isDispositivoVinculado = false;
        _codigoEmpresaVinculada = null;
        _codigoVendedorVinculado = null;
      }
    } catch (_) {}
    if (mounted) {
      safeSetState(() {});
    }
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
    final codigoEmpresa = _isDispositivoVinculado && _codigoEmpresaVinculada != null && _codigoEmpresaVinculada!.isNotEmpty
        ? _codigoEmpresaVinculada!
        : (_model.empresaCodigoFieldTextController?.text.trim() ?? '');
    final codigoVendedorDigitado =
        _model.vendedorCodigoFieldTextController?.text.trim() ?? '';

    if (codigoEmpresa.isEmpty) {
      await _exibirAlerta('Código de acesso da empresa não foi encontrado');
      return;
    }

    if (codigoVendedorDigitado.isEmpty) {
      await _exibirAlerta('Vendedor não encontrado');
      return;
    }

    // TRAVA DE SEGURANÇA: O dispositivo só permite login do vendedor vinculado no primeiro acesso
    if (_isDispositivoVinculado && _codigoVendedorVinculado != null && _codigoVendedorVinculado!.isNotEmpty) {
      final vendDigitadoNum = int.tryParse(codigoVendedorDigitado);
      final vendVinculadoNum = int.tryParse(_codigoVendedorVinculado!);
      final ehMesmoVendedor = (vendDigitadoNum != null && vendVinculadoNum != null)
          ? (vendDigitadoNum == vendVinculadoNum)
          : (codigoVendedorDigitado.toUpperCase() == _codigoVendedorVinculado!.toUpperCase());

      if (!ehMesmoVendedor) {
        await _exibirAlerta('Este dispositivo está vinculado exclusivamente ao vendedor $_codigoVendedorVinculado');
        return;
      }
    }

    AppState().is_loading = true;
    safeSetState(() {});

    try {
      // 1. Valida Empresa no JSON do FTP
      final configEmpresa =
          await AcessoFtpService().buscarConfigEmpresa(codigoEmpresa);
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

      // Persiste codigo_empresa e codigo_vendedor_vinculado no SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('codigo_empresa', codigoEmpresa);
      await prefs.setString('app_empresa_codigo', codigoEmpresa);
      await prefs.setString('codigo_vendedor_vinculado', codigoVendedorDigitado);
      _codigoEmpresaVinculada = codigoEmpresa;
      _codigoVendedorVinculado = codigoVendedorDigitado;
      _isDispositivoVinculado = true;

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

    final mediaQuery = MediaQuery.of(context);
    final screenWidth = mediaQuery.size.width;
    final screenHeight = mediaQuery.size.height;

    final horizontalPadding = (screenWidth * 0.05).clamp(16.0, 24.0);
    final verticalPadding = (screenHeight * 0.02).clamp(12.0, 24.0);
    final cardPadding = (screenWidth * 0.05).clamp(16.0, 24.0);

    final logoLoginWidth = (screenWidth * 0.45).clamp(120.0, 160.0);
    final logoLoginHeight = (screenHeight * 0.09).clamp(50.0, 80.0);

    final logoEmpresaWidth = (screenWidth * 0.38).clamp(100.0, 140.0);
    final logoEmpresaHeight = (screenHeight * 0.08).clamp(40.0, 70.0);

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
            alignment: Alignment.center,
            children: [
              Center(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: horizontalPadding,
                    vertical: verticalPadding,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420.0),
                      child: Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: AppTheme.of(context).secondaryBackground,
                          borderRadius: BorderRadius.circular(16.0),
                          boxShadow: [
                            BoxShadow(
                              blurRadius: 10.0,
                              color: Colors.black.withValues(alpha: 0.05),
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: EdgeInsets.all(cardPadding),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.start,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Padding(
                                padding: const EdgeInsetsDirectional.fromSTEB(
                                    0.0, 0.0, 0.0, 12.0),
                                child: EmpresaLogoService.instance
                                    .obterLogoLoginWidget(
                                  width: logoLoginWidth,
                                  height: logoLoginHeight,
                                  fit: BoxFit.contain,
                                  borderRadius: BorderRadius.circular(8.0),
                                ),
                              ),
                              Text(
                                'Login de Acesso',
                                style: AppTheme.of(context).bodyMedium.copyWith(
                                      color: AppTheme.of(context).secondaryText,
                                      letterSpacing: 0.0,
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                              if (!_isDispositivoVinculado)
                                TextFormField(
                                  controller: _model
                                      .empresaCodigoFieldTextController,
                                  focusNode:
                                      _model.empresaCodigoFieldFocusNode,
                                  textInputAction: TextInputAction.next,
                                  onFieldSubmitted: (_) =>
                                      FocusScope.of(context).requestFocus(
                                          _model.vendedorCodigoFieldFocusNode),
                                  inputFormatters: [
                                    UpperCaseTextFormatter(),
                                  ],
                                  obscureText: false,
                                  decoration: const InputDecoration(
                                    labelText: 'Código da Empresa',
                                    hintText: 'Digite o código da empresa',
                                    enabledBorder: OutlineInputBorder(
                                      borderSide: BorderSide(
                                        color: Color(0x00000000),
                                        width: 1.0,
                                      ),
                                      borderRadius: BorderRadius.all(Radius.circular(4.0)),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderSide: BorderSide(
                                        color: Color(0x00000000),
                                        width: 1.0,
                                      ),
                                      borderRadius: BorderRadius.all(Radius.circular(4.0)),
                                    ),
                                    errorBorder: OutlineInputBorder(
                                      borderSide: BorderSide(
                                        color: Color(0x00000000),
                                        width: 1.0,
                                      ),
                                      borderRadius: BorderRadius.all(Radius.circular(4.0)),
                                    ),
                                    focusedErrorBorder: OutlineInputBorder(
                                      borderSide: BorderSide(
                                        color: Color(0x00000000),
                                        width: 1.0,
                                      ),
                                      borderRadius: BorderRadius.all(Radius.circular(4.0)),
                                    ),
                                    filled: true,
                                  ),
                                  style: const TextStyle(),
                                  maxLines: 1,
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
                                    borderRadius: BorderRadius.all(Radius.circular(4.0)),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderSide: BorderSide(
                                      color: Color(0x00000000),
                                      width: 1.0,
                                    ),
                                    borderRadius: BorderRadius.all(Radius.circular(4.0)),
                                  ),
                                  errorBorder: OutlineInputBorder(
                                    borderSide: BorderSide(
                                      color: Color(0x00000000),
                                      width: 1.0,
                                    ),
                                    borderRadius: BorderRadius.all(Radius.circular(4.0)),
                                  ),
                                  focusedErrorBorder: OutlineInputBorder(
                                    borderSide: BorderSide(
                                      color: Color(0x00000000),
                                      width: 1.0,
                                    ),
                                    borderRadius: BorderRadius.all(Radius.circular(4.0)),
                                  ),
                                  filled: true,
                                ),
                                style: const TextStyle(),
                                maxLines: 1,
                                validator: _model
                                    .vendedorCodigoFieldTextControllerValidator
                                    .asValidator(context),
                              ),
                              AppButtonWidget(
                                onPressed: _fazerLogin,
                                text: 'ENTRAR',
                                options: AppButtonOptions(
                                  width: double.infinity,
                                  height: 48.0,
                                  padding: const EdgeInsetsDirectional
                                      .fromSTEB(0.0, 0.0, 0.0, 0.0),
                                  iconPadding: const EdgeInsetsDirectional
                                      .fromSTEB(0.0, 0.0, 0.0, 0.0),
                                  color: AppTheme.of(context).primary,
                                  textStyle: TextStyle(
                                    color: AppTheme.of(context)
                                        .secondaryBackground,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  borderRadius:
                                      BorderRadius.circular(8.0),
                                ),
                              ),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8.0),
                                child: Image.asset(
                                  'assets/images/logo-empresa.png',
                                  width: logoEmpresaWidth,
                                  height: logoEmpresaHeight,
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ].divide(const SizedBox(height: 16.0)),
                          ),
                        ),
                      ),
                    ),
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

