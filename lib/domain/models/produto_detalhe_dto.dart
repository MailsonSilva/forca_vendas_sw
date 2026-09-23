import '/backend/schema/structs/index.dart';

/// DTO detalhado completo de produto (Query 2 / Tcadpro00::cload de usysctr00.cpp).
/// Carregado sob demanda estritamente ao selecionar um produto.
class ProdutoDetalheDTO {
  final int codigo;
  final String? codbar;
  final String descricao;
  final String? deslon;
  final String unidade;
  final int? codimg;
  final String? embalagem;
  final int? indfra;
  final double? peso;
  final int? codfab;
  final int? codmar;
  final int? codgrp;
  final int? codsgr;
  final int? coddep;
  final int? codsec;
  final int? codlin;
  final int? codtrb;
  final double? pesbru;
  final double? pesliq;
  final String? defbon;
  final String? defbonven;
  final String? entdat;
  final String? prifil;
  final double qtdest;
  final int mulemb;
  final double mulven;

  const ProdutoDetalheDTO({
    required this.codigo,
    this.codbar,
    required this.descricao,
    this.deslon,
    required this.unidade,
    this.codimg,
    this.embalagem,
    this.indfra,
    this.peso,
    this.codfab,
    this.codmar,
    this.codgrp,
    this.codsgr,
    this.coddep,
    this.codsec,
    this.codlin,
    this.codtrb,
    this.pesbru,
    this.pesliq,
    this.defbon,
    this.defbonven,
    this.entdat,
    this.prifil,
    required this.qtdest,
    required this.mulemb,
    required this.mulven,
  });

  factory ProdutoDetalheDTO.fromMap(Map<String, dynamic> map) {
    double parseDouble(dynamic value, [double def = 0.0]) {
      if (value == null) return def;
      if (value is num) return value.toDouble();
      return double.tryParse(value.toString()) ?? def;
    }

    double? parseOptionalDouble(dynamic value) {
      if (value == null) return null;
      if (value is num) return value.toDouble();
      return double.tryParse(value.toString());
    }

    int parseInt(dynamic value, [int def = 0]) {
      if (value == null) return def;
      if (value is int) return value;
      if (value is num) return value.toInt();
      return int.tryParse(value.toString()) ?? def;
    }

    int? parseOptionalInt(dynamic value) {
      if (value == null) return null;
      if (value is int) return value;
      if (value is num) return value.toInt();
      return int.tryParse(value.toString());
    }

    return ProdutoDetalheDTO(
      codigo: parseInt(map['pro00_codigo'] ?? map['codigo']),
      codbar: map['pro00_codbar']?.toString(),
      descricao: (map['pro00_descri'] ?? map['descricao'] ?? '').toString(),
      deslon: map['pro00_deslon']?.toString(),
      unidade: (map['pro00_unidad'] ?? map['unidade'] ?? 'UN').toString(),
      codimg: parseOptionalInt(map['pro00_codimg'] ?? map['codimg']),
      embalagem: map['emb00_embala']?.toString() ?? map['embalagem']?.toString(),
      indfra: parseOptionalInt(map['fra00_indfra'] ?? map['indfra']),
      peso: parseOptionalDouble(map['fra00_peso'] ?? map['peso']),
      codfab: parseOptionalInt(map['pro00_codfab'] ?? map['codfab']),
      codmar: parseOptionalInt(map['pro00_codmar'] ?? map['codmar']),
      codgrp: parseOptionalInt(map['pro00_codgrp'] ?? map['codgrp']),
      codsgr: parseOptionalInt(map['pro00_codsgr'] ?? map['codsgr']),
      coddep: parseOptionalInt(map['pro00_coddep'] ?? map['coddep']),
      codsec: parseOptionalInt(map['pro00_codsec'] ?? map['codsec']),
      codlin: parseOptionalInt(map['pro00_codlin'] ?? map['codlin']),
      codtrb: parseOptionalInt(map['pro00_codtrb'] ?? map['codtrb']),
      pesbru: parseOptionalDouble(map['pro00_pesbru'] ?? map['pesbru']),
      pesliq: parseOptionalDouble(map['pro00_pesliq'] ?? map['pesliq']),
      defbon: map['bon00_defbon']?.toString(),
      defbonven: map['bon00_defbonven']?.toString(),
      entdat: map['pro00_entdat']?.toString() ?? map['entdat']?.toString(),
      prifil: map['pro00_prifil']?.toString() ?? map['prifil']?.toString(),
      qtdest: parseDouble(map['pro00_qtdest'] ?? map['qtdest'], 0.0),
      mulemb: parseInt(map['pro02_mulemb'] ?? map['mulemb'], 1),
      mulven: parseDouble(map['pro02_mulven'] ?? map['mulven'], 1.0),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'pro00_codigo': codigo,
      'pro00_codbar': codbar,
      'pro00_descri': descricao,
      'pro00_deslon': deslon,
      'pro00_unidad': unidade,
      'pro00_codimg': codimg,
      'emb00_embala': embalagem,
      'fra00_indfra': indfra,
      'fra00_peso': peso,
      'pro00_codfab': codfab,
      'pro00_codmar': codmar,
      'pro00_codgrp': codgrp,
      'pro00_codsgr': codsgr,
      'pro00_coddep': coddep,
      'pro00_codsec': codsec,
      'pro00_codlin': codlin,
      'pro00_codtrb': codtrb,
      'pro00_pesbru': pesbru,
      'pro00_pesliq': pesliq,
      'bon00_defbon': defbon,
      'bon00_defbonven': defbonven,
      'pro00_entdat': entdat,
      'pro00_prifil': prifil,
      'pro00_qtdest': qtdest,
      'pro02_mulemb': mulemb,
      'pro02_mulven': mulven,
    };
  }

  /// Converte para ProdutoResultStruct preservando compatibilidade com formulários de pedido e detalhes
  ProdutoResultStruct toProdutoResultStruct({
    double precoVenda = 0.0,
    List<String>? fotos,
    String? marcaDescri,
    String? fabricanteDescri,
  }) {
    return ProdutoResultStruct(
      codigo: codigo.toString(),
      descricao: descricao,
      unidade: unidade,
      preco: precoVenda,
      saldoEstoque: qtdest,
      estoqueAtual: qtdest,
      estoquePendente: 0.0,
      linha: codlin?.toString() ?? '',
      grupo: codgrp?.toString() ?? '',
      fabricante: fabricanteDescri ?? codfab?.toString() ?? '',
      marca: marcaDescri ?? codmar?.toString() ?? 'SEM MARCA',
      codbar: codbar ?? '',
      fotosProduto: fotos ?? const [],
      mulver: mulven > 0 ? mulven : 1.0,
      codtrb: codtrb ?? 0,
      embalagem: (embalagem != null && embalagem!.trim().isNotEmpty) ? embalagem! : unidade,
      imagemId: codimg ?? 0,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProdutoDetalheDTO &&
          runtimeType == other.runtimeType &&
          codigo == other.codigo &&
          codbar == other.codbar &&
          descricao == other.descricao &&
          unidade == other.unidade &&
          qtdest == other.qtdest &&
          mulemb == other.mulemb &&
          mulven == other.mulven;

  @override
  int get hashCode =>
      codigo.hashCode ^
      (codbar?.hashCode ?? 0) ^
      descricao.hashCode ^
      unidade.hashCode ^
      qtdest.hashCode ^
      mulemb.hashCode ^
      mulven.hashCode;

  @override
  String toString() =>
      'ProdutoDetalheDTO(codigo: $codigo, descricao: $descricao, saldo: $qtdest, mulemb: $mulemb, mulven: $mulven)';
}
