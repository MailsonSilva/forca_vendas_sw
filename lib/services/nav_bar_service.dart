import 'package:flutter/foundation.dart';

/// Controla e sincroniza a aba ativa do [NavBarPage].
///
/// Permite que qualquer componente filho (como [ConfiguracaoPageWidget]) solicite
/// a alternância de abas sem depender de contexto rígido ou recriação de rotas.
class NavBarService extends ChangeNotifier {
  static final NavBarService _instance = NavBarService._internal();
  factory NavBarService() => _instance;
  NavBarService._internal();

  static const String homeTab = 'HomePage';
  static const String configuracaoTab = 'ConfiguracaoPage';

  String _currentTab = homeTab;
  String get currentTab => _currentTab;

  void selectTab(String tabName) {
    _currentTab = tabName;
    notifyListeners();
  }

  void navegarParaHome() {
    selectTab(homeTab);
  }

  void navegarParaConfiguracao() {
    selectTab(configuracaoTab);
  }
}
