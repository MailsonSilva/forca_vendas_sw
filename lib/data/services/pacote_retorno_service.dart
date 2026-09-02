import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import '../../app_state.dart';
import '../../backend/ftp/ftp_client.dart';
import '../../backend/ftp/ftp_transport.dart';
import '../../services/ftp_path_builder.dart';
import '../../services/status_envio_db.dart';
import 'crg_codec.dart';
import 'local_sales_database_service.dart';



/// Utilitário especializado no parse de documentos XML de retorno (.ret) do ERP Suportware
class RetornoXmlParser {
  /// Extrai os atributos de todas as linhas `<row .../>` contidas dentro de uma tag específica.
  static List<Map<String, String>> parseRows(String xml, String sectionTag) {
    final List<Map<String, String>> rows = [];
    final sectionRegex = RegExp(
      '<$sectionTag[^>]*>(.*?)</$sectionTag>',
      dotAll: true,
      caseSensitive: false,
    );
    final match = sectionRegex.firstMatch(xml);
    if (match == null) return rows;

    final sectionContent = match.group(1) ?? '';
    final rowRegex = RegExp(r'<row\s+([^>]+)/?>', caseSensitive: false);
    for (final rowMatch in rowRegex.allMatches(sectionContent)) {
      final attrString = rowMatch.group(1) ?? '';
      final attrs = parseAttributes(attrString);
      if (attrs.isNotEmpty) {
        rows.add(attrs);
      }
    }
    return rows;
  }

  /// Extrai atributos XML no formato chave="valor" ou chave='valor'.
  static Map<String, String> parseAttributes(String attrString) {
    final Map<String, String> attrs = {};
    final attrRegex = RegExp(r'([a-zA-Z0-9_]+)=["\x27]([^\x27"]*)["\x27]');
    for (final match in attrRegex.allMatches(attrString)) {
      final key = match.group(1)?.toLowerCase() ?? '';
      final val = match.group(2) ?? '';
      if (key.isNotEmpty) {
        attrs[key] = val;
      }
    }
    return attrs;
  }
}

/// Resultado do processamento de arquivos de retorno da retaguarda ERP
class ProcessarRetornoResult {
  ProcessarRetornoResult({
    required this.sucesso,
    required this.totalProcessados,
    required this.arquivosProcessados,
    this.mensagem = '',
  });

  final bool sucesso;
  final int totalProcessados;
  final List<String> arquivosProcessados;
  final String mensagem;
}

/// Serviço responsável pelo download, leitura, processamento transacional e confirmação

/// de arquivos de retorno de vendas (`r<codRep>-<seq>.ret` / `fcfGETRET = 6` / `fcfRETPED = 11`)
/// emitidos pela retaguarda ERP Suportware.
class PacoteRetornoService {
  PacoteRetornoService({
    Future<FtpTransport> Function()? connectFtp,
    StatusEnvioDb? statusDb,
    Future<Database> Function()? getDatabase,
    CrgCodec? crgCodec,
  })  : _connectFtp = connectFtp ?? (() => FtpClient.connect()),
        _statusDb = statusDb ?? StatusEnvioDb(),
        _getDatabase = getDatabase ?? (() => LocalSalesDatabaseService.getDatabase()),
        _crgCodec = crgCodec ?? CrgCodec();

  final Future<FtpTransport> Function() _connectFtp;
  final StatusEnvioDb _statusDb;
  final Future<Database> Function() _getDatabase;
  final CrgCodec _crgCodec;

  /// Processa todos os arquivos de retorno pendentes no servidor FTP para o representante.
  Future<ProcessarRetornoResult> processarRetornos({
    String? empresa,
    int? codRep,
    int? codReg,
  }) async {
    final List<String> processados = [];

    try {
      // 1. Resolução resiliente da empresa e representante
      String emp = (empresa ?? '').trim();
      if (emp.isEmpty) {
        emp = AppState().empresa_codigo.trim();
      }
      if (emp.isEmpty) {
        try {
          final db = await _getDatabase();
          final rows = await db.rawQuery('SELECT ven00_codemp, rep00_codemp FROM cadrep00 LIMIT 1');
          if (rows.isNotEmpty) {
            emp = rows.first['ven00_codemp']?.toString() ?? rows.first['rep00_codemp']?.toString() ?? '';
          }
        } catch (_) {}
      }
      if (emp.isEmpty) {
        emp = 'diniz';
      }

      int rep = codRep ?? 0;
      if (rep <= 0) {
        rep = AppState().vendedor_codigo;
      }
      if (rep <= 0) {
        try {
          final db = await _getDatabase();
          final rows = await db.rawQuery('SELECT ven00_codigo, rep00_codigo FROM cadrep00 LIMIT 1');
          if (rows.isNotEmpty) {
            rep = int.tryParse(rows.first['ven00_codigo']?.toString() ?? rows.first['rep00_codigo']?.toString() ?? '') ?? 0;
          }
        } catch (_) {}
      }
      if (rep <= 0) {
        rep = 71;
      }

      final int reg = codReg ?? (AppState().vendedor_equipe > 0 ? AppState().vendedor_equipe : rep);

      final FtpTransport ftp = await _connectFtp();
      try {
        final List<String> candidateFolders = [
          FtpPathBuilder.getRemotePath(empresa: emp, codReg: reg, tipo: TipoCarga.pedido),
          '/$emp/${reg.toString().padLeft(2, '0')}/Externo/',
          '/$emp/${reg.toString().padLeft(2, '0')}/PAC/',
          '/$emp/${reg.toString().padLeft(2, '0')}/Upload/',
          '/$emp/${reg.toString().padLeft(2, '0')}/',
          '/$emp/Externo/',
          '/$emp/PAC/',
          '/Externo/',
          '/PAC/',
        ];

        final prefixoRetorno = 'r$rep-'.toLowerCase();
        const prefixoGenerico = 'r';
        final Set<String> arquivosParaProcessar = {};

        for (final targetFolder in candidateFolders) {
          try {
            await ftp.cwd('/');
            final segmentos = targetFolder.split('/').where((s) => s.trim().isNotEmpty);
            for (final seg in segmentos) {
              await ftp.cwd(seg.trim());
            }

            final List<String> fileNames = await ftp.nlst();
            final matches = fileNames.where((name) {
              final n = p.basename(name).toLowerCase();
              final isRetorno = (n.startsWith(prefixoRetorno) || n.startsWith(prefixoGenerico)) &&
                  (n.endsWith('.ret') || n.endsWith('.xml') || n.endsWith('.crg') || n.endsWith('.txt'));
              return isRetorno;
            }).toList();

            if (matches.isNotEmpty) {
              arquivosParaProcessar.addAll(matches);
              break;
            }
          } catch (_) {}
        }


        if (arquivosParaProcessar.isEmpty) {
          return ProcessarRetornoResult(
            sucesso: true,
            totalProcessados: 0,
            arquivosProcessados: [],
            mensagem: 'Nenhum arquivo de retorno pendente no servidor ($emp / #$rep).',
          );
        }

        for (final fileName in arquivosParaProcessar) {
          try {
            final rawBytes = await ftp.retr(fileName);

            // Descompactação polimórfica (mesma tecnologia do download de carga: CrgCodec / Zlib / UTF-8)
            final String conteudo = _crgCodec.decompressRetornoText(rawBytes);

            // Mapeia o nome do pacote correspondente: r71-1001.ret -> p71-1001.pac
            final String baseName = p.basenameWithoutExtension(fileName);
            final String seqStr = baseName.replaceFirst(RegExp(r'^r[0-9]*-?'), '');
            final String pacOriginal = seqStr.isNotEmpty ? 'p$rep-$seqStr.pac' : 'p$rep.pac';

            // Interpreta e aplica todas as seções do retorno no SQLite local
            await importarRetornoXml(
              xml: conteudo,
              pacOriginal: pacOriginal,
              codRep: rep,
            );

            processados.add(fileName);

            // Confirmação de leitura (fcfRETPED = 11): remove o retorno remoto após o commit
            try {
              await ftp.dele(fileName);
            } catch (_) {}
          } catch (e) {
            print('Erro ao processar arquivo de retorno $fileName: $e');
          }
        }

        return ProcessarRetornoResult(
          sucesso: true,
          totalProcessados: processados.length,
          arquivosProcessados: processados,
          mensagem: '${processados.length} arquivo(s) de retorno processado(s) com sucesso.',
        );
      } finally {
        await ftp.quit();
      }
    } catch (e) {
      return ProcessarRetornoResult(
        sucesso: false,
        totalProcessados: processados.length,
        arquivosProcessados: processados,
        mensagem: 'Falha ao baixar retorno: $e',
      );
    }
  }


  /// Importa o XML do arquivo de retorno em transação atômica no SQLite local,
  /// atualizando os 8 blocos documentados na especificação técnica:
  /// ret00, ret01, ret03, pro00, cli00, fat00, ccv00, sql00.
  Future<void> importarRetornoXml({
    required String xml,
    required String pacOriginal,
    int? codRep,
  }) async {
    final bool isRejeitado = xml.toLowerCase().contains('<erro>') ||
        xml.toLowerCase().contains('status="rejeitado"') ||
        xml.toLowerCase().contains('inconsistencia');

    if (isRejeitado) {
      print('Aviso: Pacote $pacOriginal retornou com inconsistência: $xml');
      return;
    }

    final db = await _getDatabase();
    final today = DateTime.now().toIso8601String().split('T').first;

    await db.transaction((txn) async {
      // 1. Bloco <ret00>: Faturamento do Pedido (dig00 / pckvendig000)
      final ret00Rows = RetornoXmlParser.parseRows(xml, 'ret00');
      for (final r in ret00Rows) {
        final codPed = int.tryParse(r['dig00_digcod'] ?? '') ?? 0;
        final fatMov = r['dig00_fatmov'] ?? '';
        final fatDatRaw = r['dig00_fatdat'] ?? '';
        final fatDat = fatDatRaw.contains('T') ? fatDatRaw.split('T').first : fatDatRaw;
        final fatTot = double.tryParse(r['dig00_fattot'] ?? '') ?? 0.0;
        final fatObs = r['dig00_fatobs'] ?? '';

        if (codPed > 0) {
          await txn.rawUpdate('''
            UPDATE pckvendig000 SET
              ped00_sttenv = 3,
              ped00_fatmov = ?,
              ped00_fatdat = ?,
              ped00_fattot = ?,
              ped00_fatobs = ?,
              ped00_datret = ?
            WHERE ped00_numped = ?
          ''', [fatMov, fatDat.isNotEmpty ? fatDat : today, fatTot, fatObs, today, codPed]);
        }
      }

      // 2. Bloco <ret01>: Cortes de Estoque e Preços Faturados por Item (dig01 / pckvendig010)
      final ret01Rows = RetornoXmlParser.parseRows(xml, 'ret01');
      for (final r in ret01Rows) {
        final codPed = int.tryParse(r['dig01_digcod'] ?? '') ?? 0;
        final digItm = int.tryParse(r['dig01_digitm'] ?? '') ?? 0;
        final fatQtd = double.tryParse(r['dig01_fatqtd'] ?? '') ?? 0.0;
        final fatPco = double.tryParse(r['dig01_fatpco'] ?? '') ?? 0.0;

        if (codPed > 0 && digItm > 0) {
          try {
            await txn.rawUpdate('''
              UPDATE pckvendig010 SET
                ped10_fatqtd = ?,
                ped10_fatpco = ?
              WHERE ped10_numped = ? AND ped10_seq = ?
            ''', [fatQtd, fatPco, codPed, digItm]);
          } catch (_) {}
        }
      }


      // 3. Bloco <ret03>: Protocolo do Pacote no ERP (pac00)
      final ret03Rows = RetornoXmlParser.parseRows(xml, 'ret03');
      String codLot = '';
      if (ret03Rows.isNotEmpty) {
        codLot = ret03Rows.first['pac00_codlot'] ?? '';
      }

      await txn.rawUpdate('''
        UPDATE pac00 SET
          pac00_sttenv = 2,
          pac00_codlot = ?
        WHERE pac00_pacsrc = ?
      ''', [codLot, pacOriginal]);

      // Fallback: se não atualizou por nome exato, atualiza todos os pedidos vinculados ao pacote para sttenv = 3
      await _statusDb.marcarPacoteRecebido(pacOriginal);

      // 4. Bloco <pro00>: Sincronização Delta de Estoque Físico (cadpro00 / estpro00)
      final pro00Rows = RetornoXmlParser.parseRows(xml, 'pro00');
      for (final r in pro00Rows) {
        final codPro = int.tryParse(r['pro00_codpro'] ?? '') ?? 0;
        final codFil = int.tryParse(r['pro00_codfil'] ?? '') ?? 1;
        final qtdEst = double.tryParse(r['pro00_qtdest'] ?? '') ?? 0.0;

        if (codPro > 0) {
          try {
            await txn.rawInsert('''
              INSERT OR REPLACE INTO cadpro00 (pro00_codigo, pro00_prifil, pro00_qtdest)
              VALUES (?, ?, ?)
            ''', [codPro, codFil, qtdEst]);
          } catch (_) {}

          try {
            await txn.rawUpdate('''
              UPDATE estpro00 SET pro00_qtdest = ? WHERE pro00_codigo = ? OR est00_codpro = ?
            ''', [qtdEst, codPro, codPro]);
          } catch (_) {}
        }
      }

      // 5. Bloco <cli00>: Sincronização Delta de Limite de Crédito (cadcli00 / clivend00)
      final cli00Rows = RetornoXmlParser.parseRows(xml, 'cli00');
      for (final r in cli00Rows) {
        final codCli = int.tryParse(r['cli00_codigo'] ?? '') ?? 0;
        final creLim = double.tryParse(r['cli00_crelim'] ?? '') ?? 0.0;
        final creAtu = double.tryParse(r['cli00_creatu'] ?? '') ?? 0.0;

        if (codCli > 0) {
          try {
            await txn.rawInsert('''
              INSERT OR REPLACE INTO cadcli00 (cli00_codigo, cli00_crelim, cli00_creatu)
              VALUES (?, ?, ?)
            ''', [codCli, creLim, creAtu]);
          } catch (_) {}

          try {
            await txn.rawUpdate('''
              UPDATE clivend00 SET cli00_crelim = ?, cli00_creatu = ? WHERE cli00_codigo = ? OR cli00_codcli = ?
            ''', [creLim, creAtu, codCli, codCli]);
          } catch (_) {}
        }
      }

      // 6. Bloco <fat00>: Metas e Estatísticas do Representante (estfatdat00 / estfatcvd00)
      final estfatdatRows = RetornoXmlParser.parseRows(xml, 'estfatdat00');
      for (final r in estfatdatRows) {
        final datTim = r['dat00_dattim'] ?? '';
        if (datTim.isNotEmpty) {
          try {
            await txn.rawDelete('DELETE FROM estfatdat00');
            await txn.rawInsert('INSERT INTO estfatdat00 (dat00_dattim) VALUES (?)', [datTim]);
          } catch (_) {}
        }
      }

      final estfatcvdRows = RetornoXmlParser.parseRows(xml, 'estfatcvd00');
      for (final r in estfatcvdRows) {
        final codFil = int.tryParse(r['fat00_codfil'] ?? '') ?? 1;
        final codVen = int.tryParse(r['fat00_codven'] ?? '') ?? (codRep ?? 0);
        final datMov = r['fat00_datmov'] ?? today;
        final cliDes = r['fat00_clides'] ?? '';
        final cliTyp = int.tryParse(r['fat00_clityp'] ?? '') ?? 0;
        final vlrPerFat = double.tryParse(r['fat00_vlrperfat'] ?? '') ?? 0.0;
        final vlrFatVen = double.tryParse(r['fat00_vlrfatven'] ?? '') ?? 0.0;
        final vlrDigVen = double.tryParse(r['fat00_vlrdigven'] ?? '') ?? 0.0;
        final vlrDigLoc = double.tryParse(r['fat00_vlrdigloc'] ?? '') ?? 0.0;
        final vlrTotVen = double.tryParse(r['fat00_vlrtotven'] ?? '') ?? 0.0;
        final vlrCalVen = double.tryParse(r['fat00_vlrcalven'] ?? '') ?? 0.0;
        final vlrTotPer = double.tryParse(r['fat00_vlrtotper'] ?? '') ?? 0.0;
        final vlrTotLib = double.tryParse(r['fat00_vlrtotlib'] ?? '') ?? 0.0;

        try {
          await txn.rawInsert('''
            INSERT INTO estfatcvd00 (
              fat00_codfil, fat00_codven, fat00_datmov, fat00_clides, fat00_clityp,
              fat00_vlrperfat, fat00_vlrfatven, fat00_vlrdigven, fat00_vlrdigloc,
              fat00_vlrtotven, fat00_vlrcalven, fat00_vlrtotper, fat00_vlrtotlib
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
          ''', [
            codFil, codVen, datMov, cliDes, cliTyp,
            vlrPerFat, vlrFatVen, vlrDigVen, vlrDigLoc,
            vlrTotVen, vlrCalVen, vlrTotPer, vlrTotLib,
          ]);
        } catch (_) {}
      }

      // 7. Bloco <ccv00>: Saldo de Conta-Corrente / Verba do Vendedor (fincaidat00 / fincaiccv01)
      final fincaidatRows = RetornoXmlParser.parseRows(xml, 'fincaidat00');
      for (final r in fincaidatRows) {
        final datTim = r['dat00_dattim'] ?? '';
        if (datTim.isNotEmpty) {
          try {
            await txn.rawDelete('DELETE FROM fincaidat00');
            await txn.rawInsert('INSERT INTO fincaidat00 (dat00_dattim) VALUES (?)', [datTim]);
          } catch (_) {}
        }
      }

      final fincaiccvRows = RetornoXmlParser.parseRows(xml, 'fincaiccv01');
      for (final r in fincaiccvRows) {
        final codFil = int.tryParse(r['ccv01_codfil'] ?? '') ?? 1;
        final codVen = int.tryParse(r['ccv01_codven'] ?? '') ?? (codRep ?? 0);
        final vlrSal = double.tryParse(r['ccv01_vlrsal'] ?? '') ?? 0.0;
        final vlrUseDig = double.tryParse(r['ccv01_vlrusedig'] ?? '') ?? 0.0;
        final vlrUsePck = double.tryParse(r['ccv01_vlrusepck'] ?? '') ?? 0.0;
        final vlrSalAtu = double.tryParse(r['ccv01_vlrsalatu'] ?? '') ?? 0.0;

        try {
          await txn.rawInsert('''
            INSERT INTO fincaiccv01 (
              ccv01_codfil, ccv01_codven, ccv01_vlrsal, ccv01_vlrusedig,
              ccv01_vlrusepck, ccv01_vlrsalatu
            ) VALUES (?, ?, ?, ?, ?, ?)
          ''', [codFil, codVen, vlrSal, vlrUseDig, vlrUsePck, vlrSalAtu]);
        } catch (_) {}
      }

      final fincaimovRows = RetornoXmlParser.parseRows(xml, 'fincaimovccv00');
      for (final r in fincaimovRows) {
        final codFil = int.tryParse(r['ccv00_codfil'] ?? '') ?? 1;
        final codVen = int.tryParse(r['ccv00_codven'] ?? '') ?? (codRep ?? 0);
        final datMov = r['ccv00_datmov'] ?? '';
        final typMov = (r['ccv00_typmov'] ?? 'C').toUpperCase();
        final vlrMov = double.tryParse(r['ccv00_vlrmov'] ?? '') ?? 0.0;
        final vlrSal = double.tryParse(r['ccv00_vlrsal'] ?? '') ?? 0.0;
        final observ = r['ccv00_observ'] ?? '';

        try {
          await txn.rawInsert('''
            INSERT INTO fincaimovccv00 (
              ccv00_codfil, ccv00_codven, ccv00_datmov, ccv00_typmov,
              ccv00_vlrmov, ccv00_vlrsal, ccv00_observ
            ) VALUES (?, ?, ?, ?, ?, ?, ?)
          ''', [codFil, codVen, datMov, typMov, vlrMov, vlrSal, observ]);
        } catch (_) {}
      }

      // 8. Bloco <sql00>: Manutenção Preventiva do SQLite (PRAGMAs)
      final sql00Rows = RetornoXmlParser.parseRows(xml, 'sql00');
      for (final r in sql00Rows) {
        final cmdSql = r['sql00_cmdsql']?.trim() ?? '';
        if (cmdSql.isNotEmpty && cmdSql.toLowerCase().startsWith('pragma')) {
          try {
            await txn.execute(cmdSql);
          } catch (e) {
            print('Aviso ao executar PRAGMA do retorno ($cmdSql): $e');
          }
        }
      }
    });
  }
}


