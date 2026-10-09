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
  3. Quais alvos serão criados (Mobile, Web, Landing Page).
  4. Qual a melhor estratégia de dados para o estágio atual (local simples, nuvem, híbrido).

## 2. Saídas Obrigatórias da Descoberta
Ao final da etapa de discovery, o agente deve obrigatoriamente ter preenchido:
1. `_specs/prd.md`: Baseado no modelo `_specs/prd-template.md`, com todos os alvos e tecnologias definidos.
2. Arquitetura Interativa via **Archify**: Um diagrama em arquivo HTML ou SVG autocontido detalhando o fluxo de dados entre os componentes.
3. Ticket inicial no `ai-memory` com a ementa do projeto aprovada.