import 'dart:io';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
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
    'ped00_status',
    'ped00_sitped',
    'ped00_situac',
    'ped00_enviado',
  ];

  static const List<String> _candidatasCliente = [
    'cli00_flgven',
    'cli00_status',
    'cli00_enviado',
    'cli00_sitcli',
  ];

  Future<String> _resolveDbPath() async {
    if (dbPath != null) return dbPath!;
    return join(await getDatabasesPath(), 'dbforcacad001.db');
  }

  /// Marca um pedido como enviado (`jaEnviado`) na tabela `pckvendig000`,
  /// identificado por `ped00_numped`.
  Future<void> marcarPedidoEnviado(int codMov) =>
      _marcar('pckvendig000', _candidatasPedido, 'ped00_numped', codMov);

  /// Marca um cliente como enviado (`jaEnviado`) na tabela `cadcli00`,
  /// identificado por `cli00_codigo`.
  Future<void> marcarClienteEnviado(int codCli) =>
      _marcar('cadcli00', _candidatasCliente, 'cli00_codigo', codCli);

  Future<void> _marcar(
    String tabela,
    List<String> candidatas,
    String colunaChave,
    int valorChave,
  ) async {
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

        await db.rawUpdate(
          'UPDATE $tabela SET $col = ? WHERE $colunaChave = ?',
          [StatusEnvio.jaEnviado.value, valorChave],
        );
      } finally {
        await db.close();
      }
    } catch (_) {
      // No-op: ausência da base/coluna não deve quebrar o fluxo de upload.
    }
  }
}
