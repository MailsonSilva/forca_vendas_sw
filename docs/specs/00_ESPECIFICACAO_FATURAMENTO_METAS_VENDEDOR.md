# ESPECIFICAÇÃO TÉCNICA E REGRAS DE NEGÓCIO: RELATÓRIO DE FATURAMENTO E METAS
## Módulo de Produtividade, Acompanhamento de Metas Mensais e Desempenho (ffrmrelfatcvd00 / relestfatcvd00)

Esta especificação técnica detalha o funcionamento, as regras de faturamento, a sintetização de dados, as tabelas SQLite locais e o ciclo de vida operacional do **Relatório de Faturamento e Acompanhamento de Metas do Vendedor** (`ffrmrelfatcvd00`). O objetivo deste documento é guiar a equipe de engenharia na migração reativa e offline-first para o Flutter.

---

## 1. Visão Geral e Regras de Negócio do Relatório

O relatório de faturamento e metas é uma ferramenta de gestão em campo que permite ao representante comercial analisar em tempo real seu desempenho de vendas contra as cotas/metas comerciais estipuladas pela retaguarda (ERP) para o mês vigente.

### 1.1 Regras de Negócio Centrais:
1. **Sincronização Atômica via Retorno (ERP ➔ App):** As metas originais e o acumulado de faturamento já processados pela central são transmitidos para o smartphone através do arquivo de retorno (**`.ret`**) no bloco `<fat00>`, populando as tabelas locais de metas.
2. **Sintetização Provisória Local:** Para fornecer o atingimento de metas real em campo, o aplicativo FV realiza uma consolidação matemática que soma as vendas oficiais já faturadas no ERP com os pedidos que o vendedor emitiu localmente no aparelho, mas que ainda não foram integrados ou faturados centralmente.
3. **Isolamento de Pessoas (Física vs. Jurídica):** As cotas, limites e vendas são estritamente separadas entre Pessoa Física (`clityp = 1`) e Pessoa Jurídica (`clityp = 2`). Essa divisão é crucial porque o faturamento para pessoas físicas possui tetos tributários e limites de cotas operacionais rígidos (`fat00_vlrtotlib`).
4. **Alerta de Venda de Pessoa Física (`getPEDTOTPessoaFisicaCheck`):** Toda vez que o vendedor tenta incluir itens em um pedido de Pessoa Física, o motor fiscal (`Tsysvenfun00`) consulta o limite liberado em `fat00_vlrtotlib` para garantir que o acumulado de vendas do mês não estoure o limite legal de faturamento autorizado para PF, emitindo alertas visuais ou bloqueando a digitação.

---

## 2. O Mecanismo de Sintetização Local (`ett_sintetize_ESTFATCVD00`)

O sistema legado utiliza a classe estática de sintetização **`Tsysett`** (declarada em `usysett.h` e implementada em `usysett.cpp`) para fundir dados estáticos sincronizados da retaguarda com os dados dinâmicos do carrinho local.

Ao abrir a tela de metas (`dodataload()`), o sistema dispara:
```cpp
Tsysett::ett_sintetize_ESTFATCVD00(filial, representante, 0);
```

### Algoritmo Matemático de Consolidação

Para cada segmento de pessoa (Física e Jurídica), o sistema calcula:

1. **Faturamento ERP Oficial (`fat00_vlrfatven`):**
   * Sincronizado diretamente do ERP via arquivo de retorno. Representa os pedidos faturados na retaguarda.
2. **Total Digitado e em Trânsito (`fat00_vlrdigven`):**
   * Obtido por uma query local de agregação na tabela de digitação de pedidos do aparelho (`dig00`):
     $$\text{fat00\_vlrdigven} = \sum (\text{dig00\_digtot}) \quad \text{onde } \text{dig00\_sttenv} \in \{1 \text{ (Empacotado)}, 2 \text{ (Enviado)}\}$$
3. **Total Digitado Local (Carrinho Aberto/Andamento) (`fat00_vlrdigloc`):**
   * Agregação de pedidos salvos localmente que ainda não foram para a fila de envio:
     $$\text{fat00\_vlrdigloc} = \sum (\text{dig00\_digtot}) \quad \text{onde } \text{dig00\_sttenv} = 0 \text{ (Digitado Local)}$$
4. **Valor Total de Vendas Consolidado (`fat00_vlrtotven`):**
   * Soma de todo o esforço comercial do representante no período:
     $$\text{fat00\_vlrtotven} = \text{fat00\_vlrfatven (Faturado ERP)} + \text{fat00\_vlrdigven (Enviado)} + \text{fat00\_vlrdigloc (Rascunho)}$$
5. **Percentual de Atingimento da Meta (`fat00_vlrtotper`):**
   * Confronto do total consolidado contra a meta calculada pela retaguarda (`fat00_vlrcalven`):
     $$\text{fat00\_vlrtotper} = \left( \frac{\text{fat00\_vlrtotven}}{\text{fat00\_vlrcalven}} \right) \times 100$$
6. **Limite de Pessoa Física Restante:**
   * Margem que governa a trava de novas vendas para PF:
     $$\text{Limite Restante PF} = \text{fat00\_vlrtotlib} - \text{fat00\_vlrtotven (PF)}$$

---

## 3. Dicionário de Dados das Tabelas SQLite

Os dados compilados e os deltas recebidos no arquivo `.ret` residem na tabela **`relestfatcvd00`** (ou `estfatcvd00`) mapeada no SQLite transacional local (`dbforcadig001.db`).

### Tabela: `relestfatcvd00` (Resultados de Metas do Vendedor)
* **Finalidade:** Armazena as cotas de vendas e os acumulados faturados no ERP, servindo de base para a consolidação.
* **Chave Primária:** `fat00_codfil`, `fat00_codven`, `fat00_clityp`

| Campo no SQLite | Tipo | Chave | Finalidade Comercial / Regra de Negócio |
| :--- | :--- | :--- | :--- |
| `fat00_codfil` | INTEGER | PK | Código da filial faturadora associada à cota. |
| `fat00_codven` | INTEGER | PK | Código de identificação do representante (`cadrep00.ven00_codigo`). |
| `fat00_clityp` | INTEGER | PK | Código do Tipo de Pessoa (`1` = Pessoa Física, `2` = Pessoa Jurídica). |
| `fat00_clides` | TEXT | - | Descrição textual do tipo de cliente (*"Fisica"*, *"Juridica"*). |
| `fat00_vlrperfat` | REAL | - | Percentual padrão de comissão/faturamento base. |
| `fat00_vlrfatven` | REAL | - | Valor nominal faturado na central ERP (Sincronizado via `.ret`). |
| `fat00_vlrdigven` | REAL | - | Valor acumulado de pedidos enviados e pendentes de faturamento no ERP. |
| `fat00_vlrdigloc` | REAL | - | Valor acumulado de pedidos locais (rascunhos salvos no celular). |
| `fat00_vlrtotven` | REAL | - | Valor total de faturamento consolidado (Faturado + Digitados). |
| `fat00_vlrcalven` | REAL | - | **Cota de Vendas:** Cota financeira mensal estipulada para o vendedor. |
| `fat00_vlrtotper` | REAL | - | Percentual total atingido em relação à meta calculada. |
| `fat00_vlrtotlib` | REAL | - | **Limite PF:** Limite máximo de faturamento autorizado para Pessoa Física no mês. |
| `fat00_datmov` | DATE | - | Data de referência do movimento financeiro. |

---

## 4. Estrutura de UI/UX do Relatório Legado (`ffrmrelfatcvd00`)

Na arquitetura C++/Qt, a tela é composta por duas grades principais alimentadas reativamente por consultas SQLite:

```
┌────────────────────────────────────────────────────────┐
│           ACOMPANHAMENTO DE FATURAMENTO E METAS        │
├────────────────────────────────────────────────────────┤
│ REPRESENTANTE: 71 - VENDEDOR EXEMPLO                   │
├────────────────────────────────────────────────────────┤
│ Segmento  | Vl. Meta   | Vl. Realizado | % Atingido    │
│ Jurídica  | 50.000,00  | 35.420,00     | 70,84%        │
│ Física    | 10.000,00  |  8.250,00     | 82,50%        │
├────────────────────────────────────────────────────────┤
│ [Aba de Detalhamento por Notas Fiscais Emitidas (ERP)] │
│ Nota Fiscal | Data Fat.   | Cliente     | Vl. Faturado │
│ 4677834     | 2026-09-01  | Cli 2780    | 191,16       │
│ 4677835     | 2026-09-01  | Cli 3302    |  23,88       │
├────────────────────────────────────────────────────────┤
│                                        [ Voltar ]      │
└────────────────────────────────────────────────────────┘
```

1. **Grade Superior de Cotas (`dodataloadgrid1`):**
   * Exibe as duas colunas consolidadas (Física e Jurídica).
   * Destaca as colunas: Nome do Segmento, Valor da Meta (`vlrcalven`), Valor Realizado Consolidado (`vlrtotven`) e o Percentual Final Atingido (`vlrtotper`).
2. **Grade Inferior de Detalhamento (`dodataloadgrid2` / `cgridmov`):**
   * Lista analítica de todos os pedidos locais aprovados e notas fiscais integradas no mês, servindo como base de conferência para a auditoria do vendedor em campo.

---

## 5. Diretrizes de Migração e Implementação no Flutter

Para garantir uma interface de alta performance e totalmente integrada às regras de negócio offline-first, a nova arquitetura em Flutter deve respeitar as seguintes diretrizes:

### 5.1 Reatividade de Estado com BLoC/Cubit:
* A tela de metas não deve depender exclusivamente de conexões ou sincronizações. Sempre que um pedido for salvo ou faturado localmente, a gerência de estado (BLoC/Cubit) deve re-executar a query de sintetização e redesenhar os gráficos de barra de metas instantaneamente.
* **Componentes Gráficos (Progress Bars):** Substituir as grades estáticas do Qt por indicadores visuais circulares ou de barra de progresso (LinearProgressIndicator) que mudam de cor dinamicamente (ex: Vermelho para abaixo de 50%, Amarelo para 50%-99%, e Verde para metas batidas >= 100%).

### 5.2 Modelagem de Dados e Queries Reativas (Drift / SQLite):
A query do Drift (ou Sqflite) para renderizar a tela de faturamento e metas deve consolidar os dados delta do ERP com o banco transacional local em uma única transação atômica:

```sql
-- Query reativa de sintetização de faturamento e metas
SELECT 
    f.fat00_clides AS segmento,
    f.fat00_vlrcalven AS valor_meta,
    f.fat00_vlrtotlib AS limite_pf,
    f.fat00_vlrfatven AS faturado_erp,
    -- Soma provisória de pedidos locais fechados em trânsito
    COALESCE((
        SELECT SUM(dig00_digtot) 
        FROM dig00 
        INNER JOIN cadcli00 ON cli00_codigo = dig00_clicod
        WHERE cli00_typpes = f.fat00_clityp 
          AND dig00_sttenv IN (1, 2)
    ), 0.0) AS digitado_transito,
    -- Soma provisória de carrinhos salvos localmente
    COALESCE((
        SELECT SUM(dig00_digtot) 
        FROM dig00 
        INNER JOIN cadcli00 ON cli00_codigo = dig00_clicod
        WHERE cli00_typpes = f.fat00_clityp 
          AND dig00_sttenv = 0
    ), 0.0) AS rascunho_local
FROM relestfatcvd00 f
WHERE f.fat00_codven = :codigoVendedor;
```

### 5.3 Otimização Offline-First:
* Se a retaguarda demorar para responder ou o vendedor estiver sem conectividade na rua, a tela de faturamento continuará funcionando de forma autônoma e consistente, refletindo perfeitamente os rascunhos e vendas digitadas localmente no aparelho do vendedor.
