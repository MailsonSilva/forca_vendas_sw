---
name: flutter-setup-declarative-routing
description: Roteamento declarativo com go_router (rotas, deep links Android/iOS, nested navigation). Use ao configurar navegação, receber links externos (push, e-mail) ou tabs com estado preservado.
---

# Skill: Roteamento Declarativo (go_router + Deep Links)

> Adaptado de `flutter/agent-plugins` (time oficial do Flutter, licença BSD-3-Clause).

## 1. Conceitos
- `GoRouter`: árvore de rotas; `GoRoute`: path → tela; `redirect`: guardas (ex.: sem sessão → `/login`).
- `StatefulShellRoute`: shell persistente (ex.: `NavigationBar`) com estado por aba.
- Navegação: `context.go` (substitui), `context.push` (empilha), `goNamed` + `pathParameters`, `pop`.

## 2. Setup
```bash
flutter pub add go_router
```
- App usa `MaterialApp.router(routerConfig: _router)`.
- Roteador vive em `lib/core/router/` (arquivo único por app, rotas por feature importadas).

## 3. Deep Links (Android + iOS)
- **Android** (`AndroidManifest.xml`): `intent-filter` com `autoVerify` + scheme/host; hospedar `assetlinks.json` em `/.well-known/`.
- **iOS** (`Info.plist` + `Runner.entitlements`): `FlutterDeepLinkingEnabled` + `applinks:dominio`; hospedar `apple-app-site-association` em `/.well-known/`.
- Validação: `adb shell am start -a VIEW -d "<url>" <package>`; `xcrun simctl openurl booted <url>`.
- Links de e-mail (ex.: recuperação de senha da T01): rota `/reset?token=...` que valida o token antes de renderizar.

## 4. Workflow (checklist)
- [ ] `go_router` + `MaterialApp.router`.
- [ ] Rotas por feature + `redirect` de auth + `errorBuilder` (tela 404 amigável pt-BR).
- [ ] Tabs com `StatefulShellRoute` quando houver bottom nav.
- [ ] Deep links nativos configurados e validados via adb/simctl.
- [ ] Teste de widget navegando (pump + `go` + `pumpAndSettle` + `expect` da tela destino).

## 5. Exemplo Mínimo (guarda de auth + deep link)

```dart
final router = GoRouter(
  initialLocation: '/home',
  redirect: (context, state) {
    final logged = container.read(sessionProvider).isLogged;
    if (!logged && state.matchedLocation != '/login') return '/login';
    return null;
  },
  routes: [
    GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
    GoRoute(path: '/home', builder: (_, _) => const HomeScreen()),
    GoRoute(
      path: '/reset',
      builder: (_, s) => ResetScreen(token: s.uri.queryParameters['token']),
    ),
  ],
  errorBuilder: (_, _) => const NotFoundScreen(),
);
```
