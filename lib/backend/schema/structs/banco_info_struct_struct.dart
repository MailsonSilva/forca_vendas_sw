// ignore_for_file: unnecessary_getters_setters

import '/backend/schema/util/schema_util.dart';

import 'index.dart';
import '/core/app_util.dart';

class BancoInfoStructStruct extends BaseStruct {
  BancoInfoStructStruct({
    String? nomeBanco,
    String? ddd,
    String? telefone,
  })  : _nomeBanco = nomeBanco,
        _ddd = ddd,
        _telefone = telefone;

  // "nomeBanco" field.
  String? _nomeBanco;
  String get nomeBanco => _nomeBanco ?? '';
  set nomeBanco(String? val) => _nomeBanco = val;

  bool hasNomeBanco() => _nomeBanco != null;

  // "ddd" field.
  String? _ddd;
  String get ddd => _ddd ?? '';
  set ddd(String? val) => _ddd = val;

  bool hasDdd() => _ddd != null;

  // "telefone" field.
  String? _telefone;
  String get telefone => _telefone ?? '';
  set telefone(String? val) => _telefone = val;

  bool hasTelefone() => _telefone != null;

  static BancoInfoStructStruct fromMap(Map<String, dynamic> data) =>
      BancoInfoStructStruct(
        nomeBanco: data['nomeBanco'] as String?,
        ddd: data['ddd'] as String?,
        telefone: data['telefone'] as String?,
      );

  static BancoInfoStructStruct? maybeFromMap(dynamic data) => data is Map
      ? BancoInfoStructStruct.fromMap(data.cast<String, dynamic>())
      : null;

  Map<String, dynamic> toMap() => {
        'nomeBanco': _nomeBanco,
        'ddd': _ddd,
        'telefone': _telefone,
      }.withoutNulls;

  @override
  Map<String, dynamic> toSerializableMap() => {
        'nomeBanco': serializeParam(
          _nomeBanco,
          ParamType.String,
        ),
        'ddd': serializeParam(
          _ddd,
          ParamType.String,
        ),
        'telefone': serializeParam(
          _telefone,
          ParamType.String,
        ),
      }.withoutNulls;

  static BancoInfoStructStruct fromSerializableMap(Map<String, dynamic> data) =>
      BancoInfoStructStruct(
        nomeBanco: deserializeParam(
          data['nomeBanco'],
          ParamType.String,
          false,
        ),
        ddd: deserializeParam(
          data['ddd'],
          ParamType.String,
          false,
        ),
        telefone: deserializeParam(
          data['telefone'],
          ParamType.String,
          false,
        ),
      );

  @override
  String toString() => 'BancoInfoStructStruct(${toMap()})';

  @override
  bool operator ==(Object other) {
    return other is BancoInfoStructStruct &&
        nomeBanco == other.nomeBanco &&
        ddd == other.ddd &&
        telefone == other.telefone;
  }

  @override
  int get hashCode => const ListEquality().hash([nomeBanco, ddd, telefone]);
}

BancoInfoStructStruct createBancoInfoStructStruct({
  String? nomeBanco,
  String? ddd,
  String? telefone,
}) =>
    BancoInfoStructStruct(
      nomeBanco: nomeBanco,
      ddd: ddd,
      telefone: telefone,
    );
