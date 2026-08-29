# Plano — Gap Closure PRD `docs/specs/pedidos_prd.md`

> **Preservação explícita:** `lib/services/ftp_upload_service.dart:161` (`SITE SIZE` + `STOR`), `lib/services/ftp_path_builder.dart:62` (`p<rep>-<seq>.pac` / `/<empresa>/<equipe>/Externo/`), `lib/services/concluir_venda_service.dart:135` (`gerarESalvarPedidoLocal` grava `temp/`+`documents/`), `lib/services/carga_registry_service.dart:43` (`carga_manifest.json`), `lib/data/services/pac_xml_generator_service.dart:113` (`compressXmlToPac` ZIP) **devem permanecer intactos**. Nenhum refactor toca transporte FTP; apenas `TipoCarga.pedido` + `ped00_pacstr` são lidos/escritos.

## 0. Pré-requisitos e convenções

- **DB fonte:** `dbforcacad001.db` físico permanece; compatibilidade PRD `dbforcadig001.db`/`dig00`/`dig01` via DAO alias (Fase 1), sem renomear arquivo.
- **Tolerância schema:** toda escrita usa `PRAGMA table_info(pckvendig000/010):29` + `colNames.contains` (padrão já em `lib/action_code/salvar_carrinho_pedido.dart:29`). Novos campos adicionados via `ALTER TABLE ADD COLUMN IF NOT EXISTS` guardado por `try/catch`.
- **Validação por etapa:** `flutter analyze` + `flutter test` (`sqflite_common_ffi`) devem passar antes de avançar. Cada fase tem teste dedicado `test/pedidos_gap_*_test.dart`.
- **Feature flags:** `ICMS-ST` e `usysvenblk00` atrás de `bool kEnableIcmsSt / kEnableBloqueioFinanceiro` em `lib/app_constants.dart:1` para rollout gradual.

## Fase A — Models / Entities (dependência zero)

### A1. Enums de ciclo de vida `Tpckvendig00SttDIG/SttENV`
- **Arquivo:** `lib/domain/models/status_envio.dart:7`
- **Tarefas:**
  - [ ] Criar `enum PedidoSttDig { editando(0), digitado(1), finaliza(2) }` e `enum PedidoSttEnv { digitado(0), empacote(1), enviados(2), recebido(3) }` com `value` estável alinhado ao PRD `docs/specs/pedidos_prd.md:22` (`pvddsEDITANDO/pvddsDIGITADO/pdddsFINALIZA`, `pvddeDIGITADO/EMPACOTE/ENVIADOS/RECEBIDO`).
  - [ ] Manter `enum StatusEnvio {naoEnviado, jaEnviado, retornado}` como `@deprecated` alias para compat (`lib/services/status_envio_db.dart:23` o consome).
  - [ ] Acrescentar `extension` `toStatusEnvio()` para migração.
- **Validação:** `test/pedidos_gap_a1_status_enum_test.dart` — asserts `PedidosSttDig.editando.value==0`, `PedidosSttEnv.recebido.value==3`, alias não quebra.

### A2. Snapshots header + identidade
- **Arquivos:** `lib/domain/models/pedido_venda.dart:42` (`PedidoVenda`), `lib/backend/schema/structs/item_pedido_struct.dart:1`
- **Tarefas:**
  - [ ] `PedidoVenda`: adicionar `String clides, lindes, plades` (TEXT snapshots PRD `dig00_clides/lindes/plades:10`) + `int digTab` (`dig00_digtab`) + `int bonfrcven` (`dig00_bonfrcven`) + `PedidoSttDig sttDig` + `PedidoSttEnv sttEnv`.
  - [ ] `PedidoVenda`: adicionar `int codTab` construtor `required this.codTab` (default 0 para compat).
  - [ ] `ItemPedidoStruct`: adicionar `double mulver` / `double unidadeComercial` + `String embalagem` (para `pro00_mulver/cadproemb02`).
  - [ ] Atualizar `toMap/fromMap` e `equality` nos structs.
- **Validação:** `flutter analyze` sem `missing_required_argument`; testes de serialização.

### A3. Produto — multiplicador e faixa preço
- **Arquivo:** `lib/backend/schema/structs/produto_result_struct.dart:1`
- **Tarefas:**
  - [ ] Adicionar `double mulver` (`pro00_mulver`), `double pcomin`, `double pcomax`, `double commax`, `int codtrb`, `bool freadpco` (editável preço), `String unidade` já existe.
  - [ ] Estender `ProdutoResultStruct` construtor com defaults `mulver=1.0, pcomin=0, pcomax=999999, commax=100`.
- **Validação:** `test/pedidos_gap_a3_produto_struct_test.dart`.

## Fase B — Lógica de Cálculo / Regras de Negócio (depende de A)

### B1. Correção higiênica `fattot` + casas decimais
- **Arquivos:** `lib/action_code/carregar_pedido_resumo.dart:100`, `lib/pages/pedido_resumo/pedido_resumo_widget.dart:158`, `lib/data/services/pac_xml_generator_service.dart:59`
- **Tarefas:**
  - [ ] Trocar `fattot = digtot + subtot` para `fattot = digtot - subtot` quando `kEnableIcmsSt==true` (PRD `ffrmdigvenmov04:21` `dig00_fattot = dig00_digtot - dig00_subtot`). Quando flag off, manter `+` e documentar com comentário `// PRD §2.C`.
  - [ ] Unificar `toStringAsFixed` no XML: criar helper `lib/functions/format_currency.dart` `fmtCurrency(double v, {int casas=2})` usando `CCur` 2 casas; substituir `59,79,80,85,86,92,94` de `3` para `2` quando `kEnableCurrency2Casas`.
  - [ ] Teste: `test/pedidos_gap_b1_fattot_currency_test.dart`.

### B2. Persistência — gravar snapshots e identidade
- **Arquivos:** `lib/action_code/salvar_carrinho_pedido.dart:37`, `lib/services/concluir_venda_service.dart:77`, `lib/action_code/concluir_venda_process.dart:24`
- **Tarefas:**
  - [ ] `salvar_carrinho_pedido.dart:37` — estender `insertCols` para `ped00_codfil/codrep/digtab/clides/lindes/plades/datsys/sttdig/sttenv/bonfrcven`. Resolver `codFil` via `resolverCodFilial(AppState().empresa_codigo)` + `ven00_codfil` futuro; `datsys=DateFormat('yyyy-MM-dd')`.
  - [ ] Antes do `INSERT OR REPLACE`, executar `ALTER TABLE pckvendig000 ADD COLUMN ped00_clides TEXT` (e demais) em `try/catch` se `PRAGMA` não contém.
  - [ ] `concluir_venda_service.dart:77` — estender `addUpdate` para mesmos campos + `ped00_fattot`. Garantir `UPDATE ... WHERE ped00_numped=?` não sobrescreve `clis` se já gravado.
  - [ ] `concluir_venda_process.dart:24` — popular `PedidoVenda(clides: clienteNome, lindes: linhaDescricao, plades: planoDescricao, digTab: codTab, bonfrcven: chkBon, sttDig: digitado, sttEnv: digitado)`.
- **Validação:** `test/pedidos_gap_b2_persistencia_test.dart` com `sqflite_common_ffi` DB temporário; verificar snapshots sobrevivem a `UPDATE cadcli00 SET desci='Novo'`.

### B3. Alias `dbforcadig001` / `dig00`/`dig01`
- **Arquivos:** `lib/data/services/local_sales_database_service.dart:11`, novo `lib/data/dao/pedido_dao.dart`
- **Tarefas:**
  - [ ] Criar `PedidoDao` que expõe ` Future<Database> get db` e helpers ` Future<List<Map>> queryDig00() => db.query('pckvendig000')` + `query('dig00')` via `SELECT * FROM pckvendig000` alias; idem `dig01`.
  - [ ] `local_sales_database_service.dart:11` — expor `static const aliasDig = 'dbforcadig001.db'` documentando que físico é `dbforcacad001.db` (sem renomear).
- **Validação:** teste de alias `SELECT * FROM dig00` via view temporária.

### B4. Conversão de embalagem `pro00_mulver`
- **Arquivos:** `lib/action_code/busca_produto.dart:138`, `lib/pages/pedido_itens_lista/pedido_itens_lista_widget.dart:145`, `lib/data/services/pac_xml_generator_service.dart:89`
- **Tarefas:**
  - [ ] `busca_produto.dart:138` — `SELECT pro00_mulver, pro00_pcomin, pro00_pcomax, pro00_commax, pro00_codtrb` e mapear para `ProdutoResultStruct`.
  - [ ] `pedido_itens_lista_widget.dart:145` — `_incrementarQuantidade` calcular `unidadeComercial = qtdCaixas * produto.mulver` (quando `txtembalagem` selecionado via `Dropdown` de `cadproemb02`). Exibir `unidade` no card `lib/pages/pedido_itens_lista/pedido_itens_lista_widget.dart:553`.
  - [ ] `pac_xml_generator_service.dart:89` — escrever `pac01_mulven/mulemb/percmb` reais em vez de `0`.
  - [ ] Respeitar `ven00_chkest` flag: carregar `cadven00.ven00_chkest` em `AppState` no login; só chamar `_getSaldoEstoque` se `chkest==1`.
- **Validação:** `test/pedidos_gap_b4_mulver_test.dart`.

### B5. ICMS-ST `Tsysfis00ICMSSubst`
- **Arquivos:** novo `lib/domain/services/icms_st_service.dart`, `lib/action_code/concluir_venda_process.dart:42`, `lib/domain/models/pedido_venda.dart:74`
- **Tarefas:**
  - [ ] Implementar `IcmsStService.calcBASE({MVA, base})`, `calcSubs({baseST, aliqExt, baseProp, aliqInt})`, `isSubstituicaoPCO({codtrb, cliest})` conforme `usysvenfis00.txt:35`.
  - [ ] `concluir_venda_process.dart:42` — `subtot = icmsSt.calcSubs(filter)` em vez de `totalItem`; guardar `dig01_subtot` por item.
  - [ ] `pedido_venda.dart:74` — `dig00_subtot = sum(subtot)` (imposto), `digtot` permanece `qtd*pco` líquido.
  - [ ] Feature-flag `kEnableIcmsSt=false` por padrão; quando off, `subtot=0`.
- **Validação:** `test/pedidos_gap_b5_icms_st_test.dart` fixtures com `MVA=0.4`, `aliqExt=0.18`.

### B6. Travas `ValidePCOValues` / `ValideQTDValues`
- **Arquivos:** novo `lib/domain/services/valide_pco_service.dart`, `lib/pages/pedido_itens_lista/pedido_itens_lista_widget.dart:145`, `lib/action_code/validar_produto.dart:19`
- **Tarefas:**
  - [ ] Implementar `ValidePCOValues({pcomin,pcomax,commax,digpco,destot})` retorna `ValidationResultStruct` PRD `532`; checar `freadpco` antes de permitir edição `txtpco`.
  - [ ] `validar_produto.dart:19` — estender para `preco < pcomin => 'Preço abaixo do mínimo'`, `preco > pcomax => 'Preço acima do máximo'`, `destot > commax`.
  - [ ] Chamar no `btnkeyenter` de `pedido_itens_lista_widget.dart:145` antes de `existing.quantidade++`.
- **Validação:** `test/pedidos_gap_b6_valide_pco_test.dart`.

## Fase C — UI / Validações de Tela (depende de A+B)

### C1. Bloqueio financeiro `usysvenblk00`
- **Arquivos:** novo `lib/domain/services/bloqueio_financeiro_service.dart`, `lib/pages/pedido_novo_inicio/pedido_novo_inicio_widget.dart:500`
- **Tarefas:**
  - [ ] Carregar `cli00_crelim/creatu` e `dup00_datven` (via `lib/action_code/carregar_cliente_offline.dart:90` já tem `crelim/creatu`; estender para duplicatas).
  - [ ] Antes de `obterProximoNumeroPedido()` `pedido_novo_inicio_widget.dart:807`, executar `if(digtot + creatu > crelim) bloqueia` e `if(temDuplicataAtrasada(diasAtrasado)) bloqueia` com dialog PRD `42-45` (senha liberação futura `TODO`).
  - [ ] Corrigir display `lib/pages/pedido_novo_inicio/pedido_novo_inicio_widget.dart:765` — `Limite Disponível = crelim - creatu`.
- **Validação:** `test/pedidos_gap_c1_bloqueio_test.dart`.

### C2. `doPEDPost` / `doPEDAbort` fiel + bloqueio grid
- **Arquivos:** `lib/pages/pedido_itens_lista/pedido_itens_lista_widget.dart:217,958`, `lib/action_code/concluir_venda_process.dart:19`
- **Tarefas:**
  - [ ] `doPEDPost`: ao concluir, `UPDATE pckvendig000 SET ped00_sttdig=1 (DIGITADO)` e desabilitar `ListView` edição (guard `if(sttDig==digitado) return` nos `+/-`).
  - [ ] `doPEDAbort` `lib/pages/pedido_itens_lista/pedido_itens_lista_widget.dart:958` — trocar `DELETE FROM pckvendig010` sem `WHERE` (risco) por `DELETE WHERE ped10_numped=?` sempre; limpar `children` memória `carrinhoItens.clear()` já existe, mas adicionar `ped00_sttdig=0` rollback.
  - [ ] Reabertura pedido `DIGITADO` via `PedidosRascunhosPageWidget` (futuro) — `TODO` comentário.
- **Validação:** `test/pedidos_gap_c2_post_abort_test.dart`.

### C3. Bonificação `ven00_gerbonfor` + `bon00_venmax` + combos
- **Arquivos:** `lib/components/bottom_sheet_selecao_bonificacao/bottom_sheet_selecao_bonificacao_widget.dart`, `lib/components/bottom_sheet_combos/bottom_sheet_combos_widget.dart`, `lib/data/services/pac_xml_generator_service.dart:60`
- **Tarefas:**
  - [ ] Carregar `ven00_gerbonfor` no login (`first_access_login.dart`/`offline_login.dart`); só exibir `chk_bonfrcven` Toggle no header se `gerbonfor==1`; persistir `dig00_bonfrcven` e escrever `pac00_bonfrcven` dinâmico.
  - [ ] Validar `bon00_venmax` ao incrementar kit `BottomSheetSelecaoBonificacaoWidget` com mensagem PRD `Você está excedendo o nº máximo de bonificações.` `48`.
  - [ ] Combo: validar `Combo inválida` / `Estoque insuficiente` / `Quantidade máxima excedida` `47` antes de `salvarCarrinhoPedido` `lib/pages/pedido_itens_lista/pedido_itens_lista_widget.dart:841`.
- **Validação:** `test/pedidos_gap_c3_bonificacao_combo_test.dart`.

### C4. Confirmação inclusão + mensagens PRD
- **Arquivo:** `lib/pages/pedido_itens_lista/pedido_itens_lista_widget.dart:790`
- **Tarefas:**
  - [ ] Ao confirmar combo, exibir `AlertDialog "Deseja incluir os produtos na digitação?"` PRD `47` antes de `addAll(novosItens)`.
- **Validação:** widget test de dialog.

### C5. Higiene `salvar_item_pedido.dart` + `salvar_carrinho_pedido.dart`
- **Arquivos:** `lib/action_code/salvar_item_pedido.dart:38`, `lib/action_code/salvar_carrinho_pedido.dart:102`
- **Tarefas:**
  - [ ] `salvar_item_pedido.dart:38` — adicionar `ped10_numped` obrigatório ou deprecar e remover import dead.
  - [ ] `salvar_carrinho_pedido.dart:102` — remover `DELETE FROM pckvendig010` sem `WHERE`; substituir por `return false` + log.
- **Validação:** `flutter analyze` sem `warning`.

## Checklist de Execução (ordem de dependência)

```
[ ] A1 status enums (base para B2/C2)
[ ] A2 snapshots header (base para B2)
[ ] A3 produto mulver/pcomin/pcomax (base para B4/B6)
[ ] B1 fattot/currency (cirúrgico, sem dependência)
[ ] B5 higiene DELETE dead code (cirúrgico)
[ ] B2 persistência snapshots
[ ] B3 alias dig00/dig01
[ ] B4 embalagem mulver + ven00_chkest
[ ] B5 ICMS-ST (flag off)
[ ] B6 ValidePCOValues
[ ] C1 bloqueio financeiro
[ ] C2 doPEDPost/doPEDAbort + trava grid
[ ] C3 bonificação/combo
[ ] C4 confirmação inclusão
[ ] Testes de regressão FTP intacto: flutter test (carga_registry, ftp_upload, pac_xml, concluir_venda_service)
```

## Critérios de Aceite por Fase

- **A:** `flutter analyze` 0 issues; `flutter test` existente passa; novos testes `a1-a3` verdes.
- **B:** `digtot/bontot/subtot/fattot` conferem com fixtures PRD `docs/specs/pedidos_prd.md:37`; XML 2 casas; `pckvendig000` contém snapshots após `doPEDCreate`.
- **C:** Fluxo `ffrmdigvenmov00->01->07->04->rel00` simulado em widget test; bloqueio crédito/títulos dispara dialog; combo/bonificação mensagens PRD aparecem.

## Riscos e Mitigação

- **Risco DB divergente:** mitigado por DAO alias + `ALTER TABLE` incremental.
- **Risco fiscal:** `ICMS-ST` atrás de flag; rollout com `kEnableIcmsSt=false` até homologação `Tsysfis00`.
- **Risco FTP:** **nenhum arquivo FTP é tocado** nesta fase; `flutter test test/ftp_upload_service_test.dart` deve permanecer verde a cada PR.
