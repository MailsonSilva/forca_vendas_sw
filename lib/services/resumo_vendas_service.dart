import 'package:intl/intl.dart';
import 'package:sqflite/sqflite.dart';
import '../app_state.dart';
import '../data/services/local_sales_database_service.dart';
import '../domain/models/resumo_vendas_model.dart';

/// Serviço responsável por processar, consolidar e calcular o
/// Relatório de Resumo de Vendas Diário e Apuração de Comissões (`ffrmrelresven00`).
class ResumoVendasService {
  static final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'pt_BR',
    symbol: 'R\$',
    decimalDigits: 2,
  );

  static String formatarMoeda(double valor) {
    return _currencyFormat.format(valor).replaceAll('\u00A0', ' ');
  }

  static final DateFormat _dateFormat = DateFormat('dd/MM/yyyy');
  static final DateFormat _dbDateFormat = DateFormat('yyyy-MM-dd');

  /// Consulta os pedidos e itens no SQLite local no período definido e
  /// realiza a apuração agregada e analítica de Vendas e Comissões.
  static Future<ResumoVendasConsolidado> obterResumoVendas({
    required DateTime dataInicio,
    required DateTime dataFim,
    int? codVen,
    int? codFil,
    Database? customDb,
  }) async {
    final db = customDb ?? await LocalSalesDatabaseService.getDatabase();
    final repCod = codVen ?? AppState().vendedor_codigo;
    final filCod = codFil ?? AppState().codFilialAtiva;

    final datIniStr = _dbDateFormat.format(dataInicio);
    final datFimStr = _dbDateFormat.format(dataFim);

    try {
      // 1. Busca os pedidos no período
      final whereClauses = <String>[
        'p.ped00_datsys >= ?',
        'p.ped00_datsys <= ?',
      ];
      final whereArgs = <dynamic>[datIniStr, datFimStr];

      if (repCod > 0) {
        whereClauses.add('(p.ped00_codven = ? OR p.ped00_codven = 0 OR p.ped00_codven IS NULL)');
        whereArgs.add(repCod);
      }

      if (filCod > 0) {
        whereClauses.add('(p.ped00_codfil = ? OR p.ped00_codfil = 0 OR p.ped00_codfil IS NULL)');
        whereArgs.add(filCod);
      }

      final whereSql = 'WHERE ${whereClauses.join(' AND ')}';
      final query = '''
        SELECT 
          p.*,
          c.cli00_descri
        FROM pckvendig000 p
        LEFT JOIN cadcli00 c ON c.cli00_codigo = p.ped00_codcli
        $whereSql
        ORDER BY p.ped00_datsys DESC, p.ped00_numped DESC
      ''';

      final pedidoRows = await db.rawQuery(query, whereArgs);

      // 2. Para cada pedido, busca os itens e apura comissões produto a produto
      final pedidosProcessados = <ResumoVendasPedidoItem>[];

      for (final pRow in pedidoRows) {
        final numPed = (pRow['ped00_numped'] as num?)?.toInt() ?? 0;

        const itemQuery = '''
          SELECT 
            i.*,
            p.pro00_descri,
            p.pro00_commax
          FROM pckvendig010 i
          LEFT JOIN cadpro00 p ON p.pro00_codigo = i.ped10_codpro
          WHERE i.ped10_numped = ?
          ORDER BY i.ped10_item ASC
        ''';

        final itemRows = await db.rawQuery(itemQuery, [numPed]);
        final itensModel = itemRows.map((ir) => ResumoVendasItemComissao.fromMap(ir)).toList();

        final pedModel = ResumoVendasPedidoItem.fromMap(pRow, itens: itensModel);
        pedidosProcessados.add(pedModel);
      }

      // 3. Agrupa os pedidos por data (`ped00_datsys`)
      final Map<String, List<ResumoVendasPedidoItem>> pedidosPorData = {};
      for (final p in pedidosProcessados) {
        pedidosPorData.putIfAbsent(p.dataEmissao, () => []).add(p);
      }

      final diasList = pedidosPorData.entries.map((entry) {
        return ResumoVendasDia.fromPedidos(entry.key, entry.value);
      }).toList();

      // Ordena os dias mais recentes primeiro
      diasList.sort((a, b) => b.data.compareTo(a.data));

      return ResumoVendasConsolidado.fromDias(
        dataInicio: dataInicio,
        dataFim: dataFim,
        dias: diasList,
      );
    } catch (_) {
      return ResumoVendasConsolidado.empty(dataInicio: dataInicio, dataFim: dataFim);
    }
  }

  /// Gera um resumo textual limpo e formatado para ser copiado ou compartilhado
  /// diretamente via WhatsApp ou Clipboard.
  static String gerarTextoCompartilhamento(
    ResumoVendasConsolidado resumo, {
    String? nomeVendedor,
  }) {
    final buffer = StringBuffer();
    final pIni = _dateFormat.format(resumo.dataInicio);
    final pFim = _dateFormat.format(resumo.dataFim);

    buffer.writeln('📊 *RESUMO DE VENDAS E COMISSÕES*');
    buffer.writeln('📅 Período: $pIni até $pFim');
    if (nomeVendedor != null && nomeVendedor.trim().isNotEmpty) {
      buffer.writeln('👤 Vendedor: $nomeVendedor');
    }
    buffer.writeln('━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    buffer.writeln('📦 Total de Pedidos: ${resumo.totalPedidos}');
    buffer.writeln('💰 Venda Bruta: ${formatarMoeda(resumo.totalVendaBruta)}');
    buffer.writeln('✂️ Devoluções/Cortes: ${formatarMoeda(resumo.totalDevolucoes)}');
    buffer.writeln('✅ Venda Líquida: ${formatarMoeda(resumo.totalVendaLiquida)}');
    buffer.writeln('⭐ Comissão Estimada: ${formatarMoeda(resumo.totalComissao)}');
    buffer.writeln('━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

    if (resumo.dias.isNotEmpty) {
      buffer.writeln('📋 *Detalhamento por Data:*');
      for (final dia in resumo.dias) {
        DateTime? dt;
        try {
          dt = DateTime.parse(dia.data);
        } catch (_) {}
        final dataFormatada = dt != null ? _dateFormat.format(dt) : dia.data;

        buffer.writeln('▪️ $dataFormatada (${dia.pedidos.length} pedidos) - Venda: ${formatarMoeda(dia.totalLiquido)} | Comis: ${formatarMoeda(dia.totalComissao)}');
      }
    }

    return buffer.toString().trim();
  }
}
