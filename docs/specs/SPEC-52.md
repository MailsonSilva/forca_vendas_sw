SPEC-052: Carregamento Otimizado do Catálogo e Detalhes do Produto (Fiel ao Legado usysctr00)MetadadoDetalheMóduloCatálogo / Produtos (cadpro00 e relacionamentos)Origem Legadausysctr00.h, usysctr00.cpp (Tcadpro00::cload), ffrmrelconpro01   Padrão ArquiteturalMaster-Detail lazy loading (Listagem leve / Detalhe sob demanda)StatusPronto para Implementação1. Visão Geral e ContextoO carregamento de produtos foi desmembrado em duas etapas para garantir resposta instantânea na listagem (eliminando gargalo de CPU/memória no SQLite móvel) e fidelidade aos dados cadastrais e de estoque do sistema legado:Query Leve (Card da Pesquisa / Catálogo): Carrega estritamente as colunas necessárias para renderizar a lista/card de pesquisa com paginação rápida (LIMIT 100 OFFSET :offset), consultando apenas cadpro00 e calculando o saldo físico da filial ativa via estpro00.   Query Completa (Detalhe do Produto / Clique no Card): Executa o cload fiel ao método Tcadpro00::cload(idcodfind) de usysctr00.cpp trazendo todas as amarrações relacionais (cadpro02, cadprofra00, cadprobon00, cadproemb00, estprodat00 e estpro00) apenas para o item selecionado.   2. Modelagem e Consultas SQL2.1. Query 1: Card de Pesquisa / Listagem LeveFinalidade: Alimentar a grid/lista de produtos na pesquisa.Parâmetros::filialAtiva: Filial da sessão do vendedor (cadrep00.ven00_codfil).:termo: Termo de pesquisa digitado (nulo caso não haja busca ativa).:offset: Ponto de início da paginação (incrementado de 100 em 100).SQLSELECT 
    p.pro00_codigo,
    p.pro00_descri,
    p.pro00_unidad,
    p.pro00_codbar,
    p.pro00_codimg,
    COALESCE(e.pro00_qtdest - e.pro00_qtdpen, 0) AS pro00_qtdest
FROM cadpro00 p
LEFT JOIN estpro00 e 
       ON e.pro00_codpro = p.pro00_codigo 
      AND e.pro00_codfil = :filialAtiva
WHERE (:termo IS NULL 
       OR p.pro00_descri LIKE '%' || :termo || '%' 
       OR p.pro00_codigo LIKE '%' || :termo || '%'
       OR p.pro00_codbar LIKE '%' || :termo || '%')
ORDER BY p.pro00_descri ASC
LIMIT 100 OFFSET :offset;
(Performance: Não realiza JOINs nas tabelas de bonificação, fracionamento ou histórico de datas na listagem).   2.2. Query 2: Detalhes Completos do Produto (Ao Clicar no Card)Finalidade: Ficha completa de dados e regras de negócio para a tela de detalhes ou abertura de inclusão no pedido.   Origem: Baseada no trecho original Tcadpro00::cload de usysctr00.cpp.   Parâmetros::codpro: Código interno do produto selecionado (idcodfind).   :filialAtiva: Filial da sessão (cadrep00.ven00_codfil).   SQLSELECT DISTINCT
    sel.pro00_codigo,
    sel.pro00_codbar,
    sel.pro00_descri,
    sel.pro00_deslon,
    sel.pro00_unidad,
    sel.pro00_codimg,
    emb.emb00_embala,
    fra.fra00_indfra,
    fra.fra00_peso,
    sel.pro00_codfab,
    sel.pro00_codmar,
    sel.pro00_codgrp,
    sel.pro00_codsgr,
    sel.pro00_coddep,
    sel.pro00_codsec,
    sel.pro00_codlin,
    sel.pro00_codtrb,
    sel.pro00_pesbru,
    sel.pro00_pesliq,
    bon.bon00_defbon,
    bon.bon00_defbonven,
    ed0.pro00_entdat,
    est.pro00_prifil,
    COALESCE(est.pro00_qtdest - est.pro00_qtdpen, 0) AS pro00_qtdest,
    COALESCE(pr2.pro02_mulemb, 1)                    AS pro02_mulemb,
    COALESCE(pr2.pro02_mulven, 1.0)                  AS pro02_mulven
FROM cadpro00 sel
LEFT JOIN cadpro02    pr2 ON pr2.pro02_codpro = sel.pro00_codigo
LEFT JOIN estpro00    est ON est.pro00_codfil = :filialAtiva 
                         AND est.pro00_codpro = sel.pro00_codigo
LEFT JOIN cadprofra00 fra ON fra.fra00_codpro = sel.pro00_codigo
LEFT JOIN cadprobon00 bon ON bon.bon00_codpro = sel.pro00_codigo
LEFT JOIN cadproemb00 emb ON emb.emb00_codseq = sel.pro00_codemb
LEFT JOIN estprodat00 ed0 ON ed0.pro00_codfil = :filialAtiva 
                         AND ed0.pro00_codpro = sel.pro00_codigo
WHERE sel.pro00_codigo = :codpro;
   3. Índices Mandatórios no SQLite LocalPara assegurar tempos de resposta menores que 50ms, os seguintes índices cobridores devem ser executados após cada carga de dados:SQLCREATE INDEX IF NOT EXISTS idx_cadpro00_busca ON cadpro00(pro00_descri ASC, pro00_codigo);
CREATE INDEX IF NOT EXISTS idx_estpro00_filial_prod ON estpro00(pro00_codfil, pro00_codpro, pro00_qtdest, pro00_qtdpen);
CREATE INDEX IF NOT EXISTS idx_cadpro02_prod ON cadpro02(pro02_codpro);
CREATE INDEX IF NOT EXISTS idx_cadprofra00_prod ON cadprofra00(fra00_codpro);
CREATE INDEX IF NOT EXISTS idx_cadprobon00_prod ON cadprobon00(bon00_codpro);
CREATE INDEX IF NOT EXISTS idx_estprodat00_fil_prod ON estprodat00(pro00_codfil, pro00_codpro);
   4. Regras de Apresentação na UIEstoque Numérico Puro: Exibir o valor retornado de pro00_qtdest sem adicionar sufixos estáticos (ex.: não adicionar "PC" ou "PR").Unidade Oficial: A unidade de medida exibida no card deve vir estritamente de pro00_unidad (ex.: "UN", "CX", "KG").   Multiplicadores e Embalagem: Na visualização de detalhe, utilizar emb00_embala, pro02_mulemb e pro02_mulven para regras de cálculo e fração.   5. Critérios de Aceite[ ] A tela de catálogo/pesquisa executa exclusivamente a Query 1, trazendo apenas os campos do card.[ ] A paginação carrega de 100 em 100 itens via ScrollController sem travamentos de UI.[ ] Ao clicar em um card de produto, o sistema executa a Query 2 passando o pro00_codigo e abre os detalhes do item com todas as informações relacionais carregadas.   [ ] O saldo de estoque reflete a subtração (pro00_qtdest - pro00_qtdpen) vinculada estritamente à filial da sessão.   [ ] Testes unitários para o repositório cobrem as duas queries com dados reais e cenários de nulos/fallback (COALESCE).   