// ignore_for_file: unnecessary_getters_setters

import '/backend/schema/util/schema_util.dart';

import 'index.dart';
import '/core/app_util.dart';

/// DSL struct ProdutoResult
class ProdutoResultStruct extends BaseStruct {
  ProdutoResultStruct({
    /// ProdutoResult.codigo
    String? codigo,

    /// ProdutoResult.descricao
    String? descricao,

    /// ProdutoResult.unidade
    String? unidade,

    /// ProdutoResult.preco
    double? preco,

    /// ProdutoResult.saldo_estoque
    double? saldoEstoque,

    /// ProdutoResult.preco_custo
    double? precoCusto,
    double? estoqueAtual,
    double? estoquePendente,
    String? linha,
    String? grupo,
    String? fabricante,
    String? marca,
    String? codbar,
    List<String>? fotosProduto,
  })  : _codigo = codigo,
        _descricao = descricao,
        _unidade = unidade,
        _preco = preco,
        _saldoEstoque = saldoEstoque,
        _precoCusto = precoCusto,
        _estoqueAtual = estoqueAtual,
        _estoquePendente = estoquePendente,
        _linha = linha,
        _grupo = grupo,
        _fabricante = fabricante,
        _marca = marca,
        _codbar = codbar,
        _fotosProduto = fotosProduto;

  // "codigo" field.
  String? _codigo;
  String get codigo => _codigo ?? '';
  set codigo(String? val) => _codigo = val;

  bool hasCodigo() => _codigo != null;

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

  // "preco" field.
  double? _preco;
  double get preco => _preco ?? 0.0;
  set preco(double? val) => _preco = val;

  void incrementPreco(double amount) => preco = preco + amount;

  bool hasPreco() => _preco != null;

  // "saldo_estoque" field.
  double? _saldoEstoque;
  double get saldoEstoque => _saldoEstoque ?? 0.0;
  set saldoEstoque(double? val) => _saldoEstoque = val;

  void incrementSaldoEstoque(double amount) =>
      saldoEstoque = saldoEstoque + amount;

  bool hasSaldoEstoque() => _saldoEstoque != null;

  // "preco_custo" field.
  double? _precoCusto;
  double get precoCusto => _precoCusto ?? 0.0;
  set precoCusto(double? val) => _precoCusto = val;

  void incrementPrecoCusto(double amount) => precoCusto = precoCusto + amount;

  bool hasPrecoCusto() => _precoCusto != null;

  // "estoque_atual" field.
  double? _estoqueAtual;
  double get estoqueAtual => _estoqueAtual ?? 0.0;
  set estoqueAtual(double? val) => _estoqueAtual = val;

  void incrementEstoqueAtual(double amount) =>
      estoqueAtual = estoqueAtual + amount;

  bool hasEstoqueAtual() => _estoqueAtual != null;

  // "estoque_pendente" field.
  double? _estoquePendente;
  double get estoquePendente => _estoquePendente ?? 0.0;
  set estoquePendente(double? val) => _estoquePendente = val;

  void incrementEstoquePendente(double amount) =>
      estoquePendente = estoquePendente + amount;

  bool hasEstoquePendente() => _estoquePendente != null;

  // "linha" field.
  String? _linha;
  String get linha => _linha ?? '';
  set linha(String? val) => _linha = val;

  bool hasLinha() => _linha != null;

  // "grupo" field.
  String? _grupo;
  String get grupo => _grupo ?? '';
  set grupo(String? val) => _grupo = val;

  bool hasGrupo() => _grupo != null;

  // "fabricante" field.
  String? _fabricante;
  String get fabricante => _fabricante ?? '';
  set fabricante(String? val) => _fabricante = val;

  bool hasFabricante() => _fabricante != null;

  // "marca" field.
  String? _marca;
  String get marca => _marca ?? '';
  set marca(String? val) => _marca = val;

  bool hasMarca() => _marca != null;

  // "codbar" field.
  String? _codbar;
  String get codbar => _codbar ?? '';
  set codbar(String? val) => _codbar = val;

  bool hasCodbar() => _codbar != null;

  // "fotosProduto" field.
  List<String>? _fotosProduto;
  List<String> get fotosProduto => _fotosProduto ?? const [];
  set fotosProduto(List<String>? val) => _fotosProduto = val;

  void updateFotosProduto(Function(List<String>) updateFn) {
    updateFn(_fotosProduto ??= []);
  }

  bool hasFotosProduto() => _fotosProduto != null;

  static ProdutoResultStruct fromMap(Map<String, dynamic> data) =>
      ProdutoResultStruct(
        codigo: data['codigo'] as String?,
        descricao: data['descricao'] as String?,
        unidade: data['unidade'] as String?,
        preco: castToType<double>(data['preco']),
        saldoEstoque: castToType<double>(data['saldo_estoque']),
        precoCusto: castToType<double>(data['preco_custo']),
        estoqueAtual: castToType<double>(data['estoque_atual']),
        estoquePendente: castToType<double>(data['estoque_pendente']),
        linha: data['linha'] as String?,
        grupo: data['grupo'] as String?,
        fabricante: data['fabricante'] as String?,
        marca: data['marca'] as String?,
        codbar: data['codbar'] as String?,
        fotosProduto: getDataList(data['fotosProduto']),
      );

  static ProdutoResultStruct? maybeFromMap(dynamic data) => data is Map
      ? ProdutoResultStruct.fromMap(data.cast<String, dynamic>())
      : null;

  Map<String, dynamic> toMap() => {
        'codigo': _codigo,
        'descricao': _descricao,
        'unidade': _unidade,
        'preco': _preco,
        'saldo_estoque': _saldoEstoque,
        'preco_custo': _precoCusto,
        'estoque_atual': _estoqueAtual,
        'estoque_pendente': _estoquePendente,
        'linha': _linha,
        'grupo': _grupo,
        'fabricante': _fabricante,
        'marca': _marca,
        'codbar': _codbar,
        'fotosProduto': _fotosProduto,
      }.withoutNulls;

  @override
  Map<String, dynamic> toSerializableMap() => {
        'codigo': serializeParam(
          _codigo,
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
        'preco': serializeParam(
          _preco,
          ParamType.double,
        ),
        'saldo_estoque': serializeParam(
          _saldoEstoque,
          ParamType.double,
        ),
        'preco_custo': serializeParam(
          _precoCusto,
          ParamType.double,
        ),
        'estoque_atual': serializeParam(
          _estoqueAtual,
          ParamType.double,
        ),
        'estoque_pendente': serializeParam(
          _estoquePendente,
          ParamType.double,
        ),
        'linha': serializeParam(
          _linha,
          ParamType.String,
        ),
        'grupo': serializeParam(
          _grupo,
          ParamType.String,
        ),
        'fabricante': serializeParam(
          _fabricante,
          ParamType.String,
        ),
        'marca': serializeParam(
          _marca,
          ParamType.String,
        ),
        'codbar': serializeParam(
          _codbar,
          ParamType.String,
        ),
        'fotosProduto': serializeParam(
          _fotosProduto,
          ParamType.String,
          isList: true,
        ),
      }.withoutNulls;

  static ProdutoResultStruct fromSerializableMap(Map<String, dynamic> data) =>
      ProdutoResultStruct(
        codigo: deserializeParam(
          data['codigo'],
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
        preco: deserializeParam(
          data['preco'],
          ParamType.double,
          false,
        ),
        saldoEstoque: deserializeParam(
          data['saldo_estoque'],
          ParamType.double,
          false,
        ),
        precoCusto: deserializeParam(
          data['preco_custo'],
          ParamType.double,
          false,
        ),
        estoqueAtual: deserializeParam(
          data['estoque_atual'],
          ParamType.double,
          false,
        ),
        estoquePendente: deserializeParam(
          data['estoque_pendente'],
          ParamType.double,
          false,
        ),
        linha: deserializeParam(
          data['linha'],
          ParamType.String,
          false,
        ),
        grupo: deserializeParam(
          data['grupo'],
          ParamType.String,
          false,
        ),
        fabricante: deserializeParam(
          data['fabricante'],
          ParamType.String,
          false,
        ),
        marca: deserializeParam(
          data['marca'],
          ParamType.String,
          false,
        ),
        codbar: deserializeParam(
          data['codbar'],
          ParamType.String,
          false,
        ),
        fotosProduto: deserializeParam<String>(
          data['fotosProduto'],
          ParamType.String,
          true,
        ),
      );

  @override
  String toString() => 'ProdutoResultStruct(${toMap()})';

  @override
  bool operator ==(Object other) {
    const listEquality = ListEquality();
    return other is ProdutoResultStruct &&
        codigo == other.codigo &&
        descricao == other.descricao &&
        unidade == other.unidade &&
        preco == other.preco &&
        saldoEstoque == other.saldoEstoque &&
        precoCusto == other.precoCusto &&
        estoqueAtual == other.estoqueAtual &&
        estoquePendente == other.estoquePendente &&
        linha == other.linha &&
        grupo == other.grupo &&
        fabricante == other.fabricante &&
        marca == other.marca &&
        codbar == other.codbar &&
        listEquality.equals(fotosProduto, other.fotosProduto);
  }

  @override
  int get hashCode => const ListEquality().hash([
        codigo,
        descricao,
        unidade,
        preco,
        saldoEstoque,
        precoCusto,
        estoqueAtual,
        estoquePendente,
        linha,
        grupo,
        fabricante,
        marca,
        codbar,
        fotosProduto
      ]);
}

ProdutoResultStruct createProdutoResultStruct({
  String? codigo,
  String? descricao,
  String? unidade,
  double? preco,
  double? saldoEstoque,
  double? precoCusto,
  double? estoqueAtual,
  double? estoquePendente,
  String? linha,
  String? grupo,
  String? fabricante,
  String? marca,
  String? codbar,
}) =>
    ProdutoResultStruct(
      codigo: codigo,
      descricao: descricao,
      unidade: unidade,
      preco: preco,
      saldoEstoque: saldoEstoque,
      precoCusto: precoCusto,
      estoqueAtual: estoqueAtual,
      estoquePendente: estoquePendente,
      linha: linha,
      grupo: grupo,
      fabricante: fabricante,
      marca: marca,
      codbar: codbar,
    );
