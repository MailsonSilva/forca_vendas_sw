import '/backend/schema/structs/index.dart';
import '/components/loading/loading_widget.dart';
import '/core/app_drop_down.dart';
import '/core/app_icon_button.dart';
import '/core/app_theme.dart';
import '/core/app_util.dart';
import '/core/app_widgets.dart';
import '/core/form_field_controller.dart';
import 'dart:ui';
import '/action_code/index.dart' as actions;
import '/index.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:easy_debounce/easy_debounce.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:provider/provider.dart';
import 'form_clientes_page_model.dart';
export 'form_clientes_page_model.dart';

/// Formulario de inclusao e edicao de clientes offline.
class FormClientesPageWidget extends StatefulWidget {
  const FormClientesPageWidget({
    super.key,
    this.clienteCodigo,
  });

  final int? clienteCodigo;

  static String routeName = 'FormClientesPage';
  static String routePath = '/clientes/form';

  @override
  State<FormClientesPageWidget> createState() => _FormClientesPageWidgetState();
}

class _FormClientesPageWidgetState extends State<FormClientesPageWidget>
    with TickerProviderStateMixin {
  late FormClientesPageModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => FormClientesPageModel());

    // On page load action.
    SchedulerBinding.instance.addPostFrameCallback((_) async {
      if (widget!.clienteCodigo == null) {
        _model.cliData = ClienteResultStruct(
          isNovoCliente: true,
          isModificado: false,
        );
        _model.listaBancos = [];
        safeSetState(() {});
        _model.tipoPessoa = 'F';
        safeSetState(() {});
      } else {
        _model.clienteResult = await actions.carregarClienteOffline(
          widget!.clienteCodigo!,
        );
        _model.cliData = _model.clienteResult;
        _model.tipoPessoa = _model.cliData?.cli00Pessoa;
        _model.listaBancos = [];
        safeSetState(() {});
        safeSetState(() {
          _model.nomeFieldTextController?.text = _model.cliData!.cli00Descri;
        });
        safeSetState(() {
          _model.fantasiaFieldTextController?.text =
              _model.cliData!.cli00Fantas;
        });
        if (_model.cliData?.cli00Pessoa == 'F') {
          safeSetState(() {
            _model.cpfFieldTextController?.text = _model.cliData!.cli00Cpfcnp;
            _model.cpfFieldMask.updateMask(
              newValue: TextEditingValue(
                text: _model.cpfFieldTextController!.text,
              ),
            );
          });
        } else {
          safeSetState(() {
            _model.cnpjFieldTextController?.text = _model.cliData!.cli00Cpfcnp;
            _model.cnpjFieldMask.updateMask(
              newValue: TextEditingValue(
                text: _model.cnpjFieldTextController!.text,
              ),
            );
          });
        }

        // UF
        safeSetState(() {
          _model.ieFieldTextController?.text = _model.cliData!.cli00Estsgl;
        });
        // RG
        safeSetState(() {
          _model.rgFieldTextController?.text = _model.cliData!.cli02NRGProp;
          _model.rgFieldMask.updateMask(
            newValue: TextEditingValue(
              text: _model.rgFieldTextController!.text,
            ),
          );
        });
        // Telefone
        safeSetState(() {
          _model.dddFieldTextController?.text = _model.cliData?.cli00Fonddd ?? '';
          _model.telefoneFieldTextController?.text = _model.cliData?.cli00Fonnum ?? '';
          _model.telefoneFieldMask.updateMask(
            newValue: TextEditingValue(
              text: _model.telefoneFieldTextController!.text,
            ),
          );
        });
        safeSetState(() {
          _model.emailFieldTextController?.text = _model.cliData!.cli00Contat;
        });
        safeSetState(() {
          _model.ramolFieldTextController?.text = _model.cliData!.ram00descri;
        });
        safeSetState(() {
          _model.limiteFieldTextController?.text = formatNumber(
            _model.cliData!.cli00Crelim,
            formatType: FormatType.decimal,
            decimalType: DecimalType.commaDecimal,
            currency: 'R\$ ',
          );
        });
        safeSetState(() {
          _model.cepFieldTextController?.text = _model.cliData!.cli00Endcep;
          _model.cepFieldMask.updateMask(
            newValue: TextEditingValue(
              text: _model.cepFieldTextController!.text,
            ),
          );
        });
        safeSetState(() {
          _model.numeroFieldTextController?.text = _model.cliData!.cli00Endnum;
        });
        safeSetState(() {
          _model.bairroFieldTextController?.text = _model.cliData!.cli00Bairro;
        });
        safeSetState(() {
          _model.enderecoFieldTextController?.text =
              _model.cliData!.cli00Endere;
        });
        safeSetState(() {
          _model.cidadeFieldTextController?.text = _model.cliData!.cli00Ciddes;
        });
        safeSetState(() {
          _model.nomePropFieldTextController?.text = _model.cliData!.cli02NProp;
        });
        safeSetState(() {
          _model.enderecoPropFieldTextController?.text =
              _model.cliData!.cli02EndProp;
        });
        safeSetState(() {
          _model.bairroPropFieldTextController?.text =
              _model.cliData!.cli02BairroProp;
        });
        safeSetState(() {
          _model.cidadePropFieldTextController?.text =
              _model.cliData!.cli02CidadeProp;
        });
        safeSetState(() {
          _model.ufPropDropdownValueController?.value =
              _model.cliData!.cli02UfProp;
          _model.ufPropDropdownValue = _model.cliData!.cli02UfProp;
        });
        safeSetState(() {
          _model.nomePropConjFieldTextController?.text =
              _model.cliData!.cli02ConjugeProp;
        });
        safeSetState(() {
          _model.rgPropConjFieldTextController?.text =
              _model.cliData!.cli02NRGConjProp;
          _model.rgPropConjFieldMask.updateMask(
            newValue: TextEditingValue(
              text: _model.rgPropConjFieldTextController!.text,
            ),
          );
        });
        safeSetState(() {
          _model.cpfPropConjFieldTextController?.text =
              _model.cliData!.cli02CpfConjProp;
          _model.cpfPropConjFieldMask.updateMask(
            newValue: TextEditingValue(
              text: _model.cpfPropConjFieldTextController!.text,
            ),
          );
        });
        safeSetState(() {
          _model.obsFieldTextController?.text = _model.cliData!.cli00Observ;
        });
      }
    });

    _model.tabBarCliController = TabController(
      vsync: this,
      length: 4,
      initialIndex: 0,
    )..addListener(() => safeSetState(() {}));

    _model.nomeFieldTextController ??= TextEditingController();
    _model.nomeFieldFocusNode ??= FocusNode();

    _model.fantasiaFieldTextController ??= TextEditingController();
    _model.fantasiaFieldFocusNode ??= FocusNode();

    _model.cpfFieldTextController ??= TextEditingController();
    _model.cpfFieldFocusNode ??= FocusNode();

    _model.cpfFieldMask = MaskTextInputFormatter(mask: '###.###.###-##');
    _model.cnpjFieldTextController ??= TextEditingController();
    _model.cnpjFieldFocusNode ??= FocusNode();

    _model.cnpjFieldMask = MaskTextInputFormatter(mask: '##.###.###/####-#');
    _model.ieFieldTextController ??= TextEditingController();
    _model.ieFieldFocusNode ??= FocusNode();

    _model.rgFieldTextController ??= TextEditingController();
    _model.rgFieldFocusNode ??= FocusNode();

    _model.rgFieldMask = MaskTextInputFormatter(mask: '###.###.#####-#');
    _model.telefoneFieldTextController ??= TextEditingController();
    _model.telefoneFieldFocusNode ??= FocusNode();
    // Initialize DDD field
    _model.dddFieldTextController ??= TextEditingController(
        text: _model.cliData?.cli00Fonddd ?? '');
    _model.dddFieldFocusNode ??= FocusNode();

    _model.telefoneFieldMask = MaskTextInputFormatter(mask: '#####-####');
    _model.emailFieldTextController ??= TextEditingController();
    _model.emailFieldFocusNode ??= FocusNode();

    _model.ramolFieldTextController ??= TextEditingController();
    _model.ramolFieldFocusNode ??= FocusNode();

    _model.limiteFieldTextController ??= TextEditingController(
        text: formatNumber(
      _model.cliData?.cli00Crelim,
      formatType: FormatType.decimal,
      decimalType: DecimalType.commaDecimal,
      currency: 'R\$ ',
    ));
    _model.limiteFieldFocusNode ??= FocusNode();

    _model.cepFieldTextController ??= TextEditingController(
        text: valueOrDefault<String>(
      _model.cliData?.cli00Endcep,
      'Cep',
    ));
    _model.cepFieldFocusNode ??= FocusNode();

    _model.cepFieldMask = MaskTextInputFormatter(mask: '#####-###');
    _model.numeroFieldTextController ??= TextEditingController(
        text: valueOrDefault<String>(
      _model.cliData?.cli00Endnum,
      'Numero',
    ));
    _model.numeroFieldFocusNode ??= FocusNode();

    _model.bairroFieldTextController ??= TextEditingController();
    _model.bairroFieldFocusNode ??= FocusNode();

    _model.enderecoFieldTextController ??= TextEditingController();
    _model.enderecoFieldFocusNode ??= FocusNode();

    _model.cidadeFieldTextController ??= TextEditingController();
    _model.cidadeFieldFocusNode ??= FocusNode();

    _model.nomePropFieldTextController ??= TextEditingController();
    _model.nomePropFieldFocusNode ??= FocusNode();

    _model.enderecoPropFieldTextController ??= TextEditingController();
    _model.enderecoPropFieldFocusNode ??= FocusNode();

    _model.bairroPropFieldTextController ??= TextEditingController();
    _model.bairroPropFieldFocusNode ??= FocusNode();

    _model.cidadePropFieldTextController ??= TextEditingController();
    _model.cidadePropFieldFocusNode ??= FocusNode();

    _model.rgPropFieldTextController ??= TextEditingController();
    _model.rgPropFieldFocusNode ??= FocusNode();

    _model.rgPropFieldMask = MaskTextInputFormatter(mask: '###.###.#####-#');
    _model.cpfPropFieldTextController ??= TextEditingController();
    _model.cpfPropFieldFocusNode ??= FocusNode();

    _model.cpfPropFieldMask = MaskTextInputFormatter(mask: '###.###.###-##');
    _model.nomePropConjFieldTextController ??= TextEditingController();
    _model.nomePropConjFieldFocusNode ??= FocusNode();

    _model.rgPropConjFieldTextController ??= TextEditingController();
    _model.rgPropConjFieldFocusNode ??= FocusNode();

    _model.rgPropConjFieldMask =
        MaskTextInputFormatter(mask: '###.###.#####-#');
    _model.cpfPropConjFieldTextController ??= TextEditingController();
    _model.cpfPropConjFieldFocusNode ??= FocusNode();

    _model.cpfPropConjFieldMask =
        MaskTextInputFormatter(mask: '###.###.###-##');
    _model.obsFieldTextController ??=
        TextEditingController(text: _model.cliData?.cli00Observ);
    _model.obsFieldFocusNode ??= FocusNode();
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
            icon: Icon(
              Icons.arrow_back_rounded,
              color: Colors.white,
              size: 30.0,
            ),
            onPressed: () async {
              context.pop();
            },
          ),
          title: Text(
            'Cliente',
            style: AppTheme.of(context).titleLarge.override(
                  font: GoogleFonts.plusJakartaSans(
                    fontWeight:
                        AppTheme.of(context).titleLarge.fontWeight,
                    fontStyle:
                        AppTheme.of(context).titleLarge.fontStyle,
                  ),
                  color: Colors.white,
                  letterSpacing: 0.0,
                  fontWeight:
                      AppTheme.of(context).titleLarge.fontWeight,
                  fontStyle: AppTheme.of(context).titleLarge.fontStyle,
                ),
          ),
          actions: [],
          centerTitle: true,
          elevation: 2.0,
        ),
        body: SafeArea(
          top: true,
          child: Container(
            decoration: BoxDecoration(
              color: AppTheme.of(context).primaryBackground,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.max,
              children: [
                Expanded(
                  child: Builder(
                    builder: (context) {
                      if (_model.cliData != null) {
                        return Column(
                          children: [
                            Align(
                              alignment: Alignment(0.0, 0),
                              child: TabBar(
                                isScrollable: true,
                                labelColor:
                                    AppTheme.of(context).primary,
                                unselectedLabelColor:
                                    AppTheme.of(context).secondaryText,
                                labelStyle: AppTheme.of(context)
                                    .titleMedium
                                    .override(
                                      font: GoogleFonts.plusJakartaSans(
                                        fontWeight: AppTheme.of(context)
                                            .titleMedium
                                            .fontWeight,
                                        fontStyle: AppTheme.of(context)
                                            .titleMedium
                                            .fontStyle,
                                      ),
                                      fontSize: 12.0,
                                      letterSpacing: 0.0,
                                      fontWeight: AppTheme.of(context)
                                          .titleMedium
                                          .fontWeight,
                                      fontStyle: AppTheme.of(context)
                                          .titleMedium
                                          .fontStyle,
                                    ),
                                unselectedLabelStyle: AppTheme.of(
                                        context)
                                    .titleMedium
                                    .override(
                                      font: GoogleFonts.plusJakartaSans(
                                        fontWeight: AppTheme.of(context)
                                            .titleMedium
                                            .fontWeight,
                                        fontStyle: AppTheme.of(context)
                                            .titleMedium
                                            .fontStyle,
                                      ),
                                      fontSize: 12.0,
                                      letterSpacing: 0.0,
                                      fontWeight: AppTheme.of(context)
                                          .titleMedium
                                          .fontWeight,
                                      fontStyle: AppTheme.of(context)
                                          .titleMedium
                                          .fontStyle,
                                    ),
                                indicatorColor:
                                    AppTheme.of(context).primary,
                                tabs: [
                                  Tab(
                                    text: 'Principal',
                                  ),
                                  Tab(
                                    text: 'Endereço',
                                  ),
                                  Tab(
                                    text: 'Proprietário',
                                  ),
                                  Tab(
                                    text: 'Banco e Obs',
                                  ),
                                ],
                                controller: _model.tabBarCliController,
                                onTap: (i) async {
                                  [
                                    () async {},
                                    () async {},
                                    () async {},
                                    () async {}
                                  ][i]();
                                },
                              ),
                            ),
                            Expanded(
                              child: TabBarView(
                                controller: _model.tabBarCliController,
                                children: [
                                  SingleChildScrollView(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.max,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        Padding(
                                          padding:
                                              EdgeInsetsDirectional.fromSTEB(
                                                  16.0, 0.0, 16.0, 0.0),
                                          child: TextFormField(
                                            controller:
                                                _model.nomeFieldTextController,
                                            focusNode:
                                                _model.nomeFieldFocusNode,
                                            textInputAction:
                                                TextInputAction.next,
                                            obscureText: false,
                                            decoration: InputDecoration(
                                              isDense: true,
                                              labelText: 'Razão Social',
                                              labelStyle: GoogleFonts.inter(
                                                color:
                                                    AppTheme.of(context)
                                                        .secondaryText,
                                                fontWeight: FontWeight.w600,
                                                fontSize: 14.0,
                                              ),
                                              alignLabelWithHint: false,
                                              hintText: 'Razão social',
                                              enabledBorder: OutlineInputBorder(
                                                borderSide: BorderSide(
                                                  color: Color(0x00000000),
                                                  width: 1.0,
                                                ),
                                                borderRadius:
                                                    const BorderRadius.only(
                                                  topLeft: Radius.circular(4.0),
                                                  topRight:
                                                      Radius.circular(4.0),
                                                ),
                                              ),
                                              focusedBorder: OutlineInputBorder(
                                                borderSide: BorderSide(
                                                  color: Color(0x00000000),
                                                  width: 1.0,
                                                ),
                                                borderRadius:
                                                    const BorderRadius.only(
                                                  topLeft: Radius.circular(4.0),
                                                  topRight:
                                                      Radius.circular(4.0),
                                                ),
                                              ),
                                              errorBorder: OutlineInputBorder(
                                                borderSide: BorderSide(
                                                  color: Color(0x00000000),
                                                  width: 1.0,
                                                ),
                                                borderRadius:
                                                    const BorderRadius.only(
                                                  topLeft: Radius.circular(4.0),
                                                  topRight:
                                                      Radius.circular(4.0),
                                                ),
                                              ),
                                              focusedErrorBorder:
                                                  OutlineInputBorder(
                                                borderSide: BorderSide(
                                                  color: Color(0x00000000),
                                                  width: 1.0,
                                                ),
                                                borderRadius:
                                                    const BorderRadius.only(
                                                  topLeft: Radius.circular(4.0),
                                                  topRight:
                                                      Radius.circular(4.0),
                                                ),
                                              ),
                                              filled: true,
                                              fillColor:
                                                  AppTheme.of(context)
                                                      .secondaryBackground,
                                            ),
                                            style: GoogleFonts.plusJakartaSans(
                                              color:
                                                  AppTheme.of(context)
                                                      .primaryText,
                                              fontSize: 14.0,
                                            ),
                                            maxLines: null,
                                            validator: _model
                                                .nomeFieldTextControllerValidator
                                                .asValidator(context),
                                          ),
                                        ),
                                        Padding(
                                          padding:
                                              EdgeInsetsDirectional.fromSTEB(
                                                  16.0, 0.0, 16.0, 0.0),
                                          child: TextFormField(
                                            controller: _model
                                                .fantasiaFieldTextController,
                                            focusNode:
                                                _model.fantasiaFieldFocusNode,
                                            textInputAction:
                                                TextInputAction.next,
                                            obscureText: false,
                                            decoration: InputDecoration(
                                              isDense: true,
                                              labelText: 'Nome Fantasia',
                                              labelStyle: GoogleFonts.inter(
                                                color:
                                                    AppTheme.of(context)
                                                        .secondaryText,
                                                fontWeight: FontWeight.w600,
                                                fontSize: 14.0,
                                              ),
                                              alignLabelWithHint: false,
                                              hintText: 'Nome Fantasia',
                                              enabledBorder: OutlineInputBorder(
                                                borderSide: BorderSide(
                                                  color: Color(0x00000000),
                                                  width: 1.0,
                                                ),
                                                borderRadius:
                                                    const BorderRadius.only(
                                                  topLeft: Radius.circular(4.0),
                                                  topRight:
                                                      Radius.circular(4.0),
                                                ),
                                              ),
                                              focusedBorder: OutlineInputBorder(
                                                borderSide: BorderSide(
                                                  color: Color(0x00000000),
                                                  width: 1.0,
                                                ),
                                                borderRadius:
                                                    const BorderRadius.only(
                                                  topLeft: Radius.circular(4.0),
                                                  topRight:
                                                      Radius.circular(4.0),
                                                ),
                                              ),
                                              errorBorder: OutlineInputBorder(
                                                borderSide: BorderSide(
                                                  color: Color(0x00000000),
                                                  width: 1.0,
                                                ),
                                                borderRadius:
                                                    const BorderRadius.only(
                                                  topLeft: Radius.circular(4.0),
                                                  topRight:
                                                      Radius.circular(4.0),
                                                ),
                                              ),
                                              focusedErrorBorder:
                                                  OutlineInputBorder(
                                                borderSide: BorderSide(
                                                  color: Color(0x00000000),
                                                  width: 1.0,
                                                ),
                                                borderRadius:
                                                    const BorderRadius.only(
                                                  topLeft: Radius.circular(4.0),
                                                  topRight:
                                                      Radius.circular(4.0),
                                                ),
                                              ),
                                              filled: true,
                                              fillColor:
                                                  AppTheme.of(context)
                                                      .secondaryBackground,
                                            ),
                                            style: GoogleFonts.plusJakartaSans(
                                              color:
                                                  AppTheme.of(context)
                                                      .primaryText,
                                              fontSize: 14.0,
                                            ),
                                            maxLines: null,
                                            validator: _model
                                                .fantasiaFieldTextControllerValidator
                                                .asValidator(context),
                                          ),
                                        ),
                                        Padding(
                                          padding:
                                              EdgeInsetsDirectional.fromSTEB(
                                                  16.0, 0.0, 16.0, 4.0),
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            mainAxisAlignment:
                                                MainAxisAlignment.start,
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Padding(
                                                padding: EdgeInsetsDirectional
                                                    .fromSTEB(
                                                        10.0, 0.0, 0.0, 0.0),
                                                child: Text(
                                                  'Tipo de Pessoa',
                                                  style: AppTheme.of(
                                                          context)
                                                      .bodyMedium
                                                      .override(
                                                        font: GoogleFonts.inter(
                                                          fontWeight:
                                                              FontWeight.w600,
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
                                                        fontSize: 14.0,
                                                        letterSpacing: 0.0,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        fontStyle:
                                                            AppTheme.of(
                                                                    context)
                                                                .bodyMedium
                                                                .fontStyle,
                                                      ),
                                                ),
                                              ),
                                              Row(
                                                mainAxisSize: MainAxisSize.max,
                                                mainAxisAlignment:
                                                    MainAxisAlignment.start,
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.center,
                                                children: [
                                                  Expanded(
                                                    child: AppButtonWidget(
                                                      onPressed: () async {
                                                        _model.tipoPessoa = 'F';
                                                        safeSetState(() {});
                                                      },
                                                      text: 'Física',
                                                      options: AppButtonOptions(
                                                        width: double.infinity,
                                                        height: 42.0,
                                                        padding:
                                                            EdgeInsetsDirectional
                                                                .fromSTEB(
                                                                    0.0,
                                                                    0.0,
                                                                    0.0,
                                                                    0.0),
                                                        iconPadding:
                                                            EdgeInsetsDirectional
                                                                .fromSTEB(
                                                                    0.0,
                                                                    0.0,
                                                                    0.0,
                                                                    0.0),
                                                        color: valueOrDefault<
                                                            Color>(
                                                          _model.cliData
                                                                      ?.cli00Pessoa ==
                                                                  'F'
                                                              ? AppTheme
                                                                      .of(
                                                                          context)
                                                                  .primary
                                                              : AppTheme
                                                                      .of(context)
                                                                  .secondaryBackground,
                                                          AppTheme.of(
                                                                  context)
                                                              .secondaryBackground,
                                                        ),
                                                        textStyle: TextStyle(
                                                          color: AppTheme
                                                                  .of(context)
                                                              .primaryText,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                          fontSize: 14.0,
                                                        ),
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(8.0),
                                                      ),
                                                    ),
                                                  ),
                                                  Expanded(
                                                    child: AppButtonWidget(
                                                      onPressed: () async {
                                                        _model.tipoPessoa = 'J';
                                                        safeSetState(() {});
                                                      },
                                                      text: 'Jurídica',
                                                      options: AppButtonOptions(
                                                        width: double.infinity,
                                                        height: 42.0,
                                                        padding:
                                                            EdgeInsetsDirectional
                                                                .fromSTEB(
                                                                    0.0,
                                                                    0.0,
                                                                    0.0,
                                                                    0.0),
                                                        iconPadding:
                                                            EdgeInsetsDirectional
                                                                .fromSTEB(
                                                                    0.0,
                                                                    0.0,
                                                                    0.0,
                                                                    0.0),
                                                        color: valueOrDefault<
                                                            Color>(
                                                          _model.tipoPessoa ==
                                                                  'J'
                                                              ? AppTheme
                                                                      .of(
                                                                          context)
                                                                  .primary
                                                              : AppTheme
                                                                      .of(context)
                                                                  .secondaryBackground,
                                                          AppTheme.of(
                                                                  context)
                                                              .secondaryBackground,
                                                        ),
                                                        textStyle: TextStyle(
                                                          color: AppTheme
                                                                  .of(context)
                                                              .primaryText,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                          fontSize: 14.0,
                                                        ),
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(8.0),
                                                      ),
                                                    ),
                                                  ),
                                                ].divide(SizedBox(width: 12.0)),
                                              ),
                                            ].divide(SizedBox(height: 8.0)),
                                          ),
                                        ),
                                        Builder(
                                          builder: (context) {
                                            if (_model.tipoPessoa == 'F') {
                                              return Padding(
                                                padding: EdgeInsetsDirectional
                                                    .fromSTEB(
                                                        16.0, 0.0, 16.0, 0.0),
                                                child: TextFormField(
                                                  controller: _model
                                                      .cpfFieldTextController,
                                                  focusNode:
                                                      _model.cpfFieldFocusNode,
                                                  textInputAction:
                                                      TextInputAction.next,
                                                  obscureText: false,
                                                  decoration: InputDecoration(
                                                    isDense: true,
                                                    labelText: 'CPF',
                                                    labelStyle:
                                                        GoogleFonts.inter(
                                                      color:
                                                          AppTheme.of(
                                                                  context)
                                                              .secondaryText,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      fontSize: 14.0,
                                                    ),
                                                    hintText: '000.000.000-00',
                                                    enabledBorder:
                                                        OutlineInputBorder(
                                                      borderSide: BorderSide(
                                                        color:
                                                            Color(0x00000000),
                                                        width: 1.0,
                                                      ),
                                                      borderRadius:
                                                          const BorderRadius
                                                              .only(
                                                        topLeft:
                                                            Radius.circular(
                                                                4.0),
                                                        topRight:
                                                            Radius.circular(
                                                                4.0),
                                                      ),
                                                    ),
                                                    focusedBorder:
                                                        OutlineInputBorder(
                                                      borderSide: BorderSide(
                                                        color:
                                                            Color(0x00000000),
                                                        width: 1.0,
                                                      ),
                                                      borderRadius:
                                                          const BorderRadius
                                                              .only(
                                                        topLeft:
                                                            Radius.circular(
                                                                4.0),
                                                        topRight:
                                                            Radius.circular(
                                                                4.0),
                                                      ),
                                                    ),
                                                    errorBorder:
                                                        OutlineInputBorder(
                                                      borderSide: BorderSide(
                                                        color:
                                                            Color(0x00000000),
                                                        width: 1.0,
                                                      ),
                                                      borderRadius:
                                                          const BorderRadius
                                                              .only(
                                                        topLeft:
                                                            Radius.circular(
                                                                4.0),
                                                        topRight:
                                                            Radius.circular(
                                                                4.0),
                                                      ),
                                                    ),
                                                    focusedErrorBorder:
                                                        OutlineInputBorder(
                                                      borderSide: BorderSide(
                                                        color:
                                                            Color(0x00000000),
                                                        width: 1.0,
                                                      ),
                                                      borderRadius:
                                                          const BorderRadius
                                                              .only(
                                                        topLeft:
                                                            Radius.circular(
                                                                4.0),
                                                        topRight:
                                                            Radius.circular(
                                                                4.0),
                                                      ),
                                                    ),
                                                    filled: true,
                                                    fillColor: AppTheme
                                                            .of(context)
                                                        .secondaryBackground,
                                                  ),
                                                  style: GoogleFonts
                                                      .plusJakartaSans(
                                                    color: AppTheme.of(
                                                            context)
                                                        .primaryText,
                                                    fontSize: 14.0,
                                                  ),
                                                  maxLines: null,
                                                  keyboardType:
                                                      TextInputType.number,
                                                  validator: _model
                                                      .cpfFieldTextControllerValidator
                                                      .asValidator(context),
                                                  inputFormatters: [
                                                    _model.cpfFieldMask
                                                  ],
                                                ),
                                              );
                                            } else {
                                              return Padding(
                                                padding: EdgeInsetsDirectional
                                                    .fromSTEB(
                                                        16.0, 0.0, 16.0, 0.0),
                                                child: TextFormField(
                                                  controller: _model
                                                      .cnpjFieldTextController,
                                                  focusNode:
                                                      _model.cnpjFieldFocusNode,
                                                  onChanged: (_) =>
                                                      EasyDebounce.debounce(
                                                    '_model.cnpjFieldTextController',
                                                    Duration(
                                                        milliseconds: 2000),
                                                    () async {
                                                      safeSetState(() {});
                                                    },
                                                  ),
                                                  textInputAction:
                                                      TextInputAction.next,
                                                  obscureText: false,
                                                  decoration: InputDecoration(
                                                    isDense: true,
                                                    labelText: ' CNPJ',
                                                    labelStyle:
                                                        GoogleFonts.inter(
                                                      color:
                                                          AppTheme.of(
                                                                  context)
                                                              .secondaryText,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      fontSize: 14.0,
                                                    ),
                                                    hintText:
                                                        '00.000.000/0000-0',
                                                    enabledBorder:
                                                        OutlineInputBorder(
                                                      borderSide: BorderSide(
                                                        color:
                                                            Color(0x00000000),
                                                        width: 1.0,
                                                      ),
                                                      borderRadius:
                                                          const BorderRadius
                                                              .only(
                                                        topLeft:
                                                            Radius.circular(
                                                                4.0),
                                                        topRight:
                                                            Radius.circular(
                                                                4.0),
                                                      ),
                                                    ),
                                                    focusedBorder:
                                                        OutlineInputBorder(
                                                      borderSide: BorderSide(
                                                        color:
                                                            Color(0x00000000),
                                                        width: 1.0,
                                                      ),
                                                      borderRadius:
                                                          const BorderRadius
                                                              .only(
                                                        topLeft:
                                                            Radius.circular(
                                                                4.0),
                                                        topRight:
                                                            Radius.circular(
                                                                4.0),
                                                      ),
                                                    ),
                                                    errorBorder:
                                                        OutlineInputBorder(
                                                      borderSide: BorderSide(
                                                        color:
                                                            Color(0x00000000),
                                                        width: 1.0,
                                                      ),
                                                      borderRadius:
                                                          const BorderRadius
                                                              .only(
                                                        topLeft:
                                                            Radius.circular(
                                                                4.0),
                                                        topRight:
                                                            Radius.circular(
                                                                4.0),
                                                      ),
                                                    ),
                                                    focusedErrorBorder:
                                                        OutlineInputBorder(
                                                      borderSide: BorderSide(
                                                        color:
                                                            Color(0x00000000),
                                                        width: 1.0,
                                                      ),
                                                      borderRadius:
                                                          const BorderRadius
                                                              .only(
                                                        topLeft:
                                                            Radius.circular(
                                                                4.0),
                                                        topRight:
                                                            Radius.circular(
                                                                4.0),
                                                      ),
                                                    ),
                                                    filled: true,
                                                    fillColor: AppTheme
                                                            .of(context)
                                                        .secondaryBackground,
                                                  ),
                                                  style: GoogleFonts
                                                      .plusJakartaSans(
                                                    color: AppTheme.of(
                                                            context)
                                                        .primaryText,
                                                    fontSize: 14.0,
                                                  ),
                                                  maxLines: null,
                                                  keyboardType:
                                                      TextInputType.number,
                                                  validator: _model
                                                      .cnpjFieldTextControllerValidator
                                                      .asValidator(context),
                                                  inputFormatters: [
                                                    _model.cnpjFieldMask
                                                  ],
                                                ),
                                              );
                                            }
                                          },
                                        ),
                                        Padding(
                                          padding:
                                              EdgeInsetsDirectional.fromSTEB(
                                                  16.0, 0.0, 16.0, 0.0),
                                          child: TextFormField(
                                            controller:
                                                _model.ieFieldTextController,
                                            focusNode: _model.ieFieldFocusNode,
                                            onChanged: (_) =>
                                                EasyDebounce.debounce(
                                              '_model.ieFieldTextController',
                                              Duration(milliseconds: 2000),
                                              () async {
                                                safeSetState(() {});
                                              },
                                            ),
                                            textInputAction:
                                                TextInputAction.next,
                                            obscureText: false,
                                            decoration: InputDecoration(
                                              isDense: true,
                                              labelText: 'Inscrição Estadual',
                                              labelStyle: GoogleFonts.inter(
                                                color:
                                                    AppTheme.of(context)
                                                        .secondaryText,
                                                fontWeight: FontWeight.w600,
                                                fontSize: 14.0,
                                              ),
                                              hintText: '00000000-0',
                                              enabledBorder: OutlineInputBorder(
                                                borderSide: BorderSide(
                                                  color: Color(0x00000000),
                                                  width: 1.0,
                                                ),
                                                borderRadius:
                                                    const BorderRadius.only(
                                                  topLeft: Radius.circular(4.0),
                                                  topRight:
                                                      Radius.circular(4.0),
                                                ),
                                              ),
                                              focusedBorder: OutlineInputBorder(
                                                borderSide: BorderSide(
                                                  color: Color(0x00000000),
                                                  width: 1.0,
                                                ),
                                                borderRadius:
                                                    const BorderRadius.only(
                                                  topLeft: Radius.circular(4.0),
                                                  topRight:
                                                      Radius.circular(4.0),
                                                ),
                                              ),
                                              errorBorder: OutlineInputBorder(
                                                borderSide: BorderSide(
                                                  color: Color(0x00000000),
                                                  width: 1.0,
                                                ),
                                                borderRadius:
                                                    const BorderRadius.only(
                                                  topLeft: Radius.circular(4.0),
                                                  topRight:
                                                      Radius.circular(4.0),
                                                ),
                                              ),
                                              focusedErrorBorder:
                                                  OutlineInputBorder(
                                                borderSide: BorderSide(
                                                  color: Color(0x00000000),
                                                  width: 1.0,
                                                ),
                                                borderRadius:
                                                    const BorderRadius.only(
                                                  topLeft: Radius.circular(4.0),
                                                  topRight:
                                                      Radius.circular(4.0),
                                                ),
                                              ),
                                              filled: true,
                                              fillColor:
                                                  AppTheme.of(context)
                                                      .secondaryBackground,
                                            ),
                                            style: GoogleFonts.plusJakartaSans(
                                              color:
                                                  AppTheme.of(context)
                                                      .primaryText,
                                              fontSize: 14.0,
                                            ),
                                            maxLines: null,
                                            keyboardType: TextInputType.number,
                                            validator: _model
                                                .ieFieldTextControllerValidator
                                                .asValidator(context),
                                          ),
                                        ),
                                        Padding(
                                          padding:
                                              EdgeInsetsDirectional.fromSTEB(
                                                  16.0, 0.0, 16.0, 0.0),
                                          child: TextFormField(
                                            controller:
                                                _model.rgFieldTextController,
                                            focusNode: _model.rgFieldFocusNode,
                                            onChanged: (_) =>
                                                EasyDebounce.debounce(
                                              '_model.rgFieldTextController',
                                              Duration(milliseconds: 2000),
                                              () async {
                                                safeSetState(() {});
                                              },
                                            ),
                                            textInputAction:
                                                TextInputAction.next,
                                            obscureText: false,
                                            decoration: InputDecoration(
                                              isDense: true,
                                              labelText: 'RG',
                                              labelStyle: GoogleFonts.inter(
                                                color:
                                                    AppTheme.of(context)
                                                        .secondaryText,
                                                fontWeight: FontWeight.w600,
                                                fontSize: 14.0,
                                              ),
                                              hintText: '000.000.00000-0',
                                              enabledBorder: OutlineInputBorder(
                                                borderSide: BorderSide(
                                                  color: Color(0x00000000),
                                                  width: 1.0,
                                                ),
                                                borderRadius:
                                                    const BorderRadius.only(
                                                  topLeft: Radius.circular(4.0),
                                                  topRight:
                                                      Radius.circular(4.0),
                                                ),
                                              ),
                                              focusedBorder: OutlineInputBorder(
                                                borderSide: BorderSide(
                                                  color: Color(0x00000000),
                                                  width: 1.0,
                                                ),
                                                borderRadius:
                                                    const BorderRadius.only(
                                                  topLeft: Radius.circular(4.0),
                                                  topRight:
                                                      Radius.circular(4.0),
                                                ),
                                              ),
                                              errorBorder: OutlineInputBorder(
                                                borderSide: BorderSide(
                                                  color: Color(0x00000000),
                                                  width: 1.0,
                                                ),
                                                borderRadius:
                                                    const BorderRadius.only(
                                                  topLeft: Radius.circular(4.0),
                                                  topRight:
                                                      Radius.circular(4.0),
                                                ),
                                              ),
                                              focusedErrorBorder:
                                                  OutlineInputBorder(
                                                borderSide: BorderSide(
                                                  color: Color(0x00000000),
                                                  width: 1.0,
                                                ),
                                                borderRadius:
                                                    const BorderRadius.only(
                                                  topLeft: Radius.circular(4.0),
                                                  topRight:
                                                      Radius.circular(4.0),
                                                ),
                                              ),
                                              filled: true,
                                              fillColor:
                                                  AppTheme.of(context)
                                                      .secondaryBackground,
                                            ),
                                            style: GoogleFonts.plusJakartaSans(
                                              color:
                                                  AppTheme.of(context)
                                                      .primaryText,
                                              fontSize: 14.0,
                                            ),
                                            maxLines: null,
                                            keyboardType: TextInputType.number,
                                            validator: _model
                                                .rgFieldTextControllerValidator
                                                .asValidator(context),
                                            inputFormatters: [
                                              _model.rgFieldMask
                                            ],
                                          ),
                                        ),
                                        Padding(
                                          padding: EdgeInsetsDirectional.fromSTEB(16.0, 0.0, 16.0, 0.0),
                                          child: Row(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              // DDD field (flex 2)
                                              Expanded(
                                                flex: 2,
                                                child: TextFormField(
                                                  controller: _model.dddFieldTextController,
                                                  focusNode: _model.dddFieldFocusNode,
                                                  textInputAction: TextInputAction.next,
                                                  keyboardType: TextInputType.number,
                                                  maxLength: 2,
                                                  obscureText: false,
                                                  decoration: InputDecoration(
                                                    isDense: true,
                                                    counterText: "",
                                                    labelText: "DDD",
                                                    labelStyle: GoogleFonts.inter(color: AppTheme.of(context).secondaryText, fontWeight: FontWeight.w600, fontSize: 14.0),
                                                    hintText: "00",
                                                    enabledBorder: OutlineInputBorder(borderSide: const BorderSide(color: Color(0x00000000), width: 1.0), borderRadius: const BorderRadius.only(topLeft: Radius.circular(4.0), topRight: Radius.circular(4.0))),
                                                    focusedBorder: OutlineInputBorder(borderSide: const BorderSide(color: Color(0x00000000), width: 1.0), borderRadius: const BorderRadius.only(topLeft: Radius.circular(4.0), topRight: Radius.circular(4.0))),
                                                    errorBorder: OutlineInputBorder(borderSide: const BorderSide(color: Color(0x00000000), width: 1.0), borderRadius: const BorderRadius.only(topLeft: Radius.circular(4.0), topRight: Radius.circular(4.0))),
                                                    focusedErrorBorder: OutlineInputBorder(borderSide: const BorderSide(color: Color(0x00000000), width: 1.0), borderRadius: const BorderRadius.only(topLeft: Radius.circular(4.0), topRight: Radius.circular(4.0))),
                                                    filled: true,
                                                    fillColor: AppTheme.of(context).secondaryBackground,
                                                  ),
                                                  style: GoogleFonts.plusJakartaSans(color: AppTheme.of(context).primaryText, fontSize: 14.0),
                                                  onChanged: (_) => safeSetState(() {}),
                                                ),
                                              ),
                                              const SizedBox(width: 8.0),
                                              // Numero field (flex 5)
                                              Expanded(
                                                flex: 5,
                                                child: TextFormField(
                                                  controller: _model.telefoneFieldTextController,
                                                  focusNode: _model.telefoneFieldFocusNode,
                                                  onChanged: (_) => EasyDebounce.debounce("_model.telefoneFieldTextController", const Duration(milliseconds: 2000), () async { safeSetState(() {}); }),
                                                  textInputAction: TextInputAction.next,
                                                  obscureText: false,
                                                  keyboardType: TextInputType.phone,
                                                  decoration: InputDecoration(
                                                    isDense: true,
                                                    labelText: "N\u00famero",
                                                    labelStyle: GoogleFonts.inter(color: AppTheme.of(context).secondaryText, fontWeight: FontWeight.w600, fontSize: 14.0),
                                                    hintText: "00000-0000",
                                                    enabledBorder: OutlineInputBorder(borderSide: const BorderSide(color: Color(0x00000000), width: 1.0), borderRadius: const BorderRadius.only(topLeft: Radius.circular(4.0), topRight: Radius.circular(4.0))),
                                                    focusedBorder: OutlineInputBorder(borderSide: const BorderSide(color: Color(0x00000000), width: 1.0), borderRadius: const BorderRadius.only(topLeft: Radius.circular(4.0), topRight: Radius.circular(4.0))),
                                                    errorBorder: OutlineInputBorder(borderSide: const BorderSide(color: Color(0x00000000), width: 1.0), borderRadius: const BorderRadius.only(topLeft: Radius.circular(4.0), topRight: Radius.circular(4.0))),
                                                    focusedErrorBorder: OutlineInputBorder(borderSide: const BorderSide(color: Color(0x00000000), width: 1.0), borderRadius: const BorderRadius.only(topLeft: Radius.circular(4.0), topRight: Radius.circular(4.0))),
                                                    filled: true,
                                                    fillColor: AppTheme.of(context).secondaryBackground,
                                                  ),
                                                  style: GoogleFonts.plusJakartaSans(color: AppTheme.of(context).primaryText, fontSize: 14.0),
                                                  maxLines: null,
                                                  validator: _model.telefoneFieldTextControllerValidator.asValidator(context),
                                                  inputFormatters: [MaskTextInputFormatter(mask: "#####-####")],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Padding(
                                          padding:
                                              EdgeInsetsDirectional.fromSTEB(
                                                  16.0, 0.0, 16.0, 0.0),
                                          child: TextFormField(
                                            controller:
                                                _model.emailFieldTextController,
                                            focusNode:
                                                _model.emailFieldFocusNode,
                                            onChanged: (_) =>
                                                EasyDebounce.debounce(
                                              '_model.emailFieldTextController',
                                              Duration(milliseconds: 2000),
                                              () async {
                                                safeSetState(() {});
                                              },
                                            ),
                                            textInputAction:
                                                TextInputAction.next,
                                            obscureText: false,
                                            decoration: InputDecoration(
                                              isDense: true,
                                              labelText: 'E-mail',
                                              labelStyle: GoogleFonts.inter(
                                                color:
                                                    AppTheme.of(context)
                                                        .secondaryText,
                                                fontWeight: FontWeight.w600,
                                                fontSize: 14.0,
                                              ),
                                              hintText: 'seu@email.com',
                                              enabledBorder: OutlineInputBorder(
                                                borderSide: BorderSide(
                                                  color: Color(0x00000000),
                                                  width: 1.0,
                                                ),
                                                borderRadius:
                                                    const BorderRadius.only(
                                                  topLeft: Radius.circular(4.0),
                                                  topRight:
                                                      Radius.circular(4.0),
                                                ),
                                              ),
                                              focusedBorder: OutlineInputBorder(
                                                borderSide: BorderSide(
                                                  color: Color(0x00000000),
                                                  width: 1.0,
                                                ),
                                                borderRadius:
                                                    const BorderRadius.only(
                                                  topLeft: Radius.circular(4.0),
                                                  topRight:
                                                      Radius.circular(4.0),
                                                ),
                                              ),
                                              errorBorder: OutlineInputBorder(
                                                borderSide: BorderSide(
                                                  color: Color(0x00000000),
                                                  width: 1.0,
                                                ),
                                                borderRadius:
                                                    const BorderRadius.only(
                                                  topLeft: Radius.circular(4.0),
                                                  topRight:
                                                      Radius.circular(4.0),
                                                ),
                                              ),
                                              focusedErrorBorder:
                                                  OutlineInputBorder(
                                                borderSide: BorderSide(
                                                  color: Color(0x00000000),
                                                  width: 1.0,
                                                ),
                                                borderRadius:
                                                    const BorderRadius.only(
                                                  topLeft: Radius.circular(4.0),
                                                  topRight:
                                                      Radius.circular(4.0),
                                                ),
                                              ),
                                              filled: true,
                                              fillColor:
                                                  AppTheme.of(context)
                                                      .secondaryBackground,
                                            ),
                                            style: GoogleFonts.plusJakartaSans(
                                              color:
                                                  AppTheme.of(context)
                                                      .primaryText,
                                              fontSize: 14.0,
                                            ),
                                            maxLines: null,
                                            keyboardType:
                                                TextInputType.emailAddress,
                                            validator: _model
                                                .emailFieldTextControllerValidator
                                                .asValidator(context),
                                          ),
                                        ),
                                        Padding(
                                          padding:
                                              EdgeInsetsDirectional.fromSTEB(
                                                  16.0, 0.0, 16.0, 0.0),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.max,
                                            children: [
                                              Expanded(
                                                child: TextFormField(
                                                  controller: _model
                                                      .ramolFieldTextController,
                                                  focusNode: _model
                                                      .ramolFieldFocusNode,
                                                  textInputAction:
                                                      TextInputAction.next,
                                                  obscureText: false,
                                                  decoration: InputDecoration(
                                                    isDense: true,
                                                    labelText: 'Ramo',
                                                    labelStyle:
                                                        GoogleFonts.inter(
                                                      color:
                                                          AppTheme.of(
                                                                  context)
                                                              .secondaryText,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      fontSize: 14.0,
                                                    ),
                                                    hintText:
                                                        'Ramo de atividade',
                                                    enabledBorder:
                                                        OutlineInputBorder(
                                                      borderSide: BorderSide(
                                                        color:
                                                            Color(0x00000000),
                                                        width: 1.0,
                                                      ),
                                                      borderRadius:
                                                          const BorderRadius
                                                              .only(
                                                        topLeft:
                                                            Radius.circular(
                                                                4.0),
                                                        topRight:
                                                            Radius.circular(
                                                                4.0),
                                                      ),
                                                    ),
                                                    focusedBorder:
                                                        OutlineInputBorder(
                                                      borderSide: BorderSide(
                                                        color:
                                                            Color(0x00000000),
                                                        width: 1.0,
                                                      ),
                                                      borderRadius:
                                                          const BorderRadius
                                                              .only(
                                                        topLeft:
                                                            Radius.circular(
                                                                4.0),
                                                        topRight:
                                                            Radius.circular(
                                                                4.0),
                                                      ),
                                                    ),
                                                    errorBorder:
                                                        OutlineInputBorder(
                                                      borderSide: BorderSide(
                                                        color:
                                                            Color(0x00000000),
                                                        width: 1.0,
                                                      ),
                                                      borderRadius:
                                                          const BorderRadius
                                                              .only(
                                                        topLeft:
                                                            Radius.circular(
                                                                4.0),
                                                        topRight:
                                                            Radius.circular(
                                                                4.0),
                                                      ),
                                                    ),
                                                    focusedErrorBorder:
                                                        OutlineInputBorder(
                                                      borderSide: BorderSide(
                                                        color:
                                                            Color(0x00000000),
                                                        width: 1.0,
                                                      ),
                                                      borderRadius:
                                                          const BorderRadius
                                                              .only(
                                                        topLeft:
                                                            Radius.circular(
                                                                4.0),
                                                        topRight:
                                                            Radius.circular(
                                                                4.0),
                                                      ),
                                                    ),
                                                    filled: true,
                                                    fillColor: AppTheme
                                                            .of(context)
                                                        .secondaryBackground,
                                                  ),
                                                  style: GoogleFonts
                                                      .plusJakartaSans(
                                                    color: AppTheme.of(
                                                            context)
                                                        .primaryText,
                                                    fontSize: 14.0,
                                                  ),
                                                  maxLines: null,
                                                  validator: _model
                                                      .ramolFieldTextControllerValidator
                                                      .asValidator(context),
                                                ),
                                              ),
                                              Expanded(
                                                child: TextFormField(
                                                  controller: _model
                                                      .limiteFieldTextController,
                                                  focusNode: _model
                                                      .limiteFieldFocusNode,
                                                  onChanged: (_) =>
                                                      EasyDebounce.debounce(
                                                    '_model.limiteFieldTextController',
                                                    Duration(
                                                        milliseconds: 2000),
                                                    () async {
                                                      safeSetState(() {});
                                                    },
                                                  ),
                                                  obscureText: false,
                                                  decoration: InputDecoration(
                                                    isDense: true,
                                                    labelText:
                                                        'Limite de Crédito',
                                                    labelStyle:
                                                        GoogleFonts.inter(
                                                      color:
                                                          AppTheme.of(
                                                                  context)
                                                              .secondaryText,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      fontSize: 14.0,
                                                    ),
                                                    hintText: '00,00',
                                                    enabledBorder:
                                                        OutlineInputBorder(
                                                      borderSide: BorderSide(
                                                        color:
                                                            Color(0x00000000),
                                                        width: 1.0,
                                                      ),
                                                      borderRadius:
                                                          const BorderRadius
                                                              .only(
                                                        topLeft:
                                                            Radius.circular(
                                                                4.0),
                                                        topRight:
                                                            Radius.circular(
                                                                4.0),
                                                      ),
                                                    ),
                                                    focusedBorder:
                                                        OutlineInputBorder(
                                                      borderSide: BorderSide(
                                                        color:
                                                            Color(0x00000000),
                                                        width: 1.0,
                                                      ),
                                                      borderRadius:
                                                          const BorderRadius
                                                              .only(
                                                        topLeft:
                                                            Radius.circular(
                                                                4.0),
                                                        topRight:
                                                            Radius.circular(
                                                                4.0),
                                                      ),
                                                    ),
                                                    errorBorder:
                                                        OutlineInputBorder(
                                                      borderSide: BorderSide(
                                                        color:
                                                            Color(0x00000000),
                                                        width: 1.0,
                                                      ),
                                                      borderRadius:
                                                          const BorderRadius
                                                              .only(
                                                        topLeft:
                                                            Radius.circular(
                                                                4.0),
                                                        topRight:
                                                            Radius.circular(
                                                                4.0),
                                                      ),
                                                    ),
                                                    focusedErrorBorder:
                                                        OutlineInputBorder(
                                                      borderSide: BorderSide(
                                                        color:
                                                            Color(0x00000000),
                                                        width: 1.0,
                                                      ),
                                                      borderRadius:
                                                          const BorderRadius
                                                              .only(
                                                        topLeft:
                                                            Radius.circular(
                                                                4.0),
                                                        topRight:
                                                            Radius.circular(
                                                                4.0),
                                                      ),
                                                    ),
                                                    filled: true,
                                                    fillColor: AppTheme
                                                            .of(context)
                                                        .secondaryBackground,
                                                  ),
                                                  style: GoogleFonts
                                                      .plusJakartaSans(
                                                    color: AppTheme.of(
                                                            context)
                                                        .primaryText,
                                                    fontSize: 14.0,
                                                  ),
                                                  textAlign: TextAlign.end,
                                                  maxLines: null,
                                                  keyboardType:
                                                      TextInputType.number,
                                                  validator: _model
                                                      .limiteFieldTextControllerValidator
                                                      .asValidator(context),
                                                ),
                                              ),
                                            ].divide(SizedBox(width: 12.0)),
                                          ),
                                        ),
                                      ]
                                          .divide(SizedBox(height: 12.0))
                                          .addToStart(SizedBox(height: 16.0))
                                          .addToEnd(SizedBox(height: 16.0)),
                                    ),
                                  ),
                                  Column(
                                    mainAxisSize: MainAxisSize.max,
                                    children: [
                                      Padding(
                                        padding: EdgeInsetsDirectional.fromSTEB(
                                            16.0, 0.0, 16.0, 0.0),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.max,
                                          mainAxisAlignment:
                                              MainAxisAlignment.start,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.center,
                                          children: [
                                            Expanded(
                                              flex: 2,
                                              child: TextFormField(
                                                controller: _model
                                                    .cepFieldTextController,
                                                focusNode:
                                                    _model.cepFieldFocusNode,
                                                onChanged: (_) =>
                                                    EasyDebounce.debounce(
                                                  '_model.cepFieldTextController',
                                                  Duration(milliseconds: 1000),
                                                  () async {
                                                    final cep = _model.cepFieldTextController?.text.replaceAll(RegExp(r'[^0-9]'), '') ?? '';
                                                    if (cep.length == 8) {
                                                      try {
                                                        final response = await http.get(Uri.parse('https://viacep.com.br/ws/$cep/json/'));
                                                        if (response.statusCode == 200) {
                                                          final data = json.decode(response.body);
                                                          if (data['erro'] == null) {
                                                            _model.enderecoFieldTextController?.text = data['logradouro'] ?? '';
                                                            _model.bairroFieldTextController?.text = data['bairro'] ?? '';
                                                            _model.cidadeFieldTextController?.text = '${data['localidade']} - ${data['uf']}';
                                                            safeSetState(() {});
                                                          }
                                                        }
                                                      } catch (e) {
                                                        print('Erro ao buscar CEP: $e');
                                                      }
                                                    }
                                                    safeSetState(() {});
                                                  },
                                                ),
                                                textInputAction:
                                                    TextInputAction.send,
                                                obscureText: false,
                                                decoration: InputDecoration(
                                                  isDense: true,
                                                  labelText: 'CEP',
                                                  labelStyle: GoogleFonts.inter(
                                                    color: AppTheme.of(
                                                            context)
                                                        .secondaryText,
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: 14.0,
                                                  ),
                                                  hintText: '00000-000',
                                                  enabledBorder:
                                                      OutlineInputBorder(
                                                    borderSide: BorderSide(
                                                      color: Color(0x00000000),
                                                      width: 1.0,
                                                    ),
                                                    borderRadius:
                                                        const BorderRadius.only(
                                                      topLeft:
                                                          Radius.circular(4.0),
                                                      topRight:
                                                          Radius.circular(4.0),
                                                    ),
                                                  ),
                                                  focusedBorder:
                                                      OutlineInputBorder(
                                                    borderSide: BorderSide(
                                                      color: Color(0x00000000),
                                                      width: 1.0,
                                                    ),
                                                    borderRadius:
                                                        const BorderRadius.only(
                                                      topLeft:
                                                          Radius.circular(4.0),
                                                      topRight:
                                                          Radius.circular(4.0),
                                                    ),
                                                  ),
                                                  errorBorder:
                                                      OutlineInputBorder(
                                                    borderSide: BorderSide(
                                                      color: Color(0x00000000),
                                                      width: 1.0,
                                                    ),
                                                    borderRadius:
                                                        const BorderRadius.only(
                                                      topLeft:
                                                          Radius.circular(4.0),
                                                      topRight:
                                                          Radius.circular(4.0),
                                                    ),
                                                  ),
                                                  focusedErrorBorder:
                                                      OutlineInputBorder(
                                                    borderSide: BorderSide(
                                                      color: Color(0x00000000),
                                                      width: 1.0,
                                                    ),
                                                    borderRadius:
                                                        const BorderRadius.only(
                                                      topLeft:
                                                          Radius.circular(4.0),
                                                      topRight:
                                                          Radius.circular(4.0),
                                                    ),
                                                  ),
                                                  filled: true,
                                                  fillColor:
                                                      AppTheme.of(
                                                              context)
                                                          .secondaryBackground,
                                                ),
                                                style:
                                                    GoogleFonts.plusJakartaSans(
                                                  color: AppTheme.of(
                                                          context)
                                                      .primaryText,
                                                  fontSize: 14.0,
                                                ),
                                                maxLines: null,
                                                keyboardType:
                                                    TextInputType.number,
                                                validator: _model
                                                    .cepFieldTextControllerValidator
                                                    .asValidator(context),
                                                inputFormatters: [
                                                  _model.cepFieldMask
                                                ],
                                              ),
                                            ),
                                            Expanded(
                                              flex: 1,
                                              child: TextFormField(
                                                controller: _model
                                                    .numeroFieldTextController,
                                                focusNode:
                                                    _model.numeroFieldFocusNode,
                                                onChanged: (_) =>
                                                    EasyDebounce.debounce(
                                                  '_model.numeroFieldTextController',
                                                  Duration(milliseconds: 2000),
                                                  () async {
                                                    safeSetState(() {});
                                                  },
                                                ),
                                                textInputAction:
                                                    TextInputAction.next,
                                                obscureText: false,
                                                decoration: InputDecoration(
                                                  isDense: true,
                                                  labelText: 'Número',
                                                  labelStyle: GoogleFonts.inter(
                                                    fontSize: 14.0,
                                                  ),
                                                  enabledBorder:
                                                      OutlineInputBorder(
                                                    borderSide: BorderSide(
                                                      color: Color(0x00000000),
                                                      width: 1.0,
                                                    ),
                                                    borderRadius:
                                                        const BorderRadius.only(
                                                      topLeft:
                                                          Radius.circular(4.0),
                                                      topRight:
                                                          Radius.circular(4.0),
                                                    ),
                                                  ),
                                                  focusedBorder:
                                                      OutlineInputBorder(
                                                    borderSide: BorderSide(
                                                      color: Color(0x00000000),
                                                      width: 1.0,
                                                    ),
                                                    borderRadius:
                                                        const BorderRadius.only(
                                                      topLeft:
                                                          Radius.circular(4.0),
                                                      topRight:
                                                          Radius.circular(4.0),
                                                    ),
                                                  ),
                                                  errorBorder:
                                                      OutlineInputBorder(
                                                    borderSide: BorderSide(
                                                      color: Color(0x00000000),
                                                      width: 1.0,
                                                    ),
                                                    borderRadius:
                                                        const BorderRadius.only(
                                                      topLeft:
                                                          Radius.circular(4.0),
                                                      topRight:
                                                          Radius.circular(4.0),
                                                    ),
                                                  ),
                                                  focusedErrorBorder:
                                                      OutlineInputBorder(
                                                    borderSide: BorderSide(
                                                      color: Color(0x00000000),
                                                      width: 1.0,
                                                    ),
                                                    borderRadius:
                                                        const BorderRadius.only(
                                                      topLeft:
                                                          Radius.circular(4.0),
                                                      topRight:
                                                          Radius.circular(4.0),
                                                    ),
                                                  ),
                                                  filled: true,
                                                  fillColor:
                                                      AppTheme.of(
                                                              context)
                                                          .secondaryBackground,
                                                ),
                                                style:
                                                    GoogleFonts.plusJakartaSans(
                                                  color: AppTheme.of(
                                                          context)
                                                      .primaryText,
                                                  fontSize: 14.0,
                                                ),
                                                maxLines: null,
                                                validator: _model
                                                    .numeroFieldTextControllerValidator
                                                    .asValidator(context),
                                              ),
                                            ),
                                          ].divide(SizedBox(width: 12.0)),
                                        ),
                                      ),
                                      Padding(
                                        padding: EdgeInsetsDirectional.fromSTEB(
                                            16.0, 0.0, 16.0, 0.0),
                                        child: TextFormField(
                                          controller:
                                              _model.bairroFieldTextController,
                                          focusNode:
                                              _model.bairroFieldFocusNode,
                                          onChanged: (_) =>
                                              EasyDebounce.debounce(
                                            '_model.bairroFieldTextController',
                                            Duration(milliseconds: 2000),
                                            () async {
                                              safeSetState(() {});
                                            },
                                          ),
                                          textInputAction: TextInputAction.next,
                                          obscureText: false,
                                          decoration: InputDecoration(
                                            isDense: true,
                                            labelText: 'Bairro',
                                            labelStyle: GoogleFonts.inter(
                                              color:
                                                  AppTheme.of(context)
                                                      .secondaryText,
                                              fontWeight: FontWeight.w600,
                                              fontSize: 14.0,
                                            ),
                                            hintText: 'Bairro',
                                            enabledBorder: OutlineInputBorder(
                                              borderSide: BorderSide(
                                                color: Color(0x00000000),
                                                width: 1.0,
                                              ),
                                              borderRadius:
                                                  const BorderRadius.only(
                                                topLeft: Radius.circular(4.0),
                                                topRight: Radius.circular(4.0),
                                              ),
                                            ),
                                            focusedBorder: OutlineInputBorder(
                                              borderSide: BorderSide(
                                                color: Color(0x00000000),
                                                width: 1.0,
                                              ),
                                              borderRadius:
                                                  const BorderRadius.only(
                                                topLeft: Radius.circular(4.0),
                                                topRight: Radius.circular(4.0),
                                              ),
                                            ),
                                            errorBorder: OutlineInputBorder(
                                              borderSide: BorderSide(
                                                color: Color(0x00000000),
                                                width: 1.0,
                                              ),
                                              borderRadius:
                                                  const BorderRadius.only(
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
                                              borderRadius:
                                                  const BorderRadius.only(
                                                topLeft: Radius.circular(4.0),
                                                topRight: Radius.circular(4.0),
                                              ),
                                            ),
                                            filled: true,
                                            fillColor:
                                                AppTheme.of(context)
                                                    .secondaryBackground,
                                          ),
                                          style: GoogleFonts.plusJakartaSans(
                                            color: AppTheme.of(context)
                                                .primaryText,
                                            fontSize: 14.0,
                                          ),
                                          maxLines: null,
                                          validator: _model
                                              .bairroFieldTextControllerValidator
                                              .asValidator(context),
                                        ),
                                      ),
                                      Padding(
                                        padding: EdgeInsetsDirectional.fromSTEB(
                                            16.0, 0.0, 16.0, 0.0),
                                        child: TextFormField(
                                          controller: _model
                                              .enderecoFieldTextController,
                                          focusNode:
                                              _model.enderecoFieldFocusNode,
                                          onChanged: (_) =>
                                              EasyDebounce.debounce(
                                            '_model.enderecoFieldTextController',
                                            Duration(milliseconds: 2000),
                                            () async {
                                              safeSetState(() {});
                                            },
                                          ),
                                          textInputAction: TextInputAction.next,
                                          obscureText: false,
                                          decoration: InputDecoration(
                                            isDense: true,
                                            labelText: 'Endereço',
                                            labelStyle: GoogleFonts.inter(
                                              color:
                                                  AppTheme.of(context)
                                                      .secondaryText,
                                              fontWeight: FontWeight.w600,
                                              fontSize: 14.0,
                                            ),
                                            hintText: 'Endereço',
                                            enabledBorder: OutlineInputBorder(
                                              borderSide: BorderSide(
                                                color: Color(0x00000000),
                                                width: 1.0,
                                              ),
                                              borderRadius:
                                                  const BorderRadius.only(
                                                topLeft: Radius.circular(4.0),
                                                topRight: Radius.circular(4.0),
                                              ),
                                            ),
                                            focusedBorder: OutlineInputBorder(
                                              borderSide: BorderSide(
                                                color: Color(0x00000000),
                                                width: 1.0,
                                              ),
                                              borderRadius:
                                                  const BorderRadius.only(
                                                topLeft: Radius.circular(4.0),
                                                topRight: Radius.circular(4.0),
                                              ),
                                            ),
                                            errorBorder: OutlineInputBorder(
                                              borderSide: BorderSide(
                                                color: Color(0x00000000),
                                                width: 1.0,
                                              ),
                                              borderRadius:
                                                  const BorderRadius.only(
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
                                              borderRadius:
                                                  const BorderRadius.only(
                                                topLeft: Radius.circular(4.0),
                                                topRight: Radius.circular(4.0),
                                              ),
                                            ),
                                            filled: true,
                                            fillColor:
                                                AppTheme.of(context)
                                                    .secondaryBackground,
                                          ),
                                          style: GoogleFonts.plusJakartaSans(
                                            color: AppTheme.of(context)
                                                .primaryText,
                                            fontSize: 14.0,
                                          ),
                                          maxLines: null,
                                          validator: _model
                                              .enderecoFieldTextControllerValidator
                                              .asValidator(context),
                                        ),
                                      ),
                                      Padding(
                                        padding: EdgeInsetsDirectional.fromSTEB(
                                            16.0, 0.0, 16.0, 0.0),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.max,
                                          mainAxisAlignment:
                                              MainAxisAlignment.start,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.center,
                                          children: [
                                            Expanded(
                                              flex: 3,
                                              child: TextFormField(
                                                controller: _model
                                                    .cidadeFieldTextController,
                                                focusNode:
                                                    _model.cidadeFieldFocusNode,
                                                onChanged: (_) =>
                                                    EasyDebounce.debounce(
                                                  '_model.cidadeFieldTextController',
                                                  Duration(milliseconds: 2000),
                                                  () async {
                                                    safeSetState(() {});
                                                  },
                                                ),
                                                textInputAction:
                                                    TextInputAction.next,
                                                obscureText: false,
                                                decoration: InputDecoration(
                                                  isDense: true,
                                                  labelText: 'Cidade',
                                                  labelStyle: GoogleFonts.inter(
                                                    color: AppTheme.of(
                                                            context)
                                                        .secondaryText,
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: 14.0,
                                                  ),
                                                  hintText: 'Cidade',
                                                  enabledBorder:
                                                      OutlineInputBorder(
                                                    borderSide: BorderSide(
                                                      color: Color(0x00000000),
                                                      width: 1.0,
                                                    ),
                                                    borderRadius:
                                                        const BorderRadius.only(
                                                      topLeft:
                                                          Radius.circular(4.0),
                                                      topRight:
                                                          Radius.circular(4.0),
                                                    ),
                                                  ),
                                                  focusedBorder:
                                                      OutlineInputBorder(
                                                    borderSide: BorderSide(
                                                      color: Color(0x00000000),
                                                      width: 1.0,
                                                    ),
                                                    borderRadius:
                                                        const BorderRadius.only(
                                                      topLeft:
                                                          Radius.circular(4.0),
                                                      topRight:
                                                          Radius.circular(4.0),
                                                    ),
                                                  ),
                                                  errorBorder:
                                                      OutlineInputBorder(
                                                    borderSide: BorderSide(
                                                      color: Color(0x00000000),
                                                      width: 1.0,
                                                    ),
                                                    borderRadius:
                                                        const BorderRadius.only(
                                                      topLeft:
                                                          Radius.circular(4.0),
                                                      topRight:
                                                          Radius.circular(4.0),
                                                    ),
                                                  ),
                                                  focusedErrorBorder:
                                                      OutlineInputBorder(
                                                    borderSide: BorderSide(
                                                      color: Color(0x00000000),
                                                      width: 1.0,
                                                    ),
                                                    borderRadius:
                                                        const BorderRadius.only(
                                                      topLeft:
                                                          Radius.circular(4.0),
                                                      topRight:
                                                          Radius.circular(4.0),
                                                    ),
                                                  ),
                                                  filled: true,
                                                  fillColor:
                                                      AppTheme.of(
                                                              context)
                                                          .secondaryBackground,
                                                ),
                                                style:
                                                    GoogleFonts.plusJakartaSans(
                                                  color: AppTheme.of(
                                                          context)
                                                      .primaryText,
                                                  fontSize: 14.0,
                                                ),
                                                maxLines: null,
                                                validator: _model
                                                    .cidadeFieldTextControllerValidator
                                                    .asValidator(context),
                                              ),
                                            ),
                                            Expanded(
                                              flex: 1,
                                              child:
                                                  AppDropDown<String>(
                                                controller: _model
                                                        .ufDropdownValueController ??=
                                                    FormFieldController<String>(
                                                  _model.ufDropdownValue ??=
                                                      valueOrDefault<String>(
                                                    _model.cliData?.cli00Estsgl,
                                                    'UF',
                                                  ),
                                                ),
                                                options: [
                                                  'AC',
                                                  'AL',
                                                  'AP',
                                                  'AM',
                                                  'BA',
                                                  'CE',
                                                  'DF',
                                                  'ES',
                                                  'GO',
                                                  'MA',
                                                  'MT',
                                                  'MS',
                                                  'MG',
                                                  'PA',
                                                  'PB',
                                                  'PR',
                                                  'PE',
                                                  'PI',
                                                  'RJ',
                                                  'RN',
                                                  'RS',
                                                  'RO',
                                                  'RR',
                                                  'SC',
                                                  'SP',
                                                  'SE',
                                                  'TO'
                                                ],
                                                onChanged: (val) async {
                                                  safeSetState(() => _model
                                                      .ufDropdownValue = val);
                                                  safeSetState(() {});
                                                },
                                                height: 42.0,
                                                textStyle:
                                                    AppTheme.of(context)
                                                        .bodyMedium
                                                        .override(
                                                          font:
                                                              GoogleFonts.inter(
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
                                                        ),
                                                hintText: 'UF',
                                                icon: Icon(
                                                  Icons
                                                      .keyboard_arrow_down_rounded,
                                                  color: AppTheme.of(
                                                          context)
                                                      .secondaryText,
                                                  size: 24.0,
                                                ),
                                                fillColor:
                                                    AppTheme.of(context)
                                                        .secondaryBackground,
                                                elevation: 2.0,
                                                borderColor:
                                                    AppTheme.of(context)
                                                        .alternate,
                                                borderWidth: 1.0,
                                                borderRadius: 0.0,
                                                margin: EdgeInsetsDirectional
                                                    .fromSTEB(
                                                        12.0, 0.0, 12.0, 0.0),
                                                hidesUnderline: true,
                                                isOverButton: false,
                                                isSearchable: false,
                                                isMultiSelect: false,
                                                labelText: 'UF',
                                                labelTextStyle: TextStyle(),
                                              ),
                                            ),
                                          ].divide(SizedBox(width: 12.0)),
                                        ),
                                      ),
                                    ]
                                        .divide(SizedBox(height: 16.0))
                                        .addToStart(SizedBox(height: 16.0))
                                        .addToEnd(SizedBox(height: 16.0)),
                                  ),
                                  SingleChildScrollView(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.max,
                                      children: [
                                        Padding(
                                          padding:
                                              EdgeInsetsDirectional.fromSTEB(
                                                  16.0, 0.0, 16.0, 0.0),
                                          child: TextFormField(
                                            controller: _model
                                                .nomePropFieldTextController,
                                            focusNode:
                                                _model.nomePropFieldFocusNode,
                                            onChanged: (_) =>
                                                EasyDebounce.debounce(
                                              '_model.nomePropFieldTextController',
                                              Duration(milliseconds: 2000),
                                              () async {
                                                safeSetState(() {});
                                              },
                                            ),
                                            textInputAction:
                                                TextInputAction.next,
                                            obscureText: false,
                                            decoration: InputDecoration(
                                              isDense: true,
                                              labelText: 'Nome do Proprietário',
                                              labelStyle: GoogleFonts.inter(
                                                color:
                                                    AppTheme.of(context)
                                                        .secondaryText,
                                                fontWeight: FontWeight.w600,
                                                fontSize: 14.0,
                                              ),
                                              alignLabelWithHint: false,
                                              hintText: 'Nome',
                                              enabledBorder: OutlineInputBorder(
                                                borderSide: BorderSide(
                                                  color: Color(0x00000000),
                                                  width: 1.0,
                                                ),
                                                borderRadius:
                                                    const BorderRadius.only(
                                                  topLeft: Radius.circular(4.0),
                                                  topRight:
                                                      Radius.circular(4.0),
                                                ),
                                              ),
                                              focusedBorder: OutlineInputBorder(
                                                borderSide: BorderSide(
                                                  color: Color(0x00000000),
                                                  width: 1.0,
                                                ),
                                                borderRadius:
                                                    const BorderRadius.only(
                                                  topLeft: Radius.circular(4.0),
                                                  topRight:
                                                      Radius.circular(4.0),
                                                ),
                                              ),
                                              errorBorder: OutlineInputBorder(
                                                borderSide: BorderSide(
                                                  color: Color(0x00000000),
                                                  width: 1.0,
                                                ),
                                                borderRadius:
                                                    const BorderRadius.only(
                                                  topLeft: Radius.circular(4.0),
                                                  topRight:
                                                      Radius.circular(4.0),
                                                ),
                                              ),
                                              focusedErrorBorder:
                                                  OutlineInputBorder(
                                                borderSide: BorderSide(
                                                  color: Color(0x00000000),
                                                  width: 1.0,
                                                ),
                                                borderRadius:
                                                    const BorderRadius.only(
                                                  topLeft: Radius.circular(4.0),
                                                  topRight:
                                                      Radius.circular(4.0),
                                                ),
                                              ),
                                              filled: true,
                                              fillColor:
                                                  AppTheme.of(context)
                                                      .secondaryBackground,
                                            ),
                                            style: GoogleFonts.plusJakartaSans(
                                              color:
                                                  AppTheme.of(context)
                                                      .primaryText,
                                              fontSize: 14.0,
                                            ),
                                            maxLines: null,
                                            validator: _model
                                                .nomePropFieldTextControllerValidator
                                                .asValidator(context),
                                          ),
                                        ),
                                        Padding(
                                          padding:
                                              EdgeInsetsDirectional.fromSTEB(
                                                  16.0, 0.0, 16.0, 0.0),
                                          child: TextFormField(
                                            controller: _model
                                                .enderecoPropFieldTextController,
                                            focusNode: _model
                                                .enderecoPropFieldFocusNode,
                                            onChanged: (_) =>
                                                EasyDebounce.debounce(
                                              '_model.enderecoPropFieldTextController',
                                              Duration(milliseconds: 2000),
                                              () async {
                                                safeSetState(() {});
                                              },
                                            ),
                                            textInputAction:
                                                TextInputAction.next,
                                            obscureText: false,
                                            decoration: InputDecoration(
                                              isDense: true,
                                              labelText: 'Endereço',
                                              labelStyle: GoogleFonts.inter(
                                                color:
                                                    AppTheme.of(context)
                                                        .secondaryText,
                                                fontWeight: FontWeight.w600,
                                                fontSize: 14.0,
                                              ),
                                              hintText: 'Endereço',
                                              enabledBorder: OutlineInputBorder(
                                                borderSide: BorderSide(
                                                  color: Color(0x00000000),
                                                  width: 1.0,
                                                ),
                                                borderRadius:
                                                    const BorderRadius.only(
                                                  topLeft: Radius.circular(4.0),
                                                  topRight:
                                                      Radius.circular(4.0),
                                                ),
                                              ),
                                              focusedBorder: OutlineInputBorder(
                                                borderSide: BorderSide(
                                                  color: Color(0x00000000),
                                                  width: 1.0,
                                                ),
                                                borderRadius:
                                                    const BorderRadius.only(
                                                  topLeft: Radius.circular(4.0),
                                                  topRight:
                                                      Radius.circular(4.0),
                                                ),
                                              ),
                                              errorBorder: OutlineInputBorder(
                                                borderSide: BorderSide(
                                                  color: Color(0x00000000),
                                                  width: 1.0,
                                                ),
                                                borderRadius:
                                                    const BorderRadius.only(
                                                  topLeft: Radius.circular(4.0),
                                                  topRight:
                                                      Radius.circular(4.0),
                                                ),
                                              ),
                                              focusedErrorBorder:
                                                  OutlineInputBorder(
                                                borderSide: BorderSide(
                                                  color: Color(0x00000000),
                                                  width: 1.0,
                                                ),
                                                borderRadius:
                                                    const BorderRadius.only(
                                                  topLeft: Radius.circular(4.0),
                                                  topRight:
                                                      Radius.circular(4.0),
                                                ),
                                              ),
                                              filled: true,
                                              fillColor:
                                                  AppTheme.of(context)
                                                      .secondaryBackground,
                                            ),
                                            style: GoogleFonts.plusJakartaSans(
                                              color:
                                                  AppTheme.of(context)
                                                      .primaryText,
                                              fontSize: 14.0,
                                            ),
                                            maxLines: null,
                                            validator: _model
                                                .enderecoPropFieldTextControllerValidator
                                                .asValidator(context),
                                          ),
                                        ),
                                        Padding(
                                          padding:
                                              EdgeInsetsDirectional.fromSTEB(
                                                  16.0, 0.0, 16.0, 0.0),
                                          child: TextFormField(
                                            controller: _model
                                                .bairroPropFieldTextController,
                                            focusNode:
                                                _model.bairroPropFieldFocusNode,
                                            onChanged: (_) =>
                                                EasyDebounce.debounce(
                                              '_model.bairroPropFieldTextController',
                                              Duration(milliseconds: 2000),
                                              () async {
                                                safeSetState(() {});
                                              },
                                            ),
                                            textInputAction:
                                                TextInputAction.next,
                                            obscureText: false,
                                            decoration: InputDecoration(
                                              isDense: true,
                                              labelText: 'Bairro',
                                              labelStyle: GoogleFonts.inter(
                                                color:
                                                    AppTheme.of(context)
                                                        .secondaryText,
                                                fontWeight: FontWeight.w600,
                                                fontSize: 14.0,
                                              ),
                                              hintText: 'Bairro',
                                              enabledBorder: OutlineInputBorder(
                                                borderSide: BorderSide(
                                                  color: Color(0x00000000),
                                                  width: 1.0,
                                                ),
                                                borderRadius:
                                                    const BorderRadius.only(
                                                  topLeft: Radius.circular(4.0),
                                                  topRight:
                                                      Radius.circular(4.0),
                                                ),
                                              ),
                                              focusedBorder: OutlineInputBorder(
                                                borderSide: BorderSide(
                                                  color: Color(0x00000000),
                                                  width: 1.0,
                                                ),
                                                borderRadius:
                                                    const BorderRadius.only(
                                                  topLeft: Radius.circular(4.0),
                                                  topRight:
                                                      Radius.circular(4.0),
                                                ),
                                              ),
                                              errorBorder: OutlineInputBorder(
                                                borderSide: BorderSide(
                                                  color: Color(0x00000000),
                                                  width: 1.0,
                                                ),
                                                borderRadius:
                                                    const BorderRadius.only(
                                                  topLeft: Radius.circular(4.0),
                                                  topRight:
                                                      Radius.circular(4.0),
                                                ),
                                              ),
                                              focusedErrorBorder:
                                                  OutlineInputBorder(
                                                borderSide: BorderSide(
                                                  color: Color(0x00000000),
                                                  width: 1.0,
                                                ),
                                                borderRadius:
                                                    const BorderRadius.only(
                                                  topLeft: Radius.circular(4.0),
                                                  topRight:
                                                      Radius.circular(4.0),
                                                ),
                                              ),
                                              filled: true,
                                              fillColor:
                                                  AppTheme.of(context)
                                                      .secondaryBackground,
                                            ),
                                            style: GoogleFonts.plusJakartaSans(
                                              color:
                                                  AppTheme.of(context)
                                                      .primaryText,
                                              fontSize: 14.0,
                                            ),
                                            maxLines: null,
                                            validator: _model
                                                .bairroPropFieldTextControllerValidator
                                                .asValidator(context),
                                          ),
                                        ),
                                        Padding(
                                          padding:
                                              EdgeInsetsDirectional.fromSTEB(
                                                  16.0, 0.0, 16.0, 0.0),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.max,
                                            mainAxisAlignment:
                                                MainAxisAlignment.start,
                                            crossAxisAlignment:
                                                CrossAxisAlignment.center,
                                            children: [
                                              Expanded(
                                                flex: 3,
                                                child: TextFormField(
                                                  controller: _model
                                                      .cidadePropFieldTextController,
                                                  focusNode: _model
                                                      .cidadePropFieldFocusNode,
                                                  onChanged: (_) =>
                                                      EasyDebounce.debounce(
                                                    '_model.cidadePropFieldTextController',
                                                    Duration(
                                                        milliseconds: 2000),
                                                    () async {
                                                      safeSetState(() {});
                                                    },
                                                  ),
                                                  textInputAction:
                                                      TextInputAction.next,
                                                  obscureText: false,
                                                  decoration: InputDecoration(
                                                    isDense: true,
                                                    labelText: 'Cidade',
                                                    labelStyle:
                                                        GoogleFonts.inter(
                                                      color:
                                                          AppTheme.of(
                                                                  context)
                                                              .secondaryText,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      fontSize: 14.0,
                                                    ),
                                                    hintText: 'Cidade',
                                                    enabledBorder:
                                                        OutlineInputBorder(
                                                      borderSide: BorderSide(
                                                        color:
                                                            Color(0x00000000),
                                                        width: 1.0,
                                                      ),
                                                      borderRadius:
                                                          const BorderRadius
                                                              .only(
                                                        topLeft:
                                                            Radius.circular(
                                                                4.0),
                                                        topRight:
                                                            Radius.circular(
                                                                4.0),
                                                      ),
                                                    ),
                                                    focusedBorder:
                                                        OutlineInputBorder(
                                                      borderSide: BorderSide(
                                                        color:
                                                            Color(0x00000000),
                                                        width: 1.0,
                                                      ),
                                                      borderRadius:
                                                          const BorderRadius
                                                              .only(
                                                        topLeft:
                                                            Radius.circular(
                                                                4.0),
                                                        topRight:
                                                            Radius.circular(
                                                                4.0),
                                                      ),
                                                    ),
                                                    errorBorder:
                                                        OutlineInputBorder(
                                                      borderSide: BorderSide(
                                                        color:
                                                            Color(0x00000000),
                                                        width: 1.0,
                                                      ),
                                                      borderRadius:
                                                          const BorderRadius
                                                              .only(
                                                        topLeft:
                                                            Radius.circular(
                                                                4.0),
                                                        topRight:
                                                            Radius.circular(
                                                                4.0),
                                                      ),
                                                    ),
                                                    focusedErrorBorder:
                                                        OutlineInputBorder(
                                                      borderSide: BorderSide(
                                                        color:
                                                            Color(0x00000000),
                                                        width: 1.0,
                                                      ),
                                                      borderRadius:
                                                          const BorderRadius
                                                              .only(
                                                        topLeft:
                                                            Radius.circular(
                                                                4.0),
                                                        topRight:
                                                            Radius.circular(
                                                                4.0),
                                                      ),
                                                    ),
                                                    filled: true,
                                                    fillColor: AppTheme
                                                            .of(context)
                                                        .secondaryBackground,
                                                  ),
                                                  style: GoogleFonts
                                                      .plusJakartaSans(
                                                    color: AppTheme.of(
                                                            context)
                                                        .primaryText,
                                                    fontSize: 14.0,
                                                  ),
                                                  maxLines: null,
                                                  validator: _model
                                                      .cidadePropFieldTextControllerValidator
                                                      .asValidator(context),
                                                ),
                                              ),
                                              Expanded(
                                                flex: 1,
                                                child:
                                                    AppDropDown<String>(
                                                  controller: _model
                                                          .ufPropDropdownValueController ??=
                                                      FormFieldController<
                                                          String>(null),
                                                  options: [
                                                    'AC',
                                                    'AL',
                                                    'AP',
                                                    'AM',
                                                    'BA',
                                                    'CE',
                                                    'DF',
                                                    'ES',
                                                    'GO',
                                                    'MA',
                                                    'MT',
                                                    'MS',
                                                    'MG',
                                                    'PA',
                                                    'PB',
                                                    'PR',
                                                    'PE',
                                                    'PI',
                                                    'RJ',
                                                    'RN',
                                                    'RS',
                                                    'RO',
                                                    'RR',
                                                    'SC',
                                                    'SP',
                                                    'SE',
                                                    'TO'
                                                  ],
                                                  onChanged: (val) async {
                                                    safeSetState(() => _model
                                                            .ufPropDropdownValue =
                                                        val);
                                                    safeSetState(() {});
                                                  },
                                                  height: 42.0,
                                                  textStyle: AppTheme
                                                          .of(context)
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
                                                      ),
                                                  hintText: 'UF',
                                                  icon: Icon(
                                                    Icons
                                                        .keyboard_arrow_down_rounded,
                                                    color: AppTheme.of(
                                                            context)
                                                        .secondaryText,
                                                    size: 24.0,
                                                  ),
                                                  fillColor:
                                                      AppTheme.of(
                                                              context)
                                                          .secondaryBackground,
                                                  elevation: 2.0,
                                                  borderColor:
                                                      AppTheme.of(
                                                              context)
                                                          .alternate,
                                                  borderWidth: 1.0,
                                                  borderRadius: 0.0,
                                                  margin: EdgeInsetsDirectional
                                                      .fromSTEB(
                                                          12.0, 0.0, 12.0, 0.0),
                                                  hidesUnderline: true,
                                                  isOverButton: false,
                                                  isSearchable: false,
                                                  isMultiSelect: false,
                                                  labelText: 'UF',
                                                  labelTextStyle: TextStyle(),
                                                ),
                                              ),
                                            ].divide(SizedBox(width: 12.0)),
                                          ),
                                        ),
                                        Padding(
                                          padding:
                                              EdgeInsetsDirectional.fromSTEB(
                                                  16.0, 0.0, 16.0, 0.0),
                                          child: TextFormField(
                                            controller: _model
                                                .rgPropFieldTextController,
                                            focusNode:
                                                _model.rgPropFieldFocusNode,
                                            onChanged: (_) =>
                                                EasyDebounce.debounce(
                                              '_model.rgPropFieldTextController',
                                              Duration(milliseconds: 2000),
                                              () async {
                                                safeSetState(() {});
                                              },
                                            ),
                                            textInputAction:
                                                TextInputAction.next,
                                            obscureText: false,
                                            decoration: InputDecoration(
                                              isDense: true,
                                              labelText: 'RG',
                                              labelStyle: GoogleFonts.inter(
                                                color:
                                                    AppTheme.of(context)
                                                        .secondaryText,
                                                fontWeight: FontWeight.w600,
                                                fontSize: 14.0,
                                              ),
                                              hintText: '000.000.00000-0',
                                              enabledBorder: OutlineInputBorder(
                                                borderSide: BorderSide(
                                                  color: Color(0x00000000),
                                                  width: 1.0,
                                                ),
                                                borderRadius:
                                                    const BorderRadius.only(
                                                  topLeft: Radius.circular(4.0),
                                                  topRight:
                                                      Radius.circular(4.0),
                                                ),
                                              ),
                                              focusedBorder: OutlineInputBorder(
                                                borderSide: BorderSide(
                                                  color: Color(0x00000000),
                                                  width: 1.0,
                                                ),
                                                borderRadius:
                                                    const BorderRadius.only(
                                                  topLeft: Radius.circular(4.0),
                                                  topRight:
                                                      Radius.circular(4.0),
                                                ),
                                              ),
                                              errorBorder: OutlineInputBorder(
                                                borderSide: BorderSide(
                                                  color: Color(0x00000000),
                                                  width: 1.0,
                                                ),
                                                borderRadius:
                                                    const BorderRadius.only(
                                                  topLeft: Radius.circular(4.0),
                                                  topRight:
                                                      Radius.circular(4.0),
                                                ),
                                              ),
                                              focusedErrorBorder:
                                                  OutlineInputBorder(
                                                borderSide: BorderSide(
                                                  color: Color(0x00000000),
                                                  width: 1.0,
                                                ),
                                                borderRadius:
                                                    const BorderRadius.only(
                                                  topLeft: Radius.circular(4.0),
                                                  topRight:
                                                      Radius.circular(4.0),
                                                ),
                                              ),
                                              filled: true,
                                              fillColor:
                                                  AppTheme.of(context)
                                                      .secondaryBackground,
                                            ),
                                            style: GoogleFonts.plusJakartaSans(
                                              color:
                                                  AppTheme.of(context)
                                                      .primaryText,
                                              fontSize: 14.0,
                                            ),
                                            maxLines: null,
                                            keyboardType: TextInputType.number,
                                            validator: _model
                                                .rgPropFieldTextControllerValidator
                                                .asValidator(context),
                                            inputFormatters: [
                                              _model.rgPropFieldMask
                                            ],
                                          ),
                                        ),
                                        Padding(
                                          padding:
                                              EdgeInsetsDirectional.fromSTEB(
                                                  16.0, 0.0, 16.0, 0.0),
                                          child: TextFormField(
                                            controller: _model
                                                .cpfPropFieldTextController,
                                            focusNode:
                                                _model.cpfPropFieldFocusNode,
                                            onChanged: (_) =>
                                                EasyDebounce.debounce(
                                              '_model.cpfPropFieldTextController',
                                              Duration(milliseconds: 2000),
                                              () async {
                                                safeSetState(() {});
                                              },
                                            ),
                                            textInputAction:
                                                TextInputAction.next,
                                            obscureText: false,
                                            decoration: InputDecoration(
                                              isDense: true,
                                              labelText: 'CPF',
                                              labelStyle: GoogleFonts.inter(
                                                color:
                                                    AppTheme.of(context)
                                                        .secondaryText,
                                                fontWeight: FontWeight.w600,
                                                fontSize: 14.0,
                                              ),
                                              hintText: '000.000.000-00',
                                              enabledBorder: OutlineInputBorder(
                                                borderSide: BorderSide(
                                                  color: Color(0x00000000),
                                                  width: 1.0,
                                                ),
                                                borderRadius:
                                                    const BorderRadius.only(
                                                  topLeft: Radius.circular(4.0),
                                                  topRight:
                                                      Radius.circular(4.0),
                                                ),
                                              ),
                                              focusedBorder: OutlineInputBorder(
                                                borderSide: BorderSide(
                                                  color: Color(0x00000000),
                                                  width: 1.0,
                                                ),
                                                borderRadius:
                                                    const BorderRadius.only(
                                                  topLeft: Radius.circular(4.0),
                                                  topRight:
                                                      Radius.circular(4.0),
                                                ),
                                              ),
                                              errorBorder: OutlineInputBorder(
                                                borderSide: BorderSide(
                                                  color: Color(0x00000000),
                                                  width: 1.0,
                                                ),
                                                borderRadius:
                                                    const BorderRadius.only(
                                                  topLeft: Radius.circular(4.0),
                                                  topRight:
                                                      Radius.circular(4.0),
                                                ),
                                              ),
                                              focusedErrorBorder:
                                                  OutlineInputBorder(
                                                borderSide: BorderSide(
                                                  color: Color(0x00000000),
                                                  width: 1.0,
                                                ),
                                                borderRadius:
                                                    const BorderRadius.only(
                                                  topLeft: Radius.circular(4.0),
                                                  topRight:
                                                      Radius.circular(4.0),
                                                ),
                                              ),
                                              filled: true,
                                              fillColor:
                                                  AppTheme.of(context)
                                                      .secondaryBackground,
                                            ),
                                            style: GoogleFonts.plusJakartaSans(
                                              color:
                                                  AppTheme.of(context)
                                                      .primaryText,
                                              fontSize: 14.0,
                                            ),
                                            maxLines: null,
                                            keyboardType: TextInputType.number,
                                            validator: _model
                                                .cpfPropFieldTextControllerValidator
                                                .asValidator(context),
                                            inputFormatters: [
                                              _model.cpfPropFieldMask
                                            ],
                                          ),
                                        ),
                                        SizedBox(
                                          width: 320.0,
                                          child: Divider(
                                            thickness: 2.0,
                                            color: AppTheme.of(context)
                                                .tertiary,
                                          ),
                                        ),
                                        Padding(
                                          padding:
                                              EdgeInsetsDirectional.fromSTEB(
                                                  16.0, 0.0, 16.0, 0.0),
                                          child: TextFormField(
                                            controller: _model
                                                .nomePropConjFieldTextController,
                                            focusNode: _model
                                                .nomePropConjFieldFocusNode,
                                            onChanged: (_) =>
                                                EasyDebounce.debounce(
                                              '_model.nomePropConjFieldTextController',
                                              Duration(milliseconds: 2000),
                                              () async {
                                                safeSetState(() {});
                                              },
                                            ),
                                            textInputAction:
                                                TextInputAction.next,
                                            obscureText: false,
                                            decoration: InputDecoration(
                                              isDense: true,
                                              labelText: 'Nome do Proprietário',
                                              labelStyle: GoogleFonts.inter(
                                                color:
                                                    AppTheme.of(context)
                                                        .secondaryText,
                                                fontWeight: FontWeight.w600,
                                                fontSize: 14.0,
                                              ),
                                              alignLabelWithHint: false,
                                              hintText: 'Nome',
                                              enabledBorder: OutlineInputBorder(
                                                borderSide: BorderSide(
                                                  color: Color(0x00000000),
                                                  width: 1.0,
                                                ),
                                                borderRadius:
                                                    const BorderRadius.only(
                                                  topLeft: Radius.circular(4.0),
                                                  topRight:
                                                      Radius.circular(4.0),
                                                ),
                                              ),
                                              focusedBorder: OutlineInputBorder(
                                                borderSide: BorderSide(
                                                  color: Color(0x00000000),
                                                  width: 1.0,
                                                ),
                                                borderRadius:
                                                    const BorderRadius.only(
                                                  topLeft: Radius.circular(4.0),
                                                  topRight:
                                                      Radius.circular(4.0),
                                                ),
                                              ),
                                              errorBorder: OutlineInputBorder(
                                                borderSide: BorderSide(
                                                  color: Color(0x00000000),
                                                  width: 1.0,
                                                ),
                                                borderRadius:
                                                    const BorderRadius.only(
                                                  topLeft: Radius.circular(4.0),
                                                  topRight:
                                                      Radius.circular(4.0),
                                                ),
                                              ),
                                              focusedErrorBorder:
                                                  OutlineInputBorder(
                                                borderSide: BorderSide(
                                                  color: Color(0x00000000),
                                                  width: 1.0,
                                                ),
                                                borderRadius:
                                                    const BorderRadius.only(
                                                  topLeft: Radius.circular(4.0),
                                                  topRight:
                                                      Radius.circular(4.0),
                                                ),
                                              ),
                                              filled: true,
                                              fillColor:
                                                  AppTheme.of(context)
                                                      .secondaryBackground,
                                            ),
                                            style: GoogleFonts.plusJakartaSans(
                                              color:
                                                  AppTheme.of(context)
                                                      .primaryText,
                                              fontSize: 14.0,
                                            ),
                                            maxLines: null,
                                            validator: _model
                                                .nomePropConjFieldTextControllerValidator
                                                .asValidator(context),
                                          ),
                                        ),
                                        Padding(
                                          padding:
                                              EdgeInsetsDirectional.fromSTEB(
                                                  16.0, 0.0, 16.0, 0.0),
                                          child: TextFormField(
                                            controller: _model
                                                .rgPropConjFieldTextController,
                                            focusNode:
                                                _model.rgPropConjFieldFocusNode,
                                            onChanged: (_) =>
                                                EasyDebounce.debounce(
                                              '_model.rgPropConjFieldTextController',
                                              Duration(milliseconds: 2000),
                                              () async {
                                                safeSetState(() {});
                                              },
                                            ),
                                            textInputAction:
                                                TextInputAction.next,
                                            obscureText: false,
                                            decoration: InputDecoration(
                                              isDense: true,
                                              labelText: 'RG',
                                              labelStyle: GoogleFonts.inter(
                                                color:
                                                    AppTheme.of(context)
                                                        .secondaryText,
                                                fontWeight: FontWeight.w600,
                                                fontSize: 14.0,
                                              ),
                                              hintText: '000.000.00000-0',
                                              enabledBorder: OutlineInputBorder(
                                                borderSide: BorderSide(
                                                  color: Color(0x00000000),
                                                  width: 1.0,
                                                ),
                                                borderRadius:
                                                    const BorderRadius.only(
                                                  topLeft: Radius.circular(4.0),
                                                  topRight:
                                                      Radius.circular(4.0),
                                                ),
                                              ),
                                              focusedBorder: OutlineInputBorder(
                                                borderSide: BorderSide(
                                                  color: Color(0x00000000),
                                                  width: 1.0,
                                                ),
                                                borderRadius:
                                                    const BorderRadius.only(
                                                  topLeft: Radius.circular(4.0),
                                                  topRight:
                                                      Radius.circular(4.0),
                                                ),
                                              ),
                                              errorBorder: OutlineInputBorder(
                                                borderSide: BorderSide(
                                                  color: Color(0x00000000),
                                                  width: 1.0,
                                                ),
                                                borderRadius:
                                                    const BorderRadius.only(
                                                  topLeft: Radius.circular(4.0),
                                                  topRight:
                                                      Radius.circular(4.0),
                                                ),
                                              ),
                                              focusedErrorBorder:
                                                  OutlineInputBorder(
                                                borderSide: BorderSide(
                                                  color: Color(0x00000000),
                                                  width: 1.0,
                                                ),
                                                borderRadius:
                                                    const BorderRadius.only(
                                                  topLeft: Radius.circular(4.0),
                                                  topRight:
                                                      Radius.circular(4.0),
                                                ),
                                              ),
                                              filled: true,
                                              fillColor:
                                                  AppTheme.of(context)
                                                      .secondaryBackground,
                                            ),
                                            style: GoogleFonts.plusJakartaSans(
                                              color:
                                                  AppTheme.of(context)
                                                      .primaryText,
                                              fontSize: 14.0,
                                            ),
                                            maxLines: null,
                                            keyboardType: TextInputType.number,
                                            validator: _model
                                                .rgPropConjFieldTextControllerValidator
                                                .asValidator(context),
                                            inputFormatters: [
                                              _model.rgPropConjFieldMask
                                            ],
                                          ),
                                        ),
                                        Padding(
                                          padding:
                                              EdgeInsetsDirectional.fromSTEB(
                                                  16.0, 0.0, 16.0, 0.0),
                                          child: TextFormField(
                                            controller: _model
                                                .cpfPropConjFieldTextController,
                                            focusNode: _model
                                                .cpfPropConjFieldFocusNode,
                                            onChanged: (_) =>
                                                EasyDebounce.debounce(
                                              '_model.cpfPropConjFieldTextController',
                                              Duration(milliseconds: 2000),
                                              () async {
                                                safeSetState(() {});
                                              },
                                            ),
                                            textInputAction:
                                                TextInputAction.next,
                                            obscureText: false,
                                            decoration: InputDecoration(
                                              isDense: true,
                                              labelText: 'CPF',
                                              labelStyle: GoogleFonts.inter(
                                                color:
                                                    AppTheme.of(context)
                                                        .secondaryText,
                                                fontWeight: FontWeight.w600,
                                                fontSize: 14.0,
                                              ),
                                              hintText: '000.000.000-00',
                                              enabledBorder: OutlineInputBorder(
                                                borderSide: BorderSide(
                                                  color: Color(0x00000000),
                                                  width: 1.0,
                                                ),
                                                borderRadius:
                                                    const BorderRadius.only(
                                                  topLeft: Radius.circular(4.0),
                                                  topRight:
                                                      Radius.circular(4.0),
                                                ),
                                              ),
                                              focusedBorder: OutlineInputBorder(
                                                borderSide: BorderSide(
                                                  color: Color(0x00000000),
                                                  width: 1.0,
                                                ),
                                                borderRadius:
                                                    const BorderRadius.only(
                                                  topLeft: Radius.circular(4.0),
                                                  topRight:
                                                      Radius.circular(4.0),
                                                ),
                                              ),
                                              errorBorder: OutlineInputBorder(
                                                borderSide: BorderSide(
                                                  color: Color(0x00000000),
                                                  width: 1.0,
                                                ),
                                                borderRadius:
                                                    const BorderRadius.only(
                                                  topLeft: Radius.circular(4.0),
                                                  topRight:
                                                      Radius.circular(4.0),
                                                ),
                                              ),
                                              focusedErrorBorder:
                                                  OutlineInputBorder(
                                                borderSide: BorderSide(
                                                  color: Color(0x00000000),
                                                  width: 1.0,
                                                ),
                                                borderRadius:
                                                    const BorderRadius.only(
                                                  topLeft: Radius.circular(4.0),
                                                  topRight:
                                                      Radius.circular(4.0),
                                                ),
                                              ),
                                              filled: true,
                                              fillColor:
                                                  AppTheme.of(context)
                                                      .secondaryBackground,
                                            ),
                                            style: GoogleFonts.plusJakartaSans(
                                              color:
                                                  AppTheme.of(context)
                                                      .primaryText,
                                              fontSize: 14.0,
                                            ),
                                            maxLines: null,
                                            keyboardType: TextInputType.number,
                                            validator: _model
                                                .cpfPropConjFieldTextControllerValidator
                                                .asValidator(context),
                                            inputFormatters: [
                                              _model.cpfPropConjFieldMask
                                            ],
                                          ),
                                        ),
                                      ]
                                          .divide(SizedBox(height: 14.0))
                                          .addToStart(SizedBox(height: 16.0))
                                          .addToEnd(SizedBox(height: 16.0)),
                                    ),
                                  ),
                                  Column(
                                    mainAxisSize: MainAxisSize.max,
                                    children: [
                                      Padding(
                                        padding: EdgeInsetsDirectional.fromSTEB(
                                            16.0, 0.0, 16.0, 0.0),
                                        child: Container(
                                          width: double.infinity,
                                          height: 275.15,
                                          decoration: BoxDecoration(
                                            color: AppTheme.of(context)
                                                .secondaryBackground,
                                            borderRadius:
                                                BorderRadius.circular(8.0),
                                          ),
                                          child: Padding(
                                            padding: EdgeInsets.all(16.0),
                                            child: Column(
                                              mainAxisSize: MainAxisSize.max,
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  mainAxisSize:
                                                      MainAxisSize.max,
                                                  mainAxisAlignment:
                                                      MainAxisAlignment
                                                          .spaceBetween,
                                                  children: [
                                                    Text(
                                                      'Bancos',
                                                      style: AppTheme
                                                              .of(context)
                                                          .bodyMedium
                                                          .override(
                                                            font: GoogleFonts
                                                                .inter(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w600,
                                                              fontStyle:
                                                                  AppTheme.of(
                                                                          context)
                                                                      .bodyMedium
                                                                      .fontStyle,
                                                            ),
                                                            fontSize: 16.0,
                                                            letterSpacing: 0.0,
                                                            fontWeight:
                                                                FontWeight.w600,
                                                            fontStyle:
                                                                AppTheme.of(
                                                                        context)
                                                                    .bodyMedium
                                                                    .fontStyle,
                                                          ),
                                                    ),
                                                    AppButtonWidget(
                                                      onPressed: () async {
                                                        final nomeController = TextEditingController();
                                                        final dddController = TextEditingController();
                                                        final telefoneController = TextEditingController();
                                                        await showDialog(
                                                          context: context,
                                                          builder: (dialogContext) {
                                                            return AlertDialog(
                                                              backgroundColor: AppTheme.of(context).secondaryBackground,
                                                              title: Text('Adicionar Banco', style: AppTheme.of(context).headlineSmall),
                                                              content: Column(
                                                                mainAxisSize: MainAxisSize.min,
                                                                children: [
                                                                  TextField(
                                                                    controller: nomeController,
                                                                    decoration: InputDecoration(labelText: 'Nome do Banco'),
                                                                  ),
                                                                  TextField(
                                                                    controller: dddController,
                                                                    decoration: InputDecoration(labelText: 'DDD (Ex: 11)'),
                                                                    keyboardType: TextInputType.number,
                                                                  ),
                                                                  TextField(
                                                                    controller: telefoneController,
                                                                    decoration: InputDecoration(labelText: 'Telefone'),
                                                                    keyboardType: TextInputType.phone,
                                                                  ),
                                                                ],
                                                              ),
                                                              actions: [
                                                                TextButton(
                                                                  onPressed: () => Navigator.pop(dialogContext),
                                                                  child: Text('Cancelar', style: TextStyle(color: AppTheme.of(context).primary)),
                                                                ),
                                                                TextButton(
                                                                  onPressed: () {
                                                                    _model.addToListaBancos(BancoInfoStructStruct(
                                                                      nomeBanco: nomeController.text,
                                                                      ddd: dddController.text,
                                                                      telefone: telefoneController.text,
                                                                    ));
                                                                    safeSetState(() {});
                                                                    Navigator.pop(dialogContext);
                                                                  },
                                                                  child: Text('Salvar', style: TextStyle(color: AppTheme.of(context).primary, fontWeight: FontWeight.bold)),
                                                                ),
                                                              ],
                                                            );
                                                          },
                                                        );
                                                      },
                                                      text: 'Adicionar',
                                                      icon: Icon(
                                                        Icons.add_rounded,
                                                        size: 15.0,
                                                      ),
                                                      options: AppButtonOptions(
                                                        height: 36.0,
                                                        padding:
                                                            EdgeInsetsDirectional
                                                                .fromSTEB(
                                                                    16.0,
                                                                    0.0,
                                                                    16.0,
                                                                    0.0),
                                                        iconPadding:
                                                            EdgeInsetsDirectional
                                                                .fromSTEB(
                                                                    0.0,
                                                                    0.0,
                                                                    0.0,
                                                                    0.0),
                                                        color:
                                                            AppTheme.of(
                                                                    context)
                                                                .primary,
                                                        textStyle:
                                                            AppTheme.of(
                                                                    context)
                                                                .titleSmall
                                                                .override(
                                                                  font: GoogleFonts
                                                                      .plusJakartaSans(
                                                                    fontWeight: AppTheme.of(
                                                                            context)
                                                                        .titleSmall
                                                                        .fontWeight,
                                                                    fontStyle: AppTheme.of(
                                                                            context)
                                                                        .titleSmall
                                                                        .fontStyle,
                                                                  ),
                                                                  color: Colors
                                                                      .white,
                                                                  letterSpacing:
                                                                      0.0,
                                                                  fontWeight: AppTheme.of(
                                                                          context)
                                                                      .titleSmall
                                                                      .fontWeight,
                                                                  fontStyle: AppTheme.of(
                                                                          context)
                                                                      .titleSmall
                                                                      .fontStyle,
                                                                ),
                                                        elevation: 0.0,
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(8.0),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                Expanded(
                                                  child: Builder(
                                                    builder: (context) {
                                                      final listBancos = _model
                                                          .listaBancos
                                                          .toList();

                                                      return ListView.separated(
                                                        padding:
                                                            EdgeInsets.zero,
                                                        shrinkWrap: true,
                                                        scrollDirection:
                                                            Axis.vertical,
                                                        itemCount:
                                                            listBancos.length,
                                                        separatorBuilder:
                                                            (_, __) => SizedBox(
                                                                height: 8.0),
                                                        itemBuilder: (context,
                                                            listBancosIndex) {
                                                          final listBancosItem =
                                                              listBancos[
                                                                  listBancosIndex];
                                                          return Container(
                                                            width: 100.0,
                                                            height: 54.0,
                                                            decoration:
                                                                BoxDecoration(
                                                              color: AppTheme
                                                                      .of(context)
                                                                  .secondaryBackground,
                                                              boxShadow: [
                                                                BoxShadow(
                                                                  blurRadius:
                                                                      4.0,
                                                                  color: Color(
                                                                      0x33000000),
                                                                  offset:
                                                                      Offset(
                                                                    0.0,
                                                                    2.0,
                                                                  ),
                                                                )
                                                              ],
                                                              borderRadius:
                                                                  BorderRadius
                                                                      .circular(
                                                                          8.0),
                                                            ),
                                                            child: Padding(
                                                              padding:
                                                                  EdgeInsets
                                                                      .all(8.0),
                                                              child: Row(
                                                                mainAxisSize:
                                                                    MainAxisSize
                                                                        .max,
                                                                children: [
                                                                  Padding(
                                                                    padding: EdgeInsetsDirectional
                                                                        .fromSTEB(
                                                                            4.0,
                                                                            0.0,
                                                                            0.0,
                                                                            0.0),
                                                                    child: Icon(
                                                                      Icons
                                                                          .assured_workload,
                                                                      color: AppTheme.of(
                                                                              context)
                                                                          .primary,
                                                                      size:
                                                                          20.0,
                                                                    ),
                                                                  ),
                                                                  Expanded(
                                                                    child:
                                                                        Column(
                                                                      mainAxisSize:
                                                                          MainAxisSize
                                                                              .max,
                                                                      mainAxisAlignment:
                                                                          MainAxisAlignment
                                                                              .spaceBetween,
                                                                      crossAxisAlignment:
                                                                          CrossAxisAlignment
                                                                              .start,
                                                                      children: [
                                                                        Text(
                                                                          valueOrDefault<
                                                                              String>(
                                                                            listBancosItem.nomeBanco,
                                                                            'Banco',
                                                                          ),
                                                                          style: AppTheme.of(context)
                                                                              .bodyMedium
                                                                              .override(
                                                                                font: GoogleFonts.plusJakartaSans(
                                                                                  fontWeight: FontWeight.w600,
                                                                                  fontStyle: AppTheme.of(context).bodyMedium.fontStyle,
                                                                                ),
                                                                                fontSize: 16.0,
                                                                                letterSpacing: 0.0,
                                                                                fontWeight: FontWeight.w600,
                                                                                fontStyle: AppTheme.of(context).bodyMedium.fontStyle,
                                                                              ),
                                                                        ),
                                                                        Text(
                                                                          '(${listBancosItem.ddd}) ${listBancosItem.telefone}',
                                                                          style: AppTheme.of(context)
                                                                              .bodyMedium
                                                                              .override(
                                                                                font: GoogleFonts.inter(
                                                                                  fontWeight: AppTheme.of(context).bodyMedium.fontWeight,
                                                                                  fontStyle: AppTheme.of(context).bodyMedium.fontStyle,
                                                                                ),
                                                                                color: AppTheme.of(context).secondaryText,
                                                                                letterSpacing: 0.0,
                                                                                fontWeight: AppTheme.of(context).bodyMedium.fontWeight,
                                                                                fontStyle: AppTheme.of(context).bodyMedium.fontStyle,
                                                                              ),
                                                                        ),
                                                                      ],
                                                                    ),
                                                                  ),
                                                                  InkWell(
                                                                    onTap: () async {
                                                                      _model.removeAtIndexFromListaBancos(listBancosIndex);
                                                                      safeSetState(() {});
                                                                    },
                                                                    child: Padding(
                                                                      padding: EdgeInsetsDirectional
                                                                          .fromSTEB(
                                                                              0.0,
                                                                              0.0,
                                                                              4.0,
                                                                              0.0),
                                                                      child:
                                                                          FaIcon(
                                                                        FontAwesomeIcons
                                                                            .trashAlt,
                                                                        color: AppTheme.of(
                                                                                context)
                                                                            .error,
                                                                        size:
                                                                            20.0,
                                                                      ),
                                                                    ),
                                                                  ),
                                                                ].divide(SizedBox(
                                                                    width:
                                                                        12.0)),
                                                              ),
                                                            ),
                                                          );
                                                        },
                                                      );
                                                    },
                                                  ),
                                                ),
                                              ].divide(SizedBox(height: 12.0)),
                                            ),
                                          ),
                                        ),
                                      ),
                                      Padding(
                                        padding: EdgeInsetsDirectional.fromSTEB(
                                            16.0, 0.0, 16.0, 0.0),
                                        child: Container(
                                          width: double.infinity,
                                          height: 240.0,
                                          decoration: BoxDecoration(
                                            color: AppTheme.of(context)
                                                .secondaryBackground,
                                            borderRadius:
                                                BorderRadius.circular(8.0),
                                          ),
                                          child: Padding(
                                            padding: EdgeInsets.all(16.0),
                                            child: Column(
                                              mainAxisSize: MainAxisSize.max,
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  'Observações',
                                                  style: AppTheme.of(
                                                          context)
                                                      .bodyMedium
                                                      .override(
                                                        font: GoogleFonts.inter(
                                                          fontWeight:
                                                              FontWeight.w600,
                                                          fontStyle:
                                                              AppTheme.of(
                                                                      context)
                                                                  .bodyMedium
                                                                  .fontStyle,
                                                        ),
                                                        fontSize: 16.0,
                                                        letterSpacing: 0.0,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        fontStyle:
                                                            AppTheme.of(
                                                                    context)
                                                                .bodyMedium
                                                                .fontStyle,
                                                      ),
                                                ),
                                                Expanded(
                                                  child: Container(
                                                    width: double.infinity,
                                                    child: TextFormField(
                                                      controller: _model
                                                          .obsFieldTextController,
                                                      focusNode: _model
                                                          .obsFieldFocusNode,
                                                      autofocus: false,
                                                      enabled: true,
                                                      obscureText: false,
                                                      decoration:
                                                          InputDecoration(
                                                        isDense: true,
                                                        labelStyle:
                                                            AppTheme.of(
                                                                    context)
                                                                .labelMedium
                                                                .override(
                                                                  font:
                                                                      GoogleFonts
                                                                          .inter(
                                                                    fontWeight: AppTheme.of(
                                                                            context)
                                                                        .labelMedium
                                                                        .fontWeight,
                                                                    fontStyle: AppTheme.of(
                                                                            context)
                                                                        .labelMedium
                                                                        .fontStyle,
                                                                  ),
                                                                  color: AppTheme.of(
                                                                          context)
                                                                      .primaryText,
                                                                  fontSize:
                                                                      14.0,
                                                                  letterSpacing:
                                                                      0.0,
                                                                  fontWeight: AppTheme.of(
                                                                          context)
                                                                      .labelMedium
                                                                      .fontWeight,
                                                                  fontStyle: AppTheme.of(
                                                                          context)
                                                                      .labelMedium
                                                                      .fontStyle,
                                                                ),
                                                        hintText:
                                                            'Digite Informações sobre o cliente',
                                                        hintStyle:
                                                            AppTheme.of(
                                                                    context)
                                                                .labelMedium
                                                                .override(
                                                                  font:
                                                                      GoogleFonts
                                                                          .inter(
                                                                    fontWeight: AppTheme.of(
                                                                            context)
                                                                        .labelMedium
                                                                        .fontWeight,
                                                                    fontStyle: AppTheme.of(
                                                                            context)
                                                                        .labelMedium
                                                                        .fontStyle,
                                                                  ),
                                                                  letterSpacing:
                                                                      0.0,
                                                                  fontWeight: AppTheme.of(
                                                                          context)
                                                                      .labelMedium
                                                                      .fontWeight,
                                                                  fontStyle: AppTheme.of(
                                                                          context)
                                                                      .labelMedium
                                                                      .fontStyle,
                                                                ),
                                                        enabledBorder:
                                                            OutlineInputBorder(
                                                          borderSide:
                                                              BorderSide(
                                                            color: AppTheme
                                                                    .of(context)
                                                                .secondaryText,
                                                            width: 1.0,
                                                          ),
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(
                                                                      8.0),
                                                        ),
                                                        focusedBorder:
                                                            OutlineInputBorder(
                                                          borderSide:
                                                              BorderSide(
                                                            color: Color(
                                                                0x00000000),
                                                            width: 1.0,
                                                          ),
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(
                                                                      8.0),
                                                        ),
                                                        errorBorder:
                                                            OutlineInputBorder(
                                                          borderSide:
                                                              BorderSide(
                                                            color: AppTheme
                                                                    .of(context)
                                                                .error,
                                                            width: 1.0,
                                                          ),
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(
                                                                      8.0),
                                                        ),
                                                        focusedErrorBorder:
                                                            OutlineInputBorder(
                                                          borderSide:
                                                              BorderSide(
                                                            color: AppTheme
                                                                    .of(context)
                                                                .error,
                                                            width: 1.0,
                                                          ),
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(
                                                                      8.0),
                                                        ),
                                                        filled: true,
                                                        fillColor: AppTheme
                                                                .of(context)
                                                            .secondaryBackground,
                                                      ),
                                                      style:
                                                          AppTheme.of(
                                                                  context)
                                                              .bodyMedium
                                                              .override(
                                                                font: GoogleFonts
                                                                    .plusJakartaSans(
                                                                  fontWeight: AppTheme.of(
                                                                          context)
                                                                      .bodyMedium
                                                                      .fontWeight,
                                                                  fontStyle: AppTheme.of(
                                                                          context)
                                                                      .bodyMedium
                                                                      .fontStyle,
                                                                ),
                                                                letterSpacing:
                                                                    0.0,
                                                                fontWeight: AppTheme.of(
                                                                        context)
                                                                    .bodyMedium
                                                                    .fontWeight,
                                                                fontStyle: AppTheme.of(
                                                                        context)
                                                                    .bodyMedium
                                                                    .fontStyle,
                                                              ),
                                                      maxLines: 20,
                                                      cursorColor:
                                                          AppTheme.of(
                                                                  context)
                                                              .primaryText,
                                                      enableInteractiveSelection:
                                                          true,
                                                      validator: _model
                                                          .obsFieldTextControllerValidator
                                                          .asValidator(context),
                                                    ),
                                                  ),
                                                ),
                                              ].divide(SizedBox(height: 12.0)),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ]
                                        .divide(SizedBox(height: 16.0))
                                        .addToStart(SizedBox(height: 16.0))
                                        .addToEnd(SizedBox(height: 16.0)),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      } else {
                        return wrapWithModel(
                          model: _model.loadingModel,
                          updateCallback: () => safeSetState(() {}),
                          child: LoadingWidget(),
                        );
                      }
                    },
                  ),
                ),
                Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisSize: MainAxisSize.max,
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        flex: 1,
                        child: AppButtonWidget(
                          onPressed: () async {
                            context.pushNamed(
                              ExtratoClientePageWidget.routeName,
                              queryParameters: {
                                'codigoCliente': serializeParam(
                                  '',
                                  ParamType.String,
                                ),
                              }.withoutNulls,
                            );
                          },
                          text: 'Extrato',
                          icon: Icon(
                            Icons.receipt_long,
                            size: 20.0,
                          ),
                          options: AppButtonOptions(
                            height: 48.0,
                            padding: EdgeInsetsDirectional.fromSTEB(
                                0.0, 0.0, 0.0, 0.0),
                            iconPadding: EdgeInsetsDirectional.fromSTEB(
                                0.0, 0.0, 0.0, 0.0),
                            iconColor: AppTheme.of(context).primary,
                            color:
                                AppTheme.of(context).primaryBackground,
                            textStyle: TextStyle(
                              color: AppTheme.of(context).primary,
                            ),
                            borderSide: BorderSide(
                              color: AppTheme.of(context).primary,
                              width: 1.0,
                            ),
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                        ),
                      ),
                      Expanded(
                        child: AppButtonWidget(
                          onPressed: () async {
                            if (_model.nomeFieldTextController.text == null ||
                                _model.nomeFieldTextController.text == '') {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Razão Social é obrigatória.',
                                    style: TextStyle(),
                                  ),
                                  duration: Duration(milliseconds: 4000),
                                ),
                              );
                              return;
                            }

                            if (_model.tipoPessoa == 'F' && (_model.cpfFieldTextController?.text == null || _model.cpfFieldTextController!.text.isEmpty)) {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('CPF é obrigatório.'), duration: Duration(milliseconds: 4000)));
                              return;
                            }
                            if (_model.tipoPessoa == 'J' && (_model.cnpjFieldTextController?.text == null || _model.cnpjFieldTextController!.text.isEmpty)) {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('CNPJ é obrigatório.'), duration: Duration(milliseconds: 4000)));
                              return;
                            }
                            if (_model.enderecoFieldTextController?.text == null || _model.enderecoFieldTextController!.text.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Endereço é obrigatório.'), duration: Duration(milliseconds: 4000)));
                              return;
                            }
                            if (_model.cepFieldTextController?.text == null || _model.cepFieldTextController!.text.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('CEP é obrigatório.'), duration: Duration(milliseconds: 4000)));
                              return;
                            }
                            if (_model.dddFieldTextController?.text == null || _model.dddFieldTextController!.text.trim().isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('DDD é obrigatório.'), duration: Duration(milliseconds: 4000)));
                              return;
                            }
                            if (_model.dddFieldTextController!.text.trim().replaceAll(RegExp(r'[^0-9]'), '').length != 2) {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('DDD deve ter 2 dígitos.'), duration: Duration(milliseconds: 4000)));
                              return;
                            }
                            if (_model.telefoneFieldTextController?.text == null || _model.telefoneFieldTextController!.text.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Telefone é obrigatório.'), duration: Duration(milliseconds: 4000)));
                              return;
                            }

                            // Montagem do ClienteResultStruct a partir dos
                            // controllers para geracao do XML de exportacao.
                            final String cpfCnpjValue =
                                _model.tipoPessoa == 'F'
                                    ? _model.cpfFieldTextController!.text
                                    : _model.cnpjFieldTextController!.text;
                            final String dddEnt = _model.dddFieldTextController!.text.replaceAll(RegExp(r'[^0-9]'), '');
                            final String foneEnt = _model.telefoneFieldTextController!.text.replaceAll(RegExp(r'[^0-9]'), '');
                            final String limiteRaw =
                                _model.limiteFieldTextController!.text
                                    .replaceAll(RegExp(r'[^0-9.,]'), '')
                                    .replaceAll('.', '')
                                    .replaceAll(',', '.');
                            final double limiteValue =
                                double.tryParse(limiteRaw) ?? 0.0;

                            final clienteParaXml = ClienteResultStruct(
                              cli00Codigo: _model.cliData?.cli00Codigo ?? 0,
                              cli00Descri:
                                  _model.nomeFieldTextController!.text.trim(),
                              cli00Fantas: _model
                                  .fantasiaFieldTextController!.text
                                  .trim(),
                              cli00Pessoa: _model.tipoPessoa ?? 'F',
                              cli00Cpfcnp: cpfCnpjValue.trim(),
                              cli00Insest:
                                  _model.ieFieldTextController!.text.trim(),
                              cli00Observ:
                                  _model.obsFieldTextController!.text.trim(),
                              cli00Endere: _model
                                  .enderecoFieldTextController!.text
                                  .trim(),
                              cli00Endnum:
                                  _model.numeroFieldTextController!.text.trim(),
                              cli00Bairro:
                                  _model.bairroFieldTextController!.text.trim(),
                              cli00Ciddes: _model
                                  .cidadeFieldTextController!.text
                                  .trim(),
                              cli00Estsgl: _model.ufDropdownValue ?? '',
                              cli00Endcep:
                                  _model.cepFieldTextController!.text.trim(),
                              cli00Fonddd: dddEnt,
                              cli00Fonnum: foneEnt,
                              cli00Contat:
                                  _model.emailFieldTextController!.text.trim(),
                              cli00Crelim: limiteValue,
                              cli02NProp: _model
                                  .nomePropFieldTextController!.text
                                  .trim(),
                              cli02EndProp: _model
                                  .enderecoPropFieldTextController!.text
                                  .trim(),
                              cli02NumProp: '',
                              cli02BairroProp: _model
                                  .bairroPropFieldTextController!.text
                                  .trim(),
                              cli02CidadeProp: _model
                                  .cidadePropFieldTextController!.text
                                  .trim(),
                              cli02UfProp: _model.ufPropDropdownValue ?? '',
                              cli02CpfProp: _model
                                  .cpfPropFieldTextController!.text
                                  .trim(),
                              cli02NRGProp:
                                  _model.rgPropFieldTextController!.text.trim(),
                              cli02OrgaoProp: '',
                              cli02ConjugeProp: _model
                                  .nomePropConjFieldTextController!.text
                                  .trim(),
                              cli02CpfConjProp: _model
                                  .cpfPropConjFieldTextController!.text
                                  .trim(),
                              cli02NRGConjProp: _model
                                  .rgPropConjFieldTextController!.text
                                  .trim(),
                              cli02OrgaoConjProp: '',
                              bancosList: _model.listaBancos,
                            );

                            _model.xmlPath = await actions.gerarXmlCliente(
                              clienteParaXml,
                              AppState().vendedor_codigo.toString(),
                            );
                            safeSetState(() {});

                            if (_model.xmlPath != null &&
                                _model.xmlPath!.isNotEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Cadastro preparado para envio. Arquivo gerado.',
                                    style: TextStyle(),
                                  ),
                                  duration: Duration(milliseconds: 4000),
                                ),
                              );
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Falha ao gerar arquivo do cliente.',
                                    style: TextStyle(),
                                  ),
                                  duration: Duration(milliseconds: 4000),
                                ),
                              );
                            }
                          },
                          text: 'SALVAR CADASTRO',
                          options: AppButtonOptions(
                            width: double.infinity,
                            height: 50.0,
                            padding: EdgeInsetsDirectional.fromSTEB(
                                0.0, 0.0, 0.0, 0.0),
                            iconPadding: EdgeInsetsDirectional.fromSTEB(
                                0.0, 0.0, 0.0, 0.0),
                            color: Color(0xFF5CB85C),
                            textStyle: TextStyle(
                              color: AppTheme.of(context)
                                  .secondaryBackground,
                            ),
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                        ),
                      ),
                    ].divide(SizedBox(width: 8.0)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
