---
name: antigravity-skill-orchestrator
description: Meta-orquestrador cognitivo para triagem de tarefas e ativação progressiva de skills. Avalia complexidade antes de delegar para evitar inchaço de contexto e chamadas desnecessárias. Use sempre no início de tarefas complexas ou fluxos de desenvolvimento.
---

# Antigravity Skill Orchestrator

Você atua como o avaliador prévio de execução no harness. Seu papel é impedir o desperdício de tokens e garantir que apenas o contexto necessário seja carregado.

## Regras de Triagem

1. **Alterações Elementares (Low Complexity):**
   - Correções simples de sintaxe, ajustes pontuais de tema/widgets, renomeação de variáveis ou adição de tipagens triviais.
   - **Ação:** NÃO ative skills adicionais. Execute a alteração diretamente usando ferramentas nativas de edição de arquivos (`edit_file`).

2. **Planejamento de Funcionalidade ou Refatoração Estrutural:**
   - Criação de novas features, telas, fluxos de navegação ou integração de fontes de dados.
   - **Ação:** Invoque a skill `spec-discovery` e/ou `clean-architecture`.

3. **Performance Mobile (Flutter):**
   - Rebuilds excessivos, jank em listas/animações, tamanho do app elevado ou descarte de quadros.
   - **Ação:** Ative exclusivamente a skill `clean-architecture` (isolamento e refatoração) com apoio de `mobile-ux` (skeletons e estados).

4. **Validação e Entrega:**
   - Criação de testes unitários/integração ou preparação para merge.
   - **Ação:** Ative a skill `code-quality-tests`.

## Tabela de Roteamento (tarefa → agente + skills)

Consulte esta tabela para delegar; ative no máximo 2 skills por turno, priorizando a primeira listada.

| Tarefa | Agente | Skills (ordem de prioridade) |
|---|---|---|
| Descobrir escopo, PRD, regras de negócio | `product_architect` | `spec-discovery` |
| Protótipo visual, tokens, Stitch | `ui_ux_designer` | `mobile-ux` |
| Breakpoints e telas grandes (design) | `ui_ux_designer` | `flutter-build-responsive-layout`, `mobile-ux` |
| Inventário de strings / idiomas (design) | `ui_ux_designer` | `flutter-setup-localization`, `mobile-ux` |
| Estruturar feature (camadas, pastas) | `mobile_builder` | `flutter-apply-architecture-best-practices`, `clean-architecture` |
| Estado com Riverpod / 4 estados | `mobile_builder` | `flutter-state-riverpod`, `mobile-ux` |
| Navegação, rotas, deep links | `mobile_builder` | `flutter-setup-declarative-routing` |
| Textos/i18n no código | `mobile_builder` | `flutter-setup-localization` |
| Layout adaptativo no código | `mobile_builder` | `flutter-build-responsive-layout` |
| REST/HTTP em services | `mobile_builder` | `flutter-use-http-package`, `local-first-data` |
| Supabase (auth, RLS, storage) | `mobile_builder` | `supabase-flutter`, `local-first-data` |
| Banco local, sync offline | `mobile_builder` | `local-first-data`, `supabase-flutter` |
| Refatorar if-else/JSON/sealed | `mobile_builder` ou `qa_validator` | `dart-use-pattern-matching`, `clean-architecture` |
| Testes RED (unit/widget) | `tdd_tester` | `clean-architecture`, `flutter-add-widget-test` |
| Teste E2E em device | `tdd_tester` | `flutter-add-integration-test`, `code-quality-tests` |
| QA, lint, autorreparo | `qa_validator` | `code-quality-tests`, `dart-use-pattern-matching` |
| Cobertura e gate de CI | `qa_validator` | `dart-collect-coverage`, `code-quality-tests` |
| CI/CD, lanes beta/produção | `release_manager` | `mobile-cicd`, `flutter-release` |
| Subir para Play/App Store | `release_manager` | `store-publishing`, `flutter-release` |
| Commit semântico | `git_committer` | (nenhuma — usa `ai-memory` + diff) |

## Protocolo de Decisão
- Nunca ative mais de duas skills simultaneamente no mesmo turno.
- Garanta que as regras contidas em `.agents/rules/global.md` e `.agents/rules/mobile.md` sejam o teto máximo de conformidade.