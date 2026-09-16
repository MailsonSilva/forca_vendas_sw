import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:url_launcher/url_launcher.dart';
import '../app_state.dart';
import '../data/services/local_sales_database_service.dart';
import '../core/formatters/currency_formatter.dart';

/// Representa um título individual / duplicata (dup00)
class TituloDuplicataItem {
  final int codigo;
  final int codCli;
  final String numeroDocumento;
  final DateTime? dataEmissao;
  final DateTime dataVencimento;
  final double valorOriginal;
  final double valorPago;
  final double saldoDevedor;
  final int diasAtraso;
  final bool isVencido;
  final double taxaJurosDiaria;
  final double valorJuros;
  final double totalComJuros;
  // SPEC-042: Mapeamento de Vendedor, Agente Cobrador e Tipo de Cobrança
  final int codVen;
  final int codAgt;
  final int codCob;

  TituloDuplicataItem({
    required this.codigo,
    required this.codCli,
    required this.numeroDocumento,
    this.dataEmissao,
    required this.dataVencimento,
    required this.valorOriginal,
    required this.valorPago,
    required this.saldoDevedor,
    required this.diasAtraso,
    required this.isVencido,
    this.taxaJurosDiaria = 0.0,
    this.valorJuros = 0.0,
    required this.totalComJuros,
    this.codVen = 0,
    this.codAgt = 0,
    this.codCob = 0,
  });
}

/// Representa a posição consolidada de um cliente no contas a receber
class ClienteReceberItem {
  final int codCli;
  final String razaoSocial;
  final String fantasia;
  final String cidadeUf;
  final double limiteCredito;
  final double limiteAtual;
  final double totalVencido;
  final double totalAVencer;
  final double totalDevedor;
  final double totalJuros;
  final int maiorDiasAtraso;
  final int qtdTitulosVencidos;
  final int qtdTitulosTotal;
  final List<TituloDuplicataItem> titulos;

  ClienteReceberItem({
    required this.codCli,
    required this.razaoSocial,
    required this.fantasia,
    required this.cidadeUf,
    required this.limiteCredito,
    required this.limiteAtual,
    required this.totalVencido,
    required this.totalAVencer,
    required this.totalDevedor,
    required this.totalJuros,
    required this.maiorDiasAtraso,
    required this.qtdTitulosVencidos,
    required this.qtdTitulosTotal,
    required this.titulos,
  });

  bool get temInadimplencia => qtdTitulosVencidos > 0 || totalVencido > 0;
}

enum FiltroReceber {
  todos,
  apenasVencidos,
  aVencer,
}

enum OrdenacaoReceber {
  maiorAtraso,
  maiorValor,
  alfabetica,
}

/// Serviço responsável pela auditoria e consultas de Contas a Receber (dup00)
class ReceberDuplicatasService {
  static final _dateFormat = DateFormat('dd/MM/yyyy');
  static String formatarMoeda(double valor) => formatMoeda(valor);
  static String formatarData(DateTime? dt) =>
      dt != null ? _dateFormat.format(dt) : '-';

  /// Normaliza data para corte de meia-noite (apenas dia/mês/ano)
  static DateTime normalizarData(DateTime dt) =>
      DateTime(dt.year, dt.month, dt.day);

  /// Calcula a quantidade de dias em atraso entre a data de vencimento e hoje
  static int calcularDiasAtraso(DateTime dtVencimento, {DateTime? hoje}) {
    final ref = normalizarData(hoje ?? DateTime.now());
    final ven = normalizarData(dtVencimento);
    if (!ven.isBefore(ref)) {
      return 0;
    }
    return ref.difference(ven).inDays;
  }

  /// Calcula os juros de mora acumulados:
  /// Juros = saldoDevedor * (ven00_txajur / 100) * diasAtraso
  static double calcularJurosMora({
    required double saldoDevedor,
    required double taxaJurosDiaria,
    required int diasAtraso,
  }) {
    if (diasAtraso <= 0 || taxaJurosDiaria <= 0 || saldoDevedor <= 0) {
      return 0.0;
    }
    final juros = saldoDevedor * (taxaJurosDiaria / 100.0) * diasAtraso;
    return (juros * 100).roundToDouble() / 100.0;
  }

  /// Converte string em DateTime de forma resiliente
  static DateTime? parseData(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    final str = value.toString().trim();
    if (str.isEmpty) return null;

    try {
      if (str.contains('-')) {
        return DateTime.parse(str.length == 10 ? str : str.substring(0, 10));
      }
      if (str.contains('/')) {
        final parts = str.split('/');
        if (parts.length == 3) {
          final d = int.tryParse(parts[0]) ?? 1;
          final m = int.tryParse(parts[1]) ?? 1;
          final y = int.tryParse(parts[2]) ?? 2000;
          return DateTime(y, m, d);
        }
      }
      if (str.length == 8) {
        final y = int.tryParse(str.substring(0, 4)) ?? 2000;
        final m = int.tryParse(str.substring(4, 6)) ?? 1;
        final d = int.tryParse(str.substring(6, 8)) ?? 1;
        return DateTime(y, m, d);
      }
    } catch (_) {}
    return null;
  }

  /// Obtém a taxa de juros diária configurada para o vendedor em cadrep00 (ven00_txajur)
  static Future<double> obterTaxaJurosVendedor(
    int codVen, {
    Database? dbOverride,
    String? dbPathOverride,
  }) async {
    final shouldClose = dbOverride == null;
    try {
      final db = dbOverride ??
          (dbPathOverride != null
              ? await openDatabase(dbPathOverride)
              : await LocalSalesDatabaseService.getDatabase(readOnly: true));
      try {
        final cols = await db.rawQuery('PRAGMA table_info(cadrep00)');
        final colNames = cols.map((r) => r['name'].toString().toLowerCase()).toSet();
        String colVen = colNames.contains('ven00_codigo')
            ? 'ven00_codigo'
            : (colNames.contains('rep00_codigo') ? 'rep00_codigo' : 'codigo');

        final rows = await db.rawQuery(
          'SELECT * FROM cadrep00 WHERE $colVen = ? LIMIT 1',
          [codVen],
        );
        if (rows.isNotEmpty) {
          final r = rows.first;
          for (final k in ['ven00_txajur', 'rep00_txajur', 'txajur', 'txa_jur']) {
            if (r.containsKey(k) && r[k] != null) {
              final v = _asDouble(r[k]);
              if (v >= 0) return v;
            }
          }
        }
      } finally {
        if (shouldClose) {
          await db.close();
        }
      }
    } catch (_) {}
    return 0.0;
  }

  static double _asDouble(dynamic val) {
    if (val == null) return 0.0;
    if (val is num) return val.toDouble();
    var str = val.toString().trim().replaceAll('R\$', '').replaceAll(' ', '');
    if (str.isEmpty) return 0.0;
    if (str.contains(',') && str.contains('.')) {
      if (str.indexOf('.') < str.indexOf(',')) {
        str = str.replaceAll('.', '').replaceAll(',', '.');
      } else {
        str = str.replaceAll(',', '');
      }
    } else if (str.contains(',')) {
      str = str.replaceAll(',', '.');
    }
    return double.tryParse(str) ?? 0.0;
  }

  /// Carrega e processa a lista de duplicatas de um cliente
  static Future<List<TituloDuplicataItem>> carregarTitulosCliente(
    int codCli, {
    double? taxaJurosOverride,
    Database? dbOverride,
    String? dbPathOverride,
    DateTime? hojeRef,
  }) async {
    final hoje = hojeRef ?? DateTime.now();
    final List<TituloDuplicataItem> titulos = [];
    final List<Database> dbsToSearch = [];
    final List<Database> dbsToClose = [];

    try {
      if (dbOverride != null) {
        dbsToSearch.add(dbOverride);
      }
      if (dbPathOverride != null) {
        try {
          final d = await openDatabase(dbPathOverride);
          dbsToSearch.add(d);
          dbsToClose.add(d);
        } catch (_) {}
      }

      try {
        final databasesPath = await getDatabasesPath();
        final mainDbPath = await LocalSalesDatabaseService.getDatabasePath();

        final pathsToTry = <String>{};
        if (dbOverride == null && dbPathOverride == null) {
          pathsToTry.add(mainDbPath);
        }
        pathsToTry.add(p.join(databasesPath, 'dbforcadig001.db'));
        pathsToTry.add(p.join(databasesPath, 'dbforcacad001.db'));

        for (final pth in pathsToTry) {
          if (dbOverride != null && pth == mainDbPath) continue;
          try {
            if (await File(pth).exists()) {
              final d = await openDatabase(pth, readOnly: true);
              dbsToSearch.add(d);
              dbsToClose.add(d);
            }
          } catch (_) {}
        }
      } catch (_) {}

      final candidateTables = [
        'finrecdup00',
        'dup00',
        'caddup00',
        'finrecdup',
        'findup00',
        'cadrecdup00',
      ];

      for (final db in dbsToSearch) {
        if (titulos.isNotEmpty) break;

        String targetTable = '';
        String targetColCli = '';
        String targetColVen = '';

        for (final tbl in candidateTables) {
          try {
            final cols = await db.rawQuery('PRAGMA table_info($tbl)');
            if (cols.isEmpty) continue;
            final colNames = cols.map((r) => r['name'].toString().toLowerCase()).toSet();

            String colCliExpr;
            if (colNames.contains('dup00_codcli') && colNames.contains('dup00_clicod')) {
              colCliExpr = 'COALESCE(dup00_codcli, dup00_clicod)';
            } else if (colNames.contains('dup00_codcli')) {
              colCliExpr = 'dup00_codcli';
            } else if (colNames.contains('dup00_clicod')) {
              colCliExpr = 'dup00_clicod';
            } else if (colNames.contains('codcli')) {
              colCliExpr = 'codcli';
            } else if (colNames.contains('clicod')) {
              colCliExpr = 'clicod';
            } else if (colNames.contains('cli00_codigo')) {
              colCliExpr = 'cli00_codigo';
            } else {
              continue;
            }

            final count = Sqflite.firstIntValue(await db.rawQuery(
              'SELECT COUNT(*) FROM $tbl WHERE (CAST($colCliExpr AS INTEGER) = CAST(? AS INTEGER) OR $colCliExpr = ?)',
              [codCli, codCli.toString()],
            )) ?? 0;

            if (count > 0) {
              targetTable = tbl;
              targetColCli = colCliExpr;
              targetColVen = colNames.contains('dup00_datven')
                  ? 'dup00_datven'
                  : (colNames.contains('datven') ? 'datven' : 'vencimento');
              break;
            } else if (targetTable.isEmpty) {
              targetTable = tbl;
              targetColCli = colCliExpr;
              targetColVen = colNames.contains('dup00_datven')
                  ? 'dup00_datven'
                  : (colNames.contains('datven') ? 'datven' : 'vencimento');
            }
          } catch (_) {}
        }

        if (targetTable.isEmpty) continue;

        final rows = await db.rawQuery(
          'SELECT * FROM $targetTable WHERE (CAST($targetColCli AS INTEGER) = CAST(? AS INTEGER) OR $targetColCli = ?) ORDER BY $targetColVen ASC',
          [codCli, codCli.toString()],
        );

        if (rows.isEmpty) continue;

        final Map<int, double> cacheTaxasRep = {};

        for (final r in rows) {
          final codigo = int.tryParse((r['dup00_codigo'] ?? r['codigo'] ?? '0').toString()) ?? 0;
          final doc = (r['dup00_numero'] ?? r['numero'] ?? r['dup00_codigo'] ?? codigo).toString();
          final dtEmi = parseData(r['dup00_datemi'] ?? r['datemi']);
          final dtVen = parseData(r['dup00_datven'] ?? r['datven']) ?? hoje;

          final valOri = _asDouble(r['dup00_valori'] ?? r['valori'] ?? r['valor']);
          final valPag = _asDouble(r['dup00_valpag'] ?? r['valpag']);

          double valDev = 0.0;
          if (r.containsKey('dup00_valdev') && r['dup00_valdev'] != null) {
            valDev = _asDouble(r['dup00_valdev']);
          } else if (r.containsKey('valdev') && r['valdev'] != null) {
            valDev = _asDouble(r['valdev']);
          } else {
            valDev = (valOri - valPag).clamp(0.0, double.infinity);
          }

          if (valDev <= 0.0 && valOri > 0 && valPag < valOri) {
            valDev = valOri - valPag;
          }

          if (valDev <= 0.0 && valOri > 0 && valPag >= valOri) continue;

          final codVen = int.tryParse((r['dup00_codven'] ?? r['codven'] ?? '0').toString()) ?? 0;
          final codAgt = int.tryParse((r['dup00_codagt'] ?? r['codagt'] ?? '0').toString()) ?? 0;
          final codCob = int.tryParse((r['dup00_codcob'] ?? r['codcob'] ?? '0').toString()) ?? 0;

          double taxaAplicada = taxaJurosOverride ?? 0.0;
          if (taxaAplicada <= 0.0 && codVen > 0) {
            if (!cacheTaxasRep.containsKey(codVen)) {
              cacheTaxasRep[codVen] = await obterTaxaJurosVendedor(codVen, dbOverride: db);
            }
            taxaAplicada = cacheTaxasRep[codVen] ?? 0.0;
          }
          if (taxaAplicada <= 0.0 && AppState().vendedor_codigo > 0) {
            if (!cacheTaxasRep.containsKey(AppState().vendedor_codigo)) {
              cacheTaxasRep[AppState().vendedor_codigo] =
                  await obterTaxaJurosVendedor(AppState().vendedor_codigo, dbOverride: db);
            }
            taxaAplicada = cacheTaxasRep[AppState().vendedor_codigo] ?? 0.0;
          }

          final diasCalculados = calcularDiasAtraso(dtVen, hoje: hoje);
          final isVencido = diasCalculados > 0;
          final diasAtraso = isVencido ? diasCalculados : 0;
          double juros = isVencido
              ? calcularJurosMora(
                  saldoDevedor: valDev,
                  taxaJurosDiaria: taxaAplicada,
                  diasAtraso: diasAtraso,
                )
              : 0.0;

          if (juros <= 0.0 && r.containsKey('dup00_valjur') && r['dup00_valjur'] != null) {
            juros = _asDouble(r['dup00_valjur']);
          }

          titulos.add(TituloDuplicataItem(
            codigo: codigo,
            codCli: codCli,
            numeroDocumento: doc,
            dataEmissao: dtEmi,
            dataVencimento: dtVen,
            valorOriginal: valOri > 0 ? valOri : valDev,
            valorPago: valPag,
            saldoDevedor: valDev,
            diasAtraso: diasAtraso,
            isVencido: isVencido,
            taxaJurosDiaria: taxaAplicada,
            valorJuros: juros,
            totalComJuros: valDev + juros,
            codVen: codVen,
            codAgt: codAgt,
            codCob: codCob,
          ));
        }
      }
    } finally {
      for (final d in dbsToClose) {
        try {
          await d.close();
        } catch (_) {}
      }
    }

    return titulos;
  }

  /// Lista consolidada de clientes com saldo devedor, com filtros e ordenação
  static Future<List<ClienteReceberItem>> listarClientesComDebito({
    FiltroReceber filtro = FiltroReceber.todos,
    OrdenacaoReceber ordenacao = OrdenacaoReceber.maiorAtraso,
    String busca = '',
    double? taxaJurosOverride,
    Database? dbOverride,
    String? dbPathOverride,
    DateTime? hojeRef,
  }) async {
    final hoje = hojeRef ?? DateTime.now();
    final List<ClienteReceberItem> resultado = [];
    final shouldClose = dbOverride == null;

    try {
      final db = dbOverride ??
          (dbPathOverride != null
              ? await openDatabase(dbPathOverride)
              : await LocalSalesDatabaseService.getDatabase(readOnly: true));

      try {
        // 1. Identifica tabelas candidatas procurando a que contém registros
        final candidateTables = [
          'finrecdup00',
          'dup00',
          'caddup00',
          'finrecdup',
          'findup00',
          'cadrecdup00',
        ];

        String dupTable = '';
        String colDev = '';
        String colOri = '';
        String colPag = '';

        for (final tbl in candidateTables) {
          try {
            final dupCols = await db.rawQuery('PRAGMA table_info($tbl)');
            if (dupCols.isEmpty) continue;
            final dupColNames = dupCols.map((r) => r['name'].toString().toLowerCase()).toSet();
            final cDev = dupColNames.contains('dup00_valdev')
                ? 'dup00_valdev'
                : (dupColNames.contains('valdev') ? 'valdev' : 'saldo');
            final cOri = dupColNames.contains('dup00_valori')
                ? 'dup00_valori'
                : (dupColNames.contains('valori') ? 'valori' : 'valor');
            final cPag = dupColNames.contains('dup00_valpag')
                ? 'dup00_valpag'
                : (dupColNames.contains('valpag') ? 'valpag' : 'pago');

            final count = Sqflite.firstIntValue(await db.rawQuery(
              'SELECT COUNT(*) FROM $tbl WHERE $cDev > 0 OR ($cOri - $cPag) > 0',
            )) ?? 0;

            if (count > 0) {
              dupTable = tbl;
              colDev = cDev;
              colOri = cOri;
              colPag = cPag;
              break;
            } else if (dupTable.isEmpty) {
              dupTable = tbl;
              colDev = cDev;
              colOri = cOri;
              colPag = cPag;
            }
          } catch (_) {}
        }

        if (dupTable.isEmpty) return resultado;

        // 2. Consulta títulos com saldo devedor
        final dupRows = await db.rawQuery('''
          SELECT * FROM $dupTable 
          WHERE $colDev > 0 OR ($colOri - $colPag) > 0
        ''');

        if (dupRows.isEmpty) {
          return resultado;
        }

        // 3. Agrupa títulos por cliente (SPEC-044/045: priorizar dup00_codcli / dup00_clicod)
        final Map<int, List<Map<String, dynamic>>> titulosPorCliente = {};
        for (final r in dupRows) {
          final codCli = int.tryParse(
                  (r['dup00_codcli'] ?? r['dup00_clicod'] ?? r['codcli'] ?? r['clicod'] ?? '0').toString()) ??
              0;
          if (codCli > 0) {
            titulosPorCliente.putIfAbsent(codCli, () => []).add(r);
          }
        }


        if (titulosPorCliente.isEmpty) {
          return resultado;
        }

        // 4. Carrega cadastro dos clientes agrupados
        final cliCols = await db.rawQuery('PRAGMA table_info(cadcli00)');
        final cliColNames = cliCols.map((r) => r['name'].toString().toLowerCase()).toSet();
        String colCliKey = cliColNames.contains('cli00_codigo')
            ? 'cli00_codigo'
            : (cliColNames.contains('codcli') ? 'codcli' : 'codigo');

        final codsList = titulosPorCliente.keys.join(',');
        final cliRows = await db.rawQuery(
          'SELECT * FROM cadcli00 WHERE CAST($colCliKey AS INTEGER) IN ($codsList)',
        );
        final Map<int, Map<String, dynamic>> cliMap = {
          for (final c in cliRows)
            (int.tryParse((c[colCliKey] ?? c['cli00_codigo'] ?? c['codigo']).toString()) ?? 0): c
        };

        final taxaJuros = taxaJurosOverride ?? 0.0;

        for (final entry in titulosPorCliente.entries) {
          final codCli = entry.key;
          final cData = cliMap[codCli] ?? {};

          final razao = (cData['cli00_descri'] ?? cData['descri'] ?? 'Cliente $codCli').toString();
          final fantasia = (cData['cli00_fantas'] ?? cData['fantas'] ?? '').toString();
          final cid = (cData['cli00_ciddes'] ?? '').toString();
          final uf = (cData['cli00_estsgl'] ?? '').toString();
          final cidadeUf = cid.isNotEmpty && uf.isNotEmpty
              ? '$cid - $uf'
              : (cid.isNotEmpty ? cid : uf);

          final creLim = _asDouble(cData['cli00_crelim']);
          final creAtu = _asDouble(cData['cli00_creatu']);

          final List<TituloDuplicataItem> titulosCliente = [];
          double totalVencido = 0.0;
          double totalAVencer = 0.0;
          double totalJuros = 0.0;
          int maiorDiasAtraso = 0;
          int qtdVencidos = 0;

          for (final r in entry.value) {
            final codigo = int.tryParse(
                    (r['dup00_codigo'] ?? r['codigo'] ?? '0').toString()) ??
                0;
            final doc = (r['dup00_numero'] ?? r['numero'] ?? r['dup00_codigo'] ?? codigo).toString();
            final dtEmi = parseData(r['dup00_datemi'] ?? r['datemi']);
            final dtVen = parseData(r['dup00_datven'] ?? r['datven']) ?? hoje;

            final valOri = _asDouble(r['dup00_valori'] ?? r['valori'] ?? r['valor']);
            final valPag = _asDouble(r['dup00_valpag'] ?? r['valpag']);

            double valDev = 0.0;
            if (r.containsKey('dup00_valdev') && r['dup00_valdev'] != null) {
              valDev = _asDouble(r['dup00_valdev']);
            } else {
              valDev = (valOri - valPag).clamp(0.0, double.infinity);
            }

            if (valDev <= 0) continue;

            final diasAtraso = calcularDiasAtraso(dtVen, hoje: hoje);
            final isVencido = diasAtraso > 0;
            final juros = isVencido
                ? calcularJurosMora(
                    saldoDevedor: valDev,
                    taxaJurosDiaria: taxaJuros,
                    diasAtraso: diasAtraso,
                  )
                : 0.0;

            if (isVencido) {
              qtdVencidos++;
              totalVencido += (valDev + juros);
              totalJuros += juros;
              if (diasAtraso > maiorDiasAtraso) {
                maiorDiasAtraso = diasAtraso;
              }
            } else {
              totalAVencer += valDev;
            }

            final codVen = int.tryParse((r['dup00_codven'] ?? r['codven'] ?? '0').toString()) ?? 0;
            final codAgt = int.tryParse((r['dup00_codagt'] ?? r['codagt'] ?? '0').toString()) ?? 0;
            final codCob = int.tryParse((r['dup00_codcob'] ?? r['codcob'] ?? '0').toString()) ?? 0;

            titulosCliente.add(TituloDuplicataItem(
              codigo: codigo,
              codCli: codCli,
              numeroDocumento: doc,
              dataEmissao: dtEmi,
              dataVencimento: dtVen,
              valorOriginal: valOri,
              valorPago: valPag,
              saldoDevedor: valDev,
              diasAtraso: diasAtraso,
              isVencido: isVencido,
              taxaJurosDiaria: taxaJuros,
              valorJuros: juros,
              totalComJuros: valDev + juros,
              codVen: codVen,
              codAgt: codAgt,
              codCob: codCob,
            ));
          }

          if (titulosCliente.isEmpty) continue;

          // Aplicação de Filtro Operacional
          if (filtro == FiltroReceber.apenasVencidos && qtdVencidos == 0) {
            continue;
          }
          if (filtro == FiltroReceber.aVencer && (totalAVencer <= 0 || qtdVencidos > 0)) {
            continue;
          }

          // Filtro de Busca textual
          if (busca.trim().isNotEmpty) {
            final termo = busca.trim().toLowerCase();
            final matchCod = codCli.toString().contains(termo);
            final matchRazao = razao.toLowerCase().contains(termo);
            final matchFantasia = fantasia.toLowerCase().contains(termo);
            if (!matchCod && !matchRazao && !matchFantasia) {
              continue;
            }
          }

          // Ordena títulos do cliente por vencimento crescente
          titulosCliente.sort((a, b) => a.dataVencimento.compareTo(b.dataVencimento));

          resultado.add(ClienteReceberItem(
            codCli: codCli,
            razaoSocial: razao,
            fantasia: fantasia,
            cidadeUf: cidadeUf,
            limiteCredito: creLim,
            limiteAtual: creAtu,
            totalVencido: totalVencido,
            totalAVencer: totalAVencer,
            totalDevedor: totalVencido + totalAVencer,
            totalJuros: totalJuros,
            maiorDiasAtraso: maiorDiasAtraso,
            qtdTitulosVencidos: qtdVencidos,
            qtdTitulosTotal: titulosCliente.length,
            titulos: titulosCliente,
          ));
        }
      } finally {
        if (shouldClose) {
          await db.close();
        }
      }
    } catch (_) {}

    // Ordenação da lista geral
    switch (ordenacao) {
      case OrdenacaoReceber.maiorAtraso:
        // Prioriza maior dias de atraso (Aging). Desempate por maior valor vencido.
        resultado.sort((a, b) {
          final compAtraso = b.maiorDiasAtraso.compareTo(a.maiorDiasAtraso);
          if (compAtraso != 0) return compAtraso;
          return b.totalVencido.compareTo(a.totalVencido);
        });
        break;
      case OrdenacaoReceber.maiorValor:
        resultado.sort((a, b) => b.totalDevedor.compareTo(a.totalDevedor));
        break;
      case OrdenacaoReceber.alfabetica:
        resultado.sort((a, b) =>
            a.razaoSocial.toLowerCase().compareTo(b.razaoSocial.toLowerCase()));
        break;
    }

    return resultado;
  }

  /// Gera um texto amigável e limpo para envio de cobrança via WhatsApp ou Clipboard
  static String gerarTextoCobrancaAmigavel(
    ClienteReceberItem cliente, {
    String? nomeVendedor,
  }) {
    final buffer = StringBuffer();
    buffer.writeln('📄 *EXTRATO DE DUPLICATAS / CONTAS A RECEBER*');
    buffer.writeln('👤 *Cliente:* (${cliente.codCli}) ${cliente.razaoSocial}');
    if (cliente.fantasia.isNotEmpty) {
      buffer.writeln('🏢 *Fantasia:* ${cliente.fantasia}');
    }
    if (nomeVendedor != null && nomeVendedor.trim().isNotEmpty) {
      buffer.writeln('💼 *Representante:* $nomeVendedor');
    }
    buffer.writeln('━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

    if (cliente.qtdTitulosVencidos > 0) {
      buffer.writeln('⚠️ *Títulos Vencidos (${cliente.qtdTitulosVencidos}):*');
      for (final t in cliente.titulos.where((x) => x.isVencido)) {
        buffer.writeln('• Título: ${t.numeroDocumento}');
        buffer.writeln('  Vencimento: ${formatarData(t.dataVencimento)} (${t.diasAtraso} dias em atraso)');
        buffer.writeln('  Saldo: ${formatarMoeda(t.saldoDevedor)}');
        if (t.valorJuros > 0) {
          buffer.writeln('  Juros Acumulados: ${formatarMoeda(t.valorJuros)}');
          buffer.writeln('  Total c/ Juros: ${formatarMoeda(t.totalComJuros)}');
        }
      }
      buffer.writeln('━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    }

    final titulosAVencer = cliente.titulos.where((x) => !x.isVencido).toList();
    if (titulosAVencer.isNotEmpty) {
      buffer.writeln('📅 *Títulos A Vencer (${titulosAVencer.length}):*');
      for (final t in titulosAVencer) {
        buffer.writeln('• Título: ${t.numeroDocumento} | Venc: ${formatarData(t.dataVencimento)} | Saldo: ${formatarMoeda(t.saldoDevedor)}');
      }
      buffer.writeln('━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    }

    buffer.writeln('💰 *Total Vencido:* ${formatarMoeda(cliente.totalVencido)}');
    buffer.writeln('⏳ *Total A Vencer:* ${formatarMoeda(cliente.totalAVencer)}');
    buffer.writeln('📌 *Total Geral Devedor:* ${formatarMoeda(cliente.totalDevedor)}');

    return buffer.toString();
  }

  /// Abre o WhatsApp com o texto de cobrança amigável preenchido
  static Future<bool> compartilharWhatsApp(
    BuildContext context,
    ClienteReceberItem cliente, {
    String? nomeVendedor,
  }) async {
    final texto = gerarTextoCobrancaAmigavel(cliente, nomeVendedor: nomeVendedor);
    final encoded = Uri.encodeComponent(texto);
    final whatsappUri = Uri.parse('whatsapp://send?text=$encoded');
    final webWhatsappUri = Uri.parse('https://api.whatsapp.com/send?text=$encoded');

    try {
      if (await canLaunchUrl(whatsappUri)) {
        return await launchUrl(whatsappUri, mode: LaunchMode.externalApplication);
      } else if (await canLaunchUrl(webWhatsappUri)) {
        return await launchUrl(webWhatsappUri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}

    // Fallback: cópia para clipboard
    if (context.mounted) {
      await copiarClipboard(context, cliente, nomeVendedor: nomeVendedor);
    }
    return false;
  }

  /// Copia o extrato formatado para a área de transferência do dispositivo
  static Future<void> copiarClipboard(
    BuildContext context,
    ClienteReceberItem cliente, {
    String? nomeVendedor,
  }) async {
    final texto = gerarTextoCobrancaAmigavel(cliente, nomeVendedor: nomeVendedor);
    await Clipboard.setData(ClipboardData(text: texto));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Extrato de duplicatas copiado para a área de transferência!'),
          backgroundColor: Color(0xFF2E7D32),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }
}
