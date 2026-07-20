// ignore_for_file: unnecessary_getters_setters

import '/backend/schema/util/schema_util.dart';

import 'index.dart';
import '/core/app_util.dart';

/// DSL struct ValidationResult
class ValidationResultStruct extends BaseStruct {
  ValidationResultStruct({
    /// ValidationResult.valido
    bool? valido,

    /// ValidationResult.mensagem
    String? mensagem,
  })  : _valido = valido,
        _mensagem = mensagem;

  // "valido" field.
  bool? _valido;
  bool get valido => _valido ?? false;
  set valido(bool? val) => _valido = val;

  bool hasValido() => _valido != null;

  // "mensagem" field.
  String? _mensagem;
  String get mensagem => _mensagem ?? '';
  set mensagem(String? val) => _mensagem = val;

  bool hasMensagem() => _mensagem != null;

  static ValidationResultStruct fromMap(Map<String, dynamic> data) =>
      ValidationResultStruct(
        valido: data['valido'] as bool?,
        mensagem: data['mensagem'] as String?,
      );

  static ValidationResultStruct? maybeFromMap(dynamic data) => data is Map
      ? ValidationResultStruct.fromMap(data.cast<String, dynamic>())
      : null;

  Map<String, dynamic> toMap() => {
        'valido': _valido,
        'mensagem': _mensagem,
      }.withoutNulls;

  @override
  Map<String, dynamic> toSerializableMap() => {
        'valido': serializeParam(
          _valido,
          ParamType.bool,
        ),
        'mensagem': serializeParam(
          _mensagem,
          ParamType.String,
        ),
      }.withoutNulls;

  static ValidationResultStruct fromSerializableMap(
          Map<String, dynamic> data) =>
      ValidationResultStruct(
        valido: deserializeParam(
          data['valido'],
          ParamType.bool,
          false,
        ),
        mensagem: deserializeParam(
          data['mensagem'],
          ParamType.String,
          false,
        ),
      );

  @override
  String toString() => 'ValidationResultStruct(${toMap()})';

  @override
  bool operator ==(Object other) {
    return other is ValidationResultStruct &&
        valido == other.valido &&
        mensagem == other.mensagem;
  }

  @override
  int get hashCode => const ListEquality().hash([valido, mensagem]);
}

ValidationResultStruct createValidationResultStruct({
  bool? valido,
  String? mensagem,
}) =>
    ValidationResultStruct(
      valido: valido,
      mensagem: mensagem,
    );
