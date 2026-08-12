# 📋 Especificação de Melhorias e Regras de Negócio (Migração Legado C++ -> Flutter)

Este documento mapeia os fluxos, tabelas, campos e rotas extraídos do sistema legado (`forcavenda_v415`) para implementação no aplicativo Flutter.

---

## 1. Módulo de Autenticação & Seleção de Filial

### Regra de Negócio:
Ao realizar o login e validar as credenciais do representante/vendedor:
1. O sistema deve consultar as filiais disponíveis no banco SQLite local (`cadfil00`).
2. **Se `count(cadfil00) > 1`:** Exibir um Card/Modal de seleção na tela para que o usuário escolha em qual filial irá trabalhar no aplicativo.
3. A filial selecionada deve ficar armazenada no `AppState` ou `SharedPreferences` para filtrar produtos, tabelas de preço e sequenciais de pedidos.

### Mapeamento de Tabela:
* **Tabela:** `cadfil00`
* **Campos:** `fil00_codigo` (int), `fil00_descri` (String), `fil00_active` (bool).

---

## 2. Módulo de Digitação de Pedidos: Conclusão e Resumo

### Fluxo de Telas:
`Carrinho / Lista de Itens` ➔ `[Botão Concluir Digitação]` ➔ `Modal Seleção de Agente Cobrador` ➔ `Tela Pedido Resumo`.

### A. Modal de Seleção do Agente Cobrador:
* Ao clicar em "Concluir Digitação", consultar a tabela `cadagt00`.
* Exibir Dropdown/Modal contendo Código e Nome do Agente Cobrador.
* Caso o cliente já possua um agente padrão (`cli00_codage`), pré-selecionar este agente.

### B. Tela de Resumo do Pedido (`PedidoResumoPage`):
Mapeamento dos campos do legado extraídos de `TLocalpckvendig00` / `ffrmdigvenrel01`:

| Campo no Flutter | Campo no Legado C++ | Descrição |
| :--- | :--- | :--- |
| `numeroPedido` | `dig00_digcod` | Número/Código do Pedido |
| `dataEmissao` | `dig00_datsys` | Data de Emissão (`QDate` / `DateTime`) |
| `cliente` | `cli00_codigo` + `cli00_descri` | Razão Social / Fantasia |
| `planoPagamento` | `dig00_placod` + `pla00_descri` | Plano de Pagamento Selecionado |
| `linhaProduto` | `dig00_lincod` + `lin00_descri` | Linha dos Produtos |
| `agenteCobrador` | `dig00_codagt` + `agt00_descri` | Agente Cobrador Selecionado |
| `quantidadeItens` | `dig00_qtditm` | Quantidade total de itens digitados |
| `valorBonus` | `dig00_bontot` | Valor total de Bonificação |
| `valorProdutos` | `dig00_digtot` | Valor total dos produtos |
| `valorSubstituicao` | `dig00_subtot` | Valor do ST / Produtos Substituição |
| `totalFatura` | `dig00_fattot` | Total geral da fatura do pedido |
| `observacao` | `dig00_observ` | Observações do pedido |

---

## 3. Módulo de Geração de Pacotes de Venda (`.pac`)

### Fluxo de Telas:
`Tela Pedido Resumo` ➔ `Pergunta: "Deseja gerar o pacote agora?"` ➔ `Tela Geração de Pacotes` (`ffrmdiggerpac00`).

### Regras de Negócio:
1. Exibir a lista de pedidos aguardando empacotamento (`dig00_pacstr` vazio ou status pendente).
2. Cada item da lista deve conter:
   * **Pedido** (`dig00_digcod`)
   * **Cliente** (`cli00_descri`)
   * **Data** (`dig00_datsys`)
   * **Plano** (`pla00_descri`)
   * **Linha** (`lin00_descri`)
   * **Checkbox** de seleção individual/múltipla.
3. Ao clicar em **"Gerar Pacote"**:
   * Compactar os arquivos XML dos pedidos selecionados em formato ZIP.
   * Salvar o pacote com a extensão **`.pac`**.
   * Nomenclatura oficial: `p<codigoRepresentante>-<codigoSequencialPacote>.pac` *(Ex: `p71-32504.pac`)*.
   * Exibir um alerta/SnackOnScreen com a confirmação: `"Pacote p71-32504.pac gerado com sucesso!"`.

---

## 4. Central de Cargas / Ferramentas & Ajuste de Rotas

### Layout da Tela de Ferramentas/Sincronização:
Replicar a estrutura da tela `ffrmconnect00` / `ffrmmenpri00`:
* **Painel Esquerdo (Lista de Tipos de Carga):**
  * `fcfPUTPED` (8) - Envio de Pacote de Vendas (`.pac`)
  * `fcfPUTCAD` (10) - Envio de Cadastros de Clientes (`.xml`)
  * `fcfPUTMSG` (9) - Envio de Mensagens (`.xml`)
  * `fcfGETCRG` (3) - Solicitação de Carga do Servidor
* **Painel Direito (Lista de Pacotes Gerados):**
  * Exibe os arquivos `.pac` prontos para transmissão.
* **Rodapé / Ações:**
  * Botão `[Criar Novo Pacote]`
  * Botão `[Conectar / Enviar Carga]`

---

## 5. 🛠️ Correção Crítica de Navegação (Rotas do Flutter)

### Problema Identificado:
O aplicativo atual encerra a sessão/faz logout após a conclusão de um pedido.

### Correção de Rota Requerida:
1. **Remover** chamadas de `Navigator.pushReplacementNamed(context, '/login')` ou deslogar o usuário ao salvar o pedido.
2. **Definir o Fluxo de Rotas Correto:**
   * `Concluir Venda` ➔ `PedidoResumoPage`
   * `Gerar Pacote` ➔ `GerarPacotePage` ➔ `FerramentasPage`
   * `Voltar para Home` ➔ `HomePage` (Mantendo o AppState e a Filial selecionada ativos).