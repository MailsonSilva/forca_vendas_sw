// Imports do app
import '/backend/schema/structs/index.dart';
// Imports other custom actions
// Imports custom functions
// Begin custom action code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../app_state.dart';
import '/data/repositories/produto_repository.dart';
import '/data/services/local_sales_database_service.dart';
import '/domain/models/produto_detalhe_dto.dart';

/// Carrega os detalhes completos do produto sob demanda via Query 2 fiel ao Tcadpro00::cload de usysctr00.cpp (SPEC-052).
Future<ProdutoResultStruct?> carregarProdutoDetalhe(
  String? produtoRef,
) async {
  final String codigoBusca = (produtoRef ?? '').trim();
  if (codigoBusca.isEmpty) return null;

  try {
    final int filial = AppState().codFilialAtiva != 0 ? AppState().codFilialAtiva : 1;
    final int tabela = AppState().tabelaPrecoAtiva > 0 ? AppState().tabelaPrecoAtiva : 1;
    final int regiao = AppState().clienteSelecionado?.codRegiao ?? 0;
    final int classe = AppState().clienteSelecionado?.codTipoPreco ?? 0;

    final repo = ProdutoRepository();
    final int? codpro = int.tryParse(codigoBusca);

    ProdutoDetalheDTO? detalhe;
    if (codpro != null) {
      detalhe = await repo.obterDetalhesProduto(codpro, filial, tabela, regiao, classe);
    }

    // Fallback de contingência caso o repositório não tenha localizado o produto (ex: código alfanumérico ou schema restrito)
    if (detalhe == null) {
      final db = await LocalSalesDatabaseService.getDatabase(readOnly: true);
      final fallbackRows = await db.rawQuery(
        'SELECT * FROM cadpro00 WHERE pro00_codigo = ? OR CAST(pro00_codigo AS TEXT) = ? LIMIT 1',
        [codigoBusca, codigoBusca],
      );
      if (fallbackRows.isNotEmpty) {
        detalhe = ProdutoDetalheDTO.fromMap(fallbackRows.first);
      }
    }

    if (detalhe != null) {
      // Código base limpo para encontrar os arquivos físicos (ex: 10586)
      final String baseImgCode = detalhe.codigo.toString();

      List<String> fotosEncontradas = [];
      try {
        final directory = await getApplicationDocumentsDirectory();
        final String pastaImagensPath = "${directory.path}/images/catalogo_imagens";

        // Varre do arquivo principal até as subimagens secundárias (_1, _2, _3...)
        final List<String> sufixos = [
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
      } catch (_) {}

      // Se não houver fotos baixadas, garante pelo menos uma string para o carrossel renderizar o ícone cinza
      if (fotosEncontradas.isEmpty) {
        fotosEncontradas.add("images/catalogo_imagens/$baseImgCode.jpg");
      }

      // Consulta complementar segura de descrições de marca/fabricante se existirem
      final double precoVenda = detalhe.preco;
      String? marcaDescri;
      String? fabDescri;

      try {
        final db = await LocalSalesDatabaseService.getDatabase(readOnly: true);
        final tRows = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table'");
        final Set<String> tabelas = tRows.map((r) => r['name']?.toString().toLowerCase() ?? '').toSet();
        if (detalhe.codmar != null && tabelas.contains('cadmar00')) {
          final marRows = await db.rawQuery(
            'SELECT mar00_descri FROM cadmar00 WHERE mar00_codigo = ? LIMIT 1',
            [detalhe.codmar],
          );
          if (marRows.isNotEmpty) {
            marcaDescri = marRows.first['mar00_descri']?.toString();
          }
        }
        if (detalhe.codfab != null && tabelas.contains('cadfor00')) {
          final fabRows = await db.rawQuery(
            'SELECT for00_descri FROM cadfor00 WHERE for00_codigo = ? LIMIT 1',
            [detalhe.codfab],
          );
          if (fabRows.isNotEmpty) {
            fabDescri = fabRows.first['for00_descri']?.toString();
          }
        }
      } catch (_) {}

      return detalhe.toProdutoResultStruct(
        precoVenda: precoVenda,
        fotos: fotosEncontradas,
        marcaDescri: marcaDescri,
        fabricanteDescri: fabDescri,
      );
    }
  } catch (e) {
    print('Erro em carregarProdutoDetalhe: $e');
  }
  return null;
}
