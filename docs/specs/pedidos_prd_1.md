PRD e Especificação Técnica: Seleção de Agente Cobrador e Fluxo de Envio (Migração C++/Qt para Flutter)

1. Visão Geral e Objetivos Estratégicos

A funcionalidade de Seleção de Agente Cobrador é um componente crítico do fluxo de fechamento de vendas, atuando como o elo final entre a negociação comercial e a execução financeira. Estrategicamente, a definição correta do agente — baseada na tabela legada codage00 — assegura que os recebíveis sejam processados pelos canais bancários ou administrativos adequados, impactando diretamente a liquidez financeira e a precisão do fluxo de caixa.

A transição de um modelo de seleção manual para um sistema de pré-carregamento inteligente (baseado no cli00_codage do cadastro de clientes) é fundamental para reduzir erros operacionais e acelerar o time-to-cash. Para garantir a integridade desta migração, o sistema deve respeitar não apenas as regras de negócio, mas também a arquitetura de dados e de sincronização que sustenta o ecossistema legado.

1.5. Autenticação e Seleção de Filial

Conforme os novos requisitos de arquitetura multi-tenant, o processo de login deve obrigatoriamente validar a estrutura de filiais.

* Lógica de Seleção: Após a validação das credenciais, o sistema deverá realizar um count na tabela cadfil00.
* Intervenção de UI: Caso o resultado seja > 1, o aplicativo deverá exibir um Card ou Modal para que o usuário selecione a filial ativa.
* So What? Esta filtragem em nível de login é o que garante o isolamento de dados (estoque, preços e sequenciais) para operações em cenários de múltiplas unidades de negócio.

2. Engenharia Reversa: Dicionário de Dados do Legado (C++)

A estrutura de dados definida nos arquivos usysctr00.h/.cpp (classe Tcadage00) deve ser mapeada para o Dart com rigor técnico. A tipagem forte do C++ deve ser preservada no SQLite para manter a compatibilidade com a retaguarda.

Campo Técnico (C++)	Tipo (Dart)	Descrição	Mapeamento no Pedido (dig00)
age00_codigo	int	Identificador único do agente cobrador.	dig00_digagt
age00_descri	String	Nome/Descrição (ex: Banco, Carteira).	Exibido via lblagetxt
age00_tipo	int	Classificação do tipo de cobrança.	dig00_digcob

Conexão Técnica: O campo cli00_codage da tabela cadcli00 é a fonte primária para o pré-carregamento. A integridade referencial deve impedir a persistência de IDs inexistentes no SQLite local durante a seleção manual no Flutter.

3. Desconstrução do Fluxo de UI/UX Legado (Framework Qt)

O ambiente Qt utilizava a técnica de alternância de frames entre frmdat e frmage via slots doShowAGE() e doShowDAT().

* Comportamento: O slot doAGEdataload() realizava o fetch síncrono e populava o cgridage (Coluna 0: Código; Coluna 1: Descrição).
* Aviso de Arquiteto: No legado, o uso de "frames ocultos" preservava o estado em memória de forma implícita. No Flutter, como as rotas são descartadas da árvore de widgets, a persistência do estado do checkout durante a navegação para o modal de seleção deve ser gerenciada explicitamente via Gerência de Estado (BLoC/Cubit) para evitar perda de dados.

4. Regras de Negócio e Lógica de Decisão

A lógica de decisão prioriza a automação cadastral, permitindo a flexibilidade necessária para o vendedor no momento do checkout.

A. Regras de Seleção

1. Pré-carregamento Mandatório: Ao selecionar um cliente, o sistema busca cli00_codage na tabela cadcli00 e o atribui ao pedido.
2. Sobrescrita Manual: Permitida na tela de Totais (ffrmdigvenmov04), disparando um evento de override no estado do checkout.

B. Especificação da Tela de Resumo (PedidoResumoPage)

Após a seleção do agente, o sistema deve consolidar o pedido na tela de resumo. O mapeamento técnico para os 12 campos obrigatórios é:

Campo na UI	Atributo SQLite (dig00)
1. Número do Pedido	dig00_digcod
2. Data de Emissão	dig00_datsys
3. Cliente	cli00_codigo + cli00_descri
4. Plano	dig00_placod
5. Linha	dig00_lincod
6. Agente	dig00_digagt
7. Quantidade de Itens	dig00_qtditm
8. Bônus	dig00_bontot
9. Valor do Produto	dig00_digtot
10. Valor ST	dig00_subtot
11. Total da Fatura	dig00_fattot
12. Observação	dig00_observ

5. Arquitetura de Persistência e Sincronização (.pac / FTP)

A sincronização com o servidor FTP é o gargalo de integridade do sistema. O Flutter deve replicar exatamente o comportamento do TsysSyncronizeFTP.

A. Estrutura do XML e Nomenclatura

O arquivo gerado deve seguir o schema esperado pela retaguarda:

<PacoteVendas>
    <Representante><Codigo>105</Codigo></Representante>
    <Pedido>
        <Cabecalho>
            <CodigoPedido>99823</CodigoPedido>
            <CodigoAgente>7</CodigoAgente>
            <ValorTotal>1500.50</ValorTotal>
        </Cabecalho>
        <Itens><!-- ... --></Itens>
    </Pedido>
</PacoteVendas>


Regras de Nomenclatura de Arquivos:

* Pacotes de Venda (.pac): Devem utilizar o código sequencial do pacote do banco local: p<rep>-<pck_codigo>.pac.
* Arquivos de Cliente (.xml): Devem utilizar a lógica retornaMil() (milissegundos curtos): c<rep>-<milissegundos>.xml.

B. Lógica de Confirmação de Envio (JEnviado)

Para garantir que um pedido não seja marcado como enviado sem sucesso no upload:

1. Tracking em Memória: Durante a geração do .pac, os IDs dos pedidos incluídos devem ser armazenados em uma lista temporária.
2. Callback de Sucesso: A flag JEnviado no SQLite só será atualizada via UPDATE pedidos SET status = 'JEnviado' WHERE codigo IN (...) após a confirmação do PUT bem-sucedido no servidor FTP (diretório dirPAC).

6. Estratégia de Implementação no Flutter

A implementação deverá seguir padrões reativos para garantir performance em hardware mobile.

* Modelagem: Data Class Agent com métodos fromMap para leitura da tabela codage00.
* Gerência de Estado: O CheckoutBloc deverá tratar o evento SelectClient disparando um lookup automático do agente padrão, e o evento ManualOverrideAgent para seleções manuais.
* UI Modernizada: Substituição dos frames Qt por um BottomSheet com busca assíncrona, otimizando a ergonomia mobile e mantendo o contexto visual da tela de totais.
* Persistência: Utilização de Sqflite com transações para garantir que a gravação do pedido e a limpeza dos temporários após o envio sejam atômicas.

7. Critérios de Aceite e Validação Técnica

A funcionalidade será considerada "Concluída" apenas se satisfizer os seguintes requisitos:

1. Zero-regression Filial Filtering: O sistema impede o acesso sem a escolha de filial quando count(cadfil00) > 1.
2. Paridade de Payload: O XML contido no .pac deve possuir tags e estrutura idênticas ao legado, permitindo o processamento pela retaguarda Delphi/PHP.
3. Integridade do Fluxo de Envio: A flag JEnviado não deve ser alterada em caso de falha de conexão FTP durante o upload do pacote.
4. Conformidade de Nomenclatura: Os arquivos no FTP devem seguir estritamente os padrões p<rep>-<sequencial>.pac para vendas e c<rep>-<ms>.xml para cadastros.
