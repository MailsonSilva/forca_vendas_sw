---
name: dart-use-pattern-matching
description: Pattern matching Dart 3 (switch expressions, destructuring, sealed classes). Use ao refatorar if-else encadeados, validar JSON polimórfico ou garantir exaustividade.
---

# Skill: Pattern Matching (Dart 3)

> Adaptado de `dart-lang/skills` (time oficial do Dart, licença BSD-3-Clause).

## 1. Quando Usar (e Quando Não)
- **Usar**: validar + extrair de JSON (Map/List patterns), segmentos de rota (`['a', ...rest]`), payloads polimórficos (`switch` em chave discriminante → hierarquia `sealed`), múltiplos retornos (Records), faixas numéricas (relacionais), exaustividade em `sealed`/`enum`.
- **Não usar**: booleano simples (`?:`), promoção de 1 variável (`is`), filtro de coleção, 1 propriedade conhecida (`user.name`).

## 2. Statement vs Expression
- Produz valor → **switch expression** (`=>`, exaustivo, sem fallthrough).
- Efeito colateral → **switch statement** (cases vazios caem; demais dão break implícito).

## 3. Anti-Patterns (resumo)
- `if-case` com alias desnecessário → prefira `is` com promoção direta.
- Braço `null` redundante → case no tipo anulável (`String? s`).
- `if-case` que **silencia dado malformado** → fast-fail com `FormatException` explícito.
- `switch` de 1 case ou em booleano → `if`/`?:`.
- Map pattern valida **existência da chave** (`containsKey`): chave opcional omitida ≠ `null` — extraia do submapa (`map['k'] as String?`).

## 4. Workflow (checklist)
- [ ] Identificar estrutura (JSON, segmentos, Record, sealed, enum).
- [ ] Escolher constructo + patterns (Object/Map/List/Record) + guards (`when`).
- [ ] Ramo curinga `_` ou `default` quando fallback/erro for aceitável.
- [ ] `dart analyze` (exaustividade) + teste de runtime para Map/JSON.

## 5. Exemplo Mínimo (sealed + switch)

```dart
sealed class Shape {}
class Square implements Shape { final double length; Square(this.length); }
class Circle implements Shape { final double radius; Circle(this.radius); }

double area(Shape s) => switch (s) {
  Square(length: var l) => l * l,
  Circle(:var radius) => 3.14159 * radius * radius,
};
```
