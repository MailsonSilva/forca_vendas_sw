import 'dart:io';
import 'package:sqflite/sqflite.dart';
import '../../../data/services/local_sales_database_service.dart';
import '../dtos/espelho_pedido_dto.dart';

int _getInt(Map<String, dynamic> map, List<String> candidates, [int def = 0]) {
  for (final c in candidates) {
    if (map.containsKey(c) && map[c] != null) {
      final v = map[c];
      if (v is int) return v;
      if (v is num) return v.toInt();
      final parsed = int.tryParse(v.toString());
      if (parsed != null) return parsed;
    }
  }
  return def;
}

double _getDouble(Map<String, dynamic> map, List<String> candidates, [double def = 0.0]) {
  for (final c in candidates) {
    if (map.containsKey(c) && map[c] != null) {
      final v = map[c];
      if (v is double) return v;
      if (v is num) return v.toDouble();
      final parsed = double.tryParse(v.toString().replaceAll(',', '.'));
      if (parsed != null) return parsed;
    }
  }
  return def;
}

String _getString(Map<String, dynamic> map, List<String> candidates, [String def = '']) {
  for (final c in candidates) {
    if (map.containsKey(c) && map[c] != null) {
      final s = map[c].toString().trim();
      if (s.isNotEmpty) return s;
    }
  }
  return def;
}

/// Carrega os dados estruturados de um pedido para emissão do Espelho do Pedido (PDF).
///
/// Pode receber uma instância de [Database] (injetada em testes ou transações)
/// ou buscar automaticamente no banco de dados local do aplicativo.
Future<EspelhoPedidoDTO?> carregarEspelhoPedido(int pedidoId, {Database? db}) async {
  bool shouldCloseDb = false;
  Database? activeDb = db;

  try {
    Map<String, dynamic>? foundRow;

    if (activeDb != null) {
      final t = await activeDb.rawQuery("SELECT name FROM sqlite_master WHERE type='table' AND lower(name)='pckvendig000'");
      if (t.isNotEmpty) {
        final rows = await activeDb.rawQuery('SELECT * FROM pckvendig000');
        for (final r in rows) {
          final id = _getInt(r, ['ped00_numped', 'ped00_pedcod', 'ped00_codmov', 'numped', 'pedcod', 'codmov']);
          if (id == pedidoId) {
            foundRow = r;
            break;
          }
        }
      }
    } else {
      final pathsToCheck = await LocalSalesDatabaseService.getTargetDatabasePaths();
      for (final path in pathsToCheck) {
        Database? d;
        try {
          d = await openDatabase(path);
          final t = await d.rawQuery("SELECT name FROM sqlite_master WHERE type='table' AND lower(name)='pckvendig000'");
          if (t.isNotEmpty) {
            final rows = await d.rawQuery('SELECT * FROM pckvendig000');
            for (final r in rows) {
              final id = _getInt(r, ['ped00_numped', 'ped00_pedcod', 'ped00_codmov', 'numped', 'pedcod', 'codmov']);
              if (id == pedidoId) {
                foundRow = r;
                activeDb = d;
                shouldCloseDb = true;
                d = null;
                break;
              }
            }
          }
          if (foundRow != null) break;
        } catch (_) {
        } finally {
          if (d != null && d.isOpen) await d.close();
        }
      }
    }

    if (foundRow == null || activeDb == null) {
      return null;
    }

    final m = foundRow;

    final cliCod = _getInt(m, ['ped00_codcli', 'ped00_clicod', 'codcli', 'clicod']);
    final plaCod = _getString(m, ['ped00_codpla', 'ped00_codpag', 'ped00_placod', 'ped00_digtab', 'codpla', 'codpag']);
    final linCod = _getString(m, ['ped00_codlin', 'ped00_lincod', 'codlin']);
    final agtCod = _getString(m, ['ped00_codagt', 'ped00_agtcod', 'ped00_codage', 'ped00_digagt', 'codagt', 'agtcod']);
    final repCod = _getString(m, ['ped00_codrep', 'ped00_repcod', 'ped00_digrep', 'codrep', 'repcod']);
    final datSysStr = _getString(m, ['ped00_datsys', 'ped00_datemi', 'ped00_datcad', 'datsys', 'datemi']);
    final nf = _getString(m, ['ped00_fatmov', 'ped00_numnfe', 'ped00_nf', 'fatmov']);
    final pacStr = _getString(m, ['ped00_pacstr', 'ped00_codpac', 'pacstr', 'codpac']);
    final bontot = _getDouble(m, ['ped00_bontot', 'ped00_bonval', 'bontot']);
    final digtot = _getDouble(m, ['ped00_digtot', 'ped00_subtot', 'ped00_totprd', 'ped00_valtot', 'ped00_totger', 'digtot']);
    final subtot = _getDouble(m, ['ped00_subtot', 'ped00_subval', 'subtot']);
    final fattot = _getDouble(m, ['ped00_fattot', 'ped00_totfat', 'fattot']);
    final destot = _getDouble(m, ['ped00_destot', 'ped00_valdes', 'destot']);
    final obs = _getString(m, ['ped00_observ', 'ped00_obs', 'ped00_observacao', 'observ', 'obs']);
    final sttEnv = _getInt(m, ['ped00_sttenv', 'ped00_status', 'ped00_sttdig', 'sttenv']);

    DateTime dataEmissao;
    try {
      dataEmissao = DateTime.parse(datSysStr);
    } catch (_) {
      dataEmissao = DateTime.now();
    }

    String clienteRazaoSocial = _getString(m, ['ped00_clides', 'clides']);
    String clienteFantasia = '';
    String clienteCpfCnpj = '';
    String clienteIE = '';
    String clienteEndereco = '';
    String clienteNumero = '';
    String clienteBairro = '';
    String clienteCep = '';
    String clienteCidade = '';
    String clienteUf = '';
    String clienteTelefone = '';

    String planoDesc = _getString(m, ['ped00_plades', 'plades']);
    String linhaDesc = _getString(m, ['ped00_lindes', 'lindes']);
    String agenteDesc = agtCod.isNotEmpty ? 'Agente $agtCod' : '';
    String vendedorNome = '';

    // Dados padrão da empresa emitente (do modelo base)
    String empEnd = 'AV. LOURENÇO VIEIRA DA SILVA, 16 - QUADRA 56';
    String empBairroCep = 'BAIRRO: SÃO CRISTOVAO - CEP: 65055-310';
    String empCidUf = 'CIDADE: SÃO LUIS - UF: MA';
    String empFone = 'FONE: (98) 3302-6091 - HELPDESK: (98) 3302-6091';

    // Consultas cadastrais
    Database? catDb = activeDb;
    bool openedCatDb = false;
    try {
      if (db == null) {
        final mainPath = await LocalSalesDatabaseService.getDatabasePath();
        if (activeDb.path != mainPath && await File(mainPath).exists()) {
          catDb = await openDatabase(mainPath, readOnly: true);
          openedCatDb = true;
        }
      }

      // Filial / Empresa emitente
      try {
        final tFil = await catDb.rawQuery("SELECT name FROM sqlite_master WHERE type='table' AND lower(name)='cadfil00'");
        if (tFil.isNotEmpty) {
          final filRows = await catDb.rawQuery('SELECT * FROM cadfil00 LIMIT 1');
          if (filRows.isNotEmpty) {
            final f = filRows.first;
            final fEnd = _getString(f, ['fil00_endere', 'endere']);
            final fBai = _getString(f, ['fil00_bairro', 'bairro']);
            final fCep = _getString(f, ['fil00_cep', 'cep']);
            final fCid = _getString(f, ['fil00_ciddes', 'ciddes']);
            final fUf = _getString(f, ['fil00_estsgl', 'estsgl']);
            final fFon = _getString(f, ['fil00_fone', 'fil00_telefone', 'fone']);

            if (fEnd.isNotEmpty) empEnd = 'ENDEREÇO: $fEnd';
            if (fBai.isNotEmpty && fCep.isNotEmpty) {
              empBairroCep = 'BAIRRO: $fBai - CEP: $fCep';
            } else if (fBai.isNotEmpty) {
              empBairroCep = 'BAIRRO: $fBai';
            }
            if (fCid.isNotEmpty && fUf.isNotEmpty) {
              empCidUf = 'CIDADE: $fCid - UF: $fUf';
            }
            if (fFon.isNotEmpty) empFone = 'FONE: $fFon';
          }
        }
      } catch (_) {}

      // Cliente
      if (cliCod != 0) {
        try {
          final cliRows = await catDb.rawQuery('SELECT * FROM cadcli00 WHERE cli00_codigo = ? LIMIT 1', [cliCod]);
          if (cliRows.isNotEmpty) {
            final c = cliRows.first;
            if (clienteRazaoSocial.isEmpty) {
              clienteRazaoSocial = _getString(c, ['cli00_descri', 'descri', 'nome']);
            }
            clienteFantasia = _getString(c, ['cli00_fantas', 'cli00_fantasi', 'fantas', 'fantasia']);
            clienteCpfCnpj = _getString(c, ['cli00_cpfcnp', 'cli00_cgc', 'cpfcnp', 'cgc']);
            clienteIE = _getString(c, ['cli00_insest', 'insest', 'ie']);

            clienteEndereco = _getString(c, ['cli00_endere', 'endere', 'endereco']);
            clienteNumero = _getString(c, ['cli00_endnum', 'endnum', 'numero', 'num']);
            clienteBairro = _getString(c, ['cli00_bairro', 'bairro']);
            clienteCidade = _getString(c, ['cli00_ciddes', 'ciddes', 'cidade']);
            clienteUf = _getString(c, ['cli00_estsgl', 'estsgl', 'uf']);
            clienteCep = _getString(c, ['cli00_endcep', 'cli00_cep', 'endcep', 'cep']);

            final ddd = _getString(c, ['cli00_fonddd', 'fonddd', 'ddd']);
            final fone = _getString(c, ['cli00_fonnum', 'fonnum', 'telefone', 'fone']);
            if (ddd.isNotEmpty && fone.isNotEmpty) {
              clienteTelefone = '($ddd) $fone';
            } else if (fone.isNotEmpty) {
              clienteTelefone = fone;
            }
          }
        } catch (_) {}
      }

      // Vendedor
      if (repCod.isNotEmpty) {
        final repInt = int.tryParse(repCod);
        try {
          final cols = await catDb.rawQuery('PRAGMA table_info(cadrep00)');
          final colNames = cols.map((r) => r['name']?.toString().toLowerCase()).toSet();
          String colCod = colNames.contains('ven00_codigo') ? 'ven00_codigo' : (colNames.contains('rep00_codigo') ? 'rep00_codigo' : '');
          if (colCod.isNotEmpty) {
            final repRows = await catDb.rawQuery('SELECT * FROM cadrep00 WHERE $colCod = ? LIMIT 1', [repInt ?? repCod]);
            if (repRows.isNotEmpty) {
              vendedorNome = _getString(repRows.first, ['ven00_nome', 'rep00_nome', 'ven00_descri', 'nome']);
            }
          }
        } catch (_) {}
      }

      // Plano
      if (planoDesc.isEmpty && plaCod.isNotEmpty) {
        try {
          final plaRows = await catDb.rawQuery('SELECT * FROM cadpla00 WHERE pla00_codigo = ? LIMIT 1', [plaCod]);
          if (plaRows.isNotEmpty) planoDesc = _getString(plaRows.first, ['pla00_descri', 'descri', 'descricao']);
        } catch (_) {}
      }

      // Linha
      if (linhaDesc.isEmpty && linCod.isNotEmpty) {
        try {
          final linRows = await catDb.rawQuery('SELECT * FROM cadlin00 WHERE lin00_codigo = ? LIMIT 1', [linCod]);
          if (linRows.isNotEmpty) linhaDesc = _getString(linRows.first, ['lin00_descri', 'descri', 'descricao']);
        } catch (_) {}
      }

      // Agente
      if (agtCod.isNotEmpty) {
        for (final tbl in ['cadagt00', 'codage00', 'cadage00', 'cadcob00', 'codcob00']) {
          try {
            final exists = await catDb.rawQuery("SELECT name FROM sqlite_master WHERE type='table' AND lower(name)=?", [tbl]);
            if (exists.isEmpty) continue;
            final rows = await catDb.rawQuery('SELECT * FROM $tbl WHERE age00_codigo = ? OR agt00_codigo = ? OR cob00_codigo = ? LIMIT 1', [agtCod, agtCod, agtCod]);
            if (rows.isNotEmpty) {
              agenteDesc = _getString(rows.first, ['age00_descri', 'agt00_descri', 'cob00_descri', 'descri', 'nome']);
              break;
            }
          } catch (_) {}
        }
      }
    } finally {
      if (openedCatDb && catDb != null && catDb.isOpen) {
        await catDb.close();
      }
    }

    // Itens do Pedido (pckvendig010)
    final List<ItemEspelhoDTO> itensDto = [];
    try {
      final t10 = await activeDb.rawQuery("SELECT name FROM sqlite_master WHERE type='table' AND lower(name)='pckvendig010'");
      if (t10.isNotEmpty) {
        final cols = await activeDb.rawQuery('PRAGMA table_info(pckvendig010)');
        final colNames = cols.map((r) => r['name']?.toString().toLowerCase()).toSet();
        String colNum = 'ped10_numped';
        for (final c in ['ped10_numped', 'ped10_pedcod', 'ped10_codmov', 'numped']) {
          if (colNames.contains(c)) {
            colNum = c;
            break;
          }
        }

        final rowsItens = await activeDb.rawQuery('SELECT * FROM pckvendig010 WHERE $colNum = ? ORDER BY ped10_seq ASC', [pedidoId]);

        for (int idx = 0; idx < rowsItens.length; idx++) {
          final r = rowsItens[idx];
          final seq = _getInt(r, ['ped10_seq', 'seq'], idx + 1);
          final codPrdStr = _getString(r, ['ped10_codprd', 'ped10_codpro', 'ped10_procod', 'codprd', 'codpro']);
          final codPrdInt = int.tryParse(codPrdStr) ?? 0;
          var descri = _getString(r, ['ped10_descri', 'ped10_descricao', 'descri']);
          final unid = _getString(r, ['ped10_unidpri', 'ped10_unidade', 'ped10_unimed', 'unidpri', 'unidade'], 'UN');
          final qtdPed = _getDouble(r, ['ped10_qtdped', 'qtdped', 'qtd']);
          var fatQtd = _getDouble(r, ['ped10_fatqtd', 'fatqtd']);
          // Se fatqtd for 0 e não houver corte explícito, e pedido estiver faturado ou digitado
          if (fatQtd == 0.0 && qtdPed > 0 && sttEnv != 2) {
            fatQtd = qtdPed;
          }
          final pco = _getDouble(r, ['ped10_pcosub', 'ped10_prcuni', 'ped10_vlruni', 'pcosub', 'prcuni']);
          var tot = _getDouble(r, ['ped10_totprd', 'ped10_totite', 'ped10_valtot', 'totprd']);
          if (tot == 0.0 && qtdPed > 0 && pco > 0) {
            tot = qtdPed * pco;
          }
          final isBon = (_getInt(r, ['ped10_sttbon', 'ped10_flgbon', 'ped10_bonificado']) == 1) ||
              (_getDouble(r, ['ped10_qtdbon']) > 0);
          final perDes = _getDouble(r, ['ped10_perdes', 'perdes']);

          String ean = '';
          String marca = '';

          // Busca dados complementares em cadpro00 e cadmar00
          if (codPrdStr.isNotEmpty) {
            try {
              final pr = await activeDb.rawQuery(
                'SELECT * FROM cadpro00 WHERE pro00_codigo = ? OR CAST(pro00_codigo AS TEXT) = ? LIMIT 1',
                [codPrdStr, codPrdStr],
              );
              if (pr.isNotEmpty) {
                final pRow = pr.first;
                if (descri.isEmpty) {
                  descri = _getString(pRow, ['pro00_descri', 'descri']);
                }
                ean = _getString(pRow, ['pro00_codbar', 'codbar', 'ean']);
                final codMar = _getString(pRow, ['pro00_codmar', 'codmar']);
                if (codMar.isNotEmpty) {
                  try {
                    final mr = await activeDb.rawQuery('SELECT mar00_descri FROM cadmar00 WHERE mar00_codigo = ? LIMIT 1', [codMar]);
                    if (mr.isNotEmpty) {
                      marca = _getString(mr.first, ['mar00_descri', 'descri']);
                    }
                  } catch (_) {}
                }
              }
            } catch (_) {}
          }

          itensDto.add(ItemEspelhoDTO(
            sequencial: seq,
            codigoProduto: codPrdInt,
            codigoEAN: ean,
            descricao: descri,
            marca: marca,
            unidade: unid,
            quantidadeDigitada: qtdPed,
            quantidadeFaturada: fatQtd,
            precoUnitario: pco,
            descontoPercentual: perDes,
            valorTotal: tot,
            isBonificacao: isBon,
          ));
        }
      }
    } catch (_) {}

    String statusStr = 'Digitado';
    if (sttEnv == 1) statusStr = 'Empacotado';
    if (sttEnv == 2) statusStr = 'Transmitido';
    if (sttEnv == 3) statusStr = 'Faturado';

    return EspelhoPedidoDTO(
      numeroPedido: pedidoId,
      numeroNotaFiscal: nf,
      numeroPacote: pacStr,
      dataEmissao: dataEmissao,
      vendedorCodigo: repCod,
      vendedorNome: vendedorNome,
      empresaEndereco: empEnd,
      empresaBairroCep: empBairroCep,
      empresaCidadeUf: empCidUf,
      empresaTelefone: empFone,
      clienteCodigo: cliCod.toString(),
      clienteRazaoSocial: clienteRazaoSocial,
      clienteNomeFantasia: clienteFantasia,
      clienteCpfCnpj: clienteCpfCnpj,
      clienteIE: clienteIE,
      clienteEndereco: clienteEndereco,
      clienteNumero: clienteNumero,
      clienteBairro: clienteBairro,
      clienteCep: clienteCep,
      clienteCidade: clienteCidade,
      clienteUf: clienteUf,
      clienteTelefone: clienteTelefone,
      planoPagamento: planoDesc,
      linhaProduto: linhaDesc,
      agenteCobrador: agenteDesc,
      status: statusStr,
      observacao: obs,
      valorTotalDigitado: digtot,
      valorTotalFaturado: fattot > 0 ? fattot : digtot,
      valorTotalBonificado: bontot,
      valorSubstituicaoTributaria: subtot,
      valorDescontoTotal: destot,
      itens: itensDto,
      duplicatas: const [],
    );
  } finally {
    if (shouldCloseDb && activeDb != null && activeDb.isOpen) {
      await activeDb.close();
    }
  }
}
