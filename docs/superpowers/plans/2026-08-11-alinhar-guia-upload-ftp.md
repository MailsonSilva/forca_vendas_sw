# Alinhar Guide Upload FTP Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Align the existing Flutter `.pac`/FTP implementation with `docs/Guia_Upload_FTP_Flutter.md` and close the test gaps, ensuring the full flow (sequential naming → XML → ZIP `.pac` → FTP upload → flag update → cleanup) is verified.

**Architecture:** All core components already exist (`PacXmlGeneratorService`, `ClienteXmlGeneratorService`, `FtpUploadService`, `CargaRegistryService`, `StatusEnvioDb`, `FtpPathBuilder`, `ConcluirVendaService`, `obterProximoNumeroPedido`). This plan completes the guide's sequential-naming alignment already in the working tree, adds the missing test files, and runs the full suite/analyze.

**Tech Stack:** Flutter 3 (SDK `>=3.0.0 <4.0.0`), `archive` ^3.3.2 (ZIP), `path_provider` 2.1.4, `ftpconnect`/raw-socket `FtpClient` (socket `FtpTransport`), `sqflite` + `sqflite_common_ffi` (tests), `flutter_test`.

## Global Constraints

- Nomenclature oficial do pedido: `p<codigoRepresentante>-<codigoSequencialPacote>.pac` (ex: `p71-32504.pac`), sequência de `MAX(ped00_numped)+1` da tabela `pckvendig000` — NUNCA milissegundos Unix (`docs/Guia_Upload_FTP_Flutter.md` §2 item 4).
- Nome do cliente: `c<codRep>-<ms>.xml` para inclusão (`cli00_codigo == 0`), `c<codRep>-<cli00_codigo>.xml` para edição (`guia` §3.A).
- `.pac` é um arquivo **ZIP renomeado** (magic `PK`, `0x50 0x4B`) gerado com `archive`, salvo em `getTemporaryDirectory()`.
- Paths FTP remotos (comentados como `dirPAC`/`dirCAD` no guia): `/empresa/equipe/Externo/` (pedidos), `/empresa/equipe/Customer/` (clientes), `/empresa/equipe/Upload/` (geral); empresa fallback `diniz`, equipe formatada com 2 dígitos.
- Upload em lote: uma única conexão FTP, navegação `CWD`/`MKD`, `STOR`, confirmação por `SIZE`, marcação de flag `JEnviado (1)` via manifesto em memória, e **deleção** do temp após sucesso; falha mantém o arquivo na fila (retry).
- Serviços de geração são **puros** (sem I/O); a escrita em disco vive em `ConcluirVendaService`/actions. Dependências de I/O injetáveis para testes.

---

### Task 1: Testes do gerador de XML de pedido (`PacXmlGeneratorService.generate`)

**Files:**
- Create: `test/pac_xml_generator_service_test.dart`

**Interfaces:**
- Consumes: `PacXmlGeneratorService.generate(PedidoVenda) → String` (firma em `lib/data/services/pac_xml_generator_service.dart`), `PedidoVenda`/`ItemPedidoVenda` (`lib/domain/models/pedido_venda.dart`).
- Produces: cobertura de TODOS os atributos `pac00_*`/`pac01_*` do envelope legado (nada para tasks posteriores consumirem; valida contrato do guia §2/`refatoração.md`).

- [ ] **Step 1: Escrever o teste que falha (arquivo sonho)**

Create `test/pac_xml_generator_service_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:forca_de_vendas/data/services/pac_xml_generator_service.dart';
import 'package:forca_de_vendas/domain/models/pedido_venda.dart';

void main() {
  PedidoVenda sample() {
    final pedido = PedidoVenda(
      codFil: 1,
      codMov: 32504,
      codRep: 71,
      codCli: 1542,
      codLin: 5,
      codPla: 3,
      codAgt: 71,
      datSys: '2026-08-11',
      items: [
        ItemPedidoVenda(
          digpro: '78945',
          digqtd: 10.0,
          digpco: 150.05,
          pcomax: 150.05,
          pcomin: 150.05,
          destot: 0.0,
          subtot: 1500.50,
          bontyp: 0,
          boncod: 0,
          ccvtot: 0.0,
          digitm: 1,
        ),
      ],
    );
    pedido.calcularTotais();
    return pedido;
  }

  test('generate() produz envelope legacy com rep00_codigo', () {
    final xml = PacXmlGeneratorService.generate(sample());
    expect(xml, contains('<!DOCTYPE suportware>'));
    expect(xml, contains('<root sys_versao="1.0" rep00_codigo="71">'));
    expect(xml, contains('<pckvenpac00>'));
    expect(xml, contains('</pckvenpac00>'));
    expect(xml, contains('</root>'));
  });

  test('generate() mapeia cabeçalho pac00_* e sequencial do pacote', () {
    final xml = PacXmlGeneratorService.generate(sample());
    expect(xml, contains('pac00_pacrep="71"'));
    expect(xml, contains('pac00_paccod="32504"'));
    expect(xml, contains('pac00_pacqtd="1"'));
    expect(xml, contains('pac00_pactot="1500.500"'));
    expect(xml, contains('pac00_clicod="1542"'));
    expect(xml, contains('pac00_lincod="5"'));
    expect(xml, contains('pac00_placod="3"'));
    expect(xml, contains('pac00_agtcod="71"'));
    expect(xml, contains('pac00_digfil="1"'));
  });

  test('generate() mapeia itens pac01_*', () {
    final xml = PacXmlGeneratorService.generate(sample());
    expect(xml, contains('pac01_paccod="32504"'));
    expect(xml, contains('pac01_pacitm="1"'));
    expect(xml, contains('pac01_procod="78945"'));
    expect(xml, contains('pac01_qtd="10.000"'));
    expect(xml, contains('pac01_pco="150.050"'));
    expect(xml, contains('<cot00/>'));
  });

  test('generate() não vaza campos dig00_/dig01_/rep00 avulsos', () {
    final xml = PacXmlGeneratorService.generate(sample());
    expect(xml, isNot(contains('dig00_')));
    expect(xml, isNot(contains('dig01_')));
    expect(xml, isNot(contains('<rep00 ')));
  });
}
```

- [ ] **Step 2: Rodar e confirmar falha (arquivo inexistente)**

Run: `flutter test test/pac_xml_generator_service_test.dart`
Expected: FAIL — "Target of URI doesn't exist" (arquivo do teste ainda não existe).

- [ ] **Step 3: Criar o arquivo de teste com o conteúdo acima**

Sinônimo: o próprio arquivo é a implementação do teste; não há código de produção novo.

- [ ] **Step 4: Executar e confirmar PASS**

Run: `flutter test test/pac_xml_generator_service_test.dart`
Expected: 4 testes PASS.

- [ ] **Step 5: Commit**

```bash
git add test/pac_xml_generator_service_test.dart
git commit -m "test: cobre estrutura XML legada do gerador PAC"
```

---

### Task 2: Testes de geração local do `.pac` (`ConcluirVendaService.gerarESalvarPedidoLocal`)

**Files:**
- Modify: `lib/services/concluir_venda_service.dart` (injeção de diretórios/registry para testabilidade — padrão já usado por `FtpUploadService`)
- Create: `test/concluir_venda_service_test.dart`

**Interfaces:**
- Consumes: `PacXmlGeneratorService`, `CargaRegistryService`, `FtpPathBuilder.getFileNamePedido`.
- Produces: `ConcluirVendaService({getTemporaryDirectoryFn, getDocumentsDirFn, registry})` — construtor testável compatível com chamadas atuais (`ConcluirVendaService()`).

- [ ] **Step 1: Escrever o teste que falha primeiro**

Criar primeiro o comportamento alvo. Como o construtor hoje não é injetável, o teste define a forma desejada (TDD). Usar `sqflite_common_ffi` e um fake `getDatabasesPath` via factory override para `doUpdateStatistics`:

`test/concluir_venda_service_test.dart`:

```dart
import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:forca_de_vendas/data/services/pac_xml_generator_service.dart';
import 'package:forca_de_vendas/domain/models/pedido_venda.dart';
import 'package:forca_de_vendas/services/carga_registry_service.dart';
import 'package:forca_de_vendas/services/concluir_venda_service.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late Directory tempDir;
  late Directory docsDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('concluir_test_');
    docsDir = await Directory.systemTemp.createTemp('concluir_docs_');
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    if (docsDir.existsSync()) docsDir.deleteSync(recursive: true);
  });

  PedidoVenda sample() => PedidoVenda(
        codFil: 1, codMov: 32504, codRep: 71, codCli: 1542,
        codLin: 5, codPla: 3, codAgt: 71, datSys: '2026-08-11',
        items: [
          ItemPedidoVenda(
            digpro: '78945', digqtd: 10.0, digpco: 150.05,
            pcomax: 150.05, pcomin: 150.05, destot: 0.0,
            subtot: 1500.50, bontyp: 0, boncod: 0,
            ccvtot: 0.0, digitm: 1,
          ),
        ],
      );

  test('gera arquivo .pac em temp com nomenclatura sequencial e ZIP válido', () async {
    final service = ConcluirVendaService(
      getTemporaryDirectoryFn: () async => tempDir,
      getDocumentsDirFn: () async => docsDir,
      registry: CargaRegistryService(
        manifestPath: p.join(tempDir.path, 'carga_manifest.json'),
      ),
    );

    final fileName = await service.gerarESalvarPedidoLocal(
      pedido: sample(),
      empresa: 'diniz',
      codigoEquipe: 71,
    );

    expect(fileName, 'p71-32504.pac');
    final file = File(p.join(tempDir.path, 'p71-32504.pac'));
    expect(await file.exists(), isTrue);
    final bytes = await file.readAsBytes();
    expect(bytes.sublist(0, 2), [0x50, 0x4B]); // ZIP magic

    final archive = ZipDecoder().decodeBytes(bytes);
    expect(archive.length, 1);
    final xml = utf8.decode(archive.first.content as List<int>);
    expect(xml, contains('<root sys_versao="1.0" rep00_codigo="71">'));
    expect(
      PacXmlGeneratorService.compressXmlToPac(xml),
      equals(bytes),
    );
  }, skip: 'arquivo de produção ainda não aceita injeção');

  test('registra arquivo→id no manifesto e grava também em documents/', () async {
    final registry = CargaRegistryService(
      manifestPath: p.join(tempDir.path, 'carga_manifest.json'),
    );
    final service = ConcluirVendaService(
      getTemporaryDirectoryFn: () async => tempDir,
      getDocumentsDirFn: () async => docsDir,
      registry: registry,
    );

    final fileName = await service.gerarESalvarPedidoLocal(
      pedido: sample(),
      empresa: 'diniz',
      codigoEquipe: 71,
    );

    final registros = await registry.listar();
    expect(registros.length, 1);
    expect(registros.single.arquivo, 'p71-32504.pac');
    expect(registros.single.tipo, TipoCarga.pedido);
    expect(registros.single.id, 32504);
    expect(await File(p.join(docsDir.path, fileName)).exists(), isTrue);
  }, skip: 'arquivo de produção ainda não aceita injeção');
}
```

- [ ] **Step 2: Rodar para confirmar falha de compilação do teste**

Run: `flutter test test/concluir_venda_service_test.dart`
Expected: FAIL — construtor `ConcluirVendaService({getTemporaryDirectoryFn, ...})` não existe ainda.

- [ ] **Step 3: Adicionar injeção de dependências ao construtor**

Em `lib/services/concluir_venda_service.dart`, adicionar campos e construtor injetáveis (mantendo `ConcluirVendaService()` default), espelhando `FtpUploadService`:

```dart
import 'package:path_provider/path_provider.dart';
import 'carga_registry_service.dart';

class ConcluirVendaService {
  ConcluirVendaService({
    Future<Directory> Function()? getTemporaryDirectoryFn,
    Future<Directory> Function()? getDocumentsDirFn,
    CargaRegistryService? registry,
  })  : _getTemporaryDirectoryFn =
            getTemporaryDirectoryFn ?? getTemporaryDirectory,
        _getDocumentsDirFn =
            getDocumentsDirFn ?? getApplicationDocumentsDirectory,
        _registry = registry ?? CargaRegistryService();

  final Future<Directory> Function() _getTemporaryDirectoryFn;
  final Future<Directory> Function() _getDocumentsDirFn;
  final CargaRegistryService _registry;
```

Substituir, em `gerarESalvarPedidoLocal`, as chamadas `getTemporaryDirectory()`/`getApplicationDocumentsDirectory()`/`CargaRegistryService().registrar(...)` por `_getTemporaryDirectoryFn()`/`_getDocumentsDirFn()`/`_registry.registrar(...)`. Manter `enviarPedidoFtp`/`_limparTemporarioDoPedido` usando os mesmos getters injetados onde aplicável. Remover depois os `skip:` dos dois testes.

- [ ] **Step 4: Rodar para confirmar PASS**

Run: `flutter test test/concluir_venda_service_test.dart`
Expected: 2 testes PASS.

- [ ] **Step 5: Verify nenhum outro caller quebra**

Run: `flutter analyze && flutter test`
Expected: sem erros de análise; todos os testes PASS (o restante da suíte usa `ConcluirVendaService()` sem args).

- [ ] **Step 6: Commit**

```bash
git add lib/services/concluir_venda_service.dart test/concluir_venda_service_test.dart
git commit -m "test: cobre geração local do pac com nomenclatura sequencial"
```

---

### Task 3: Testes do sequencial de pedido (`obterProximoNumeroPedido`)

**Files:**
- Modify: `lib/functions/proximo_numero_pedido.dart` (parâmetro `dbPath` opcional para testabilidade)
- Create: `test/proximo_numero_pedido_test.dart`

**Interfaces:**
- Consumes: `sqflite`, `sqflite_common_ffi`.
- Produces: `Future<int> obterProximoNumeroPedido({String? dbPath})` — contrato do guia: `MAX(ped00_numped)+1` de `pckvendig000`; fallback `1` quando banco/tabela ausentes.

- [ ] **Step 1: Escrever o teste que falha**

`test/proximo_numero_pedido_test.dart`:

```dart
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:forca_de_vendas/functions/proximo_numero_pedido.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late Directory dbDir;

  setUp(() async {
    dbDir = await Directory.systemTemp.createTemp('seq_pedido_');
  });

  tearDown(() {
    if (dbDir.existsSync()) dbDir.deleteSync(recursive: true);
  });

  Future<String> createDb(List<int> numeds) async {
    final path = p.join(dbDir.path, 'dbforcacad001.db');
    final db = await databaseFactory.openDatabase(path);
    await db.execute(
        'CREATE TABLE pckvendig000 (ped00_numped INTEGER PRIMARY KEY)');
    for (final n in numeds) {
      await db.insert('pckvendig000', {'ped00_numped': n});
    }
    await db.close();
    return path;
  }

  test('retorna MAX(ped00_numped)+1 em banco populado', () async {
    final path = await createDb([100, 120, 110]);
    expect(await obterProximoNumeroPedido(dbPath: path), 121);
  });

  test('retorna 1 em banco vazio', () async {
    final path = await createDb([]);
    expect(await obterProximoNumeroPedido(dbPath: path), 1);
  });

  test('retorna 1 quando o banco não existe (no-op seguro)', () async {
    expect(await obterProximoNumeroPedido(dbPath: 'sem/arquivo.db'), 1);
  });
}
```

- [ ] **Step 2: Rodar para confirmar falha**

Run: `flutter test test/proximo_numero_pedido_test.dart`
Expected: FAIL — assinatura `obterProximoNumeroPedido({dbPath})` não existe.

- [ ] **Step 3: Adicionar parâmetro `dbPath`**

Em `lib/functions/proximo_numero_pedido.dart`, alterar para:

```dart
Future<int> obterProximoNumeroPedido({String? dbPath}) async {
  try {
    final resolved = dbPath ??
        join(await getDatabasesPath(), 'dbforcacad001.db');
    if (!await File(resolved).exists()) return 1;
    final db = await openDatabase(resolved);
    // ... resto inalterado
  } catch (_) {
    return 1;
  }
}
```

- [ ] **Step 4: Rodar para confirmar PASS**

Run: `flutter test test/proximo_numero_pedido_test.dart`
Expected: 3 testes PASS.

- [ ] **Step 5: Analyzer + suíte completa**

Run: `flutter analyze && flutter test`
Expected: sem novos sinais; todos PASS (caller em `pedido_novo_inicio_widget.dart:807` usa chamada sem args — continua válida).

- [ ] **Step 6: Commit**

```bash
git add lib/functions/proximo_numero_pedido.dart test/proximo_numero_pedido_test.dart
git commit -m "test: cobre sequencial MAX(ped00_numped)+1 do nome do pac"
```

---

### Task 4: Alinhamento final aprovado da nomenclatura + suíte completa

**Files:**
- Verify: `lib/services/ftp_path_builder.dart`, `lib/services/concluir_venda_service.dart`, `docs/Guia_Upload_FTP_Flutter.md`
- Test: todo `test/`

**Interfaces:**
- Consumes: todos os componentes implementados nas Tasks 1–3 + `FtpUploadService`, `CargaRegistryService`, `StatusEnvioDb`, `ClienteXmlGeneratorService` já testados.

- [ ] **Step 1: Confirmar que nenhuma nomenclatura `ms` de pacote resta**

Buscar por `millisecondsSinceEpoch` em arquivos de pedido/pac. Único uso legítimo restante: `getFileNameCliente` para inclusão de cliente (`gerar_xml_cliente.dart:44,55`) e `ftp_path_builder.dart:69` (comentário) — conforme guia §3.A. Nenhum `p{codRep}-{ms}` pode restar:
`git grep -n "millisecondsSinceEpoch" -- lib/`
Expected: somente os 3 pontos acima (serialization/app_util são DateTime serial — ignorar).

- [ ] **Step 2: Rodar a suíte completa e analyze**

Run: `flutter analyze && flutter test`
Expected: 0 errors/lints novos; todos os testes (incl. `ftp_upload_service_test`, `carga_registry_service_test`, `cliente_xml_generator_service_test`, `status_envio_test`, `pac_compress_test`, `ftp_path_builder_test`, `pedido_venda_test`, `widget_test`, + Tasks 1–3) PASS.

- [ ] **Step 3: Ajustar guia se divergente**

Conferir que `docs/Guia_Upload_FTP_Flutter.md` §2 item 4 descreve `p{rep}-{sequencial}.pac` (já editado no working tree). Se hover divergência com o código, alinhar o texto do guia; senão não alterar.

- [ ] **Step 4: Commit da limpeza final**

```bash
git add docs/Guia_Upload_FTP_Flutter.md lib/services/ftp_path_builder.dart lib/services/concluir_venda_service.dart
git commit -m "docs: alinha guia upload FTP com nomenclatura sequencial do pac"
```

---

## Self-Review

**Spec coverage:** Guia §1 (XML) → Task 1; §2.4 nomenclatura sequencial → Task 3 + Task 4; §2.5 gravação `.pac` local → Task 2; §3 upload/limpeza → já implementado e testado em `ftp_upload_service_test.dart`/`carga_registry_service_test.dart` (Task 4 verifica suíte). Sem lacunas.

**Placeholder scan:** Sem "TBD"/"implement later"; cada passo tem código real. O `skip:` nos testes da Task 2 é intencional (red phase) e removido no Step 3.

**Type consistency:** `ConcluirVendaService` consome os mesmos tipos que `FtpUploadService` já usa (`CargaRegistryService`, `Future<Directory> Function()`); `obterProximoNumeroPedido({String? dbPath})` mantém chamadas sem args intactas. Nenhuma discrepância de nomes entre tasks.