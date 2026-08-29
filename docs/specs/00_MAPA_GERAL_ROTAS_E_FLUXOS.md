# 00_MAPA_GERAL_ROTAS_E_FLUXOS.md - ARQUITETURA FUNCIONAL DE ROTAS, ESTADOS E PERSISTÊNCIA

Este documento apresenta a especificação técnica da arquitetura funcional, do fluxo de navegação lógica, da gerência de estados globais de sessão e do modelo relacional do banco de dados local SQLite do aplicativo de Força de Vendas (FV). Esta especificação serve como diretriz oficial para a migração limpa, modular e reativa do sistema legado para a arquitetura Flutter.

---

## 1. Árvore de Rotas e Navegação Lógica

A navegação do sistema é estruturada como uma máquina de estados baseada em fluxos de negócios sequenciais. O usuário progride à medida que cumpre validações comerciais e fiscais obrigatórias.

### Grafo Geral de Fluxos Lógicos

```
[Inicialização do App]
       │
       ▼
[Fluxo 1: Autenticação de Sessão] (Login)
       │
 (Sucesso na senha e carga de filial padrão)
       │
       ▼
[Fluxo 2: Painel Central de Controle] (Menu Principal)
       ├───► [Fluxo 3: Abertura de Pedido] (Abertura de Carrinho)
       │            │
       │     (Validação de cliente, limite e atrasos)
       │            │
       │            ▼
       │     [Fluxo 4: Carrinho de Compras] (Lista de Itens)
       │            ├───► [Fluxo 4.1: Catálogo de Produtos] (Livro de Preços)
       │            │            │
       │            │     (Validação de embalagem, estoque e preço)
       │            │            │
       │            │            ▼
       │            │     [Lançamento de Quantidade/Preço] (Quantidade e Preço)
       │            │
       │            ├───► [Fluxo 4.2: Distribuição de Brindes] (Bonificações)
       │            │
       │            ├───► [Fluxo 4.3: Montagem de Kits] (Combos Promocionais)
       │            │
       │            ▼
       │     [Fluxo 5: Checkout Comercial] (Resumo e Totais)
       │            │
       │     (Seleção de Agente Cobrador e validação de regras fiscais)
       │            │
       │     (Post transacional do pedido -> cpost() local)
       │            │
       │            ▼
       │     [Fluxo 6: Empacotamento para Envio] (Geração de Pacotes .pac)
       │
       ├───► [Fluxo 7: Histórico de Vendas] (Consulta de Extratos e Detalhes)
       │
       ├───► [Fluxo 8: Sincronizador de Lotes] (Comunicação FTP Carga/Descarga)
       │
       └───► [Fluxo 9: Configurações de Rede] (Servidor FTP/Acessos)
```

---

### Detalhamento Técnico de Fluxos e Transições

#### Fluxo 1: Autenticação de Sessão (Login)
*   **Gatilho de Entrada:** Inicialização física do aplicativo de Força de Vendas.
*   **Parâmetros Recebidos:** Nenhum (estado inicial limpo).
*   **Condições de Saída:**
    *   *Sucesso:* Autenticação válida. O sistema redireciona o vendedor para o Menu Principal.
    *   *Falha:* Bloqueio por senha inválida ou usuário inativo.
*   **Validações de Transição:**
    1.  O sistema descriptografa localmente a senha gravada no campo `ven00_paswor` da tabela de representantes (`cadrep00`).
    2.  Ao confirmar o acesso, o sistema executa o carregamento das variáveis do representante ativo em memória através do inicializador do perfil do vendedor logado.
    3.  A filial de faturamento padrão associada ao cadastro do vendedor (`ven00_codfil`) é definida como a filial ativa e imutável para filtrar as operações daquela sessão.

#### Fluxo 2: Painel Central de Controle (Menu Principal)
*   **Gatilho de Entrada:** Autenticação concluída com sucesso no Fluxo 1.
*   **Parâmetros Recebidos:** ID do Vendedor Logado, Filial Ativa e Parâmetros de Trabalho em memória.
*   **Condições de Saída:** Seleção de qualquer um dos submódulos funcionais ou Logout voluntário.
*   **Validações de Transição:**
    1.  **Limpeza e Manutenção de Banco:** Ao abrir o painel principal, o sistema aciona de forma transparente rotinas de manutenção interna. Ele executa a varredura e exclusão física de registros residuais, pedidos em edição abandonados e mensagens expiradas do banco SQLite local de digitação (`dbforcadig001.db`).
    2.  Ao acionar o logout, o estado do vendedor ativo é limpo de todas as variáveis globais de sessão em memória, retornando o app ao estado de login inicial.

#### Fluxo 3: Abertura de Pedido (Abertura de Carrinho)
*   **Gatilho de Entrada:** Clique em "Novo Pedido" ou "Iniciar Venda".
*   **Parâmetros Recebidos:** Filial Ativa.
*   **Condições de Saída:** Definição obrigatória do Cliente, Canal de Vendas (Linha de Produtos) e Condição de Pagamento (Plano).
*   **Validações de Transição:**
    1.  **Validação de Status do Cliente:** Bloqueia a abertura se o cliente estiver inativo (`cli00_active = 0`).
    2.  **Validação de Inadimplência:** O sistema cruza o cadastro do cliente com a tabela de títulos em atraso (`dup00`). Se houver qualquer título vencido há mais dias do que a tolerância parametrizada, o faturamento sob condições de prazo (boleto) é terminantemente bloqueado.
    3.  **Validação de Limite de Crédito:** Compara o saldo do cliente com o limite de crédito rotativo (`cli00_crelim` vs `cli00_creatu`). Caso o cliente esteja com o limite estourado, o faturamento a prazo é negado (a menos que a flag `ven00_ignlimfis` esteja ativa, permitindo a venda apenas com aviso de risco).

#### Fluxo 4: Carrinho de Compras (Lista de Itens)
*   **Gatilho de Entrada:** Aprovação das checagens cadastrais e financeiras do cliente no Fluxo 3.
*   **Parâmetros Recebidos:** ID do Cliente do pedido, ID da Linha de faturamento e ID do Plano de Pagamento.
*   **Condições de Saída:**
    *   *Confirmar:* Avançar para o fechamento/totais do pedido (exige que a lista de itens não esteja vazia).
    *   *Abortar:* Descarte completo do pedido em digitação e retorno ao painel de controle.
*   **Validações de Transição (Aborto):** O acionamento da ação de cancelamento do carrinho reverte todas as variáveis temporárias em memória. Nenhum commit é executado no banco SQLite, e os rascunhos de estoque e reserva são imediatamente descartados sem corromper as tabelas locais.

#### Fluxo 4.1: Catálogo de Produtos e Lançamento de Quantidades
*   **Gatilho de Entrada:** Clique em "Adicionar Itens" dentro do carrinho de compras.
*   **Parâmetros Recebidos:** ID da filial logada, ID da linha do pedido e ID da tabela de faturamento de preços.
*   **Condições de Saída:** Lançamento de quantidade/preço de um produto ou retorno simples ao grid do carrinho.
*   **Validações de Transição (Inserção de Linha):**
    1.  **Validação de Estoque Físico:** Se a verificação for obrigatória (`ven00_chkest = 1`), o sistema roda o cálculo de estoque disponível deduzindo as reservas temporárias em digitação. Se o saldo for insuficiente, impede o lançamento físico do item.
    2.  **Validação de Margem de Preço:** O preço unitário digitado manualmente pelo vendedor é auditado pela rotina de cálculo. O valor deve estar estritamente contido no intervalo entre o Preço Mínimo (`pro00_pcomin`) e o Preço Máximo (`pro00_pcomax`), respeitando o percentual teto de desconto parametrizado para o vendedor logado.

#### Fluxo 5: Checkout Comercial (Resumo, Totais e Fechamento)
*   **Gatilho de Entrada:** Clique em "Concluir" no carrinho de compras.
*   **Parâmetros Recebidos:** Objeto do pedido ativo em memória.
*   **Condições de Saída:** Confirmação da venda e gravação transacional definitiva no SQLite local.
*   **Validações de Transição:**
    1.  **Seleção de Agente Cobrador:** O seletor de agentes exibe a lista de cobradores disponíveis. O sistema busca no cadastro do cliente o campo `cli00_codage` (Agente Cobrador Padrão) e define esse código como a pré-seleção em foco no grid. O vendedor pode alterar manualmente se a negociação atual exigir. Se o vendedor desistir ou fechar a tela nessa etapa, o sistema apenas oculta o painel, mantendo o pedido intocado em rascunho de edição, sem gravar dados no banco local.
    2.  **Cálculo Fiscal e ICMS-ST:** O motor de cálculo fiscal local realiza as fórmulas de arredondamento de duas casas decimais para itens de faturamento inteiro ou três casas para itens pesados, calculando o ICMS-ST se aplicável para a UF destino.
    3.  **Post Transacional:** Ao clicar em salvar definitivo, o status do pedido muda para "Digitado/Fechado" (`sttdig = 1` na tabela `dig00`) e a rotina transacional grava de forma atômica o cabeçalho na tabela `dig00` e os itens na tabela `dig01` do SQLite.

#### Fluxo 6: Empacotamento para Envio (Sincronização Ativa)
*   **Gatilho de Entrada:** Salvamento com sucesso do pedido no Fluxo 5 (ou acionamento do Sincronizador).
*   **Parâmetros Recebidos:** Pedidos com status de sincronização pendente (`dig00_sttenv = 0`).
*   **Condições de Saída:** Geração do pacote compactado ZIP com assinatura única e extensão `.pac` depositado na fila de transmissão FTP.
*   **Validações de Transição:** O gerador de pacotes converte os registros do SQLite em um arquivo de dados estruturado XML com tags de cabeçalho e itens. Em seguida, compacta o arquivo físico no formato ZIP, renomeia a extensão para `.pac` seguindo o padrão rígido de nomenclatura `p<Representante>-<Timestamp>.pac` e atualiza transacionalmente o status de sincronização para "Empacotado" (`dig00_sttenv = 1`), impedindo qualquer edição ou duplicação de dados pelo vendedor.

---

## 2. Matriz de Estados Globais da Sessão

Para garantir a operação contínua e a integridade comercial em faturamentos totalmente offline, o aplicativo mantém em memória RAM global um conjunto de variáveis e classes singleton compartilhadas reativamente entre todas as interfaces.

| Estado Global de Sessão | Tipo de Objeto / Estrutura | Propósito Comercial e Funcional | Escopo / Ciclo de Vida |
| :--- | :--- | :--- | :--- |
| **Vendedor Ativo** | Classe Singleton (`Tcadrep00`) | Mantém a identificação física do representante logado (`ven00_codigo`), seu nome, limites de descontos e parâmetros comerciais de bloqueio. | Carregado no login. Desalocado da memória apenas no logout ou encerramento do app. |
| **Filial Ativa** | Variável Inteira (`int`) | Chave principal de faturamento. Filtra automaticamente todo o catálogo de produtos, estoques locais e tabelas de preço do representante. | Herdada do cadastro do vendedor logado. Limpa no encerramento da sessão. |
| **Configuração de Parâmetros**| Flags Booleanas (`bool`) | Controla as travas de validação em campo: checagem de estoque local (`ven00_chkest`), obrigatoriedade de cobrador (`ven00_chkage`) e permissão de bonificação manual (`ven00_gerbonfor`). | Instanciada no login, mantida de forma reativa durante toda a sessão. |
| **Carrinho Ativo (Rascunho)** | Classe de Modelo (`Tpckvendig00`) | Estrutura reativa que acumula em memória os dados do cabeçalho do pedido e o vetor dinâmico de itens inseridos pelo vendedor em tempo real. | Instanciado ao iniciar um novo pedido. Persistido fisicamente no SQLite ao fechar ou descartado ao abortar. |
| **Clientes em Cache** | Lista de Objetos (`Tcadcli00List`) | Indexação rápida em memória da carteira de clientes atribuída ao representante para pesquisa instantânea de rotas e limites. | Carregada na abertura da tela de pesquisa de clientes, desalocada ao selecionar o cliente destino. |

---

## 3. Dicionário do Banco de Dados Local (SQLite)

O sistema opera com faturamento offline distribuído em dois arquivos de banco SQLite independentes, gravados na memória de armazenamento interno do celular:
1.  **`dbforcacad001.db` (Banco de Consultas e Cadastros - Somente Leitura):** Atualizado exclusivamente por downloads de carga da retaguarda ERP.
2.  **`dbforcadig001.db` (Banco de Digitação e Movimentos - Escrita e Leitura):** Gravado localmente pelo aplicativo e consumido nas rotinas de descarga.

---

### A. Tabela: `cadrep00` (Cadastro de Vendedores e Parâmetros)
*   **Banco:** `dbforcacad001.db`
*   **Finalidade:** Cadastro e parametrização das políticas comerciais offline autorizadas para o representante logado.
*   **Chave Primária (PK):** `ven00_codigo` (INTEGER)

| Nome da Coluna | Tipo SQLite | Requisito | Regra de Negócio / Função no Faturamento |
| :--- | :--- | :--- | :--- |
| `ven00_codigo` | INTEGER | NOT NULL (PK) | Identificador único do vendedor para validação e registro de autoria dos pedidos. |
| `ven00_codfil` | INTEGER | NOT NULL | Código da Filial de faturamento padrão associada à rota de vendas do representante. |
| `ven00_descri` | TEXT | NOT NULL | Nome completo do vendedor para assinatura digital do pedido. |
| `ven00_paswor` | TEXT | NOT NULL | Senha de login criptografada local de acesso rápido. |
| `ven00_passet` | TEXT | NOT NULL | Senha de contingência de supervisor para liberação manual de estouros de crédito/bloqueios. |
| `ven00_chkest` | INTEGER | NOT NULL | Ativa a trava de estoque físico impeditiva no aparelho (`0` = Desativado, `1` = Ativo). |
| `ven00_chkage` | INTEGER | NOT NULL | Exige obrigatoriamente a validação do Agente Cobrador na finalização (`0` = Não, `1` = Sim). |
| `ven00_gerbonfor`| INTEGER | NOT NULL | Define se o representante tem autorização para emitir brindes/bonificações manuais em campo. |
| `ven00_ignlimfis`| INTEGER | NOT NULL | Permite ignorar o limite de crédito fiscal na finalização da venda (`0` = Trava, `1` = Avisa). |
| `ven00_maxitmdig`| INTEGER | NOT NULL | Teto máximo de itens permitidos em um único pedido local (evita estouros de payload). |

---

### B. Tabela: `cadcli00` (Cadastro de Clientes e Dados Financeiros)
*   **Banco:** `dbforcacad001.db`
*   **Finalidade:** Carteira de clientes do vendedor contendo as margens financeiras e preferências comerciais de faturamento.
*   **Chave Primária (PK):** `cli00_codigo` (INTEGER)
*   **Chave Estrangeira (FK):** `cli00_codage` ➔ `codage00` (`age00_codigo`)

| Nome da Coluna | Tipo SQLite | Requisito | Regra de Negócio / Função no Faturamento |
| :--- | :--- | :--- | :--- |
| `cli00_codigo` | INTEGER | NOT NULL (PK) | ID de faturamento exclusivo do cliente gerado no ERP. |
| `cli00_codrep` | INTEGER | NOT NULL | ID do representante de vendas detentor do cliente, garantindo exclusividade de rota. |
| `cli00_descri` | TEXT | NOT NULL | Razão Social limpa do cliente (removendo caracteres especiais e espaços). |
| `cli00_fantas` | TEXT | NULL | Nome Fantasia para busca rápida em campo. |
| `cli00_cpfcnp` | TEXT | NOT NULL | CPF ou CNPJ sem máscaras para emissão de Notas Fiscais eletrônicas. |
| `cli00_insest` | TEXT | NULL | Inscrição Estadual (obrigatório para PJ contribuinte, preenche com `"-"` para PF). |
| `cli00_codage` | INTEGER | NOT NULL (FK) | Código do Agente Cobrador Padrão pré-configurado no perfil do cliente. |
| `cli00_crelim` | REAL | NOT NULL | Limite de Crédito global bruto do cliente na retaguarda. |
| `cli00_creatu` | REAL | NOT NULL | Limite de Crédito reativo atualizado no celular (desconta vendas locais em trânsito). |
| `cli00_titven` | REAL | NOT NULL | Saldo total acumulado de duplicatas vencidas e inadimplentes na carteira. |
| `cli00_titave` | REAL | NOT NULL | Saldo total acumulado de duplicatas e faturas comerciais a vencer. |
| `cli00_active` | INTEGER | NOT NULL | Estado cadastral administrativo no aplicativo (`0` = Inativo/Bloqueado, `1` = Ativo). |

---

### C. Tabela: `cadpro00` (Cadastro do Catálogo de Produtos e Estoques)
*   **Banco:** `dbforcacad001.db`
*   **Finalidade:** Catálogo de mercadorias atualizadas com estoques físicos, fatores de embalagem e preços da filial.
*   **Chave Primária (PK):** `pro00_codigo` (INTEGER)

| Nome da Coluna | Tipo SQLite | Requisito | Regra de Negócio / Função no Faturamento |
| :--- | :--- | :--- | :--- |
| `pro00_codigo` | INTEGER | NOT NULL (PK) | Código de identificação exclusivo do produto. |
| `pro00_descri` | TEXT | NOT NULL | Nome comercial simplificado da mercadoria para o catálogo. |
| `pro00_unidade`| TEXT | NOT NULL | Unidade física de faturamento do item (UN, CX, KG, PC). |
| `pro00_qtdest` | REAL | NOT NULL | Saldo de estoque físico físico bruto disponível na filial correspondente. |
| `pro00_indfra` | INTEGER | NOT NULL | Sinalizador físico de fracionamento (`0` = Apenas inteiros, `1` = Aceita decimais/balança). |
| `pro00_prifil` | INTEGER | NOT NULL | Código da Filial física detentora desse saldo de estoque. |
| `pro00_pcomin` | REAL | NOT NULL | Preço mínimo permitido para venda (limite de desconto de faturamento). |
| `pro00_pcomax` | REAL | NOT NULL | Preço máximo de tabela sugerido para venda. |
| `pro00_commax` | REAL | NOT NULL | Percentual teto de desconto / flexibilidade máxima permitido para o vendedor. |
| `pro02_mulemb` | INTEGER | NOT NULL | Fator multiplicador de caixa fechada para faturamento de embalagem padrão. |
| `pro02_mulven` | REAL | NOT NULL | Multiplicador comercial mínimo utilizado para proporcionalizar volumes físicos. |

---

### D. Tabela: `dig00` (Cabeçalho do Pedido de Venda)
*   **Banco:** `dbforcadig001.db`
*   **Finalidade:** Registro físico local do cabeçalho de cada pedido comercial faturado ou em digitação pelo celular.
*   **Chave Primária (PK):** `dig00_digcod` (INTEGER)
*   **Chaves Estrangeiras (FK):** `dig00_clicod` ➔ `cadcli00` (`cli00_codigo`), `dig00_placod` ➔ `cadpla00` (`pla00_codigo`)

| Nome da Coluna | Tipo SQLite | Requisito | Regra de Negócio / Função no Faturamento |
| :--- | :--- | :--- | :--- |
| `dig00_digfil` | INTEGER | NOT NULL | Filial de faturamento responsável pelo processamento do pedido fiscal. |
| `dig00_digcod` | INTEGER | NOT NULL (PK) | Número do pedido gerado de forma incremental e automática pelo smartphone. |
| `dig00_clicod` | INTEGER | NOT NULL (FK) | ID do Cliente associado à venda para faturamento. |
| `dig00_clides` | TEXT | NOT NULL | Razão Social do cliente capturada em snapshot na conclusão. |
| `dig00_placod` | INTEGER | NOT NULL (FK) | Condição de Pagamento (Plano de Vendas) selecionada no checkout. |
| `dig00_digagt` | INTEGER | NOT NULL | ID do Agente Cobrador financeiro (Banco/Carteira) selecionado. |
| `dig00_digtot` | REAL | NOT NULL | Valor total líquido final do pedido (soma dos produtos ativos faturados). |
| `dig00_bontot` | REAL | NOT NULL | Valor correspondente a produtos cedidos como brinde/bonificação no pedido. |
| `dig00_subtot` | REAL | NOT NULL | Somatório calculado do imposto retido por Substituição Tributária (ICMS-ST). |
| `dig00_sttdig` | INTEGER | NOT NULL | Situação local da digitação (`0` = Em Digitação/Rascunho, `1` = Digitado/Fechado). |
| `dig00_sttenv` | INTEGER | NOT NULL | Status de sincronização (`0` = Pronto para Envio, `1` = Empacotado em .pac, `2` = Enviado FTP). |
| `dig00_datsys` | TEXT | NOT NULL | Data e hora exatas de encerramento do pedido gravadas no dispositivo. |

---

### E. Tabela: `dig01` (Itens e Produtos do Pedido)
*   **Banco:** `dbforcadig001.db`
*   **Finalidade:** Linhas físicas de itens vinculadas a cada pedido registrado no cabeçalho.
*   **Chave Primária Composta:** `dig01_digfil` (INTEGER), `dig01_digcod` (INTEGER), `dig01_digitm` (INTEGER)
*   **Chaves Estrangeiras (FK):** `dig01_digcod` ➔ `dig00` (`dig00_digcod`), `dig01_digpro` ➔ `cadpro00` (`pro00_codigo`)

| Nome da Coluna | Tipo SQLite | Requisito | Regra de Negócio / Função no Faturamento |
| :--- | :--- | :--- | :--- |
| `dig01_digfil` | INTEGER | NOT NULL (PK) | Filial física responsável pelo faturamento do item do pedido. |
| `dig01_digcod` | INTEGER | NOT NULL (PK/FK) | ID do pedido de cabeçalho correspondente. |
| `dig01_digitm` | INTEGER | NOT NULL (PK) | Número sequencial ordenado da linha física do item no grid (ex: item 1, 2, 3...). |
| `dig01_digpro` | INTEGER | NOT NULL (FK) | ID da mercadoria inserida no carrinho. |
| `dig01_digqtd` | REAL | NOT NULL | Quantidade final acordada com o cliente no painel rápido de digitação. |
| `dig01_digpco` | REAL | NOT NULL | Preço unitário final negociado (após descontos/acréscimos aplicados). |
| `dig01_subtot` | REAL | NOT NULL | Valor do imposto Substituição Tributária (ICMS-ST) calculado por linha. |
| `dig01_destot` | REAL | NULL | Valor absoluto de desconto financeiro aplicado exclusivamente nesta linha. |

---

### F. Outras Tabelas Estáticas de Faturamento (`dbforcacad001.db`)

#### Tabela: `codage00` (Cadastro de Agentes Cobradores)
*   **PK:** `age00_codigo` (INTEGER)
*   **Descrição:** Instituições financeiras, carteiras ou bancos cadastrados na retaguarda financeira para geração de boletos ou controle em carteira.
*   *Campos:* `age00_codigo` (INTEGER), `age00_descri` (TEXT).

#### Tabela: `dup00` (Títulos e Duplicatas em Aberto)
*   **PK:** `dup00_codigo` (TEXT)
*   **FK:** `dup00_clicod` ➔ `cadcli00` (`cli00_codigo`)
*   **Descrição:** Faturas antigas faturadas pela retaguarda, utilizadas no celular para cálculo offline de inadimplência e régua de cobrança em campo.
*   *Campos:* `dup00_codigo` (TEXT), `dup00_clicod` (INTEGER), `dup00_datemi` (TEXT), `dup00_datven` (TEXT), `dup00_valdev` (REAL), `dup00_codven` (INTEGER).

#### Tabela: `cadpla00` (Planos e Condições de Pagamento)
*   **PK:** `pla00_codigo` (INTEGER)
*   **Descrição:** Condições de prazo permitidas para parcelamento físico e regras de faturamento mínimo por pedido.
*   *Campos:* `pla00_codigo` (INTEGER), `pla00_descri` (TEXT), `pla00_vlrmin` (REAL).

---

## 4. Diretrizes Técnicas para Migração Segura para Flutter

Para assegurar uma reescrita moderna do sistema Força de Vendas que herde com segurança todas as regras offline-first descritas acima, a equipe de engenharia deve seguir as diretrizes abaixo:

1.  **Isolamento Absoluto de Código Legado (Clean Architecture):**
    *   A camada de UI do Flutter não deve conhecer o banco de dados diretamente.
    *   Crie um repositório centralizado de checkout (**CheckoutRepository**) que encapsule a máquina de estados comercial. É papel deste repositório realizar os cálculos de crédito do cliente, estoque líquido disponível e as validações impeditivas de faturamento antes de autorizar qualquer persistência de dados.
2.  **Gerenciamento de Estado Reativo (BLoC / Cubit):**
    *   A tela de checkout de carrinho de compras deve ser regida por estados reativos bem definidos (ex: `CartState`, `CreditValidationState`, `AgenteSelectionState`).
    *   A alteração de qualquer dado físico do pedido (como a remoção de um item ou a alteração de um plano de pagamento) deve disparar eventos de recálculo imediato de totais, impostos e limites de crédito, mantendo a interface reativa e informando o usuário em tempo real sobre bloqueios fiscais ou financeiros.
3.  **Persistência Offline Segura (Drift / Sqflite):**
    *   Utilize a biblioteca **Drift (anteriormente Moor)** baseada em SQLite para manter a consistência de tipos e integridade referencial nas tabelas locais do celular.
    *   Defina as tabelas `dig00` e `dig01` usando as mesmas chaves primárias e relacionamentos mapeados para garantir compatibilidade lógica de dados offline.
4.  **Sincronização Segura e Idempotente:**
    *   Implemente um gerenciador de fila de sincronização (**SyncManager**) resiliente a falhas de rede.
    *   Assegure que os status de transmissão sejam modificados de forma transacional atômica (SQLite Batch `UPDATE` sob transação) somente após a confirmação absoluta e íntegra de recebimento de uploads via FTP dos lotes empacotados, blindando o sistema contra riscos de faturamento em duplicidade.
