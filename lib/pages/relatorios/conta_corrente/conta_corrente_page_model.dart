import 'package:flutter/material.dart';
import '/core/app_util.dart';
import '/domain/models/conta_corrente_model.dart';
import '/services/conta_corrente_service.dart';
import 'conta_corrente_page_widget.dart' show ContaCorrentePageWidget;

class ContaCorrentePageModel extends AppModel<ContaCorrentePageWidget> {
  ContaCorrenteSaldo? saldo;
  List<ContaCorrenteMovimentacao> movimentacoes = [];
  bool isLoading = true;

  String filtroTipo = 'TODOS'; // 'TODOS', 'C', 'D'
  TextEditingController? searchController;
  FocusNode? searchFocusNode;

  @override
  void initState(BuildContext context) {
    searchController = TextEditingController();
    searchFocusNode = FocusNode();
  }

  @override
  void dispose() {
    searchController?.dispose();
    searchFocusNode?.dispose();
  }

  Future<void> carregarDados({BuildContext? context}) async {
    isLoading = true;
    if (context != null) onUpdate();

    try {
      final s = await ContaCorrenteService.obterSaldoConsolidado();
      final movs = await ContaCorrenteService.obterMovimentacoes(
        filtroTipo: filtroTipo,
        busca: searchController?.text,
      );

      saldo = s;
      movimentacoes = movs;
    } catch (e) {
      print('Erro ao carregar dados de Conta-Corrente: $e');
    } finally {
      isLoading = false;
      if (context != null) onUpdate();
    }
  }

  Future<void> alterarFiltro(String novoFiltro) async {
    filtroTipo = novoFiltro;
    await carregarDados();
  }
}
