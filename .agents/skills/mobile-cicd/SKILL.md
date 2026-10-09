---
name: mobile-cicd
description: Pipeline CI/CD mobile com Fastlane + GitHub Actions (lanes beta e produção). Use ao configurar builds automatizados, gating por testes ou deploy contínuo para Firebase App Distribution, Play interna e TestFlight.
---

# Skill: CI/CD Mobile (Fastlane + GitHub Actions)

## 1. Estrutura de Lanes (por plataforma, em `android/fastlane` e `ios/fastlane`)
- `beta`: `flutter test` + `dart analyze` verdes → build → distribui em canal interno (Play Internal / TestFlight) a cada merge na `main`.
- `release`: exige tag `v*` → build com flavor `prod` → sobe para Play (track configurável) / App Store.
- Versionamento: `build_number` derivado do número do run do CI; `version_name` lido do `pubspec.yaml`.

## 2. Segredos (nunca no repo)
- Android: keystore em base64 + `key.properties` via GitHub Secrets.
- iOS: `fastlane match` (repositório privado de certificados) + App Store Connect API Key via Secrets.
- Supabase/URLs: via `--dart-define` a partir de Secrets por ambiente.

## 3. Template de Workflow (`.github/workflows/mobile-ci.yml`)
```yaml
name: mobile-ci
on:
  push:
    branches: [main]
  pull_request:
jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with: { channel: stable }
      - run: flutter pub get
      - run: dart analyze
      - run: flutter test
  beta-android:
    needs: validate
    if: github.ref == 'refs/heads/main'
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with: { channel: stable }
      - run: cd android && bundle exec fastlane beta
        env:
          KEYSTORE_BASE64: ${{ secrets.KEYSTORE_BASE64 }}
```

## 4. Gates
- PR não mergeia com `validate` vermelho (branch protection).
- Lane `release` nunca roda sem tag; build iOS exige runner `macos`.
