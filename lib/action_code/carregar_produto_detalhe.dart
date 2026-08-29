// Imports do app
import '/backend/schema/structs/index.dart';
// Imports other custom actions
// Imports custom functions
// Begin custom action code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

// Set your action name, define your arguments and return parameter,
// and then add the boilerplate code using the `</>` button on the right!
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../app_state.dart';

Future<ProdutoResultStruct?> carregarProdutoDetalhe(
  String? produtoRef,
) async {
  final String codigoBusca = (produtoRef ?? '').trim();
  if (codigoBusca.isEmpty) return null;

  try {
    // 1. Abre o banco local com segurança
    final dbPath = join(await getDatabasesPath(), 'dbforcacad001.db');
    if (!await File(dbPath).exists()) {
      return null;
    }

    final db = await openDatabase(dbPath);
    try {
      final int filial = AppState().codFilialAtiva != 0 ? AppState().codFilialAtiva : 1;

      // 2. Consulta detalhada com JOIN de preço e estoque por filial
      const String query = '''
        SELECT p.*,
               COALESCE(t.pro00_pcosub, 0) AS preco_venda,
               COALESCE(e.pro00_qtdest, 0) AS estoque_atual,
               COALESCE(e.pro00_qtdpen, 0) AS estoque_pendente,
               (COALESCE(e.pro00_qtdest, 0) - COALESCE(e.pro00_qtdpen, 0)) AS saldo
        FROM cadpro00 p
        LEFT JOIN estpcopro00 t ON t.pro00_codpro = p.pro00_codigo
        LEFT JOIN estpro00 e ON e.pro00_codpro = p.pro00_codigo AND e.pro00_codfil = ?
        WHERE p.pro00_codigo = ? OR CAST(p.pro00_codigo AS INTEGER) = ?
        LIMIT 1
      ''';

      final intVal = int.tryParse(codigoBusca) ?? -1;
      List<Map<String, dynamic>> maps = await db.rawQuery(query, [filial, codigoBusca, intVal]);

      if (maps.isNotEmpty) {
        final m = maps.first;
        String codigoProd = m['pro00_codigo']?.toString().trim() ?? codigoBusca;

        // Código base limpo para encontrar os arquivos físicos (ex: 10586)
        String baseImgCode = int.tryParse(codigoProd)?.toString() ?? codigoProd;

        final directory = await getApplicationDocumentsDirectory();
        final String pastaImagensPath =
            "${directory.path}/images/catalogo_imagens";

        List<String> fotosEncontradas = [];
        // Varre do arquivo principal até as subimagens secundárias (_1, _2, _3...)
        List<String> sufixos = [
          '',
          '_1',
          '_2',
          '_3',
          '_4',
          '_5',
          '_6',
          '_7',
          '_8'
        ];

        for (String sufixo in sufixos) {
          String nomeArquivo = "$baseImgCode$sufixo.jpg";
          String caminhoFisicoParaTeste = "$pastaImagensPath/$nomeArquivo";

          if (await File(caminhoFisicoParaTeste).exists()) {
            fotosEncontradas.add("images/catalogo_imagens/$nomeArquivo");
          }
        }

        // Se não houver fotos baixadas, garante pelo menos uma string para o carrossel renderizar o ícone cinza
        if (fotosEncontradas.isEmpty) {
          fotosEncontradas.add("images/catalogo_imagens/$baseImgCode.jpg");
        }

        double parseDouble(dynamic value) {
          if (value == null) return 0.0;
          if (value is num) return value.toDouble();
          if (value is String) return double.tryParse(value) ?? 0.0;
          return 0.0;
        }

        final double estoqueAtual = parseDouble(m['estoque_atual']);
        final double estoquePendente = parseDouble(m['estoque_pendente']);
        double saldo = parseDouble(m['saldo']);
        if (saldo < 0) saldo = 0.0;

        // 3. Retorna o Struct populando os campos
        return ProdutoResultStruct(
          codigo: codigoProd,
          descricao: m['pro00_descri']?.toString() ?? '',
          unidade: m['pro00_unidad']?.toString() ?? '',
          preco: parseDouble(m['preco_venda']),
          saldoEstoque: saldo,
          estoqueAtual: estoqueAtual,
          estoquePendente: estoquePendente,
          linha: m['pro00_codlin']?.toString() ?? '',
          grupo: m['pro00_codgrp']?.toString() ?? '',
          fabricante: m['pro00_codfab']?.toString() ?? '',
          marca: m['pro00_codmar']?.toString() ?? '',
          codbar: m['pro00_codbar']?.toString() ?? '',
          mulver: parseDouble(m['pro00_mulver']),
          pcomin: parseDouble(m['pro00_pcomin']),
          pcomax: parseDouble(m['pro00_pcomax']),
          commax: parseDouble(m['pro00_commax']),
          fotosProduto: fotosEncontradas,
        );
      }
    } finally {
      await db.close();
    }
  } catch (e) {
    print('Erro em carregarProdutoDetalhe: $e');
  }
  return null;
}
