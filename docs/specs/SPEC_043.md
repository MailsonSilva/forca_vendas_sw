# SPEC-043: Correção da Query e Exibição de Títulos na Tela de Extrato do Cliente

| Metadado | Detalhe |
| :--- | :--- |
| **Módulo** | Extrato do Cliente (`ExtratoDuplicatasWidget` / `consultarTitulos`) |
| **Origem Legada** | `ffrmextractcli00.cpp`, `ffrmextractcli00.h`, `ffrmrelrecdup02.cpp` |
| **Tabelas Envolvidas** | `dup00` (`caddup00`), `cadrep00`, `cadcli00` |
| **Status** | Pronto para Execução via TDD / Triagem |

---

## 1. Causa Raiz da Discrepância

Conforme evidenciado no comparativo entre o app legado e o app novo:
1. **Filtro de Data Excessivo (`dup00_datven < DATE('now')`):**
   * A query atual restringiu o carregamento exclusivamente a títulos já vencidos.
   * No legado (`ffrmextractcli00::consultarTitulos`), a listagem de títulos do cliente contempla **todos os títulos pendentes em aberto** (`dup00_valdev > 0`), incluindo títulos vincendos (a vencer), cujo campo `Dias/Atraso` é igual a zero.
2. **Incompatibilidade de Tipo em `dup00_codcli`:**
   * O código do cliente na tabela `dup00` pode estar tipado como numérico ou texto com inconsistência de preenchimento (`INTEGER` vs `VARCHAR`), falhando na igualdade estrita sem conversão explícita.
3. **Contador Zerado no Cabeçalho:**
   * Como a consulta retornou lista vazia, a aba do topo exibiu `Títulos (0)` e acionou o placeholder de lista vazia (`Nenhum título a receber`).

---

## 2. Dicionário de Dados do Extrato (`dup00`)

Mapeamento exato das colunas físicas conforme constantes do sistema legado (`c_dup00_*`):

| Campo na Grid / Interface | Coluna Física SQLite | Tipo | Regra Legada (`ffrmextractcli00` / `ffrmrelrecdup02`) |
| :--- | :--- | :--- | :--- |
| **Título** | `dup00_codigo` | TEXT | Identificador/duplicata (ex: `2098/2`, `2109/2`) |
| **Emissão** | `dup00_datemi` | TEXT | Data de emissão da parcela |
| **Vencimento** | `dup00_datven` | TEXT | Data de vencimento |
| **Valor** | `dup00_valori` | REAL | Valor nominal bruto original da duplicata |
| **Dias de Atraso** | *(Calculado)* | INTEGER | Se `dup00_datven < DataAtual` então `DataAtual - dup00_datven`, senão `0` |
| **Juros** | *(Calculado)* | REAL | Se vencido: `dup00_valdev * (ven00_txajur / 100) * dias_atraso`, senão `0.00` |
| **Devedor** | `dup00_valdev` | REAL | Saldo líquido pendente |
| **Recebido** | `dup00_valpag` | REAL | Valor já amortizado na retaguarda |
| **Vendedor** | `dup00_codven` | INTEGER | Código do vendedor emitente |
| **Agente Cobrador** | `dup00_codagt` | INTEGER | Código do agente cobrador vinculado |
| **Tipo de Cobrança** | `dup00_codcob` | INTEGER | Código da modalidade de cobrança (`T.Cob`) |

---

## 3. Query SQL Corrigida (SQLite Local)

A consulta ao repositório local de duplicatas (`dup00`) deve remover o filtro restritivo de data, sanitizar o código do cliente e calcular os juros e dias de atraso de forma condicional:

```sql
SELECT
    d.dup00_codigo AS titulo,
    d.dup00_datemi AS emissao,
    d.dup00_datven AS vencimento,
    d.dup00_valori AS valor_original,
    d.dup00_valdev AS saldo_devedor,
    d.dup00_valpag AS valor_recebido,
    d.dup00_codven AS vendedor,
    d.dup00_codagt AS agente_cobrador,
    d.dup00_codcob AS tipo_cobranca,
    CASE 
        WHEN DATE(d.dup00_datven) < DATE('now') 
        THEN CAST((julianday('now') - julianday(d.dup00_datven)) AS INTEGER)
        ELSE 0 
    END AS dias_atraso,
    CASE 
        WHEN DATE(d.dup00_datven) < DATE('now') 
        THEN ROUND(
            d.dup00_valdev * (COALESCE(r.ven00_txajur, 0.0) / 100.0) *
            CAST((julianday('now') - julianday(d.dup00_datven)) AS INTEGER), 2
        )
        ELSE 0.0 
    END AS valor_juros
FROM dup00 d
LEFT JOIN cadrep00 r ON r.ven00_codigo = d.dup00_codven
WHERE CAST(d.dup00_codcli AS INTEGER) = CAST(:codcli AS INTEGER)
  AND d.dup00_valdev > 0
ORDER BY d.dup00_datven ASC;
4. Totalizadores do Rodapé
Para conferência com o sistema legado:

Vencido: Somatório exclusivo das duplicatas vencidas (dup00_datven < DATE('now')). Na tela legada do cliente 48785: R$ 3.375,70.

Devedor: Somatório de todas as duplicatas em aberto (dup00_valdev > 0). Na tela legada do cliente 48785: R$ 5.940,92.

Limite Atual / Utilizado: R$ 1.190,12 (já mapeado no cabeçalho do app novo).

Limite Original: R$ 7.000,00 (já mapeado no cabeçalho do app novo).

5. Critérios de Aceite
[ ] A tela de Extrato do Cliente passa a listar tanto títulos vencidos quanto títulos a vencer que possuam saldo em aberto (dup00_valdev > 0).

[ ] Para títulos a vencer, Dias de Atraso e Juros devem ser exibidos como zero (0 e R$ 0,00).

[ ] Para títulos vencidos, o cálculo de diasAtrasado e juros deve ser dinâmico e refletir os valores da retaguarda.

[ ] O badge da aba superior deve refletir a contagem real dos registros retornados (ex: Títulos (11) para o cliente 48785).

[ ] Todos os valores monetários devem continuar utilizando o utilitário global .toMoeda().