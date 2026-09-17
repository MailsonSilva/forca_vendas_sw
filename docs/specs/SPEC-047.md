SPEC-047: Gestão Multi-Filial, Fechamento de Venda, Validação de Estoque e Atualização Integral de Carga

Metadado

Detalhe

Módulo

Autenticação, Digitação de Pedidos (pckvendig00), Catálogo e Carga (ffrmcom00)

Arquivos Legados de Referência

ffrmcadcli.h, ffrmdigvenmov07.h, usysvenfun00.h, usysfis00.h, ffrmdiggerpac00.cpp

Tabelas Envolvidas

cadfil00, cadrep00, cadpro00, estpro00, cadpro02, cadace00, pckvendig00, pckvendig01

Bancos SQLite

dbforcacad001.db (Cadastros/Carga) e dbforcadig001.db (Movimento de Vendas)

Status

Pronto para Execução via TDD / Triagem

1. Módulo 1: Seleção e Contexto de Filial Ativa no Login

1.1. Regra de Negócio Legada

Ao autenticar as credenciais do vendedor (cadrep00.ven00_codigo), o sistema consulta as filiais ativas na tabela cadfil00 (WHERE fil00_active = 1 ou true).

Cenário 1 (Filial Única): Se COUNT(cadfil00) == 1, seleciona automaticamente o registro retornado, gravando o código no estado da sessão (ven00_codfil).

Cenário 2 (Multi-Empresa): Se COUNT(cadfil00) > 1, o app interrompe o avanço e abre obrigatoriamente o modal ModalSelecaoFilialWidget (padronizado com showAppModalBottomSheet). O vendedor deve escolher em qual unidade irá operar.

Persistência de Sessão: A filial selecionada (filialAtiva) é mantida em memória global / SharedPreferences e governa:

Catálogo de produtos e saldos de estoque.

Preços e tabelas promocionais.

O cabeçalho dos pedidos (pckvendig00.dig00_digfil = filialAtiva).

2. Módulo 2: Fechamento de Pedido, Agente Cobrador e Observação

2.1. Fluxo de Encerramento da Venda

[Carrinho / Lista de Itens]
          │
          ▼  (Ação: "Concluir Digitação")
[Modal: Seleção do Agente Cobrador (cadagt00)]
          │  - Pré-seleciona cli00_codage se definido no cadastro do cliente
          ▼  (Confirmar Agente: dig00_digagt)
[Campo Aberto: Observação do Pedido (dig00_digobs)]
          │  - Texto livre (instruções de entrega, restrições de horário)
          ▼  (Avançar para Totais)
[Tela: Resumo do Pedido (PedidoResumoPage)]
          │  - Exibe os 12 indicadores consolidados do legado
          ▼
[Decisão: "Deseja gerar o pacote agora?"]
    ├── (Sim) ──► [Tela Geração de Pacotes (ffrmdiggerpac00)]
    └── (Não) ──► Retorna à HomePage mantendo a sessão e filial ativas


2.2. Dicionário de Campos do Resumo do Pedido (PedidoResumoPage)

Conforme mapeamento das classes legadas TLocalpckvendig00, ffrmdigvenmov04 e ffrmdigvenrel01:

Campo na UI

Campo Legado SQLite

Tipo

Descrição

Número do Pedido

dig00_digcod

INTEGER

Sequencial local incremental (MAX + 1)

Data de Emissão

dig00_datsys

DATETIME

Data e hora do registro da digitação

Cliente

dig00_clicod + Razão

TEXT

[Código] Razão Social

Plano de Pagamento

dig00_placod + Nome

TEXT

Condição de pagamento / parcelamento

Linha de Produto

dig00_lincod + Nome

TEXT

Linha comercial selecionada

Agente Cobrador

dig00_digagt + Nome

TEXT

Agente/Banco selecionado

Qtd de Itens

dig00_qtditm

INTEGER

Contagem total de itens/linhas digitadas

Bônus / Bonificação

dig00_bontot

REAL

Total de mercadorias bonificadas (formato .toMoeda())

Valor dos Produtos

dig00_digtot

REAL

Valor bruto total dos produtos

Substituição Tributária

dig00_subtot

REAL

Total apurado de ST (calcICMSSubTotal())

Total Faturado/Geral

dig00_fattot

REAL

Total líquido final da venda

Observação

dig00_digobs

TEXT

Texto digitado pós-agente

3. Módulo 3: Catálogo, Unidade e Validação de Estoque (ffrmdigvenmov07)

3.1. Correção Visual do Estoque e Referência no Card

Remoção de String Fixa: Excluir qualquer sufixo estático (ex: " PC", " PR"). O estoque físico deve ser exibido como número puro extraído de cadpro00.pro00_qtdest ou da tabela multi-filial estpro00.pro00_qtdest.

Sigla Oficial da Unidade: Exibir exclusivamente o conteúdo do campo textual pro00_unidad (ex: "UN", "CX", "FD", "KG").

Referência e EAN:

Referência principal: pro00_codbar (Código de Barras EAN).

Referências comerciais secundárias: prp00_ref001 e prp00_ref002 (se presentes no schema da carga).

3.2. Regra de Validação de Estoque no Item (ffrmdigvenmov07::validaEstoque)

Ao inserir quantidade de um item no pedido:

Buscar o estoque físico disponível da filial ativa:

SELECT COALESCE(e.pro00_qtdest, p.pro00_qtdest, 0.0) AS estoque_disponivel
FROM cadpro00 p
LEFT JOIN estpro00 e ON e.pro00_codpro = p.pro00_codigo 
                    AND e.pro00_codfil = :filialAtiva
WHERE p.pro00_codigo = :codigoProduto;


Caso o parâmetro de controle de venda negativa esteja bloqueado no sistema (ven00_estneg == false ou diretiva de carga), impedir a confirmação caso a quantidade digitada (dig01_digqtd) supere o estoque disponível.

4. Módulo 4: Atualização Integral da Carga e FTP (fcfGETCRG = 3)

4.1. Substituição Fisiológica do Banco SQLite

Problema: A execução de INSERT OR REPLACE incremental gera inconsistências de estoque residual.

Comportamento Legado Obrigatório:

O download da carga via FTP traz o arquivo binário do SQLite (dbforcacad001.db / carga do vendedor).

A aplicação encerra todas as conexões abertas com a instância local do banco SQLite de carga (dbCad.close()).

O arquivo físico antigo em disco é deletado.

O arquivo temporário baixado é movido/renomeado para o local definitivo.

As instâncias dos repositórios locais são reabertas.

Atenção: As tabelas do banco de movimentação local (pckvendig00, pckvendig01, pckvenpac00) no arquivo dbforcadig001.db não podem ser apagadas.

4.2. Registro Temporal na Home Page

Ao concluir a substituição da carga com sucesso, persistir a data e hora em SharedPreferences:

Chave: ultima_atualizacao_carga

Formato exibido: "Última atualização: DD/MM/AAAA às HH:MM"

Localização: Centralizado na base da Home Page, acima dos botões de navegação e protegido por SafeArea(bottom: true).

4.3. Renomeação Remota no Servidor FTP

Imediatamente após a confirmação de integridade do download:

O arquivo original presente na pasta remota do FTP (ex: carga_105.db) deve ser renomeado via comando FTP (RENAME):

Regra: Remoção da extensão original e sufixação com data e hora no formato ISO compacto.

Padrão: <nomeOriginalSemExtensao>_<YYYYMMDD_HHmmss>

Exemplo: carga_105.db ➔ carga_105_20260917_092247

5. Critérios de Aceite

[ ] Login com mais de uma filial ativa exibe ModalSelecaoFilialWidget; com filial única, seleciona automaticamente.

[ ] Conclusão da digitação exibe modal de Agente Cobrador (cadagt00) seguido do campo de texto Observação do Pedido (dig00_digobs).

[ ] A tela de Resumo do Pedido exibe todos os 12 indicadores consolidados e, ao final, não desloga o vendedor nem fecha o app.

[ ] O card de produtos exibe o estoque puramente numérico (sem a sigla "PC" concatenada) e utiliza a sigla de pro00_unidad.

[ ] O estoque do produto reflete a filial ativa (estpro00 / cadpro00).

[ ] A baixa de carga fecha a conexão, substitui o arquivo binário .db integralmente, grava a data/hora na Home e renomeia o arquivo remoto no FTP sem extensão.