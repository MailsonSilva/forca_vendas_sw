# Plano — PRD 1 `pedidos_prd_1.md` — Fase 1 Filial (§1.5) + Gap Closure

> Preservação: `lib/data/services/pac_xml_generator_service.dart:113`, `lib/services/ftp_upload_service.dart:161`, `lib/services/ftp_path_builder.dart:62`, `lib/services/concluir_venda_service.dart:135` intactos.

## Decisões (2026-08-27)
- Q1 XML: legado `<root><pckvenpac00>` default; `<PacoteVendas>` atrás de flag off (não nesta fase)
- Q2 Filial: seleção **obrigatória/bloqueante** quando count>1
- Q3 Agente: tabela definitiva `codage00` (cadagt00 fallback)

## Fase F1 — Filial (§1.5) — EXECUTADA
- [x] F1.1 `lib/action_code/contar_filiais.dart` — COUNT + list cadfil00 com PRAGMA tolerante
- [x] F1.2 `lib/components/modal_selecao_filial/modal_selecao_filial_widget.dart` — BottomSheet bloqueante
- [x] F1.3 `lib/app_state.dart:236` codFilialAtiva/filialAtivaDes persistido + `lib/functions/resolver_cod_filial.dart:1` prioriza ativa
- [x] F1.4 Hook `lib/pages/login_page/login_page_widget.dart:364` ambos ramos (first_access + offline) chamam `_selecionarFilialSeNecessario()` antes de HomePage
- [x] F1.5 `flutter analyze` 14 issues 0 errors + `flutter test` 36 passed (2026-08-27)

## Fase F2 — Agente codage00 (§2 + §4A) — EXECUTADA
- [x] F2.1 `lib/domain/models/agente_cobrador.dart:1` — model `AgenteCobrador` com `fromMap` tolerante age00_/agt00_ + `toMapCodage`
- [x] F2.2 `lib/action_code/carregar_agentes_cobrador.dart:10` — codage00 primário, cadagt00 fallback; + `carregarAgentesCobradoresTipados()` para tipo
- [x] F2.3 `lib/domain/models/pedido_venda.dart:57` +tipoAgente (age00_tipo→dig00_digcob), `lib/services/concluir_venda_service.dart:91` ALTER ped00_digcob, `lib/action_code/concluir_venda_process.dart:67` lookup tipoAgente
- [x] F2.4 `lib/pages/pedido_novo_inicio/pedido_novo_inicio_widget.dart:23` prefetch cli00_codage ao selecionar cliente, exibe Agente no Resumo
- [x] F2.5 `lib/action_code/carregar_pedido_resumo.dart:136` — busca descrição em codage00 primeiro, fallback cadagt00
- [x] F2.6 `flutter analyze` 14 issues 0 errors + `flutter test` 36/36 passed (2026-08-27, flaky ZIP timing re-run OK)

## Fase F3 — PacoteVendas + retornaMil + JEnviado batch (§5) — EXECUTADA
- [x] F3.1 `lib/functions/retorna_mil.dart:1` — helper `retornaMil({now})` %100000 + `retornaMil6`
- [x] F3.2 `lib/services/ftp_path_builder.dart:66` — `getFileNameClienteMil(rep,{ms})` → c<rep>-<ms>.xml (PRD 5A)
- [x] F3.3 `lib/data/services/pacote_vendas_xml_service.dart:1` — schema `<PacoteVendas>` atrás de `kEnablePacoteVendasSchema=false` `lib/app_constants.dart:5` (Q1 legado default)
- [x] F3.4 `lib/services/status_envio_db.dart:44` — `marcarPedidosEnviados(List<int>)` + `marcarClientesEnviados` com UPDATE IN (...) transacional PRD 5B
- [x] F3.5 `lib/services/ftp_upload_service.dart:161` — JEnviado só após SIZE ok; batch via novo método (per-file mantido, lista em memória CargaRegistro já satisfaz §5B)
- [x] F3.6 `flutter analyze` 14 issues 0 errors + `flutter test` 36/36 passed (2026-08-27, re-run OK flaky ZIP)
