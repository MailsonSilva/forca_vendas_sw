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
import '/widgets/index.dart' as custom_widgets;
import '/core/app_functions.dart' as functions;
import '/index.dart';
import 'package:easy_debounce/easy_debounce.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'busca_produto_page_model.dart';
export 'busca_produto_page_model.dart';

/// Consulta de estoque e catalogo de produtos com busca SQLite.
class BuscaProdutoPageWidget extends StatefulWidget {
  const BuscaProdutoPageWidget({super.key, this.isSelectionMode = false});

  final bool isSelectionMode;

  static String routeName = 'BuscaProdutoPage';
  static String routePath = '/estoque';

  @override
  State<BuscaProdutoPageWidget> createState() => _BuscaProdutoPageWidgetState();
}

class _BuscaProdutoPageWidgetState extends State<BuscaProdutoPageWidget> {
  late BuscaProdutoPageModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => BuscaProdutoPageModel());

    // On page load action.
    SchedulerBinding.instance.addPostFrameCallback((_) async {
      _model.listaLinha = await actions.carregarFiltros(
        'linhas',
      );
      _model.listaGrupo = await actions.carregarFiltros(
        'grupos',
      );
      _model.listaFab = await actions.carregarFiltros(
        'fabricantes',
      );
      _model.listaMarca = await actions.carregarFiltros(
        'marcas',
      );
      _model.resultadoOnLoad = await actions.buscaProduto(
        '',
        0,
        _model.filtroLinha,
        _model.filtroGrupo,
        _model.filtroFabricante,
        _model.filtroMarca,
        _model.filtroEstoque,
        _model.filtroPromocao,
        functions.resolverCodFilial(AppState().empresa_codigo),
        _model.filtroDataEntrada,
      );
      _model.listaProdutos =
          _model.resultadoOnLoad!.toList().cast<ProdutoResultStruct>();
      safeSetState(() {});
      _model.dadosCarregados = true;
      safeSetState(() {});
    });

    _model.buscaProdutoFieldTextController ??= TextEditingController();
    _model.buscaProdutoFieldFocusNode ??= FocusNode();
  }

  @override
  void dispose() {
    _model.dispose();

  }

  void _abrirModalAdicionarCarrinho(ProdutoResultStruct produto) {
    int quantidade = produto.saldoEstoque > 0 ? 1 : 0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            String formatCurrency(double val) {
              return 'R\$ ${val.toStringAsFixed(2).replaceAll('.', ',')}';
            }

            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20.0)),
              ),
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 24.0,
                left: 16.0,
                right: 16.0,
                top: 12.0,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40.0,
                      height: 5.0,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16.0),
                  const Text(
                    'Adicionar ao Carrinho',
                    style: TextStyle(
                      fontSize: 18.0,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF14181B),
                    ),
                  ),
                  const SizedBox(height: 16.0),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16.0),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12.0),
                      border: Border.all(color: const Color(0xFFE0E3E7)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Cód. ${produto.codigo}',
                          style: TextStyle(
                            color: AppTheme.of(context).primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 12.0,
                          ),
                        ),
                        const SizedBox(height: 4.0),
                        Text(
                          produto.descricao,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14.0,
                          ),
                        ),
                        const SizedBox(height: 12.0),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Un: ${produto.unidade}',
                              style: const TextStyle(color: Colors.grey, fontSize: 13.0),
                            ),
                            Text(
                              'Preço: ${formatCurrency(produto.preco)}',
                              style: const TextStyle(color: Colors.grey, fontSize: 13.0),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8.0),
                        Row(
                          children: [
                            const Icon(Icons.inventory_2_outlined, color: Colors.grey, size: 16.0),
                            const SizedBox(width: 4.0),
                            const Text('Estoque disponível: ', style: TextStyle(color: Colors.grey, fontSize: 12.0)),
                            Text(
                              '${produto.saldoEstoque.toInt()}',
                              style: TextStyle(
                                color: produto.saldoEstoque > 0 ? AppTheme.of(context).primary : Colors.red,
                                fontWeight: FontWeight.bold,
                                fontSize: 12.0,
                              ),
                            ),
                          ],
                        ),
                        if (produto.saldoEstoque <= 0) ...[
                          const SizedBox(height: 12.0),
                          Row(
                            children: const [
                              Icon(Icons.warning_amber_rounded, color: Colors.red, size: 18.0),
                              SizedBox(width: 6.0),
                              Expanded(
                                child: Text(
                                  'Produto indisponível: Estoque esgotado (Saldo: 0)',
                                  style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 13.0),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 24.0),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFAED5E6),
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.remove, color: Colors.white),
                          onPressed: quantidade > 1
                              ? () => setModalState(() => quantidade--)
                              : null,
                          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                        ),
                      ),
                      Container(
                        constraints: const BoxConstraints(minWidth: 64.0),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          border: Border.all(color: AppTheme.of(context).primary),
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12.0),
                        margin: const EdgeInsets.symmetric(horizontal: 8.0),
                        child: Text(
                          '$quantidade',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18.0),
                        ),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF0288D1),
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.add, color: Colors.white),
                          onPressed: quantidade < produto.saldoEstoque
                              ? () => setModalState(() => quantidade++)
                              : null,
                          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24.0),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total do Item',
                        style: TextStyle(color: Colors.grey, fontSize: 16.0),
                      ),
                      Text(
                        formatCurrency(produto.preco * quantidade),
                        style: TextStyle(
                          color: AppTheme.of(context).primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 20.0,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24.0),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.grey),
                            padding: const EdgeInsets.symmetric(vertical: 16.0),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
                          ),
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Cancelar', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(width: 12.0),
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.of(context).primary,
                            padding: const EdgeInsets.symmetric(vertical: 16.0),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
                          ),
                          onPressed: quantidade > 0
                              ? () {
                                  Navigator.of(context).pop(); // Close modal
                                  final item = ItemPedidoStruct(
                                    codigoProduto: produto.codigo,
                                    descricao: produto.descricao,
                                    unidade: produto.unidade,
                                    precoUnitario: produto.preco,
                                    quantidade: quantidade.toDouble(),
                                    totalItem: produto.preco * quantidade,
                                  );
                                  context.pop(item);
                                }
                              : null,
                          icon: const Icon(Icons.shopping_cart_outlined, color: Colors.white, size: 20.0),
                          label: const Text('Adicionar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
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
            'Pesquisa de Produtos',
            style: AppTheme.of(context).titleLarge.override(
                  font: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w600,
                    fontStyle:
                        AppTheme.of(context).titleLarge.fontStyle,
                  ),
                  color: AppTheme.of(context).secondaryBackground,
                  fontSize: 22.0,
                  letterSpacing: 0.0,
                  fontWeight: FontWeight.w600,
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
            child: Padding(
              padding: EdgeInsetsDirectional.fromSTEB(0.0, 16.0, 0.0, 16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    decoration: BoxDecoration(),
                    child: Column(
                      mainAxisSize: MainAxisSize.max,
                      children: [
                        Padding(
                          padding: EdgeInsetsDirectional.fromSTEB(
                              16.0, 0.0, 16.0, 0.0),
                          child: TextFormField(
                            controller: _model.buscaProdutoFieldTextController,
                            focusNode: _model.buscaProdutoFieldFocusNode,
                            onChanged: (_) => EasyDebounce.debounce(
                              '_model.buscaProdutoFieldTextController',
                              Duration(milliseconds: 2000),
                              () async {
                                _model.resultadoBusca =
                                    await actions.buscaProduto(
                                  _model.buscaProdutoFieldTextController.text,
                                  0,
                                  _model.filtroLinha,
                                  _model.filtroGrupo,
                                  _model.filtroFabricante,
                                  _model.filtroMarca,
                                  _model.filtroEstoque,
                                  _model.filtroPromocao,
                                  functions.resolverCodFilial(
                                      AppState().empresa_codigo),
                                  _model.filtroDataEntrada,
                                );
                                _model.listaProdutos = _model.resultadoBusca!
                                    .toList()
                                    .cast<ProdutoResultStruct>();
                                safeSetState(() {});

                                safeSetState(() {});
                              },
                            ),
                            textInputAction: TextInputAction.search,
                            obscureText: false,
                            decoration: InputDecoration(
                              labelText: 'Produto',
                              hintText: 'Pesquise por código ou descrição...',
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
                              prefixIcon: Icon(
                                Icons.search,
                              ),
                            ),
                            style: TextStyle(),
                            maxLines: null,
                            validator: _model
                                .buscaProdutoFieldTextControllerValidator
                                .asValidator(context),
                          ),
                        ),
                        Padding(
                          padding: EdgeInsetsDirectional.fromSTEB(
                              16.0, 0.0, 16.0, 0.0),
                          child: Container(
                            width: double.infinity,
                            height: 50.0,
                            decoration: BoxDecoration(
                              color: AppTheme.of(context)
                                  .secondaryBackground,
                              boxShadow: [
                                BoxShadow(
                                  blurRadius: 4.0,
                                  color: Color(0x33000000),
                                  offset: Offset(
                                    0.0,
                                    2.0,
                                  ),
                                )
                              ],
                              borderRadius: BorderRadius.circular(12.0),
                            ),
                            child: Padding(
                              padding: EdgeInsetsDirectional.fromSTEB(
                                  12.0, 8.0, 12.0, 8.0),
                              child: InkWell(
                                splashColor: Colors.transparent,
                                focusColor: Colors.transparent,
                                hoverColor: Colors.transparent,
                                highlightColor: Colors.transparent,
                                onTap: () async {
                                  _model.isFiltroExpanded =
                                      !_model.isFiltroExpanded;
                                  safeSetState(() {});
                                },
                                child: Row(
                                  mainAxisSize: MainAxisSize.max,
                                  children: [
                                    Icon(
                                      Icons.filter_alt_outlined,
                                      color:
                                          AppTheme.of(context).primary,
                                      size: 24.0,
                                    ),
                                    Expanded(
                                      child: Padding(
                                        padding: EdgeInsetsDirectional.fromSTEB(
                                            8.0, 0.0, 0.0, 0.0),
                                        child: Text(
                                          'Filtros Avançados',
                                          style: AppTheme.of(context)
                                              .bodyMedium
                                              .override(
                                                font: GoogleFonts.inter(
                                                  fontWeight: FontWeight.w500,
                                                  fontStyle:
                                                      AppTheme.of(
                                                              context)
                                                          .bodyMedium
                                                          .fontStyle,
                                                ),
                                                color:
                                                    AppTheme.of(context)
                                                        .primary,
                                                fontSize: 16.0,
                                                letterSpacing: 0.0,
                                                fontWeight: FontWeight.w500,
                                                fontStyle:
                                                    AppTheme.of(context)
                                                        .bodyMedium
                                                        .fontStyle,
                                              ),
                                        ),
                                      ),
                                    ),
                                    Builder(
                                      builder: (context) {
                                        if (_model.isFiltroExpanded &&
                                            _model.dadosCarregados) {
                                          return Icon(
                                            Icons.keyboard_arrow_up,
                                            color: AppTheme.of(context)
                                                .primary,
                                            size: 24.0,
                                          );
                                        } else {
                                          return Icon(
                                            Icons.keyboard_arrow_down,
                                            color: AppTheme.of(context)
                                                .primary,
                                            size: 24.0,
                                          );
                                        }
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        if (_model.isFiltroExpanded && _model.dadosCarregados)
                          Padding(
                            padding: EdgeInsetsDirectional.fromSTEB(
                                16.0, 0.0, 16.0, 0.0),
                            child: Container(
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: AppTheme.of(context)
                                    .secondaryBackground,
                                boxShadow: [
                                  BoxShadow(
                                    blurRadius: 4.0,
                                    color: Color(0x33000000),
                                    offset: Offset(
                                      0.0,
                                      2.0,
                                    ),
                                  )
                                ],
                                borderRadius: BorderRadius.circular(12.0),
                              ),
                              child: Padding(
                                padding: EdgeInsetsDirectional.fromSTEB(
                                    16.0, 0.0, 16.0, 0.0),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        Text(
                                          'Linha',
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
                                                lineHeight: 1.38,
                                              ),
                                        ),
                                        AppDropDown<String>(
                                          controller: _model
                                                  .ddFiltroLinhaValueController ??=
                                              FormFieldController<String>(null),
                                          options: List<String>.from(_model
                                              .listaLinha!
                                              .map((e) => e.codigo)
                                              .toList()),
                                          optionLabels: _model.listaLinha!
                                              .map((e) => e.descricao)
                                              .toList(),
                                          onChanged: (val) async {
                                            safeSetState(() => _model
                                                .ddFiltroLinhaValue = val);
                                            _model.filtroLinha =
                                                _model.ddFiltroLinhaValue!;
                                            safeSetState(() {});
                                          },
                                          width: 200.0,
                                          height: 40.0,
                                          textStyle: AppTheme.of(
                                                  context)
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
                                                    AppTheme.of(context)
                                                        .bodyMedium
                                                        .fontWeight,
                                                fontStyle:
                                                    AppTheme.of(context)
                                                        .bodyMedium
                                                        .fontStyle,
                                              ),
                                          hintText: 'Todas as linhas',
                                          icon: Icon(
                                            Icons.keyboard_arrow_down_rounded,
                                            color: AppTheme.of(context)
                                                .secondaryText,
                                            size: 24.0,
                                          ),
                                          fillColor:
                                              AppTheme.of(context)
                                                  .secondaryBackground,
                                          elevation: 2.0,
                                          borderColor:
                                              AppTheme.of(context)
                                                  .secondary,
                                          borderWidth: 1.0,
                                          borderRadius: 8.0,
                                          margin:
                                              EdgeInsetsDirectional.fromSTEB(
                                                  12.0, 0.0, 12.0, 0.0),
                                          hidesUnderline: true,
                                          isOverButton: false,
                                          isSearchable: false,
                                          isMultiSelect: false,
                                        ),
                                      ].divide(SizedBox(height: 4.0)),
                                    ),
                                    Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        Text(
                                          'Grupo',
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
                                                lineHeight: 1.38,
                                              ),
                                        ),
                                        AppDropDown<String>(
                                          controller: _model
                                                  .ddFiltroGrupoValueController ??=
                                              FormFieldController<String>(null),
                                          options: List<String>.from(_model
                                              .listaGrupo!
                                              .map((e) => e.codigo)
                                              .toList()),
                                          optionLabels: _model.listaGrupo!
                                              .map((e) => e.descricao)
                                              .toList(),
                                          onChanged: (val) async {
                                            safeSetState(() => _model
                                                .ddFiltroGrupoValue = val);
                                            _model.filtroGrupo =
                                                _model.ddFiltroGrupoValue!;
                                            safeSetState(() {});
                                          },
                                          width: 200.0,
                                          height: 40.0,
                                          textStyle: AppTheme.of(
                                                  context)
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
                                                    AppTheme.of(context)
                                                        .bodyMedium
                                                        .fontWeight,
                                                fontStyle:
                                                    AppTheme.of(context)
                                                        .bodyMedium
                                                        .fontStyle,
                                              ),
                                          hintText: 'Todos os grupos',
                                          icon: Icon(
                                            Icons.keyboard_arrow_down_rounded,
                                            color: AppTheme.of(context)
                                                .secondaryText,
                                            size: 24.0,
                                          ),
                                          fillColor:
                                              AppTheme.of(context)
                                                  .secondaryBackground,
                                          elevation: 2.0,
                                          borderColor:
                                              AppTheme.of(context)
                                                  .secondary,
                                          borderWidth: 1.0,
                                          borderRadius: 8.0,
                                          margin:
                                              EdgeInsetsDirectional.fromSTEB(
                                                  12.0, 0.0, 12.0, 0.0),
                                          hidesUnderline: true,
                                          isOverButton: false,
                                          isSearchable: false,
                                          isMultiSelect: false,
                                        ),
                                      ].divide(SizedBox(height: 4.0)),
                                    ),
                                    Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        Text(
                                          'Fabricante',
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
                                                lineHeight: 1.38,
                                              ),
                                        ),
                                        AppDropDown<String>(
                                          controller: _model
                                                  .ddFiltroFabricanteValueController ??=
                                              FormFieldController<String>(null),
                                          options: List<String>.from(_model
                                              .listaFab!
                                              .map((e) => e.codigo)
                                              .toList()),
                                          optionLabels: _model.listaFab!
                                              .map((e) => e.descricao)
                                              .toList(),
                                          onChanged: (val) async {
                                            safeSetState(() => _model
                                                .ddFiltroFabricanteValue = val);
                                            _model.filtroFabricante =
                                                _model.ddFiltroFabricanteValue!;
                                            safeSetState(() {});
                                          },
                                          width: 200.0,
                                          height: 40.0,
                                          textStyle: AppTheme.of(
                                                  context)
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
                                                    AppTheme.of(context)
                                                        .bodyMedium
                                                        .fontWeight,
                                                fontStyle:
                                                    AppTheme.of(context)
                                                        .bodyMedium
                                                        .fontStyle,
                                              ),
                                          hintText: 'Todos os Fabricantes',
                                          icon: Icon(
                                            Icons.keyboard_arrow_down_rounded,
                                            color: AppTheme.of(context)
                                                .secondaryText,
                                            size: 24.0,
                                          ),
                                          fillColor:
                                              AppTheme.of(context)
                                                  .secondaryBackground,
                                          elevation: 2.0,
                                          borderColor:
                                              AppTheme.of(context)
                                                  .secondary,
                                          borderWidth: 1.0,
                                          borderRadius: 8.0,
                                          margin:
                                              EdgeInsetsDirectional.fromSTEB(
                                                  12.0, 0.0, 12.0, 0.0),
                                          hidesUnderline: true,
                                          isOverButton: false,
                                          isSearchable: false,
                                          isMultiSelect: false,
                                        ),
                                      ].divide(SizedBox(height: 4.0)),
                                    ),
                                    Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        Text(
                                          'Marca',
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
                                                lineHeight: 1.38,
                                              ),
                                        ),
                                        AppDropDown<String>(
                                          controller: _model
                                                  .ddFiltroMarcaValueController ??=
                                              FormFieldController<String>(null),
                                          options: List<String>.from(_model
                                              .listaMarca!
                                              .map((e) => e.codigo)
                                              .toList()),
                                          optionLabels: _model.listaMarca!
                                              .map((e) => e.descricao)
                                              .toList(),
                                          onChanged: (val) async {
                                            safeSetState(() => _model
                                                .ddFiltroMarcaValue = val);
                                            _model.filtroMarca =
                                                _model.ddFiltroMarcaValue!;
                                            safeSetState(() {});
                                          },
                                          width: 200.0,
                                          height: 40.0,
                                          textStyle: AppTheme.of(
                                                  context)
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
                                                    AppTheme.of(context)
                                                        .bodyMedium
                                                        .fontWeight,
                                                fontStyle:
                                                    AppTheme.of(context)
                                                        .bodyMedium
                                                        .fontStyle,
                                              ),
                                          hintText: 'Todas as Marcas',
                                          icon: Icon(
                                            Icons.keyboard_arrow_down_rounded,
                                            color: AppTheme.of(context)
                                                .secondaryText,
                                            size: 24.0,
                                          ),
                                          fillColor:
                                              AppTheme.of(context)
                                                  .secondaryBackground,
                                          elevation: 2.0,
                                          borderColor:
                                              AppTheme.of(context)
                                                  .secondary,
                                          borderWidth: 1.0,
                                          borderRadius: 8.0,
                                          margin:
                                              EdgeInsetsDirectional.fromSTEB(
                                                  12.0, 0.0, 12.0, 0.0),
                                          hidesUnderline: true,
                                          isOverButton: false,
                                          isSearchable: false,
                                          isMultiSelect: false,
                                        ),
                                      ].divide(SizedBox(height: 4.0)),
                                    ),
                                    Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        Text(
                                          'Data de entrada',
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
                                                lineHeight: 1.38,
                                              ),
                                        ),
                                        AppDropDown<String>(
                                          controller: _model
                                                  .ddDataEntValueController ??=
                                              FormFieldController<String>(null),
                                          options: [
                                            'Todas',
                                            'Hoje',
                                            'Ontem',
                                            'Últimos 7 dias'
                                          ],
                                          onChanged: (val) async {
                                            safeSetState(() =>
                                                _model.ddDataEntValue = val);
                                            _model.filtroDataEntrada =
                                                _model.ddDataEntValue;
                                            safeSetState(() {});
                                          },
                                          width: 250.0,
                                          height: 40.0,
                                          textStyle: AppTheme.of(
                                                  context)
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
                                                    AppTheme.of(context)
                                                        .bodyMedium
                                                        .fontWeight,
                                                fontStyle:
                                                    AppTheme.of(context)
                                                        .bodyMedium
                                                        .fontStyle,
                                              ),
                                          hintText: 'Todas',
                                          icon: Icon(
                                            Icons.keyboard_arrow_down_rounded,
                                            color: AppTheme.of(context)
                                                .secondaryText,
                                            size: 24.0,
                                          ),
                                          fillColor:
                                              AppTheme.of(context)
                                                  .secondaryBackground,
                                          elevation: 2.0,
                                          borderColor:
                                              AppTheme.of(context)
                                                  .secondary,
                                          borderWidth: 1.0,
                                          borderRadius: 8.0,
                                          margin:
                                              EdgeInsetsDirectional.fromSTEB(
                                                  12.0, 0.0, 12.0, 0.0),
                                          hidesUnderline: true,
                                          isOverButton: false,
                                          isSearchable: false,
                                          isMultiSelect: false,
                                        ),
                                      ].divide(SizedBox(height: 4.0)),
                                    ),
                                    Row(
                                      mainAxisSize: MainAxisSize.max,
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      children: [
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.center,
                                          children: [
                                            Theme(
                                              data: ThemeData(
                                                checkboxTheme:
                                                    CheckboxThemeData(
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            4.0),
                                                  ),
                                                ),
                                                unselectedWidgetColor:
                                                    AppTheme.of(context)
                                                        .secondaryText,
                                              ),
                                              child: Checkbox(
                                                value: _model
                                                        .checkboxPromoValue ??=
                                                    _model.filtroPromocao,
                                                onChanged: (newValue) async {
                                                  safeSetState(() => _model
                                                          .checkboxPromoValue =
                                                      newValue!);
                                                  if (newValue!) {
                                                    _model.filtroPromocao =
                                                        _model
                                                            .checkboxPromoValue!;
                                                    safeSetState(() {});
                                                  } else {
                                                    _model.filtroPromocao =
                                                        _model
                                                            .checkboxPromoValue!;
                                                    safeSetState(() {});
                                                  }
                                                },
                                                side: (AppTheme.of(
                                                                context)
                                                            .secondaryText !=
                                                        null)
                                                    ? BorderSide(
                                                        width: 2,
                                                        color:
                                                            AppTheme.of(
                                                                    context)
                                                                .secondaryText!,
                                                      )
                                                    : null,
                                                activeColor:
                                                    AppTheme.of(context)
                                                        .primary,
                                                checkColor:
                                                    AppTheme.of(context)
                                                        .primaryBackground,
                                              ),
                                            ),
                                            Container(
                                              width: 8.0,
                                            ),
                                            Text(
                                              'Só promoções',
                                              style: TextStyle(),
                                            ),
                                          ],
                                        ),
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.center,
                                          children: [
                                            Theme(
                                              data: ThemeData(
                                                checkboxTheme:
                                                    CheckboxThemeData(
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            4.0),
                                                  ),
                                                ),
                                                unselectedWidgetColor:
                                                    AppTheme.of(context)
                                                        .secondaryText,
                                              ),
                                              child: Checkbox(
                                                value: _model
                                                        .checkboxEstoqueValue ??=
                                                    _model.filtroEstoque,
                                                onChanged: (newValue) async {
                                                  safeSetState(() => _model
                                                          .checkboxEstoqueValue =
                                                      newValue!);
                                                  if (newValue!) {
                                                    _model.filtroEstoque = _model
                                                        .checkboxEstoqueValue!;
                                                    safeSetState(() {});
                                                  } else {
                                                    _model.filtroEstoque = _model
                                                        .checkboxEstoqueValue!;
                                                    safeSetState(() {});
                                                  }
                                                },
                                                side: (AppTheme.of(
                                                                context)
                                                            .secondaryText !=
                                                        null)
                                                    ? BorderSide(
                                                        width: 2,
                                                        color:
                                                            AppTheme.of(
                                                                    context)
                                                                .secondaryText!,
                                                      )
                                                    : null,
                                                activeColor:
                                                    AppTheme.of(context)
                                                        .primary,
                                                checkColor:
                                                    AppTheme.of(context)
                                                        .primaryBackground,
                                              ),
                                            ),
                                            Container(
                                              width: 8.0,
                                            ),
                                            Text(
                                              'Com estoque',
                                              style: TextStyle(),
                                            ),
                                          ],
                                        ),
                                      ].divide(SizedBox(width: 12.0)),
                                    ),
                                    Padding(
                                      padding: EdgeInsetsDirectional.fromSTEB(
                                          0.0, 8.0, 0.0, 0.0),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.max,
                                        mainAxisAlignment:
                                            MainAxisAlignment.start,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.center,
                                        children: [
                                          Expanded(
                                            flex: 1,
                                            child: AppButtonWidget(
                                              onPressed: () async {
                                                _model.filtroLinha = '';
                                                _model.filtroGrupo = '';
                                                _model.filtroMarca = '';
                                                _model.filtroFabricante = '';
                                                _model.filtroEstoque = false;
                                                _model.filtroPromocao = false;
                                                _model.filtroDataEntrada =
                                                    'Todas';
                                                safeSetState(() {});
                                                safeSetState(() {
                                                  _model
                                                      .ddFiltroLinhaValueController
                                                      ?.reset();
                                                  _model.ddFiltroLinhaValue =
                                                      null;
                                                  _model
                                                      .ddFiltroGrupoValueController
                                                      ?.reset();
                                                  _model.ddFiltroGrupoValue =
                                                      null;
                                                  _model
                                                      .ddFiltroFabricanteValueController
                                                      ?.reset();
                                                  _model.ddFiltroFabricanteValue =
                                                      null;
                                                  _model
                                                      .ddFiltroMarcaValueController
                                                      ?.reset();
                                                  _model.ddFiltroMarcaValue =
                                                      null;
                                                  _model
                                                      .ddDataEntValueController
                                                      ?.reset();
                                                  _model.ddDataEntValue = null;
                                                });
                                                _model.listaProdutos = _model
                                                    .resultadoOnLoad!
                                                    .toList()
                                                    .cast<
                                                        ProdutoResultStruct>();
                                                safeSetState(() {});
                                              },
                                              text: 'Limpar',
                                              icon: Icon(
                                                Icons.clear,
                                                size: 20.0,
                                              ),
                                              options: AppButtonOptions(
                                                height: 42.0,
                                                padding: EdgeInsetsDirectional
                                                    .fromSTEB(
                                                        0.0, 0.0, 0.0, 0.0),
                                                iconPadding:
                                                    EdgeInsetsDirectional
                                                        .fromSTEB(
                                                            0.0, 0.0, 0.0, 0.0),
                                                iconColor: Colors.white,
                                                color:
                                                    AppTheme.of(context)
                                                        .secondary,
                                                textStyle: TextStyle(
                                                  color: Colors.white,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(8.0),
                                              ),
                                            ),
                                          ),
                                          Expanded(
                                            flex: 2,
                                            child: AppButtonWidget(
                                              onPressed: () async {
                                                _model.resultadoOnLoadFiltro =
                                                    await actions.buscaProduto(
                                                  _model
                                                      .buscaProdutoFieldTextController
                                                      .text,
                                                  0,
                                                  _model.filtroLinha,
                                                  _model.filtroGrupo,
                                                  _model.filtroFabricante,
                                                  _model.filtroMarca,
                                                  _model.filtroEstoque,
                                                  _model.filtroPromocao,
                                                  functions.resolverCodFilial(
                                                      AppState()
                                                          .empresa_codigo),
                                                  _model.filtroDataEntrada,
                                                );
                                                _model.listaProdutos = _model
                                                    .resultadoOnLoadFiltro!
                                                    .toList()
                                                    .cast<
                                                        ProdutoResultStruct>();
                                                safeSetState(() {});
                                                _model.isFiltroExpanded = false;
                                                safeSetState(() {});

                                                safeSetState(() {});
                                              },
                                              text: 'Aplicar Filtros',
                                              icon: Icon(
                                                Icons.check,
                                                size: 20.0,
                                              ),
                                              options: AppButtonOptions(
                                                height: 42.0,
                                                padding: EdgeInsetsDirectional
                                                    .fromSTEB(
                                                        0.0, 0.0, 0.0, 0.0),
                                                iconPadding:
                                                    EdgeInsetsDirectional
                                                        .fromSTEB(
                                                            0.0, 0.0, 0.0, 0.0),
                                                iconColor: Colors.white,
                                                color:
                                                    AppTheme.of(context)
                                                        .primary,
                                                textStyle: TextStyle(
                                                  color: Colors.white,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(8.0),
                                              ),
                                            ),
                                          ),
                                        ].divide(SizedBox(width: 12.0)),
                                      ),
                                    ),
                                  ]
                                      .divide(SizedBox(height: 12.0))
                                      .addToStart(SizedBox(height: 12.0))
                                      .addToEnd(SizedBox(height: 12.0)),
                                ),
                              ),
                            ),
                          ),
                      ].divide(SizedBox(height: 12.0)),
                    ),
                  ),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(),
                      child: Builder(
                        builder: (context) {
                          if (_model.listaProdutos.isNotEmpty) {
                            return Builder(
                              builder: (context) {
                                final listaProduto =
                                    _model.listaProdutos.toList();

                                return ListView.separated(
                                  padding: EdgeInsets.zero,
                                  primary: false,
                                  scrollDirection: Axis.vertical,
                                  itemCount: listaProduto.length,
                                  separatorBuilder: (_, __) =>
                                      SizedBox(height: 12.0),
                                  itemBuilder: (context, listaProdutoIndex) {
                                    final listaProdutoItem =
                                        listaProduto[listaProdutoIndex];
                                    return Padding(
                                      padding: EdgeInsetsDirectional.fromSTEB(
                                          16.0, 0.0, 16.0, 0.0),
                                      child: InkWell(
                                        splashColor: Colors.transparent,
                                        focusColor: Colors.transparent,
                                        hoverColor: Colors.transparent,
                                        highlightColor: Colors.transparent,
                                        onTap: () async {
                                          if (widget.isSelectionMode) {
                                            _abrirModalAdicionarCarrinho(listaProdutoItem);
                                          } else {
                                            context.pushNamed(
                                              DetalheProdutoPageWidget.routeName,
                                              queryParameters: {
                                                'produtoRef': serializeParam(
                                                  listaProdutoItem.codigo,
                                                  ParamType.String,
                                                ),
                                              }.withoutNulls,
                                            );
                                          }
                                        },
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color: AppTheme.of(context)
                                                .secondaryBackground,
                                            borderRadius:
                                                BorderRadius.circular(12.0),
                                          ),
                                          child: Padding(
                                            padding: EdgeInsets.all(12.0),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.max,
                                              mainAxisAlignment:
                                                  MainAxisAlignment.start,
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.center,
                                              children: [
                                                Container(
                                                  width: 80.0,
                                                  height: 80.0,
                                                  child: custom_widgets
                                                      .ImagemLocalWidget(
                                                    width: 80.0,
                                                    height: 80.0,
                                                    caminhoArquivo:
                                                        listaProdutoItem.codigo,
                                                  ),
                                                ),
                                                Expanded(
                                                  flex: 1,
                                                  child: Column(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    mainAxisAlignment:
                                                        MainAxisAlignment.start,
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Row(
                                                        mainAxisSize:
                                                            MainAxisSize.max,
                                                        mainAxisAlignment:
                                                            MainAxisAlignment
                                                                .start,
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .center,
                                                        children: [
                                                          Text(
                                                            valueOrDefault<
                                                                String>(
                                                              listaProdutoItem
                                                                  .codigo,
                                                              '00000',
                                                            ),
                                                            style: AppTheme
                                                                    .of(context)
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
                                                                  fontWeight: FontWeight.w700,
                                                                  fontStyle: AppTheme.of(context).bodySmall.fontStyle,
                                                                ),
                                                          ),
                                                          Expanded(
                                                            flex: 1,
                                                            child: Text(
                                                              valueOrDefault<
                                                                  String>(
                                                                listaProdutoItem
                                                                    .descricao,
                                                                'Descrição',
                                                              ),
                                                              maxLines: 1,
                                                              style: AppTheme
                                                                      .of(context)
                                                                  .bodyLarge
                                                                  .override(
                                                                    font: GoogleFonts
                                                                        .inter(
                                                                      fontWeight: AppTheme.of(
                                                                              context)
                                                                          .bodyLarge
                                                                          .fontWeight,
                                                                      fontStyle: AppTheme.of(
                                                                              context)
                                                                          .bodyLarge
                                                                          .fontStyle,
                                                                    ),
                                                                    letterSpacing:
                                                                        0.0,
                                                                    fontWeight: AppTheme.of(
                                                                            context)
                                                                        .bodyLarge
                                                                        .fontWeight,
                                                                    fontStyle: AppTheme.of(
                                                                            context)
                                                                        .bodyLarge
                                                                        .fontStyle,
                                                                  ),
                                                              overflow:
                                                                  TextOverflow
                                                                      .ellipsis,
                                                            ),
                                                          ),
                                                        ].divide(SizedBox(
                                                            width: 8.0)),
                                                      ),
                                                      Row(
                                                        mainAxisSize:
                                                            MainAxisSize.max,
                                                        mainAxisAlignment:
                                                            MainAxisAlignment
                                                                .spaceBetween,
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .center,
                                                        children: [
                                                          Column(
                                                            mainAxisSize:
                                                                MainAxisSize
                                                                    .min,
                                                            mainAxisAlignment:
                                                                MainAxisAlignment
                                                                    .start,
                                                            crossAxisAlignment:
                                                                CrossAxisAlignment
                                                                    .start,
                                                            children: [
                                                              Text(
                                                                'UN',
                                                                style: AppTheme.of(
                                                                        context)
                                                                    .bodySmall
                                                                    .override(
                                                                      font: GoogleFonts
                                                                          .inter(
                                                                        fontWeight: AppTheme.of(context)
                                                                            .bodySmall
                                                                            .fontWeight,
                                                                        fontStyle: AppTheme.of(context)
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
                                                              Text(
                                                                valueOrDefault<
                                                                    String>(
                                                                  listaProdutoItem
                                                                      .unidade,
                                                                  'UN',
                                                                ),
                                                                style: AppTheme.of(
                                                                        context)
                                                                    .bodyMedium
                                                                    .override(
                                                                      font: GoogleFonts
                                                                          .inter(
                                                                        fontWeight:
                                                                            FontWeight.w500,
                                                                        fontStyle: AppTheme.of(context)
                                                                            .bodyMedium
                                                                            .fontStyle,
                                                                      ),
                                                                      letterSpacing:
                                                                          0.0,
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .w500,
                                                                      fontStyle: AppTheme.of(
                                                                              context)
                                                                          .bodyMedium
                                                                          .fontStyle,
                                                                    ),
                                                              ),
                                                            ],
                                                          ),
                                                          Column(
                                                            mainAxisSize:
                                                                MainAxisSize
                                                                    .min,
                                                            mainAxisAlignment:
                                                                MainAxisAlignment
                                                                    .start,
                                                            crossAxisAlignment:
                                                                CrossAxisAlignment
                                                                    .start,
                                                            children: [
                                                              Text(
                                                                'Estoque',
                                                                style: AppTheme.of(
                                                                        context)
                                                                    .bodySmall
                                                                    .override(
                                                                      font: GoogleFonts
                                                                          .inter(
                                                                        fontWeight: AppTheme.of(context)
                                                                            .bodySmall
                                                                            .fontWeight,
                                                                        fontStyle: AppTheme.of(context)
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
                                                              Text(
                                                                valueOrDefault<
                                                                    String>(
                                                                  listaProdutoItem
                                                                      .estoqueAtual
                                                                      .toString(),
                                                                  '0,00',
                                                                ),
                                                                style: AppTheme.of(
                                                                        context)
                                                                    .bodyMedium
                                                                    .override(
                                                                      font: GoogleFonts
                                                                          .inter(
                                                                        fontWeight:
                                                                            FontWeight.w500,
                                                                        fontStyle: AppTheme.of(context)
                                                                            .bodyMedium
                                                                            .fontStyle,
                                                                      ),
                                                                      letterSpacing:
                                                                          0.0,
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .w500,
                                                                      fontStyle: AppTheme.of(
                                                                              context)
                                                                          .bodyMedium
                                                                          .fontStyle,
                                                                    ),
                                                              ),
                                                            ],
                                                          ),
                                                          Column(
                                                            mainAxisSize:
                                                                MainAxisSize
                                                                    .min,
                                                            mainAxisAlignment:
                                                                MainAxisAlignment
                                                                    .start,
                                                            crossAxisAlignment:
                                                                CrossAxisAlignment
                                                                    .start,
                                                            children: [
                                                              Text(
                                                                'Preço',
                                                                style: AppTheme.of(
                                                                        context)
                                                                    .bodySmall
                                                                    .override(
                                                                      font: GoogleFonts
                                                                          .inter(
                                                                        fontWeight: AppTheme.of(context)
                                                                            .bodySmall
                                                                            .fontWeight,
                                                                        fontStyle: AppTheme.of(context)
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
                                                              Text(
                                                                valueOrDefault<
                                                                    String>(
                                                                  listaProdutoItem
                                                                      .preco
                                                                      .toString(),
                                                                  '0,00',
                                                                ),
                                                                style: AppTheme.of(
                                                                        context)
                                                                    .bodyMedium
                                                                    .override(
                                                                      font: GoogleFonts
                                                                          .inter(
                                                                        fontWeight:
                                                                            FontWeight.w700,
                                                                        fontStyle: AppTheme.of(context)
                                                                            .bodyMedium
                                                                            .fontStyle,
                                                                      ),
                                                                      color: (listaProdutoItem.preco > 0)
                                                                          ? const Color(0xFF2E7D32)
                                                                          : AppTheme.of(context).primaryText,
                                                                      fontSize:
                                                                          16.0,
                                                                      letterSpacing:
                                                                          0.0,
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .w700,
                                                                      fontStyle: AppTheme.of(
                                                                              context)
                                                                          .bodyMedium
                                                                          .fontStyle,
                                                                    ),
                                                              ),
                                                            ],
                                                          ),
                                                        ].divide(SizedBox(
                                                            width: 16.0)),
                                                      ),
                                                    ].divide(
                                                        SizedBox(height: 4.0)),
                                                  ),
                                                ),
                                              ].divide(SizedBox(width: 12.0)),
                                            ),
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
                              child: LoadingWidget(),
                            );
                          }
                        },
                      ),
                    ),
                  ),
                ].divide(SizedBox(height: 16.0)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

