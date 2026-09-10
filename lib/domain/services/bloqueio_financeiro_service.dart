import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import '../../app_constants.dart';
import '../../app_state.dart';
import '../../services/receber_duplicatas_service.dart';
import '../../core/formatters/currency_formatter.dart';

class BloqueioFinanceiroResult {
  final bool bloqueado;
  final String motivo;
  BloqueioFinanceiroResult({required this.bloqueado, required this.motivo});
}

/// Representa uma duplicata / título com vencimento em atraso (dup00)
class TituloVencidoItem {
  final String numeroDocumento;
  final String dataEmissao;
  final String dataVencimento;
  final double valor;
  final int diasAtraso;
  final double valorJuros;
  final double saldoDevedor;

  TituloVencidoItem({
    required this.numeroDocumento,
    required this.dataEmissao,
    required this.dataVencimento,
    required this.valor,
    required this.diasAtraso,
    this.valorJuros = 0.0,
    this.saldoDevedor = 0.0,
  });
}

/// PRD C1 & Especificação Técnica — Validação de Crédito e Títulos Vencidos (usysvenblk00)
class BloqueioFinanceiroService {
  /// Verifica limite de crédito: Limite Restante = cli00_creatu - Total do Pedido Atual
  static BloqueioFinanceiroResult verificaCredito({
    double? crelim,
    required double creatu,
    required double valorPedido,
  }) {
    if (!kEnableBloqueioFinanceiro) {
      return BloqueioFinanceiroResult(bloqueado: false, motivo: '');
    }
    // Na abertura com carrinho zerado ou valor 0, não bloqueia
    if (valorPedido <= 0) {
      return BloqueioFinanceiroResult(bloqueado: false, motivo: '');
    }
    final limiteRestante = creatu - valorPedido;
    if (limiteRestante < 0 || creatu <= 0) {
      return BloqueioFinanceiroResult(
        bloqueado: true,
        motivo: 'Limite de crédito excedido. Disponível: ${creatu.toMoeda()}',
      );
    }
    return BloqueioFinanceiroResult(bloqueado: false, motivo: '');
  }

  /// Verifica se o plano de pagamento é à vista (pla00_codtyp == 0 / à vista / dinheiro)
  static Future<bool> isPlanoAVista(String? planoCodigo, {String? dbPathOverride}) async {
    final plaCod = int.tryParse(planoCodigo ?? '') ?? 0;
    if (plaCod == 0) return true;
    try {
      final path = dbPathOverride ?? p.join(await getDatabasesPath(), 'dbforcacad001.db');
      final db = await openDatabase(path, readOnly: true);
      try {
        final r = await db.rawQuery('SELECT * FROM cadpla00 WHERE pla00_codigo = ? LIMIT 1', [plaCod]);
        if (r.isNotEmpty) {
          final row = r.first;
          final typ = row['pla00_codtyp'] ?? row['pla00_tipval'] ?? row['codtyp'];
          if (typ != null) {
            final typInt = (typ is num) ? typ.toInt() : int.tryParse(typ.toString()) ?? 1;
            return typInt == 0;
          }
          final desc = (row['pla00_descri'] ?? row['descri'] ?? '').toString().trim().toUpperCase();
          if (desc.startsWith('A VISTA') ||
              desc.startsWith('À VISTA') ||
              desc == '0 DIAS' ||
              desc.contains('DINHEIRO')) {
            return true;
          }
          return false;
        }
      } finally {
        await db.close();
      }
    } catch (_) {}
    return false;
  }

  /// Validação impeditiva de limite de crédito no fechamento do pedido:
  /// - Desconsiderada em vendas à vista (pla00_codtyp = 0).
  /// - Flexibilizada caso o representante possua permissão ven00_ignlimfis == 1.
  /// - Bloqueia caso o total da venda exceda o saldo de crédito atual (cli00_creatu).
  static Future<BloqueioFinanceiroResult> verificaFechamentoPedido({
    required int clienteCodigo,
    required double valorPedido,
    required String? planoCodigo,
    String? dbPathOverride,
  }) async {
    if (!kEnableBloqueioFinanceiro) {
      return BloqueioFinanceiroResult(bloqueado: false, motivo: '');
    }

    // 1. Permissão comercial para ignorar limite fiscal (ven00_ignlimfis == 1)
    if (AppState().ven_ignlimfis == 1) {
      return BloqueioFinanceiroResult(bloqueado: false, motivo: '');
    }

    // 2. Venda à vista não consome limite de crédito rotativo
    final aVista = await isPlanoAVista(planoCodigo, dbPathOverride: dbPathOverride);
    if (aVista) {
      return BloqueioFinanceiroResult(bloqueado: false, motivo: '');
    }

    // 3. Confronta valor total do pedido com saldo disponível (cli00_creatu)
    double creatu = 0.0;
    try {
      final path = dbPathOverride ?? p.join(await getDatabasesPath(), 'dbforcacad001.db');
      final db = await openDatabase(path);
      try {
        final r = await db.rawQuery(
          'SELECT cli00_creatu, cli00_crelim FROM cadcli00 WHERE cli00_codigo = ? LIMIT 1',
          [clienteCodigo],
        );
        if (r.isNotEmpty) {
          final v = r.first['cli00_creatu'] ?? r.first['cli00_crelim'];
          if (v != null) {
            creatu = (v is num) ? v.toDouble() : double.tryParse(v.toString()) ?? 0.0;
          }
        }
      } finally {
        await db.close();
      }
    } catch (_) {}

    final limiteRestante = creatu - valorPedido;
    if (limiteRestante < 0 || creatu <= 0) {
      return BloqueioFinanceiroResult(
        bloqueado: true,
        motivo: 'Limite de crédito insuficiente para fechamento a prazo.\nTotal do Pedido: ${valorPedido.toMoeda()}\nSaldo de Crédito Disponível: ${creatu.toMoeda()}',
      );
    }

    return BloqueioFinanceiroResult(bloqueado: false, motivo: '');
  }

  /// Consulta lista de títulos vencidos utilizando o ReceberDuplicatasService centralizado (DRY)
  static Future<List<TituloVencidoItem>> listarTitulosVencidos(
    int cliCodigo, {
    String? dbPathOverride,
  }) async {
    final List<TituloVencidoItem> itens = [];
    try {
      final titulos = await ReceberDuplicatasService.carregarTitulosCliente(
        cliCodigo,
        dbPathOverride: dbPathOverride,
      );

      for (final t in titulos) {
        if (t.isVencido) {
          itens.add(TituloVencidoItem(
            numeroDocumento: t.numeroDocumento,
            dataEmissao: ReceberDuplicatasService.formatarData(t.dataEmissao),
            dataVencimento: ReceberDuplicatasService.formatarData(t.dataVencimento),
            valor: t.saldoDevedor,
            diasAtraso: t.diasAtraso,
            valorJuros: t.valorJuros,
            saldoDevedor: t.saldoDevedor,
          ));
        }
      }
    } catch (_) {}
    return itens;
  }

  /// Verifica duplicatas atrasadas via tabela findup00/dup00 se existir.
  static Future<BloqueioFinanceiroResult> verificaDuplicatasAtrasadas(int cliCodigo, {String? dbPathOverride}) async {
    if (!kEnableBloqueioFinanceiro) {
      return BloqueioFinanceiroResult(bloqueado: false, motivo: '');
    }
    final titulos = await listarTitulosVencidos(cliCodigo, dbPathOverride: dbPathOverride);
    if (titulos.isNotEmpty) {
      return BloqueioFinanceiroResult(
        bloqueado: true,
        motivo: 'Cliente possui ${titulos.length} título(s) vencido(s).',
      );
    }
    return BloqueioFinanceiroResult(bloqueado: false, motivo: '');
  }

  /// Valida a senha de supervisor (ven00_passet) gravada nas tabelas cadrep00 / cadven00 ou na sessão.
  static Future<bool> validaSenhaSupervisor(String senhaDigitada, {String? dbPathOverride}) async {
    final senha = senhaDigitada.trim();
    if (senha.isEmpty) return false;

    // 1. Checa senha na sessão se já carregada
    if (AppState().ven_passet.isNotEmpty && AppState().ven_passet.trim() == senha) {
      return true;
    }

    // 2. Checa no banco de dados local
    try {
      final dbPath = dbPathOverride ?? p.join(await getDatabasesPath(), 'dbforcacad001.db');
      if (!await File(dbPath).exists()) return false;
      final db = await openDatabase(dbPath, readOnly: true);
      try {
        final tables = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table'");
        final names = tables.map((r) => r['name'].toString().toLowerCase()).toSet();

        for (final tbl in ['cadrep00', 'cadven00']) {
          if (names.contains(tbl)) {
            final cols = await db.rawQuery('PRAGMA table_info($tbl)');
            final cn = cols.map((r) => r['name'].toString().toLowerCase()).toSet();
            if (cn.contains('ven00_passet')) {
              final rows = await db.rawQuery(
                'SELECT ven00_passet FROM $tbl WHERE TRIM(ven00_passet) = ? LIMIT 1',
                [senha],
              );
              if (rows.isNotEmpty) {
                await db.close();
                return true;
              }
            }
          }
        }
        await db.close();
        return false;
      } catch (_) {
        try { await db.close(); } catch (_) {}
        return false;
      }
    } catch (_) {
      return false;
    }
  }

  /// Limite restante = cli00_creatu - valorPedido
  static double limiteDisponivel(double creatu, [double valorPedido = 0.0]) => creatu - valorPedido;
}
