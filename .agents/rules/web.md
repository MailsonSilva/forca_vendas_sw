# Diretrizes Técnicas para Desenvolvimento Web e Landing Pages (Next.js / React)

Este guia estabelece os padrões de arquitetura, ergonomia de componentes, performance de renderização (Core Web Vitals) e boas práticas de conversão para aplicações em `apps/web/` e `apps/landing/`, fundamentado em padrões modernos de engenharia web.

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
│   ├── supabase/          # Clientes Supabase (Server e Browser clients)
│   └── utils.ts           # Formatadores e helpers compartilhados
└── types/                 # Interfaces e tipos globais TypeScript
```

---

## 2. Paradigma Server-First (RSC) e Gestão de Estado
1. **Server Components por Padrão**:
   - Todo componente deve ser renderizado no servidor por padrão (`React Server Component`).
   - A diretiva `'use client'` deve ser restrita exclusivamente às folhas da árvore de componentes que exigem interatividade imediata (event listeners, hooks como `useState`/`useEffect` ou APIs de navegador).
2. **Data Fetching Direto no Servidor**:
   - Evite carregar dados primários através de `useEffect` no cliente. Busque os dados diretamente em Server Components assíncronos (`async/await`) para eliminar cascatas de carregamento (*waterfalls*).
3. **Mutações Seguras via Server Actions**:
   - Formulários e ações de escrita devem priorizar **Server Actions** tipadas com validação de schema (ex.: Zod).
   - Manipulação de feedback otimista na UI com hooks padrão (`useOptimistic`, `useTransition`).

---

## 3. Performance Web e Core Web Vitals (Padrões de Engenharia)
Inspirado nas diretrizes de alta performance web e otimização para carregamento instantâneo:

1. **Otimização de Carregamento de Recursos**:
   - Imagens devem obrigatoriamente utilizar o componente `next/image` com dimensões explícitas (`width` e `height`) ou propriedade `fill`, prevenindo alterações cumulativas de layout (**Cumulative Layout Shift - CLS**).
   - A imagem principal visível da dobra inicial (*Hero Image*) deve conter a propriedade `priority` para otimizar o **Largest Contentful Paint (LCP)**.
2. **Fontes Locais e Zero Layout Shift**:
   - Carregue fontes via `next/font/google` ou `next/font/local` com a estratégia de swap automático para eliminar FOUT (*Flash of Unstyled Text*).
3. **Eliminação de Código Não Utilizado (Tree-Shaking)**:
   - Evite bibliotecas monolíticas pesadas. Importe ícones e módulos de forma granular (ex.: `lucide-react` com imports individuais).
   - Use dynamic imports (`next/dynamic`) para componentes pesados que ficam abaixo da dobra (*below the fold*) ou dentro de modais.

---

## 4. Landing Pages de Alta Conversão e SEO (`apps/landing`)
Para o target de landing page e captura de leads:

1. **Metadados e Open Graph Dinâmicos**:
   - Todo layout ou página pública deve declarar o objeto `metadata` completo: `title`, `description`, `openGraph` (com imagem de preview de 1200x630px) e `robots`.
2. **Semântica HTML e Acessibilidade (a11y)**:
   - Respeite rigorosamente a hierarquia de títulos: apenas um único `<h1>` por página, seguido de `<h2>` e `<h3>` estruturados.
   - Todo elemento interativo deve ter rótulo acessível (`aria-label`) e contraste de cores conforme as diretrizes WCAG AA.
3. **Copywriting e Seções Obrigatórias de Conversão**:
   - **Above the Fold (Primeira Dobra)**: Proposta de valor em uma frase clara, subtítulo de reforço e botão de Ação Principal (*Call to Action - CTA*).
   - **Prova Social / Autoridade**: Depoimentos, métricas reais ou demonstração visual da dor resolvida.
   - **Tabela de Preços / Oferta**: Comparativo claro, sem letras miúdas, com garantia e quebra de objeções.
   - **FAQ com Acordeão**: Endereçamento das principais dúvidas antes do fechamento.

---

## 5. Estilização e Tokens de Design
- Utilize **Tailwind CSS** estruturado em classes semânticas.
- Cores de marca, raio de borda e escalas tipográficas devem ser mapeados a partir de `_specs/design-tokens.json` e espelhados no arquivo `tailwind.config.ts`.
- Evite valores arbitrários soltos (ex.: `w-[347px]`); utilize a grade padronizada do sistema.