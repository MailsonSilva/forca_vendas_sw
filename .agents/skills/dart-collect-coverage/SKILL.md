---
name: dart-collect-coverage
description: Cobertura de testes Flutter com relatório LCOV e gates de CI. Use ao medir cobertura do projeto ou exigir mínimo em pipeline.
---

# Skill: Cobertura de Testes (LCOV)

> Adaptado de `dart-lang/skills` (time oficial do Dart, licença BSD-3-Clause).

## 1. Coleta Rápida (Flutter)
```bash
flutter test --coverage
```
Gera `coverage/lcov.info`. Para HTML navegável (exige `lcov` instalado):
```bash
genhtml coverage/lcov.info -o coverage/html
```

## 2. Coleta Avançada (package:coverage)
```bash
flutter pub add dev:coverage
dart run coverage:test_with_coverage
```
Valida `coverage/coverage.json` + `coverage/lcov.info`. Em monorepo, passar os dirs de teste explicitamente.

## 3. Diretivas de Exclusão
- Linha: `// coverage:ignore-line` · Bloco: `ignore-start/end` · Arquivo: `// coverage:ignore-file`.
- Usar para gerados e `UnimplementedError` de providers base; **nunca** para esconder regra de negócio sem teste.

## 4. Gate de CI
- `validate` do `mobile-cicd` pode extrair o percentual do `lcov.info` e falhar abaixo do mínimo do projeto (sugestão inicial: 70% em `lib/`, excluídos gerados).
- Tendência > número absoluto: cobertura caindo em PR bloqueia merge.

## 5. Workflow (checklist)
- [ ] Rodar coleta e abrir relatório.
- [ ] Arquivos críticos (domain, repositories) com cobertura total.
- [ ] Adicionar testes onde a cobertura caiu antes de novas features.
