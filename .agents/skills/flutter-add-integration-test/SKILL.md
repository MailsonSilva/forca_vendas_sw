---
name: flutter-add-integration-test
description: Testes de integração end-to-end (integration_test) com fluxos de usuário e profiling. Use ao automatizar jornadas críticas (login, checkout, onboarding) em device/emulador.
---

# Skill: Testes de Integração (integration_test)

> Adaptado de `flutter/agent-plugins` (time oficial do Flutter, licença BSD-3-Clause).
> Foco mobile (Android/iOS); fluxos web/Chrome da fonte original foram removidos.

## 1. Setup
- `flutter pub add 'dev:integration_test:{"sdk":"flutter"}'`.
- Diretório `integration_test/` na raiz; arquivos `<nome>_test.dart`.
- `IntegrationTestWidgetsFlutterBinding.ensureInitialized()` no início do `main()`.
- `ValueKey`s nos widgets críticos (botões, campos, itens de lista).

## 2. Autoria
- Carregar o app real: `await tester.pumpWidget(const MyApp())`.
- Após cada interação (`tap`, `enterText`): `await tester.pumpAndSettle()`.
- Asserções por `find.byKey(ValueKey('...'))` + `findsOneWidget`/`findsNothing`.
- Listas: `scrollUntilVisible` antes de interagir com item fora da tela.

## 3. Execução (device/emulador conectado)
```bash
flutter test integration_test/app_test.dart
```
- Para profiling com `binding.traceAction()`, usar driver dedicado (`test_driver/perf_driver.dart`).
- `PumpAndSettleTimedOutException` → há animação infinita: isolar com `pump(duration)` ou desativar a animação no teste.

## 4. Workflow (checklist)
- [ ] Deps + `ValueKey`s nos alvos.
- [ ] Escrever `integration_test/<fluxo>_test.dart` cobrindo o caminho feliz + 1 falha (ex.: login inválido).
- [ ] Rodar em Android e iOS antes de considerar verde.
- [ ] Falhou? Revisar saída → `scrollUntilVisible`/`pump` → reexecutar.

## 5. Exemplo Mínimo

```dart
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('login válido abre a home', (tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.enterText(find.byKey(const ValueKey('email')), 'user@mail.com');
    await tester.enterText(find.byKey(const ValueKey('password')), 'Senha123');
    await tester.tap(find.byKey(const ValueKey('login_button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('home_screen')), findsOneWidget);
  });
}
```
