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
  final double pcomax;
  final double pcomin;

  const ProdutoCardDTO({
    required this.codigo,
    required this.descricao,
    required this.unidade,
    this.codbar,
    this.codimg,
    required this.qtdest,
    this.preco = 0.0,
    this.pcomax = 0.0,
    this.pcomin = 0.0,
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

    final double precoVal = parsePreco(map['preco_venda'] ?? map['pro00_pcomax'] ?? map['preco']);
    final double pcomaxVal = parsePreco(map['pro00_pcomax'] ?? map['pcomax'] ?? precoVal);
    final double pcominVal = parsePreco(map['pro00_pcomin'] ?? map['pcomin'] ?? precoVal);

    return ProdutoCardDTO(
      codigo: parseCod(map['pro00_codigo'] ?? map['codigo']),
      descricao: map['pro00_descri']?.toString() ?? map['descricao']?.toString() ?? '',
      unidade: map['pro00_unidad']?.toString() ?? map['unidade']?.toString() ?? 'UN',
      codbar: map['pro00_codbar']?.toString() ?? map['codbar']?.toString(),
      codimg: parseImg(map['pro00_codimg'] ?? map['codimg']),
      qtdest: parseQtd(map['pro00_qtdest'] ?? map['qtdest']),
      preco: precoVal,
      pcomax: pcomaxVal > 0 ? pcomaxVal : precoVal,
      pcomin: pcominVal > 0 ? pcominVal : precoVal,
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
      'pro00_pcomax': pcomax > 0 ? pcomax : preco,
      'pro00_pcomin': pcomin > 0 ? pcomin : preco,
      'preco': preco,
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
      pcomax: pcomax > 0 ? pcomax : preco,
      pcomin: pcomin > 0 ? pcomin : preco,
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
          preco == other.preco &&
          pcomax == other.pcomax &&
          pcomin == other.pcomin;

  @override
  int get hashCode =>
      codigo.hashCode ^
      descricao.hashCode ^
      unidade.hashCode ^
      codbar.hashCode ^
      codimg.hashCode ^
      qtdest.hashCode ^
      preco.hashCode ^
      pcomax.hashCode ^
      pcomin.hashCode;

  @override
  String toString() =>
      'ProdutoCardDTO(codigo: $codigo, descricao: $descricao, unidade: $unidade, qtdest: $qtdest, preco: $preco)';
}
