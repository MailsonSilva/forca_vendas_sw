// ignore_for_file: unnecessary_getters_setters

import '/backend/schema/util/schema_util.dart';

import 'index.dart';
import '/core/app_util.dart';

class ListaPadraoStruct extends BaseStruct {
  ListaPadraoStruct({
    String? codigo,
    String? descricao,
    double? vlrmin,
  })  : _codigo = codigo,
        _descricao = descricao,
        _vlrmin = vlrmin;

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

  // "vlrmin" field — PRD pla00_vlrmin (valor mínimo exigido pelo plano).
  double? _vlrmin;
  double get vlrmin => _vlrmin ?? 0.0;
  set vlrmin(double? val) => _vlrmin = val;

  bool hasVlrmin() => _vlrmin != null;

  static ListaPadraoStruct fromMap(Map<String, dynamic> data) =>
      ListaPadraoStruct(
        codigo: data['codigo'] as String?,
        descricao: data['descricao'] as String?,
        vlrmin: castToType<double>(data['vlrmin']),
      );

  static ListaPadraoStruct? maybeFromMap(dynamic data) => data is Map
      ? ListaPadraoStruct.fromMap(data.cast<String, dynamic>())
      : null;

  Map<String, dynamic> toMap() => {
        'codigo': _codigo,
        'descricao': _descricao,
        'vlrmin': _vlrmin,
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
        'vlrmin': serializeParam(
          _vlrmin,
          ParamType.double,
        ),
      }.withoutNulls;

  static ListaPadraoStruct fromSerializableMap(Map<String, dynamic> data) =>
      ListaPadraoStruct(
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
        vlrmin: deserializeParam(
          data['vlrmin'],
          ParamType.double,
          false,
        ),
      );

  @override
  String toString() => 'ListaPadraoStruct(${toMap()})';

  @override
  bool operator ==(Object other) {
    return other is ListaPadraoStruct &&
        codigo == other.codigo &&
        descricao == other.descricao &&
        vlrmin == other.vlrmin;
  }

  @override
  int get hashCode => const ListEquality().hash([codigo, descricao, vlrmin]);
}

ListaPadraoStruct createListaPadraoStruct({
  String? codigo,
  String? descricao,
  double? vlrmin,
}) =>
    ListaPadraoStruct(
      codigo: codigo,
      descricao: descricao,
      vlrmin: vlrmin,
    );
