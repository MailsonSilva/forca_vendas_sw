import 'dart:io';
import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/services/local_sales_database_service.dart';
import '../data/services/pac_xml_generator_service.dart';
import '../domain/models/pedido_venda.dart';
import '../services/carga_registry_service.dart';
import '../services/ftp_path_builder.dart';
import '/app_state.dart';

Future<String> gerarPacote({
  required List<int> pedidosIds,
  required int codRep,
}) async {
  if (pedidosIds.isEmpty) throw Exception('Nenhum pedido selecionado');

  // Validação: garante que nenhum dos pedidos já foi empacotado
  final dbCheck = await LocalSalesDatabaseService.getDatabase();
  try {
    final placeholdersCheck = List.filled(pedidosIds.length, '?').join(',');
    final rowsCheck = await dbCheck.rawQuery(
      'SELECT ped00_numped, ped00_sttenv, ped00_pacstr FROM pckvendig000 WHERE ped00_numped IN ($placeholdersCheck)',
      pedidosIds,
    );
    final List<int> jaEmpacotados = [];
    for (final r in rowsCheck) {
      final sEnv = (r['ped00_sttenv'] is num) ? (r['ped00_sttenv'] as num).toInt() : 0;
      final pac = r['ped00_pacstr']?.toString().trim() ?? '';
      if (sEnv >= 1 || pac.isNotEmpty) {
        final id = (r['ped00_numped'] is num) ? (r['ped00_numped'] as num).toInt() : 0;
        jaEmpacotados.add(id);
      }
    }
    if (jaEmpacotados.isNotEmpty) {
      throw Exception('O(s) pedido(s) #${jaEmpacotados.join(", #")} já está(ão) em outro pacote e não pode(m) ser re-empacotado(s).');
    }
  } catch (e) {
    if (e.toString().contains('já está(ão) em outro pacote')) rethrow;
  }

  final prefs = await SharedPreferences.getInstance();
  const seqKey = 'sequencial_pacote';
  int seq = prefs.getInt(seqKey) ?? 0;
  // se nunca teve, inicia em 1 ou MAX existente +1
  if (seq == 0) {
    // tenta descobrir maior sequencial já usado nos arquivos temp
    try {
      final tempDir = await getTemporaryDirectory();
      final files = tempDir.listSync().whereType<File>().map((f) => p.basename(f.path)).where((n) => n.startsWith('p$codRep-') && n.endsWith('.pac')).toList();
      int maxSeq = 0;
      for (final n in files) {
        final part = n.replaceFirst('p$codRep-', '').replaceFirst('.pac', ''); // ignore: unnecessary_brace_in_string_interps
        final v = int.tryParse(part) ?? 0;
        if (v > maxSeq) maxSeq = v;
      }
      seq = maxSeq;
    } catch (_) {}
  }
  seq += 1;
  await prefs.setInt(seqKey, seq);

  final fileName = FtpPathBuilder.getFileNamePedido(codRep, seq);
  // Exemplo p71-1.pac, p71-2.pac

  final archive = Archive();

  for (final pedidoId in pedidosIds) {
    try {
      final pedido = await _carregarPedidoVenda(pedidoId, codRep);
      if (pedido == null) continue;
      final xml = PacXmlGeneratorService.generate(pedido);
      final bytes = xml.codeUnits;
      // cada pedido como xml separado dentro do zip
      archive.addFile(ArchiveFile('pedido_$pedidoId.xml', bytes.length, bytes));
    } catch (e) {
      print('Erro ao gerar XML do pedido $pedidoId: $e');
    }
  }

  if (archive.isEmpty) throw Exception('Nenhum pedido válido para gerar pacote');

  final zipBytes = ZipEncoder().encode(archive);
  if (zipBytes == null) throw Exception('Falha ao compactar pacote');

  final tempDir = await getTemporaryDirectory();
  final pacFile = File(p.join(tempDir.path, fileName));
  await pacFile.writeAsBytes(zipBytes, flush: true);

  final docsDir = await getApplicationDocumentsDirectory();
  final docsFile = File(p.join(docsDir.path, fileName));
  await docsFile.writeAsBytes(zipBytes, flush: true);

  // registra no manifesto
  final registry = CargaRegistryService();
  await registry.registrar(CargaRegistro(arquivo: fileName, tipo: TipoCarga.pedido, id: seq));

  // Marca pedidos como empacotados (sttenv = 1, pacstr = fileName) no SQLite
  try {
    final db = await LocalSalesDatabaseService.getDatabase();
    try { await db.execute('ALTER TABLE pckvendig000 ADD COLUMN ped00_pacstr TEXT'); } catch (_) {}
    try { await db.execute('ALTER TABLE pckvendig000 ADD COLUMN ped00_sttenv INTEGER DEFAULT 0'); } catch (_) {}
    try { await db.execute('ALTER TABLE pckvendig000 ADD COLUMN ped00_sttdig INTEGER DEFAULT 0'); } catch (_) {}

    final cols = await db.rawQuery('PRAGMA table_info(pckvendig000)');
    final colNames = cols.map((r) => r['name']?.toString().toLowerCase()).toSet();
    String? colNum;
    for (final c in ['ped00_numped', 'ped00_pedcod', 'ped00_codmov', 'numped']) {
      if (colNames.contains(c)) { colNum = c; break; }
    }
    colNum ??= 'ped00_numped';

    String? colPac;
    for (final c in ['ped00_pacstr', 'ped00_pacote', 'pacstr', 'pacote']) {
      if (colNames.contains(c)) { colPac = c; break; }
    }
    colPac ??= 'ped00_pacstr';

    String? colSttEnv;
    for (final c in ['ped00_sttenv', 'ped00_enviado', 'ped00_flgenv', 'sttenv']) {
      if (colNames.contains(c)) { colSttEnv = c; break; }
    }
    colSttEnv ??= 'ped00_sttenv';

    final placeholders = List.filled(pedidosIds.length, '?').join(',');
    await db.rawUpdate(
      'UPDATE pckvendig000 SET $colPac = ?, $colSttEnv = 1, ped00_sttdig = 1 WHERE $colNum IN ($placeholders)',
      [fileName, ...pedidosIds],
    );
  } catch (e) {
    print('Erro ao atualizar status empacotado no SQLite: $e');
  }

  return fileName;
}

Future<PedidoVenda?> _carregarPedidoVenda(int pedidoId, int codRepFallback) async {
  try {
    final db = await LocalSalesDatabaseService.getDatabase();
    final t = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table' AND lower(name)='pckvendig000'");
    if (t.isEmpty) return null;

    final cols = await db.rawQuery('PRAGMA table_info(pckvendig000)');
    final colNames = cols.map((r) => r['name']?.toString().toLowerCase()).toSet();

    String? pick(List<String> cands) {
      for (final c in cands) { if (colNames.contains(c.toLowerCase())) return c; }
      return null;
    }

    final colNum = pick(['ped00_numped', 'ped00_pedcod', 'ped00_codmov', 'numped']) ?? 'ped00_numped';
    final colCli = pick(['ped00_codcli', 'ped00_clicod', 'codcli', 'clicod']);
    final colPla = pick(['ped00_codpla', 'ped00_codpag', 'ped00_placod', 'codpla', 'codpag']);
    final colLin = pick(['ped00_codlin', 'ped00_lincod', 'codlin']);
    final colAgt = pick(['ped00_codagt', 'ped00_agtcod', 'ped00_codage', 'ped00_digagt', 'codagt', 'agtcod']);
    final colDat = pick(['ped00_datsys', 'ped00_datemi', 'ped00_datcad', 'datsys', 'datemi']);

    final rows = await db.rawQuery('SELECT * FROM pckvendig000 WHERE $colNum = ?', [pedidoId]);
    if (rows.isEmpty) return null;
    final m = rows.first;

    int toInt(dynamic v) => v is int ? v : int.tryParse(v.toString()) ?? 0;
    final codCli = colCli != null ? toInt(m[colCli]) : 0;
    final codLin = colLin != null ? toInt(m[colLin]) : 0;
    final codPla = colPla != null ? toInt(m[colPla]) : 0;
    final codAgt = colAgt != null ? toInt(m[colAgt]) : codRepFallback;
    final datSys = colDat != null ? (m[colDat]?.toString() ?? '') : '';

    // Carregar itens
    final itemCols = await db.rawQuery('PRAGMA table_info(pckvendig010)');
    final itemColNames = itemCols.map((r) => r['name']?.toString().toLowerCase()).toSet();
    String? itemNumCol;
    for (final c in ['ped10_numped', 'ped10_pedcod', 'ped10_codmov', 'numped']) {
      if (itemColNames.contains(c)) { itemNumCol = c; break; }
    }

    List<Map<String, dynamic>> itensRows;
    if (itemNumCol != null) {
      itensRows = await db.rawQuery('SELECT * FROM pckvendig010 WHERE $itemNumCol = ?', [pedidoId]);
    } else {
      itensRows = await db.rawQuery('SELECT * FROM pckvendig010');
    }

    List<ItemPedidoVenda> items = [];
    int idx = 1;
    for (final r in itensRows) {
      final codPro = r['ped10_codprd']?.toString() ?? r['ped10_codpro']?.toString() ?? r['ped10_procod']?.toString() ?? '';
      final qtd = r['ped10_qtdped'] != null ? double.tryParse(r['ped10_qtdped'].toString()) ?? 0.0 : 0.0;
      final qtdBon = r['ped10_qtdbon'] != null ? double.tryParse(r['ped10_qtdbon'].toString()) ?? 0.0 : 0.0;
      final pco = r['ped10_pcosub'] != null ? double.tryParse(r['ped10_pcosub'].toString()) ?? 0.0 : 0.0;
      final tot = r['ped10_totprd'] != null ? double.tryParse(r['ped10_totprd'].toString()) ?? 0.0 : 0.0;
      final isBon = (r['ped10_sttbon'] == 1 || r['ped10_flgbon'] == 1 || r['ped10_bonificado'] == 1);
      final codCmb = r['ped10_codcmb']?.toString() ?? '';

      items.add(ItemPedidoVenda(
        digpro: codPro,
        digqtd: isBon ? (qtdBon > 0 ? qtdBon : qtd) : qtd,
        digpco: pco,
        pcomax: pco,
        pcomin: pco,
        destot: 0.0,
        subtot: isBon ? 0.0 : tot,
        bontyp: isBon ? 1 : 0,
        boncod: isBon ? (int.tryParse(codCmb) ?? 1) : 0,
        ccvtot: 0.0,
        digitm: idx++,
      ));
    }

    if (items.isEmpty) return null;

    final int codFil = AppState().codFilialAtiva != 0 ? AppState().codFilialAtiva : 1;

    final pVenda = PedidoVenda(
      codFil: codFil,
      codMov: pedidoId,
      codRep: codRepFallback,
      codCli: codCli,
      codLin: codLin,
      codPla: codPla,
      codAgt: codAgt != 0 ? codAgt : codRepFallback,
      datSys: datSys.isNotEmpty ? datSys : DateTime.now().toString().split(' ').first,
      items: items,
    );
    pVenda.calcularTotais();
    return pVenda;
  } catch (e) {
    print('Erro _carregarPedidoVenda: $e');
  }
  return null;
}
