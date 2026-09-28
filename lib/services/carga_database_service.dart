import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import '../app_state.dart';
import '../data/services/local_sales_database_service.dart';

/// Resultado da extração e verificação dos parâmetros de carga da base SQLite.
class CargaInfoResult {
  const CargaInfoResult({
    this.sequencialCarga = 0,
    this.dataHoraCarga,
    this.versaoSistema = '',
    this.equipeVendedor = 0,
    this.filialVendedor = 0,
    this.logCarga = '',
  });

  final int sequencialCarga;
  final DateTime? dataHoraCarga;
  final String versaoSistema;
  final int equipeVendedor;
  final int filialVendedor;
  final String logCarga;
}

/// Serviço responsável por inspecionar e extrair os metadados da carga (SPEC-056):
/// - Sequencial e data da carga (cadcfg00: cfg00_numcar, cfg00_datcar)
/// - Versão do sistema/carga (cadcfg00.cfg00_versis / fallback cadace00.srv00_verapp)
/// - Equipe e filial do representante (cadrep00: ven00_codeqp, ven00_codfil)
class CargaDatabaseService {
  CargaDatabaseService({this.dbPath});

  final String? dbPath;

  Future<Database> _getDatabase(Database? db) async {
    if (db != null) return db;
    if (dbPath != null) {
      return openDatabase(dbPath!);
    }
    return LocalSalesDatabaseService.getDatabase();
  }

  /// Processa e sincroniza os campos da carga no AppState e SharedPreferences.
  Future<CargaInfoResult> processarCamposCarga({
    Database? db,
    int? vendedorCodigo,
  }) async {
    final bool isCustomDb = db != null;
    Database? activeDb;
    int seqCarga = 0;
    DateTime? dtCarga;
    String versao = '';
    int codeqp = 0;
    int codfil = 0;
    final StringBuffer logBuffer = StringBuffer();

    try {
      activeDb = await _getDatabase(db);

      // 1. Inspecionar cadcfg00 (Sequencial, Data e Versão da Carga)
      try {
        final tables = await activeDb.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND lower(name) = 'cadcfg00'",
        );
        if (tables.isNotEmpty) {
          final cols = await activeDb.rawQuery('PRAGMA table_info(cadcfg00)');
          final colNames = cols
              .map((r) => r['name']?.toString().toLowerCase())
              .whereType<String>()
              .toSet();

          final rows = await activeDb.rawQuery('SELECT * FROM cadcfg00 LIMIT 1');
          if (rows.isNotEmpty) {
            final row = rows.first;

            // Sequencial da Carga (cfg00_numcar / cfg00_seqcar)
            if (colNames.contains('cfg00_numcar') && row['cfg00_numcar'] != null) {
              seqCarga = int.tryParse(row['cfg00_numcar'].toString()) ?? 0;
            } else if (colNames.contains('cfg00_seqcar') && row['cfg00_seqcar'] != null) {
              seqCarga = int.tryParse(row['cfg00_seqcar'].toString()) ?? 0;
            }

            // Data da Carga (cfg00_datcar)
            if (colNames.contains('cfg00_datcar') && row['cfg00_datcar'] != null) {
              final rawDt = row['cfg00_datcar'].toString().trim();
              dtCarga = DateTime.tryParse(rawDt) ??
                  DateTime.tryParse(rawDt.replaceAll(' ', 'T'));
            }

            // Versão do Sistema (cfg00_versis / srv00_verapp)
            if (colNames.contains('cfg00_versis') && row['cfg00_versis'] != null) {
              versao = row['cfg00_versis'].toString().trim();
            } else if (colNames.contains('srv00_verapp') && row['srv00_verapp'] != null) {
              versao = row['srv00_verapp'].toString().trim();
            }
          }
        }
      } catch (e) {
        logBuffer.writeln('[CargaDatabaseService] Erro ao ler cadcfg00: $e');
      }

      // Fallback de Versão: cadace00 (srv00_verapp / srv00_versis)
      if (versao.isEmpty) {
        try {
          final aceTables = await activeDb.rawQuery(
            "SELECT name FROM sqlite_master WHERE type='table' AND lower(name) = 'cadace00'",
          );
          if (aceTables.isNotEmpty) {
            final aceCols = await activeDb.rawQuery('PRAGMA table_info(cadace00)');
            final aceColNames = aceCols
                .map((r) => r['name']?.toString().toLowerCase())
                .whereType<String>()
                .toSet();

            final rows = await activeDb.rawQuery('SELECT * FROM cadace00 LIMIT 1');
            if (rows.isNotEmpty) {
              final row = rows.first;
              if (aceColNames.contains('srv00_verapp') && row['srv00_verapp'] != null) {
                versao = row['srv00_verapp'].toString().trim();
              } else if (aceColNames.contains('srv00_versis') && row['srv00_versis'] != null) {
                versao = row['srv00_versis'].toString().trim();
              }
            }
          }
        } catch (e) {
          logBuffer.writeln('[CargaDatabaseService] Erro ao ler cadace00: $e');
        }
      }

      // 2. Inspecionar cadrep00 (Equipe e Filial do Vendedor)
      try {
        final repTables = await activeDb.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND lower(name) = 'cadrep00'",
        );
        if (repTables.isNotEmpty) {
          final repCols = await activeDb.rawQuery('PRAGMA table_info(cadrep00)');
          final repColNames = repCols
              .map((r) => r['name']?.toString().toLowerCase())
              .whereType<String>()
              .toSet();

          final int codVendedor = (vendedorCodigo != null && vendedorCodigo > 0)
              ? vendedorCodigo
              : AppState().vendedor_codigo;

          List<Map<String, dynamic>> rows = [];
          if (codVendedor > 0) {
            final colId = repColNames.contains('ven00_codigo')
                ? 'ven00_codigo'
                : (repColNames.contains('rep00_codigo') ? 'rep00_codigo' : null);
            if (colId != null) {
              rows = await activeDb.rawQuery(
                'SELECT * FROM cadrep00 WHERE $colId = ? LIMIT 1',
                [codVendedor],
              );
            }
          }
          if (rows.isEmpty) {
            rows = await activeDb.rawQuery('SELECT * FROM cadrep00 LIMIT 1');
          }

          if (rows.isNotEmpty) {
            final row = rows.first;
            if (repColNames.contains('ven00_codeqp') && row['ven00_codeqp'] != null) {
              codeqp = int.tryParse(row['ven00_codeqp'].toString()) ?? 0;
            } else if (repColNames.contains('rep00_codeqp') && row['rep00_codeqp'] != null) {
              codeqp = int.tryParse(row['rep00_codeqp'].toString()) ?? 0;
            }

            if (repColNames.contains('ven00_codfil') && row['ven00_codfil'] != null) {
              codfil = int.tryParse(row['ven00_codfil'].toString()) ?? 0;
            } else if (repColNames.contains('rep00_codfil') && row['rep00_codfil'] != null) {
              codfil = int.tryParse(row['rep00_codfil'].toString()) ?? 0;
            }

            // Atualiza nome do perfil do vendedor se presente
            String? nomeVendedor;
            if (repColNames.contains('ven00_nome') && row['ven00_nome'] != null) {
              nomeVendedor = row['ven00_nome'].toString().trim();
            } else if (repColNames.contains('rep00_nome') && row['rep00_nome'] != null) {
              nomeVendedor = row['rep00_nome'].toString().trim();
            }
            if (nomeVendedor != null && nomeVendedor.isNotEmpty) {
              AppState().vendedor_nome = nomeVendedor;
              AppState().vendedor_logado_nome = nomeVendedor;
            }
          }
        }
      } catch (e) {
        logBuffer.writeln('[CargaDatabaseService] Erro ao ler cadrep00: $e');
      }

      // 3. Persistir valores no AppState e log de auditoria
      try {
        if (seqCarga > 0) {
          AppState().sequencialCarga = seqCarga;
        }
        if (dtCarga != null) {
          AppState().dataHoraUltimaCarga = dtCarga;
        }
        if (versao.isNotEmpty) {
          AppState().versaoSistema = versao;
          try {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('versao_carga_sistema', versao);
          } catch (_) {}
        }
        if (codeqp > 0) {
          AppState().vendedor_equipe = codeqp;
        }
        if (codfil > 0 && AppState().codFilialAtiva <= 0) {
          AppState().codFilialAtiva = codfil;
        }
      } catch (e) {
        logBuffer.writeln('[CargaDatabaseService] Erro ao atualizar AppState: $e');
      }

      final logFinal = 'Carga processada: seq=$seqCarga, data=${dtCarga?.toIso8601String()}, '
          'versao=$versao, equipe=$codeqp, filial=$codfil\n${logBuffer.toString()}';

      AppState().logUltimaCarga = logFinal;
      debugPrint('[CargaDatabaseService] $logFinal');

      return CargaInfoResult(
        sequencialCarga: seqCarga,
        dataHoraCarga: dtCarga,
        versaoSistema: versao,
        equipeVendedor: codeqp,
        filialVendedor: codfil,
        logCarga: logFinal,
      );
    } finally {
      if (!isCustomDb && dbPath != null && activeDb != null) {
        await activeDb.close();
      }
    }
  }
}
