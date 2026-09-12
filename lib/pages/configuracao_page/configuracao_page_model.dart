import '/core/app_util.dart';
import '../../core/services/empresa_logo_service.dart';
import 'configuracao_page_widget.dart' show ConfiguracaoPageWidget;
import 'package:flutter/material.dart';

class ConfiguracaoPageModel extends AppModel<ConfiguracaoPageWidget> {
  bool exibirLogoPdf = true;
  bool isLoading = true;

  @override
  void initState(BuildContext context) {}

  Future<void> carregarConfiguracoes() async {
    exibirLogoPdf = await EmpresaLogoService.instance.isExibirLogoPdfHabilitado();
    isLoading = false;
  }

  Future<void> alterarExibicaoLogoPdf(bool valor) async {
    exibirLogoPdf = valor;
    await EmpresaLogoService.instance.setExibirLogoPdf(valor);
  }

  @override
  void dispose() {}
}
