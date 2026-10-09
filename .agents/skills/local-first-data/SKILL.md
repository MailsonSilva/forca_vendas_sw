---
name: local-first-data
description: Persistência local-first em Flutter com Drift/SQLite (migrations, sync, batch). Use ao modelar banco local, versionar schema, operar offline ou sincronizar com a nuvem.
---

# Skill: Dados Local-First (Drift/SQLite + Sync)

Estende a seção 4 de `.agents/rules/mobile.md` com o protocolo operacional.

## 1. Modelagem com Drift
- Tabelas Drift espelham as entidades do domínio; DAOs expõem `Stream`s para a UI reagir a mudanças locais.
- Colunas de controle obrigatórias em tabelas sincronizáveis: `updated_at`, `deleted` (soft-delete) e `dirty` (pendente de envio).

## 2. Migrations
- `schemaVersion` incrementado a cada mudança; cada versão tem `MigrationStrategy` com `onUpgrade` testado.
- Teste de migration: banco antigo em asset → migra → valida dados preservados.

## 3. Operações
- Inserções/atualizações em lote dentro de transação (`batch`); leituras de lista sempre paginadas (`limit`/`offset`).
- Índices em toda coluna usada em `WHERE`, `ORDER BY` ou chave estrangeira.

## 4. Sincronização com Supabase
- Fila de saída: registros `dirty` enviados em ordem, com backoff em falha de rede.
- Fila de entrada: buscar por `updated_at > last_sync` (sync incremental, nunca full-refresh).
- Conflito: última escrita por `updated_at` vence; deleção remota propaga soft-delete local.
- Indicador de sync visível na UI (sincronizado / pendente / erro) — nunca falhar silenciosamente.
