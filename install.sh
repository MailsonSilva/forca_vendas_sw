#!/usr/bin/env bash
# ==============================================================================
# Antigravity Developer Harness - Instalador Universal (Linux / macOS / WSL / Git Bash)
# 100% Autocontido: Instala ferramentas (ai-memory, graft), regras, skills e workflows
# ==============================================================================

set -e

GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
GRAY='\033[0;37m'
NC='\033[0m' # No Color

echo -e "${CYAN}=====================================================${NC}"
echo -e "${CYAN}   🚀 Antigravity Developer Harness - Instalador    ${NC}"
echo -e "${CYAN}=====================================================${NC}"
echo ""

TARGET_DIR="${1:-.}"
cd "$TARGET_DIR"

echo -e "${YELLOW}📁 Criando estrutura de pastas no diretório: $(pwd)${NC}"

# ------------------------------------------------------------------------------
# 1. Verificação e Instalação de Ferramentas Auxiliares (MCPs & CLI Tools)
# ------------------------------------------------------------------------------
echo -e "\n${YELLOW}🔍 Verificando ferramentas auxiliares...${NC}"

# 1.1 Checagem do Node / npm e ai-memory
if command -v npm &> /dev/null; then
    if ! command -v ai-memory &> /dev/null; then
        echo -e "${CYAN}📦 Instalando ai-memory globalmente via npm...${NC}"
        npm install -g ai-memory || echo -e "${YELLOW}⚠️ Falha ao instalar ai-memory globalmente. Execute 'npm i -g ai-memory' com permissões adequadas se necessário.${NC}"
    else
        echo -e "${GREEN}✔ ai-memory já instalado no sistema.${NC}"
    fi
else
    echo -e "${YELLOW}⚠️ Node.js / npm não detectado. O servidor ai-memory precisará do Node instalado para rodar.${NC}"
fi

# 1.2 Checagem do Graft (AST Graph Navigator)
if ! command -v graft &> /dev/null; then
    if command -v cargo &> /dev/null; then
        echo -e "${CYAN}📦 Compilando e instalando Graft via Cargo...${NC}"
        cargo install graft-cli || echo -e "${YELLOW}⚠️️ Falha ao compilar graft via cargo.${NC}"
    else
        echo -e "${YELLOW}ℹ️️ Cargo não detectado. O harness usará fallback para análise estática nativa caso o binário do Graft não esteja no PATH.${NC}"
    fi
else
    echo -e "${GREEN}✔ Graft já instalado no sistema.${NC}"
fi

# ------------------------------------------------------------------------------
# 2. Criação das pastas fundamentais
# ------------------------------------------------------------------------------
echo -e "\n${YELLOW}📁 Criando diretórios do projeto...${NC}"

mkdir -p .agents/rules
mkdir -p .agents/skills/spec-discovery
mkdir -p .agents/skills/mobile-ux
mkdir -p .agents/skills/clean-architecture
mkdir -p .agents/skills/code-quality-tests
mkdir -p .agents/skills/antigravity-skill-orchestrator
mkdir -p .agents/skills/flutter-state-riverpod
mkdir -p .agents/skills/supabase-flutter
mkdir -p .agents/skills/local-first-data
mkdir -p .agents/skills/mobile-cicd
mkdir -p .agents/skills/store-publishing
mkdir -p .agents/skills/flutter-release
mkdir -p .agents/skills/flutter-apply-architecture-best-practices
mkdir -p .agents/skills/flutter-add-widget-test
mkdir -p .agents/skills/flutter-add-integration-test
mkdir -p .agents/skills/flutter-setup-declarative-routing
mkdir -p .agents/skills/flutter-use-http-package
mkdir -p .agents/skills/flutter-setup-localization
mkdir -p .agents/skills/flutter-build-responsive-layout
mkdir -p .agents/skills/dart-use-pattern-matching
mkdir -p .agents/skills/dart-collect-coverage
mkdir -p .agents/workflows
mkdir -p .agents/memory
mkdir -p _specs/features
mkdir -p _specs/tasks
mkdir -p _references/screens
mkdir -p _references/brand
mkdir -p apps/mobile

# Criação de .gitkeep para garantir que as pastas de referências subam para o Git
touch _references/screens/.gitkeep
touch _references/brand/.gitkeep

echo -e "${GREEN}✔ Diretórios criados com sucesso.${NC}"
echo -e "${YELLOW}📄 Gerando arquivos de configuração, regras, skills e workflows...${NC}"

# ------------------------------------------------------------------------------
# 3. _specs/prd-template.md (Agnóstico e Dinâmico)
# ------------------------------------------------------------------------------
cat << 'EOF' > _specs/prd-template.md
---
project_name: "NomeDoProjeto"
version: "0.1.0"
date: "2026-10-01"
status: "draft" # draft | approved | in_progress | completed

# Plataformas do aplicativo (ativadas na fase de descoberta)
platforms:
  android: true
  ios: true

# Definição tecnológica aberta decidida na descoberta
technology_choices:
  # Estratégia de dados definida conforme a necessidade do projeto:
  # Exemplos: local_first (SQLite, Drift, Hive, Realm) | cloud_only | hybrid_sync | serverless | rest_api | none
  persistence_type: "to_be_decided" 
  primary_database: "to_be_decided" # ex: sqlite, postgres, mysql, supabase, firebase, local_json, nenhum
  backend_strategy: "to_be_decided" # ex: direct_db, custom_api, edge_functions, baas, offline_only

  # Framework do app
  mobile_framework: "flutter" # ou react_native_expo, nativo, etc.
  styling_approach: "tokens"  # design_tokens, material3
---

# PRD: {{project_name}}

## 1. Visão Geral e Proposta de Valor
- **Problema Central**: Qual é a dor ou gargalo real que o sistema resolve? Quem sofre com esse problema atualmente?
- **Solução Proposta**: O que a solução entrega para sanar esse problema com o menor atrito possível?
- **Público-Alvo e Persona (ICP)**: Quem utilizará ou pagará pelo produto?
- **Métrica de Sucesso (North Star Metric)**: Qual número ou resultado valida o sucesso do projeto (ex.: usuários ativos, cadastros, conversão, tempo economizado)?

---

## 2. Definição e Justificativa de Tecnologias (Tech Stack)
*Esta seção é preenchida pelo agente de descoberta junto ao desenvolvedor antes do início da implementação:*

- **Persistência de Dados**: 
  - *Decisão*: [ex: Iniciar 100% local com SQLite para velocidade de MVP sem custo de servidor / Usar API externa já existente / Usar Postgres na nuvem]
  - *Justificativa*: [Por que essa escolha é ideal para o momento atual do projeto?]
- **Autenticação e Sessão**: [Local/Pin, JWT, OAuth, sessão de dispositivo ou sem autenticação]
- **Armazenamento de Arquivos/Imagens**: [Local no dispositivo, Bucket S3/R2 ou N/A]

---

## 3. Escopo do Aplicativo Mobile (`apps/mobile`)

- **Papel no Produto**:
- **Capacidades Críticas**: [Offline-first, notificações, acesso à câmera, biometria, etc.]
- **Plataformas**: [Android e/ou iOS, versão mínima do SO por plataforma]
- **Matriz de Devices**: [modelos e tamanhos de tela prioritários para teste]

---

## 4. Identidade Visual e Referências (`_references/`)
- **Referências em `_references/screens/`**: Telas de inspiração para leitura pelo Stitch MCP.
- **Paleta Preliminar & Tokens**:
  - Tom Primário: `#XXXXXX`
  - Tom Secundário / Destaque: `#XXXXXX`
  - Superfície / Fundo: `#XXXXXX`
  - Tipografia de Interface: [Inter, Roboto, Poppins, etc.]

---

## 5. Jornadas do Usuário e Épicos

### Épico 1: [Nome do Fluxo Principal]
- **Como** [perfil de usuário],
- **Quero** [realizar uma ação no app],
- **Para** [atingir determinado benefício].

**Critérios de Aceitação Obrigatórios**:
- [ ] Cenário de Sucesso (Caminho Feliz).
- [ ] Estado de Carregamento contextual (Skeleton ou loader não intrusivo).
- [ ] Estado Vazio (Empty State) informativo e com botão de ação rápida.
- [ ] Estado de Falha (Error State) com mensagem em pt-BR e opção de tentar novamente.

---

## 6. Diagrama Conceitual de Arquitetura (Archify)
- *Fluxo de dados documentado em HTML/SVG autocontido*:
  - Componente de Entrada -> Gerenciador de Estado -> Contrato de Repositório -> Mecanismo de Dados Escolhido.
EOF

# ------------------------------------------------------------------------------
# 4. .agents/harness.yaml (Modelos Dinâmicos Gemini 3.8 & Subagentes)
# ------------------------------------------------------------------------------
cat << 'EOF' > .agents/harness.yaml
version: "1.0"
name: "unified-developer-harness"
description: "Harness unificado multi-alvo com alocação dinâmica de modelos de IA, TDD, Stitch MCP, Graft e ai-memory."

# Nenhum modelo é fixado: escolha via variáveis de ambiente por tarefa.
# Ex: export MODEL_REASONING="seu-modelo-forte" MODEL_CODING="seu-modelo-rapido"
models:
  reasoning: "${MODEL_REASONING}"
  coding: "${MODEL_CODING}"
  multimodal_design: "${MODEL_DESIGN}"
  fast_ops: "${MODEL_OPS}"

settings:
  prd_path: "_specs/prd.md"
  language: "pt-BR"
  enforce_tdd: true
  max_repair_cycles: 3
  active_profile: "dynamic"

workspaces:
  shared:
    paths:
      - "_specs/"
      - "_references/"
      - ".agents/"
  mobile:
    path: "apps/mobile/"
    test_command: "cd apps/mobile && flutter test"
    lint_command: "cd apps/mobile && dart analyze"

tools:
  ai_memory:
    cli: "ai-memory"
    description: "Handoffs atômicos entre agentes e histórico de aprendizado do ciclo TDD."
  graft:
    cli: "graft"
    description: "Grafo de símbolos e chamadas via AST Tree-sitter para navegação precisa no código."
  google_stitch_mcp:
    server_id: "google-stitch"
    description: "Leitor de referências visuais de telas e prototipagem de UI."
  git:
    cli: "git"
    description: "Controle de versão e commits semânticos atômicos."

subagents:
  product_architect:
    model: "${MODEL_REASONING}"
    role: "Entrevista o desenvolvedor, define requisitos de negócio e gera o PRD agnóstico em _specs/ com diagramas Archify."
    rules:
      - ".agents/rules/global.md"
    skills:
      - ".agents/skills/spec-discovery/SKILL.md"
    tools: ["file_read", "file_write", "ai_memory"]

  ui_ux_designer:
    model: "${MODEL_DESIGN}"
    role: "Inspeciona capturas em _references/screens/ usando Google Stitch MCP e gera os tokens de design em _specs/design-tokens.json."
    rules:
      - ".agents/rules/global.md"
    skills:
      - ".agents/skills/mobile-ux/SKILL.md"
      - ".agents/skills/flutter-build-responsive-layout/SKILL.md"
      - ".agents/skills/flutter-setup-localization/SKILL.md"
    tools: ["google_stitch_mcp", "file_read", "file_write", "ai_memory"]

  tdd_tester:
    model: "${MODEL_CODING}"
    role: "Lê a spec da feature e cria testes unitários/widgets/componentes que obrigatoriamente falham antes do código."
    rules:
      - ".agents/rules/global.md"
    skills:
      - ".agents/skills/clean-architecture/SKILL.md"
      - ".agents/skills/flutter-add-widget-test/SKILL.md"
      - ".agents/skills/flutter-add-integration-test/SKILL.md"
    tools: ["file_read", "file_write", "bash", "graft", "ai_memory"]

  mobile_builder:
    model: "${MODEL_CODING}"
    role: "Escreve código Flutter estritamente tipado, modular e aderente à Clean Architecture para passar nos testes."
    rules:
      - ".agents/rules/global.md"
      - ".agents/rules/mobile.md"
    skills:
      - ".agents/skills/mobile-ux/SKILL.md"
      - ".agents/skills/clean-architecture/SKILL.md"
      - ".agents/skills/flutter-apply-architecture-best-practices/SKILL.md"
      - ".agents/skills/flutter-state-riverpod/SKILL.md"
      - ".agents/skills/flutter-setup-declarative-routing/SKILL.md"
      - ".agents/skills/flutter-setup-localization/SKILL.md"
      - ".agents/skills/flutter-build-responsive-layout/SKILL.md"
      - ".agents/skills/flutter-use-http-package/SKILL.md"
      - ".agents/skills/dart-use-pattern-matching/SKILL.md"
      - ".agents/skills/supabase-flutter/SKILL.md"
      - ".agents/skills/local-first-data/SKILL.md"
    tools: ["file_read", "file_write", "graft", "ai_memory"]

  qa_validator:
    model: "${MODEL_CODING}"
    role: "Executa testes e linters do app mobile, orquestrando até 3 ciclos de autorreparo automático caso algo quebre."
    rules:
      - ".agents/rules/global.md"
    skills:
      - ".agents/skills/code-quality-tests/SKILL.md"
      - ".agents/skills/dart-collect-coverage/SKILL.md"
      - ".agents/skills/dart-use-pattern-matching/SKILL.md"
    tools: ["bash", "file_read", "file_write", "ai_memory"]

  git_committer:
    model: "${MODEL_OPS}"
    role: "Inspeciona o diff staged, extrai o contexto do ticket no ai-memory e cria o commit semântico atômico."
    rules:
      - ".agents/rules/global.md"
    tools: ["git", "ai_memory", "bash"]

  release_manager:
    model: "${MODEL_CODING}"
    role: "Executa o pipeline de release Flutter (gates, versionamento, build, entrega) e publica nas lojas com rollout controlado."
    rules:
      - ".agents/rules/global.md"
      - ".agents/rules/mobile.md"
    skills:
      - ".agents/skills/flutter-release/SKILL.md"
      - ".agents/skills/mobile-cicd/SKILL.md"
      - ".agents/skills/store-publishing/SKILL.md"
    tools: ["bash", "file_read", "file_write", "ai_memory"]

workflows:
  dev_cycle:
    file: ".agents/workflows/dev-cycle.yaml"
    description: "Ciclo ponta a ponta: Ingestão -> Design -> TDD Red -> Green -> Refactor -> Commit."
EOF

# ------------------------------------------------------------------------------
# 5. .agents/mcp.json (Configuração dos MCP Servers)
# ------------------------------------------------------------------------------
cat << 'EOF' > .agents/mcp.json
{
  "mcpServers": {
    "google-stitch": {
      "command": "npx",
      "args": [
        "-y",
        "@google/stitch-mcp-server"
      ],
      "env": {
        "STITCH_REFERENCES_DIR": "./_references/screens",
        "STITCH_OUTPUT_DIR": "./_specs"
      },
      "description": "Servidor MCP do Google Stitch para extrair o Design DNA de referências em _references/screens/ e gerar protótipos visuais de telas."
    },
    "graft-ast": {
      "command": "graft",
      "args": [
        "mcp",
        "--watch"
      ],
      "description": "Grafo estático do código com Tree-sitter para consulta determinística de símbolos, funções e contratos sem consumir tokens desnecessários."
    },
    "ai-memory": {
      "command": "ai-memory",
      "args": [
        "server"
      ],
      "env": {
        "AI_MEMORY_DB_PATH": "./.agents/memory/context.db"
      },
      "description": "Servidor de memória local para persistência de tickets de handoff entre subagentes e histórico de aprendizados do ciclo TDD."
    }
  }
}
EOF

# ------------------------------------------------------------------------------
# 6. .agents/rules/ (Regras de Engenharia)
# ------------------------------------------------------------------------------
cat << 'EOF' > .agents/rules/global.md
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
EOF

cat << 'EOF' > .agents/rules/mobile.md
# Diretrizes Técnicas para Desenvolvimento Mobile (Flutter)

Este guia estabelece os padrões arquiteturais, convenções de código, gestão de estado, persistência de dados e ergonomia de interface para as aplicações em `apps/mobile/`.

## 1. Arquitetura de Software e Separação de Camadas
Adotamos uma abordagem modular e desacoplada inspirada em **Clean Architecture**:

```
apps/mobile/lib/
├── core/                  # Serviços globais, tema, utilitários e clientes (HTTP/DB)
│   ├── database/          # SQLite (migrations, helpers, DAOs)
│   ├── network/           # Clientes HTTP / Supabase SDK
│   └── theme/             # Design Tokens, tipografia e estilos globais
├── features/              # Módulos funcionais isolados
│   └── [feature_name]/
│       ├── data/          # Models, DTOs, DataSources e Repositórios concretos
│       ├── domain/        # Entidades de negócio e Contratos de repositório (Interfaces)
│       └── presentation/  # Telas, Widgets atômicos e State Holders (Bloc/Notifier)
└── main.dart
```

### Regras de Dependência:
- A camada de **Apresentação (Presentation)** depende apenas do **Domínio (Domain)**. Nunca chame a camada de dados diretamente de dentro de um Widget.
- A camada de **Dados (Data)** implementa os contratos da camada de **Domínio**.
- O **Domínio (Domain)** é composto por Dart puro: livre de dependências do framework Flutter, widgets ou pacotes externos de terceiros.

---

## 2. Gerenciamento de Estados de Tela (Regra dos 4 Estados)
Toda tela que consulta, carrega ou submete informações DEVE implementar explicitamente os quatro estados visuais da UI:
1. **Estado de Carregamento (`LoadingState`)**:
   - Usar *shimmer skeleton* ou indicador visual de progresso contextualizado.
   - Evitar bloquear a tela inteira se parte do conteúdo já estiver em cache.
2. **Estado de Conteúdo Vazio (`EmptyState`)**:
   - Mensagem amigável explicando por que não há itens na lista.
   - Ação visual clara e direta (*Call to Action*), com botão destacado.
3. **Estado de Falha/Erro (`ErrorState`)**:
   - Mensagem em Português claro, sem termos técnicos indecifráveis para o usuário final.
   - Botão obrigatório de *"Tentar Novamente"* para reexecutar a consulta.
4. **Estado de Sucesso/Dados (`SuccessState`)**:
   - Renderização limpa, com paginação sob demanda quando houver listas extensas.

---

## 3. Diretrizes de UI, Widgets e Performance
1. **Construtores `const`**: Sempre declare construtores `const` em Widgets sem estado mutável para evitar reconstruções desnecessárias na árvore de renderização.
2. **Tamanho Mínimo de Alvo de Toque (Touch Target)**:
    - Todo botão, ícone interativo ou elemento clicável deve ter uma área de toque de no mínimo **48x48 dp**, prevenindo toques acidentais ou frustração de uso.
3. **Alinhamento com Tokens Visuais**:
   - Cores, raios de borda, espaçamentos e fontes devem ser consumidos centralmente a partir de `core/theme/` (gerado a partir de `_specs/design-tokens.json`).
   - É proibido usar cores "mágicas" (`Color(0xFF123456)`) diretamente no corpo dos widgets.
4. **Desacoplamento de Widgets**:
   - Funções construtoras de widgets internas como `Widget _buildItem()` são desencorajadas para componentes complexos; prefira classes `StatelessWidget` dedicadas para isolar reconstruções.

---

## 4. Persistência de Dados e SQLite (Offline-First)
Quando o projeto utilizar persistência local em SQLite:

1. **Migrações Incrementais e Versionadas**:
   - Nunca altere o schema existente diretamente. Toda alteração de estrutura (coluna nova, índice novo) exige uma migration sequencial vinculada à versão do banco (`onUpgrade`).
2. **Índices Estruturados**:
   - Crie índices explícitos (`CREATE INDEX IF NOT EXISTS`) em qualquer campo utilizado com frequência em cláusulas `WHERE`, ordenações `ORDER BY` ou chaves estrangeiras.
3. **Operações em Lote (Transactions / Batch)**:
   - Mutações ou inserções de múltiplos registros devem obrigatoriamente ser executadas dentro de uma transação ou usando `batch.commit(noResult: true)` para evitar retenção de I/O em disco.
4. **Testabilidade do Banco de Dados**:
   - Testes unitários de repositórios e DAOs devem ser executados em memória utilizando `sqflite_common_ffi` (`databaseFactoryFfi`), garantindo execução em milissegundos sem depender de emulador ou dispositivo físico.

---

## 5. Qualidade de Código e Análise Estática
- O código deve compilar sem nenhum aviso de linter (`flutter analyze` deve retornar código de saída `0`).
- Use o formatador padrão do Dart (`dart format .`) antes de qualquer submissão de código.
- Nomes de classes em `UpperCamelCase`, nomes de variáveis e métodos em `lowerCamelCase`, e nomes de arquivos em `snake_case`.

---

## 6. Versionamento, Flavors e Assinatura de Release
1. **Versionamento Único**:
   - A versão do app vive no `pubspec.yaml` (`version: x.y.z+build`). Todo release incrementa o build number; toda entrega visível incrementa `x.y.z` seguindo semver.
2. **Flavors Obrigatórios (`dev` / `stg` / `prod`)**:
   - Nenhum build de produção pode apontar para backend de desenvolvimento. Use `--flavor` com entrypoints e bundle IDs/applicationIds distintos por ambiente.
3. **Assinatura**:
   - Android: App Bundle (`.aab`) assinado com upload key versionada fora do repo (nunca commitar keystore ou `key.properties`).
   - iOS: distribuição via certificado + provisioning profile gerenciados por `fastlane match`; segredos apenas em variáveis de ambiente do CI.
4. **Gate de Release**:
   - Nenhum build sobe para loja sem `flutter test` + `dart analyze` verdes na mesma revisão.
EOF

# ------------------------------------------------------------------------------
# 7. .agents/skills/ (As 4 Skills Fundamentais)
# ------------------------------------------------------------------------------
cat << 'EOF' > .agents/skills/spec-discovery/SKILL.md
---
name: spec-discovery
description: Condução de entrevistas de descoberta, mapeamento de regras de negócio e geração do PRD com suporte ao Archify.
---

# Skill: Product Discovery & Specification

Esta skill guia o agente `product_architect` ao iniciar um projeto novo ou desenhar uma funcionalidade complexa.

## 1. Princípio da Descoberta Prática
- Não faça perguntas genéricas em excesso. Conduza uma conversa direta, estruturada e colaborativa em **Português do Brasil (pt-BR)**.
- Mapeie imediatamente:
  1. O problema central e a persona que sofre com ele.
  2. A métrica de valor e monetização (se aplicável).
  3. Quais plataformas (Android, iOS) e versões mínimas de SO.
  4. Qual a melhor estratégia de dados para o estágio atual (local simples, nuvem, híbrido).

## 2. Saídas Obrigatórias da Descoberta
Ao final da etapa de discovery, o agente deve obrigatoriamente ter preenchido:
1. `_specs/prd.md`: Baseado no modelo `_specs/prd-template.md`, com plataformas e tecnologias definidos.
2. Arquitetura Interativa via **Archify**: Um diagrama em arquivo HTML ou SVG autocontido detalhando o fluxo de dados entre os componentes.
3. Ticket inicial no `ai-memory` com a ementa do projeto aprovada.
EOF

cat << 'EOF' > .agents/skills/mobile-ux/SKILL.md
---
name: mobile-ux
description: Diretrizes de UX/UI mobile, extração de Design DNA com Google Stitch MCP a partir de prints e geração de tokens visuais.
---

# Skill: Mobile UX & Google Stitch Integration

Esta skill capacita o agente a atuar como um designer de produto e engenheiro de interface, integrando referências visuais em telas funcionais.

## 1. Fluxo de Extração com Google Stitch MCP
Quando existirem capturas ou imagens em `_references/screens/`:
1. **Inspeção de Referência**:
   - Acione a tool `google_stitch_mcp` com a ação `extract_design_context` apontando para o diretório `_references/screens/`.
   - Extraia a paleta de cores primárias, superfícies, contraste, pesos tipográficos e bordas.
2. **Exportação de Design Tokens**:
   - Salve os valores extraídos em `_specs/design-tokens.json` no formato padrão W3C:
     ```json
     {
       "color": {
         "brand": { "primary": { "value": "#..." }, "secondary": { "value": "#..." } },
         "background": { "screen": { "value": "#..." }, "card": { "value": "#..." } }
       },
       "radius": { "md": { "value": "12px" } },
       "spacing": { "base": { "value": "8px" } }
     }
     ```

## 2. Princípios Inegociáveis de Ergonomia Mobile (Touch & Layout)
- **Área Mínima de Toque (Touch Target)**: Todo botão, ícone ou linha clicável deve ter no mínimo 48x48 dp. Se o ícone for menor (ex: 24 dp), adicione padding transparente de padding/hit-test.
- **Zona de Alcance do Polegar (Thumb Zone)**: Ações primárias e botões de avanço/salvamento devem estar posicionados no terço inferior da tela. Evite botões críticos nos cantos superiores.
- **Feedback Háptico e Visual de Toque**: Todo elemento interativo deve ter indicação visual imediata de clique (ripple ou feedback de opacidade).

## 3. A Regra dos 4 Estados de Tela
Nenhuma tela mobile é entregue contendo apenas o estado de dados. A skill exige:
1. `LoadingState`: Uso de shimmers/skeletons para conteúdo assíncrono.
2. `EmptyState`: Ilustração ou ícone sutil, explicação curta em pt-BR e botão de ação primária (Call to Action).
3. `ErrorState`: Mensagem em linguagem humana amigável, ícone de aviso e botão com ação de retentativa.
4. `SuccessState`: Renderização fluida, com scroll desacoplado e animações suaves.
EOF

cat << 'EOF' > .agents/skills/clean-architecture/SKILL.md
---
name: clean-architecture
description: Práticas de Test-Driven Development (Red-Green-Refactor), desacoplamento de domínio e criação de suítes de teste de alta velocidade.
---

# Skill: Clean Architecture & Disciplina TDD

Esta skill dita o comportamento dos subagentes `tdd_tester`, `mobile_builder` e `qa_validator` durante a criação de funcionalidades.

## 1. Protocolo Red-Green-Refactor
1. **Fase Vermelha (RED)**:
   - O agente `tdd_tester` lê o arquivo de especificação da funcionalidade (`_specs/features/*.md`).
   - Identifica os contratos necessários (entidades, repositórios, use cases).
   - Escreve os testes unitários ou de widgets cobrindo os critérios de aceitação.
   - Executa a suíte de testes e valida que ela **FALHOU** pelos motivos corretos (ausência da classe ou método).
2. **Fase Verde (GREEN)**:
   - O agente construtor (`builder`) lê a falha e escreve **apenas** o código suficiente para satisfazer os testes.
   - Não invente funcionalidades secundárias que não estejam cobertas por um teste.
3. **Fase de Refatoração (REFACTOR)**:
   - Limpeza de nomes, extração de métodos duplicados, tipagem rigorosa.
   - Reexecução imediata dos testes para garantir que nada foi quebrado durante a limpeza.

## 2. Isolamento de Dependências
- **Camada de Domínio Puro**: Entidades e contratos de repositório não devem importar Flutter, SQLite, HTTP, Supabase ou bibliotecas de terceiros.
- **Testes de Banco Ultrarrápidos**:
  - Testes que envolvam banco de dados local (ex: SQLite) devem ser executados em memória utilizando fábrica em memória (`sqflite_common_ffi` ou equivalente), garantindo execução em menos de 100ms sem necessidade de emulador ou simulador.
- **Mocks Determinísticos**: Dependências externas (APIs, serviços de rede, GPS) devem ser simuladas via interfaces mockadas.
EOF

cat << 'EOF' > .agents/skills/antigravity-skill-orchestrator/SKILL.md
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
EOF

cat << 'EOF' > .agents/skills/code-quality-tests/SKILL.md
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
EOF

cat << 'EOF' > .agents/skills/flutter-state-riverpod/SKILL.md
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
EOF

cat << 'EOF' > .agents/skills/supabase-flutter/SKILL.md
---
name: supabase-flutter
description: Integração Flutter com Supabase (Auth, Database, Storage, Realtime). Use ao autenticar usuários, ler/escrever dados remotos, subir arquivos ou assinar mudanças em tempo real.
---

# Skill: Supabase no Flutter

Backend padrão deste harness para dados em nuvem. Combina com `local-first-data` para modo offline.

## 1. Setup Mínimo
- Pacote `supabase_flutter`; inicialização única no `main.dart` com URL e anon key via `--dart-define` (nunca hardcodadas no repo).
- Cliente acessível via repositório (`Supabase.instance.client`), nunca direto no widget.

## 2. Auth
- Login social e e-mail/senha via `supabase.auth`; sessão persistida automaticamente.
- Telas reagem a `onAuthStateChange` (ex.: redirecionar para login ao deslogar).
- JWT do usuário propaga o `auth.uid()` usado nas políticas RLS.

## 3. Database e RLS
- Toda tabela exposta ao app **exige RLS ativado** com políticas por `auth.uid()`; sem política, sem acesso.
- Leituras com paginação (`range`) e filtros no servidor — nunca baixar tabelas inteiras para filtrar no cliente.
- Escritas críticas via funções Postgres (`rpc`) quando precisarem de transação atômica.

## 4. Storage e Realtime
- Uploads com caminhos por usuário (`<uid>/<arquivo>`) e buckets com políticas RLS espelhadas.
- Realtime apenas em canais necessários (chat, notificações); fechar a subscription no `dispose`/`ref.onDispose`.
EOF

cat << 'EOF' > .agents/skills/local-first-data/SKILL.md
---
name: local-first-data
description: Persistência local-first em Flutter com Drift/SQLite (migrations, sync, batch). Use ao modelar banco local, versionar schema, operar offline ou sincronizar com a nuvem.
---

# Skill: Dados Local-First (Drift/SQLite + Sync)

Estende a seção 4 de `.agents/rules/mobile.md` com o protocolo operacional.

## 1. Modelagem com Drift
- Tabelas Drift espelham as entidades do domínio; DAOs expõem `Stream`s para a UI reagir a mudanças locais.
- Colunas de controle obrigatórias em tabelas sincronizáveis: `updated_at`, `deleted` (soft-delete) e `dirty` (pendente de envio).

## 2. Migrations
- `schemaVersion` incrementado a cada mudança; cada versão tem `MigrationStrategy` com `onUpgrade` testado.
- Teste de migration: banco antigo em asset → migra → valida dados preservados.

## 3. Operações
- Inserções/atualizações em lote dentro de transação (`batch`); leituras de lista sempre paginadas (`limit`/`offset`).
- Índices em toda coluna usada em `WHERE`, `ORDER BY` ou chave estrangeira.

## 4. Sincronização com Supabase
- Fila de saída: registros `dirty` enviados em ordem, com backoff em falha de rede.
- Fila de entrada: buscar por `updated_at > last_sync` (sync incremental, nunca full-refresh).
- Conflito: última escrita por `updated_at` vence; deleção remota propaga soft-delete local.
- Indicador de sync visível na UI (sincronizado / pendente / erro) — nunca falhar silenciosamente.
EOF

cat << 'EOF' > .agents/skills/mobile-cicd/SKILL.md
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
EOF

cat << 'EOF' > .agents/skills/store-publishing/SKILL.md
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
EOF

cat << 'EOF' > .agents/skills/flutter-release/SKILL.md
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
EOF

cat << 'EOF' > .agents/skills/flutter-apply-architecture-best-practices/SKILL.md
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
EOF

cat << 'EOF' > .agents/skills/flutter-add-widget-test/SKILL.md
---
name: flutter-add-widget-test
description: Testes de widget com WidgetTester (renderização e interações: tap, scroll, texto). Use ao validar que um widget exibe dados corretos e responde a eventos, incluindo os 4 estados de tela.
---

# Skill: Testes de Widget (WidgetTester)

> Adaptado de `flutter/agent-plugins` (time oficial do Flutter, licença BSD-3-Clause).

## 1. Setup
- `flutter_test` em `dev_dependencies`; arquivos em `test/` com sufixo `_test.dart`.
- Widgets com Riverpod: envolver em `ProviderScope` (com `overrides` para mocks). Telas com Material: envolver em `MaterialApp`.

## 2. Componentes
- **WidgetTester**: constrói e interage (`testWidgets`).
- **Finder**: localiza (`find.text`, `find.byType`, `find.byKey`). Prefira `ValueKey` semânticas nos widgets críticos.
- **Matcher**: `findsOneWidget`, `findsNothing`, `findsNWidgets`.

## 3. Workflow (checklist)
- [ ] 1. Definir com `testWidgets('descrição', (tester) async {...})`.
- [ ] 2. Renderizar com `await tester.pumpWidget(...)` (com `ProviderScope`/`MaterialApp` conforme preciso).
- [ ] 3. Verificar estado inicial com `expect(finder, matcher)`.
- [ ] 4. Interagir: `tap` → `pump`; animação/assíncrono → `pumpAndSettle`; texto → `enterText`; lista longa → `scrollUntilVisible`.
- [ ] 5. Verificar estado final.
- [ ] 6. Rodar `flutter test <arquivo>` e iterar até verde.

## 4. Padrão do Harness: Cobrir os 4 Estados
Todo teste de tela cobre: `LoadingState` (skeleton/spinner visível), `EmptyState` (mensagem + CTA),
`ErrorState` (mensagem pt-BR + tentar novamente) e `SuccessState` (dados renderizados).

## 5. Exemplo Mínimo (Riverpod + 4 estados)

```dart
testWidgets('Exibe ErrorState com retry em falha', (tester) async {
  final repo = MockRepo();
  when(() => repo.load()).thenThrow(const NetworkFailure());

  await tester.pumpWidget(
    ProviderScope(
      overrides: [repoProvider.overrideWithValue(repo)],
      child: const MaterialApp(home: ItemsScreen()),
    ),
  );
  await tester.pumpAndSettle();

  expect(find.text('Tentar novamente'), findsOneWidget);
  await tester.tap(find.text('Tentar novamente'));
  await tester.pump();
  verify(() => repo.load()).called(2);
});
```
EOF

cat << 'EOF' > .agents/skills/flutter-add-integration-test/SKILL.md
---
name: flutter-add-integration-test
description: Testes de integração end-to-end (integration_test) com fluxos de usuário e profiling. Use ao automatizar jornadas críticas (login, checkout, onboarding) em device/emulador.
---

# Skill: Testes de Integração (integration_test)

> Adaptado de `flutter/agent-plugins` (time oficial do Flutter, licença BSD-3-Clause).
> Foco mobile (Android/iOS); fluxos web/Chrome da fonte original foram removidos.

## 1. Setup
- `flutter pub add 'dev:integration_test:{"sdk":"flutter"}'`.
- Diretório `integration_test/` na raiz; arquivos `<nome>_test.dart`.
- `IntegrationTestWidgetsFlutterBinding.ensureInitialized()` no início do `main()`.
- `ValueKey`s nos widgets críticos (botões, campos, itens de lista).

## 2. Autoria
- Carregar o app real: `await tester.pumpWidget(const MyApp())`.
- Após cada interação (`tap`, `enterText`): `await tester.pumpAndSettle()`.
- Asserções por `find.byKey(ValueKey('...'))` + `findsOneWidget`/`findsNothing`.
- Listas: `scrollUntilVisible` antes de interagir com item fora da tela.

## 3. Execução (device/emulador conectado)
```bash
flutter test integration_test/app_test.dart
```
- Para profiling com `binding.traceAction()`, usar driver dedicado (`test_driver/perf_driver.dart`).
- `PumpAndSettleTimedOutException` → há animação infinita: isolar com `pump(duration)` ou desativar a animação no teste.

## 4. Workflow (checklist)
- [ ] Deps + `ValueKey`s nos alvos.
- [ ] Escrever `integration_test/<fluxo>_test.dart` cobrindo o caminho feliz + 1 falha (ex.: login inválido).
- [ ] Rodar em Android e iOS antes de considerar verde.
- [ ] Falhou? Revisar saída → `scrollUntilVisible`/`pump` → reexecutar.

## 5. Exemplo Mínimo

```dart
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('login válido abre a home', (tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.enterText(find.byKey(const ValueKey('email')), 'user@mail.com');
    await tester.enterText(find.byKey(const ValueKey('password')), 'Senha123');
    await tester.tap(find.byKey(const ValueKey('login_button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('home_screen')), findsOneWidget);
  });
}
```
EOF

cat << 'EOF' > .agents/skills/flutter-setup-declarative-routing/SKILL.md
---
name: flutter-setup-declarative-routing
description: Roteamento declarativo com go_router (rotas, deep links Android/iOS, nested navigation). Use ao configurar navegação, receber links externos (push, e-mail) ou tabs com estado preservado.
---

# Skill: Roteamento Declarativo (go_router + Deep Links)

> Adaptado de `flutter/agent-plugins` (time oficial do Flutter, licença BSD-3-Clause).

## 1. Conceitos
- `GoRouter`: árvore de rotas; `GoRoute`: path → tela; `redirect`: guardas (ex.: sem sessão → `/login`).
- `StatefulShellRoute`: shell persistente (ex.: `NavigationBar`) com estado por aba.
- Navegação: `context.go` (substitui), `context.push` (empilha), `goNamed` + `pathParameters`, `pop`.

## 2. Setup
```bash
flutter pub add go_router
```
- App usa `MaterialApp.router(routerConfig: _router)`.
- Roteador vive em `lib/core/router/` (arquivo único por app, rotas por feature importadas).

## 3. Deep Links (Android + iOS)
- **Android** (`AndroidManifest.xml`): `intent-filter` com `autoVerify` + scheme/host; hospedar `assetlinks.json` em `/.well-known/`.
- **iOS** (`Info.plist` + `Runner.entitlements`): `FlutterDeepLinkingEnabled` + `applinks:dominio`; hospedar `apple-app-site-association` em `/.well-known/`.
- Validação: `adb shell am start -a VIEW -d "<url>" <package>`; `xcrun simctl openurl booted <url>`.
- Links de e-mail (ex.: recuperação de senha da T01): rota `/reset?token=...` que valida o token antes de renderizar.

## 4. Workflow (checklist)
- [ ] `go_router` + `MaterialApp.router`.
- [ ] Rotas por feature + `redirect` de auth + `errorBuilder` (tela 404 amigável pt-BR).
- [ ] Tabs com `StatefulShellRoute` quando houver bottom nav.
- [ ] Deep links nativos configurados e validados via adb/simctl.
- [ ] Teste de widget navegando (pump + `go` + `pumpAndSettle` + `expect` da tela destino).

## 5. Exemplo Mínimo (guarda de auth + deep link)

```dart
final router = GoRouter(
  initialLocation: '/home',
  redirect: (context, state) {
    final logged = container.read(sessionProvider).isLogged;
    if (!logged && state.matchedLocation != '/login') return '/login';
    return null;
  },
  routes: [
    GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
    GoRoute(path: '/home', builder: (_, _) => const HomeScreen()),
    GoRoute(
      path: '/reset',
      builder: (_, s) => ResetScreen(token: s.uri.queryParameters['token']),
    ),
  ],
  errorBuilder: (_, _) => const NotFoundScreen(),
);
```
EOF

cat << 'EOF' > .agents/skills/flutter-use-http-package/SKILL.md
---
name: flutter-use-http-package
description: Networking REST com package:http (GET/POST/PUT/DELETE, erros, parsing isolado). Use ao consumir APIs remotas em services/repositórios da camada Data.
---

# Skill: Networking REST (package:http)

> Adaptado de `flutter/agent-plugins` (time oficial do Flutter, licença BSD-3-Clause).
> Regra do harness: HTTP vive em services (`data/` ou `core/network/`), nunca em widgets/Notifiers.

## 1. Setup e Permissões
```bash
flutter pub add http
```
- Android: `<uses-permission android:name="android.permission.INTERNET" />` no `AndroidManifest.xml`.
- Token/keys via `--dart-define`, nunca no código.

## 2. Execução e Erros
- URLs sempre com `Uri.parse`; headers de auth/content-type no parâmetro `headers`.
- POST/PUT com `jsonEncode`; sucesso = 200 (GET/PUT/DELETE) ou 201 (POST).
- **Falha nunca retorna null**: lança exceção de domínio (ex.: `NetworkFailure`) — o `AsyncValue.error` vira ErrorState na UI.
- Desserializa com `fromJson` tipado; listas grandes via `compute()` (isolate) para não derrubar frames.

## 3. Workflow (checklist)
- [ ] Model + `fromJson`.
- [ ] Método no service retornando `Future<Model>`.
- [ ] `statusCode` validado + exceção em falha.
- [ ] Teste unitário do service com cliente mockado (sucesso + 4xx/5xx + timeout).
- [ ] Repositório consome o service e expõe modelo de domínio.

## 4. Exemplo Mínimo (service + parsing isolado)

```dart
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

List<Item> parseItems(String body) => (jsonDecode(body) as List)
    .map((e) => Item.fromJson(e as Map<String, dynamic>))
    .toList();

class ItemApi {
  ItemApi(this._client, this._base);
  final http.Client _client;
  final Uri _base;

  Future<List<Item>> fetchAll(String token) async {
    final res = await _client.get(
      _base.replace(path: '/items'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (res.statusCode != 200) throw NetworkFailure();
    return compute(parseItems, res.body);
  }
}
```
EOF

cat << 'EOF' > .agents/skills/flutter-setup-localization/SKILL.md
---
name: flutter-setup-localization
description: Internacionalização com flutter_localizations + intl (ARB, l10n.yaml, plurais). Use ao criar ou alterar qualquer texto visível — o harness exige pt-BR como idioma base.
---

# Skill: Localização (i18n/l10n)

> Adaptado de `flutter/skills` (time oficial do Flutter, licença BSD-3-Clause).
> Regra do harness: **nenhum texto hardcoded em inglês/português solto na UI** — toda string passa por ARB, com pt-BR como template base.

## 1. Setup
```bash
flutter pub add flutter_localizations --sdk=flutter
flutter pub add intl:any
```
- `pubspec.yaml`: `flutter: { generate: true }`.
- `l10n.yaml` na raiz:
```yaml
arb-dir: lib/l10n
template-arb-file: app_pt.arb
output-localization-file: app_localizations.dart
synthetic-package: true
```
- `MaterialApp`: delegates (`AppLocalizations.delegate` + globais) e `supportedLocales` (pt primeiro).

## 2. Workflow
- [ ] Nova string: adicionar ao template `app_pt.arb` **com `@description`**; replicar a chave nos demais `.arb`.
- [ ] Editar string: atualizar **todos** os `.arb`, nunca só um.
- [ ] Rodar `flutter pub get` para regenerar; corrigir erro de sintaxe ARB e repetir.
- [ ] Consumir via `AppLocalizations.of(context)!.chave` — nunca `Text('literal')` em tela.
- [ ] Teste de widget de cada tela com locale pt e (se suportado) en.

## 3. Formatação Avançada (ARB)
- Placeholders: `"hello": "Olá {userName}"` + bloco `@hello` com tipo/exemplo.
- Plurais: `{count, plural, =0{...} =1{...} other{...}}` (`other` obrigatório).
- Selects: `{gender, select, male{...} female{...} other{...}}`.

## 4. Exemplo Mínimo

```json
// lib/l10n/app_pt.arb
{
  "retry": "Tentar novamente",
  "@retry": { "description": "Botão de retentativa do ErrorState" }
}
```

```dart
Text(AppLocalizations.of(context)!.retry)
```
EOF

cat << 'EOF' > .agents/skills/flutter-build-responsive-layout/SKILL.md
---
name: flutter-build-responsive-layout
description: Layouts adaptativos (LayoutBuilder, breakpoints, telas grandes). Use ao construir telas que funcionam em celular, tablet e dobráveis, sem overflow.
---

# Skill: Layout Responsivo/Adaptativo

> Adaptado de `flutter/skills` (time oficial do Flutter, licença BSD-3-Clause).
> Foco mobile-first: celular → tablet/dobrável (form factors desktop são secundários).

## 1. Regras de Medição
- Decida pelo **espaço disponível**, não pelo device: `LayoutBuilder` + `constraints.maxWidth` (nunca "é tablet?" por hardware).
- `MediaQuery.sizeOf(context)` para a janela do app; **não** use `OrientationBuilder` no topo para trocar layout.
- Regra de ouro: constraints descem, tamanhos sobem, o pai posiciona.

## 2. Distribuição e Limites
- `Expanded` (preenche resto) vs `Flexible` (até o limite, com `flex` proporcional) em `Row`/`Column`.
- Telas grandes: `ConstrainedBox(maxWidth: ...)` centralizado para não esticar; listas viram `GridView.builder` com `SliverGridDelegateWithMaxCrossAxisExtent`.
- Listas sempre `builder` (lazy); nunca travar orientação (quebra dobráveis — letterboxing).

## 3. Workflow (checklist)
- [ ] Envolver em `LayoutBuilder`; breakpoint (ex.: `600` para 2 colunas/sidebar).
- [ ] `maxWidth > breakpoint` → layout expandido; senão → layout compacto.
- [ ] Redimensionar/rotacionar no emulador e corrigir overflows (`flutter-fix` conceitual: `Expanded`, `Flexible`, `SingleChildScrollView` onde couber scroll).
- [ ] Touch targets ≥ 48x48 dp preservados em todos os breakpoints.

## 4. Exemplo Mínimo

```dart
const largeMinWidth = 600.0;

LayoutBuilder(
  builder: (context, c) {
    if (c.maxWidth > largeMinWidth) {
      return const Row(children: [
        SizedBox(width: 250, child: NavRail()),
        VerticalDivider(width: 1),
        Expanded(child: Content()),
      ]);
    }
    return const Content();
  },
)
```
EOF

cat << 'EOF' > .agents/skills/dart-use-pattern-matching/SKILL.md
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
EOF

cat << 'EOF' > .agents/skills/dart-collect-coverage/SKILL.md
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
EOF

# ------------------------------------------------------------------------------
# 8. .agents/workflows/dev-cycle.yaml (Workflow Completo com TDD e Git)
# ------------------------------------------------------------------------------
cat << 'EOF' > .agents/workflows/dev-cycle.yaml
version: "1.0"
name: "dev-cycle"
description: "Pipeline completo orientado a Spec com TDD (Red-Green-Refactor), loop autônomo de autorreparo e Git committer semântico."

inputs:
  task_id:
    type: string
    description: "ID da tarefa em _specs/tasks/ (ex: T01). Se informado, a spec é derivada da tarefa e feature_spec torna-se opcional"
    required: false
    default: ""
  feature_spec:
    type: string
    description: "Caminho relativo da especificação da funcionalidade (ex: _specs/features/auth-login.md). Opcional quando task_id é informado"
    required: false
    default: ""
  target:
    type: string
    description: "Plataforma de destino do build: android | ios | both"
    default: "both"
  skip_design:
    type: boolean
    description: "Pular inspeção visual caso a tarefa seja puramente backend/lógica de negócio"
    default: false
  release:
    type: boolean
    description: "Executar a etapa de release ao final (gates, versionamento, build e entrega)"
    default: false

steps:
  - id: step_select_task
    name: "0. Seleção da Tarefa (ranking por dificuldade x urgência)"
    actions:
      - description: "Aborta se nem task_id nem feature_spec foram informados"
        command: >
          if [ -z "${inputs.task_id}" ] && [ -z "${inputs.feature_spec}" ]; then echo "ERRO: informe task_id (ex: T01, veja o ranking em _specs/task-board.md) ou feature_spec."; exit 1; fi
      - description: "Com task_id: valida existência em _specs/tasks/ com status todo e deriva a spec da tarefa"
        command: >
          if [ -n "${inputs.task_id}" ]; then f=$(grep -rl "^id: \"${inputs.task_id}\"$" _specs/tasks/ | head -n 1); if [ -z "$f" ]; then echo "ERRO: tarefa ${inputs.task_id} não encontrada em _specs/tasks/."; exit 1; fi; st=$(grep "^status:" "$f" | head -n 1); case "$st" in *todo*) ;; *) echo "ERRO: tarefa ${inputs.task_id} não está com status todo ($st)."; exit 1;; esac; fi
  - id: step_ingest_context
    name: "1. Ingestão de Contexto e Análise de Símbolos"
    agent: "product_architect"
    actions:
      - description: "Resolver spec (da tarefa quando feature_spec vazio) e validar existência"
        command: >
          SPEC="${inputs.feature_spec}"; if [ -z "$SPEC" ]; then SPEC=$(grep -h "^spec:" $(grep -rl "^id: \"${inputs.task_id}\"$" _specs/tasks/ | head -n 1) | head -n 1 | sed 's/^spec: "\(.*\)"$/\1/'); fi; if [ -z "$SPEC" ]; then echo "ERRO: nenhuma spec resolvida (informe feature_spec ou task_id com campo spec)."; exit 1; fi; test -f "$SPEC" || { echo "ERRO: spec não encontrada: $SPEC. Rode spec-discovery para criá-la antes do dev-cycle."; exit 1; }
      - description: "Fail-fast: aborta se algum MODEL_* (REASONING/CODING/DESIGN/OPS) estiver vazio"
        command: >
          for v in MODEL_REASONING MODEL_CODING MODEL_DESIGN MODEL_OPS; do
            if [ -z "${!v}" ]; then echo "ERRO: $v não definida. Defina antes de executar (ex: export $v='<seu-modelo>') e rode novamente."; exit 1; fi;
          done
      - description: "Consultar grafo estático via Graft para mapear arquivos impactados"
        command: "graft scan --path apps/mobile"
      - description: "Inicializar ticket de execução no ai-memory"
        command: >
          ai-memory ticket create
          --title "Dev Cycle: ${inputs.feature_spec}"
          --tags "platform:${inputs.target},tdd,in_progress"

  - id: step_design_tokens
    name: "2. Verificação de Tokens e Referências Visuais"
    agent: "ui_ux_designer"
    condition: "${inputs.skip_design == false}"
    actions:
      - description: "Verificar referências em _references/screens/ via Google Stitch MCP"
        tool: "google_stitch_mcp"
        parameters:
          action: "extract_design_context"
          source_dir: "_references/screens/"
      - description: "Garantir consistência das cores e tipografia em _specs/design-tokens.json"
        tool: "file_read"
        path: "_specs/design-tokens.json"

  - id: step_tdd_red
    name: "3. TDD Fase Vermelha (RED) - Escrita de Testes Que Devem Falhar"
    agent: "tdd_tester"
    actions:
      - description: "Ler contratos e critérios de aceitação na spec"
        tool: "file_read"
        path: "${inputs.feature_spec}"
      - description: "Escrever testes unitários e de interface cobrindo os cenários"
        tool: "file_write"
      - description: "Executar testes e certificar que falham (Red)"
        command: "cd apps/mobile && flutter test || true"

  - id: step_tdd_green
    name: "4. TDD Fase Verde (GREEN) - Implementação de Código de Produção"
    agent: "mobile_builder"
    actions:
      - description: "Escrever código de produção estritamente necessário para satisfazer os testes"
        tool: "file_write"

  - id: step_repair_loop
    name: "5. Validação de Testes e Loop Fechado de Autorreparo"
    agent: "qa_validator"
    loop:
      max_iterations: 3
      until: "test_result.exit_code == 0 && lint_result.exit_code == 0"
      on_iteration:
        - name: "Executar Linter e Checagem de Tipos"
          command: "cd apps/mobile && dart analyze"
          catch_output: "lint_result"
        - name: "Executar Suíte de Testes"
          command: "cd apps/mobile && flutter test"
          catch_output: "test_result"

  - id: step_refactor
    name: "6. Refatoração de Código, Limpeza e Formatação"
    agent: "qa_validator"
    actions:
      - description: "Aplicar formatador de código oficial"
        command: "cd apps/mobile && dart format ."

  - id: step_git_commit
    name: "7. Versionamento Atômico e Fechamento no Git"
    agent: "git_committer"
    actions:
      - description: "Adicionar arquivos alterados à staging area"
        command: "git add apps/mobile _specs/"
      - description: "Executar commit semântico atômico"
        command: >
          git commit -m "feat(mobile): implement ${inputs.feature_spec} with TDD coverage"
          -m "- Verified against criteria in ${inputs.feature_spec}"
          -m "- Clean Architecture and full test suite passed"

  - id: step_release
    name: "8. Release (gates, versionamento, build, entrega)"
    agent: "release_manager"
    condition: "${inputs.release == true}"
    actions:
      - description: "Seguir flutter-release com mobile-cicd/store-publishing conforme platform"
        tool: "file_read"
        path: "_specs/prd.md"
EOF

# ------------------------------------------------------------------------------
# 9. .gitignore recomendado
# ------------------------------------------------------------------------------
if [ ! -f .gitignore ]; then
cat << 'EOF' > .gitignore
# Ambientes e Dependências
.env
.env*.local
node_modules/
.dart_tool/
.packages
build/

# Antigravity & Memória Local
.agents/memory/*.db
.agents/memory/*.db-journal

# IDEs e OS
.DS_Store
Thumbs.db
.vscode/
.idea/
EOF
echo -e "${GREEN}✔ .gitignore padrão criado.${NC}"
fi

echo ""
echo -e "${GREEN}=====================================================${NC}"
echo -e "${GREEN}  🎉 Harness configurado com sucesso!               ${NC}"
echo -e "${GREEN}=====================================================${NC}"
echo ""
echo -e "Próximos passos recomendados:"
echo -e " 1. Adicione prints/telas de inspiração em:  ${CYAN}_references/screens/${NC}"
echo -e " 2. Inicie a descoberta do produto:          ${CYAN}Copie _specs/prd-template.md para _specs/prd.md${NC}"
echo -e " 3. Escolha os modelos por tarefa:          ${CYAN}export MODEL_REASONING='seu-modelo-forte' MODEL_CODING='seu-modelo-rapido'${NC}"
echo ""