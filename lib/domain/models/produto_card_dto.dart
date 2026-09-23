import '/backend/schema/structs/index.dart';

/// DTO leve para exibição no card de pesquisa e scroll infinito (SPEC-052).
/// Contém estritamente os campos necessários para renderização visual rápida.
class ProdutoCardDTO {
  final int codigo;
  final String descricao;
  final String unidade;
  final String? codbar;
  final int? codimg;
  final double qtdest;
  final double preco;

  const ProdutoCardDTO({
    required this.codigo,
    required this.descricao,
    required this.unidade,
    this.codbar,
    this.codimg,
    required this.qtdest,
    this.preco = 0.0,
  });

  factory ProdutoCardDTO.fromMap(Map<String, dynamic> map) {
    int parseCod(dynamic val) {
      if (val == null) return 0;
      if (val is num) return val.toInt();
      return int.tryParse(val.toString()) ?? 0;
    }

    double parseQtd(dynamic val) {
      if (val == null) return 0.0;
      if (val is num) return val.toDouble();
      return double.tryParse(val.toString()) ?? 0.0;
    }

    double parsePreco(dynamic val) {
      if (val == null) return 0.0;
      if (val is num) return val.toDouble();
      return double.tryParse(val.toString()) ?? 0.0;
    }

    int? parseImg(dynamic val) {
      if (val == null) return null;
      if (val is num) return val.toInt();
      return int.tryParse(val.toString());
    }

    return ProdutoCardDTO(
      codigo: parseCod(map['pro00_codigo'] ?? map['codigo']),
      descricao: map['pro00_descri']?.toString() ?? map['descricao']?.toString() ?? '',
      unidade: map['pro00_unidad']?.toString() ?? map['unidade']?.toString() ?? 'UN',
      codbar: map['pro00_codbar']?.toString() ?? map['codbar']?.toString(),
      codimg: parseImg(map['pro00_codimg'] ?? map['codimg']),
      qtdest: parseQtd(map['pro00_qtdest'] ?? map['qtdest']),
      preco: parsePreco(map['pro00_pcomax'] ?? map['preco'] ?? map['pro00_preco']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'pro00_codigo': codigo,
      'pro00_descri': descricao,
      'pro00_unidad': unidade,
      'pro00_codbar': codbar,
      'pro00_codimg': codimg,
      'pro00_qtdest': qtdest,
      'pro00_pcomax': preco,
    };
  }

  /// Converte para ProdutoResultStruct para manter compatibilidade com widgets legados
  ProdutoResultStruct toProdutoResultStruct() {
    return ProdutoResultStruct(
      codigo: codigo.toString(),
      descricao: descricao,
      unidade: unidade,
      codbar: codbar ?? '',
      preco: preco,
      pcomax: preco,
      saldoEstoque: qtdest,
      estoqueAtual: qtdest,
      estoquePendente: 0.0,
      imagemId: codimg ?? 0,
      embalagem: unidade,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProdutoCardDTO &&
          runtimeType == other.runtimeType &&
          codigo == other.codigo &&
          descricao == other.descricao &&
          unidade == other.unidade &&
          codbar == other.codbar &&
          codimg == other.codimg &&
          qtdest == other.qtdest &&
          preco == other.preco;

  @override
  int get hashCode =>
      codigo.hashCode ^
      descricao.hashCode ^
      unidade.hashCode ^
      codbar.hashCode ^
      codimg.hashCode ^
      qtdest.hashCode ^
      preco.hashCode;

  @override
  String toString() =>
      'ProdutoCardDTO(codigo: $codigo, descricao: $descricao, unidade: $unidade, qtdest: $qtdest, preco: $preco)';
}
