# Diretrizes Globais do Harness de Engenharia

Este documento estabelece as regras universais e inegociáveis para todos os agentes, workflows e interações no workspace. A adesão a essas regras é obrigatória em todas as etapas do ciclo de vida do software.

---

## 1. Idioma e Comunicação (Regra de Ouro)
- **Interação com o Desenvolvedor**: Todas as conversas, explicações, resumos de progresso, relatórios de diagnóstico e comentários de handoff DEVEM ser estritamente em **Português do Brasil (pt-BR)**.
- **Artefatos e Código**:
  - Código-fonte, variáveis, funções, classes, interfaces e nomes de arquivos devem ser escritos em **inglês** (padrão universal da indústria).
  - Documentações de especificação técnica (`_specs/`), PRDs e notas de negócio são mantidos em **Português do Brasil (pt-BR)**.
  - Mensagens de commit seguem a convenção em **inglês** padronizada pelo Conventional Commits.

---

## 2. Princípio de Desenvolvimento Orientado a Especificações (Spec-Driven)
1. **Sem Spec, Sem Código**: Nenhum subagente de codificação (`builder`) tem permissão para escrever código de produção sem que exista uma especificação aprovada em `_specs/` com critérios de aceitação objetivos.
2. **Fidelidade ao Contrato**: O código implementado deve atender estritamente ao que foi pedido na spec — sem suposições arbitrárias (*scope creep*) e sem código desnecessário além do escopo.
3. **Identificação de Ambiguidade**: Se a especificação for ambígua ou contraditória, o agente deve interromper o fluxo e solicitar alinhamento antes de codificar.

---

## 3. Disciplina de TDD (Test-Driven Development)
1. **Ciclo Vermelho-Verde-Refatora (Red-Green-Refactor)**:
   - **Fase Vermelha (RED)**: O agente `tdd_tester` escreve a suíte de testes correspondente aos critérios da spec. Os testes DEVEM falhar comprovadamente antes do início da implementação.
   - **Fase Verde (GREEN)**: O agente construtor escreve a menor quantidade de código possível para satisfazer os testes e torná-los verdes.
   - **Fase de Refatoração (REFACTOR)**: O agente de QA limpa o código, remove duplicações e assegura que nenhum teste quebrou durante a limpeza.
2. **Cobertura de Casos Limítrofes**: Os testes devem cobrir obrigatoriamente fluxos principais (caminho feliz), valores nulos/inválidos, falhas de conectividade e cenários de borda.

---

## 4. Gestão de Contexto e Handoffs com `ai-memory`
1. **Registro Contínuo**: Cada etapa concluída no pipeline deve registrar um ticket ou atualização no `ai-memory`.
2. **Isolamento de Contexto**: Nenhum subagente deve reler o repositório inteiro; ele deve consultar o ticket do `ai-memory` e o grafo estático do **Graft** para obter apenas o contexto relevante para sua tarefa.
3. **Memória de Erros**: Toda falha que demandou correção no ciclo de autorreparo deve ser sintetizada como aprendizado para prevenir reincidência.

---

## 5. Padrão de Versionamento no Git (Conventional Commits)
- Todos os commits devem seguir a estrutura atômica:
  ```text
  <tipo>(<escopo>): <descrição curta no imperativo>

  - <detalhe da alteração ou critério da spec atendido>
  - Context Ticket: <id-do-ticket-ai-memory>
  ```
- **Tipos permitidos**:
  - `feat`: Nova funcionalidade implementada com cobertura de testes.
  - `fix`: Correção cirúrgica de defeito ou bug reportado.
  - `refactor`: Alteração de código sem impacto no comportamento externo ou nos testes.
  - `test`: Criação ou atualização de suítes de teste (fase Red).
  - `chore`: Atualização de configurações, builds, dependências ou scripts.
  - `docs`: Atualização de documentação, specs ou diagramas de arquitetura.

---

## 6. Segurança e Confidencialidade
1. **Segredos e Chaves**: Nenhuma chave de API, token de serviço, credencial de banco ou arquivo `.env` pode ser gravado em arquivos de código ou incluído na staging area do Git.
2. **Sanitização de Entradas**: Qualquer entrada de usuário ou parâmetro externo deve ser validada e higienizada antes do processamento ou persistência.
3. **Auditoria de Diff**: O agente `git_committer` deve inspecionar o `git diff --staged` antes da emissão do commit para garantir ausência de vazamentos.