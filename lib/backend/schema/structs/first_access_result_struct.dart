// ignore_for_file: unnecessary_getters_setters

import '/backend/schema/util/schema_util.dart';

import 'index.dart';
import '/core/app_util.dart';

/// DSL struct FirstAccessResult
class FirstAccessResultStruct extends BaseStruct {
  FirstAccessResultStruct({
    /// FirstAccessResult.success
    bool? success,

    /// FirstAccessResult.message
    String? message,
  })  : _success = success,
        _message = message;

  // "success" field.
  bool? _success;
  bool get success => _success ?? false;
  set success(bool? val) => _success = val;

  bool hasSuccess() => _success != null;

  // "message" field.
  String? _message;
  String get message => _message ?? '';
  set message(String? val) => _message = val;

  bool hasMessage() => _message != null;

  static FirstAccessResultStruct fromMap(Map<String, dynamic> data) =>
      FirstAccessResultStruct(
        success: data['success'] as bool?,
        message: data['message'] as String?,
      );

  static FirstAccessResultStruct? maybeFromMap(dynamic data) => data is Map
      ? FirstAccessResultStruct.fromMap(data.cast<String, dynamic>())
      : null;

  Map<String, dynamic> toMap() => {
        'success': _success,
        'message': _message,
      }.withoutNulls;

  @override
  Map<String, dynamic> toSerializableMap() => {
        'success': serializeParam(
          _success,
          ParamType.bool,
        ),
        'message': serializeParam(
          _message,
          ParamType.String,
        ),
      }.withoutNulls;

  static FirstAccessResultStruct fromSerializableMap(
          Map<String, dynamic> data) =>
      FirstAccessResultStruct(
        success: deserializeParam(
          data['success'],
          ParamType.bool,
          false,
        ),
        message: deserializeParam(
          data['message'],
          ParamType.String,
          false,
        ),
      );

  @override
  String toString() => 'FirstAccessResultStruct(${toMap()})';

  @override
  bool operator ==(Object other) {
    return other is FirstAccessResultStruct &&
        success == other.success &&
        message == other.message;
  }

  @override
  int get hashCode => const ListEquality().hash([success, message]);
}

FirstAccessResultStruct createFirstAccessResultStruct({
  bool? success,
  String? message,
}) =>
    FirstAccessResultStruct(
      success: success,
      message: message,
    );
