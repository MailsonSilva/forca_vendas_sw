# ESPECIFICAÇÃO TÉCNICA E DE REGRAS DE NEGÓCIO: MÓDULO DE CLIENTES E GESTÃO FINANCEIRA

Este documento estabelece as especificações funcionais e técnicas para a migração e reescrita do **Módulo de Clientes e Gestão Financeira** do aplicativo de Força de Vendas (FV). O mapeamento é baseado na engenharia reversa das regras comerciais, validações fiscais e de faturamento offline contidas nas classes C++/Qt e nas tabelas SQLite do banco local.

---

## 1. Dados do Cliente (Entidade, Estrutura e Vínculos)

No sistema legado, a representação de dados do cliente é estruturada de forma dupla: em memória, pela classe de modelo **`Tcadcli00`** (declarada em `usysctr00.h` e implementada em `usysctr00.cpp`), e no banco de dados local de cadastros (`dbforcacad001.db`), pela tabela **`cadcli00`**.

### A. Campos Obrigatórios e Mapeamento de Faturamento
A validação do cadastro no dispositivo é gerenciada pelo formulário **`ffrmcadcli.cpp`**, que exige o preenchimento de dados essenciais antes de liberar a gravação física. Os campos comerciais e fiscais obrigatórios são:
*   **`cli00_codigo` (INTEGER):** Chave primária de identificação do cliente no ERP.
*   **`cli00_codrep` (INTEGER):** Código do representante de vendas (vendedor) proprietário do cliente.
*   **`cli00_descri` (TEXT):** Razão Social (limpeza de caracteres vazios via `trimmed()`).
*   **`cli00_fantas` (TEXT):** Nome Fantasia (opcional).
*   **`cli00_pessoa` (INTEGER):** Tipo de Pessoa definido pelo enumerador **`TPessoalType`** (`ptFIS = 1` para Física, `ptJUR = 2` para Jurídica).
*   **`cli00_cpfcnp` (TEXT):** CPF ou CNPJ limpo de pontuações.
*   **`cli00_insest` (TEXT):** Inscrição Estadual. Obrigatório para Pessoa Jurídica (se contribuinte).
*   **`cli00_codage` (INTEGER):** Identificador do Agente Cobrador Padrão (chave estrangeira apontando para a tabela de cobradores `codage00` / `codage00`).

### B. Status e Situação Cadastral
O status do cliente é monitorado de forma binária no dispositivo pelo campo **`cli00_active`** (Sinalizador de Ativação, tipo `INTEGER` / `bool` em C++):
*   **`cli00_active = 1` (Ativo):** Cliente regularizado, liberado para seleção no início do pedido de venda.
*   **`cli00_active = 0` (Inativo / Bloqueado administrativamente):** Cliente com restrição ou suspenso na retaguarda. O aplicativo impede que o vendedor abra uma nova digitação para este cadastro.

### C. Vínculo com Vendedor e Filial
A carteira móvel de clientes é totalmente isolada para garantir a segurança dos dados de campo:
*   **Propriedade do Vendedor:** Cada cliente possui o campo **`cli00_codrep`** (ID do Representante) no banco local, vinculando o cadastro ao vendedor logado na sessão ativa (`Tcadrep00::ven00_codigo`).
*   **Vinculação de Filial:** A filial não é gravada de forma estática no cliente. Em vez disso, o sistema herda a filial ativa do vendedor logado em memória (**`ven00_codfil`**) no momento em que um pedido é aberto para o cliente, persistindo-a no cabeçalho da venda como **`dig00_digfil`**.

---

## 2. Análise de Crédito, Gestão Financeira e Bloqueios

Toda a inteligência financeira offline é centralizada na classe de validações comerciais **`usysvenblk00`** e nas controllers de faturamento.

### A. Consulta e Cálculo do Limite de Crédito vs. Saldo Devedor
O sistema legado protege o faturamento calculando o limite líquido disponível para compras de forma offline no dispositivo:

1.  **Saldo Devedor Total do Cliente:**
    Obtido através do somatório de títulos vencidos em atraso (**`cli00_titven`**) e faturas emitidas ainda a vencer (**`cli00_titave`**):
    \\[\text{Saldo Devedor Total} = \text{cli00\_titven} + \text{cli00\_titave}\\]
2.  **Cálculo de Margem Disponível para Novas Vendas:**
    Ao faturar um novo carrinho, o aplicativo avalia se a venda atual estoura o teto de crédito do cliente confrontando o saldo de limite atualizado em sincronia (**`cli00_creatu`**):
    \\[\text{Limite Disponível para Venda} = \text{cli00\_creatu} - \text{Total Geral do Pedido (dig00\_fattot)}\\]
    Se o resultado for menor que zero, o faturamento é impedido ou sinalizado para auditoria de limite excedido.

### B. Avaliação de Títulos em Aberto e Vencidos (`dup00` / `tit00`)
Os títulos detalhados de cobrança são controlados na tabela local **`dup00`** (mapeada visualmente no extrato `ffrmextractcli00.cpp` e nos relatórios de recebíveis `ffrmrelrecdup01.cpp`).

*   **Régua de Atraso de Duplicatas:**
    A função **`diasAtrasado(QDate dtUltimoPagamento)`** da classe `ffrmextractcli00` calcula os dias de atraso comparando o vencimento do título (**`dup00_datven`**) com a data atual do aparelho:
    \\[\text{Dias de Atraso} = \text{Data Atual} - \text{dup00\_datven}\\]
    Este método roda um calendário iterativo que acumula os dias de atraso físico enquanto a data de vencimento for menor que a data corrente.
*   **Filtro por Propriedade:**
    Na consulta, a query ordena os títulos de modo a priorizar primeiro as duplicatas faturadas sob a autoria do próprio vendedor logado (**`dup00_codven = ven00_codigo`**), facilitando a cobrança em carteira direto no cliente.

### C. Regras e Mensagens de Bloqueio Automático

No momento em que o vendedor seleciona o cliente para abrir a venda (`ffrmdigvenmov00.cpp`), o motor de negócios **`usysvenblk00`** audita a saúde financeira do cadastro:

1.  **Inadimplência Crítica (Títulos Vencidos em Atraso):**
    *   *Regra:* Se **`cli00_titven > 0`** (ou se houver qualquer linha na tabela `dup00` com dias de atraso superiores à tolerância parametrizada para a carteira de vendas).
    *   *Comportamento:* O faturamento convencional é bloqueado. O sistema trava a abertura do pedido ou exige que o vendedor altere o faturamento para condições de baixo risco (como dinheiro à vista ou cobrança em carteira) que desconsideram o limite de crédito. O desbloqueio do faturamento faturado só ocorre mediante a inserção da **senha de supervisor** (**`ven00_passet`**).
2.  **Estouro de Limite de Crédito:**
    *   *Regra:* Se o valor total do pedido ativo superar o saldo do cliente (\\[\text{Total Venda} > \text{cli00\_creatu}\\]).
    *   *Comportamento:* É controlado pelo parâmetro do representante **`ven00_ignlimfis`** (Ignora Limite Fiscal). Se estiver ativo (`true`), o sistema exibe um aviso de alerta na tela mas permite salvar o pedido. Se estiver inativo (`false`), o salvamento do pedido é rigidamente bloqueado.

---

## 3. Operações Disponíveis (Fluxos e Processos de Campo)

### A. Fluxo de Consulta e Extrato Financeiro
*   **Extrato de Títulos:** Através do método **`consultarTitulos(int codcli)`** na janela de extrato financeiro **`ffrmextractcli00.cpp`**, o sistema realiza uma varredura de recebíveis na tabela `dup00` consolidando os juros acumulados, valores originais de faturamento e saldo devedor atualizado.
*   **Histórico de Faturamento:** O volume histórico de vendas anteriores é carregado offline a partir da estrutura de histórico consolidado de faturamento por cliente (**`ESTFATCVD00Record`** em `usysvenfun00.h`), que indica o faturamento acumulado por filial e representante.

### B. Cadastro de Clientes no App Móvel (Offline-First)
O sistema legado permite a inserção de novos clientes diretamente em campo através do formulário **`ffrmcadcli.cpp`**, utilizando as seguintes regras:

1.  **Validações Fiscais e Máscaras Dinâmicas:**
    *   Durante a digitação, o evento **`keyReleaseEvent`** monitora o foco e aplica masks com base no tipo de pessoa selecionado:
        *   **Pessoa Física:** Aplica máscara de CPF (`999.999.999-99`) e exige preenchimento de RG (`cli00_nRG`). Desabilita e oculta Inscrição Estadual.
        *   **Pessoa Jurídica:** Aplica máscara de CNPJ (`99.999.999/9999-99`) e exige Inscrição Estadual (`cli00_iEst`). Desabilita campo de RG.
2.  **Limpeza de Caracteres Especiais:**
    *   Antes de persistir o cadastro na tabela SQLite local de escrita (`dbaliasdig`), a rotina utilitária **`RemoveMascara(QString Text)`** limpa todos os caracteres especiais (`.`, `-`, `/`, `(`, `)`) salvando o documento bruto.
3.  **Geração e Compactação do Arquivo de Integração:**
    *   Ao salvar com sucesso através do método **`salvarNoDb(Cliente *c1)`**, a classe de negócios `Cliente` aciona os métodos **`Cliente::fileCAD()`** ou **`Cliente::fileLOC()`**.
    *   Estas rotinas geram um arquivo XML padronizado contendo a ficha cadastral do cliente e gravam o arquivo no diretório local de faturamento **`dirCLI`** (gerido pela sincronização FTP).
    *   **Padrão de Nomenclatura do Arquivo:**
        \\[\text{Nomenclatura do Arquivo} \rightarrow \mathbf{c\langle\text{codigoRepresentante}\rangle-\langle\text{Timestamp/retornaMil()}\rangle.xml}\\]
        *Exemplo: `c105-1682930.xml`*
