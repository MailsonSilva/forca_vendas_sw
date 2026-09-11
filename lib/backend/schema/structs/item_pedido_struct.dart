// ignore_for_file: unnecessary_getters_setters

import '/backend/schema/util/schema_util.dart';

import 'index.dart';
import '/core/app_util.dart';

/// DSL struct ItemPedido
class ItemPedidoStruct extends BaseStruct {
  ItemPedidoStruct({
    /// ItemPedido.codigo_produto
    String? codigoProduto,

    /// ItemPedido.descricao
    String? descricao,

    /// ItemPedido.unidade
    String? unidade,

    /// ItemPedido.preco_unitario
    double? precoUnitario,

    /// ItemPedido.quantidade
    double? quantidade,

    /// ItemPedido.total_item
    double? totalItem,

    /// ItemPedido.is_bonificacao
    bool? isBonificacao,

    /// ItemPedido.quantidade_bonificada
    double? quantidadeBonificada,

    /// ItemPedido.codigo_combo
    String? codigoCombo,

    // Fase A2 — PRD dig01_*: embalagem/mulver (compat: defaults 1.0/vazio)
    double? mulver,
    double? unidadeComercial,
    String? embalagem,
    // Atributos de Identificação Comercial (EAN, Marca, Referência)
    String? marca,
    String? referencia,
    String? codbar,
  })  : _codigoProduto = codigoProduto,
        _descricao = descricao,
        _unidade = unidade,
        _precoUnitario = precoUnitario,
        _quantidade = quantidade,
        _totalItem = totalItem,
        _isBonificacao = isBonificacao,
        _quantidadeBonificada = quantidadeBonificada,
        _codigoCombo = codigoCombo,
        _mulver = mulver,
        _unidadeComercial = unidadeComercial,
        _embalagem = embalagem,
        _marca = marca,
        _referencia = referencia,
        _codbar = codbar;

  // "codigo_produto" field.
  String? _codigoProduto;
  String get codigoProduto => _codigoProduto ?? '';
  set codigoProduto(String? val) => _codigoProduto = val;

  bool hasCodigoProduto() => _codigoProduto != null;

  // "descricao" field.
  String? _descricao;
  String get descricao => _descricao ?? '';
  set descricao(String? val) => _descricao = val;

  bool hasDescricao() => _descricao != null;

  // "unidade" field.
  String? _unidade;
  String get unidade => _unidade ?? '';
  set unidade(String? val) => _unidade = val;

  bool hasUnidade() => _unidade != null;

  // "preco_unitario" field.
  double? _precoUnitario;
  double get precoUnitario => _precoUnitario ?? 0.0;
  set precoUnitario(double? val) => _precoUnitario = val;

  void incrementPrecoUnitario(double amount) =>
      precoUnitario = precoUnitario + amount;

  bool hasPrecoUnitario() => _precoUnitario != null;

  // "quantidade" field.
  double? _quantidade;
  double get quantidade => _quantidade ?? 0.0;
  set quantidade(double? val) => _quantidade = val;

  void incrementQuantidade(double amount) => quantidade = quantidade + amount;

  bool hasQuantidade() => _quantidade != null;

  // "total_item" field.
  double? _totalItem;
  double get totalItem => _totalItem ?? 0.0;
  set totalItem(double? val) => _totalItem = val;

  void incrementTotalItem(double amount) => totalItem = totalItem + amount;

  bool hasTotalItem() => _totalItem != null;

  // "is_bonificacao" field.
  bool? _isBonificacao;
  bool get isBonificacao => _isBonificacao ?? false;
  set isBonificacao(bool? val) => _isBonificacao = val;

  bool hasIsBonificacao() => _isBonificacao != null;

  // "quantidade_bonificada" field.
  double? _quantidadeBonificada;
  double get quantidadeBonificada => _quantidadeBonificada ?? 0.0;
  set quantidadeBonificada(double? val) => _quantidadeBonificada = val;

  bool hasQuantidadeBonificada() => _quantidadeBonificada != null;

  // "codigo_combo" field.
  String? _codigoCombo;
  String get codigoCombo => _codigoCombo ?? '';
  set codigoCombo(String? val) => _codigoCombo = val;

  bool hasCodigoCombo() => _codigoCombo != null;

  // "mulver" field — PRD pro00_mulver / cadproemb02.
  double? _mulver;
  double get mulver => _mulver ?? 1.0;
  set mulver(double? val) => _mulver = val;
  bool hasMulver() => _mulver != null;

  // "unidade_comercial" field — PRD pro00_unidade = txtqtd * mulver.
  double? _unidadeComercial;
  double get unidadeComercial => _unidadeComercial ?? quantidade;
  set unidadeComercial(double? val) => _unidadeComercial = val;
  bool hasUnidadeComercial() => _unidadeComercial != null;

  // "embalagem" field — índice cadproemb02.
  String? _embalagem;
  String get embalagem => _embalagem ?? '';
  set embalagem(String? val) => _embalagem = val;
  bool hasEmbalagem() => _embalagem != null;

  // "marca" field.
  String? _marca;
  String get marca => _marca ?? '';
  set marca(String? val) => _marca = val;
  bool hasMarca() => _marca != null;

  // "referencia" field.
  String? _referencia;
  String get referencia => _referencia ?? '';
  set referencia(String? val) => _referencia = val;
  bool hasReferencia() => _referencia != null;

  // "codbar" field.
  String? _codbar;
  String get codbar => _codbar ?? '';
  set codbar(String? val) => _codbar = val;
  bool hasCodbar() => _codbar != null;

  static ItemPedidoStruct fromMap(Map<String, dynamic> data) =>
      ItemPedidoStruct(
        codigoProduto: data['codigo_produto'] as String?,
        descricao: data['descricao'] as String?,
        unidade: data['unidade'] as String?,
        precoUnitario: castToType<double>(data['preco_unitario']),
        quantidade: castToType<double>(data['quantidade']),
        totalItem: castToType<double>(data['total_item']),
        isBonificacao: data['is_bonificacao'] as bool?,
        quantidadeBonificada: castToType<double>(data['quantidade_bonificada']),
        codigoCombo: data['codigo_combo'] as String?,
        mulver: castToType<double>(data['mulver']),
        unidadeComercial: castToType<double>(data['unidade_comercial']),
        embalagem: data['embalagem'] as String?,
        marca: data['marca'] as String?,
        referencia: data['referencia'] as String?,
        codbar: data['codbar'] as String?,
      );

  static ItemPedidoStruct? maybeFromMap(dynamic data) => data is Map
      ? ItemPedidoStruct.fromMap(data.cast<String, dynamic>())
      : null;

  Map<String, dynamic> toMap() => {
        'codigo_produto': _codigoProduto,
        'descricao': _descricao,
        'unidade': _unidade,
        'preco_unitario': _precoUnitario,
        'quantidade': _quantidade,
        'total_item': _totalItem,
        'is_bonificacao': _isBonificacao,
        'quantidade_bonificada': _quantidadeBonificada,
        'codigo_combo': _codigoCombo,
        'mulver': _mulver,
        'unidade_comercial': _unidadeComercial,
        'embalagem': _embalagem,
        'marca': _marca,
        'referencia': _referencia,
        'codbar': _codbar,
      }.withoutNulls;

  @override
  Map<String, dynamic> toSerializableMap() => {
        'codigo_produto': serializeParam(
          _codigoProduto,
          ParamType.String,
        ),
        'descricao': serializeParam(
          _descricao,
          ParamType.String,
        ),
        'unidade': serializeParam(
          _unidade,
          ParamType.String,
        ),
        'preco_unitario': serializeParam(
          _precoUnitario,
          ParamType.double,
        ),
        'quantidade': serializeParam(
          _quantidade,
          ParamType.double,
        ),
        'total_item': serializeParam(
          _totalItem,
          ParamType.double,
        ),
        'is_bonificacao': serializeParam(
          _isBonificacao,
          ParamType.bool,
        ),
        'quantidade_bonificada': serializeParam(
          _quantidadeBonificada,
          ParamType.double,
        ),
        'codigo_combo': serializeParam(
          _codigoCombo,
          ParamType.String,
        ),
        'mulver': serializeParam(
          _mulver,
          ParamType.double,
        ),
        'unidade_comercial': serializeParam(
          _unidadeComercial,
          ParamType.double,
        ),
        'embalagem': serializeParam(
          _embalagem,
          ParamType.String,
        ),
      }.withoutNulls;

  static ItemPedidoStruct fromSerializableMap(Map<String, dynamic> data) =>
      ItemPedidoStruct(
        codigoProduto: deserializeParam(
          data['codigo_produto'],
          ParamType.String,
          false,
        ),
        descricao: deserializeParam(
          data['descricao'],
          ParamType.String,
          false,
        ),
        unidade: deserializeParam(
          data['unidade'],
          ParamType.String,
          false,
        ),
        precoUnitario: deserializeParam(
          data['preco_unitario'],
          ParamType.double,
          false,
        ),
        quantidade: deserializeParam(
          data['quantidade'],
          ParamType.double,
          false,
        ),
        totalItem: deserializeParam(
          data['total_item'],
          ParamType.double,
          false,
        ),
        isBonificacao: deserializeParam(
          data['is_bonificacao'],
          ParamType.bool,
          false,
        ),
        quantidadeBonificada: deserializeParam(
          data['quantidade_bonificada'],
          ParamType.double,
          false,
        ),
        codigoCombo: deserializeParam(
          data['codigo_combo'],
          ParamType.String,
          false,
        ),
        mulver: deserializeParam(
          data['mulver'],
          ParamType.double,
          false,
        ),
        unidadeComercial: deserializeParam(
          data['unidade_comercial'],
          ParamType.double,
          false,
        ),
        embalagem: deserializeParam(
          data['embalagem'],
          ParamType.String,
          false,
        ),
      );

  @override
  String toString() => 'ItemPedidoStruct(${toMap()})';

  @override
  bool operator ==(Object other) {
    return other is ItemPedidoStruct &&
        codigoProduto == other.codigoProduto &&
        descricao == other.descricao &&
        unidade == other.unidade &&
        precoUnitario == other.precoUnitario &&
        quantidade == other.quantidade &&
        totalItem == other.totalItem &&
        isBonificacao == other.isBonificacao &&
        quantidadeBonificada == other.quantidadeBonificada &&
        codigoCombo == other.codigoCombo &&
        mulver == other.mulver &&
        unidadeComercial == other.unidadeComercial &&
        embalagem == other.embalagem;
  }

  @override
  int get hashCode => const ListEquality().hash([
        codigoProduto,
        descricao,
        unidade,
        precoUnitario,
        quantidade,
        totalItem,
        isBonificacao,
        quantidadeBonificada,
        codigoCombo,
        mulver,
        unidadeComercial,
        embalagem
      ]);
}

ItemPedidoStruct createItemPedidoStruct({
  String? codigoProduto,
  String? descricao,
  String? unidade,
  double? precoUnitario,
  double? quantidade,
  double? totalItem,
  bool? isBonificacao,
  double? quantidadeBonificada,
  String? codigoCombo,
  double? mulver,
  double? unidadeComercial,
  String? embalagem,
  String? marca,
  String? referencia,
  String? codbar,
}) =>
    ItemPedidoStruct(
      codigoProduto: codigoProduto,
      descricao: descricao,
      unidade: unidade,
      precoUnitario: precoUnitario,
      quantidade: quantidade,
      totalItem: totalItem,
      isBonificacao: isBonificacao,
      quantidadeBonificada: quantidadeBonificada,
      codigoCombo: codigoCombo,
      mulver: mulver,
      unidadeComercial: unidadeComercial,
      embalagem: embalagem,
      marca: marca,
      referencia: referencia,
      codbar: codbar,
    );
