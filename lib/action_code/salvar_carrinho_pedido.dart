import '/backend/schema/structs/index.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:io';

Future<bool> salvarCarrinhoPedido({
  required int pedidoId,
  required int clienteCodigo,
  required String? linhaCodigo,
  required String? planoCodigo,
  required List<ItemPedidoStruct> carrinhoItens,
}) async {
  Database? db;
  try {
    final dbPath = join(await getDatabasesPath(), 'dbforcacad001.db');
    if (!await File(dbPath).exists()) {
      print('Erro: Banco de dados local não encontrado para salvar o carrinho.');
      return false;
    }

    db = await openDatabase(dbPath);

    // 1. Gravar Cabeçalho do Pedido (tabela pckvendig000 se existir)
    try {
      final List<Map<String, dynamic>> tablesHeader = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='pckvendig000'"
      );
      if (tablesHeader.isNotEmpty) {
        final List<Map<String, dynamic>> columns = await db.rawQuery('PRAGMA table_info(pckvendig000)');
        final colNames = columns.map((r) => r['name']?.toString().toLowerCase()).toSet();

        final List<String> insertCols = [];
        final List<String> placeholders = [];
        final List<dynamic> binds = [];

        // Verifica mapeamento dinâmico para evitar erros de colunas faltantes
        if (colNames.contains('ped00_numped')) {
          insertCols.add('ped00_numped');
          placeholders.add('?');
          binds.add(pedidoId);
        }
        
        // Código do cliente
        if (colNames.contains('ped00_codcli')) {
          insertCols.add('ped00_codcli');
          placeholders.add('?');
          binds.add(clienteCodigo);
        } else if (colNames.contains('ped00_clicod')) {
          insertCols.add('ped00_clicod');
          placeholders.add('?');
          binds.add(clienteCodigo);
        }

        // Código da linha
        final linVal = int.tryParse(linhaCodigo ?? '') ?? 0;
        if (colNames.contains('ped00_codlin')) {
          insertCols.add('ped00_codlin');
          placeholders.add('?');
          binds.add(linVal);
        }

        // Plano de pagamento
        final plaVal = int.tryParse(planoCodigo ?? '') ?? 0;
        if (colNames.contains('ped00_codpla')) {
          insertCols.add('ped00_codpla');
          placeholders.add('?');
          binds.add(plaVal);
        } else if (colNames.contains('ped00_codpag')) {
          insertCols.add('ped00_codpag');
          placeholders.add('?');
          binds.add(plaVal);
        }

        if (insertCols.isNotEmpty) {
          final query = 'INSERT OR REPLACE INTO pckvendig000 (${insertCols.join(', ')}) VALUES (${placeholders.join(', ')})';
          await db.rawInsert(query, binds);
          print('Header do pedido #$pedidoId salvo com sucesso no SQLite.');
        }
      }
    } catch (e) {
      print('Erro ao tentar salvar header (pckvendig000): $e');
    }

    // 2. Gravar Itens do Pedido (tabela pckvendig010)
    try {
      final List<Map<String, dynamic>> tablesItems = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='pckvendig010'"
      );
      if (tablesItems.isEmpty) {
        print('Aviso: Tabela pckvendig010 não existe no SQLite.');
        await db.close();
        return false;
      }

      final List<Map<String, dynamic>> columns = await db.rawQuery('PRAGMA table_info(pckvendig010)');
      final colNames = columns.map((r) => r['name']?.toString().toLowerCase()).toSet();

      // Primeiro limpa os itens antigos desse pedido se houver a coluna numped
      if (colNames.contains('ped10_numped')) {
        await db.rawDelete('DELETE FROM pckvendig010 WHERE ped10_numped = ?', [pedidoId]);
      } else {
        // Se não tiver numped, limpa tudo pois o banco local é temporário e armazena apenas o pedido ativo
        await db.rawDelete('DELETE FROM pckvendig010');
      }

      for (final item in carrinhoItens) {
        final List<String> insertCols = [];
        final List<String> placeholders = [];
        final List<dynamic> binds = [];

        if (colNames.contains('ped10_numped')) {
          insertCols.add('ped10_numped');
          placeholders.add('?');
          binds.add(pedidoId);
        }

        if (colNames.contains('ped10_codprd')) {
          insertCols.add('ped10_codprd');
          placeholders.add('?');
          binds.add(item.codigoProduto);
        }

        if (colNames.contains('ped10_descri')) {
          insertCols.add('ped10_descri');
          placeholders.add('?');
          binds.add(item.descricao);
        }

        if (colNames.contains('ped10_unidpri')) {
          insertCols.add('ped10_unidpri');
          placeholders.add('?');
          binds.add(item.unidade);
        }

        if (colNames.contains('ped10_qtdped')) {
          insertCols.add('ped10_qtdped');
          placeholders.add('?');
          binds.add(item.isBonificacao ? 0.0 : item.quantidade);
        }

        if (colNames.contains('ped10_pcosub')) {
          insertCols.add('ped10_pcosub');
          placeholders.add('?');
          binds.add(item.isBonificacao ? 0.0 : item.precoUnitario);
        }

        if (colNames.contains('ped10_totprd')) {
          insertCols.add('ped10_totprd');
          placeholders.add('?');
          binds.add(item.isBonificacao ? 0.0 : item.totalItem);
        }

        if (colNames.contains('ped10_qtdbon')) {
          insertCols.add('ped10_qtdbon');
          placeholders.add('?');
          binds.add(item.isBonificacao ? item.quantidadeBonificada : 0.0);
        }

        if (colNames.contains('ped10_sttbon')) {
          insertCols.add('ped10_sttbon');
          placeholders.add('?');
          binds.add(item.isBonificacao ? 1 : 0);
        } else if (colNames.contains('ped10_flgbon')) {
          insertCols.add('ped10_flgbon');
          placeholders.add('?');
          binds.add(item.isBonificacao ? 1 : 0);
        } else if (colNames.contains('ped10_bonificado')) {
          insertCols.add('ped10_bonificado');
          placeholders.add('?');
          binds.add(item.isBonificacao ? 1 : 0);
        }



        if (colNames.contains('ped10_codcmb') && item.codigoCombo.isNotEmpty) {
          insertCols.add('ped10_codcmb');
          placeholders.add('?');
          binds.add(item.codigoCombo);
        }

        if (insertCols.isNotEmpty) {
          final query = 'INSERT OR REPLACE INTO pckvendig010 (${insertCols.join(', ')}) VALUES (${placeholders.join(', ')})';
          await db.rawInsert(query, binds);
        }
      }
      print('Carrinho com ${carrinhoItens.length} itens salvo no SQLite.');
    } catch (e) {
      print('Erro ao tentar salvar itens (pckvendig010): $e');
      await db.close();
      return false;
    }

    await db.close();
    return true;
  } catch (e) {
    print('Erro geral ao salvar carrinho: $e');
    if (db != null && db.isOpen) {
      await db.close();
    }
    return false;
  }
}
