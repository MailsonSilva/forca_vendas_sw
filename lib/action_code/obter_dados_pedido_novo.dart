import '/backend/schema/structs/index.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:io';

class DadosPedidoNovoResult {
  final List<ClienteResultStruct> clientes;
  final List<ListaPadraoStruct> linhas;
  final List<ListaPadraoStruct> planos;

  DadosPedidoNovoResult({
    required this.clientes,
    required this.linhas,
    required this.planos,
  });
}

Future<DadosPedidoNovoResult> obterDadosPedidoNovo() async {
  List<ClienteResultStruct> clientes = [];
  List<ListaPadraoStruct> linhas = [];
  List<ListaPadraoStruct> planos = [];

  try {
    final dbPath = join(await getDatabasesPath(), 'dbforcacad001.db');
    if (!await File(dbPath).exists()) {
      print('Aviso: Banco de dados local não encontrado para carregar dados do novo pedido.');
      return DadosPedidoNovoResult(clientes: [], linhas: [], planos: []);
    }

    final db = await openDatabase(dbPath);

    // 1. Clientes
    try {
      final List<Map<String, dynamic>> resClientes = await db.rawQuery('''
        SELECT 
          cli00_codigo, 
          cli00_descri, 
          cli00_fantas, 
          cli00_ciddes, 
          cli00_cpfcnp, 
          cli00_crelim 
        FROM cadcli00 
        WHERE cli00_active in (0,1) 
        ORDER BY cli00_descri
      ''');
      clientes = resClientes.map((m) {
        return ClienteResultStruct(
          cli00Codigo: m['cli00_codigo'] as int?,
          cli00Descri: m['cli00_descri']?.toString() ?? '',
          cli00Fantas: m['cli00_fantas']?.toString() ?? '',
          cli00Ciddes: m['cli00_ciddes']?.toString() ?? '',
          cli00Cpfcnp: m['cli00_cpfcnp']?.toString() ?? '',
          cli00Crelim: (m['cli00_crelim'] as num?)?.toDouble() ?? 0.0,
          success: true,
        );
      }).toList();
    } catch (e) {
      print('Erro ao carregar clientes do SQLite: $e');
    }

    // 2. Linhas
    try {
      final List<Map<String, dynamic>> resLinhas = await db.rawQuery('''
        SELECT lin00_codigo, lin00_descri FROM cadlin00 ORDER BY lin00_descri
      ''');
      linhas = resLinhas.map((m) {
        return ListaPadraoStruct(
          codigo: m['lin00_codigo']?.toString() ?? '',
          descricao: m['lin00_descri']?.toString() ?? '',
        );
      }).toList();
    } catch (e) {
      print('Erro ao carregar linhas do SQLite: $e');
    }

    // 3. Planos de Pagamento
    try {
      final List<Map<String, dynamic>> resPlanos = await db.rawQuery('''
        SELECT pla00_codigo, pla00_descri FROM cadpla00 ORDER BY pla00_descri
      ''');
      planos = resPlanos.map((m) {
        return ListaPadraoStruct(
          codigo: m['pla00_codigo']?.toString() ?? '',
          descricao: m['pla00_descri']?.toString() ?? '',
        );
      }).toList();
    } catch (e) {
      print('Erro ao carregar planos de pagamento do SQLite: $e');
    }

    await db.close();
  } catch (e) {
    print('Erro geral no SQLite ao obter dados de novo pedido: $e');
  }

  return DadosPedidoNovoResult(
    clientes: clientes,
    linhas: linhas,
    planos: planos,
  );
}
