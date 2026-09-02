import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '/backend/schema/structs/index.dart';

import '/main.dart';
import '/core/app_util.dart';

import '/index.dart';

export 'package:go_router/go_router.dart';
export 'serialization_util.dart';

const kTransitionInfoKey = '__transition_info__';

GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

class AppStateNotifier extends ChangeNotifier {
  AppStateNotifier._();

  static AppStateNotifier? _instance;
  static AppStateNotifier get instance => _instance ??= AppStateNotifier._();

  bool showSplashImage = true;

  void stopShowingSplashImage() {
    showSplashImage = false;
    notifyListeners();
  }
}

GoRouter createRouter(AppStateNotifier appStateNotifier) => GoRouter(
      initialLocation: '/',
      debugLogDiagnostics: true,
      refreshListenable: appStateNotifier,
      navigatorKey: appNavigatorKey,
      errorBuilder: (context, state) => appStateNotifier.showSplashImage
          ? Builder(
              builder: (context) => Container(
                color: Colors.white,
                child: Image.asset(
                  'assets/images/DentixIA_Logo_(500_x_500_px).png',
                  fit: BoxFit.contain,
                ),
              ),
            )
          : const LoginPageWidget(),
      routes: [
        AppRoute(
          name: '_initialize',
          path: '/',
          builder: (context, _) => appStateNotifier.showSplashImage
              ? Builder(
                  builder: (context) => Container(
                    color: Colors.white,
                    child: Image.asset(
                      'assets/images/DentixIA_Logo_(500_x_500_px).png',
                      fit: BoxFit.contain,
                    ),
                  ),
                )
              : const LoginPageWidget(),
        ),
        AppRoute(
          name: HomePageWidget.routeName,
          path: HomePageWidget.routePath,
          builder: (context, params) => params.isEmpty
              ? const NavBarPage(initialPage: 'HomePage')
              : const HomePageWidget(),
        ),
        AppRoute(
          name: LoginPageWidget.routeName,
          path: LoginPageWidget.routePath,
          builder: (context, params) => const LoginPageWidget(),
        ),
        AppRoute(
          name: PedidosRascunhosPageWidget.routeName,
          path: PedidosRascunhosPageWidget.routePath,
          builder: (context, params) => const PedidosRascunhosPageWidget(),
        ),
        AppRoute(
          name: BuscaProdutoPageWidget.routeName,
          path: BuscaProdutoPageWidget.routePath,
          builder: (context, params) => const BuscaProdutoPageWidget(),
        ),
        AppRoute(
          name: FormClientesPageWidget.routeName,
          path: FormClientesPageWidget.routePath,
          builder: (context, params) => FormClientesPageWidget(
            clienteCodigo: params.getParam(
              'clienteCodigo',
              ParamType.int,
            ),
          ),
        ),
        AppRoute(
          name: ConfiguracaoPageWidget.routeName,
          path: ConfiguracaoPageWidget.routePath,
          builder: (context, params) => params.isEmpty
              ? const NavBarPage(initialPage: 'ConfiguracaoPage')
              : const ConfiguracaoPageWidget(),
        ),
        AppRoute(
          name: DetalheProdutoPageWidget.routeName,
          path: DetalheProdutoPageWidget.routePath,
          builder: (context, params) => DetalheProdutoPageWidget(
            produtoRef: params.getParam(
              'produtoRef',
              ParamType.String,
            ),
          ),
        ),
        AppRoute(
          name: FerramentasPageWidget.routeName,
          path: FerramentasPageWidget.routePath,
          builder: (context, params) => const FerramentasPageWidget(),
        ),
        AppRoute(
          name: ExtratoClientePageWidget.routeName,
          path: ExtratoClientePageWidget.routePath,
          builder: (context, params) => ExtratoClientePageWidget(
            codigoCliente: params.getParam(
              'codigoCliente',
              ParamType.String,
            ),
          ),
        ),
        AppRoute(
          name: ClientePageWidget.routeName,
          path: ClientePageWidget.routePath,
          builder: (context, params) => const ClientePageWidget(),
        ),
        AppRoute(
          name: PedidoNovoInicioWidget.routeName,
          path: PedidoNovoInicioWidget.routePath,
          builder: (context, params) => const PedidoNovoInicioWidget(),
        ),
        AppRoute(
          name: PedidoItensListaWidget.routeName,
          path: PedidoItensListaWidget.routePath,
          builder: (context, params) => PedidoItensListaWidget(
            pedidoId: params.getParam(
              'pedidoId',
              ParamType.int,
            ),
            clienteNome: params.getParam(
              'clienteNome',
              ParamType.String,
            ),
            clienteCodigo: params.getParam(
              'clienteCodigo',
              ParamType.int,
            ),
            linhaCodigo: params.getParam(
              'linhaCodigo',
              ParamType.String,
            ),
            planoCodigo: params.getParam(
              'planoCodigo',
              ParamType.String,
            ),
            clienteCnpj: params.getParam(
              'clienteCnpj',
              ParamType.String,
            ),
            clienteCidade: params.getParam(
              'clienteCidade',
              ParamType.String,
            ),
            clienteLimite: params.getParam(
              'clienteLimite',
              ParamType.String,
            ),
            linhaDescricao: params.getParam(
              'linhaDescricao',
              ParamType.String,
            ),
            planoDescricao: params.getParam(
              'planoDescricao',
              ParamType.String,
            ),
            clienteEndereco: params.getParam(
              'clienteEndereco',
              ParamType.String,
            ),
          ),
        ),
        AppRoute(
          name: PedidoResumoWidget.routeName,
          path: PedidoResumoWidget.routePath,
          builder: (context, params) => PedidoResumoWidget(
            pedidoId: params.getParam(
              'pedidoId',
              ParamType.int,
            ),
          ),
        ),
        AppRoute(
          name: GerarPacotePageWidget.routeName,
          path: GerarPacotePageWidget.routePath,
          builder: (context, params) => const GerarPacotePageWidget(),
        ),
        AppRoute(
          name: ContaCorrentePageWidget.routeName,
          path: ContaCorrentePageWidget.routePath,
          builder: (context, params) => const ContaCorrentePageWidget(),
        ),
        AppRoute(
          name: ResumoVendasPageWidget.routeName,
          path: ResumoVendasPageWidget.routePath,
          builder: (context, params) => const ResumoVendasPageWidget(),
        ),
        AppRoute(
          name: CarteiraRoteirizacaoPageWidget.routeName,
          path: CarteiraRoteirizacaoPageWidget.routePath,
          builder: (context, params) => const CarteiraRoteirizacaoPageWidget(),
        ),
        AppRoute(
          name: FaturamentoMetasPageWidget.routeName,
          path: FaturamentoMetasPageWidget.routePath,
          builder: (context, params) => const FaturamentoMetasPageWidget(),
        ),
        AppRoute(
          name: ReceberPageWidget.routeName,
          path: ReceberPageWidget.routePath,
          builder: (context, params) => const ReceberPageWidget(),
        )
      ].map((r) => r.toRoute(appStateNotifier)).toList(),
    );

extension NavParamExtensions on Map<String, String?> {
  Map<String, String> get withoutNulls => Map.fromEntries(
        entries
            .where((e) => e.value != null)
            .map((e) => MapEntry(e.key, e.value!)),
      );
}

extension NavigationExtensions on BuildContext {
  void safePop() {
    // If there is only one route on the stack, navigate to the initial
    // page instead of popping.
    if (canPop()) {
      pop();
    } else {
      go('/');
    }
  }
}

extension _GoRouterStateExtensions on GoRouterState {
  Map<String, dynamic> get extraMap =>
      extra != null ? extra as Map<String, dynamic> : {};
  Map<String, dynamic> get allParams => <String, dynamic>{}
    ..addAll(pathParameters)
    ..addAll(uri.queryParameters)
    ..addAll(extraMap);
  TransitionInfo get transitionInfo => extraMap.containsKey(kTransitionInfoKey)
      ? extraMap[kTransitionInfoKey] as TransitionInfo
      : TransitionInfo.appDefault();
}

class AppRouteParameters {
  AppRouteParameters(this.state, [this.asyncParams = const {}]);

  final GoRouterState state;
  final Map<String, Future<dynamic> Function(String)> asyncParams;

  Map<String, dynamic> futureParamValues = {};

  // Parameters are empty if the params map is empty or if the only parameter
  // present is the special extra parameter reserved for the transition info.
  bool get isEmpty =>
      state.allParams.isEmpty ||
      (state.allParams.length == 1 &&
          state.extraMap.containsKey(kTransitionInfoKey));
  bool isAsyncParam(MapEntry<String, dynamic> param) =>
      asyncParams.containsKey(param.key) && param.value is String;
  bool get hasFutures => state.allParams.entries.any(isAsyncParam);
  Future<bool> completeFutures() => Future.wait(
        state.allParams.entries.where(isAsyncParam).map(
          (param) async {
            final doc = await asyncParams[param.key]!(param.value)
                .onError((_, __) => null);
            if (doc != null) {
              futureParamValues[param.key] = doc;
              return true;
            }
            return false;
          },
        ),
      ).onError((_, __) => [false]).then((v) => v.every((e) => e));

  dynamic getParam<T>(
    String paramName,
    ParamType type, {
    bool isList = false,
    StructBuilder<T>? structBuilder,
  }) {
    if (futureParamValues.containsKey(paramName)) {
      return futureParamValues[paramName];
    }
    if (!state.allParams.containsKey(paramName)) {
      return null;
    }
    final param = state.allParams[paramName];
    // Got parameter from `extras`, so just directly return it.
    if (param is! String) {
      return param;
    }
    // Return serialized value.
    return deserializeParam<T>(
      param,
      type,
      isList,
      structBuilder: structBuilder,
    );
  }
}

class AppRoute {
  const AppRoute({
    required this.name,
    required this.path,
    required this.builder,
    this.requireAuth = false,
    this.asyncParams = const {},
    this.routes = const [],
  });

  final String name;
  final String path;
  final bool requireAuth;
  final Map<String, Future<dynamic> Function(String)> asyncParams;
  final Widget Function(BuildContext, AppRouteParameters) builder;
  final List<GoRoute> routes;

  GoRoute toRoute(AppStateNotifier appStateNotifier) => GoRoute(
        name: name,
        path: path,
        pageBuilder: (context, state) {
          fixStatusBarOniOS16AndBelow(context);
          final ffParams = AppRouteParameters(state, asyncParams);
          final page = ffParams.hasFutures
              ? FutureBuilder(
                  future: ffParams.completeFutures(),
                  builder: (context, _) => builder(context, ffParams),
                )
              : builder(context, ffParams);
          final child = page;

          final transitionInfo = state.transitionInfo;
          return transitionInfo.hasTransition
              ? CustomTransitionPage(
                  key: state.pageKey,
                  name: state.name,
                  child: child,
                  transitionDuration: transitionInfo.duration,
                  transitionsBuilder:
                      (context, animation, secondaryAnimation, child) =>
                          PageTransition(
                    type: transitionInfo.transitionType,
                    duration: transitionInfo.duration,
                    reverseDuration: transitionInfo.duration,
                    alignment: transitionInfo.alignment,
                    child: child,
                  ).buildTransitions(
                    context,
                    animation,
                    secondaryAnimation,
                    child,
                  ),
                )
              : MaterialPage(
                  key: state.pageKey, name: state.name, child: child);
        },
        routes: routes,
      );
}

class TransitionInfo {
  const TransitionInfo({
    required this.hasTransition,
    this.transitionType = PageTransitionType.fade,
    this.duration = const Duration(milliseconds: 300),
    this.alignment,
  });

  final bool hasTransition;
  final PageTransitionType transitionType;
  final Duration duration;
  final Alignment? alignment;

  static TransitionInfo appDefault() => const TransitionInfo(hasTransition: false);
}

class RootPageContext {
  const RootPageContext(this.isRootPage, [this.errorRoute]);
  final bool isRootPage;
  final String? errorRoute;

  static bool isInactiveRootPage(BuildContext context) {
    final rootPageContext = context.read<RootPageContext?>();
    final isRootPage = rootPageContext?.isRootPage ?? false;
    final location = GoRouterState.of(context).uri.toString();
    return isRootPage &&
        location != '/' &&
        location != rootPageContext?.errorRoute;
  }

  static Widget wrap(Widget child, {String? errorRoute}) => Provider.value(
        value: RootPageContext(true, errorRoute),
        child: child,
      );
}

extension GoRouterLocationExtension on GoRouter {
  String getCurrentLocation() {
    final RouteMatch lastMatch = routerDelegate.currentConfiguration.last;
    final RouteMatchList matchList = lastMatch is ImperativeRouteMatch
        ? lastMatch.matches
        : routerDelegate.currentConfiguration;
    return matchList.uri.toString();
  }
}
