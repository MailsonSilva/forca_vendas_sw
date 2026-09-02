import 'package:flutter/material.dart';
import '/core/app_util.dart';
import '/domain/models/carteira_roteirizacao_model.dart';
import '/services/carteira_roteirizacao_service.dart';
import 'carteira_roteirizacao_page_widget.dart' show CarteiraRoteirizacaoPageWidget;

class CarteiraRoteirizacaoPageModel extends AppModel<CarteiraRoteirizacaoPageWidget> {
  CarteiraRoteirizacaoResumo? resumo;
  bool isLoading = true;

  RoteirizacaoFiltro filtro = const RoteirizacaoFiltro();
  TextEditingController? searchController;
  FocusNode? searchFocusNode;

  List<String> ufsDisponiveis = [];
  List<String> cidadesDisponiveis = [];

  @override
  void initState(BuildContext context) {
    searchController = TextEditingController();
    searchFocusNode = FocusNode();

    // Inicializa com a rota do dia atual
    final diaHoje = CarteiraRoteirizacaoService.obterDiaSemanaAtual();
    filtro = RoteirizacaoFiltro(diaVisita: diaHoje);
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
      final res = await CarteiraRoteirizacaoService.obterCarteiraRoteirizada(
        filtro: filtro.copyWith(buscaTexto: searchController?.text),
      );
      final ufs = await CarteiraRoteirizacaoService.obterUfsDisponiveis();
      final cids = await CarteiraRoteirizacaoService.obterCidadesDisponiveis(uf: filtro.uf);

      resumo = res;
      ufsDisponiveis = ufs;
      cidadesDisponiveis = cids;
    } catch (e) {
      print('Erro ao carregar carteira roteirizada: $e');
    } finally {
      isLoading = false;
      if (context != null) onUpdate();
    }
  }

  Future<void> alterarDiaVisita(int dia) async {
    filtro = filtro.copyWith(diaVisita: dia);
    await carregarDados();
  }

  Future<void> alterarStatusAtivo(int status) async {
    filtro = filtro.copyWith(statusAtivo: status);
    await carregarDados();
  }

  Future<void> alterarTipoPessoa(int tipo) async {
    filtro = filtro.copyWith(tipoPessoa: tipo);
    await carregarDados();
  }

  Future<void> alterarUf(String? uf) async {
    filtro = filtro.copyWith(uf: uf, cidade: null);
    await carregarDados();
  }

  Future<void> alterarCidade(String? cid) async {
    filtro = filtro.copyWith(cidade: cid);
    await carregarDados();
  }
}
