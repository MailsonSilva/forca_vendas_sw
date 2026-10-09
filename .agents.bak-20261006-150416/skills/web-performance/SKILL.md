---
name: web-performance-seo
description: Padrões de alta performance web, otimização de Core Web Vitals, SSR/RSC e SEO técnico inspirados nas diretrizes de engenharia de Addy Osmani.
---

# Skill: Web Performance & SEO Optimization

Esta skill estabelece os padrões técnicos aplicáveis às aplicações em `apps/web/` e `apps/landing/`, focada em carregamento instantâneo, zero Cumulative Layout Shift e acessibilidade.

## 1. Otimização de Core Web Vitals
- **Largest Contentful Paint (LCP < 2.5s)**:
  - Imagens hero (acima da dobra) no Next.js devem conter obrigatoriamente a propriedade `priority`.
  - Pré-carregue recursos críticos e evite bloquear a renderização inicial com scripts pesados de terceiros.
- **Cumulative Layout Shift (CLS < 0.1)**:
  - Todo elemento de mídia (`<img>`, `<video>`, `<iframe>`) deve ter dimensões explícitas (`width` e `height`) ou container pai com proporção fixa (`aspect-ratio`).
  - Carregue fontes locais ou Google Fonts com a flag `display: swap` via `next/font` para eliminar FOUT (*Flash of Unstyled Text*).
- **Interaction to Next Paint (INP < 200ms)**:
  - Divida tarefas longas de JavaScript.
  - Isole handlers de formulários e evite computações síncronas pesadas na thread principal.

## 2. Padrão Server-First (React Server Components)
- Mantenha 90% dos componentes como Server Components puros.
- Utilize a diretiva `'use client'` estritamente quando houver necessidade de:
  - Escutadores de eventos DOM (`onClick`, `onChange`).
  - Hooks do React (`useState`, `useReducer`, `useEffect`).
  - Acesso a APIs exclusivas do navegador (`localStorage`, `navigator`, `window`).
- Mutações de dados devem ser orquestradas via **Server Actions** com tipagem estrita via Zod.

## 3. SEO Técnico e Landing Pages de Alta Conversão
- **Hierarquia Semântica**: Exatamente um único `<h1>` por página, estruturando subtítulos em `<h2>` e `<h3>`.
- **Open Graph Dinâmico**: Todo layout público deve fornecer imagem prévia de 1200x630px, metatags de Twitter Card e canônicos.
- **Acessibilidade (WCAG AA)**:
  - Todo botão sem texto explícito deve possuir atributo `aria-label`.
  - Contraste de cores entre texto e fundo com proporção mínima de 4.5:1.