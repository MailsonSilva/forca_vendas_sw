---
name: flutter-setup-localization
description: Internacionalização com flutter_localizations + intl (ARB, l10n.yaml, plurais). Use ao criar ou alterar qualquer texto visível — o harness exige pt-BR como idioma base.
---

# Skill: Localização (i18n/l10n)

> Adaptado de `flutter/skills` (time oficial do Flutter, licença BSD-3-Clause).
> Regra do harness: **nenhum texto hardcoded em inglês/português solto na UI** — toda string passa por ARB, com pt-BR como template base.

## 1. Setup
```bash
flutter pub add flutter_localizations --sdk=flutter
flutter pub add intl:any
```
- `pubspec.yaml`: `flutter: { generate: true }`.
- `l10n.yaml` na raiz:
```yaml
arb-dir: lib/l10n
template-arb-file: app_pt.arb
output-localization-file: app_localizations.dart
synthetic-package: true
```
- `MaterialApp`: delegates (`AppLocalizations.delegate` + globais) e `supportedLocales` (pt primeiro).

## 2. Workflow
- [ ] Nova string: adicionar ao template `app_pt.arb` **com `@description`**; replicar a chave nos demais `.arb`.
- [ ] Editar string: atualizar **todos** os `.arb`, nunca só um.
- [ ] Rodar `flutter pub get` para regenerar; corrigir erro de sintaxe ARB e repetir.
- [ ] Consumir via `AppLocalizations.of(context)!.chave` — nunca `Text('literal')` em tela.
- [ ] Teste de widget de cada tela com locale pt e (se suportado) en.

## 3. Formatação Avançada (ARB)
- Placeholders: `"hello": "Olá {userName}"` + bloco `@hello` com tipo/exemplo.
- Plurais: `{count, plural, =0{...} =1{...} other{...}}` (`other` obrigatório).
- Selects: `{gender, select, male{...} female{...} other{...}}`.

## 4. Exemplo Mínimo

```json
// lib/l10n/app_pt.arb
{
  "retry": "Tentar novamente",
  "@retry": { "description": "Botão de retentativa do ErrorState" }
}
```

```dart
Text(AppLocalizations.of(context)!.retry)
```
