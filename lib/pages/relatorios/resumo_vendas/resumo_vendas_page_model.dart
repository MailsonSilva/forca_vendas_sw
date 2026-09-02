import 'package:flutter/material.dart';
import '/core/app_util.dart';
import '/domain/models/resumo_vendas_model.dart';
import '/services/resumo_vendas_service.dart';
import 'resumo_vendas_page_widget.dart' show ResumoVendasPageWidget;

class ResumoVendasPageModel extends AppModel<ResumoVendasPageWidget> {
  ResumoVendasConsolidado? resumo;
  bool isLoading = true;

  DateTime dataInicio = DateTime.now();
  DateTime dataFim = DateTime.now();
  String filtroAtalho = 'HOJE'; // 'HOJE', '7DIAS', 'MES', 'CUSTOM'

  @override
  void initState(BuildContext context) {
    definirAtalho('HOJE');
  }

  @override
  void dispose() {}

  void definirAtalho(String atalho) {
    filtroAtalho = atalho;
    final now = DateTime.now();
    final hoje = DateTime(now.year, now.month, now.day);

    switch (atalho) {
      case 'HOJE':
        dataInicio = hoje;
        dataFim = hoje;
        break;
      case '7DIAS':
        dataInicio = hoje.subtract(const Duration(days: 6));
        dataFim = hoje;
        break;
      case 'MES':
        dataInicio = DateTime(now.year, now.month, 1);
        dataFim = hoje;
        break;
      case 'CUSTOM':
      default:
        break;
    }
  }

  Future<void> carregarDados({BuildContext? context}) async {
    isLoading = true;
    if (context != null) onUpdate();

    try {
      final res = await ResumoVendasService.obterResumoVendas(
        dataInicio: dataInicio,
        dataFim: dataFim,
      );
      resumo = res;
    } catch (e) {
      print('Erro ao carregar resumo de vendas: $e');
    } finally {
      isLoading = false;
      if (context != null) onUpdate();
    }
  }

  Future<void> alterarPeriodoCustomizado(DateTime inicio, DateTime fim) async {
    filtroAtalho = 'CUSTOM';
    dataInicio = DateTime(inicio.year, inicio.month, inicio.day);
    dataFim = DateTime(fim.year, fim.month, fim.day);
    await carregarDados();
  }

  Future<void> selecionarAtalho(String atalho) async {
    definirAtalho(atalho);
    await carregarDados();
  }
}
