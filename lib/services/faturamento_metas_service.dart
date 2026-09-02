import 'package:sqflite/sqflite.dart';
import '../app_state.dart';
import '../data/services/local_sales_database_service.dart';
import '../domain/models/faturamento_metas_model.dart';

/// Serviço responsável por gerenciar a sintetização local, regras fiscais
/// e validações de faturamento e metas do vendedor (`ffrmrelfatcvd00` / `relestfatcvd00`).
class FaturamentoMetasService {
  /// Validação pura de cálculo de Limite de Pessoa Física (`getPEDTOTPessoaFisicaCheck`).
  ///
  /// - [tipoCliente]: 1 = Pessoa Física (PF), 2 = Pessoa Jurídica (PJ).
  /// - [valorPedidoAtual]: Valor total do pedido em checkout/digitação.
  /// - [totalAcumuladoPF]: Total consolidado de vendas PF no mês (ERP + enviados + rascunhos).
  /// - [limiteLiberadoPF]: Cota máxima de faturamento autorizada para PF (`fat00_vlrtotlib`).
  static ResultadoValidacaoLimitePF validarLimitePessoaFisicaCalculado({
    required int tipoCliente,
    required double valorPedidoAtual,
    required double totalAcumuladoPF,
    required double limiteLiberadoPF,
  }) {
    // 1. Clientes Pessoa Jurídica (PJ / tipo 2) não possuem trava de cota PF
    if (tipoCliente != 1) {
      return ResultadoValidacaoLimitePF.liberado(
        limiteTotal: limiteLiberadoPF,
        totalAcumulado: totalAcumuladoPF,
        valorPedido: valorPedidoAtual,
        limiteRestante: limiteLiberadoPF > 0.0 ? (limiteLiberadoPF - totalAcumuladoPF) : 0.0,
      );
    }

    // 2. Se o limite autorizado for zero ou negativo, a trava está desativada / sem teto
    if (limiteLiberadoPF <= 0.0) {
      return ResultadoValidacaoLimitePF.liberado(
        limiteTotal: 0.0,
        totalAcumulado: totalAcumuladoPF,
        valorPedido: valorPedidoAtual,
        limiteRestante: 0.0,
      );
    }

    final limiteRestante = limiteLiberadoPF - totalAcumuladoPF;
    final totalProjetado = totalAcumuladoPF + valorPedidoAtual;

    // 3. Verifica se o pedido estoura o limite liberado
    if (totalProjetado > limiteLiberadoPF) {
      final fLimite = limiteLiberadoPF.toStringAsFixed(2).replaceAll('.', ',');
      final fRestante = (limiteRestante > 0 ? limiteRestante : 0.0).toStringAsFixed(2).replaceAll('.', ',');
      final fPedido = valorPedidoAtual.toStringAsFixed(2).replaceAll('.', ',');

      return ResultadoValidacaoLimitePF.bloqueado(
        limiteTotal: limiteLiberadoPF,
        totalAcumulado: totalAcumuladoPF,
        valorPedido: valorPedidoAtual,
        limiteRestante: limiteRestante,
        mensagem: 'Limite de faturamento para Pessoa Física excedido no mês! '
            '(Limite: R\$ $fLimite, Saldo Disponível: R\$ $fRestante, Pedido: R\$ $fPedido)',
      );
    }

    // 4. Pedido dentro do limite autorizado
    return ResultadoValidacaoLimitePF.liberado(
      limiteTotal: limiteLiberadoPF,
      totalAcumulado: totalAcumuladoPF,
      valorPedido: valorPedidoAtual,
      limiteRestante: limiteLiberadoPF - totalProjetado,
    );
  }

  /// Valida o limite de Pessoa Física consultando o banco SQLite local (`getPEDTOTPessoaFisicaCheck`).
  static Future<ResultadoValidacaoLimitePF> validarLimitePessoaFisica({
    required int clienteCodigo,
    required double valorPedido,
    int? codVen,
    int? codFil,
    Database? customDb,
  }) async {
    final db = customDb ?? await LocalSalesDatabaseService.getDatabase();
    final repCod = codVen ?? AppState().vendedor_codigo;
    final filCod = codFil ?? AppState().codFilialAtiva;

    int tipoCliente = 2; // Default PJ se não localizado
    try {
      final cliRows = await db.rawQuery(
        'SELECT cli00_typpes FROM cadcli00 WHERE cli00_codigo = ? LIMIT 1',
        [clienteCodigo],
      );
      if (cliRows.isNotEmpty && cliRows.first['cli00_typpes'] != null) {
        tipoCliente = (cliRows.first['cli00_typpes'] as num).toInt();
      }
    } catch (_) {}

    // Se for PJ, libera imediatamente sem onerar consultas de metas
    if (tipoCliente != 1) {
      return ResultadoValidacaoLimitePF.liberado(valorPedido: valorPedido);
    }

    // Obtém a cota configurada para PF
    double limiteLiberadoPF = 0.0;
    double faturadoErpPF = 0.0;
    try {
      var metaRows = await db.rawQuery(
        'SELECT fat00_vlrtotlib, fat00_vlrfatven FROM estfatcvd00 '
        'WHERE fat00_clityp = 1 AND (fat00_codven = ? OR fat00_codven = 0) '
        'AND (fat00_codfil = ? OR fat00_codfil = 0 OR fat00_codfil IS NULL) '
        'LIMIT 1',
        [repCod, filCod],
      );
      if (metaRows.isEmpty && repCod > 0) {
        metaRows = await db.rawQuery(
          'SELECT fat00_vlrtotlib, fat00_vlrfatven FROM estfatcvd00 '
          'WHERE fat00_clityp = 1 AND (fat00_codven = ? OR fat00_codven = 0) '
          'LIMIT 1',
          [repCod],
        );
      }
      if (metaRows.isEmpty) {
        metaRows = await db.rawQuery(
          'SELECT fat00_vlrtotlib, fat00_vlrfatven FROM estfatcvd00 WHERE fat00_clityp = 1 LIMIT 1',
        );
      }
      if (metaRows.isNotEmpty) {
        limiteLiberadoPF = (metaRows.first['fat00_vlrtotlib'] as num?)?.toDouble() ?? 0.0;
        faturadoErpPF = (metaRows.first['fat00_vlrfatven'] as num?)?.toDouble() ?? 0.0;
      }
    } catch (_) {}

    // Se o limite não está configurado (> 0), libera
    if (limiteLiberadoPF <= 0.0) {
      return ResultadoValidacaoLimitePF.liberado(valorPedido: valorPedido);
    }

    // Calcula pedidos locais de Pessoa Física (enviados e rascunhos)
    double vendasLocaisPF = 0.0;
    try {
      final localRows = await db.rawQuery('''
        SELECT COALESCE(SUM(p.ped00_digtot), 0.0) AS total_local
        FROM pckvendig000 p
        INNER JOIN cadcli00 c ON c.cli00_codigo = p.ped00_codcli
        WHERE c.cli00_typpes = 1
      ''');
      if (localRows.isNotEmpty) {
        vendasLocaisPF = (localRows.first['total_local'] as num?)?.toDouble() ?? 0.0;
      }
    } catch (_) {}

    final totalAcumuladoPF = faturadoErpPF + vendasLocaisPF;

    return validarLimitePessoaFisicaCalculado(
      tipoCliente: tipoCliente,
      valorPedidoAtual: valorPedido,
      totalAcumuladoPF: totalAcumuladoPF,
      limiteLiberadoPF: limiteLiberadoPF,
    );
  }

  /// Sintetiza os dados de faturamento e metas (`ett_sintetize_ESTFATCVD00`),
  /// fundindo o histórico do ERP (`estfatcvd00`) com os pedidos locais (`pckvendig000`).
  static Future<FaturamentoConsolidadoResumo> obterMetasConsolidadas({
    int? codVen,
    int? codFil,
    Database? customDb,
  }) async {
    final db = customDb ?? await LocalSalesDatabaseService.getDatabase();
    final repCod = codVen ?? AppState().vendedor_codigo;
    final filCod = codFil ?? AppState().codFilialAtiva;

    String? dataSinc;
    try {
      final dRows = await db.rawQuery('SELECT dat00_dattim FROM estfatdat00 LIMIT 1');
      if (dRows.isNotEmpty && dRows.first['dat00_dattim'] != null) {
        dataSinc = dRows.first['dat00_dattim'].toString();
      }
    } catch (_) {}

    MetaSegmentoModel pfModel = MetaSegmentoModel.empty(codFil: filCod, codVen: repCod, tipoPessoa: 1);
    MetaSegmentoModel pjModel = MetaSegmentoModel.empty(codFil: filCod, codVen: repCod, tipoPessoa: 2);

    try {
      // 1. Busca metas cadastradas do ERP para PF e PJ
      var metaRows = await db.rawQuery(
        'SELECT * FROM estfatcvd00 WHERE fat00_codven = ?',
        [repCod],
      );

      if (metaRows.isEmpty && repCod > 0) {
        metaRows = await db.rawQuery('SELECT * FROM estfatcvd00 LIMIT 2');
      }

      Map<int, Map<String, dynamic>> erpMetas = {};
      for (final r in metaRows) {
        final typ = (r['fat00_clityp'] as num?)?.toInt() ?? 0;
        if (typ == 1 || typ == 2) {
          erpMetas[typ] = r;
        }
      }

      // 2. Calcula agregação de pedidos locais por tipo de cliente
      // Transito: ped00_sttenv IN (1, 2)
      // Rascunho: ped00_sttenv = 0
      final localAgregados = await db.rawQuery('''
        SELECT 
          c.cli00_typpes AS tipo_pessoa,
          COALESCE(SUM(CASE WHEN p.ped00_sttenv IN (1, 2) THEN p.ped00_digtot ELSE 0 END), 0.0) AS transito,
          COALESCE(SUM(CASE WHEN p.ped00_sttenv = 0 THEN p.ped00_digtot ELSE 0 END), 0.0) AS rascunho
        FROM pckvendig000 p
        INNER JOIN cadcli00 c ON c.cli00_codigo = p.ped00_codcli
        GROUP BY c.cli00_typpes
      ''');

      Map<int, Map<String, double>> agregadosPorTipo = {};
      for (final r in localAgregados) {
        final typ = (r['tipo_pessoa'] as num?)?.toInt() ?? 0;
        agregadosPorTipo[typ] = {
          'transito': (r['transito'] as num?)?.toDouble() ?? 0.0,
          'rascunho': (r['rascunho'] as num?)?.toDouble() ?? 0.0,
        };
      }

      // 3. Monta o modelo de Pessoa Física (tipo 1)
      final mapPf = erpMetas[1] ?? {
        'fat00_codfil': filCod,
        'fat00_codven': repCod,
        'fat00_clityp': 1,
        'fat00_clides': 'Fisica',
      };
      pfModel = MetaSegmentoModel.fromMap(
        mapPf,
        digitadoTransito: agregadosPorTipo[1]?['transito'] ?? 0.0,
        rascunhoLocal: agregadosPorTipo[1]?['rascunho'] ?? 0.0,
      );

      // 4. Monta o modelo de Pessoa Jurídica (tipo 2)
      final mapPj = erpMetas[2] ?? {
        'fat00_codfil': filCod,
        'fat00_codven': repCod,
        'fat00_clityp': 2,
        'fat00_clides': 'Juridica',
      };
      pjModel = MetaSegmentoModel.fromMap(
        mapPj,
        digitadoTransito: agregadosPorTipo[2]?['transito'] ?? 0.0,
        rascunhoLocal: agregadosPorTipo[2]?['rascunho'] ?? 0.0,
      );
    } catch (e) {
      print('Erro ao obter metas consolidadas: $e');
    }

    return FaturamentoConsolidadoResumo.calcular(
      pf: pfModel,
      pj: pjModel,
      dataSincronizacao: dataSinc,
    );
  }
}
