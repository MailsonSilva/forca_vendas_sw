import 'dart:io';
import 'package:sqflite/sqflite.dart';
import '../data/services/local_sales_database_service.dart';
import '../domain/models/status_envio.dart';

/// Centraliza a atualização do lifecycle de status de envio (NEnviado → JEnviado)
/// no SQLite local, replicando o `doEnviado()` do legado C++/Delphi.
///
/// Regras do protocolo legado:
///   - Sucesso no upload → status `StatusEnvio.jaEnviado` (1).
///   - Falha → manter `StatusEnvio.naoEnviado` (0); o arquivo fica na fila.
///   - `StatusEnvio.retornado` (2) é preenchido pelo ERP ao retornar com erro.
///
/// A coluna de status é descoberta via `PRAGMA table_info`, tolerando variações
/// de nomenclatura entre versões da base local. Se o banco não existir, o método
/// é um no-op seguro (sem lançar exceção).
class StatusEnvioDb {
  StatusEnvioDb({this.dbPath});

  /// Caminho do banco SQLite local. Nulo → usa o default `dbforcacad001.db`.
  final String? dbPath;

  static const List<String> _candidatasPedido = [
    'ped00_sttenv',
    'ped00_enviado',
    'ped00_status',
    'ped00_sitped',
    'ped00_situac',
  ];

  static const List<String> _candidatasCliente = [
    'cli00_flgven',
    'cli00_status',
    'cli00_enviado',
    'cli00_sitcli',
  ];

  Future<String> _resolveDbPath() async {
    if (dbPath != null) return dbPath!;
    return LocalSalesDatabaseService.getDatabasePath();
  }

  /// Marca um pedido como enviado (`PedidoSttEnv.enviados = 2`) na tabela `pckvendig000`,
  /// identificado por `ped00_numped`.
  Future<void> marcarPedidoEnviado(int codMov) =>
      _marcar('pckvendig000', _candidatasPedido, 'ped00_numped', codMov,
          valorStatus: PedidoSttEnv.enviados.value);

  /// PRD 1 §5B — batch JEnviado: UPDATE ... WHERE ped00_numped IN (...) em transação.
  /// Grava sttenv = 2 (PedidoSttEnv.enviados) garantindo que 1 seja exclusivo para empacotado.
  Future<void> marcarPedidosEnviados(List<int> codMovs) async {
    if (codMovs.isEmpty) return;
    // Deduplica e filtra zeros
    final ids = codMovs.where((e) => e != 0).toSet().toList();
    if (ids.isEmpty) return;
    try {
      final path = await _resolveDbPath();
      if (!await File(path).exists()) return;
      final db = await openDatabase(path);
      try {
        final columns = await db.rawQuery('PRAGMA table_info(pckvendig000)');
        final colNames = columns.map((r) => r['name']?.toString().toLowerCase()).toSet();
        String? col;
        for (final c in _candidatasPedido) {
          if (colNames.contains(c.toLowerCase())) { col = c; break; }
        }
        if (col == null) return;
        final placeholders = List.filled(ids.length, '?').join(',');
        await db.transaction((txn) async {
          await txn.rawUpdate(
            'UPDATE pckvendig000 SET $col = ? WHERE ped00_numped IN ($placeholders)',
            [PedidoSttEnv.enviados.value, ...ids],
          );
        });
      } finally {
        await db.close();
      }
    } catch (_) {}
  }

  /// Marca um cliente como enviado (`jaEnviado`) na tabela `cadcli00`,
  /// identificado por `cli00_codigo`.
  Future<void> marcarClienteEnviado(int codCli) =>
      _marcar('cadcli00', _candidatasCliente, 'cli00_codigo', codCli);

  /// Batch clientes (análogo a pedidos, para uso futuro).
  Future<void> marcarClientesEnviados(List<int> codClis) async {
    if (codClis.isEmpty) return;
    final ids = codClis.where((e) => e != 0).toSet().toList();
    if (ids.isEmpty) return;
    try {
      final path = await _resolveDbPath();
      if (!await File(path).exists()) return;
      final db = await openDatabase(path);
      try {
        final columns = await db.rawQuery('PRAGMA table_info(cadcli00)');
        final colNames = columns.map((r) => r['name']?.toString().toLowerCase()).toSet();
        String? col;
        for (final c in _candidatasCliente) {
          if (colNames.contains(c.toLowerCase())) { col = c; break; }
        }
        if (col == null) return;
        final placeholders = List.filled(ids.length, '?').join(',');
        await db.transaction((txn) async {
          await txn.rawUpdate(
            'UPDATE cadcli00 SET $col = ? WHERE cli00_codigo IN ($placeholders)',
            [StatusEnvio.jaEnviado.value, ...ids],
          );
        });
      } finally {
        await db.close();
      }
    } catch (_) {}
  }

  Future<void> _marcar(
    String tabela,
    List<String> candidatas,
    String colunaChave,
    int valorChave, {
    int? valorStatus,
  }) async {
    try {
      final path = await _resolveDbPath();
      if (!await File(path).exists()) return;

      final db = await openDatabase(path);
      try {
        final columns = await db.rawQuery('PRAGMA table_info($tabela)');
        final colNames =
            columns.map((r) => r['name']?.toString().toLowerCase()).toSet();

        String? col;
        for (final c in candidatas) {
          if (colNames.contains(c.toLowerCase())) {
            col = c;
            break;
          }
        }
        if (col == null) return;

        final statusVal = valorStatus ?? StatusEnvio.jaEnviado.value;
        await db.rawUpdate(
          'UPDATE $tabela SET $col = ? WHERE $colunaChave = ?',
          [statusVal, valorChave],
        );
      } finally {
        await db.close();
      }
    } catch (_) {
      // No-op: ausência da base/coluna não deve quebrar o fluxo de upload.
    }
  }
}
