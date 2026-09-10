import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../data/services/local_sales_database_service.dart';

class ClientePendenteItem {
  ClientePendenteItem({
    required this.clienteCodigo,
    required this.razaoSocial,
    required this.nomeFantasia,
    required this.cpfCnpj,
    required this.cidadeUf,
    required this.sttEnv,
    required this.nomeArquivoXml,
    required this.caminhoArquivo,
    required this.existeEmTemp,
    required this.dataCriacao,
  });

  final int clienteCodigo;
  final String razaoSocial;
  final String nomeFantasia;
  final String cpfCnpj;
  final String cidadeUf;
  final int sttEnv; // 0 = Pendente, 2 = Enviado
  final String nomeArquivoXml;
  final String caminhoArquivo;
  final bool existeEmTemp;
  final String dataCriacao;

  bool get isPendente => sttEnv == 0 || existeEmTemp;
  bool get isEnviado => sttEnv == 2 && !existeEmTemp;
}

/// Consulta os clientes cadastrados ou atualizados localmente que estão
/// pendentes de transmissão FTP ou já foram gerados na pasta de envio.
Future<List<ClientePendenteItem>> listarClientesPendentes({
  String filtro = 'todos', // 'pendentes', 'enviados', 'todos'
}) async {
  try {
    final Map<int, ClientePendenteItem> clientesMap = {};

    // 1. Inspeciona o diretório temporário para arquivos c*.xml
    final tempDir = await getTemporaryDirectory();
    final List<File> tempFiles = [];

    if (await tempDir.exists()) {
      tempFiles.addAll(
        tempDir
            .listSync()
            .whereType<File>()
            .where((f) {
              final n = p.basename(f.path).toLowerCase();
              return n.startsWith('c') && n.endsWith('.xml');
            }),
      );
    }

    final cliSubDir = Directory(p.join(tempDir.path, 'cli'));
    if (await cliSubDir.exists()) {
      tempFiles.addAll(
        cliSubDir
            .listSync()
            .whereType<File>()
            .where((f) {
              final n = p.basename(f.path).toLowerCase();
              return n.startsWith('c') && n.endsWith('.xml');
            }),
      );
    }

    // Mapa de arquivos em temp por ID extraído do nome (ex: c71-123.xml -> 123)
    final Map<String, File> arquivosXmlTemp = {};
    for (final tf in tempFiles) {
      final name = p.basename(tf.path);
      arquivosXmlTemp[name] = tf;
    }

    // 2. Consulta banco SQLite (cadcli00)
    try {
      final db = await LocalSalesDatabaseService.getDatabase();
      final tableCheck = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND lower(name)='cadcli00'",
      );

      if (tableCheck.isNotEmpty) {
        final cols = await db.rawQuery('PRAGMA table_info(cadcli00)');
        final colNames = cols.map((r) => r['name']?.toString().toLowerCase()).toSet();

        String colSttEnv = 'cli00_sttenv';
        if (!colNames.contains(colSttEnv)) {
          colSttEnv = '0 AS cli00_sttenv';
        }

        final rows = await db.rawQuery('''
          SELECT 
            cli00_codigo,
            cli00_descri,
            cli00_fantas,
            cli00_cpfcnp,
            cli00_ciddes,
            cli00_estsgl,
            $colSttEnv
          FROM cadcli00
          ORDER BY cli00_codigo DESC
        ''');

        for (final r in rows) {
          final id = int.tryParse(r['cli00_codigo']?.toString() ?? '0') ?? 0;
          if (id <= 0) continue;

          final sEnv = int.tryParse(r['cli00_sttenv']?.toString() ?? '0') ?? 0;
          final rSocial = r['cli00_descri']?.toString() ?? 'Cliente #$id';
          final nFantas = r['cli00_fantas']?.toString() ?? '';
          final cpfCnpj = r['cli00_cpfcnp']?.toString() ?? '';
          final cid = r['cli00_ciddes']?.toString() ?? '';
          final uf = r['cli00_estsgl']?.toString() ?? '';
          final cidUf = (cid.isNotEmpty && uf.isNotEmpty) ? '$cid - $uf' : cid;

          // Procura arquivo XML correspondente
          String xmlName = '';
          String xmlPath = '';
          bool inTemp = false;

          for (final entry in arquivosXmlTemp.entries) {
            final fileName = entry.key;
            if (fileName.contains('-$id.') || fileName.contains('-$id-')) {
              xmlName = fileName;
              xmlPath = entry.value.path;
              inTemp = true;
              break;
            }
          }

          // Se estiver com sttenv == 0 ou tiver arquivo pendente, é pendente
          if (sEnv == 0 || inTemp) {
            clientesMap[id] = ClientePendenteItem(
              clienteCodigo: id,
              razaoSocial: rSocial,
              nomeFantasia: nFantas,
              cpfCnpj: cpfCnpj,
              cidadeUf: cidUf,
              sttEnv: inTemp ? 0 : sEnv,
              nomeArquivoXml: xmlName.isNotEmpty ? xmlName : 'c-$id.xml',
              caminhoArquivo: xmlPath,
              existeEmTemp: inTemp,
              dataCriacao: DateTime.now().toString().split(' ').first,
            );
          } else if (filtro == 'todos' || filtro == 'enviados') {
            clientesMap[id] = ClientePendenteItem(
              clienteCodigo: id,
              razaoSocial: rSocial,
              nomeFantasia: nFantas,
              cpfCnpj: cpfCnpj,
              cidadeUf: cidUf,
              sttEnv: sEnv,
              nomeArquivoXml: xmlName,
              caminhoArquivo: xmlPath,
              existeEmTemp: false,
              dataCriacao: '',
            );
          }
        }
      }
    } catch (e) {
      print('Erro ao consultar clientes no SQLite: $e');
    }

    // 3. Adiciona arquivos XML soltos em temp que possam ser novos clientes
    for (final entry in arquivosXmlTemp.entries) {
      final name = entry.key;
      final file = entry.value;
      // Extrai número do arquivo c<rep>-<num>.xml
      final parts = name.replaceAll('.xml', '').split('-');
      final fileId = parts.length >= 2 ? (int.tryParse(parts.last) ?? 0) : 0;

      if (fileId > 0 && !clientesMap.containsKey(fileId)) {
        clientesMap[fileId] = ClientePendenteItem(
          clienteCodigo: fileId,
          razaoSocial: 'Novo Cliente Cadastrado ($name)',
          nomeFantasia: '',
          cpfCnpj: '',
          cidadeUf: '',
          sttEnv: 0,
          nomeArquivoXml: name,
          caminhoArquivo: file.path,
          existeEmTemp: true,
          dataCriacao: DateTime.now().toString().split(' ').first,
        );
      }
    }

    var list = clientesMap.values.toList();

    if (filtro == 'pendentes') {
      list = list.where((c) => c.isPendente).toList();
    } else if (filtro == 'enviados') {
      list = list.where((c) => c.isEnviado).toList();
    }

    list.sort((a, b) => b.clienteCodigo.compareTo(a.clienteCodigo));
    return list;
  } catch (e) {
    print('Erro em listarClientesPendentes: $e');
    return [];
  }
}
