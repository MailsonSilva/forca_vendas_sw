SPEC-053: Restauração Imediata e Reescrita das Consultas Locais (Produtos e Clientes)MetadadoDetalheMóduloCatálogo de Produtos e Carteira de Clientes (SQLite local)Origem Legadacadpro00, cadcli00, estpro00, estpcopro00, cadmar00   Arquivos Afetadoslib/action_code/busca_produto.dart, lib/action_code/pesquisa_cliente.dart, lib/pages/produtos/busca_produto_page/busca_produto_page_widget.dart[source: 2]StatusPronto para Execução Imediata1. Diagnóstico e Causa Raiz do Spinner InfinitoDestruição Prematura de Conexão (await db.close()):Ao final de cada execução, as custom actions fechavam o SQLite. Com isso, os FutureBuilder concorrentes ou novas digitações falhavam com DatabaseException(database closed). Como a exceção não era tratada pelo FlutterFlow, a tela ficava presa no CircularProgressIndicator para sempre.Incompatibilidade de Binds e Joins com OR:Junções contendo operadores OR (como amarrações com padding de filial e subqueries em tabelas de rascunhos) desativavam os índices B-Tree do SQLite nativo, convertendo uma busca de 10 milissegundos em um travamento de 60 segundos por Full Table Scan.Ausência do Preço de Venda:Na base legada, o preço do item não reside na cadpro00; ele fica registrado na tabela estpcopro00 (pro00_codpro, pro00_codtab, pro00_pcosub ou pro00_preco). A simplificação anterior eliminou essa junção, zerando o preço de todo o catálogo.   2. Implementação das Consultas SQL Canônicas2.1. Produtos (lib/action_code/busca_produto.dart)Substituição completa do arquivo eliminando qualquer chamada a PRAGMA table_info, eliminando await db.close(), integrando a tabela de preços estpcopro00 e calculando o saldo da filial ativa via estpro00:   Dartimport 'dart:io';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '/backend/schema/structs/index.dart';
import '../app_state.dart';

Database? _dbCargaInstancia;

Future<Database> _getDbCarga() async {
  if (_dbCargaInstancia != null && _dbCargaInstancia!.isOpen) {
    return _dbCargaInstancia!;
  }
  final dbPath = join(await getDatabasesPath(), 'dbforcacad001.db');
  _dbCargaInstancia = await openDatabase(dbPath, readOnly: true);
  return _dbCargaInstancia!;
}

Future<List<ProdutoResultStruct>> buscaProduto(
  String? filtro,
  String? ultimoDescri,
  String? filtroLinha,
  String? filtroGrupo,
  String? filtroFabricante,
  String? filtroMarca,
  bool? apenasEstoque,
  bool? apenasPromocao,
  int? codFilial,
  String? dataEntrada, [
  int? codTabela,
  int? offset,
]) async {
  try {
    final db = await _getDbCarga();

    final int filial = (codFilial == null || codFilial == 0)
        ? (AppState().codFilialAtiva != 0 ? AppState().codFilialAtiva : 1)
        : codFilial;

    final int tab = (codTabela != null && codTabela > 0) ? codTabela : 1;
    final String termo = (filtro ?? '').trim();

    String whereSql = '';
    final List<dynamic> binds = [filial, tab, tab];

    if (termo.isNotEmpty) {
      whereSql = '''
        WHERE (
          p.pro00_descri LIKE ? 
          OR p.pro00_codbar = ? 
          OR CAST(p.pro00_codigo AS TEXT) = ?
        )
      ''';
      binds.add('%$termo%');
      binds.add(termo);
      binds.add(termo);
    }

    final String query = '''
      SELECT 
        p.pro00_codigo,
        p.pro00_descri,
        COALESCE(p.pro00_unidad, 'UN') AS pro00_unidad,
        COALESCE(p.pro00_embala, p.pro00_unidad, 'UN') AS embalagem,
        COALESCE(p.pro00_codbar, '') AS pro00_codbar,
        COALESCE(p.pro00_ref001, '') AS ref001,
        COALESCE(p.pro00_ref002, '') AS ref002,
        COALESCE(p.pro00_reffor, '') AS reffor,
        p.pro00_codimg,
        COALESCE(m.mar00_descri, 'SEM MARCA') AS marca_nome,
        COALESCE((
          SELECT e.pro00_qtdest 
          FROM estpro00 e 
          WHERE e.pro00_codpro = p.pro00_codigo 
            AND e.pro00_codfil = ? 
          LIMIT 1
        ), p.pro00_qtdest, 0.0) AS saldo,
        COALESCE((
          SELECT COALESCE(t.pro00_pcosub, t.pro00_preco, 0.0)
          FROM estpcopro00 t 
          WHERE t.pro00_codpro = p.pro00_codigo 
            AND (t.pro00_codtab = ? OR ? = 0)
          LIMIT 1
        ), 0.0) AS preco_venda
      FROM cadpro00 p
      LEFT JOIN cadmar00 m ON m.mar00_codigo = p.pro00_codmar
      $whereSql
      ORDER BY p.pro00_descri ASC;
    ''';

    final rows = await db.rawQuery(query, binds);

    return rows.map((m) {
      final double preco = (m['preco_venda'] as num?)?.toDouble() ?? 0.0;
      final double saldo = (m['saldo'] as num?)?.toDouble() ?? 0.0;
      return ProdutoResultStruct(
        codigo: (m['pro00_codigo'] ?? '').toString(),
        descricao: (m['pro00_descri'] ?? '').toString(),
        unidade: (m['pro00_unidad'] ?? 'UN').toString(),
        embalagem: (m['embalagem'] ?? 'UN').toString(),
        codbar: (m['pro00_codbar'] ?? '').toString(),
        referencia1: m['ref001']?.toString() ?? '',
        referencia2: m['ref002']?.toString() ?? '',
        reffor: m['reffor']?.toString() ?? '',
        marca: (m['marca_nome'] ?? 'SEM MARCA').toString(),
        imagemId: (m['pro00_codimg'] as num?)?.toInt() ?? 0,
        saldoEstoque: saldo,
        estoqueAtual: saldo,
        preco: preco,
        pcomax: preco,
      );
    }).toList();
  } catch (e) {
    print('ERRO BUSCA PRODUTO: $e');
    return [];
  }
}
```[cite: 1, 2, 4]

---

### 2.2. Clientes (`lib/action_code/pesquisa_cliente.dart`)
Reescrita completa da ação para carregar a lista diretamente de `cadcli00`, sem fechar a conexão do banco[cite: 5]:

```dart
import 'dart:io';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '/backend/schema/structs/index.dart';

Database? _dbClienteInstancia;

Future<Database> _getDbCliente() async {
  if (_dbClienteInstancia != null && _dbClienteInstancia!.isOpen) {
    return _dbClienteInstancia!;
  }
  final dbPath = join(await getDatabasesPath(), 'dbforcacad001.db');
  _dbClienteInstancia = await openDatabase(dbPath, readOnly: true);
  return _dbClienteInstancia!;
}

Future<List<ClienteResultStruct>> pesquisaCliente(String? termo) async {
  try {
    final db = await _getDbCliente();
    final String busca = (termo ?? '').trim();

    String whereSql = '';
    final List<dynamic> binds = [];

    if (busca.isNotEmpty) {
      whereSql = '''
        WHERE (
          c.cli00_descri LIKE ? 
          OR c.cli00_fantas LIKE ? 
          OR c.cli00_cpfcnp LIKE ? 
          OR CAST(c.cli00_codigo AS TEXT) = ?
        )
      ''';
      binds.add('%$busca%');
      binds.add('%$busca%');
      binds.add('$busca%');
      binds.add(busca);
    }

    final sql = '''
      SELECT 
        c.cli00_codigo,
        c.cli00_descri,
        COALESCE(c.cli00_fantas, c.cli00_descri) AS cli00_fantas,
        COALESCE(c.cli00_cpfcnp, '') AS cli00_cpfcnp,
        COALESCE(c.cli00_endere, '') AS cli00_endere,
        COALESCE(c.cli00_ciddes, '') AS cli00_ciddes,
        COALESCE(c.cli00_estsgl, '') AS cli00_estsgl,
        COALESCE(c.cli00_fonddd, '') AS cli00_fonddd,
        COALESCE(c.cli00_fonnum, '') AS cli00_fonnum,
        COALESCE(c.cli00_crelim, 0.0) AS cli00_crelim,
        COALESCE(c.cli00_creatu, 0.0) AS cli00_creatu,
        COALESCE(c.cli00_titven, 0.0) AS cli00_titven,
        COALESCE(c.cli00_active, 1)   AS cli00_active
      FROM cadcli00 c
      $whereSql
      ORDER BY c.cli00_descri ASC;
    ''';

    final rows = await db.rawQuery(sql, binds);

    return rows.map((m) {
      return ClienteResultStruct(
        codigo: (m['cli00_codigo'] ?? '').toString(),
        razaoSocial: (m['cli00_descri'] ?? '').toString(),
        nomeFantasia: (m['cli00_fantas'] ?? '').toString(),
        cpfCnpj: (m['cli00_cpfcnp'] ?? '').toString(),
        endereco: (m['cli00_endere'] ?? '').toString(),
        cidade: (m['cli00_ciddes'] ?? '').toString(),
        uf: (m['cli00_estsgl'] ?? '').toString(),
        telefone: '${m['cli00_fonddd'] ?? ''}${m['cli00_fonnum'] ?? ''}',
        limiteCredito: (m['cli00_crelim'] as num?)?.toDouble() ?? 0.0,
        limiteAtual: (m['cli00_creatu'] as num?)?.toDouble() ?? 0.0,
        saldoDevedor: (m['cli00_titven'] as num?)?.toDouble() ?? 0.0,
        situacao: (m['cli00_active'] == 1 || m['cli00_active'] == true) ? 'ATIVO' : 'INATIVO',
      );
    }).toList();
  } catch (e) {
    print('ERRO PESQUISA CLIENTE: $e');
    return [];
  }
}
```[cite: 5]

---

## 3. UI da Busca de Produtos (`BuscaProdutoPageWidget`)
* **Remoção de paginação artificial:** A lista é construída diretamente sobre o retorno do `FutureBuilder`, eliminando listeners de rolagem de 100 em 100 itens[source: 2].
* **Exibição do Preço:** Cada card deve exibir o valor de `item.preco` formatado via `toMoeda()` ou `currency_formatter.dart`[cite: 2, 4].

---