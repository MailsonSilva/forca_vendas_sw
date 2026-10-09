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
