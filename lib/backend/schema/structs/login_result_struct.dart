// ignore_for_file: unnecessary_getters_setters

import '/backend/schema/util/schema_util.dart';

import 'index.dart';
import '/core/app_util.dart';

/// DSL struct LoginResult
class LoginResultStruct extends BaseStruct {
  LoginResultStruct({
    /// LoginResult.success
    bool? success,

    /// LoginResult.vendedor_codigo
    int? vendedorCodigo,

    /// LoginResult.vendedor_nome
    String? vendedorNome,
  })  : _success = success,
        _vendedorCodigo = vendedorCodigo,
        _vendedorNome = vendedorNome;

  // "success" field.
  bool? _success;
  bool get success => _success ?? false;
  set success(bool? val) => _success = val;

  bool hasSuccess() => _success != null;

  // "vendedor_codigo" field.
  int? _vendedorCodigo;
  int get vendedorCodigo => _vendedorCodigo ?? 0;
  set vendedorCodigo(int? val) => _vendedorCodigo = val;

  void incrementVendedorCodigo(int amount) =>
      vendedorCodigo = vendedorCodigo + amount;

  bool hasVendedorCodigo() => _vendedorCodigo != null;

  // "vendedor_nome" field.
  String? _vendedorNome;
  String get vendedorNome => _vendedorNome ?? '';
  set vendedorNome(String? val) => _vendedorNome = val;

  bool hasVendedorNome() => _vendedorNome != null;

  static LoginResultStruct fromMap(Map<String, dynamic> data) =>
      LoginResultStruct(
        success: data['success'] as bool?,
        vendedorCodigo: castToType<int>(data['vendedor_codigo']),
        vendedorNome: data['vendedor_nome'] as String?,
      );

  static LoginResultStruct? maybeFromMap(dynamic data) => data is Map
      ? LoginResultStruct.fromMap(data.cast<String, dynamic>())
      : null;

  Map<String, dynamic> toMap() => {
        'success': _success,
        'vendedor_codigo': _vendedorCodigo,
        'vendedor_nome': _vendedorNome,
      }.withoutNulls;

  @override
  Map<String, dynamic> toSerializableMap() => {
        'success': serializeParam(
          _success,
          ParamType.bool,
        ),
        'vendedor_codigo': serializeParam(
          _vendedorCodigo,
          ParamType.int,
        ),
        'vendedor_nome': serializeParam(
          _vendedorNome,
          ParamType.String,
        ),
      }.withoutNulls;

  static LoginResultStruct fromSerializableMap(Map<String, dynamic> data) =>
      LoginResultStruct(
        success: deserializeParam(
          data['success'],
          ParamType.bool,
          false,
        ),
        vendedorCodigo: deserializeParam(
          data['vendedor_codigo'],
          ParamType.int,
          false,
        ),
        vendedorNome: deserializeParam(
          data['vendedor_nome'],
          ParamType.String,
          false,
        ),
      );

  @override
  String toString() => 'LoginResultStruct(${toMap()})';

  @override
  bool operator ==(Object other) {
    return other is LoginResultStruct &&
        success == other.success &&
        vendedorCodigo == other.vendedorCodigo &&
        vendedorNome == other.vendedorNome;
  }

  @override
  int get hashCode =>
      const ListEquality().hash([success, vendedorCodigo, vendedorNome]);
}

LoginResultStruct createLoginResultStruct({
  bool? success,
  int? vendedorCodigo,
  String? vendedorNome,
}) =>
    LoginResultStruct(
      success: success,
      vendedorCodigo: vendedorCodigo,
      vendedorNome: vendedorNome,
    );
