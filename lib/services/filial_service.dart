import 'package:sqflite/sqflite.dart';
import '/action_code/contar_filiais.dart';
import '/backend/schema/structs/lista_padrao_struct.dart';

/// Resultado da avaliação da regra pós-login de filial conforme SPEC-049 §6.
class DecisaoFilialResult {
  const DecisaoFilialResult({
    required this.precisaAbrirModal,
    this.filialDefinida,
    this.filiaisDisponiveis = const [],
  });

  /// Indica se a tela de login deve abrir obrigatoriamente o modal de seleção.
  final bool precisaAbrirModal;

  /// Código da filial definida automaticamente quando [precisaAbrirModal] for false.
  final int? filialDefinida;

  /// Lista de códigos de filiais disponíveis em estoque para seleção no modal.
  final List<String> filiaisDisponiveis;
}

/// Avalia as regras de negócio de filial conforme dados da carga do representante (cadrep00)
/// e filiais com produtos em estoque (estpro00).
DecisaoFilialResult avaliarRegraSelecaoFilial({
  required int venSelfil,
  required int venCodfil,
  required List<String> filiaisEstoque,
}) {
  // Caso A (ven00_selfil == 0): Monofilial travada; define filial ativa sem exibir diálogos
  if (venSelfil == 0) {
    return DecisaoFilialResult(
      precisaAbrirModal: false,
      filialDefinida: venCodfil > 0 ? venCodfil : 1,
    );
  }

  // Caso B (ven00_selfil == 1): Permite seleção de filiais se houver >= 2 filiais em estoque
  if (filiaisEstoque.length >= 2) {
    return DecisaoFilialResult(
      precisaAbrirModal: true,
      filiaisDisponiveis: filiaisEstoque,
    );
  } else if (filiaisEstoque.length == 1) {
    final cod = int.tryParse(filiaisEstoque.first) ?? venCodfil;
    return DecisaoFilialResult(
      precisaAbrirModal: false,
      filialDefinida: cod > 0 ? cod : 1,
      filiaisDisponiveis: filiaisEstoque,
    );
  } else {
    // Nenhuma filial em estpro00, usa a filial padrão do representante
    return DecisaoFilialResult(
      precisaAbrirModal: false,
      filialDefinida: venCodfil > 0 ? venCodfil : 1,
    );
  }
}

/// Helper para auto-seleção de Linha de Produtos no início do pedido (SPEC-049 §4.1).
/// Se a lista contiver exatamente 1 registro, seleciona-o automaticamente.
ListaPadraoStruct? autoSelecionarLinhaSeUnica(List<ListaPadraoStruct> linhas) {
  if (linhas.length == 1) {
    return linhas.first;
  }
  return null;
}

/// Serviço de consulta e resolução de filiais no SQLite.
class FilialService {
  /// Consulta filiais distintas no estoque:
  /// `SELECT DISTINCT pro00_codfil FROM estpro00 ORDER BY pro00_codfil ASC;`
  static Future<List<String>> obterFiliaisDistintasEstoque(Database db) async {
    try {
      final t = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND lower(name)='estpro00'",
      );
      if (t.isEmpty) return [];

      final rows = await db.rawQuery(
        'SELECT DISTINCT pro00_codfil FROM estpro00 WHERE pro00_codfil IS NOT NULL AND pro00_codfil != "" ORDER BY pro00_codfil ASC',
      );

      final List<String> list = [];
      for (final r in rows) {
        final val = r['pro00_codfil']?.toString().trim();
        if (val != null && val.isNotEmpty && !list.contains(val)) {
          list.add(val);
        }
      }
      return list;
    } catch (_) {
      return [];
    }
  }

  /// Recupera a lista de [FilialInfo] para exibição no modal buscando a descrição em cadfil00.
  static Future<List<FilialInfo>> obterFiliaisComDescricao(
    Database db,
    List<String> codigos,
  ) async {
    return obterFiliaisComDescricaoQuery(db, codigos);
  }

  /// Recupera a lista de [FilialInfo] para exibição no modal buscando a descrição em cadfil00
  /// conforme query estrita do legado:
  /// `SELECT fil00_codigo, COALESCE(fil00_descri, 'Filial ' || fil00_codigo) AS fil00_descri FROM cadfil00`
  /// com fallback para `cadace00` ou `cadrep00`.
  static Future<List<FilialInfo>> obterFiliaisComDescricaoQuery(
    Database db,
    List<String> codigos,
  ) async {
    final Map<String, String> descricoes = {};

    // 1. Tenta buscar em cadfil00 com query exata
    try {
      final tFil = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND lower(name)='cadfil00'",
      );
      if (tFil.isNotEmpty) {
        final cols = await db.rawQuery('PRAGMA table_info(cadfil00)');
        final colNames = cols.map((r) => r['name']?.toString().toLowerCase()).toSet();

        String codCol = 'fil00_codigo';
        if (!colNames.contains('fil00_codigo') && colNames.contains('fil00_codfil')) {
          codCol = 'fil00_codfil';
        }

        String descCol = 'fil00_descri';
        if (!colNames.contains('fil00_descri') && colNames.contains('fil00_descricao')) {
          descCol = 'fil00_descricao';
        }

        final rows = await db.rawQuery(
          "SELECT $codCol AS fil00_codigo, COALESCE($descCol, 'Filial ' || $codCol) AS fil00_descri FROM cadfil00",
        );
        for (final r in rows) {
          final c = r['fil00_codigo']?.toString().trim() ?? '';
          final d = r['fil00_descri']?.toString().trim() ?? '';
          if (c.isNotEmpty && d.isNotEmpty) {
            descricoes[c] = d;
            final intVal = int.tryParse(c);
            if (intVal != null) descricoes[intVal.toString()] = d;
          }
        }
      }
    } catch (_) {}

    // 2. Fallback de descrição para cadace00 (srv00_descri) ou cadrep00 (ven00_empresa / ven00_nomfil)
    String fallbackDesc = '';
    try {
      final tAce = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND lower(name)='cadace00'",
      );
      if (tAce.isNotEmpty) {
        final rowsAce = await db.rawQuery(
          "SELECT srv00_descri FROM cadace00 WHERE srv00_descri IS NOT NULL AND TRIM(srv00_descri) != '' LIMIT 1",
        );
        if (rowsAce.isNotEmpty) {
          fallbackDesc = rowsAce.first['srv00_descri']?.toString().trim() ?? '';
        }
      }
    } catch (_) {}

    if (fallbackDesc.isEmpty) {
      try {
        final tRep = await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND lower(name)='cadrep00'",
        );
        if (tRep.isNotEmpty) {
          final colsRep = await db.rawQuery('PRAGMA table_info(cadrep00)');
          final cn = colsRep.map((r) => r['name']?.toString().toLowerCase()).toSet();
          String? repCol;
          if (cn.contains('ven00_empresa')) repCol = 'ven00_empresa';
          else if (cn.contains('ven00_nomfil')) repCol = 'ven00_nomfil';
          else if (cn.contains('rep00_empresa')) repCol = 'rep00_empresa';

          if (repCol != null) {
            final rowsRep = await db.rawQuery(
              "SELECT $repCol AS d FROM cadrep00 WHERE $repCol IS NOT NULL AND TRIM($repCol) != '' LIMIT 1",
            );
            if (rowsRep.isNotEmpty) {
              fallbackDesc = rowsRep.first['d']?.toString().trim() ?? '';
            }
          }
        }
      } catch (_) {}
    }

    return codigos.map((cod) {
      final intCod = int.tryParse(cod);
      final desc = descricoes[cod] ??
          (intCod != null ? descricoes[intCod.toString()] : null) ??
          (fallbackDesc.isNotEmpty ? fallbackDesc : 'Filial $cod');
      return FilialInfo(codigo: cod, descricao: desc);
    }).toList();
  }
}
