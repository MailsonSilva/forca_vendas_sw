---
name: flutter-release
description: Pipeline de release Flutter de ponta a ponta (verificar, versionar, buildar, entregar). Use ao fechar uma versão: valida gates, incrementa versão, gera artefatos e entrega aos canais.
---

# Skill: Release Flutter (test → version → build → ship)

Checklist executado em ordem; qualquer etapa vermelha aborta as seguintes.

## 0. Verificação de Projeto
- `pubspec.yaml` existe; flavors `dev/stg/prod` configurados; segredos fora do repo.

## 1. Portões de Qualidade (Gates)
- `flutter test` verde + `dart analyze` com zero avisos na revisão exata a ser lançada.

## 2. Versionamento
- Incrementar `version: x.y.z+build` no `pubspec.yaml` (semver + build crescente); commit `chore(release): vX.Y.Z`.
- Criar tag `vX.Y.Z` — é ela que dispara a lane `release` no CI.

## 3. Build
- Android: `flutter build appbundle --flavor prod --dart-define=...`.
- iOS: `flutter build ipa --flavor prod --export-options-plist=...`.
- Registrar checksums dos artefatos na nota de release.

## 4. Entrega (Ship)
- Beta: Firebase App Distribution / Play Internal / TestFlight interno com notas em pt-BR.
- Produção: via `store-publishing` (staged rollout / phased release).
- Pós-release: monitorar crash nas primeiras 24h antes de expandir o rollout.
