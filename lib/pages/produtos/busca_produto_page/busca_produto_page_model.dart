import '/backend/schema/structs/index.dart';
import '/components/loading/loading_widget.dart';
import '/core/app_util.dart';
import '/core/form_field_controller.dart';
import '/index.dart';
import 'busca_produto_page_widget.dart' show BuscaProdutoPageWidget;
import 'package:flutter/material.dart';

class BuscaProdutoPageModel extends AppModel<BuscaProdutoPageWidget> {
  ///  Local state fields for this page.

  List<ProdutoResultStruct> listaProdutos = [];
  void addToListaProdutos(ProdutoResultStruct item) => listaProdutos.add(item);
  void removeFromListaProdutos(ProdutoResultStruct item) =>
      listaProdutos.remove(item);
  void removeAtIndexFromListaProdutos(int index) =>
      listaProdutos.removeAt(index);
  void insertAtIndexInListaProdutos(int index, ProdutoResultStruct item) =>
      listaProdutos.insert(index, item);
  void updateListaProdutosAtIndex(
          int index, Function(ProdutoResultStruct) updateFn) =>
      listaProdutos[index] = updateFn(listaProdutos[index]);

  int? offsetAtual = 0;

  String filtroLinha = '';

  String filtroGrupo = '';

  String filtroMarca = '';

  String filtroFabricante = '';

  bool filtroEstoque = false;

  bool filtroPromocao = false;

  bool isFiltroExpanded = false;

  String? filtroDataEntrada = 'Todas';

  bool dadosCarregados = false;

  ///  State fields for stateful widgets in this page.

  // Stores action output result for [Custom Action - carregarFiltros] action in BuscaProdutoPage widget.
  List<ListaPadraoStruct>? listaLinha;
  // Stores action output result for [Custom Action - carregarFiltros] action in BuscaProdutoPage widget.
  List<ListaPadraoStruct>? listaGrupo;
  // Stores action output result for [Custom Action - carregarFiltros] action in BuscaProdutoPage widget.
  List<ListaPadraoStruct>? listaFab;
  // Stores action output result for [Custom Action - carregarFiltros] action in BuscaProdutoPage widget.
  List<ListaPadraoStruct>? listaMarca;
  // Stores action output result for [Custom Action - buscaProduto] action in BuscaProdutoPage widget.
  List<ProdutoResultStruct>? resultadoOnLoad;
  // State field(s) for BuscaProdutoField widget.
  FocusNode? buscaProdutoFieldFocusNode;
  TextEditingController? buscaProdutoFieldTextController;
  String? Function(BuildContext, String?)?
      buscaProdutoFieldTextControllerValidator;
  // Stores action output result for [Custom Action - buscaProduto] action in BuscaProdutoField widget.
  List<ProdutoResultStruct>? resultadoBusca;
  // State field(s) for DdFiltroLinha widget.
  String? ddFiltroLinhaValue;
  FormFieldController<String>? ddFiltroLinhaValueController;
  // State field(s) for DdFiltroGrupo widget.
  String? ddFiltroGrupoValue;
  FormFieldController<String>? ddFiltroGrupoValueController;
  // State field(s) for DdFiltroFabricante widget.
  String? ddFiltroFabricanteValue;
  FormFieldController<String>? ddFiltroFabricanteValueController;
  // State field(s) for DdFiltroMarca widget.
  String? ddFiltroMarcaValue;
  FormFieldController<String>? ddFiltroMarcaValueController;
  // State field(s) for DdDataEnt widget.
  String? ddDataEntValue;
  FormFieldController<String>? ddDataEntValueController;
  // State field(s) for CheckboxPromo widget.
  bool? checkboxPromoValue;
  // State field(s) for CheckboxEstoque widget.
  bool? checkboxEstoqueValue;
  // Stores action output result for [Custom Action - buscaProduto] action in BotaoAplicar widget.
  List<ProdutoResultStruct>? resultadoOnLoadFiltro;
  // Model for Loading component.
  late LoadingModel loadingModel;

  @override
  void initState(BuildContext context) {
    loadingModel = createModel(context, () => LoadingModel());
  }

  @override
  void dispose() {
    buscaProdutoFieldFocusNode?.dispose();
    buscaProdutoFieldTextController?.dispose();

    loadingModel.dispose();
  }
}
