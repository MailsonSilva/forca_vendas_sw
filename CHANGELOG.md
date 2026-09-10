# Changelog

Todas as alterações notáveis deste projeto serão documentadas neste arquivo.

O formato é baseado em [Keep a Changelog](https://keepachangelog.com/pt-BR/1.0.0/),
e este projeto adere ao [Versionamento Semântico](https://semver.org/lang/pt-BR/).

---

## [5.1.0] - 2026-09-02

### 🌟 Adicionado (Novas Funcionalidades)

#### 1. Módulo de Contas a Receber (Receber / Gestão de Duplicatas)
- **Consulta Consolidada Geral (`ReceberPageWidget`)**:
  - Hub financeiro 100% offline para acompanhamento da inadimplência da carteira.
  - Card de resumo financeiro superior: Montante Total Devedor, Total Vencido e Total A Vencer.
  - Filtros operacionais reativos por chips: `Todos com Débito`, `Apenas Vencidos` e `A Vencer`.
  - Ordenação dinâmica com foco em mitigação de risco: **Aging / Maior Tempo de Atraso** (padrão), Maior Valor Devedor e Ordem Alfabética.
  - Barra de busca instantânea por Código, Razão Social ou Nome Fantasia.
- **Extrato Analítico em Sliding BottomSheet (`ExtratoDuplicatasWidget`)**:
  - Abertura suave e modal que preserva a posição de rolagem da lista macro de clientes.
  - Badges coloridos de alerta: destaque em vermelho para títulos vencidos (`X dias de atraso`) com juros acumulados; verde para títulos no prazo.
  - Auditoria de limites de crédito: Limite Total (`cli00_crelim`) e Limite Disponível (`cli00_creatu`).
  - **Cobrança Amigável**: Ação de compartilhamento com formatação limpa e emojis para envio direto via WhatsApp ou cópia para Clipboard.
  - **Atalho de Novo Pedido**: Abertura direta do carrinho de digitação com validação de barreira de bloqueio e termo de responsabilidade para clientes com débitos vencidos.
- **Pontos de Entrada no Sistema**:
  - Novo botão **"Receber"** no menu principal (`HomePageWidget`) ao lado de "Relatórios", completando a grade 2x3.
  - Atalho de consulta rápida no modal de clientes (`ModalClienteWidget`).
  - Botão de auditoria de duplicatas na AppBar da ficha do cliente (`ExtratoClientePageWidget`).

#### 2. Módulo de Relatórios Comerciais e Produtividade
- **Conta-Corrente do Vendedor (CCV / Saldo Flex)**:
  - Apuração em tempo real do Saldo Base oficial (`ccv01_vlrsal`) + Provisão de Digitação (`ccv01_vlrusedig`) + Pedidos em Trânsito (`ccv01_vlrusepck`).
  - Validação da trava de desconto `ven00_chkccv`.
- **Faturamento e Acompanhamento de Metas (`FaturamentoMetasPageWidget`)**:
  - Cota mensal (`fat00_vlrcalven`) vs. Faturamento ERP (`fat00_vlrfatven`).
  - Sintetização local considerando rascunhos e lotes em trânsito.
  - Controle e validação de teto de faturamento para Pessoa Física (`fat00_vlrtotlib` e `cli00_typpes = 1`).
- **Resumo de Vendas Diário e Comissões (`ResumoVendasPageWidget`)**:
  - Totalizadores de Venda Bruta, Devoluções/Cortes e Venda Líquida.
  - Cálculo de comissão acumulada item por item conforme alíquota do cadastro de produtos (`cadpro00.pro00_commax`).
  - Tratamento de itens bonificados (`bontyp > 0`) com comissão zerada (0%).
  - Diferenciação entre comissão projetada (pedidos locais) e homologada (pedidos faturados via `.ret`).
- **Carteira de Clientes e Roteirização (`CarteiraRoteirizacaoPageWidget`)**:
  - Segmentação de visitas por dia da semana (`cli00_flgven`).
  - Semáforo financeiro: Vermelho (Inadimplente), Amarelo (Vencimento Próximo) e Verde (Crédito em dia).
  - Consulta de limites de crédito e coordenadas de georreferenciamento (`cli16_codlat`, `cli16_codlon`).

### ⚙️ Melhorias e Refatorações (DRY)
- **Serviço Centralizado [`ReceberDuplicatasService`]**:
  - Unificação do motor de cálculo de duplicatas (`dup00`) para relatórios e checkout.
  - Resolução dinâmica de nomes de tabelas e colunas via `PRAGMA table_info`, garantindo imunidade a variações de esquemas de banco (PRD, legados e testes).
  - Cálculo offline fiel de juros de mora utilizando rigorosamente a taxa `ven00_txajur` do representante (`cadrep00`). Se ausente ou zero, o juro apurado é mantido em R$ 0,00 sem taxas inventadas.
- **Refatoração do [`BloqueioFinanceiroService`]**:
  - Eliminação de duplicidade de código SQL (DRY), passando a consumir o `ReceberDuplicatasService` para validação de títulos vencidos na abertura e fechamento de pedidos.
- **Banco de Dados Local (`LocalSalesDatabaseService`)**:
  - Migração automática para garantir a tabela `dup00`, coluna `cadrep00.ven00_txajur`, índices de alta performance em `dup00_codcli` e `dup00_datven`, e views de compatibilidade `findup00` e `cadrecdup00`.

### 🛡️ Testes e Garantia de Qualidade
- **Testes Unitários e de Integração**:
  - Criação de `test/receber_duplicatas_service_test.dart` com validação de apuração de dias de atraso, juros ponderados, parse de datas, geração de texto de WhatsApp, filtros de status e ordenação por Aging.
- **Testes de Widgets**:
  - Criação de `test/receber_page_widget_test.dart` validando renderização de cabeçalho, filtros, botões de ação e Sliding BottomSheet.
  - 100% dos testes passando com sucesso.
- **Análise Estática**:
  - Execução de `flutter analyze` sem nenhum erro ou aviso (`No issues found!`).

### 📚 Documentação e Governança
- Registrada [`ADR 0002: Arquitetura do Módulo de Contas a Receber e Gestão de Duplicatas Offline`](docs/adr/0002-modulo-receber-duplicatas-offline.md).
- Atualizado o glossário de domínio e regras de negócio em [`CONTEXT.md`](CONTEXT.md).
