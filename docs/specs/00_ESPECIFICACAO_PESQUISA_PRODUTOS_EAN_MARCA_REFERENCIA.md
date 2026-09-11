# ESPECIFICAÇÃO TÉCNICA E REGRAS DE NEGÓCIO: PESQUISA E SELEÇÃO DE PRODUTOS (EAN, MARCA E REFERÊNCIA)

Este documento estabelece a especificação técnica detalhada e as regras de negócio para a atualização das telas de **Pesquisa de Produtos** e **Digitação de Pedidos de Vendas** no novo aplicativo em Flutter. A especificação orienta a incorporação e exibição obrigatória dos atributos **Código EAN (Código de Barras)**, **Marca** e **Referências (Refer.1 / Refer.2)** na consulta e no carrinho de compras, com base nas fontes legadas C++/Qt e no banco de dados SQLite local.

---

## 1. Visão Geral do Requisito e Justificativa de Negócio

Nas operações de Força de Vendas em campo, a localização rápida e inequívoca do produto é essencial para evitar erros de digitação e retrabalho no faturamento. 

A atualização da tela visa garantir que:
1. **Busca Multicritério:** O vendedor possa pesquisar produtos não apenas pela descrição, mas também bipando/digitando o **Código EAN (`pro00_codbar`)**, buscando pelo nome da **Marca (`mar00_descri`)** ou informando os códigos de **Referência do fabricante (`pro00_ref001` / `pro00_ref002`)**.
2. **Identificação Clara no Card:** Durante a rolagem do catálogo e na tela de digitação/carrinho (`dig01`), o card de cada produto exiba ostensivamente a Marca, a Referência e o EAN junto à descrição, foto, preço e estoque disponível.

---

## 2. Mapeamento e Rastreabilidade nos Fontes Legados C++/Qt

A auditoria dos arquivos fontes confirmou a presença e o suporte nativo a esses campos nas grades de exibição e estruturas de dados legadas:

| Atributo Comercial | Campo na Entidade C++ (`Tcadpro00` / `usysctr00.h`) | Coluna no Grid Legado (`ffrmdigvenliv00.cpp` / `ffrmdigvenmov07.cpp`) | Rótulo / Label no Legado |
| :--- | :--- | :--- | :--- |
| **Código EAN / Barras** | `pro00_codbar` (`QString`) | `c_prp00_probar` (Índice `15` / `12`) | `"Barras"` |
| **Marca** | `pro00_codmar` (`int`) ➔ `cadmar00` | `c_prp00_promar` (Índice `12`) | `"Marca"` |
| **Referência 1** | `pro00_ref001` (`QString`) | `c_prp00_ref001` (Índice `4` / `3`) | `"Refer.1"` |
| **Referência 2** | `pro00_ref002` (`QString`) | `c_prp00_ref002` (Índice `5` / `4`) | `"Refer.2"` |
| **Fabricante / Fornecedor**| `pro00_codfab` (`int`) ➔ `cadfor00` | `c_prp00_profab` (Índice `11` / `9`) | `"Fabricante"` |

---

## 3. Estrutura do Banco de Dados Local (SQLite)

Para viabilizar a busca reativa e a exibição completa, o repositório local em Flutter deve correlacionar as tabelas do banco de **Cadastros (`dbforcacad001.db`)** e do banco de **Digitação (`dbforcadig001.db`)**:

### A. Tabela de Produtos: `cadpro00` (em `dbforcacad001.db`)

```sql
CREATE TABLE cadpro00 (
    pro00_codigo   INTEGER PRIMARY KEY, -- Código interno do produto
    pro00_codbar   TEXT,                -- Código EAN / Código de Barras
    pro00_descri   TEXT,                -- Descrição comercial reduzida
    pro00_deslon   TEXT,                -- Descrição detalhada / longa
    pro00_codmar   INTEGER,             -- FK com cadmar00 (Código da Marca)
    pro00_codfab   INTEGER,             -- FK com cadfor00 (Código do Fabricante)
    pro00_ref001   TEXT,                -- Referência Comercial / Fábrica 1
    pro00_ref002   TEXT,                -- Referência Comercial / Fábrica 2
    pro00_embala   TEXT,                -- Embalagem (ex: CX 12, UN)
    pro00_unidad   TEXT,                -- Unidade de Medida (UN, CX, KG)
    pro00_qtdest   REAL,                -- Saldo em estoque físico
    pro00_codimg   INTEGER              -- ID da Imagem do produto
);
```

### B. Tabela de Marcas: `cadmar00` (em `dbforcacad001.db`)

```sql
CREATE TABLE cadmar00 (
    mar00_codigo   INTEGER PRIMARY KEY, -- Código da Marca
    mar00_descri   TEXT                 -- Nome/Descrição da Marca (ex: "Nestlé", "BAMBINO")
);
```

### C. Tabela de Fabricantes: `cadfor00` (em `dbforcacad001.db`)

```sql
CREATE TABLE cadfor00 (
    for00_codigo   INTEGER PRIMARY KEY, -- Código do Fabricante
    for00_descri   TEXT                 -- Nome do Fabricante/Fornecedor
);
```

### D. Tabela de Itens do Pedido: `dig01` (em `dbforcadig001.db`)

```sql
CREATE TABLE dig01 (
    dig01_digfil   INTEGER,             -- Filial
    dig01_digcod   INTEGER,             -- Código do Pedido
    dig01_digitm   INTEGER,             -- Sequencial do Item
    dig01_digpro   INTEGER,             -- FK com cadpro00 (pro00_codigo)
    dig01_digqtd   REAL,                -- Quantidade digitada
    dig01_digpco   REAL,                -- Preço unitário aplicado
    PRIMARY KEY (dig01_digfil, dig01_digcod, dig01_digitm)
);
```

---

## 4. Consultas SQL Reais para Busca Multifiltro Offline

A consulta de produtos no Flutter deve realizar o `LEFT JOIN` com `cadmar00` e `cadfor00` e permitir a busca dinâmica por qualquer um dos atributos:

```sql
SELECT 
    p.pro00_codigo   AS produto_id,
    p.pro00_descri   AS descricao,
    p.pro00_codbar   AS ean,
    COALESCE(m.mar00_descri, 'SEM MARCA') AS marca_nome,
    p.pro00_ref001   AS referencia_1,
    p.pro00_ref002   AS referencia_2,
    COALESCE(f.for00_descri, '')          AS fabricante_nome,
    p.pro00_embala   AS embalagem,
    p.pro00_unidad   AS unidade,
    p.pro00_qtdest   AS estoque_saldo,
    p.pro00_codimg   AS imagem_id
FROM cadpro00 p
LEFT JOIN cadmar00 m ON m.mar00_codigo = p.pro00_codmar
LEFT JOIN cadfor00 f ON f.for00_codigo = p.pro00_codfab
WHERE 
    (:query IS NULL OR :query = '' OR (
        p.pro00_descri LIKE '%' || :query || '%' OR
        p.pro00_codbar LIKE '%' || :query || '%' OR
        p.pro00_ref001 LIKE '%' || :query || '%' OR
        p.pro00_ref002 LIKE '%' || :query || '%' OR
        m.mar00_descri LIKE '%' || :query || '%'
    ))
ORDER BY p.pro00_descri ASC
LIMIT 100;
```

---

## 5. Implementação em Dart / Drift ORM (Flutter)

### A. Classe DTO de Produto Completo

```dart
class ProdutoLookupDTO {
  final int id;
  final String descricao;
  final String? ean;
  final String marca;
  final String? referencia1;
  final String? referencia2;
  final String? fabricante;
  final String embalagem;
  final String unidade;
  final double estoqueSaldo;
  final double precoTabela;
  final int? imagemId;

  ProdutoLookupDTO({
    required this.id,
    required this.descricao,
    this.ean,
    required this.marca,
    this.referencia1,
    this.referencia2,
    this.fabricante,
    required this.embalagem,
    required this.unidade,
    required this.estoqueSaldo,
    required this.precoTabela,
    this.imagemId,
  });

  /// Formatação legível da referência para exibição na UI
  String get referenciaFormatada {
    final refs = <String>[];
    if (referencia1 != null && referencia1!.trim().isNotEmpty) {
      refs.add(referencia1!.trim());
    }
    if (referencia2 != null && referencia2!.trim().isNotEmpty) {
      refs.add(referencia2!.trim());
    }
    return refs.isNotEmpty ? refs.join(' / ') : 'N/A';
  }
}
```

---

## 6. Diretrizes de UI/UX no Flutter

### A. Barra de Pesquisa Multifiltro
* **Campo de Busca Único (`TextField`):** Aceita digitação de nome, código interno, EAN, Marca ou Referência.
* **Leitor de Código de Barras (EAN):** Botão de câmera integrado na barra de busca para bipar a embalagem física do produto e preencher o campo de busca automaticamente.

### B. Layout do Card de Produto (Catálogo / Seleção)
Cada card da lista de produtos deve apresentar os atributos organizados hierarquicamente:

```
┌────────────────────────────────────────────────────────────────────────┐
  [ FOTO ]  01007 - BISCOITO WAFER CHOCOLATE 110G
            Marca: NESTLÉ  |  Ref: REF-7890-A
            EAN: 7891000241501
            Estoque: 142 UN  |  Emb: CX 24 UN
            ────────────────────────────────────────────────────────────
            R$ 4,85                                   [  -  1  +  ] [ADD]
└────────────────────────────────────────────────────────────────────────┘
```

### C. Exibição na Tela de Digitação e Carrinho (`dig01`)
Nos cards de itens adicionados ao pedido:
* Exibir um **badge/chip** destacando a **Marca** e a **Referência**.
* Exibir em texto secundário discreto o **EAN** para conferência no momento do carregamento ou entrega.
