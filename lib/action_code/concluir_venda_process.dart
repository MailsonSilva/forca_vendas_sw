import 'package:intl/intl.dart';
import '../../backend/schema/structs/index.dart';
import '../../core/app_functions.dart';
import '../../app_state.dart';
import '../../domain/models/pedido_venda.dart';
import '../../domain/models/status_envio.dart';
import '../../domain/services/icms_st_service.dart';
import '../../services/concluir_venda_service.dart';
import '../../data/services/local_sales_database_service.dart';
import 'salvar_carrinho_pedido.dart';

Future<bool> concluirVendaProcess({
  required int pedidoId,
  required int clienteCodigo,
  required String? linhaCodigo,
  required String? planoCodigo,
  required List<ItemPedidoStruct> carrinhoItens,
  int? codAgenteCobrador,
  int bonfrcven = 0,
}) async {
  try {
    // 1. Validação
    if (carrinhoItens.isEmpty) {
      print('>>> ERRO NO CONCLUIR_VENDA_PROCESS: Carrinho vazio! Não é possível concluir a venda.');
      throw Exception('Carrinho vazio! Não é possível concluir a venda.');
    }

    final String datSys = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final int codRep = AppState().vendedor_codigo;
    final int codFil = resolverCodFilial(AppState().empresa_codigo) ?? 1;
    final int codEqp = AppState().vendedor_equipe;

    int resolvedClienteCodigo = clienteCodigo;

    // Usa a instância Singleton ativa — NUNCA abre/fecha conexão descartável
    // O SQLite no Flutter deve permanecer aberto durante toda a sessão do app.
    final Map<String, Map<String, double>> fiscalParams = {};
    int tipoAgente = 0;
    String clidesSnap = '';
    String lindesSnap = '';
    String pladesSnap = '';
    final int codAgt = codAgenteCobrador ?? codRep;

    // Obtém conexão singleton para leituras — SEM readOnly para evitar conflito WAL
    final db = await LocalSalesDatabaseService.getDatabase();

    // Se ainda não tem clienteCodigo, tenta recuperar do rascunho em pckvendig000
    if (resolvedClienteCodigo == 0) {
      try {
        final rPed = await db.rawQuery(
          'SELECT ped00_codcli FROM pckvendig000 WHERE ped00_numped = ? LIMIT 1',
          [pedidoId],
        );
        if (rPed.isNotEmpty && rPed.first['ped00_codcli'] != null) {
          resolvedClienteCodigo = int.tryParse(rPed.first['ped00_codcli'].toString()) ?? 0;
        }
      } catch (_) {}
    }

    // 1b. Validação de Valor Mínimo do Plano (pla00_vlrmin - PRD Seção 2.3)
    final int plaValCheck = int.tryParse(planoCodigo ?? '') ?? 0;
    if (plaValCheck > 0) {
      try {
        final colsPla = await db.rawQuery('PRAGMA table_info(cadpla00)');
        final plaColNames = colsPla.map((r) => r['name'].toString().toLowerCase()).toSet();
        if (plaColNames.contains('pla00_vlrmin')) {
          final rPla = await db.rawQuery('SELECT pla00_vlrmin FROM cadpla00 WHERE pla00_codigo = ? LIMIT 1', [plaValCheck]);
          if (rPla.isNotEmpty && rPla.first['pla00_vlrmin'] != null) {
            final vMin = (rPla.first['pla00_vlrmin'] is num)
                ? (rPla.first['pla00_vlrmin'] as num).toDouble()
                : (double.tryParse(rPla.first['pla00_vlrmin'].toString()) ?? 0.0);
            final double totalPedido = carrinhoItens
                .where((i) => !i.isBonificacao)
                .fold(0.0, (sum, i) => sum + (i.quantidade * i.precoUnitario));
            if (vMin > 0 && totalPedido < vMin) {
              final formattedMin = vMin.toStringAsFixed(2).replaceAll('.', ',');
              throw Exception('Valor total do pedido inferior ao valor mínimo exigido pelo plano de pagamento (Mínimo: R\$ $formattedMin)!');
            }
          }
        }
      } catch (e) {
        if (e.toString().contains('Valor total do pedido inferior')) rethrow;
      }
    }

    // 2. Parâmetros fiscais dos produtos
    for (final item in carrinhoItens) {
      final pid = item.codigoProduto;
      if (fiscalParams.containsKey(pid)) continue;

      double itemMva = 0.40;
      double itemAliqExt = 0.18;
      double itemAliqInt = 0.18;
      int codTrb = 1;

      for (final tbl in ['cadpro00', 'estpcopro00', 'estpro00', 'pro00']) {
        try {
          final exists = await db.rawQuery(
            "SELECT name FROM sqlite_master WHERE type='table' AND lower(name)=?", [tbl],
          );
          if (exists.isEmpty) continue;
          final cols = await db.rawQuery('PRAGMA table_info($tbl)');
          final colNames = cols.map((r) => r['name'].toString().toLowerCase()).toSet();

          String? pCodCol;
          for (final c in ['pro00_codigo', 'pro00_codpro', 'codigo', 'codpro']) {
            if (colNames.contains(c)) { pCodCol = c; break; }
          }
          if (pCodCol == null) continue;

          final rows = await db.rawQuery('SELECT * FROM $tbl WHERE $pCodCol = ? LIMIT 1', [pid]);
          if (rows.isNotEmpty) {
            final r = rows.first;
            for (final entry in r.entries) {
              final k = entry.key.toLowerCase();
              final v = entry.value;
              if (v == null) continue;
              final numVal = (v is num) ? v.toDouble() : double.tryParse(v.toString()) ?? 0.0;
              if (k.contains('mva') || k.contains('perst') || k.contains('aliqst')) {
                if (numVal > 0) itemMva = numVal > 1.0 ? numVal / 100.0 : numVal;
              } else if (k.contains('aliext') || k.contains('aliqdst') || k.contains('aliqext')) {
                if (numVal > 0) itemAliqExt = numVal > 1.0 ? numVal / 100.0 : numVal;
              } else if (k.contains('aliint') || k.contains('aliicm') || k.contains('aliquota')) {
                if (numVal > 0) itemAliqInt = numVal > 1.0 ? numVal / 100.0 : numVal;
              } else if (k.contains('codtrb') || k.contains('trb')) {
                codTrb = numVal.toInt();
              }
            }
            break;
          }
        } catch (_) {}
      }

      fiscalParams[pid] = {
        'mva': itemMva,
        'aliqExt': itemAliqExt,
        'aliqInt': itemAliqInt,
        'codTrb': codTrb.toDouble(),
      };
    }

    // 3. Tipo do agente cobrador
    if (codAgt != 0) {
      for (final tbl in ['codage00', 'cadagt00', 'cadage00', 'cadcob00', 'codcob00', 'cadcob000', 'cadage000', 'cadagt000']) {
        try {
          final exists = await db.rawQuery(
              "SELECT name FROM sqlite_master WHERE type='table' AND lower(name)=?", [tbl]);
          if (exists.isEmpty) continue;
          final colsT = await db.rawQuery('PRAGMA table_info($tbl)');
          final cnT = colsT.map((r) => r['name'].toString().toLowerCase()).toSet();
          String? codColT;
          String? tipoCol;
          for (final c in ['age00_codigo', 'agt00_codigo', 'agt00_codage', 'agt00_codagt', 'cob00_codigo', 'cob00_codcob', 'cad00_codigo', 'codigo']) {
            if (cnT.contains(c)) { codColT = c; break; }
          }
          for (final c in ['age00_tipo', 'agt00_tipo', 'agt00_tipage', 'cob00_tipo', 'tipo']) {
            if (cnT.contains(c)) { tipoCol = c; break; }
          }
          if (codColT != null && tipoCol != null) {
            final r = await db.rawQuery('SELECT $tipoCol as t FROM $tbl WHERE $codColT = ? LIMIT 1', [codAgt]);
            if (r.isNotEmpty && r.first['t'] != null) {
              final v = r.first['t'];
              tipoAgente = v is int ? v : int.tryParse(v.toString()) ?? 0;
              if (tipoAgente != 0) break;
            }
          }
        } catch (_) {}
      }
    }

    // 4. Snapshots clides/lindes/plades
    if (resolvedClienteCodigo != 0) {
      try {
        final cr = await db.rawQuery('SELECT cli00_descri FROM cadcli00 WHERE cli00_codigo = ? LIMIT 1', [resolvedClienteCodigo]);
        if (cr.isNotEmpty) clidesSnap = cr.first['cli00_descri']?.toString() ?? '';
      } catch (_) {}
    }
    final linVal = int.tryParse(linhaCodigo ?? '') ?? 0;
    if (linVal != 0) {
      try {
        final lr = await db.rawQuery('SELECT lin00_descri FROM cadlin00 WHERE lin00_codigo = ? LIMIT 1', [linVal]);
        if (lr.isNotEmpty) lindesSnap = lr.first['lin00_descri']?.toString() ?? '';
      } catch (_) {}
    }
    final plaVal = int.tryParse(planoCodigo ?? '') ?? 0;
    if (plaVal != 0) {
      try {
        final pr = await db.rawQuery('SELECT pla00_descri FROM cadpla00 WHERE pla00_codigo = ? LIMIT 1', [plaVal]);
        if (pr.isNotEmpty) pladesSnap = pr.first['pla00_descri']?.toString() ?? '';
      } catch (_) {}
    }

    // 5. Mapeamento para os modelos de domínio com cálculo fiscal
    final List<ItemPedidoVenda> itemsVenda = [];
    for (int i = 0; i < carrinhoItens.length; i++) {
      final item = carrinhoItens[i];
      final isBon = item.isBonificacao;
      final mv = item.mulver != 0 ? item.mulver : 1.0;
      final base = isBon ? 0.0 : (item.quantidade * item.precoUnitario);

      final f = fiscalParams[item.codigoProduto];
      final mva = f?['mva'] ?? 0.40;
      final aliqExt = f?['aliqExt'] ?? 0.18;
      final aliqInt = f?['aliqInt'] ?? 0.18;
      final isTrb = (f?['codTrb'] ?? 1.0) != 0.0;

      final double sub = (!isBon && isTrb)
          ? IcmsStService.calcularItem(
              valorItem: base,
              mva: mva,
              aliqPropria: aliqInt,
              aliqDestino: aliqExt,
            )
          : 0.0;

      itemsVenda.add(
        ItemPedidoVenda(
          digpro: item.codigoProduto,
          digqtd: isBon ? item.quantidadeBonificada : item.quantidade,
          digpco: item.precoUnitario,
          pcomax: item.precoUnitario,
          pcomin: item.precoUnitario,
          destot: 0.0,
          subtot: sub,
          bontyp: isBon ? 1 : 0,
          boncod: isBon ? (int.tryParse(item.codigoCombo) ?? 1) : 0,
          ccvtot: isBon ? item.totalItem : 0.0,
          digitm: i + 1,
          mulven: mv,
          mulemb: mv,
          percmb: 0.0,
        ),
      );
    }

    final pedido = PedidoVenda(
      codFil: codFil,
      codMov: pedidoId,
      codRep: codRep,
      codCli: resolvedClienteCodigo,
      codLin: int.tryParse(linhaCodigo ?? '') ?? 0,
      codPla: int.tryParse(planoCodigo ?? '') ?? 0,
      codAgt: codAgt,
      tipoAgente: tipoAgente,
      codReg: codRep,
      datSys: datSys,
      items: itemsVenda,
      clides: clidesSnap,
      lindes: lindesSnap,
      plades: pladesSnap,
      codTab: int.tryParse(planoCodigo ?? '') ?? 0,
      bonfrcven: bonfrcven,
      sttDig: PedidoSttDig.digitado,
      sttEnv: PedidoSttEnv.digitado,
    );
    pedido.calcularTotais();

    final String empresa = AppState().empresa_codigo.trim().isEmpty
        ? 'diniz'
        : AppState().empresa_codigo.trim();

    // 6. Salva os itens do carrinho no SQLite com status Digitado (1)
    final savedOk = await salvarCarrinhoPedido(
      pedidoId: pedidoId,
      clienteCodigo: resolvedClienteCodigo,
      linhaCodigo: linhaCodigo,
      planoCodigo: planoCodigo,
      carrinhoItens: carrinhoItens,
      sttDig: PedidoSttDig.digitado.value,
      codAgenteCobrador: codAgt,
      bonfrcven: bonfrcven,
      subtot: pedido.subtot,
      destot: pedido.destot,
      itensSubtot: itemsVenda.map((i) => i.subtot).toList(),
    );

    if (!savedOk) {
      print('>>> ERRO CRITICO AO GRAVAR PEDIDO: salvarCarrinhoPedido retornou false para pedido #$pedidoId');
      throw Exception('Falha ao salvar itens do pedido #$pedidoId no SQLite local.');
    }

    // 6b. Validação atômica: confirma que os itens foram gravados em pckvendig010.
    // Usa a mesma conexão singleton ativa — sem abrir nova sessão.
    List<Map<String, dynamic>> itensNoBanco = [];
    try {
      itensNoBanco = await db.rawQuery(
        'SELECT * FROM pckvendig010 WHERE ped10_numped = ?',
        [pedidoId],
      );
    } catch (_) {}

    if (itensNoBanco.isEmpty) {
      // Fallback: itens estão apenas em memória — grava agora
      print('[concluirVendaProcess] AVISO: pckvendig010 vazio para pedido #$pedidoId — executando insert de fallback');
      final fallbackOk = await salvarCarrinhoPedido(
        pedidoId: pedidoId,
        clienteCodigo: resolvedClienteCodigo,
        linhaCodigo: linhaCodigo,
        planoCodigo: planoCodigo,
        carrinhoItens: carrinhoItens,
        sttDig: PedidoSttDig.digitado.value,
        codAgenteCobrador: codAgt,
        bonfrcven: bonfrcven,
        subtot: pedido.subtot,
        destot: pedido.destot,
        itensSubtot: itemsVenda.map((i) => i.subtot).toList(),
      );
      if (!fallbackOk) {
        print('>>> ERRO CRITICO AO GRAVAR PEDIDO: fallback insert falhou para pedido #$pedidoId');
        throw Exception('Falha no fallback de itens do pedido #$pedidoId no SQLite local.');
      }
      // Re-verifica após fallback
      try {
        itensNoBanco = await db.rawQuery(
          'SELECT * FROM pckvendig010 WHERE ped10_numped = ?',
          [pedidoId],
        );
      } catch (_) {}
    }

    // Atualiza pckvendig000: ped00_sttdig = 1 (Digitado/Concluído) e ped00_sttenv = 0 (Aguardando Pacote)
    try {
      await db.rawUpdate(
        'UPDATE pckvendig000 SET ped00_sttdig = 1, ped00_sttenv = 0, ped00_pacstr = "" WHERE ped00_numped = ?',
        [pedidoId],
      );
    } catch (_) {}

    print('[concluirVendaProcess] TRANSACAO CONFIRMADA pckvendig000/pckvendig010 pedido #$pedidoId '
        '(sttDig=${PedidoSttDig.digitado.value}, sttEnv=${PedidoSttEnv.digitado.value}, itens=${itensNoBanco.length}, cobrador=$codAgt)');

    // 7. Persiste totais no cabeçalho SQLite e atualiza estatísticas locais (sem gerar .pac)
    final concluirService = ConcluirVendaService();
    await concluirService.salvarPedidoConcluidoLocal(
      pedido: pedido,
      empresa: empresa,
      codigoEquipe: codEqp,
    );
    print('DEBUG SUCESSO: Pedido $pedidoId concluído com ${itensNoBanco.length} itens e cobrador $codAgt (Aguardando Pacote)');
    return true;
  } catch (e, stack) {
    print('>>> ERRO REAL NO CONCLUIR_VENDA_PROCESS: $e \n $stack');
    throw Exception('Falha na gravação: $e');
  }
}
