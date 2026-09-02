# ADR 0002: Arquitetura do Módulo de Contas a Receber e Gestão de Duplicatas Offline

## Contexto
No sistema de Força de Vendas legado, a auditoria de cobrança e inadimplência era realizada de forma fragmentada entre frames do menu principal (`ffrmmenpri00`), telas de consulta (`ffrmrelrecdup00`), extrato (`ffrmrelrecdup01`) e travas duras na digitação (`ffrmrelrecdup02`). 

Na modernização em Flutter, é necessário manter a integridade da apuração 100% offline dos títulos em aberto (`dup00`), respeitar o escopo negativo estrito da aplicação em campo (sem baixa física, sem emissão de boleto/Pix local, sem alteração de prazos) e prover uma experiência ágil (UX) que não desoriente o vendedor durante a rotina diária.

## Decisões Tomadas
1. **Ponto de Entrada Duplo**:
   - **Visão Macro**: Botão direto "Receber" na `HomePageWidget` completando o grid da tela inicial ao lado de "Relatórios".
   - **Visão Micro**: Acesso contextual a partir do extrato / perfil do cliente em `ClientePageWidget` e `ExtratoClientePageWidget`.
2. **Interface Reativa via Sliding BottomSheet**:
   - A consulta consolidada geral exibe a carteira de clientes com débitos ativos e filtros rápidos por chips (`Todos com Débito`, `Apenas Vencidos`, `A Vencer`).
   - O extrato analítico do cliente abre em um `Sliding BottomSheet` modal deslizante que preserva o estado de rolagem da lista macro, permitindo auditoria rápida ou expansão para tela cheia.
3. **Ordenação Crítica por Aging (Tempo de Atraso)**:
   - A lista prioriza por padrão os clientes com títulos mais antigos em atraso (maior risco de bloqueio comercial imediato), disponibilizando alternância rápida para maior valor vencido e ordem alfabética.
4. **Cálculo Fiel de Juros Offline (`ven00_txajur`)**:
   - Os juros de mora acumulados seguem a regra $\text{dup00\_valdev} \times (\text{ven00\_txajur} / 100) \times \text{diasAtrasado}$. Caso `ven00_txajur` seja nulo ou 0 no representante (`cadrep00`), juros permanecem em R$ 0,00 sem alíquotas arbitrárias.
5. **Centralização DRY no `ReceberDuplicatasService`**:
   - As queries em SQLite (`dup00`), cálculos de dias de atraso, juros e agrupamentos são centralizados em `ReceberDuplicatasService`. O `BloqueioFinanceiroService` consome essa mesma base, eliminando discrepâncias entre relatórios e travas de fechamento de pedido.
6. **Cobrança Amigável e Atalho de Pedido**:
   - O extrato permite exportação rápida formatada para WhatsApp ou Clipboard.
   - O botão "Iniciar Pedido" no extrato integra-se diretamente ao fluxo de venda, executando a barreira de liberação/handshake se o cliente possuir títulos vencidos.

## Consequências
- **Consistência Absoluta**: Relatórios e checkout utilizam rigorosamente a mesma regra de apuração de débitos e títulos vencidos.
- **Eficiência Operacional**: O vendedor audita dívidas, gera texto para o financeiro do cliente e inicia novos pedidos no mesmo fluxo sem fricção.
- **Conformidade Regulatória/Negócio**: O app preserva a integridade financeira delegando baixas e conciliações fiscais estritamente à retaguarda (ERP).
