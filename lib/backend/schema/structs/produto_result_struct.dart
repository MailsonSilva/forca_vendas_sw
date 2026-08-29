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
    // Fase A3 — PRD pro00_* (compat defaults)
    double? mulver,
    double? pcomin,
    double? pcomax,
    double? commax,
    int? codtrb,
    bool? freadpco,
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
        _fotosProduto = fotosProduto,
        _mulver = mulver,
        _pcomin = pcomin,
        _pcomax = pcomax,
        _commax = commax,
        _codtrb = codtrb,
        _freadpco = freadpco;

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

  // "mulver" field — PRD pro00_mulver (conversão caixas).
  double? _mulver;
  double get mulver => _mulver ?? 1.0;
  set mulver(double? val) => _mulver = val;
  bool hasMulver() => _mulver != null;

  // "pcomin" field — PRD pro00_pcomin (preço mínimo).
  double? _pcomin;
  double get pcomin => _pcomin ?? 0.0;
  set pcomin(double? val) => _pcomin = val;
  bool hasPcomin() => _pcomin != null;

  // "pcomax" field — PRD pro00_pcomax (preço máximo).
  double? _pcomax;
  double get pcomax => _pcomax ?? 999999.0;
  set pcomax(double? val) => _pcomax = val;
  bool hasPcomax() => _pcomax != null;

  // "commax" field — PRD pro00_commax (comissão/desconto máx).
  double? _commax;
  double get commax => _commax ?? 100.0;
  set commax(double? val) => _commax = val;
  bool hasCommax() => _commax != null;

  // "codtrb" field — PRD pro00_codtrb (tributação ICMS-ST).
  int? _codtrb;
  int get codtrb => _codtrb ?? 0;
  set codtrb(int? val) => _codtrb = val;
  bool hasCodtrb() => _codtrb != null;

  // "freadpco" field — PRD freadpco (permite editar preço).
  bool? _freadpco;
  bool get freadpco => _freadpco ?? true;
  set freadpco(bool? val) => _freadpco = val;
  bool hasFreadpco() => _freadpco != null;

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
        mulver: castToType<double>(data['mulver']),
        pcomin: castToType<double>(data['pcomin']),
        pcomax: castToType<double>(data['pcomax']),
        commax: castToType<double>(data['commax']),
        codtrb: castToType<int>(data['codtrb']),
        freadpco: data['freadpco'] as bool?,
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
        'mulver': _mulver,
        'pcomin': _pcomin,
        'pcomax': _pcomax,
        'commax': _commax,
        'codtrb': _codtrb,
        'freadpco': _freadpco,
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
        'mulver': serializeParam(
          _mulver,
          ParamType.double,
        ),
        'pcomin': serializeParam(
          _pcomin,
          ParamType.double,
        ),
        'pcomax': serializeParam(
          _pcomax,
          ParamType.double,
        ),
        'commax': serializeParam(
          _commax,
          ParamType.double,
        ),
        'codtrb': serializeParam(
          _codtrb,
          ParamType.int,
        ),
        'freadpco': serializeParam(
          _freadpco,
          ParamType.bool,
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
        mulver: deserializeParam(
          data['mulver'],
          ParamType.double,
          false,
        ),
        pcomin: deserializeParam(
          data['pcomin'],
          ParamType.double,
          false,
        ),
        pcomax: deserializeParam(
          data['pcomax'],
          ParamType.double,
          false,
        ),
        commax: deserializeParam(
          data['commax'],
          ParamType.double,
          false,
        ),
        codtrb: deserializeParam(
          data['codtrb'],
          ParamType.int,
          false,
        ),
        freadpco: deserializeParam(
          data['freadpco'],
          ParamType.bool,
          false,
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
        listEquality.equals(fotosProduto, other.fotosProduto) &&
        mulver == other.mulver &&
        pcomin == other.pcomin &&
        pcomax == other.pcomax &&
        commax == other.commax &&
        codtrb == other.codtrb &&
        freadpco == other.freadpco;
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
        fotosProduto,
        mulver,
        pcomin,
        pcomax,
        commax,
        codtrb,
        freadpco
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
  double? mulver,
  double? pcomin,
  double? pcomax,
  double? commax,
  int? codtrb,
  bool? freadpco,
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
      mulver: mulver,
      pcomin: pcomin,
      pcomax: pcomax,
      commax: commax,
      codtrb: codtrb,
      freadpco: freadpco,
    );
