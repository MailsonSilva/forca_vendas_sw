import '/backend/schema/structs/index.dart';
import 'package:intl/intl.dart';
import '/functions/resolver_cod_filial.dart';
import '/data/services/local_sales_database_service.dart';
import '../app_state.dart';

Future<bool> salvarCarrinhoPedido({
  required int pedidoId,
  required int clienteCodigo,
  required String? linhaCodigo,
  required String? planoCodigo,
  required List<ItemPedidoStruct> carrinhoItens,
  int? sttDig,
  int? codAgenteCobrador,
  double? subtot,
  double? destot,
  int? bonfrcven,
  String? nomePacote,
  List<double>? itensSubtot,
  String? observacao,
}) async {
  try {
    final db = await LocalSalesDatabaseService.getDatabase();

      // 0. Garante existência das tabelas locais pckvendig000 e pckvendig010
      await db.execute('''
        CREATE TABLE IF NOT EXISTS pckvendig000 (
          ped00_numped INTEGER PRIMARY KEY,
          ped00_codcli INTEGER,
          ped00_codlin INTEGER,
          ped00_codpla INTEGER,
          ped00_codfil INTEGER,
          ped00_codrep INTEGER,
          ped00_codagt INTEGER,
          ped00_digtab INTEGER,
          ped00_digcob INTEGER,
          ped00_bonfrcven INTEGER DEFAULT 0,
          ped00_sttdig INTEGER DEFAULT 0,
          ped00_sttenv INTEGER DEFAULT 0,
          ped00_datsys TEXT,
          ped00_clides TEXT,
          ped00_lindes TEXT,
          ped00_plades TEXT,
          ped00_digtot REAL DEFAULT 0,
          ped00_fattot REAL DEFAULT 0,
          ped00_subtot REAL DEFAULT 0,
          ped00_bontot REAL DEFAULT 0,
          ped00_destot REAL DEFAULT 0,
          ped00_pacstr TEXT
        )
      ''');
      // Garante coluna ped00_pacstr em bancos criados antes desta versão
      try { await db.execute('ALTER TABLE pckvendig000 ADD COLUMN ped00_pacstr TEXT'); } catch (_) {}
      try { await db.execute('CREATE VIEW IF NOT EXISTS dig00 AS SELECT * FROM pckvendig000'); } catch (_) {}

      await db.execute('''
        CREATE TABLE IF NOT EXISTS pckvendig010 (
          ped10_numped INTEGER,
          ped10_seq INTEGER DEFAULT 1,
          ped10_codprd TEXT,
          ped10_descri TEXT,
          ped10_unidpri TEXT,
          ped10_qtdped REAL DEFAULT 0,
          ped10_pcosub REAL DEFAULT 0,
          ped10_totprd REAL DEFAULT 0,
          ped10_qtdbon REAL DEFAULT 0,
          ped10_sttbon INTEGER DEFAULT 0,
          ped10_codcmb TEXT
        )
      ''');
      try { await db.execute('CREATE VIEW IF NOT EXISTS dig01 AS SELECT * FROM pckvendig010'); } catch (_) {}

      // PRD B2: garante colunas de cabeçalho completas se ausentes
      final ensureCols = <String, String>{
        'ped00_numped': 'INTEGER',
        'ped00_codcli': 'INTEGER',
        'ped00_codlin': 'INTEGER',
        'ped00_codpla': 'INTEGER',
        'ped00_codfil': 'INTEGER',
        'ped00_codrep': 'INTEGER',
        'ped00_codagt': 'INTEGER',
        'ped00_digagt': 'INTEGER',
        'ped00_digcob': 'INTEGER',
        'ped00_digtab': 'INTEGER',
        'ped00_bonfrcven': 'INTEGER',
        'ped00_sttdig': 'INTEGER',
        'ped00_sttenv': 'INTEGER',
        'ped00_datsys': 'TEXT',
        'ped00_datemi': 'TEXT',
        'ped00_clides': 'TEXT',
        'ped00_lindes': 'TEXT',
        'ped00_plades': 'TEXT',
        'ped00_fattot': 'REAL',
        'ped00_digtot': 'REAL',
        'ped00_subtot': 'REAL',
        'dig00_subtot': 'REAL',
        'ped00_bontot': 'REAL',
        'ped00_destot': 'REAL',
        'ped00_pacstr': 'TEXT',
        'ped00_digobs': 'TEXT',
        'dig00_digobs': 'TEXT',
        'ped00_obs': 'TEXT',
        'ped00_observ': 'TEXT',
      };
      for (final e in ensureCols.entries) {
        try {
          await db.execute('ALTER TABLE pckvendig000 ADD COLUMN ${e.key} ${e.value}');
        } catch (_) {}
      }

      final ensureItemCols = <String, String>{
        'ped10_seq': 'INTEGER',
        'ped10_codprd': 'TEXT',
        'ped10_descri': 'TEXT',
        'ped10_unidpri': 'TEXT',
        'ped10_qtdped': 'REAL',
        'ped10_pcosub': 'REAL',
        'ped10_totprd': 'REAL',
        'ped10_qtdbon': 'REAL',
        'ped10_sttbon': 'INTEGER',
        'ped10_codcmb': 'TEXT',
        'ped10_subtot': 'REAL',
        'ped10_valsub': 'REAL',
        'dig01_subtot': 'REAL',
        'ped10_destot': 'REAL',
        'dig01_destot': 'REAL',
      };
      for (final e in ensureItemCols.entries) {
        try {
          await db.execute('ALTER TABLE pckvendig010 ADD COLUMN ${e.key} ${e.value}');
        } catch (_) {}
      }

      final List<Map<String, dynamic>> headerCols = await db.rawQuery('PRAGMA table_info(pckvendig000)');
      final colNamesHeader = headerCols.map((r) => r['name']?.toString().toLowerCase()).toSet();

      final linVal = int.tryParse(linhaCodigo ?? '') ?? 0;
      final plaVal = int.tryParse(planoCodigo ?? '') ?? 0;
      final codFil = resolverCodFilial(AppState().empresa_codigo) ?? 1;
      final codRep = AppState().vendedor_codigo;
      final datSys = DateFormat('yyyy-MM-dd').format(DateTime.now());

      // Calcula totais dos itens para manter o cabeçalho sempre atualizado
      double calcDigTot = 0.0;
      double calcBonTot = 0.0;
      for (final itm in carrinhoItens) {
        if (itm.isBonificacao) {
          calcBonTot += itm.totalItem > 0 ? itm.totalItem : (itm.quantidadeBonificada * itm.precoUnitario);
        } else {
          calcDigTot += itm.totalItem > 0 ? itm.totalItem : (itm.quantidade * itm.precoUnitario);
        }
      }
      final calcFatTot = calcDigTot;

      String clides = '';
      String lindes = '';
      String plades = '';
      try {
        final r = await db.rawQuery('SELECT cli00_descri FROM cadcli00 WHERE cli00_codigo = ? LIMIT 1', [clienteCodigo]);
        if (r.isNotEmpty) clides = r.first['cli00_descri']?.toString() ?? '';
      } catch (_) {}
      try {
        final r = await db.rawQuery('SELECT lin00_descri FROM cadlin00 WHERE lin00_codigo = ? LIMIT 1', [linVal]);
        if (r.isNotEmpty) lindes = r.first['lin00_descri']?.toString() ?? '';
      } catch (_) {}
      try {
        final r = await db.rawQuery('SELECT pla00_descri FROM cadpla00 WHERE pla00_codigo = ? LIMIT 1', [plaVal]);
        if (r.isNotEmpty) plades = r.first['pla00_descri']?.toString() ?? '';
      } catch (_) {}

      int finalClienteCodigo = clienteCodigo;
      int finalLinVal = linVal;
      int finalPlaVal = plaVal;
      int finalCodRep = codRep;
      int finalCodFil = codFil;

      // Preserva dados existentes no registro para não perder status, agente ou pacote
      int existingSttDig = 0;
      int existingSttEnv = 0;
      int existingCodAgt = 0;
      double existingSubTot = 0.0;
      double existingDesTot = 0.0;
      int existingBonFrcVen = 0;
      String existingPacStr = '';
      String existingClides = '';
      String existingLindes = '';
      String existingPlades = '';

      try {
        String queryCheck = 'SELECT * FROM pckvendig000 WHERE 1=0';
        for (final c in ['ped00_numped', 'ped00_pedcod', 'ped00_codmov', 'numped']) {
          if (colNamesHeader.contains(c)) {
            queryCheck = 'SELECT * FROM pckvendig000 WHERE $c = ? LIMIT 1';
            break;
          }
        }
        final existing = await db.rawQuery(queryCheck, [pedidoId]);
        if (existing.isNotEmpty) {
          final row0 = existing.first;
          for (final entry in row0.entries) {
            final k = entry.key.toLowerCase();
            final val = entry.value;
            if (val == null) continue;
            if (finalClienteCodigo == 0 && (k == 'ped00_codcli' || k == 'ped00_clicod' || k == 'codcli')) {
              finalClienteCodigo = int.tryParse(val.toString()) ?? 0;
            } else if (finalLinVal == 0 && (k == 'ped00_codlin' || k == 'ped00_lincod' || k == 'codlin')) {
              finalLinVal = int.tryParse(val.toString()) ?? 0;
            } else if (finalPlaVal == 0 && (k == 'ped00_codpla' || k == 'ped00_codpag' || k == 'ped00_placod' || k == 'codpla')) {
              finalPlaVal = int.tryParse(val.toString()) ?? 0;
            } else if (finalCodRep == 0 && (k == 'ped00_codrep' || k == 'ped00_repcod' || k == 'ped00_vencod' || k == 'codrep')) {
              finalCodRep = int.tryParse(val.toString()) ?? 0;
            } else if (finalCodFil == 0 && (k == 'ped00_codfil' || k == 'ped00_filcod' || k == 'codfil')) {
              finalCodFil = int.tryParse(val.toString()) ?? 0;
            } else if (k == 'ped00_sttdig' || k == 'sttdig') {
              existingSttDig = int.tryParse(val.toString()) ?? existingSttDig;
            } else if (k == 'ped00_sttenv' || k == 'sttenv' || k == 'ped00_enviado' || k == 'enviado') {
              existingSttEnv = int.tryParse(val.toString()) ?? existingSttEnv;
            } else if (k == 'ped00_codagt' || k == 'ped00_agtcod' || k == 'ped00_codage' || k == 'codagt') {
              existingCodAgt = int.tryParse(val.toString()) ?? existingCodAgt;
            } else if (k == 'ped00_subtot' || k == 'ped00_subval' || k == 'subtot') {
              existingSubTot = double.tryParse(val.toString()) ?? existingSubTot;
            } else if (k == 'ped00_destot' || k == 'ped00_desval' || k == 'destot') {
              existingDesTot = double.tryParse(val.toString()) ?? existingDesTot;
            } else if (k == 'ped00_bonfrcven' || k == 'bonfrcven') {
              existingBonFrcVen = int.tryParse(val.toString()) ?? existingBonFrcVen;
            } else if (k == 'ped00_pacstr' || k == 'ped00_pacote' || k == 'pacstr' || k == 'pacote') {
              existingPacStr = val.toString();
            } else if (k == 'ped00_clides' || k == 'clides') {
              existingClides = val.toString();
            } else if (k == 'ped00_lindes' || k == 'lindes') {
              existingLindes = val.toString();
            } else if (k == 'ped00_plades' || k == 'plades') {
              existingPlades = val.toString();
            }
          }
        }
      } catch (_) {}

      if (clides.isEmpty && finalClienteCodigo != 0) {
        try {
          final r = await db.rawQuery('SELECT cli00_descri FROM cadcli00 WHERE cli00_codigo = ? LIMIT 1', [finalClienteCodigo]);
          if (r.isNotEmpty) clides = r.first['cli00_descri']?.toString() ?? '';
        } catch (_) {}
      }
      if (lindes.isEmpty && finalLinVal != 0) {
        try {
          final r = await db.rawQuery('SELECT lin00_descri FROM cadlin00 WHERE lin00_codigo = ? LIMIT 1', [finalLinVal]);
          if (r.isNotEmpty) lindes = r.first['lin00_descri']?.toString() ?? '';
        } catch (_) {}
      }
      if (plades.isEmpty && finalPlaVal != 0) {
        try {
          final r = await db.rawQuery('SELECT pla00_descri FROM cadpla00 WHERE pla00_codigo = ? LIMIT 1', [finalPlaVal]);
          if (r.isNotEmpty) plades = r.first['pla00_descri']?.toString() ?? '';
        } catch (_) {}
      }

      final finalSttDig = sttDig ?? (existingSttDig != 0 ? existingSttDig : 0);
      final finalSttEnv = (nomePacote != null && nomePacote.isNotEmpty) ? 1 : existingSttEnv;
      final finalCodAgt = codAgenteCobrador ?? (existingCodAgt != 0 ? existingCodAgt : 0);
      final finalSubTot = subtot ?? existingSubTot;
      final finalDesTot = destot ?? existingDesTot;
      final finalBonFrcVen = bonfrcven ?? existingBonFrcVen;
      final finalPacStr = (nomePacote != null && nomePacote.isNotEmpty) ? nomePacote : existingPacStr;
      final finalClides = clides.isNotEmpty ? clides : existingClides;
      final finalLindes = lindes.isNotEmpty ? lindes : existingLindes;
      final finalPlades = plades.isNotEmpty ? plades : existingPlades;

      final List<String> insertHeaderCols = [];
      final List<String> placeholdersHeader = [];
      final List<dynamic> bindsHeader = [];

      void addHeaderIf(String col, dynamic val) {
        final lower = col.toLowerCase();
        for (final h in headerCols) {
          final realCol = h['name']?.toString() ?? '';
          if (realCol.toLowerCase() == lower && !insertHeaderCols.contains(realCol)) {
            insertHeaderCols.add(realCol);
            placeholdersHeader.add('?');
            bindsHeader.add(val);
            break;
          }
        }
      }

      addHeaderIf('ped00_numped', pedidoId);
      addHeaderIf('ped00_pedcod', pedidoId);
      addHeaderIf('ped00_codmov', pedidoId);
      addHeaderIf('numped', pedidoId);
      addHeaderIf('ped00_codcli', finalClienteCodigo);
      addHeaderIf('ped00_clicod', finalClienteCodigo);
      addHeaderIf('codcli', finalClienteCodigo);
      addHeaderIf('ped00_codlin', finalLinVal);
      addHeaderIf('ped00_lincod', finalLinVal);
      addHeaderIf('ped00_codpla', finalPlaVal);
      addHeaderIf('ped00_codpag', finalPlaVal);
      addHeaderIf('ped00_placod', finalPlaVal);
      addHeaderIf('ped00_codfil', finalCodFil);
      addHeaderIf('ped00_filcod', finalCodFil);
      addHeaderIf('ped00_codrep', finalCodRep);
      addHeaderIf('ped00_repcod', finalCodRep);
      addHeaderIf('ped00_vencod', finalCodRep);
      addHeaderIf('ped00_codagt', finalCodAgt);
      addHeaderIf('ped00_agtcod', finalCodAgt);
      addHeaderIf('ped00_codage', finalCodAgt);
      addHeaderIf('ped00_digagt', finalCodAgt);
      addHeaderIf('ped00_digtab', plaVal);
      addHeaderIf('ped00_digcob', 0);
      addHeaderIf('ped00_bonfrcven', finalBonFrcVen);
      addHeaderIf('ped00_clides', finalClides);
      addHeaderIf('ped00_lindes', finalLindes);
      addHeaderIf('ped00_plades', finalPlades);
      addHeaderIf('ped00_datsys', datSys);
      addHeaderIf('ped00_datemi', datSys);
      addHeaderIf('ped00_datcad', datSys);
      addHeaderIf('ped00_sttdig', finalSttDig);
      addHeaderIf('ped00_status', finalSttDig);
      addHeaderIf('ped00_sitped', finalSttDig);
      addHeaderIf('ped00_sttenv', finalSttEnv);
      addHeaderIf('ped00_enviado', finalSttEnv);
      addHeaderIf('ped00_flgenv', finalSttEnv);
      addHeaderIf('ped00_digtot', calcDigTot);
      addHeaderIf('ped00_valtot', calcDigTot);
      addHeaderIf('ped00_totger', calcDigTot);
      addHeaderIf('ped00_fattot', (calcFatTot - finalSubTot) > 0 ? (calcFatTot - finalSubTot) : calcFatTot);
      addHeaderIf('ped00_totfat', (calcFatTot - finalSubTot) > 0 ? (calcFatTot - finalSubTot) : calcFatTot);
      addHeaderIf('ped00_subtot', finalSubTot);
      addHeaderIf('ped00_subval', finalSubTot);
      addHeaderIf('ped00_bontot', calcBonTot);
      addHeaderIf('ped00_bonval', calcBonTot);
      addHeaderIf('ped00_destot', finalDesTot);
      addHeaderIf('ped00_desval', finalDesTot);
      addHeaderIf('ped00_qtditm', carrinhoItens.length);
      addHeaderIf('ped00_qtdite', carrinhoItens.length);
      if (finalPacStr.isNotEmpty) {
        addHeaderIf('ped00_pacstr', finalPacStr);
        addHeaderIf('ped00_pacote', finalPacStr);
        addHeaderIf('pacstr', finalPacStr);
        addHeaderIf('pacote', finalPacStr);
      }
      if (observacao != null && observacao.isNotEmpty) {
        addHeaderIf('ped00_digobs', observacao);
        addHeaderIf('dig00_digobs', observacao);
        addHeaderIf('ped00_obs', observacao);
        addHeaderIf('ped00_observ', observacao);
      }

      final List<Map<String, dynamic>> itemCols = await db.rawQuery('PRAGMA table_info(pckvendig010)');

      // Executa em transação atômica
      await db.transaction((txn) async {
        // 1. Grava cabeçalho
        if (insertHeaderCols.isNotEmpty) {
          final queryHeader =
              'INSERT OR REPLACE INTO pckvendig000 (${insertHeaderCols.join(', ')}) VALUES (${placeholdersHeader.join(', ')})';
          await txn.rawInsert(queryHeader, bindsHeader);
        }

        // 2. Limpa itens existentes
        for (final c in ['ped10_numped', 'ped10_pedcod', 'ped10_codmov', 'numped']) {
          for (final h in itemCols) {
            final realCol = h['name']?.toString() ?? '';
            if (realCol.toLowerCase() == c) {
              await txn.rawDelete('DELETE FROM pckvendig010 WHERE $realCol = ?', [pedidoId]);
              break;
            }
          }
        }

        int itemIdx = 1;
        for (final item in carrinhoItens) {
          final List<String> insertItemCols = [];
          final List<String> placeholdersItem = [];
          final List<dynamic> bindsItem = [];

          void addItemIf(String col, dynamic val) {
            final lower = col.toLowerCase();
            for (final h in itemCols) {
              final realCol = h['name']?.toString() ?? '';
              if (realCol.toLowerCase() == lower && !insertItemCols.contains(realCol)) {
                insertItemCols.add(realCol);
                placeholdersItem.add('?');
                bindsItem.add(val);
                break;
              }
            }
          }

          addItemIf('ped10_numped', pedidoId);
          addItemIf('ped10_pedcod', pedidoId);
          addItemIf('ped10_codmov', pedidoId);
          addItemIf('numped', pedidoId);
          addItemIf('ped10_seq', itemIdx);
          addItemIf('ped10_numseq', itemIdx);
          addItemIf('ped10_seqite', itemIdx);
          addItemIf('ped10_item', itemIdx);
          addItemIf('ped10_digitm', itemIdx);
          addItemIf('ped10_codprd', item.codigoProduto);
          addItemIf('ped10_codpro', item.codigoProduto);
          addItemIf('ped10_procod', item.codigoProduto);
          addItemIf('ped10_descri', item.descricao);
          addItemIf('ped10_descricao', item.descricao);
          addItemIf('ped10_prodes', item.descricao);
          addItemIf('ped10_unidpri', item.unidade);
          addItemIf('ped10_unidade', item.unidade);
          addItemIf('ped10_unimed', item.unidade);
          addItemIf('ped10_qtdped', item.isBonificacao ? 0.0 : item.quantidade);
          addItemIf('ped10_qtd', item.isBonificacao ? 0.0 : item.quantidade);
          addItemIf('ped10_quantidade', item.isBonificacao ? 0.0 : item.quantidade);
          addItemIf('ped10_pcosub', item.isBonificacao ? 0.0 : item.precoUnitario);
          addItemIf('ped10_prcuni', item.isBonificacao ? 0.0 : item.precoUnitario);
          addItemIf('ped10_vlruni', item.isBonificacao ? 0.0 : item.precoUnitario);
          addItemIf('ped10_preco', item.isBonificacao ? 0.0 : item.precoUnitario);
          addItemIf('ped10_totprd', item.isBonificacao ? 0.0 : item.totalItem);
          addItemIf('ped10_totite', item.isBonificacao ? 0.0 : item.totalItem);
          addItemIf('ped10_valtot', item.isBonificacao ? 0.0 : item.totalItem);
          addItemIf('ped10_qtdbon', item.isBonificacao ? item.quantidadeBonificada : 0.0);
          addItemIf('ped10_bonqtd', item.isBonificacao ? item.quantidadeBonificada : 0.0);
          addItemIf('ped10_sttbon', item.isBonificacao ? 1 : 0);
          addItemIf('ped10_flgbon', item.isBonificacao ? 1 : 0);
          addItemIf('ped10_bonificado', item.isBonificacao ? 1 : 0);

          final double itmSub = (itensSubtot != null && (itemIdx - 1) < itensSubtot.length)
              ? itensSubtot[itemIdx - 1]
              : 0.0;
          addItemIf('ped10_subtot', itmSub);
          addItemIf('ped10_valsub', itmSub);
          addItemIf('dig01_subtot', itmSub);

          if (item.codigoCombo.isNotEmpty) {
            addItemIf('ped10_codcmb', item.codigoCombo);
            addItemIf('ped10_combo', item.codigoCombo);
          }

          if (insertItemCols.isNotEmpty) {
            final queryItem =
                'INSERT OR REPLACE INTO pckvendig010 (${insertItemCols.join(', ')}) VALUES (${placeholdersItem.join(', ')})';
            await txn.rawInsert(queryItem, bindsItem);
          }
          itemIdx++;
        }
      });
      print('DEBUG PEDIDO GRAVADO: ID $pedidoId, StatusDig: $finalSttDig, StatusEnv: $finalSttEnv, Rep: $codRep, Fil: $codFil');
      print('Pedido #$pedidoId e ${carrinhoItens.length} itens salvos com sucesso no SQLite.');
      return true;
  } catch (e, stack) {
    print('>>> ERRO REAL NO SALVAR_CARRINHO_PEDIDO: $e \n $stack');
    return false;
  }
}
