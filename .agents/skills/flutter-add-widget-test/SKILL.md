---
name: flutter-add-widget-test
description: Testes de widget com WidgetTester (renderização e interações: tap, scroll, texto). Use ao validar que um widget exibe dados corretos e responde a eventos, incluindo os 4 estados de tela.
---

# Skill: Testes de Widget (WidgetTester)

> Adaptado de `flutter/agent-plugins` (time oficial do Flutter, licença BSD-3-Clause).

## 1. Setup
- `flutter_test` em `dev_dependencies`; arquivos em `test/` com sufixo `_test.dart`.
- Widgets com Riverpod: envolver em `ProviderScope` (com `overrides` para mocks). Telas com Material: envolver em `MaterialApp`.

## 2. Componentes
- **WidgetTester**: constrói e interage (`testWidgets`).
- **Finder**: localiza (`find.text`, `find.byType`, `find.byKey`). Prefira `ValueKey` semânticas nos widgets críticos.
- **Matcher**: `findsOneWidget`, `findsNothing`, `findsNWidgets`.

## 3. Workflow (checklist)
- [ ] 1. Definir com `testWidgets('descrição', (tester) async {...})`.
- [ ] 2. Renderizar com `await tester.pumpWidget(...)` (com `ProviderScope`/`MaterialApp` conforme preciso).
- [ ] 3. Verificar estado inicial com `expect(finder, matcher)`.
- [ ] 4. Interagir: `tap` → `pump`; animação/assíncrono → `pumpAndSettle`; texto → `enterText`; lista longa → `scrollUntilVisible`.
- [ ] 5. Verificar estado final.
- [ ] 6. Rodar `flutter test <arquivo>` e iterar até verde.

## 4. Padrão do Harness: Cobrir os 4 Estados
Todo teste de tela cobre: `LoadingState` (skeleton/spinner visível), `EmptyState` (mensagem + CTA),
`ErrorState` (mensagem pt-BR + tentar novamente) e `SuccessState` (dados renderizados).

## 5. Exemplo Mínimo (Riverpod + 4 estados)

```dart
testWidgets('Exibe ErrorState com retry em falha', (tester) async {
  final repo = MockRepo();
  when(() => repo.load()).thenThrow(const NetworkFailure());

  await tester.pumpWidget(
    ProviderScope(
      overrides: [repoProvider.overrideWithValue(repo)],
      child: const MaterialApp(home: ItemsScreen()),
    ),
  );
  await tester.pumpAndSettle();

  expect(find.text('Tentar novamente'), findsOneWidget);
  await tester.tap(find.text('Tentar novamente'));
  await tester.pump();
  verify(() => repo.load()).called(2);
});
```
