---
name: code-quality-tests
description: Automação de testes unitários, de widgets e de integração, além de revisão estática, para aplicativos Flutter. Use para gerar testes, validar regras de negócio e garantir cobertura antes de commits.
---

# Code Quality & Tests (Flutter)

Diretrizes para garantia de qualidade e estabilidade de código em aplicativos Flutter.

## Princípios de Testes
1. **Pirâmide Focada:** Priorize testes de regras de domínio e funções puras em Dart. Para widgets, teste comportamento do usuário (toques, estados renderizados) em vez de implementação interna.
2. **Camadas e Dependências:**
   - Domínio e repositórios: testes unitários com mocks das fontes de dados.
   - Telas: testes de widget cobrindo os 4 estados (loading, empty, error, success).
   - Fluxos críticos: testes de integração (`integration_test`) no caminho feliz.

## Checklist Pré-Entrega
- [ ] Executar análise estática (`flutter analyze` com zero avisos).
- [ ] Aplicar formatação (`dart format .`).
- [ ] Criar/atualizar testes para a funcionalidade recém-adicionada (`flutter test`).
