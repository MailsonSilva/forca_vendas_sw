import 'package:intl/intl.dart';

/// Modelo de dados consolidado de Saldo de Conta-Corrente do Vendedor (CCV / Saldo Flex)
/// Mapeia a tabela SQLite `fincaiccv01` e data em `fincaidat00`.
class ContaCorrenteSaldo {
  final int codFil;
  final int codVen;
  final double saldoBase;
  final double saldoEmDigitacao;
  final double saldoEmTransito;
  final double saldoDisponivel;
  final String? dataSincronizacao;

  const ContaCorrenteSaldo({
    required this.codFil,
    required this.codVen,
    required this.saldoBase,
    required this.saldoEmDigitacao,
    required this.saldoEmTransito,
    required this.saldoDisponivel,
    this.dataSincronizacao,
  });

  bool get isPositivo => saldoDisponivel > 0;
  bool get isNegativo => saldoDisponivel < 0;
  bool get isZerado => saldoDisponivel == 0;

  factory ContaCorrenteSaldo.empty({int codFil = 1, int codVen = 0}) {
    return ContaCorrenteSaldo(
      codFil: codFil,
      codVen: codVen,
      saldoBase: 0.0,
      saldoEmDigitacao: 0.0,
      saldoEmTransito: 0.0,
      saldoDisponivel: 0.0,
      dataSincronizacao: null,
    );
  }

  factory ContaCorrenteSaldo.fromMap(Map<String, dynamic> map, {String? dataSincronizacao}) {
    double parseDouble(dynamic val) {
      if (val == null) return 0.0;
      if (val is num) return val.toDouble();
      return double.tryParse(val.toString()) ?? 0.0;
    }

    int parseInt(dynamic val) {
      if (val == null) return 0;
      if (val is num) return val.toInt();
      return int.tryParse(val.toString()) ?? 0;
    }

    return ContaCorrenteSaldo(
      codFil: parseInt(map['ccv01_codfil'] ?? map['codfil']),
      codVen: parseInt(map['ccv01_codven'] ?? map['codven']),
      saldoBase: parseDouble(map['ccv01_vlrsal'] ?? map['vlrsal']),
      saldoEmDigitacao: parseDouble(map['ccv01_vlrusedig'] ?? map['vlrusedig']),
      saldoEmTransito: parseDouble(map['ccv01_vlrusepck'] ?? map['vlrusepck']),
      saldoDisponivel: parseDouble(map['ccv01_vlrsalatu'] ?? map['vlrsalatu']),
      dataSincronizacao: dataSincronizacao,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'ccv01_codfil': codFil,
      'ccv01_codven': codVen,
      'ccv01_vlrsal': saldoBase,
      'ccv01_vlrusedig': saldoEmDigitacao,
      'ccv01_vlrusepck': saldoEmTransito,
      'ccv01_vlrsalatu': saldoDisponivel,
    };
  }
}

/// Modelo de dados analítico para Lançamento / Movimentação de Conta-Corrente (CCV)
/// Mapeia a tabela SQLite `fincaimovccv00`.
class ContaCorrenteMovimentacao {
  final int? id;
  final int codFil;
  final int codVen;
  final String dataMovimento;
  final String tipoMovimento; // 'C' (Crédito) ou 'D' (Débito)
  final double valorMovimento;
  final double saldoAcumulado;
  final String observacao;

  const ContaCorrenteMovimentacao({
    this.id,
    required this.codFil,
    required this.codVen,
    required this.dataMovimento,
    required this.tipoMovimento,
    required this.valorMovimento,
    required this.saldoAcumulado,
    required this.observacao,
  });

  bool get isCredito => tipoMovimento.toUpperCase() == 'C';
  bool get isDebito => tipoMovimento.toUpperCase() == 'D';

  String get dataFormatada {
    if (dataMovimento.isEmpty) return '';
    try {
      if (dataMovimento.contains('-')) {
        final parts = dataMovimento.split('T')[0].split('-');
        if (parts.length == 3) {
          return '${parts[2].padLeft(2, '0')}/${parts[1].padLeft(2, '0')}/${parts[0]}';
        }
      }
      final parsed = DateTime.tryParse(dataMovimento);
      if (parsed != null) {
        return DateFormat('dd/MM/yyyy').format(parsed);
      }
    } catch (_) {}
    return dataMovimento;
  }

  factory ContaCorrenteMovimentacao.fromMap(Map<String, dynamic> map) {
    double parseDouble(dynamic val) {
      if (val == null) return 0.0;
      if (val is num) return val.toDouble();
      return double.tryParse(val.toString()) ?? 0.0;
    }

    int parseInt(dynamic val) {
      if (val == null) return 0;
      if (val is num) return val.toInt();
      return int.tryParse(val.toString()) ?? 0;
    }

    return ContaCorrenteMovimentacao(
      id: map['id'] != null ? parseInt(map['id']) : null,
      codFil: parseInt(map['ccv00_codfil'] ?? map['codfil']),
      codVen: parseInt(map['ccv00_codven'] ?? map['codven']),
      dataMovimento: map['ccv00_datmov']?.toString() ?? map['datmov']?.toString() ?? '',
      tipoMovimento: map['ccv00_typmov']?.toString().toUpperCase() ?? map['typmov']?.toString().toUpperCase() ?? 'C',
      valorMovimento: parseDouble(map['ccv00_vlrmov'] ?? map['vlrmov']),
      saldoAcumulado: parseDouble(map['ccv00_vlrsal'] ?? map['vlrsal']),
      observacao: map['ccv00_observ']?.toString() ?? map['observ']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'ccv00_codfil': codFil,
      'ccv00_codven': codVen,
      'ccv00_datmov': dataMovimento,
      'ccv00_typmov': tipoMovimento,
      'ccv00_vlrmov': valorMovimento,
      'ccv00_vlrsal': saldoAcumulado,
      'ccv00_observ': observacao,
    };
  }
}
