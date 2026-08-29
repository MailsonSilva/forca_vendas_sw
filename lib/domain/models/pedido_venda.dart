import 'package:sqflite/sqflite.dart';
import '../../data/services/local_sales_database_service.dart';
import 'status_envio.dart';

/// Representa uma parcela de pagamento projetada com valor e vencimento em dia útil
class ParcelaVenda {
  ParcelaVenda({
    required this.numero,
    required this.dataVencimento,
    required this.valor,
  });

  final int numero;
  final DateTime dataVencimento;
  final double valor;

  String get dataFormatada {
    final y = dataVencimento.year.toString().padLeft(4, '0');
    final m = dataVencimento.month.toString().padLeft(2, '0');
    final d = dataVencimento.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}

class ItemPedidoVenda {
  ItemPedidoVenda({
    required this.digpro,
    required this.digqtd,
    required this.digpco,
    required this.pcomax,
    required this.pcomin,
    required this.destot,
    required this.subtot,
    required this.bontyp,
    required this.boncod,
    required this.ccvtot,
    required this.digitm,
    this.mulven,
    this.mulemb,
    this.percmb,
  });

  final String digpro;
  final double digqtd;
  final double digpco;
  final double pcomax;
  final double pcomin;
  final double destot;
  final double subtot;
  final int bontyp;
  final int boncod;
  final double ccvtot;
  final int digitm;
  // PRD B4 — mulver embalagem (opcionais compat)
  final double? mulven;
  final double? mulemb;
  final double? percmb;

  double getTotLiquido() {
    return (digqtd * digpco) - destot;
  }

  double getTotBonificacao() {
    return bontyp != 0 || boncod != 0 ? (digqtd * digpco) : 0.0;
  }
}

class PedidoVenda {
  PedidoVenda({
    required this.codFil,
    required this.codMov,
    required this.codRep,
    required this.codCli,
    required this.codLin,
    required this.codPla,
    required this.codAgt,
    this.codReg = 1,
    this.bontot = 0.0,
    this.destot = 0.0,
    this.subtot = 0.0,
    this.digtot = 0.0,
    this.fattot = 0.0,
    required this.datSys,
    required this.items,
    // Fase A2 — snapshots e identidade PRD dig00_* (opcionais para compat)
    this.clides = '',
    this.lindes = '',
    this.plades = '',
    this.codTab = 0,
    this.bonfrcven = 0,
    this.sttDig = PedidoSttDig.editando,
    this.sttEnv = PedidoSttEnv.digitado,
    // PRD 1 §2 — age00_tipo → dig00_digcob (classificação cobrança)
    this.tipoAgente = 0,
  });

  final int codFil;
  final int codMov;
  final int codRep;
  final int codCli;
  final int codLin;
  final int codPla;
  final int codAgt;
  final int codReg;
  double bontot;
  double destot;
  double subtot;
  double digtot;
  double fattot;
  final String datSys;
  final List<ItemPedidoVenda> items;

  // Snapshots TEXT gravados no ato da digitação (PRD dig00_clides/lindes/plades)
  final String clides;
  final String lindes;
  final String plades;

  // Tabela de preços ativa (PRD dig00_digtab)
  final int codTab;

  // Flag bonificação força de venda (PRD dig00_bonfrcven via ven00_gerbonfor)
  final int bonfrcven;

  // Máquina de estados PRD
  final PedidoSttDig sttDig;
  final PedidoSttEnv sttEnv;

  // PRD 1 §2 — age00_tipo → dig00_digcob
  final int tipoAgente;

  void calcularTotais() {
    bontot = 0.0;
    destot = 0.0;
    subtot = 0.0;
    digtot = 0.0;
    fattot = 0.0;

    for (final item in items) {
      if (item.bontyp != 0 || item.boncod != 0) {
        bontot += item.getTotBonificacao();
      } else {
        destot += item.destot;
        subtot += item.subtot;
        digtot += item.getTotLiquido();
      }
    }
    // PRD §2.C: fattot = digtot - subtot
    fattot = digtot - subtot;
  }

  /// Ajusta uma data de vencimento: se coincidir com sábado (6), domingo (7)
  /// ou com feriado presente na lista [feriados] (formato 'yyyy-MM-dd', 'dd/MM/yyyy', 'MM-dd' ou 'dd/MM'),
  /// posterga automaticamente para o primeiro dia útil subsequente.
  static DateTime postergarParaDiaUtil(DateTime data, {Set<String> feriados = const {}}) {
    DateTime atual = DateTime(data.year, data.month, data.day);
    while (true) {
      final isFimDeSemana = atual.weekday == DateTime.saturday || atual.weekday == DateTime.sunday;
      final ymd = '${atual.year.toString().padLeft(4, '0')}-${atual.month.toString().padLeft(2, '0')}-${atual.day.toString().padLeft(2, '0')}';
      final dmy = '${atual.day.toString().padLeft(2, '0')}/${atual.month.toString().padLeft(2, '0')}/${atual.year.toString().padLeft(4, '0')}';
      final md = '${atual.month.toString().padLeft(2, '0')}-${atual.day.toString().padLeft(2, '0')}';
      final dm = '${atual.day.toString().padLeft(2, '0')}/${atual.month.toString().padLeft(2, '0')}';

      final isFeriado = feriados.contains(ymd) ||
          feriados.contains(dmy) ||
          feriados.contains(md) ||
          feriados.contains(dm);

      if (isFimDeSemana || isFeriado) {
        atual = atual.add(const Duration(days: 1));
      } else {
        break;
      }
    }
    return atual;
  }

  /// Carrega lista de feriados cadastrados na tabela cadfer00 no SQLite local
  static Future<Set<String>> carregarFeriadosLocal({String? dbPath}) async {
    final Set<String> feriados = {};
    try {
      final db = dbPath != null
          ? await openDatabase(dbPath)
          : await LocalSalesDatabaseService.getDatabase();
      final t = await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND lower(name)='cadfer00'");
      if (t.isNotEmpty) {
        final cols = await db.rawQuery('PRAGMA table_info(cadfer00)');
        final colNames = cols.map((r) => r['name']?.toString().toLowerCase()).toSet();
        String? dataCol;
        for (final c in ['fer00_data', 'fer00_datfer', 'fer00_dtfer', 'data', 'datfer']) {
          if (colNames.contains(c)) { dataCol = c; break; }
        }
        if (dataCol != null) {
          final rows = await db.rawQuery('SELECT $dataCol as d FROM cadfer00');
          for (final r in rows) {
            final d = r['d']?.toString().trim();
            if (d != null && d.isNotEmpty) {
              feriados.add(d);
            }
          }
        }
      }
    } catch (_) {}
    return feriados;
  }

  /// Extrai os prazos em dias a partir da descrição ou código do plano (ex: "30/60/90" -> [30, 60, 90])
  static List<int> extrairPrazosDias(String planoDesc) {
    final matches = RegExp(r'\d+').allMatches(planoDesc);
    if (matches.isEmpty) return [0];
    return matches.map((m) => int.parse(m.group(0)!)).toList();
  }

  /// Projeta as parcelas e datas de vencimento do plano de pagamento considerando prazos
  /// e postergando fins de semana e feriados registrados na tabela cadfer00.
  static List<ParcelaVenda> projetarParcelas({
    required double valorTotal,
    required DateTime dataBase,
    required List<int> prazosDias,
    Set<String> feriados = const {},
  }) {
    if (prazosDias.isEmpty || valorTotal <= 0) {
      final vcto = postergarParaDiaUtil(dataBase, feriados: feriados);
      return [ParcelaVenda(numero: 1, dataVencimento: vcto, valor: valorTotal)];
    }

    final int nParcelas = prazosDias.length;
    final double valorBaseParcela = double.parse((valorTotal / nParcelas).toStringAsFixed(2));
    double somaParcelas = 0.0;
    final List<ParcelaVenda> parcelas = [];

    for (int i = 0; i < nParcelas; i++) {
      final dias = prazosDias[i];
      final dataCalculada = dataBase.add(Duration(days: dias));
      final dataVencimento = postergarParaDiaUtil(dataCalculada, feriados: feriados);

      double valorParcela;
      if (i == nParcelas - 1) {
        // Ajuste de centavos na última parcela
        valorParcela = double.parse((valorTotal - somaParcelas).toStringAsFixed(2));
      } else {
        valorParcela = valorBaseParcela;
        somaParcelas += valorParcela;
      }

      parcelas.add(ParcelaVenda(
        numero: i + 1,
        dataVencimento: dataVencimento,
        valor: valorParcela,
      ));
    }

    return parcelas;
  }

  /// Projeta as parcelas deste pedido com base na data de emissão (datSys) e plano (plades)
  List<ParcelaVenda> projetarVencimentos({Set<String> feriados = const {}}) {
    final dtBase = DateTime.tryParse(datSys) ?? DateTime.now();
    final prazos = extrairPrazosDias(plades.isNotEmpty ? plades : codPla.toString());
    final total = fattot > 0 ? fattot : (digtot - subtot);
    return projetarParcelas(
      valorTotal: total > 0 ? total : digtot,
      dataBase: dtBase,
      prazosDias: prazos,
      feriados: feriados,
    );
  }

  Future<void> doUpdateStatistics() async {
    try {
      final db = await LocalSalesDatabaseService.getDatabase();

      // Garante tabelas acessórias existam (evita rollback silencioso se vier de banco novo)
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS ESTFATCVD00 (
            fat00_codfil INTEGER,
            fat00_codmov INTEGER PRIMARY KEY,
            fat00_codrep INTEGER,
            fat00_codcli INTEGER,
            fat00_valtot REAL,
            fat00_datfat TEXT,
            fat00_subtot REAL,
            fat00_destot REAL
          )
        ''');
      } catch (e, stack) {
        print('ERRO GRAVACAO PEDIDO: $e \n $stack');
      }
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS FINCAICVD00 (
            cai00_codfil INTEGER,
            cai00_codmov INTEGER PRIMARY KEY,
            cai00_codcli INTEGER,
            cai00_valtot REAL,
            cai00_datmov TEXT,
            cai00_codpla INTEGER
          )
        ''');
      } catch (e, stack) {
        print('ERRO GRAVACAO PEDIDO: $e \n $stack');
      }
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS ESTPRO00 (
            pro00_codfil INTEGER,
            pro00_codpro TEXT,
            pro00_qtdest REAL DEFAULT 0,
            pro00_qtdpen REAL DEFAULT 0,
            PRIMARY KEY (pro00_codfil, pro00_codpro)
          )
        ''');
      } catch (e, stack) {
        print('ERRO GRAVACAO PEDIDO: $e \n $stack');
      }

      // 1. Atualizar Estoque (ESTPRO00) — não bloqueia venda se falhar
      try {
        final List<Map<String, dynamic>> tablesEst = await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND lower(name)='estpro00'"
        );
        if (tablesEst.isNotEmpty) {
          final List<Map<String, dynamic>> columns = await db.rawQuery('PRAGMA table_info(estpro00)');
          final colNames = columns.map((r) => r['name']?.toString().toLowerCase()).toSet();

          for (final item in items) {
            if (colNames.contains('pro00_qtdpen')) {
              await db.rawUpdate(
                'UPDATE estpro00 SET pro00_qtdpen = COALESCE(pro00_qtdpen, 0) + ? WHERE pro00_codpro = ? AND pro00_codfil = ?',
                [item.digqtd, item.digpro, codFil],
              );
            } else if (colNames.contains('pro00_qtdest')) {
              await db.rawUpdate(
                'UPDATE estpro00 SET pro00_qtdest = COALESCE(pro00_qtdest, 0) - ? WHERE pro00_codpro = ? AND pro00_codfil = ?',
                [item.digqtd, item.digpro, codFil],
              );
            }
          }
          print('Estatísticas de estoque (estpro00) atualizadas.');
        }
      } catch (e, stack) {
        print('ERRO GRAVACAO PEDIDO: $e \n $stack');
      }

      // 2. Atualizar Histórico de Faturamento (ESTFATCVD00) — não bloqueia venda
      try {
        final List<Map<String, dynamic>> tablesFat = await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND lower(name)='estfatcvd00'"
        );
        if (tablesFat.isNotEmpty) {
          final List<Map<String, dynamic>> columns = await db.rawQuery('PRAGMA table_info(ESTFATCVD00)');
          final colNames = columns.map((r) => r['name']?.toString().toLowerCase()).toSet();

          final List<String> insertCols = [];
          final List<String> placeholders = [];
          final List<dynamic> binds = [];

          void addIfPresent(String colName, dynamic value) {
            if (colNames.contains(colName.toLowerCase())) {
              insertCols.add(colName);
              placeholders.add('?');
              binds.add(value);
            }
          }

          addIfPresent('fat00_codfil', codFil);
          addIfPresent('fat00_codmov', codMov);
          addIfPresent('fat00_codrep', codRep);
          addIfPresent('fat00_codcli', codCli);
          addIfPresent('fat00_valtot', digtot);
          addIfPresent('fat00_datfat', datSys);
          addIfPresent('fat00_subtot', subtot);
          addIfPresent('fat00_destot', destot);

          if (insertCols.isNotEmpty) {
            final query = 'INSERT OR REPLACE INTO ESTFATCVD00 (${insertCols.join(', ')}) VALUES (${placeholders.join(', ')})';
            await db.rawInsert(query, binds);
            print('Histórico de faturamento (ESTFATCVD00) atualizado.');
          }
        }
      } catch (e, stack) {
        print('ERRO GRAVACAO PEDIDO: $e \n $stack');
      }

      // 3. Atualizar Financeiro Caixa (FINCAICVD00) — não bloqueia venda
      try {
        final List<Map<String, dynamic>> tablesFin = await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND lower(name)='fincaicvd00'"
        );
        if (tablesFin.isNotEmpty) {
          final List<Map<String, dynamic>> columns = await db.rawQuery('PRAGMA table_info(FINCAICVD00)');
          final colNames = columns.map((r) => r['name']?.toString().toLowerCase()).toSet();

          final List<String> insertCols = [];
          final List<String> placeholders = [];
          final List<dynamic> binds = [];

          void addIfPresent(String colName, dynamic value) {
            if (colNames.contains(colName.toLowerCase())) {
              insertCols.add(colName);
              placeholders.add('?');
              binds.add(value);
            }
          }

          addIfPresent('cai00_codfil', codFil);
          addIfPresent('cai00_codmov', codMov);
          addIfPresent('cai00_codcli', codCli);
          addIfPresent('cai00_valtot', digtot);
          addIfPresent('cai00_datmov', datSys);
          addIfPresent('cai00_codpla', codPla);

          if (insertCols.isNotEmpty) {
            final query = 'INSERT OR REPLACE INTO FINCAICVD00 (${insertCols.join(', ')}) VALUES (${placeholders.join(', ')})';
            await db.rawInsert(query, binds);
            print('Financeiro caixa (FINCAICVD00) atualizado.');
          }
        }
      } catch (e, stack) {
        print('ERRO GRAVACAO PEDIDO: $e \n $stack');
      }
    } catch (e, stack) {
      print('ERRO GRAVACAO PEDIDO: $e \n $stack');
    }
  }
}
