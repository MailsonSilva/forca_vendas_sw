// ignore_for_file: unnecessary_getters_setters

import '/backend/schema/util/schema_util.dart';

import 'index.dart';
import '/core/app_util.dart';

class ListaPadraoStruct extends BaseStruct {
  ListaPadraoStruct({
    String? codigo,
    String? descricao,
  })  : _codigo = codigo,
        _descricao = descricao;

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

  static ListaPadraoStruct fromMap(Map<String, dynamic> data) =>
      ListaPadraoStruct(
        codigo: data['codigo'] as String?,
        descricao: data['descricao'] as String?,
      );

  static ListaPadraoStruct? maybeFromMap(dynamic data) => data is Map
      ? ListaPadraoStruct.fromMap(data.cast<String, dynamic>())
      : null;

  Map<String, dynamic> toMap() => {
        'codigo': _codigo,
        'descricao': _descricao,
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
      );

  @override
  String toString() => 'ListaPadraoStruct(${toMap()})';

  @override
  bool operator ==(Object other) {
    return other is ListaPadraoStruct &&
        codigo == other.codigo &&
        descricao == other.descricao;
  }

  @override
  int get hashCode => const ListEquality().hash([codigo, descricao]);
}

ListaPadraoStruct createListaPadraoStruct({
  String? codigo,
  String? descricao,
}) =>
    ListaPadraoStruct(
      codigo: codigo,
      descricao: descricao,
    );
