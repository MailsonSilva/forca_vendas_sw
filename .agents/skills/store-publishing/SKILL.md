---
name: store-publishing
description: Publicação na Play Store e App Store (tracks, TestFlight, review, screenshots). Use ao preparar releases, configurar fichas de loja ou responder a rejeições.
---

# Skill: Publicação em Lojas (Play + App Store)

## 1. Google Play
- Artefato: `.aab` assinado com upload key; `versionCode` sempre crescente.
- Trilhos em ordem: Internal → Closed → Open → Production com **staged rollout** (ex.: 10% → 50% → 100%), pausando em crash acima do baseline.
- Ficha: título, descrição curta/longa em pt-BR, screenshots por formato (telefone, tablet 7"/10"), ícone 512px e feature graphic 1024×500.

## 2. App Store
- Artefato: `.ipa` via Xcode Cloud/Fastlane; upload com App Store Connect API Key.
- Fluxo: build → TestFlight (grupo interno, depois externo com revisão beta) → App Store com **phased release**.
- Revisão: declarar permissões sensíveis (câmera, localização, biometria) com `NS*UsageDescription` em pt-BR claro; conta demo se houver login.

## 3. Screenshots Promocionais
- Gerar a partir de frames reais do app (golden tests ou device frames), nos tamanhos exigidos por cada loja; nunca mock desatualizado da UI.

## 4. Rejeições
- Registrar motivo + correção como aprendizado no `ai-memory`; re-submeter só após reproduzir a correção em build interno.
