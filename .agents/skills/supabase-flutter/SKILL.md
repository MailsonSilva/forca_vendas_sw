---
name: supabase-flutter
description: Integração Flutter com Supabase (Auth, Database, Storage, Realtime). Use ao autenticar usuários, ler/escrever dados remotos, subir arquivos ou assinar mudanças em tempo real.
---

# Skill: Supabase no Flutter

Backend padrão deste harness para dados em nuvem. Combina com `local-first-data` para modo offline.

## 1. Setup Mínimo
- Pacote `supabase_flutter`; inicialização única no `main.dart` com URL e anon key via `--dart-define` (nunca hardcodadas no repo).
- Cliente acessível via repositório (`Supabase.instance.client`), nunca direto no widget.

## 2. Auth
- Login social e e-mail/senha via `supabase.auth`; sessão persistida automaticamente.
- Telas reagem a `onAuthStateChange` (ex.: redirecionar para login ao deslogar).
- JWT do usuário propaga o `auth.uid()` usado nas políticas RLS.

## 3. Database e RLS
- Toda tabela exposta ao app **exige RLS ativado** com políticas por `auth.uid()`; sem política, sem acesso.
- Leituras com paginação (`range`) e filtros no servidor — nunca baixar tabelas inteiras para filtrar no cliente.
- Escritas críticas via funções Postgres (`rpc`) quando precisarem de transação atômica.

## 4. Storage e Realtime
- Uploads com caminhos por usuário (`<uid>/<arquivo>`) e buckets com políticas RLS espelhadas.
- Realtime apenas em canais necessários (chat, notificações); fechar a subscription no `dispose`/`ref.onDispose`.
