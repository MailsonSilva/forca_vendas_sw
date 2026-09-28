import 'package:sqflite/sqflite.dart';
import '../../domain/models/cliente_novo_model.dart';
import '../services/local_sales_database_service.dart';

/// Repositório para gerenciamento dos clientes no SQLite local,
/// separando estritamente os cadastros locais ('cadclipre00') da carga externa ('cadcli00').
class ClienteRepository {
  static Database? _dbForTesting;

  static void setDatabaseForTesting(Database? db) {
    _dbForTesting = db;
  }

  Future<Database> _getDb() async {
    if (_dbForTesting != null) {
      return _dbForTesting!;
    }
    return LocalSalesDatabaseService.getDatabase();
  }

  /// Garante a criação da tabela de novos clientes locais ('cadclipre00')
  Future<void> inicializarTabelas() async {
    final db = await _getDb();
    await db.execute('''
      CREATE TABLE IF NOT EXISTS cadclipre00 (
        cli00_codigo INTEGER PRIMARY KEY AUTOINCREMENT,
        cli00_codrep INTEGER,
        cli00_descri TEXT,
        cli00_fantas TEXT,
        cli00_typpes INTEGER DEFAULT 1,
        cli00_cpfcnp TEXT,
        cli00_insest TEXT,
        cli00_nrg TEXT,
        cli00_email TEXT,
        cli00_endere TEXT,
        cli00_endnum TEXT,
        cli00_bairro TEXT,
        cli00_ciddes TEXT,
        cli00_estsgl TEXT,
        cli00_endcep TEXT,
        cli00_fonddd TEXT,
        cli00_fonnum TEXT,
        cli00_observ TEXT,
        cli00_crelim REAL DEFAULT 0,
        cli00_creatu REAL DEFAULT 0,
        cli00_titven REAL DEFAULT 0,
        cli00_active INTEGER DEFAULT 1,
        novo_local INTEGER DEFAULT 1,
        status_envio TEXT DEFAULT 'pendente_envio'
      )
    ''');
  }

  /// Insere um novo cliente local na tabela 'cadclipre00'
  Future<int> inserirNovoCliente(ClienteNovo cliente, {int? codRep}) async {
    await inicializarTabelas();
    final db = await _getDb();

    final data = cliente.toMap();
    if (codRep != null && (data['cli00_codrep'] == null || data['cli00_codrep'] == 0)) {
      data['cli00_codrep'] = codRep;
    }

    final id = await db.insert('cadclipre00', data);
    return id;
  }

  /// Retorna os novos clientes locais pendentes de transmissão FTP
  Future<List<ClienteNovo>> listarNovosClientesPendentes() async {
    await inicializarTabelas();
    final db = await _getDb();

    final rows = await db.query(
      'cadclipre00',
      where: 'status_envio = ? OR status_envio IS NULL',
      whereArgs: ['pendente_envio'],
      orderBy: 'cli00_codigo ASC',
    );

    return rows.map((m) => ClienteNovo.fromMap(m)).toList();
  }

  /// Retorna todos os novos clientes cadastrados localmente
  Future<List<ClienteNovo>> listarTodosNovosClientes() async {
    await inicializarTabelas();
    final db = await _getDb();

    final rows = await db.query(
      'cadclipre00',
      orderBy: 'cli00_codigo DESC',
    );

    return rows.map((m) => ClienteNovo.fromMap(m)).toList();
  }

  /// Atualiza o status de sincronização pós-upload FTP
  Future<void> marcarClienteSincronizado(int codigo) async {
    await inicializarTabelas();
    final db = await _getDb();

    await db.update(
      'cadclipre00',
      {'status_envio': 'sincronizado'},
      where: 'cli00_codigo = ?',
      whereArgs: [codigo],
    );
  }

  /// Verifica se o cliente é originário da carga (cadcli00) com cli00_codigo > 0
  /// e não é um novo cliente local (cadclipre00).
  Future<bool> isClienteDaCarga(int codigo) async {
    if (codigo <= 0) return false;
    await inicializarTabelas();
    final db = await _getDb();

    // Se estiver em cadclipre00 com novo_local = 1, NÃO é da carga
    final localRows = await db.query(
      'cadclipre00',
      columns: ['cli00_codigo'],
      where: 'cli00_codigo = ?',
      whereArgs: [codigo],
      limit: 1,
    );
    if (localRows.isNotEmpty) return false;

    // Se estiver em cadcli00 com cli00_codigo > 0, é da carga
    try {
      final cargaRows = await db.query(
        'cadcli00',
        columns: ['cli00_codigo'],
        where: 'cli00_codigo = ?',
        whereArgs: [codigo],
        limit: 1,
      );
      return cargaRows.isNotEmpty;
    } catch (_) {
      return false;
    }
  }
}
