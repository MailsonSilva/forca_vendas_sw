---
name: flutter-state-riverpod
description: Padrão de gerência de estado com Riverpod em Flutter. Use ao criar providers, consumir estado em widgets, testar lógica de estado e ligar telas à regra dos 4 estados.
---

# Skill: Gerência de Estado com Riverpod (padrão do harness)

Riverpod é o padrão oficial de estado deste harness: testável, sem BuildContext global e com escopo por feature.

## 1. Tipos de Provider por Caso
- **Estado imutável simples** (filtros, seleções): `StateProvider` / `NotifierProvider`.
- **Estado assíncrono** (buscas, login): `AsyncNotifierProvider` — o `AsyncValue` casa direto com os 4 estados de tela (`loading` → LoadingState, `error` → ErrorState, `data` vazia → EmptyState, `data` → SuccessState).
- **Dependências** (repositórios, clientes): `Provider` puro, sobrescrito em testes via `ProviderScope(overrides: [...])`.
- **Parâmetros** (ex.: detalhe por id): `family` com parcimônia — prefira um Notifier que recebe o id no método.

## 2. Regras Inegociáveis
- Widgets **observam** (`ref.watch`) apenas o que renderizam; ações usam `ref.read(provider.notifier)` — nunca `watch` dentro de callbacks.
- Nenhum provider acessa SQLite, HTTP ou Supabase diretamente: ele chama o **repositório do domínio**.
- `autoDispose` por padrão em telas descartáveis para não vazar estado entre rotas.

## 3. Testabilidade
- Teste Notifiers com `ProviderContainer` puro (sem `pumpWidget`), sobrescrevendo o repositório por mock.
- Teste widgets com `ProviderScope` + `UncontrolledProviderScope` quando precisar de estado inicial fixo.
