/// DTO de produto para busca e seleção no catálogo e digitação de pedidos.
/// Especificação: 00_ESPECIFICACAO_PESQUISA_PRODUTOS_EAN_MARCA_REFERENCIA.md
class ProdutoLookupDTO {
  final int id;
  final String descricao;
  final String? ean;
  final String marca;
  final String? referencia1;
  final String? referencia2;
  final String? fabricante;
  final String embalagem;
  final String unidade;
  final double estoqueSaldo;
  final double precoTabela;
  final int? imagemId;

  const ProdutoLookupDTO({
    required this.id,
    required this.descricao,
    this.ean,
    required this.marca,
    this.referencia1,
    this.referencia2,
    this.fabricante,
    required this.embalagem,
    required this.unidade,
    required this.estoqueSaldo,
    required this.precoTabela,
    this.imagemId,
  });

  /// Formatação legível da referência para exibição na UI
  String get referenciaFormatada {
    final refs = <String>[];
    if (referencia1 != null && referencia1!.trim().isNotEmpty) {
      refs.add(referencia1!.trim());
    }
    if (referencia2 != null && referencia2!.trim().isNotEmpty) {
      refs.add(referencia2!.trim());
    }
    return refs.isNotEmpty ? refs.join(' / ') : 'N/A';
  }

  factory ProdutoLookupDTO.fromMap(Map<String, dynamic> map) {
    double parseDouble(dynamic value) {
      if (value == null) return 0.0;
      if (value is num) return value.toDouble();
      return double.tryParse(value.toString()) ?? 0.0;
    }

    int parseInt(dynamic value) {
      if (value == null) return 0;
      if (value is int) return value;
      if (value is num) return value.toInt();
      return int.tryParse(value.toString()) ?? 0;
    }

    int? parseOptionalInt(dynamic value) {
      if (value == null) return null;
      if (value is int) return value;
      if (value is num) return value.toInt();
      return int.tryParse(value.toString());
    }

    return ProdutoLookupDTO(
      id: parseInt(map['produto_id'] ?? map['pro00_codigo'] ?? map['id']),
      descricao: (map['descricao'] ?? map['pro00_descri'] ?? '').toString(),
      ean: map['ean']?.toString() ?? map['pro00_codbar']?.toString(),
      marca: (map['marca_nome'] ?? map['marca'] ?? map['mar00_descri'] ?? 'SEM MARCA').toString(),
      referencia1: map['referencia_1']?.toString() ?? map['pro00_ref001']?.toString(),
      referencia2: map['referencia_2']?.toString() ?? map['pro00_ref002']?.toString(),
      fabricante: map['fabricante_nome']?.toString() ?? map['fabricante'] ?? map['for00_descri']?.toString(),
      embalagem: (map['embalagem'] ?? map['pro00_embala'] ?? map['unidade'] ?? 'UN').toString(),
      unidade: (map['unidade'] ?? map['pro00_unidad'] ?? 'UN').toString(),
      estoqueSaldo: parseDouble(map['estoque_saldo'] ?? map['pro00_qtdest'] ?? map['saldo']),
      precoTabela: parseDouble(map['preco_tabela'] ?? map['preco_venda'] ?? map['pro00_preco']),
      imagemId: parseOptionalInt(map['imagem_id'] ?? map['pro00_codimg']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'produto_id': id,
      'descricao': descricao,
      'ean': ean,
      'marca_nome': marca,
      'referencia_1': referencia1,
      'referencia_2': referencia2,
      'fabricante_nome': fabricante,
      'embalagem': embalagem,
      'unidade': unidade,
      'estoque_saldo': estoqueSaldo,
      'preco_tabela': precoTabela,
      'imagem_id': imagemId,
    };
  }

  ProdutoLookupDTO copyWith({
    int? id,
    String? descricao,
    String? ean,
    String? marca,
    String? referencia1,
    String? referencia2,
    String? fabricante,
    String? embalagem,
    String? unidade,
    double? estoqueSaldo,
    double? precoTabela,
    int? imagemId,
  }) {
    return ProdutoLookupDTO(
      id: id ?? this.id,
      descricao: descricao ?? this.descricao,
      ean: ean ?? this.ean,
      marca: marca ?? this.marca,
      referencia1: referencia1 ?? this.referencia1,
      referencia2: referencia2 ?? this.referencia2,
      fabricante: fabricante ?? this.fabricante,
      embalagem: embalagem ?? this.embalagem,
      unidade: unidade ?? this.unidade,
      estoqueSaldo: estoqueSaldo ?? this.estoqueSaldo,
      precoTabela: precoTabela ?? this.precoTabela,
      imagemId: imagemId ?? this.imagemId,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProdutoLookupDTO &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          descricao == other.descricao &&
          ean == other.ean &&
          marca == other.marca &&
          referencia1 == other.referencia1 &&
          referencia2 == other.referencia2 &&
          fabricante == other.fabricante &&
          embalagem == other.embalagem &&
          unidade == other.unidade &&
          estoqueSaldo == other.estoqueSaldo &&
          precoTabela == other.precoTabela &&
          imagemId == other.imagemId;

  @override
  int get hashCode =>
      id.hashCode ^
      descricao.hashCode ^
      ean.hashCode ^
      marca.hashCode ^
      referencia1.hashCode ^
      referencia2.hashCode ^
      fabricante.hashCode ^
      embalagem.hashCode ^
      unidade.hashCode ^
      estoqueSaldo.hashCode ^
      precoTabela.hashCode ^
      imagemId.hashCode;

  @override
  String toString() =>
      'ProdutoLookupDTO(id: $id, descricao: $descricao, ean: $ean, marca: $marca, ref: $referenciaFormatada)';
}
