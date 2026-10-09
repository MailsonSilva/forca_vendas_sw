---
name: flutter-use-http-package
description: Networking REST com package:http (GET/POST/PUT/DELETE, erros, parsing isolado). Use ao consumir APIs remotas em services/repositórios da camada Data.
---

# Skill: Networking REST (package:http)

> Adaptado de `flutter/agent-plugins` (time oficial do Flutter, licença BSD-3-Clause).
> Regra do harness: HTTP vive em services (`data/` ou `core/network/`), nunca em widgets/Notifiers.

## 1. Setup e Permissões
```bash
flutter pub add http
```
- Android: `<uses-permission android:name="android.permission.INTERNET" />` no `AndroidManifest.xml`.
- Token/keys via `--dart-define`, nunca no código.

## 2. Execução e Erros
- URLs sempre com `Uri.parse`; headers de auth/content-type no parâmetro `headers`.
- POST/PUT com `jsonEncode`; sucesso = 200 (GET/PUT/DELETE) ou 201 (POST).
- **Falha nunca retorna null**: lança exceção de domínio (ex.: `NetworkFailure`) — o `AsyncValue.error` vira ErrorState na UI.
- Desserializa com `fromJson` tipado; listas grandes via `compute()` (isolate) para não derrubar frames.

## 3. Workflow (checklist)
- [ ] Model + `fromJson`.
- [ ] Método no service retornando `Future<Model>`.
- [ ] `statusCode` validado + exceção em falha.
- [ ] Teste unitário do service com cliente mockado (sucesso + 4xx/5xx + timeout).
- [ ] Repositório consome o service e expõe modelo de domínio.

## 4. Exemplo Mínimo (service + parsing isolado)

```dart
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

List<Item> parseItems(String body) => (jsonDecode(body) as List)
    .map((e) => Item.fromJson(e as Map<String, dynamic>))
    .toList();

class ItemApi {
  ItemApi(this._client, this._base);
  final http.Client _client;
  final Uri _base;

  Future<List<Item>> fetchAll(String token) async {
    final res = await _client.get(
      _base.replace(path: '/items'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (res.statusCode != 200) throw NetworkFailure();
    return compute(parseItems, res.body);
  }
}
```
