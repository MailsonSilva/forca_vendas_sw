---
name: mobile-ux-stitch
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
- **Área Mínima de Toque (Touch Target)**: Todo botão, ícone ou linha clicável deve ter no mínimo $48 \times 48\text{ dp}$. Se o ícone for menor (ex: $24\text{ dp}$), adicione padding transparente de padding/hit-test.
- **Zona de Alcance do Polegar (Thumb Zone)**: Ações primárias e botões de avanço/salvamento devem estar posicionados no terço inferior da tela. Evite botões críticos nos cantos superiores.
- **Feedback Háptico e Visual de Toque**: Todo elemento interativo deve ter indicação visual imediata de clique (ripple ou feedback de opacidade).

## 3. A Regra dos 4 Estados de Tela
Nenhuma tela mobile é entregue contendo apenas o estado de dados. A skill exige:
1. `LoadingState`: Uso de shimmers/skeletons para conteúdo assíncrono.
2. `EmptyState`: Ilustração ou ícone sutil, explicação curta em pt-BR e botão de ação primária (Call to Action).
3. `ErrorState`: Mensagem em linguagem humana amigável, ícone de aviso e botão com ação de retentativa.
4. `SuccessState`: Renderização fluida, com scroll desacoplado e animações suaves.