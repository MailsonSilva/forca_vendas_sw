# SPEC-050: Consulta SQL Oficial de Carregamento e Pesquisa de Produtos com Estoque Multi-Filial

## Problem Statement

No aplicativo de Força de Vendas, o vendedor em campo precisa carregar o catálogo e pesquisar mercadorias com extrema agilidade e precisão. Atualmente, divergências de saldo entre o cadastro geral (`cadpro00`) e a tabela de estoque multi-filial (`estpro00`), somadas à ausência de uma consulta canônica oficial padronizada com o código legado C++/Qt, causam inconsistências na exibição de preços (`pro00_pcomax`), unidades (`pro00_unidad`), códigos de barras (`pro00_codbar`) e saldos disponíveis (`pro00_qtdest`). Além disso, buscas em bases locais volumosas sem paginação rigorosa (`LIMIT`/`OFFSET`) e sem indexação adequada degradam a performance do dispositivo móvel.

## Solution

Padronizar a consulta SQL oficial de carregamento e pesquisa de produtos no SQLite local (`dbforcacad001.db`), alinhando-a estritamente com as regras de negócio legadas em C++/Qt:
1. Utilização de `cadpro00` como tabela mestre (`pro00_codigo`, `pro00_descri`, `pro00_unidad`, `pro00_pcomax`, `pro00_codbar`).
2. Junção relacional (`LEFT JOIN`) com `estpro00` vinculada pelo código do produto (`estpro00.pro00_codpro = cadpro00.pro00_codigo`) e filtrada estritamente pela filial ativa da sessão (`cadrep00.ven00_codfil`).
3. Fallback determinístico de estoque utilizando `COALESCE(e.pro00_qtdest, p.pro00_qtdest, 0.0)` para preservar o saldo geral de `cadpro00` caso não haja registro específico para a filial em `estpro00`.
4. Critérios flexíveis de busca combinando código exato, código de barras e termos textuais na descrição com paginação obrigatória via `LIMIT` e `OFFSET`.

---

## User Stories

1. As a vendedor externo, I want to visualizar a descrição completa e correta de cada produto (`pro00_descri`), so that eu possa identificar com certeza a mercadoria durante a negociação.
2. As a vendedor externo, I want to ver o código interno (`pro00_codigo`) de cada item listado, so that eu possa digitar ou ditar o código rapidamente ao cliente.
3. As a vendedor externo, I want to visualizar a sigla oficial da unidade comercial (`pro00_unidad`), so that eu não cometa erros vendendo caixas como unidades avulsas ou vice-versa.
4. As a vendedor externo, I want to consultar o preço padrão de tabela (`pro00_pcomax`), so that eu apresente o valor oficial vigente definido pela retaguarda.
5. As a vendedor externo, I want to pesquisar produtos digitando ou bipando o código de barras EAN (`pro00_codbar`), so that a busca retorne instantaneamente o item correspondente.
6. As a vendedor externo, I want to ver o saldo de estoque físico (`pro00_qtdest`) estritamente correspondente à filial ativa da minha sessão (`ven00_codfil`), so that eu não venda itens sem saldo na unidade faturadora.
7. As a vendedor externo, I want que o aplicativo use o saldo de estoque geral de `cadpro00.pro00_qtdest` caso o produto não possua linha cadastrada em `estpro00` para a filial ativa, so that mercadorias sem segregação explícita continuem faturáveis.
8. As a vendedor externo, I want to buscar produtos digitando trechos parciais do nome ou descrição, so that mesmo sem saber a grafia completa eu localize o item desejado.
9. As a vendedor externo, I want to buscar produtos digitando o código exato, so that o sistema dê prioridade imediata ao produto correspondente.
10. As a vendedor externo, I want que a listagem de produtos responda de forma fluida através de paginação incremental com `LIMIT` e `OFFSET`, so that a rolagem não trave o aplicativo em aparelhos de menor processamento.
11. As a auditor de regras de negócio, I want que a consulta respeite o isolamento multi-filial gravado na sessão do representante (`cadrep00.ven00_codfil`), so that estoques de outras filiais não sejam misturados ou somados indevidamente.
12. As a integrador de sistemas, I want que valores nulos de estoque sejam convertidos com segurança para `0.0`, so that a interface gráfica e os cálculos matemáticos não sofram com exceções de parsing.

---

## Implementation Decisions

### 1. Estrutura Canônica da Instrução SQL (Protótipo Validado)
A instrução oficial para extração e pesquisa de produtos adota a seguinte forma estrutural:

```sql
SELECT 
    p.pro00_codigo AS codigo,
    p.pro00_descri AS descricao,
    COALESCE(p.pro00_unidad, 'UN') AS unidade,
    COALESCE(p.pro00_pcomax, 0.0) AS preco_maximo,
    COALESCE(p.pro00_codbar, '') AS codigo_barras,
    COALESCE(e.pro00_qtdest, p.pro00_qtdest, 0.0) AS saldo_estoque
FROM cadpro00 p
LEFT JOIN estpro00 e 
    ON (
        e.pro00_codpro = p.pro00_codigo 
        OR CAST(e.pro00_codpro AS INTEGER) = p.pro00_codigo
    )
    AND (
        e.pro00_codfil = :filialAtiva 
        OR CAST(e.pro00_codfil AS INTEGER) = CAST(:filialAtiva AS INTEGER)
    )
WHERE (
    :termo IS NULL OR :termo = '' OR
    p.pro00_codigo = :termoCodigo OR
    p.pro00_codbar = :termoCodbar OR
    UPPER(p.pro00_descri) LIKE :termoDescri
)
ORDER BY p.pro00_descri ASC, p.pro00_codigo ASC
LIMIT :limit OFFSET :offset;
```

*(Nota: O trecho acima foi refinado a partir do protótipo e dos testes de compatibilidade de tipos no SQLite local, garantindo tratamento resiliente tanto para `pro00_codpro`/`pro00_codfil` como `TEXT` com zeros à esquerda quanto como `INTEGER`).*

### 2. Mapeamento de Filial Ativa da Sessão
- A filial ativa de faturamento é extraída da sessão do usuário autenticado a partir de `cadrep00.ven00_codfil`.
- Em casos de representantes multi-filial (`cadrep00.ven00_selfil = 1`), a filial selecionada no modal pós-login é injetada no parâmetro `:filialAtiva`.
- Se a sessão não possuir filial informada, adota-se o fallback seguro `1`.

### 3. Tratamento de Fallback de Estoque
- Prioridade 1: Saldo específico da filial em `estpro00.pro00_qtdest`.
- Prioridade 2: Saldo geral de `cadpro00.pro00_qtdest` caso o `LEFT JOIN` com `estpro00` resulte em `NULL`.
- Prioridade 3: `0.0` absoluto via `COALESCE` caso ambas as colunas estejam nulas.

### 4. Paginação e Ordenação Estrita
- Cláusula de ordenação determinística: `ORDER BY p.pro00_descri ASC, p.pro00_codigo ASC`. A inclusão do código como critério de desempate previne saltos de itens ou registros duplicados entre páginas consecutivas.
- Cláusula de paginação: `LIMIT :limit OFFSET :offset`, onde `:limit` padroniza o tamanho do lote (ex: 20 a 50 itens) e `:offset` calcula o deslocamento da página.

### 5. Indexação Recomendada
Para garantir plano de execução ótimo sem `SCAN TABLE` completo na busca por texto e relacionamentos:
- Índice em `estpro00`: `CREATE INDEX IF NOT EXISTS idx_estpro00_fil_pro ON estpro00(pro00_codfil, pro00_codpro);`
- Índice em `cadpro00`: `CREATE INDEX IF NOT EXISTS idx_cadpro00_busca ON cadpro00(pro00_descri, pro00_codigo, pro00_codbar);`

---

## Testing Decisions

### O que constitui um bom teste
- Testar o comportamento externo da consulta e os dados retornados, sem acoplamento a implementações voláteis de widgets.
- Validar se a filial ativa filtra rigorosamente o saldo de `estpro00` sem vazamento entre filiais.
- Validar se a ausência de registro na filial em `estpro00` aciona o fallback para `cadpro00.pro00_qtdest`.
- Validar se a paginação com `LIMIT` e `OFFSET` particiona os resultados sem sobreposição e sem omissão de registros.
- Validar a busca por código exato, código de barras e descrição textual (case-insensitive).

### Módulos a serem testados
- Repositório / Ação de consulta de produtos do banco de dados SQLite local.
- Camada de serviço de busca e catálogo de produtos.

### Arte prévia no repositório
- `test/spec_047_multi_filial_estoque_test.dart` (cenários de multi-filial e fallback de estoque).
- `test/busca_produto_estoque_triage_test.dart` (testes de compatibilidade de tipos e zeros à esquerda).
- `test/performance_sqlite_busca_test.dart` (testes de paginação e índices no SQLite).

---

## Out of Scope

- Cálculo de abatimento de reservas de rascunhos em digitação (`pckvendig010` / `dig01`), escopo do módulo de carrinho/digitação.
- Regras fiscais e cálculo dinâmico de ICMS-ST por UF de destino.
- Validação de quantidade mínima e regras de combos/kits promocionais (`estdefcmb00`).
- Interface com leitor de código de barras por hardware ou câmera (apenas o critério de busca por `pro00_codbar` na consulta está no escopo).

---

## Further Notes

- A consulta foi desenhada para operar em modo somente leitura (`readOnly: true`) sobre o arquivo `dbforcacad001.db`, prevenindo qualquer bloqueio de concorrência com rotinas de digitação em segundo plano.
- As diretivas de PRAGMA (`PRAGMA cache_size = -64000` e `PRAGMA temp_store = MEMORY`) já adotadas no projeto devem ser preservadas nas conexões de catálogo para máxima velocidade de resposta.
