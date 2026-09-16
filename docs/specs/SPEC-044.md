# SPEC-044: Correção do Carregamento do Extrato de Títulos e Remoção de Agente Prematuro

| Metadado | Detalhe |
| :--- | :--- |
| **Módulo** | Extrato do Cliente / Novo Pedido |
| **Arquivos Legados** | `ffrmextractcli00.cpp`, `ffrmrelrecdup02.h`, `cadcli00.h`, `caddup00.h` |
| **Tabelas** | `dup00`, `cadcli00` |
| **Status** | Correção Crítica |

---

## 1. Correções na Tela de Novo Pedido (Seleção de Cliente)

* **Problema:** A tela de Novo Pedido está exibindo um campo `"Agente: 501"` logo abaixo do cliente selecionado.
* **Causa:** O campo `cli00_codage` da tabela `cadcli00` está sendo renderizado no cabeçalho.
* **Ação Corretiva:** 
  * **Remover** o campo de agente cobrador da tela de abertura e seleção de cliente em Novo Pedido.
  * O Agente Cobrador (`dig00_digagt`) pertence exclusivamente à etapa de **Fechamento e Totais do Pedido** (`ffrmdigvenmov04`).

---

## 2. Correções na Tela de Extrato do Cliente (`dup00`)

### 2.1. Causa da Falha de Busca
1. O repositório está utilizando nome incorreto para a coluna de código do cliente ou aplicando filtros indevidos por vendedor logado.
2. Tratamento de data via SQLite (`DATE()` / `julianday()`) falha se o campo `dup00_datven` estiver gravado no formato brasileiro `DD/MM/YYYY`.

### 2.2. Query SQLite no Repositório Dart
A consulta deve buscar tanto por `dup00_clicod` quanto por `dup00_codcli` para cobrir o schema real da base `dbforcadig001.db`:

```sql
SELECT 
    dup00_codigo,
    dup00_datemi,
    dup00_datven,
    dup00_valori,
    dup00_valdev,
    dup00_valpag,
    COALESCE(dup00_valjur, 0.0) AS dup00_valjur,
    dup00_codven,
    dup00_codagt,
    dup00_codcob
FROM dup00
WHERE (
    CAST(COALESCE(dup00_clicod, dup00_codcli) AS INTEGER) = CAST(:codcli AS INTEGER)
)
AND COALESCE(dup00_valdev, dup00_valori) > 0;