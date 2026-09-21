import '/backend/schema/structs/index.dart';
import '/components/loading/loading_widget.dart';
import '/core/app_drop_down.dart';
import '/core/app_icon_button.dart';
import '/core/app_theme.dart';
import '/core/app_util.dart';
import '/core/app_widgets.dart';
import '/core/form_field_controller.dart';
import '/action_code/index.dart' as actions;
import '/widgets/index.dart' as custom_widgets;
import '/core/app_functions.dart' as functions;
import '/index.dart';
import 'package:easy_debounce/easy_debounce.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'busca_produto_page_model.dart';
export 'busca_produto_page_model.dart';

/// Consulta de estoque e catalogo de produtos com busca SQLite.
class BuscaProdutoPageWidget extends StatefulWidget {
  const BuscaProdutoPageWidget(
      {super.key, this.isSelectionMode = false, this.filtroInicial});

  final bool isSelectionMode;
  final String? filtroInicial;

  static String routeName = 'BuscaProdutoPage';
  static String routePath = '/estoque';

  @override
  State<BuscaProdutoPageWidget> createState() => _BuscaProdutoPageWidgetState();
}

class _BuscaProdutoPageWidgetState extends State<BuscaProdutoPageWidget> {
  late BuscaProdutoPageModel _model;
  final ScrollController _scrollController = ScrollController();
  bool _isLoadingMore = false;
  bool _hasMoreItems = true;

  final scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => BuscaProdutoPageModel());

    _scrollController.addListener(() {
      if (_scrollController.hasClients &&
          _scrollController.position.pixels >=
              _scrollController.position.maxScrollExtent - 300) {
        if (!_isLoadingMore && _hasMoreItems) {
          _carregarProximaPaginaProdutos();
        }
      }
    });

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
      final String filtroInicial = widget.filtroInicial?.trim() ?? '';
      _model.resultadoOnLoad = await actions.buscaProduto(
        filtroInicial,
        null,
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
      _hasMoreItems = _model.listaProdutos.length >= 100;
      safeSetState(() {});
      _model.dadosCarregados = true;
      safeSetState(() {});
    });

    _model.buscaProdutoFieldTextController ??=
        TextEditingController(text: widget.filtroInicial ?? '');
    _model.buscaProdutoFieldFocusNode ??= FocusNode();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _model.dispose();
    super.dispose();
  }

  Future<void> _carregarProximaPaginaProdutos() async {
    if (_isLoadingMore || !_hasMoreItems) return;
    _isLoadingMore = true;
    safeSetState(() {});
    try {
      final ultimoDescri = _model.listaProdutos.isNotEmpty
          ? _model.listaProdutos.last.descricao
          : null;
      final novos = await actions.buscaProduto(
        _model.buscaProdutoFieldTextController.text.trim(),
        ultimoDescri,
        _model.filtroLinha,
        _model.filtroGrupo,
        _model.filtroFabricante,
        _model.filtroMarca,
        _model.filtroEstoque,
        _model.filtroPromocao,
        functions.resolverCodFilial(AppState().empresa_codigo),
        _model.filtroDataEntrada,
      );
      if (novos.isEmpty || novos.length < 100) {
        _hasMoreItems = false;
      }
      _model.listaProdutos.addAll(novos);
    } catch (_) {
      _hasMoreItems = false;
    } finally {
      _isLoadingMore = false;
      if (mounted) safeSetState(() {});
    }
  }


  void _abrirModalAdicionarCarrinho(ProdutoResultStruct produto) async {
    final bool validaEstoque = (AppState().ven_chkest == 1);
    final bool temEstoque = !validaEstoque || (produto.saldoEstoque > 0);
    int quantidade = temEstoque ? 1 : 0;
    final qtdController = TextEditingController(text: '$quantidade');

    final itemSelecionado = await showModalBottomSheet<ItemPedidoStruct?>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (modalContext) {
        return StatefulBuilder(
          builder: (builderCtx, setModalState) {
            return Align(
              alignment: Alignment.bottomCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600.0),
                child: Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(20.0)),
                  ),
                  child: SafeArea(
                    top: false,
                    bottom: true,
                    child: Padding(
                      padding: EdgeInsets.only(
                        bottom:
                            MediaQuery.of(builderCtx).viewInsets.bottom + 16.0,
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
                              width: 48.0,
                              height: 5.0,
                              decoration: BoxDecoration(
                                color: const Color(0xFFE0E3E7),
                                borderRadius: BorderRadius.circular(2.5),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12.0),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.add_shopping_cart_rounded,
                                    color: AppTheme.of(builderCtx).primary,
                                    size: 24.0,
                                  ),
                                  const SizedBox(width: 8.0),
                                  const Text(
                                    'Adicionar ao Carrinho',
                                    style: TextStyle(
                                      fontSize: 18.0,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF14181B),
                                    ),
                                  ),
                                ],
                              ),
                              AppIconButton(
                                borderColor: Colors.transparent,
                                borderRadius: 20.0,
                                borderWidth: 1.0,
                                buttonSize: 38.0,
                                fillColor: const Color(0xFFF1F4F8),
                                icon: const Icon(
                                  Icons.close_rounded,
                                  color: Color(0xFF57636C),
                                  size: 20.0,
                                ),
                                onPressed: () =>
                                    Navigator.of(modalContext).pop(null),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8.0),
                          const Divider(
                              height: 1.0,
                              thickness: 1.0,
                              color: Color(0xFFE0E3E7)),
                          const SizedBox(height: 14.0),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16.0),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12.0),
                              border:
                                  Border.all(color: const Color(0xFFE0E3E7)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Cód. ${produto.codigo}',
                                  style: TextStyle(
                                    color: AppTheme.of(builderCtx).primary,
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
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Un: ${produto.unidade}',
                                      style: const TextStyle(
                                          color: Colors.grey, fontSize: 13.0),
                                    ),
                                    Text(
                                      'Preço: ${produto.preco.toMoeda()}',
                                      style: const TextStyle(
                                          color: Colors.grey, fontSize: 13.0),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8.0),
                                Row(
                                  children: [
                                    const Icon(Icons.inventory_2_outlined,
                                        color: Colors.grey, size: 16.0),
                                    const SizedBox(width: 4.0),
                                    const Text('Estoque disponível: ',
                                        style: TextStyle(
                                            color: Colors.grey,
                                            fontSize: 12.0)),
                                    Text(
                                      validaEstoque
                                          ? functions.formatQuantity(
                                              produto.saldoEstoque,
                                              unidade: produto.unidade,
                                            )
                                          : 'Ilimitado',
                                      style: TextStyle(
                                        color: (!validaEstoque ||
                                                produto.saldoEstoque > 0)
                                            ? AppTheme.of(builderCtx).primary
                                            : Colors.red,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12.0,
                                      ),
                                    ),
                                  ],
                                ),
                                if (validaEstoque &&
                                    produto.saldoEstoque <= 0) ...[
                                  const SizedBox(height: 12.0),
                                  const Row(
                                    children: [
                                      Icon(Icons.warning_amber_rounded,
                                          color: Colors.red, size: 18.0),
                                      SizedBox(width: 6.0),
                                      Expanded(
                                        child: Text(
                                          'Produto indisponível: Estoque esgotado (Saldo: 0)',
                                          style: TextStyle(
                                              color: Colors.red,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13.0),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 20.0),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  color: const Color(0xFFAED5E6),
                                  borderRadius: BorderRadius.circular(8.0),
                                ),
                                child: IconButton(
                                  icon: const Icon(Icons.remove,
                                      color: Colors.white),
                                  onPressed: quantidade > 1
                                      ? () => setModalState(() {
                                            quantidade--;
                                            qtdController.text = '$quantidade';
                                          })
                                      : null,
                                  constraints: const BoxConstraints(
                                      minWidth: 48, minHeight: 48),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                                child: SizedBox(
                                  width: 80.0,
                                  child: TextFormField(
                                    controller: qtdController,
                                    keyboardType: TextInputType.number,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                    ],
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18.0,
                                    ),
                                    decoration: InputDecoration(
                                      contentPadding: const EdgeInsets.symmetric(
                                          vertical: 12.0, horizontal: 4.0),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8.0),
                                        borderSide: BorderSide(
                                            color: AppTheme.of(builderCtx).primary),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8.0),
                                        borderSide: BorderSide(
                                            color: AppTheme.of(builderCtx).primary),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8.0),
                                        borderSide: BorderSide(
                                            color: AppTheme.of(builderCtx).primary,
                                            width: 2.0),
                                      ),
                                    ),
                                    onTap: () {
                                      qtdController.selection = TextSelection(
                                        baseOffset: 0,
                                        extentOffset: qtdController.text.length,
                                      );
                                    },
                                    onChanged: (val) {
                                      int parsed = int.tryParse(val) ?? 0;
                                      if (validaEstoque &&
                                          parsed > produto.saldoEstoque) {
                                        parsed = produto.saldoEstoque.toInt();
                                        qtdController.text = parsed.toString();
                                        qtdController.selection =
                                            TextSelection.collapsed(
                                                offset: qtdController.text.length);
                                      }
                                      setModalState(() {
                                        quantidade = parsed;
                                      });
                                    },
                                  ),
                                ),
                              ),
                              Container(
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0288D1),
                                  borderRadius: BorderRadius.circular(8.0),
                                ),
                                child: IconButton(
                                  icon: const Icon(Icons.add,
                                      color: Colors.white),
                                  onPressed: (!validaEstoque ||
                                          quantidade < produto.saldoEstoque)
                                      ? () => setModalState(() {
                                            quantidade++;
                                            qtdController.text = '$quantidade';
                                          })
                                      : null,
                                  constraints: const BoxConstraints(
                                      minWidth: 48, minHeight: 48),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 20.0),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Total do Item',
                                style: TextStyle(
                                    color: Colors.grey, fontSize: 16.0),
                              ),
                              Text(
                                (produto.preco * quantidade).toMoeda(),
                                style: TextStyle(
                                  color: AppTheme.of(builderCtx).primary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 20.0,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20.0),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(color: Colors.grey),
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 16.0),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(8.0)),
                                  ),
                                  onPressed: () =>
                                      Navigator.of(modalContext).pop(null),
                                  child: const Text('Cancelar',
                                      style: TextStyle(
                                          color: Colors.grey,
                                          fontWeight: FontWeight.bold)),
                                ),
                              ),
                              const SizedBox(width: 12.0),
                              Expanded(
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor:
                                        AppTheme.of(builderCtx).primary,
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 16.0),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(8.0)),
                                  ),
                                  onPressed: quantidade > 0
                                      ? () {
                                          final mul = (produto.mulver != 0)
                                              ? produto.mulver
                                              : 1.0;
                                          final item = ItemPedidoStruct(
                                            codigoProduto: produto.codigo,
                                            descricao: produto.descricao,
                                            unidade: produto.unidade,
                                            precoUnitario: produto.preco,
                                            quantidade: quantidade.toDouble(),
                                            totalItem:
                                                produto.preco * quantidade,
                                            mulver: mul,
                                            unidadeComercial:
                                                quantidade.toDouble() * mul,
                                            embalagem:
                                                produto.embalagem.isNotEmpty
                                                    ? produto.embalagem
                                                    : produto.unidade,
                                            marca: produto.marca,
                                            referencia:
                                                produto.referenciaFormatada,
                                            codbar: produto.codbar,
                                          );
                                          Navigator.of(modalContext).pop(item);
                                        }
                                      : null,
                                  icon: const Icon(Icons.shopping_cart_outlined,
                                      color: Colors.white, size: 20.0),
                                  label: const Text('Adicionar',
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold)),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
    qtdController.dispose();

    if (itemSelecionado != null && mounted) {
      Navigator.of(context).pop(itemSelecionado);
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
            'Pesquisa de Produtos',
            style: AppTheme.of(context).titleLarge.override(
                  font: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w600,
                    fontStyle: AppTheme.of(context).titleLarge.fontStyle,
                  ),
                  color: AppTheme.of(context).secondaryBackground,
                  fontSize: 22.0,
                  letterSpacing: 0.0,
                  fontWeight: FontWeight.w600,
                  fontStyle: AppTheme.of(context).titleLarge.fontStyle,
                ),
          ),
          actions: const [],
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
              padding:
                  const EdgeInsetsDirectional.fromSTEB(0.0, 16.0, 0.0, 16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    decoration: const BoxDecoration(),
                    child: Column(
                      mainAxisSize: MainAxisSize.max,
                      children: [
                        Padding(
                          padding: const EdgeInsetsDirectional.fromSTEB(
                              16.0, 0.0, 16.0, 0.0),
                          child: TextFormField(
                            controller: _model.buscaProdutoFieldTextController,
                            focusNode: _model.buscaProdutoFieldFocusNode,
                            onChanged: (_) => EasyDebounce.debounce(
                              '_model.buscaProdutoFieldTextController',
                              const Duration(milliseconds: 350),
                              () async {
                                _model.resultadoBusca =
                                    await actions.buscaProduto(
                                  _model.buscaProdutoFieldTextController.text,
                                  null,
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
                                _hasMoreItems =
                                    _model.listaProdutos.length >= 100;
                                safeSetState(() {});
                              },
                            ),
                            textInputAction: TextInputAction.search,
                            obscureText: false,
                            decoration: InputDecoration(
                              labelText: 'Produto',
                              hintText:
                                  'Pesquise por descrição, EAN, marca ou referência...',
                              hintStyle: TextStyle(
                                fontSize: 12.0,
                                color: Colors.grey.shade500,
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
                              fillColor:
                                  AppTheme.of(context).secondaryBackground,
                              prefixIcon: Icon(
                                Icons.search,
                                color: AppTheme.of(context).secondaryText,
                              ),
                              suffixIcon: _model
                                      .buscaProdutoFieldTextController!
                                      .text
                                      .isNotEmpty
                                  ? InkWell(
                                      onTap: () async {
                                        _model.buscaProdutoFieldTextController
                                            ?.clear();
                                        _model.resultadoBusca =
                                            await actions.buscaProduto(
                                          '',
                                          null,
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
                                        _model.listaProdutos = _model
                                            .resultadoBusca!
                                            .toList()
                                            .cast<ProdutoResultStruct>();
                                        _hasMoreItems =
                                            _model.listaProdutos.length >= 100;
                                        safeSetState(() {});
                                      },
                                      child: Icon(
                                        Icons.clear_rounded,
                                        color:
                                            AppTheme.of(context).secondaryText,
                                        size: 20.0,
                                      ),
                                    )
                                  : null,
                            ),
                            style: const TextStyle(),
                            maxLines: null,
                            validator: _model
                                .buscaProdutoFieldTextControllerValidator
                                .asValidator(context),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsetsDirectional.fromSTEB(
                              16.0, 0.0, 16.0, 0.0),
                          child: Container(
                            width: double.infinity,
                            height: 50.0,
                            decoration: BoxDecoration(
                              color: AppTheme.of(context).secondaryBackground,
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
                              borderRadius: BorderRadius.circular(12.0),
                            ),
                            child: Padding(
                              padding: const EdgeInsetsDirectional.fromSTEB(
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
                                      color: AppTheme.of(context).primary,
                                      size: 24.0,
                                    ),
                                    Expanded(
                                      child: Padding(
                                        padding: const EdgeInsetsDirectional
                                            .fromSTEB(8.0, 0.0, 0.0, 0.0),
                                        child: Text(
                                          'Filtros Avançados',
                                          style: AppTheme.of(context)
                                              .bodyMedium
                                              .override(
                                                font: GoogleFonts.inter(
                                                  fontWeight: FontWeight.w500,
                                                  fontStyle:
                                                      AppTheme.of(context)
                                                          .bodyMedium
                                                          .fontStyle,
                                                ),
                                                color: AppTheme.of(context)
                                                    .primary,
                                                fontSize: 16.0,
                                                letterSpacing: 0.0,
                                                fontWeight: FontWeight.w500,
                                                fontStyle: AppTheme.of(context)
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
                                            color: AppTheme.of(context).primary,
                                            size: 24.0,
                                          );
                                        } else {
                                          return Icon(
                                            Icons.keyboard_arrow_down,
                                            color: AppTheme.of(context).primary,
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
                            padding: const EdgeInsetsDirectional.fromSTEB(
                                16.0, 0.0, 16.0, 0.0),
                            child: Container(
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: AppTheme.of(context).secondaryBackground,
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
                                borderRadius: BorderRadius.circular(12.0),
                              ),
                              child: Padding(
                                padding: const EdgeInsetsDirectional.fromSTEB(
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
                                                      AppTheme.of(context)
                                                          .labelMedium
                                                          .fontWeight,
                                                  fontStyle:
                                                      AppTheme.of(context)
                                                          .labelMedium
                                                          .fontStyle,
                                                ),
                                                color: AppTheme.of(context)
                                                    .secondaryText,
                                                letterSpacing: 0.0,
                                                fontWeight: AppTheme.of(context)
                                                    .labelMedium
                                                    .fontWeight,
                                                fontStyle: AppTheme.of(context)
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
                                          textStyle: AppTheme.of(context)
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
                                                letterSpacing: 0.0,
                                                fontWeight: AppTheme.of(context)
                                                    .bodyMedium
                                                    .fontWeight,
                                                fontStyle: AppTheme.of(context)
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
                                          fillColor: AppTheme.of(context)
                                              .secondaryBackground,
                                          elevation: 2.0,
                                          borderColor:
                                              AppTheme.of(context).secondary,
                                          borderWidth: 1.0,
                                          borderRadius: 8.0,
                                          margin: const EdgeInsetsDirectional
                                              .fromSTEB(12.0, 0.0, 12.0, 0.0),
                                          hidesUnderline: true,
                                          isOverButton: false,
                                          isSearchable: false,
                                          isMultiSelect: false,
                                        ),
                                      ].divide(const SizedBox(height: 4.0)),
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
                                                      AppTheme.of(context)
                                                          .labelMedium
                                                          .fontWeight,
                                                  fontStyle:
                                                      AppTheme.of(context)
                                                          .labelMedium
                                                          .fontStyle,
                                                ),
                                                color: AppTheme.of(context)
                                                    .secondaryText,
                                                letterSpacing: 0.0,
                                                fontWeight: AppTheme.of(context)
                                                    .labelMedium
                                                    .fontWeight,
                                                fontStyle: AppTheme.of(context)
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
                                          textStyle: AppTheme.of(context)
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
                                                letterSpacing: 0.0,
                                                fontWeight: AppTheme.of(context)
                                                    .bodyMedium
                                                    .fontWeight,
                                                fontStyle: AppTheme.of(context)
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
                                          fillColor: AppTheme.of(context)
                                              .secondaryBackground,
                                          elevation: 2.0,
                                          borderColor:
                                              AppTheme.of(context).secondary,
                                          borderWidth: 1.0,
                                          borderRadius: 8.0,
                                          margin: const EdgeInsetsDirectional
                                              .fromSTEB(12.0, 0.0, 12.0, 0.0),
                                          hidesUnderline: true,
                                          isOverButton: false,
                                          isSearchable: false,
                                          isMultiSelect: false,
                                        ),
                                      ].divide(const SizedBox(height: 4.0)),
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
                                                      AppTheme.of(context)
                                                          .labelMedium
                                                          .fontWeight,
                                                  fontStyle:
                                                      AppTheme.of(context)
                                                          .labelMedium
                                                          .fontStyle,
                                                ),
                                                color: AppTheme.of(context)
                                                    .secondaryText,
                                                letterSpacing: 0.0,
                                                fontWeight: AppTheme.of(context)
                                                    .labelMedium
                                                    .fontWeight,
                                                fontStyle: AppTheme.of(context)
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
                                          textStyle: AppTheme.of(context)
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
                                                letterSpacing: 0.0,
                                                fontWeight: AppTheme.of(context)
                                                    .bodyMedium
                                                    .fontWeight,
                                                fontStyle: AppTheme.of(context)
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
                                          fillColor: AppTheme.of(context)
                                              .secondaryBackground,
                                          elevation: 2.0,
                                          borderColor:
                                              AppTheme.of(context).secondary,
                                          borderWidth: 1.0,
                                          borderRadius: 8.0,
                                          margin: const EdgeInsetsDirectional
                                              .fromSTEB(12.0, 0.0, 12.0, 0.0),
                                          hidesUnderline: true,
                                          isOverButton: false,
                                          isSearchable: false,
                                          isMultiSelect: false,
                                        ),
                                      ].divide(const SizedBox(height: 4.0)),
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
                                                      AppTheme.of(context)
                                                          .labelMedium
                                                          .fontWeight,
                                                  fontStyle:
                                                      AppTheme.of(context)
                                                          .labelMedium
                                                          .fontStyle,
                                                ),
                                                color: AppTheme.of(context)
                                                    .secondaryText,
                                                letterSpacing: 0.0,
                                                fontWeight: AppTheme.of(context)
                                                    .labelMedium
                                                    .fontWeight,
                                                fontStyle: AppTheme.of(context)
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
                                          textStyle: AppTheme.of(context)
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
                                                letterSpacing: 0.0,
                                                fontWeight: AppTheme.of(context)
                                                    .bodyMedium
                                                    .fontWeight,
                                                fontStyle: AppTheme.of(context)
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
                                          fillColor: AppTheme.of(context)
                                              .secondaryBackground,
                                          elevation: 2.0,
                                          borderColor:
                                              AppTheme.of(context).secondary,
                                          borderWidth: 1.0,
                                          borderRadius: 8.0,
                                          margin: const EdgeInsetsDirectional
                                              .fromSTEB(12.0, 0.0, 12.0, 0.0),
                                          hidesUnderline: true,
                                          isOverButton: false,
                                          isSearchable: false,
                                          isMultiSelect: false,
                                        ),
                                      ].divide(const SizedBox(height: 4.0)),
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
                                                      AppTheme.of(context)
                                                          .labelMedium
                                                          .fontWeight,
                                                  fontStyle:
                                                      AppTheme.of(context)
                                                          .labelMedium
                                                          .fontStyle,
                                                ),
                                                color: AppTheme.of(context)
                                                    .secondaryText,
                                                letterSpacing: 0.0,
                                                fontWeight: AppTheme.of(context)
                                                    .labelMedium
                                                    .fontWeight,
                                                fontStyle: AppTheme.of(context)
                                                    .labelMedium
                                                    .fontStyle,
                                                lineHeight: 1.38,
                                              ),
                                        ),
                                        AppDropDown<String>(
                                          controller: _model
                                                  .ddDataEntValueController ??=
                                              FormFieldController<String>(null),
                                          options: const [
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
                                          textStyle: AppTheme.of(context)
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
                                                letterSpacing: 0.0,
                                                fontWeight: AppTheme.of(context)
                                                    .bodyMedium
                                                    .fontWeight,
                                                fontStyle: AppTheme.of(context)
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
                                          fillColor: AppTheme.of(context)
                                              .secondaryBackground,
                                          elevation: 2.0,
                                          borderColor:
                                              AppTheme.of(context).secondary,
                                          borderWidth: 1.0,
                                          borderRadius: 8.0,
                                          margin: const EdgeInsetsDirectional
                                              .fromSTEB(12.0, 0.0, 12.0, 0.0),
                                          hidesUnderline: true,
                                          isOverButton: false,
                                          isSearchable: false,
                                          isMultiSelect: false,
                                        ),
                                      ].divide(const SizedBox(height: 4.0)),
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
                                                side: BorderSide(
                                                  width: 2,
                                                  color: AppTheme.of(context)
                                                      .secondaryText,
                                                ),
                                                activeColor:
                                                    AppTheme.of(context)
                                                        .primary,
                                                checkColor: AppTheme.of(context)
                                                    .primaryBackground,
                                              ),
                                            ),
                                            Container(
                                              width: 8.0,
                                            ),
                                            const Text(
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
                                                side: BorderSide(
                                                  width: 2,
                                                  color: AppTheme.of(context)
                                                      .secondaryText,
                                                ),
                                                activeColor:
                                                    AppTheme.of(context)
                                                        .primary,
                                                checkColor: AppTheme.of(context)
                                                    .primaryBackground,
                                              ),
                                            ),
                                            Container(
                                              width: 8.0,
                                            ),
                                            const Text(
                                              'Com estoque',
                                              style: TextStyle(),
                                            ),
                                          ],
                                        ),
                                      ].divide(const SizedBox(width: 12.0)),
                                    ),
                                    Padding(
                                      padding:
                                          const EdgeInsetsDirectional.fromSTEB(
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
                                              icon: const Icon(
                                                Icons.clear,
                                                size: 20.0,
                                              ),
                                              options: AppButtonOptions(
                                                height: 42.0,
                                                padding:
                                                    const EdgeInsetsDirectional
                                                        .fromSTEB(
                                                        0.0, 0.0, 0.0, 0.0),
                                                iconPadding:
                                                    const EdgeInsetsDirectional
                                                        .fromSTEB(
                                                        0.0, 0.0, 0.0, 0.0),
                                                iconColor: Colors.white,
                                                color: AppTheme.of(context)
                                                    .secondary,
                                                textStyle: const TextStyle(
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
                                                  null,
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
                                              icon: const Icon(
                                                Icons.check,
                                                size: 20.0,
                                              ),
                                              options: AppButtonOptions(
                                                height: 42.0,
                                                padding:
                                                    const EdgeInsetsDirectional
                                                        .fromSTEB(
                                                        0.0, 0.0, 0.0, 0.0),
                                                iconPadding:
                                                    const EdgeInsetsDirectional
                                                        .fromSTEB(
                                                        0.0, 0.0, 0.0, 0.0),
                                                iconColor: Colors.white,
                                                color: AppTheme.of(context)
                                                    .primary,
                                                textStyle: const TextStyle(
                                                  color: Colors.white,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(8.0),
                                              ),
                                            ),
                                          ),
                                        ].divide(const SizedBox(width: 12.0)),
                                      ),
                                    ),
                                  ]
                                      .divide(const SizedBox(height: 12.0))
                                      .addToStart(const SizedBox(height: 12.0))
                                      .addToEnd(const SizedBox(height: 12.0)),
                                ),
                              ),
                            ),
                          ),
                      ].divide(const SizedBox(height: 12.0)),
                    ),
                  ),
                  Expanded(
                    child: Container(
                      decoration: const BoxDecoration(),
                      child: Builder(
                        builder: (context) {
                          if (_model.listaProdutos.isNotEmpty) {
                            return Builder(
                              builder: (context) {
                                final listaProduto =
                                    _model.listaProdutos.toList();

                                return ListView.separated(
                                  controller: _scrollController,
                                  padding: EdgeInsets.zero,
                                  scrollDirection: Axis.vertical,
                                  itemCount: listaProduto.length + (_isLoadingMore ? 1 : 0),
                                  separatorBuilder: (_, __) =>
                                      const SizedBox(height: 12.0),
                                  itemBuilder: (context, listaProdutoIndex) {
                                    if (listaProdutoIndex >= listaProduto.length) {
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
                                    final listaProdutoItem =
                                        listaProduto[listaProdutoIndex];
                                    return Padding(
                                      padding:
                                          const EdgeInsetsDirectional.fromSTEB(
                                              16.0, 0.0, 16.0, 0.0),
                                      child: InkWell(
                                        splashColor: Colors.transparent,
                                        focusColor: Colors.transparent,
                                        hoverColor: Colors.transparent,
                                        highlightColor: Colors.transparent,
                                        onTap: () async {
                                          if (widget.isSelectionMode) {
                                            _abrirModalAdicionarCarrinho(
                                                listaProdutoItem);
                                          } else {
                                            context.pushNamed(
                                              DetalheProdutoPageWidget
                                                  .routeName,
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
                                            padding: const EdgeInsets.all(12.0),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.max,
                                              mainAxisAlignment:
                                                  MainAxisAlignment.start,
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.center,
                                              children: [
                                                SizedBox(
                                                  width: 80.0,
                                                  height: 80.0,
                                                  child: custom_widgets
                                                      .ImagemLocalWidget(
                                                    width: 80.0,
                                                    height: 80.0,
                                                    caminhoArquivo:
                                                        listaProdutoItem.codigo,
                                                    titulo: listaProdutoItem
                                                        .descricao,
                                                    subtitulo:
                                                        'Cód: ${listaProdutoItem.codigo} • ${listaProdutoItem.preco.toMoeda()}',
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
                                                            style:
                                                                AppTheme.of(
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
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .w700,
                                                                      fontStyle: AppTheme.of(
                                                                              context)
                                                                          .bodySmall
                                                                          .fontStyle,
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
                                                              style: AppTheme.of(
                                                                      context)
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
                                                        ].divide(const SizedBox(
                                                            width: 8.0)),
                                                      ),
                                                      const SizedBox(
                                                          height: 4.0),
                                                      Row(
                                                        mainAxisSize:
                                                            MainAxisSize.max,
                                                        children: [
                                                          Text(
                                                            'Marca: ${listaProdutoItem.marca.isNotEmpty ? listaProdutoItem.marca : "SEM MARCA"}',
                                                            style:
                                                                AppTheme.of(
                                                                        context)
                                                                    .bodySmall
                                                                    .override(
                                                                      font: GoogleFonts.inter(
                                                                          fontWeight:
                                                                              FontWeight.w600),
                                                                      color: AppTheme.of(
                                                                              context)
                                                                          .secondaryText,
                                                                      fontSize:
                                                                          11.0,
                                                                    ),
                                                          ),
                                                          Text(
                                                            '  |  ',
                                                            style: TextStyle(
                                                                color: AppTheme.of(
                                                                        context)
                                                                    .alternate,
                                                                fontSize: 11.0),
                                                          ),
                                                          Expanded(
                                                            child: Text(
                                                              'Ref: ${listaProdutoItem.referenciaFormatada}',
                                                              maxLines: 1,
                                                              overflow:
                                                                  TextOverflow
                                                                      .ellipsis,
                                                              style: AppTheme.of(
                                                                      context)
                                                                  .bodySmall
                                                                  .override(
                                                                    font: GoogleFonts.inter(
                                                                        fontWeight:
                                                                            FontWeight.w500),
                                                                    color: AppTheme.of(
                                                                            context)
                                                                        .secondaryText,
                                                                    fontSize:
                                                                        11.0,
                                                                  ),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                      if (listaProdutoItem
                                                          .codbar.isNotEmpty)
                                                        Padding(
                                                          padding:
                                                              const EdgeInsets
                                                                  .only(
                                                                  top: 2.0),
                                                          child: Text(
                                                            'EAN: ${listaProdutoItem.codbar}',
                                                            style:
                                                                AppTheme.of(
                                                                        context)
                                                                    .bodySmall
                                                                    .override(
                                                                      font: GoogleFonts.inter(
                                                                          fontWeight:
                                                                              FontWeight.w500),
                                                                      color: AppTheme.of(
                                                                              context)
                                                                          .secondaryText,
                                                                      fontSize:
                                                                          11.0,
                                                                    ),
                                                          ),
                                                        ),
                                                      const SizedBox(
                                                          height: 6.0),
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
                                                                functions.formatQuantity(
                                                                  listaProdutoItem.saldoEstoque,
                                                                  unidade: listaProdutoItem.unidade,
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
                                                                'UN.',
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
                                                                          .unidade
                                                                          .isNotEmpty
                                                                      ? listaProdutoItem
                                                                          .unidade
                                                                      : (listaProdutoItem
                                                                              .embalagem
                                                                              .isNotEmpty
                                                                          ? listaProdutoItem
                                                                              .embalagem
                                                                          : 'UN'),
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
                                                                listaProdutoItem
                                                                    .preco
                                                                    .toMoeda(),
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
                                                                      color: (listaProdutoItem.preco >
                                                                              0)
                                                                          ? const Color(
                                                                              0xFF2E7D32)
                                                                          : AppTheme.of(context)
                                                                              .primaryText,
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
                                                        ].divide(const SizedBox(
                                                            width: 16.0)),
                                                      ),
                                                    ].divide(const SizedBox(
                                                        height: 4.0)),
                                                  ),
                                                ),
                                              ].divide(
                                                  const SizedBox(width: 12.0)),
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
                              child: const LoadingWidget(),
                            );
                          }
                        },
                      ),
                    ),
                  ),
                ].divide(const SizedBox(height: 16.0)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
