1. Momento da Validação do Limite de Crédito
Momento da Validação (Abertura vs. Fechamento)
Na Seleção do Cliente (ffrmdigvenmov00): O sistema realiza apenas a leitura consultiva e exibição dos limites financeiro original (cli00_crelim) e atualizado (cli00_creatu). A abertura da digitação de itens não é travada antecipadamente por limite de crédito insuficiente, pois o valor total da venda ainda inexiste (carrinho zerado).
No Fechamento do Pedido (doPEDPost / cpost em ffrmdigvenmov01 e usysvendig00): É no pipeline de gravação/conclusão da venda que ocorre a validação impeditiva. O motor de faturamento confronta o valor total líquido calculado do pedido (dig00_fattot / dig00_digtot) contra o saldo de crédito atual do cliente (cli00_creatu).
Tratamento do Limite em Vendas com Pagamento "À Vista"
Quando o plano de pagamento selecionado na tabela cadpla00 é configurado como modalidade À Vista / Dinheiro (pla00_codtyp = 0 / à vista), o sistema desconsidera a trava de limite de crédito.
Fundamento comercial: Como a operação à vista pressupõe liquidação financeira imediata no ato da entrega ou recebimento pelo próprio vendedor, a venda não gera duplicata a prazo (dup00), não consumindo e não dependendo de margem de crédito rotativo (cli00_creatu).
Papel do Parâmetro do Vendedor ven00_ignlimfis
O parâmetro booleano ven00_ignlimfis (Ignora Limite Fiscal do Representante), cadastrado na tabela cadrep00 e carregado na sessão do vendedor:
Quando Ativo (true / 1): Concede permissão comercial para o representante emitir e concluir pedidos mesmo com o limite de crédito do cliente estourado. O sistema emite apenas avisos e registra a flexibilização para auditoria do ERP.
Quando Inativo (false / 0): O sistema aciona um bloqueio rígido impeditivo, impedindo a conclusão do pedido (doPEDPost) e abortando a gravação local caso o total da venda ultrapasse cli00_creatu.
Comportamento na Abertura do Pedido (Aviso vs. Bloqueio)
O sistema permite prosseguir normalmente com a seleção de Linha (fspLIN), Condição de Pagamento (fspPLA) e entrada na tela de itens, exibindo os valores de limite de crédito nos painéis informativos sem travar a navegação. O bloqueio só é acionado no momento em que o vendedor tenta gravar o pedido com valor consolidado.
2. Exibição de Títulos Vencidos na Seleção do Cliente
Fluxo de Tela e Diálogo de Títulos Vencidos
Ao selecionar um cliente que possua duplicatas em atraso registradas na tabela local dup00 (ou totalizador cli00_titven > 0), o fluxo de abertura (ffrmdigvenmov00::doCLISelect) intercepta a navegação antes da seleção de linhas de produtos.
Em vez de avançar diretamente para a escolha de catálogo/linha, o formulário altera seu estado interno para a subpágina de títulos pendentes fspTIT (wpage_tit) e dispara o método doTITdataload(codcli), apresentando a listagem analítica de débitos em aberto.
Caso o vendedor acione a consulta financeira aprofundada, o sistema instancia o módulo dedicado de extrato financeiro ffrmextractcli00 ou a visualização detalhada de cobrança frmrelrecdup02.
Campos dos Títulos Vencidos Exibidos na Listagem
A listagem em grade da subpágina de títulos (wpage_tit / cgrid) expõe as seguintes colunas extraídas da tabela dup00:
Campo Exibido
Identificador Legado
Origem no SQLite
Descrição
Título
c_dup00_codigo
dup00_codigo
Número / identificador da duplicata ou fatura.
Emissão
c_dup00_datemi
dup00_datemi
Data de emissão original do título.
Vencimento
c_dup00_datven
dup00_datven
Data de vencimento da obrigação financeira.
Valor
c_dup00_valori
dup00_valori
Valor nominal de face do título.
Dias/Atraso
c_dup00_dias
Cálculo Dinâmico
Quantidade de dias em atraso calculada pela função diasAtrasado() em relação à data atual do dispositivo.
Juros
c_dup00_valjur
dup00_valjur
Valor dos encargos e juros acumulados por atraso.
Devedor
c_dup00_valdev
dup00_valdev
Saldo devedor líquido atualizado da duplicata.
Recebido
c_dup00_valpag
dup00_valpag
Total de amortizações parciais já registradas.
Vendedor
c_dup00_codven
dup00_codven
Código do representante comercial responsável pelo título.
Agente
c_dup00_codagt
dup00_codagt
Código do agente cobrador / carteira bancária.
T.Cob
c_dup00_codcob
dup00_codcob
Tipo de cobrança bancária associada.
Liberação e Continuidade da Digitação do Pedido
Sim, o vendedor pode continuar. A visualização da lista de títulos vencidos (fspTIT) tem caráter de alerta e gestão de cobrança em campo.
Ao acionar a ação de avançar / selecionar títulos (doTITSelect / botão de seleção da grade de títulos), o sistema executa o carregamento das linhas comerciais (doLINdataload()) e avança a máquina de estados para a seleção de Linhas (fspLIN) e Planos (fspPLA), ingressando normalmente na tela do carrinho de compras (ffrmdigvenmov01).
Condição de Exceção: Caso o cliente possua bloqueio rígido por inadimplência crônica configurado nas diretrizes de crédito sem permissão de liberação por parte do vendedor, o pedido só será impedido de ser finalizado no momento da validação do fechamento ou exigirá a modalidade à vista / autorização de supervisor.