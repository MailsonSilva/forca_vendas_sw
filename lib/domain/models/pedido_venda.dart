import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

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
    required this.datSys,
    required this.items,
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
  final String datSys;
  final List<ItemPedidoVenda> items;

  void calcularTotais() {
    bontot = 0.0;
    destot = 0.0;
    subtot = 0.0;
    digtot = 0.0;

    for (final item in items) {
      if (item.bontyp != 0 || item.boncod != 0) {
        bontot += item.getTotBonificacao();
      } else {
        destot += item.destot;
        subtot += item.subtot;
        digtot += item.getTotLiquido();
      }
    }
  }

  Future<void> doUpdateStatistics() async {
    try {
      final databasesPath = await getDatabasesPath();
      final dbPath = join(databasesPath, 'dbforcacad001.db');
      if (!await File(dbPath).exists()) {
        print('Aviso: Banco de dados local não encontrado para doUpdateStatistics.');
        return;
      }

      final db = await openDatabase(dbPath);

      // 1. Atualizar Estoque (ESTPRO00)
      try {
        final List<Map<String, dynamic>> tablesEst = await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND name='estpro00'"
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
      } catch (e) {
        print('Erro ao atualizar estoque em doUpdateStatistics: $e');
      }

      // 2. Atualizar Histórico de Faturamento (ESTFATCVD00)
      try {
        final List<Map<String, dynamic>> tablesFat = await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND name='ESTFATCVD00'"
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
      } catch (e) {
        print('Erro ao atualizar ESTFATCVD00 em doUpdateStatistics: $e');
      }

      // 3. Atualizar Financeiro Caixa (FINCAICVD00)
      try {
        final List<Map<String, dynamic>> tablesFin = await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND name='FINCAICVD00'"
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
      } catch (e) {
        print('Erro ao atualizar FINCAICVD00 em doUpdateStatistics: $e');
      }

      await db.close();
    } catch (e) {
      print('Erro estrutural em doUpdateStatistics: $e');
    }
  }
}
