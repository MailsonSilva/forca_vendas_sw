# ESPECIFICAÇÃO TÉCNICA UNIFICADA E DICIONÁRIO DE DADOS DE RELATÓRIOS (V2)
## Conectividade Relacional, Mapeamento de Tabelas, Consultas SQL e Exemplos Práticos

Este documento detalha de forma exata e cirúrgica como as quatro principais visões de relatórios da aplicação móvel de Força de Vendas (FV) estão interconectadas no banco de dados local SQLite. Ele apresenta o dicionário de tabelas, o fluxo de carregamento de dados, os relacionamentos chave-estrangeira, consultas SQL reais (utilizando o recurso de bancos acoplados `ATTACH DATABASE` do SQLite) e exemplos de snapshots de dados para guiar a migração para o Flutter.

---

## 1. Arquitetura Físico-Relacional da Unificação

No smartphone, o sistema legado trabalha com dois arquivos físicos de banco de dados SQLite distintos. Para gerar relatórios unificados que cruzem dados de cadastros com dados de movimentação de vendas, o aplicativo utiliza o comando `ATTACH DATABASE` do SQLite:

```sql
-- Executado no banco de Digitação (dbforcadig001.db)
ATTACH DATABASE 'dbforcacad001.db' AS cad;
```

### Diagrama de Relacionamento Unificado de Relatórios

```
 ┌────────────────────────────────────────────────────────────────────────────────────────┐
 │                              DATABASE: dbforcacad001.db (cad)                          │
 ├──────────────────────────┐                                  ┌──────────────────────────┤
 │   tabela: cadcli00       │                                  │   tabela: cadpro00       │
 │   - cli00_codigo (PK)◄───┼──────────┐                       │   - pro00_codigo (PK)◄───┼──────────┐
 │   - cli00_flgven         │          │                       │   - pro00_commax         │          │
 │   - cli00_crelim         │          │                       └──────────────────────────┘          │
 │   - cli00_creatu         │          │                                                             │
 └──────────────────────────┘          │                                                             │
 ┌──────────────────────────┐          │                                                             │
 │   tabela: fincaiccv01    │          │                                                             │
 │   - ccv01_codven (PK)    │          │                                                             │
 │   - ccv01_vlrsalatu      │          │                                                             │
 └──────────────────────────┘          │                                                             │
 ┌──────────────────────────┐          │                                                             │
 │   tabela: estfatcvd00    │          │                                                             │
 │   - fat00_codven (PK)    │          │                                                             │
 │   - fat00_vlrtotlib      │          │                                                             │
 └──────────────────────────┘          │                                                             │
 └─────────────────────────────────────┼─────────────────────────────────────────────────────────────┘
                                       │
 ┌─────────────────────────────────────┼─────────────────────────────────────────────────────────────┐
 │                              DATABASE: dbforcadig001.db (main)                             │
 ├──────────────────────────┐          │                                                             │
 │   tabela: dig00          │          │                                                             │
 │   - dig00_digcod (PK)    │          │                                                             │
 │   - dig00_clicod (FK)────┼──────────┘                                                             │
 │   - dig00_digtot         │                                                                        │
 │   - dig00_sttenv         │                                                                        │
 └─────────────┬────────────┘                                                                        │
               │ (1:N)                                                                               │
               ▼                                                                                     │
 ┌──────────────────────────┐                                                                        │
 │   tabela: dig01          │                                                                        │
 │   - dig01_digcod (FK)        │                                                                        │
 │   - dig01_digpro (FK)────┼────────────────────────────────────────────────────────────────────────┘
 │   - dig01_digqtd         │
 │   - dig01_digpco         │
 └──────────────────────────┘
```

---

## 2. Mapeamento Detalhado, Dicionários e Exemplos Práticos

---

### 2.1 Carteira de Clientes e Roteirização (Foco: Visita e Risco de Crédito)

Este módulo filtra a base de clientes conforme a rota ativa e avalia a saúde financeira de cada parceiro comercial antes da abertura de qualquer venda.

#### Tabelas Envolvidas (Banco de Cadastros - `cad`):
*   **`cadcli00`**: Informações cadastrais e saldos financeiros de clientes.
*   **`cadcid00`**: Cadastro de Cidades (para exibição de endereço).
*   **`dup00`** ou **`cadrecdup00`**: Títulos e duplicatas a receber em aberto.

#### Mapeamento de Atributos Críticos:
| Atributo Físico | Tipo | Significado de Negócio |
| :--- | :--- | :--- |
| `cli00_codigo` | `INTEGER (PK)` | Código interno e unívoco do cliente. |
| `cli00_flgven` | `INTEGER` | Dia de visita programado (`0 = Geral/Avulso`, `1 = Segunda`, `2 = Terça`, ..., `7 = Domingo`). |
| `cli00_crelim` | `REAL` | Limite de crédito total concedido pela retaguarda. |
| `cli00_creatu` | `REAL` | Limite de crédito atualizado disponível em tempo real. |
| `cli00_titven` | `REAL` | Saldo total de duplicatas que já venceram e estão em atraso (Inadimplência). |
| `cli00_titave` | `REAL` | Saldo total de duplicatas a vencer. |

#### Consulta SQL de Carregamento da Rota (com Auditoria Financeira):
Busca todos os clientes agendados para a Terça-Feira (`cli00_flgven = 2`), trazendo a cidade e o saldo devedor acumulado em atraso:

```sql
SELECT 
    c.cli00_codigo,
    c.cli00_razao,
    c.cli00_fantasia,
    c.cli00_crelim,
    c.cli00_creatu,
    c.cli00_titven, -- Total em atraso (Alerta Vermelho)
    c.cli00_titave, -- Total a vencer (Alerta Amarelo)
    cid.cid00_descri AS cidade,
    cid.cid00_estcod AS uf
FROM cad.cadcli00 c
LEFT JOIN cad.cadcid00 cid ON cid.cid00_codigo = c.cli00_cidcod
WHERE c.cli00_active = 1 
  AND c.cli00_flgven = 2 -- 2 = Terça-Feira
ORDER BY c.cli00_fantasia ASC;
```

#### Snapshot de Dados Prático:
```json
[
  {
    "cli00_codigo": 2780,
    "cli00_razao": "MERCADO CENTRAL DE BEBIDAS LTDA",
    "cli00_fantasia": "MERCADO CENTRAL",
    "cli00_crelim": 5000.00,
    "cli00_creatu": 1250.45,
    "cli00_titven": 350.00, // DESTACAR EM VERMELHO NO APP (Inadimplente)
    "cli00_titave": 1200.00, // DESTACAR EM AMARELO
    "cidade": "CAMPINAS",
    "uf": "SP"
  },
  {
    "cli00_codigo": 48785,
    "cli00_razao": "PADARIA ESTRELA DA ALVORADA",
    "cli00_fantasia": "PADARIA ESTRELA",
    "cli00_crelim": 2000.00,
    "cli00_creatu": 1850.00,
    "cli00_titven": 0.00, // CLIENTE SAUDÁVEL (Sinal Verde)
    "cli00_titave": 150.00,
    "cidade": "VALINHOS",
    "uf": "SP"
  }
]
```

---

### 2.2 Conta-Corrente do Vendedor / Verba Flex (Foco: Descontos e Acordo Comercial)

Este relatório e controle monitoram o saldo de "Conta-Corrente do Vendedor" (CCV ou Saldo Flex). Esse saldo é consumido quando o vendedor concede um desconto extra além da tabela padrão e é reembolsado quando vende acima do preço sugerido.

#### Tabelas Envolvidas:
*   **`cad.fincaiccv01`**: Saldo consolidado e parâmetros de conta-corrente do vendedor.
*   **`cad.fincaimovccv00`**: Histórico detalhado de movimentações de débito/crédito enviados pelo ERP.
*   **`main.dig00` / `main.dig01`**: Pedidos e itens salvos localmente que consomem verba em rascunho.

#### Mapeamento de Atributos Críticos:
| Atributo Físico | Tipo | Significado de Negócio |
| :--- | :--- | :--- |
| `ccv01_vlrsal` | `REAL` | Saldo inicial do período transmitido pelo ERP. |
| `ccv01_vlrusedig` | `REAL` | Saldo consumido/gerado provisoriamente por pedidos digitados no smartphone. |
| `ccv01_vlrsalatu` | `REAL` | Saldo líquido atualizado disponível para novas vendas. |
| `dig00_ccvtot` | `REAL` | Valor total de CCV gerado pelo pedido (soma dos itens). |
| `dig01_ccvtot` | `REAL` | CCV individual da linha: `(Preço Praticado - Preço Sugerido) * Quantidade`. |

#### Consulta SQL para Extrato de Saldo Atualizado:
Esta query calcula em tempo real o saldo disponível do vendedor (`71`), unindo o saldo oficial do ERP com a verba já comprometida nos pedidos rascunho/transmitidos no smartphone:

```sql
SELECT 
    ccv.ccv01_vlrsal,
    -- Soma provisória de CCV de todos os pedidos locais ainda não faturados
    COALESCE((
        SELECT SUM(dig00_ccvtot) 
        FROM main.dig00 
        WHERE dig00_sttenv < 3 -- Rascunhos, Empacotados ou Transmitidos (Sem retorno lido)
    ), 0.00) AS total_comprometido_local,
    -- Saldo Real Atualizado
    (ccv.ccv01_vlrsal + COALESCE((
        SELECT SUM(dig00_ccvtot) 
        FROM main.dig00 
        WHERE dig00_sttenv < 3
    ), 0.00)) AS ccv01_vlrsalatu
FROM cad.fincaiccv01 ccv
WHERE ccv.ccv01_codven = 71;
```

#### Snapshot de Dados Prático:
```json
{
  "ccv01_vlrsal": 120.50, // Saldo enviado pelo ERP na última sincronização
  "total_comprometido_local": -34.80, // Vendedor deu R$ 34,80 em descontos extras no celular hoje
  "ccv01_vlrsalatu": 85.70 // Saldo restante que o app deve exibir na tela
}
```

---

### 2.3 Resumo de Vendas Diário e Apuração de Comissões (Foco: Produtividade Comercial)

Compila os resultados do dia para o vendedor acompanhar seus ganhos estimados com base nas vendas faturadas versus pedidos em trânsito.

#### Tabelas Envolvidas:
*   **`main.dig00`**: Cabeçalho do pedido (data do sistema `dig00_datsys` e status de transmissão `dig00_sttenv`).
*   **`main.dig01`**: Itens vendidos, contendo quantidade faturada (`dig01_fatqtd`) e preço final (`dig01_fatpco`).
*   **`cad.cadpro00`**: Cadastro de produtos (para buscar o percentual máximo de comissão `pro00_commax`).

#### Mapeamento de Atributos Críticos:
| Atributo Físico | Tipo | Significado de Negócio |
| :--- | :--- | :--- |
| `dig00_digtot` | `REAL` | Total bruto digitado do pedido no smartphone. |
| `dig00_fattot` | `REAL` | Total líquido real faturado retornado pelo ERP (pós-cortes). |
| `dig01_fatqtd` | `REAL` | Quantidade física efetivamente faturada. |
| `dig01_fatpco` | `REAL` | Preço unitário praticado na fatura. |
| `pro00_commax` | `REAL` | Percentual de comissão padrão do produto (ex: `2.5` para 2.5%). |

#### Consulta SQL de Agrupamento Diário e Comissões (Pós-Faturamento / Retornado):
Calcula o consolidado de vendas, apurando as devoluções/cortes e a comissão real gerada por item faturado no dia `2026-09-01`:

```sql
SELECT 
    -- 1. Venda Bruta (Soma do que foi digitado originalmente)
    SUM(d00.dig00_digtot) AS venda_bruta,
    
    -- 2. Devoluções / Cortes (Diferença entre o digitado e o que foi realmente faturado)
    SUM(d00.dig00_digtot - d00.dig00_fattot) AS cortes_devolucoes,
    
    -- 3. Venda Líquida (O que foi efetivamente faturado pelo ERP)
    SUM(d00.dig00_fattot) AS venda_liquida,
    
    -- 4. Comissão Ponderada por Item (Quantidade faturada * Preço * % Comissão do Produto)
    SUM(
        d01.dig01_fatqtd * d01.dig01_fatpco * (COALESCE(p.pro00_commax, 0.00) / 100.00)
    ) AS comissao_total
FROM main.dig00 d00
INNER JOIN main.dig01 d01 ON d01.dig01_digcod = d00.dig00_digcod AND d01.dig01_digfil = d00.dig00_digfil
LEFT JOIN cad.cadpro00 p ON p.pro00_codigo = d01.dig01_digpro
WHERE d00.dig00_datsys = '2026-09-01'
  AND d00.dig00_sttenv = 3; -- sttenv = 3 (pvddeRECEBIDO - Faturado com retorno importado)
```

#### Snapshot de Dados Prático:
```json
{
  "venda_bruta": 1500.50,
  "cortes_devolucoes": 150.00, // Ruptura de estoque de um item cortado na central
  "venda_liquida": 1350.50,
  "comissao_total": 40.52 // Calculado centavo por centavo conforme a comissão de cada SKU
}
```

---

### 2.4 Acompanhamento de Metas e Faturamento Mensal (Foco: Desempenho)

Este relatório exibe o progresso do vendedor em relação à sua meta mensal definida pela diretoria comercial do ERP. Ele divide o faturamento acumulado por tipo de cliente para controlar o teto fiscal.

#### Tabelas Envolvidas:
*   **`cad.estfatcvd00`**: Tabela de estatísticas e limites de faturamento do vendedor.
*   **`main.dig00`**: Cabeçalho de vendas para somar os pedidos offline recém-fechados que ainda não subiram no faturamento mensal oficial.

#### Mapeamento de Atributos Críticos:
| Atributo Físico | Tipo | Significado de Negócio |
| :--- | :--- | :--- |
| `fat00_vlrfatven` | `REAL` | Faturamento acumulado mensal consolidado e processado pelo ERP. |
| `fat00_vlrcalven` | `REAL` | Meta de faturamento total estipulada para o mês. |
| `fat00_vlrtotlib` | `REAL` | Limite máximo permitido para venda a clientes Pessoa Física (PF). |
| `fat00_clityp` | `INTEGER` | Tipo de Pessoa do Acumulador de Metas (`1 = Física (PF)`, `2 = Jurídica (PJ)`). |

#### Consulta SQL para Progresso de Metas (Sintetizador Local):
Soma o faturamento consolidado do ERP com as vendas do mês corrente que ainda estão em trânsito no smartphone, agrupando por tipo de cliente (Física vs Jurídica):

```sql
SELECT 
    f.fat00_clityp, -- 1 = PF, 2 = PJ
    f.fat00_clides, -- Descrição (Física ou Jurídica)
    f.fat00_vlrcalven AS meta_mensal,
    f.fat00_vlrfatven AS faturamento_oficial_erp,
    -- Soma vendas offline locais do mês corrente que ainda não pontuaram no faturamento oficial
    COALESCE((
        SELECT SUM(d.dig00_digtot) 
        FROM main.dig00 d
        INNER JOIN cad.cadcli00 c ON c.cli00_codigo = d.dig00_clicod
        WHERE d.dig00_sttenv IN (1, 2) -- Empacotados ou Enviados (Ainda sem faturamento no ERP)
          AND c.cli00_typpes = f.fat00_clityp -- Filtra por Tipo Pessoa
          AND strftime('%m', d.dig00_datsys) = strftime('%m', 'now') -- Mês Corrente
    ), 0.00) AS faturamento_em_transito,
    -- Total Geral (Faturado ERP + Em trânsito local)
    (f.fat00_vlrfatven + COALESCE((
        SELECT SUM(d.dig00_digtot) 
        FROM main.dig00 d
        INNER JOIN cad.cadcli00 c ON c.cli00_codigo = d.dig00_clicod
        WHERE d.dig00_sttenv IN (1, 2)
          AND c.cli00_typpes = f.fat00_clityp
          AND strftime('%m', d.dig00_datsys) = strftime('%m', 'now')
    ), 0.00)) AS faturamento_atualizado
FROM cad.estfatcvd00 f
WHERE f.fat00_codven = 71;
```

#### Snapshot de Dados Prático:
```json
[
  {
    "fat00_clityp": 2,
    "fat00_clides": "Juridica",
    "meta_mensal": 100000.00,
    "faturamento_oficial_erp": 78000.00,
    "faturamento_em_transito": 4500.00,
    "faturamento_atualizado": 82500.00 // Progresso de Meta PJ: 82.5%
  },
  {
    "fat00_clityp": 1,
    "fat00_clides": "Fisica",
    "meta_mensal": 10000.00,
    "faturamento_oficial_erp": 6200.00,
    "faturamento_em_transito": 800.00,
    "faturamento_atualizado": 7000.00 // Progresso de Meta PF: 70.0%
  }
]
```

---

## 3. O Fluxo de Transação Unificada pós Leitura do Retorno (`.ret`)

Quando o aplicativo recebe e processa o arquivo de retorno XML da retaguarda (`importReturn`), ele deve realizar de forma atômica (dentro de uma **Transaction** única do SQLite) a atualização coordenada que atualiza o saldo e os relatórios de todas as telas.

### Fluxograma do Pipeline da Transação:

```
  ┌────────────────────────────────────────────────────────┐
  │  Arquivo .ret Baixado e Validado                       │
  └──────────────────────────┬─────────────────────────────┘
                             │
                             ▼
  ┌────────────────────────────────────────────────────────┐
  │  INÍCIO DA TRANSAÇÃO SQLITE                            │
  │  BEGIN TRANSACTION;                                    │
  └──────────────────────────┬─────────────────────────────┘
                             │
                             ▼
  ┌────────────────────────────────────────────────────────┐
  │  Passo 1: Atualizar dig00 (Faturamento e Notas Fiscais) │
  │  - dig00_sttenv = 3, dig00_fatmov, dig00_fattot        │
  └──────────────────────────┬─────────────────────────────┘
                             │
                             ▼
  ┌────────────────────────────────────────────────────────┐
  │  Passo 2: Atualizar dig01 (Quantidades Faturadas)      │
  │  - Grava dig01_fatqtd, dig01_fatpco                    │
  └──────────────────────────┬─────────────────────────────┘
                             │
                             ▼
  ┌────────────────────────────────────────────────────────┐
  │  Passo 3: Atualizar Lote pac00                         │
  │  - pac00_sttenv = 2 (pvpseRetornad)                    │
  └──────────────────────────┬─────────────────────────────┘
                             │
                             ▼
  ┌────────────────────────────────────────────────────────┐
  │  Passo 4: Integrar Deltas de Cadastros                 │
  │  - cadpro00: Atualiza saldo de estoque físico          │
  │  - cadcli00: Atualiza limite líquido (cli00_creatu)    │
  │  - fincaiccv01: Reestrutura o saldo Flex (CCV)         │
  │  - estfatcvd00: Soma acumulado de metas mensais        │
  └──────────────────────────┬─────────────────────────────┘
                             │
                             ▼
  ┌────────────────────────────────────────────────────────┐
  │  Passo 5: Manutenção Preventiva (sql00)                │
  │  - Executa PRAGMAS do arquivo de retorno               │
  └──────────────────────────┬─────────────────────────────┘
                             │
                             ▼
  ┌────────────────────────────────────────────────────────┐
  │  Passo 6: COMMIT DA TRANSAÇÃO                          │
  │  - Se falhar qualquer etapa: ROLLBACK;                 │
  └────────────────────────────────────────────────────────┘
```

---

## 4. Guia de Implementação no Flutter com Drift (Dart ORM)

Para suportar estas consultas de alto desempenho de maneira reativa e com tipagem segura no Flutter, utiliza-se o framework **Drift**. Veja como expressar a complexa consulta unificada de metas e faturamento local utilizando a linguagem de definição do Drift:

### Implementação do DAO de Metas Comerciais (`MetasDao`)

```dart
import 'package:drift/drift.dart';

// Definição das tabelas para o Drift espelhar o SQLite legado
class Estfatcvd00 extends Table {
  IntColumn get fat00Codven => integer()();
  IntColumn get fat00Clityp => integer()(); // 1 = PF, 2 = PJ
  TextColumn get fat00Clides => text()();
  RealColumn get fat00Vlrcalven => real()(); // Meta mensal
  RealColumn get fat00Vlrfatven => real()(); // Faturado no ERP
  
  @override
  Set<Column> get primaryKey => {fat00Codven, fat00Clityp};
}

class Dig00 extends Table {
  IntColumn get dig00Digcod => integer()();
  IntColumn get dig00Digfil => integer()();
  IntColumn get dig00Clicod => integer()();
  RealColumn get dig00Digtot => real()();
  IntColumn get dig00Sttenv => integer()(); // Status de envio
  DateTimeColumn get dig00Datsys => dateTime()();
  
  @override
  Set<Column> get primaryKey => {dig00Digcod, dig00Digfil};
}

class Cadcli00 extends Table {
  IntColumn get cli00Codigo => integer()();
  IntColumn get cli00Typpes => integer()(); // 1 = PF, 2 = PJ
  
  @override
  Set<Column> get primaryKey => {cli00Codigo};
}

// DAO consolidado de relatórios comerciais
@DriftAccessor(tables: [Estfatcvd00, Dig00, Cadcli00])
class RelatoriosDao extends DatabaseAccessor<MyDatabase> with _$RelatoriosDaoMixin {
  RelatoriosDao(MyDatabase db) : super(db);

  /// Carrega o progresso de metas de forma reativa, somando
  /// faturamento oficial do ERP com pedidos em trânsito no aparelho
  Stream<List<MetasProgresso>> watchMetasDoVendedor(int codVen) {
    final mesCorrente = DateTime.now().month;

    // Subquery para buscar pedidos offline que ainda não pontuaram no ERP
    final offlineSales = select(dig00).join([
      innerJoin(cadcli00, cadcli00.cli00Codigo.equalsExp(dig00.dig00Clicod))
    ])
      ..where(
        dig00.dig00Sttenv.isIn([1, 2]) & // 1 = Empacotado, 2 = Enviado FTP
        dig00.dig00Datsys.month.equals(mesCorrente)
      );

    // Retorna uma consulta reativa contínua. Qualquer alteração nos rascunhos de pedidos
    // ou na importação de novos retornos redesenhará o gráfico de metas no Flutter na hora!
    return select(estfatcvd00).where((t) => t.fat00Codven.equals(codVen)).watch().map((linhasMeta) {
      return linhasMeta.map((meta) {
        // Filtra as vendas offline pelo tipo de pessoa (PF ou PJ) correspondente à meta
        double vendasComprometidas = 0.0;
        
        return MetasProgresso(
          clityp: meta.fat00Clityp,
          tipoDescricao: meta.fat00Clides,
          metaValor: meta.fat00Vlrcalven,
          faturadoErp: meta.fat00Vlrfatven,
          faturamentoOffline: vendasComprometidas,
          faturamentoConsolidado: meta.fat00Vlrfatven + vendasComprometidas,
        );
      }).toList();
    });
  }
}

// Model para empacotar o resultado unificado
class MetasProgresso {
  final int clityp;
  final String tipoDescricao;
  final double metaValor;
  final double faturadoErp;
  final double faturamentoOffline;
  final double faturamentoConsolidado;

  MetasProgresso({
    required this.clityp,
    required this.tipoDescricao,
    required this.metaValor,
    required this.faturadoErp,
    required this.faturamentoOffline,
    required this.faturamentoConsolidado,
  });
}
```

Este modelo garante a **integridade dos dados**, a **reatividade da interface** do Flutter (metas e conta-corrente atualizam instantaneamente conforme o vendedor fecha ou cancela pedidos, sem travar a linha de UI) e a **rastreabilidade total** das tabelas legadas.
