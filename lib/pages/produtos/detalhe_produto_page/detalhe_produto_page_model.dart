import '/backend/schema/structs/index.dart';
import '/components/classification_row2/classification_row2_widget.dart';
import '/components/inventory_stat2/inventory_stat2_widget.dart';
import '/core/app_util.dart';
import 'detalhe_produto_page_widget.dart' show DetalheProdutoPageWidget;
import 'package:flutter/material.dart';

class DetalheProdutoPageModel
    extends AppModel<DetalheProdutoPageWidget> {
  ///  Local state fields for this page.

  ProdutoResultStruct? produtoResult;
  void updateProdutoResultStruct(Function(ProdutoResultStruct) updateFn) {
    updateFn(produtoResult ??= ProdutoResultStruct());
  }

  ///  State fields for stateful widgets in this page.

  // Stores action output result for [Custom Action - carregarProdutoDetalhe] action in DetalheProdutoPage widget.
  ProdutoResultStruct? resultadoBanco;
  // Model for InventoryStat.
  late InventoryStat2Model inventoryStatModel1;
  // Model for InventoryStat.
  late InventoryStat2Model inventoryStatModel2;
  // Model for InventoryStat.
  late InventoryStat2Model inventoryStatModel3;
  // Model for ClassificationRow.
  late ClassificationRow2Model classificationRowModel1;
  // Model for ClassificationRow.
  late ClassificationRow2Model classificationRowModel2;
  // Model for ClassificationRow.
  late ClassificationRow2Model classificationRowModel3;
  // Model for ClassificationRow.
  late ClassificationRow2Model classificationRowModel4;

  @override
  void initState(BuildContext context) {
    inventoryStatModel1 = createModel(context, () => InventoryStat2Model());
    inventoryStatModel2 = createModel(context, () => InventoryStat2Model());
    inventoryStatModel3 = createModel(context, () => InventoryStat2Model());
    classificationRowModel1 =
        createModel(context, () => ClassificationRow2Model());
    classificationRowModel2 =
        createModel(context, () => ClassificationRow2Model());
    classificationRowModel3 =
        createModel(context, () => ClassificationRow2Model());
    classificationRowModel4 =
        createModel(context, () => ClassificationRow2Model());
  }

  @override
  void dispose() {
    inventoryStatModel1.dispose();
    inventoryStatModel2.dispose();
    inventoryStatModel3.dispose();
    classificationRowModel1.dispose();
    classificationRowModel2.dispose();
    classificationRowModel3.dispose();
    classificationRowModel4.dispose();
  }
}
