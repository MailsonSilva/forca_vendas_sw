---
name: flutter-apply-architecture-best-practices
description: Arquitetura Flutter em camadas (UI, Lógica, Dados) com workflow de feature em 8 passos. Use ao estruturar um projeto novo ou refatorar para escalabilidade.
---

# Skill: Arquitetura Flutter em Camadas

> Adaptado de `flutter/agent-plugins` (time oficial do Flutter, licença BSD-3-Clause).
> Compatibilizado com este harness: pastas `core/` + `features/` (ver `.agents/rules/mobile.md`),
> estado via Riverpod (`flutter-state-riverpod`) e TDD obrigatório (`clean-architecture`).

## 1. Camadas (Separation of Concerns)

Nunca misture renderização de UI com regra de negócio ou acesso a dados.

### UI (Presentation) — `features/<feature>/presentation/`
- **Views:** widgets enxutos e reutilizáveis; só lógica de UI (animação, layout, navegação simples). Todo dado vem do state holder.
- **State holders:** neste harness, o papel de ViewModel é do `AsyncNotifier` (Riverpod). Expõe `AsyncValue` (casa com os 4 estados de tela) e recebe repositórios por injeção (provider/construtor).

### Dados — `features/<feature>/data/` (+ `core/database/`, `core/network/`)
- **Services:** classes sem estado que envelopam APIs externas (HTTP, banco local, plugins). Retornam modelos crus.
- **Repositories:** consomem um ou mais services, transformam em modelos de domínio, cuidam de cache, sync offline e retry. Expõem apenas modelos de domínio.

### Lógica (Domain) — `features/<feature>/domain/` — opcional por feature
- **Use cases:** só quando a lógica é complexa ou reutilizada entre telas; CRUD simples vai direto do state holder ao repositório.

## 2. Estrutura de Projeto (padrão do harness)

```text
lib/
├── core/
│   ├── database/   # SQLite/Drift: migrations, DAOs
│   ├── network/    # Clientes HTTP / Supabase
│   └── theme/      # Design tokens
└── features/
    └── [feature_name]/
        ├── data/          # Models crus, services, repositórios concretos
        ├── domain/        # Entidades + contratos (Dart puro, sem Flutter)
        └── presentation/  # Telas, widgets e Notifiers (Riverpod)
```

## 3. Workflow: Implementar uma Feature (8 passos + TDD)

Siga em ordem; cada passo de código nasce de um teste (`clean-architecture`):

- [ ] **1. Modelos de domínio:** entidades imutáveis em `domain/`.
- [ ] **2. Contratos:** interfaces de repositório em `domain/` (é contra elas que os testes RED são escritos).
- [ ] **3. Services:** acesso a API/banco em `data/` ou `core/`.
- [ ] **4. Repositórios:** implementações concretas; cache, retry e mapeamento para o domínio.
- [ ] **5. Lógica condicional:** use case em `domain/` se houver transformação complexa ou reuso; senão, pule.
- [ ] **6. State holder:** `AsyncNotifier` (Riverpod) com repositórios injetados; estados via `AsyncValue`.
- [ ] **7. View:** widget que observa o provider e renderiza os 4 estados (loading/empty/error/success).
- [ ] **8. Validador:** `flutter test` + `dart analyze` verdes; corrija e reexecute até passar.

## 4. Exemplo Mínimo (repositório + state holder)

```dart
// data: implementação contra o contrato do domínio
class UserRepositoryImpl implements UserRepository {
  UserRepositoryImpl(this._api);
  final ApiClient _api;
  User? _cached;

  @override
  Future<User> getUser(String id) async {
    final cached = _cached;
    if (cached != null) return cached;
    final raw = await _api.fetchUser(id);
    return _cached = User(id: raw.id, name: raw.fullName);
  }
}

// presentation: AsyncNotifier no lugar do ViewModel
class ProfileNotifier extends AsyncNotifier<User?> {
  @override
  FutureOr<User?> build() => null;

  Future<void> load(String id) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(userRepositoryProvider).getUser(id),
    );
  }
}
```
