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

Future<ProdutoResultStruct?> carregarProdutoDetalhe(
  String? produtoRef,
) async {
  try {
    // 1. Abre o banco local com segurança
    final dbPath = join(await getDatabasesPath(), 'dbforcacad001.db');
    if (!await File(dbPath).exists()) {
      return null;
    }

    final db = await openDatabase(dbPath);
    final String codigoBusca = (produtoRef ?? '').trim();
    if (codigoBusca.isEmpty) return null;

    // 2. Consulta padrão por código de produto
    List<Map<String, dynamic>> maps = await db.query(
      'cadpro00',
      where: 'pro00_codigo = ?',
      whereArgs: [codigoBusca],
    );

    // Fallback caso haja divergência de zeros à esquerda entre o BD e o parâmetro
    if (maps.isEmpty) {
      final intValue = int.tryParse(codigoBusca);
      if (intValue != null) {
        maps = await db.query(
          'cadpro00',
          where: 'CAST(pro00_codigo AS INTEGER) = ?',
          whereArgs: [intValue],
        );
      }
    }

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
          // Adiciona o caminho relativo que o ImagemLocalWidget processa com perfeição
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

      // 3. Retorna o Struct populando os campos e corrigindo o nome da propriedade de fotos
      return ProdutoResultStruct(
        codigo: codigoProd,
        descricao: m['pro00_descri']?.toString() ?? '',
        unidade: m['pro00_unidad']?.toString() ?? '',
        preco: parseDouble(m['preco_venda']),
        saldoEstoque: parseDouble(m['saldo']),
        estoqueAtual: parseDouble(m['estoque_atual']),
        estoquePendente: parseDouble(m['estoque_pendente']),
        linha: m['pro00_codlin']?.toString() ?? '',
        grupo: m['pro00_codgrp']?.toString() ?? '',
        fabricante: m['pro00_codfab']?.toString() ?? '',
        marca: m['pro00_codmar']?.toString() ?? '',
        fotosProduto:
            fotosEncontradas, // <-- CORREÇÃO: Alinhado com o nome do campo no seu Struct!
      );
    }
  } catch (e) {
    print('Erro em carregarProdutoDetalhe: $e');
  }
  return null;
}
