import '/core/app_util.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/services/empresa_logo_service.dart';
import 'configuracao_page_widget.dart' show ConfiguracaoPageWidget;
import 'package:flutter/material.dart';

class ConfiguracaoPageModel extends AppModel<ConfiguracaoPageWidget> {
  bool exibirLogoPdf = true;
  bool isLoading = true;
  String versaoCargaSistema = '';

  @override
  void initState(BuildContext context) {}

  Future<void> carregarConfiguracoes() async {
    exibirLogoPdf = await EmpresaLogoService.instance.isExibirLogoPdfHabilitado();
    try {
      final prefs = await SharedPreferences.getInstance();
      versaoCargaSistema = prefs.getString('versao_carga_sistema') ?? '';
    } catch (_) {}
    if (versaoCargaSistema.isEmpty && AppState().versaoSistema.isNotEmpty) {
      versaoCargaSistema = AppState().versaoSistema;
    }
    isLoading = false;
  }

  Future<void> alterarExibicaoLogoPdf(bool valor) async {
    exibirLogoPdf = valor;
    await EmpresaLogoService.instance.setExibirLogoPdf(valor);
  }

  @override
  void dispose() {}
}
