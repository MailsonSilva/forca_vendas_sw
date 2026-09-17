import 'package:sqflite/sqflite.dart';

/// SPEC-046: Gerenciamento dos Sequenciais de Pedido (dig00_digcod) e Pacote (pac00_paccod)
///
/// Baseado nas regras extraídas do sistema legado C++ (ffrmdiggerpac00.cpp).
class SequenceGeneratorService {
  final Database dbDig;

  SequenceGeneratorService(this.dbDig);

  /// Obtém o próximo código de pacote (+1) mantendo a faixa 1000..9999.
  ///
  /// Conforme ffrmdiggerpac00.cpp:
  /// - Consulta: `SELECT COALESCE(MAX(pac00_paccod), 0) FROM pckvenpac00 WHERE pac00_pacrep = :codrep`
  /// - Se o valor retornado for menor que 1000 ou maior/igual a 9999, o próximo é 1000.
  /// - Caso contrário: max + 1.
  Future<int> obterProximoCodigoPacote(int codigoVendedor) async {
    int maxPac = 0;
    try {
      final result = await dbDig.rawQuery('''
        SELECT COALESCE(MAX(pac00_paccod), 0) AS max_pac 
        FROM pckvenpac00 
        WHERE pac00_pacrep = ?
      ''', [codigoVendedor]);

      maxPac = (result.first['max_pac'] as int?) ?? 0;
    } catch (_) {
      // Fallback para tabela pac00
      try {
        final result = await dbDig.rawQuery('''
          SELECT COALESCE(MAX(pac00_paccod), 0) AS max_pac 
          FROM pac00 
          WHERE pac00_pacrep = ?
        ''', [codigoVendedor]);
        maxPac = (result.first['max_pac'] as int?) ?? 0;
      } catch (_) {}
    }

    // Regra oficial do ffrmdiggerpac00.cpp:
    if (maxPac < 1000 || maxPac >= 9999) {
      return 1000;
    }
    return maxPac + 1;
  }

  /// Obtém o próximo código sequencial do pedido (+1) particionado por filial.
  ///
  /// Conforme SPEC-046:
  /// - Consulta: `SELECT COALESCE(MAX(dig00_digcod), 0) AS max_cod FROM pckvendig00 WHERE dig00_digfil = :filial`
  /// - Se a base estiver zerada (max_cod == 0), tenta recuperar o valor padrão
  ///   de `cadrep00` para o vendedor antes de somar 1.
  Future<int> obterProximoCodigoPedido(int filial, int codigoVendedor) async {
    int maxCod = 0;

    // 1. Tenta buscar em pckvendig00 ou pckvendig000
    for (final tbl in ['pckvendig00', 'pckvendig000']) {
      try {
        final t = await dbDig.rawQuery(
          "SELECT name FROM sqlite_master WHERE (type='table' OR type='view') AND lower(name) = ?",
          [tbl.toLowerCase()],
        );
        if (t.isEmpty) continue;

        final cols = await dbDig.rawQuery('PRAGMA table_info($tbl)');
        final colNames = cols.map((r) => r['name']?.toString().toLowerCase()).toSet();

        String? colCod;
        for (final c in ['dig00_digcod', 'ped00_numped', 'ped00_pedcod', 'ped00_codmov', 'numped']) {
          if (colNames.contains(c.toLowerCase())) {
            colCod = c;
            break;
          }
        }
        if (colCod == null) continue;

        String? colFil;
        for (final c in ['dig00_digfil', 'ped00_codfil', 'codfil']) {
          if (colNames.contains(c.toLowerCase())) {
            colFil = c;
            break;
          }
        }

        List<Map<String, dynamic>> result;
        if (colFil != null && filial > 0) {
          result = await dbDig.rawQuery(
            'SELECT COALESCE(MAX($colCod), 0) AS max_cod FROM $tbl WHERE $colFil = ?',
            [filial],
          );
        } else {
          result = await dbDig.rawQuery(
            'SELECT COALESCE(MAX($colCod), 0) AS max_cod FROM $tbl',
          );
        }

        if (result.isNotEmpty) {
          final val = result.first['max_cod'];
          final n = (val is num) ? val.toInt() : (int.tryParse(val?.toString() ?? '') ?? 0);
          if (n > maxCod) {
            maxCod = n;
          }
        }
        break;
      } catch (_) {}
    }

    if (maxCod == 0 && codigoVendedor > 0) {
      // Recupera valor padrão de cadrep00 / configuração de carga inicial
      try {
        final cols = await dbDig.rawQuery('PRAGMA table_info(cadrep00)');
        final colNames = cols.map((r) => r['name']?.toString().toLowerCase()).toSet();
        final repCol = colNames.contains('ven00_codigo')
            ? 'ven00_codigo'
            : (colNames.contains('rep00_codigo') ? 'rep00_codigo' : null);
        if (repCol != null) {
          final rows = await dbDig.rawQuery(
            'SELECT * FROM cadrep00 WHERE $repCol = ? LIMIT 1',
            [codigoVendedor],
          );
          if (rows.isNotEmpty) {
            final r = rows.first;
            for (final col in ['ven00_pedseq', 'ven00_ultped', 'txtven00_pedseq', 'pedseq', 'rep00_pedseq']) {
              if (r.containsKey(col) && r[col] != null) {
                final v = int.tryParse(r[col].toString()) ?? 0;
                if (v > 0) {
                  maxCod = v;
                  break;
                }
              }
            }
          }
        }
      } catch (_) {}
    }

    return maxCod + 1;
  }

  /// Retorna o nome do arquivo físico do pacote: `p<codigoVendedor>-<ipac>.pac`
  String formatarNomeArquivoPacote(int codigoVendedor, int ipac) {
    return 'p$codigoVendedor-$ipac.pac';
  }

  /// Retorna a string do pacote para o cabeçalho do pedido: `p<codigoVendedor>-<ipac>`
  String formatarPacStr(int codigoVendedor, int ipac) {
    return 'p$codigoVendedor-$ipac';
  }

  /// Registra o lote na tabela `pckvenpac00` e atualiza os pedidos selecionados
  /// com `dig00_paccod = ipac`, `dig00_pacstr = 'p<rep>-<ipac>'`, `dig00_sttenv = 2`
  /// (`pvddeEMPACOTE`) e `dig00_datenv = hoje`.
  Future<void> registrarPacoteEPedidos({
    required int codigoVendedor,
    required int ipac,
    required List<int> pedidosIds,
    required double totalValorLote,
    DateTime? dataAtual,
  }) async {
    if (pedidosIds.isEmpty) return;

    final hoje = (dataAtual ?? DateTime.now()).toString().split(' ').first;
    final nomeArquivo = formatarNomeArquivoPacote(codigoVendedor, ipac);
    final pacStr = formatarPacStr(codigoVendedor, ipac);

    // 1. Persistência na tabela pckvenpac00 (conforme ffrmdiggerpac00.cpp)
    try {
      await dbDig.rawInsert('''
        INSERT OR REPLACE INTO pckvenpac00 (
          pac00_pacrep, pac00_paccod, pac00_pacsrc, pac00_pacdat,
          pac00_pacqtd, pac00_pactot, pac00_sttpac, pac00_sttenv
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
      ''', [
        codigoVendedor,
        ipac,
        nomeArquivo,
        hoje,
        pedidosIds.length,
        totalValorLote,
        0, // 0 = Gerado, não enviado (pvpspNEnviado)
        0, // 0 = Pendente de envio (pvpseNEnviado)
      ]);
    } catch (_) {}

    // Compatibilidade reversa com tabela pac00
    try {
      await dbDig.rawInsert('''
        INSERT OR REPLACE INTO pac00 (
          pac00_pacrep, pac00_paccod, pac00_pacsrc, pac00_pacdat,
          pac00_pacqtd, pac00_pactot, pac00_sttpac, pac00_sttenv
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
      ''', [
        codigoVendedor,
        ipac,
        nomeArquivo,
        hoje,
        pedidosIds.length,
        totalValorLote,
        0,
        0,
      ]);
    } catch (_) {}

    // 2. Atualização dos pedidos vinculados (pckvendig00 / pckvendig000)
    final placeholders = List.filled(pedidosIds.length, '?').join(',');

    // Atualiza tabela pckvendig00 se existir
    try {
      final t = await dbDig.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND lower(name)='pckvendig00'",
      );
      if (t.isNotEmpty) {
        final cols = await dbDig.rawQuery('PRAGMA table_info(pckvendig00)');
        final colNames = cols.map((r) => r['name']?.toString().toLowerCase()).toSet();
        final idCol = colNames.contains('dig00_digcod') ? 'dig00_digcod' : 'ped00_numped';

        final updates = <String>[];
        final binds = <dynamic>[];

        if (colNames.contains('dig00_paccod')) { updates.add('dig00_paccod = ?'); binds.add(ipac); }
        if (colNames.contains('ped00_paccod')) { updates.add('ped00_paccod = ?'); binds.add(ipac); }
        if (colNames.contains('dig00_pacstr')) { updates.add('dig00_pacstr = ?'); binds.add(pacStr); }
        if (colNames.contains('ped00_pacstr')) { updates.add('ped00_pacstr = ?'); binds.add(pacStr); }
        if (colNames.contains('dig00_sttenv')) { updates.add('dig00_sttenv = ?'); binds.add(2); }
        if (colNames.contains('ped00_sttenv')) { updates.add('ped00_sttenv = ?'); binds.add(2); }
        if (colNames.contains('dig00_datenv')) { updates.add('dig00_datenv = ?'); binds.add(hoje); }
        if (colNames.contains('ped00_datenv')) { updates.add('ped00_datenv = ?'); binds.add(hoje); }
        if (colNames.contains('ped00_sttdig')) { updates.add('ped00_sttdig = ?'); binds.add(1); }
        if (colNames.contains('dig00_sttdig')) { updates.add('dig00_sttdig = ?'); binds.add(1); }

        if (updates.isNotEmpty) {
          await dbDig.rawUpdate(
            'UPDATE pckvendig00 SET ${updates.join(', ')} WHERE $idCol IN ($placeholders)',
            [...binds, ...pedidosIds],
          );
        }
      }
    } catch (_) {}

    // Atualiza tabela pckvendig000 se existir
    try {
      final t = await dbDig.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND lower(name)='pckvendig000'",
      );
      if (t.isNotEmpty) {
        final cols = await dbDig.rawQuery('PRAGMA table_info(pckvendig000)');
        final colNames = cols.map((r) => r['name']?.toString().toLowerCase()).toSet();
        final idCol = colNames.contains('ped00_numped') ? 'ped00_numped' : 'dig00_digcod';

        final updates = <String>[];
        final binds = <dynamic>[];

        if (colNames.contains('dig00_paccod')) { updates.add('dig00_paccod = ?'); binds.add(ipac); }
        if (colNames.contains('ped00_paccod')) { updates.add('ped00_paccod = ?'); binds.add(ipac); }
        if (colNames.contains('dig00_pacstr')) { updates.add('dig00_pacstr = ?'); binds.add(pacStr); }
        if (colNames.contains('ped00_pacstr')) { updates.add('ped00_pacstr = ?'); binds.add(nomeArquivo); }
        if (colNames.contains('dig00_sttenv')) { updates.add('dig00_sttenv = ?'); binds.add(2); }
        if (colNames.contains('ped00_sttenv')) { updates.add('ped00_sttenv = ?'); binds.add(1); }
        if (colNames.contains('dig00_datenv')) { updates.add('dig00_datenv = ?'); binds.add(hoje); }
        if (colNames.contains('ped00_datenv')) { updates.add('ped00_datenv = ?'); binds.add(hoje); }
        if (colNames.contains('ped00_sttdig')) { updates.add('ped00_sttdig = ?'); binds.add(1); }
        if (colNames.contains('dig00_sttdig')) { updates.add('dig00_sttdig = ?'); binds.add(1); }

        if (updates.isNotEmpty) {
          await dbDig.rawUpdate(
            'UPDATE pckvendig000 SET ${updates.join(', ')} WHERE $idCol IN ($placeholders)',
            [...binds, ...pedidosIds],
          );
        }
      }
    } catch (_) {}
  }
}
