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
mkdir -p .agents/skills/mobile-ux-stitch
mkdir -p .agents/skills/web-performance-seo
mkdir -p .agents/skills/clean-architecture-tdd
mkdir -p .agents/workflows
mkdir -p .agents/memory
mkdir -p _specs/features
mkdir -p _references/screens
mkdir -p _references/brand
mkdir -p apps/mobile
mkdir -p apps/web
mkdir -p apps/landing

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

# Alvos da aplicação (ativados na fase de descoberta)
targets:
  mobile: true        # apps/mobile
  web: false          # apps/web
  landing_page: true  # apps/landing

# Definição tecnológica aberta decidida na descoberta
technology_choices:
  # Estratégia de dados definida conforme a necessidade do projeto:
  # Exemplos: local_first (SQLite, Drift, Hive, Realm) | cloud_only | hybrid_sync | serverless | rest_api | none
  persistence_type: "to_be_decided" 
  primary_database: "to_be_decided" # ex: sqlite, postgres, mysql, supabase, firebase, local_json, nenhum
  backend_strategy: "to_be_decided" # ex: direct_db, custom_api, edge_functions, baas, offline_only

  # Frameworks decididos por alvo
  mobile_framework: "flutter" # ou react_native_expo, nativo, etc.
  web_framework: "nextjs"     # ou react_vite, astro, etc.
  styling_approach: "tokens"  # tailwind, design_tokens, material3
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

## 3. Escopo dos Alvos (Targets)

### 3.1. Aplicativo Mobile (`apps/mobile`)
> *Status: [Ativo / Inativo]*
- **Papel no Produto**: 
- **Capacidades Críticas**: [Offline-first, notificações, acesso à câmera, biometria, etc.]

### 3.2. Painel Web / Dashboard (`apps/web`)
> *Status: [Ativo / Inativo]*
- **Papel no Produto**: 
- **Capacidades Críticas**: [Relatórios, dashboards gerenciais, operações em massa, desktop-friendly]

### 3.3. Landing Page / Site Institucional (`apps/landing`)
> *Status: [Ativo / Inativo]*
- **Papel no Produto**: 
- **Capacidades Críticas**: [Alta conversão, SEO semântico, carregamento instantâneo, captura de leads]

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
- **Quero** [realizar uma ação no app/web],
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

models:
  reasoning: "${MODEL_REASONING:-gemini-3.8-pro}"
  coding: "${MODEL_CODING:-gemini-3.8-flash}"
  multimodal_design: "${MODEL_DESIGN:-gemini-3.8-flash}"
  fast_ops: "${MODEL_OPS:-gemini-3.8-flash}"

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
    active_when: "targets.mobile == true"
    test_command: "cd apps/mobile && flutter test"
    lint_command: "cd apps/mobile && dart analyze"
  web:
    path: "apps/web/"
    active_when: "targets.web == true"
    test_command: "cd apps/web && npm test"
    lint_command: "cd apps/web && npm run lint"
  landing:
    path: "apps/landing/"
    active_when: "targets.landing_page == true"
    test_command: "cd apps/landing && npm test"
    lint_command: "cd apps/landing && npm run lint"

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
    model: "${models.reasoning}"
    role: "Entrevista o desenvolvedor, define requisitos de negócio e gera o PRD agnóstico em _specs/ com diagramas Archify."
    rules:
      - ".agents/rules/global.md"
    skills:
      - ".agents/skills/spec-discovery/SKILL.md"
    tools: ["file_read", "file_write", "ai_memory"]

  ui_ux_designer:
    model: "${models.multimodal_design}"
    role: "Inspeciona capturas em _references/screens/ usando Google Stitch MCP e gera os tokens de design em _specs/design-tokens.json."
    rules:
      - ".agents/rules/global.md"
    skills:
      - ".agents/skills/mobile-ux-stitch/SKILL.md"
    tools: ["google_stitch_mcp", "file_read", "file_write", "ai_memory"]

  tdd_tester:
    model: "${models.coding}"
    role: "Lê a spec da feature e cria testes unitários/widgets/componentes que obrigatoriamente falham antes do código."
    rules:
      - ".agents/rules/global.md"
    skills:
      - ".agents/skills/clean-architecture-tdd/SKILL.md"
    tools: ["file_read", "file_write", "bash", "graft", "ai_memory"]

  mobile_builder:
    model: "${models.coding}"
    role: "Escreve código Flutter estritamente tipado, modular e aderente à Clean Architecture para passar nos testes."
    active_when: "targets.mobile == true"
    rules:
      - ".agents/rules/global.md"
      - ".agents/rules/mobile.md"
    skills:
      - ".agents/skills/mobile-ux-stitch/SKILL.md"
      - ".agents/skills/clean-architecture-tdd/SKILL.md"
    tools: ["file_read", "file_write", "graft", "ai_memory"]

  web_builder:
    model: "${models.coding}"
    role: "Escreve componentes Next.js/React com Server Components e boas práticas de Core Web Vitals (Addy Osmani)."
    active_when: "targets.web == true || targets.landing_page == true"
    rules:
      - ".agents/rules/global.md"
      - ".agents/rules/web.md"
    skills:
      - ".agents/skills/web-performance-seo/SKILL.md"
    tools: ["file_read", "file_write", "graft", "ai_memory"]

  qa_validator:
    model: "${models.coding}"
    role: "Executa testes e linters do target ativo, orquestrando até 3 ciclos de autorreparo automático caso algo quebre."
    rules:
      - ".agents/rules/global.md"
    tools: ["bash", "file_read", "file_write", "ai_memory"]

  git_committer:
    model: "${models.fast_ops}"
    role: "Inspeciona o diff staged, extrai o contexto do ticket no ai-memory e cria o commit semântico atômico."
    rules:
      - ".agents/rules/global.md"
    tools: ["git", "ai_memory", "bash"]

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
│   ├── database/          # SQLite / persistência local (migrations, helpers, DAOs)
│   ├── network/           # Clientes HTTP / APIs remotas
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
- O **Domínio (Domain)** é composto por Dart puro: livre de dependências do framework Flutter, widgets ou pacotes externos.

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
1. **Construtores `const`**: Sempre declare construtores `const` em Widgets sem estado mutável para evitar reconstruções desnecessárias.
2. **Tamanho Mínimo de Alvo de Toque (Touch Target)**:
   - Todo botão, ícone interativo ou elemento clicável deve ter uma área de toque de no mínimo 48x48 dp.
3. **Alinhamento com Tokens Visuais**:
   - Cores, raios de borda, espaçamentos e fontes devem ser consumidos centralmente a partir de `core/theme/` (gerado a partir de `_specs/design-tokens.json`).
   - É proibido usar cores "mágicas" (`Color(0xFF123456)`) soltas no corpo dos widgets.

---

## 4. Persistência de Dados e Testabilidade
1. **Migrações Incrementais e Versionadas**:
   - Nunca altere schemas existentes diretamente; utilize migrations sequenciais vinculadas à versão do banco.
2. **Operações em Lote**:
   - Mutações de múltiplos registros devem utilizar transações ou batches para evitar retenção de I/O em disco.
3. **Testabilidade em Memória**:
   - Testes unitários de repositórios e DAOs locais devem rodar em memória (ex.: `sqflite_common_ffi`), garantindo feedback em milissegundos sem depender de emulador físico.
EOF

cat << 'EOF' > .agents/rules/web.md
# Diretrizes Técnicas para Desenvolvimento Web e Landing Pages (Next.js / React)

Este guia estabelece os padrões de arquitetura, ergonomia de componentes, performance de renderização (Core Web Vitals) e boas práticas de conversão para aplicações em `apps/web/` e `apps/landing/`.

---

## 1. Arquitetura de Software e Estrutura de Diretórios
Adotamos o padrão modular com Next.js (App Router) e TypeScript estrito:

```text
apps/[web|landing]/
├── app/                   # Rotas, Layouts e Server Actions (App Router)
│   ├── (auth)/            # Rotas autenticadas agrupadas
│   ├── api/               # Route Handlers para webhooks/integrações
│   ├── layout.tsx         # Layout raiz com fontes e metadados globais
│   └── page.tsx           # Ponto de entrada da aplicação/landing
├── components/            # Componentes visuais reutilizáveis
│   ├── ui/                # Componentes atômicos e primitivos (Design System / Tailwind)
│   └── shared/            # Componentes compostos entre páginas
├── lib/                   # Utilitários, clientes de dados e conexões
└── types/                 # Interfaces e tipos globais TypeScript
```

---

## 2. Paradigma Server-First (RSC) e Gestão de Estado
1. **Server Components por Padrão**:
   - Todo componente deve ser renderizado no servidor por padrão (`React Server Component`).
   - A diretiva `'use client'` deve ser restrita exclusivamente às folhas da árvore de componentes que exigem interatividade imediata (event listeners, hooks como `useState`/`useEffect` ou APIs de navegador).
2. **Data Fetching Direto no Servidor**:
   - Evite carregar dados primários através de `useEffect` no cliente. Busque os dados diretamente em Server Components assíncronos (`async/await`) para eliminar cascatas (*waterfalls*).
3. **Mutações Seguras via Server Actions**:
   - Formulários e ações de escrita devem priorizar **Server Actions** tipadas com validação de schema (ex.: Zod).

---

## 3. Performance Web e Core Web Vitals (Padrões de Engenharia)
Inspirado nas diretrizes de alta performance de Addy Osmani:
1. **Otimização de Carregamento de Recursos**:
   - Imagens devem obrigatoriamente utilizar o componente `next/image` com dimensões explícitas (`width` e `height`) ou propriedade `fill`, prevenindo CLS (Cumulative Layout Shift).
   - A imagem principal da primeira dobra (*Hero Image*) deve conter a propriedade `priority` para otimizar o LCP (Largest Contentful Paint).
2. **Fontes Locais e Zero Layout Shift**:
   - Carregue fontes via `next/font` com estratégia de swap automático.
3. **Eliminação de Código Não Utilizado**:
   - Importe ícones e módulos de forma granular (ex.: `lucide-react` com imports individuais).

---

## 4. Landing Pages de Alta Conversão e SEO (`apps/landing`)
1. **Metadados e Open Graph Dinâmicos**:
   - Todo layout ou página pública deve declarar o objeto `metadata` completo: `title`, `description`, `openGraph` (com imagem de preview de 1200x630px) e `robots`.
2. **Semântica HTML e Acessibilidade (a11y)**:
   - Respeite rigorosamente a hierarquia de títulos: apenas um único `<h1>` por página, seguido de `<h2>` e `<h3>`.
   - Contraste de cores conforme as diretrizes WCAG AA.
3. **Seções Obrigatórias de Conversão**:
   - **Above the Fold**: Proposta de valor clara, subtítulo de reforço e CTA principal.
   - **Prova Social / Demonstração**: Demonstração visual do valor gerado ou depoimentos.
   - **Tabela de Preços / Planos**: Comparativo direto e transparente.
   - **FAQ com Acordeão**: Quebra das principais objeções antes da compra.
EOF

# ------------------------------------------------------------------------------
# 7. .agents/skills/ (As 4 Skills Fundamentais)
# ------------------------------------------------------------------------------
cat << 'EOF' > .agents/skills/spec-discovery/SKILL.md
---
name: spec-discovery
description: Conduz a entrevista de produto inicial, define requisitos de negócio e gera o PRD estruturado em _specs/prd.md com diagramas conceituais Archify.
---

# Skill: Descoberta de Produto e PRD

Esta skill orienta o agente `product_architect` na formalização de escopo e estratégias técnicas antes do início do código.

## 1. Processo de Entrevista de Produto
O agente deve formular perguntas curtas e diretas ao desenvolvedor, cobrindo:
1. **Dor Central**: Qual gargalo o usuário enfrenta sem esse software?
2. **Alvos do Projeto (Targets)**: O projeto terá App Mobile, Painel Web e/ou Landing Page?
3. **Decisão de Persistência**: A solução precisa de banco 100% local (ex: SQLite), sincronização em nuvem ou API externa?
4. **Métrica de Sucesso (North Star Metric)**: O que valida comercialmente o produto no curto prazo?

## 2. Geração do PRD
- Copie o modelo de `_specs/prd-template.md` para `_specs/prd.md`.
- Preencha com linguagem objetiva em pt-BR.
- Registre o ticket inicial no `ai-memory` marcando os targets ativos.
EOF

cat << 'EOF' > .agents/skills/mobile-ux-stitch/SKILL.md
---
name: mobile-ux-stitch
description: Diretrizes de UX/UI mobile, extração de Design DNA com Google Stitch MCP a partir de prints e geração de tokens visuais.
---

# Skill: Mobile UX & Google Stitch Integration

Esta skill capacita o agente a atuar como designer e engenheiro de interface mobile.

## 1. Fluxo de Extração com Google Stitch MCP
Quando existirem capturas ou imagens em `_references/screens/`:
1. Inspecione as referências via tool `google_stitch_mcp` com a ação `extract_design_context`.
2. Salve os valores extraídos em `_specs/design-tokens.json` no formato padrão W3C (cores, raios de borda, espaçamentos e fontes).

## 2. Ergonomia Mobile e Regra dos 4 Estados
- **Touch Target**: Área clicável mínima de 48x48 dp.
- **Thumb Zone**: Ações críticas posicionadas no terço inferior da tela.
- **Os 4 Estados de Tela Obrigatórios**:
  - `LoadingState`: Shimmer skeletons contextuais.
  - `EmptyState`: Mensagem amigável com botão de ação direta.
  - `ErrorState`: Mensagem clara em pt-BR e botão de retentativa.
  - `SuccessState`: Renderização fluida e performática dos dados.
EOF

cat << 'EOF' > .agents/skills/web-performance-seo/SKILL.md
---
name: web-performance-seo
description: Padrões de alta performance web, otimização de Core Web Vitals, SSR/RSC e SEO técnico inspirados nas diretrizes de Addy Osmani.
---

# Skill: Web Performance & SEO Optimization

Esta skill estabelece os padrões técnicos aplicáveis às aplicações em `apps/web/` e `apps/landing/`.

## 1. Core Web Vitals
- **LCP (< 2.5s)**: Imagens hero da primeira dobra com a propriedade `priority`.
- **CLS (< 0.1)**: Mídia com dimensões explícitas (`width` e `height`) e fontes com swap automático.
- **INP (< 200ms)**: Tarefas longas divididas para evitar travamento da thread principal.

## 2. Padrão Server-First (React Server Components)
- Mantenha a maior parte dos componentes como Server Components puros.
- Restrinja `'use client'` às folhas da árvore com interatividade imediata.
- Mutações centralizadas em Server Actions com validação Zod.
EOF

cat << 'EOF' > .agents/skills/clean-architecture-tdd/SKILL.md
---
name: clean-architecture-tdd
description: Práticas de Test-Driven Development (Red-Green-Refactor), desacoplamento de domínio e criação de suítes de teste de alta velocidade.
---

# Skill: Clean Architecture & Disciplina TDD

Esta skill dita o comportamento dos subagentes `tdd_tester`, `mobile_builder` e `qa_validator`.

## 1. Protocolo Red-Green-Refactor
1. **Fase Vermelha (RED)**:
   - Lê a spec da feature em `_specs/features/*.md`.
   - Cria testes unitários ou de widgets que cobrem os critérios de aceitação.
   - Executa a suíte e valida que ela **FALHOU** pelos motivos corretos.
2. **Fase Verde (GREEN)**:
   - Escreve apenas o código estritamente necessário para fazer os testes passarem.
3. **Fase de Refatoração (REFACTOR)**:
   - Limpeza de nomes, tipagem estrita e reexecução dos testes para garantir que tudo continua verde.

## 2. Isolamento de Domínio
- O domínio é composto por regras puras de negócio, livre de frameworks de UI ou dependências externas.
- Testes de banco de dados devem ser executados em memória para resposta instantânea.
EOF

# ------------------------------------------------------------------------------
# 8. .agents/workflows/dev-cycle.yaml (Workflow Completo com TDD e Git)
# ------------------------------------------------------------------------------
cat << 'EOF' > .agents/workflows/dev-cycle.yaml
version: "1.0"
name: "dev-cycle"
description: "Pipeline completo orientado a Spec com TDD (Red-Green-Refactor), loop autônomo de autorreparo e Git committer semântico."

inputs:
  feature_spec:
    type: string
    description: "Caminho relativo da especificação da funcionalidade (ex: _specs/features/auth-login.md)"
    required: true
  target:
    type: string
    description: "Alvo da execução: mobile | web | landing (se omitido, lê targets de _specs/prd.md)"
    required: false
  skip_design:
    type: boolean
    description: "Pular inspeção visual caso a tarefa seja puramente backend/lógica de negócio"
    default: false

steps:
  - id: step_ingest_context
    name: "1. Ingestão de Contexto e Análise de Símbolos"
    agent: "product_architect"
    actions:
      - description: "Validar se a spec existe e possui critérios de aceitação objetivos"
        command: "test -f ${inputs.feature_spec}"
      - description: "Consultar grafo estático via Graft para mapear arquivos impactados"
        command: "graft scan --path apps/${inputs.target || 'mobile'}"
      - description: "Inicializar ticket de execução no ai-memory"
        command: >
          ai-memory ticket create
          --title "Dev Cycle: ${inputs.feature_spec}"
          --tags "target:${inputs.target},tdd,in_progress"

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
        command: >
          if [ "${inputs.target}" = "web" ] || [ "${inputs.target}" = "landing" ]; then
            cd apps/${inputs.target} && npm test || true
          else
            cd apps/mobile && flutter test || true
          fi

  - id: step_tdd_green
    name: "4. TDD Fase Verde (GREEN) - Implementação de Código de Produção"
    agent_selector:
      when:
        - condition: "${inputs.target == 'mobile'}"
          agent: "mobile_builder"
        - condition: "${inputs.target == 'web' || inputs.target == 'landing'}"
          agent: "web_builder"
        - default: "mobile_builder"
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
          command: >
            if [ "${inputs.target}" = "web" ] || [ "${inputs.target}" = "landing" ]; then
              cd apps/${inputs.target} && npm run lint
            else
              cd apps/mobile && dart analyze
            fi
          catch_output: "lint_result"
        - name: "Executar Suíte de Testes"
          command: >
            if [ "${inputs.target}" = "web" ] || [ "${inputs.target}" = "landing" ]; then
              cd apps/${inputs.target} && npm test
            else
              cd apps/mobile && flutter test
            fi
          catch_output: "test_result"

  - id: step_refactor
    name: "6. Refatoração de Código, Limpeza e Formatação"
    agent: "qa_validator"
    actions:
      - description: "Aplicar formatador de código oficial"
        command: >
          if [ "${inputs.target}" = "web" ] || [ "${inputs.target}" = "landing" ]; then
            cd apps/${inputs.target} && npm run format || true
          else
            cd apps/mobile && dart format .
          fi

  - id: step_git_commit
    name: "7. Versionamento Atômico e Fechamento no Git"
    agent: "git_committer"
    actions:
      - description: "Adicionar arquivos alterados à staging area"
        command: "git add apps/${inputs.target} _specs/"
      - description: "Executar commit semântico atômico"
        command: >
          git commit -m "feat(${inputs.target}): implement ${inputs.feature_spec} with TDD coverage"
          -m "- Verified against criteria in ${inputs.feature_spec}"
          -m "- Clean Architecture and full test suite passed"
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
echo -e " 3. Ajuste os modelos (se desejar):          ${CYAN}export MODEL_REASONING='gemini-3.8-pro'${NC}"
echo ""