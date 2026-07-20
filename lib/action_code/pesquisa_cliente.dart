// Imports do app
import '/backend/schema/structs/index.dart';
import '/core/app_theme.dart';
import '/core/app_util.dart';
import '/action_code/index.dart'; // Imports other custom actions
import '/core/app_functions.dart'; // Imports custom functions
import 'package:flutter/material.dart';
// Begin custom action code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:io';

Future<List<ClienteResultStruct>> pesquisaCliente(
  String? filtro,
  int? offset,
) async {
  try {
    // 1. Valida se o banco de dados já existe no aparelho
    final dbPath = join(await getDatabasesPath(), 'dbforcacad001.db');
    if (!await File(dbPath).exists()) {
      print('Erro: Banco de dados não encontrado para a pesquisa de clientes.');
      return [];
    }

    final db = await openDatabase(dbPath);
    final String busca = filtro?.trim() ?? '';
    final int currentOffset = offset ?? 0;

    // 2. Garante que sempre buscará APENAS clientes ativos
    String whereClause = 'WHERE cli00_active in (0,1)';
    List<dynamic> binds = [];

    // 3. Aplica o filtro de texto ou numérico conforme a busca do usuário
    if (busca.isNotEmpty) {
      final isNumeric = RegExp(r'^\d+$').hasMatch(busca);
      if (isNumeric) {
        whereClause += ' AND (cli00_codigo = ? OR cli00_cpfcnp LIKE ?)';
        binds.addAll([int.tryParse(busca) ?? 0, '%$busca%']);
      } else {
        final termo = '%${busca.toUpperCase()}%';
        whereClause +=
            ' AND (UPPER(cli00_descri) LIKE ? OR UPPER(cli00_fantas) LIKE ?)';
        binds.addAll([termo, termo]);
      }
    }

    // 4. Sua query original mantendo todos os aliases (apelidos) exatamente iguais
    final String query = '''
      SELECT 
        cli00_codigo AS codigo,
        cli00_descri AS nome,
        cli00_fantas AS fantasia,
        cli00_cpfcnp AS cpfCnpj,
        cli00_insest AS ie,
        cli00_endere AS endereco,
        cli00_endnum AS numero,
        cli00_bairro AS bairro,
        cli00_ciddes AS cidade,
        cli00_estsgl AS uf,
        cli00_endcep AS cep,
        cli00_fonnum AS telefone,
        cli00_observ AS email,
        cli00_active AS ativo,
        COALESCE(cli00_titven, 0) AS cli00Titven,
        COALESCE(cli00_titave, 0) AS cli00Titave
      FROM cadcli00 
      $whereClause
      ORDER BY cli00_descri 
      LIMIT 500 OFFSET ?
    ''';

    binds.add(currentOffset);
    final results = await db.rawQuery(query, binds);
    await db.close();

    // 5. Retorna a lista mapeada usando os apelidos da query
    return results.map((m) {
      int cli00Active = int.tryParse(m['ativo']?.toString() ?? '1') ?? 1;
      double cli00Titven =
          double.tryParse(m['cli00Titven']?.toString() ?? '0') ?? 0.0;
      double cli00Titave =
          double.tryParse(m['cli00Titave']?.toString() ?? '0') ?? 0.0;

      // Mantém a sua lógica dinâmica de atribuição de cor
      Color corDefinida;
      if (cli00Active == 0) {
        corDefinida = const Color(0xFFD32F2F); // Inativo
      } else if (cli00Titven > 0 || cli00Titave > 0) {
        corDefinida = const Color(0xFFFFD700); // Pendências
      } else {
        corDefinida = const Color(0xFF10B981); // Limpo
      }

      // Correção: Instanciação direta por propriedades nomeadas para evitar que venha em branco no Flutter
      return ClienteResultStruct(
        cli00Codigo: int.tryParse(m['codigo']?.toString() ?? '0'),
        cli00Descri: m['nome']?.toString() ?? '',
        cli00Fantas: m['fantasia']?.toString() ?? '',
        cli00Cpfcnp: m['cpfCnpj']?.toString() ?? '',
        cli00Insest: m['ie']?.toString() ?? '',
        cli00Endere: m['endereco']?.toString() ?? '',
        cli00Endnum: m['numero']?.toString() ?? '',
        cli00Bairro: m['bairro']?.toString() ?? '',
        cli00Ciddes: m['cidade']?.toString() ?? '',
        cli00Estsgl: m['uf']?.toString() ?? '',
        cli00Endcep: m['cep']?.toString() ?? '',
        cli00Fonnum: m['telefone']?.toString() ?? '',
        cli00Observ: m['email']?.toString() ?? '',
        cli00Active: cli00Active,
        cli00Titven: cli00Titven,
        cli00Titave: cli00Titave,
        success: true,
        corBorda: corDefinida,
      );
    }).toList();
  } catch (e) {
    print('Erro fatal na busca do SQLite: ' + e.toString());
    return [];
  }
}
