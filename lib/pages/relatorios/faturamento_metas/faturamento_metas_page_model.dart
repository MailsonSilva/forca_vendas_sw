import 'package:flutter/material.dart';
import '/core/app_util.dart';
import '/domain/models/faturamento_metas_model.dart';
import '/services/faturamento_metas_service.dart';
import 'faturamento_metas_page_widget.dart' show FaturamentoMetasPageWidget;

class FaturamentoMetasPageModel extends AppModel<FaturamentoMetasPageWidget> {
  bool isLoading = false;
  FaturamentoConsolidadoResumo? dadosMetas;

  @override
  void initState(BuildContext context) {}

  @override
  void dispose() {}

  /// Carrega os dados de metas consolidadas do vendedor.
  Future<void> carregarMetas({int? codVen, int? codFil, BuildContext? context}) async {
    isLoading = true;
    if (context != null) onUpdate();

    try {
      dadosMetas = await FaturamentoMetasService.obterMetasConsolidadas(
        codVen: codVen,
        codFil: codFil,
      );
    } catch (e) {
      debugPrint('Erro ao carregar metas e faturamento: $e');
      dadosMetas = FaturamentoConsolidadoResumo.empty();
    } finally {
      isLoading = false;
      if (context != null) onUpdate();
    }
  }
}
