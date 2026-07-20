// ignore_for_file: unnecessary_getters_setters

import '/backend/schema/util/schema_util.dart';

import 'index.dart';
import '/core/app_util.dart';

/// DSL struct UploadPendenteResult
///
/// Resultado agregado do envio FTP de todos os cadastros pendentes.
/// `enviados` e preenchido com um ItemUploadStruct por arquivo submetido
/// a upload, permitindo a UI exibir status individual (sucesso/falha, bytes,
/// mensagem de erro) e o nome do arquivo.
class UploadPendenteResultStruct extends BaseStruct {
  UploadPendenteResultStruct({
    bool? success,
    String? message,
    List<ItemUploadStruct>? enviados,
  })  : _success = success,
        _message = message,
        _enviados = enviados;

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

  // "enviados" field.
  List<ItemUploadStruct>? _enviados;
  List<ItemUploadStruct> get enviados => _enviados ?? const [];
  set enviados(List<ItemUploadStruct>? val) => _enviados = val;

  void updateEnviados(Function(List<ItemUploadStruct>) updateFn) {
    updateFn(_enviados ??= []);
  }

  bool hasEnviados() => _enviados != null;

  static UploadPendenteResultStruct fromMap(Map<String, dynamic> data) =>
      UploadPendenteResultStruct(
        success: data['success'] as bool?,
        message: data['message'] as String?,
        enviados: getStructList(
          data['enviados'],
          ItemUploadStruct.fromMap,
        ),
      );

  static UploadPendenteResultStruct? maybeFromMap(dynamic data) => data is Map
      ? UploadPendenteResultStruct.fromMap(data.cast<String, dynamic>())
      : null;

  Map<String, dynamic> toMap() => {
        'success': _success,
        'message': _message,
        'enviados': _enviados?.map((e) => e.toMap()).toList(),
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
        'enviados': serializeParam(
          _enviados,
          ParamType.DataStruct,
          isList: true,
        ),
      }.withoutNulls;

  static UploadPendenteResultStruct fromSerializableMap(
          Map<String, dynamic> data) =>
      UploadPendenteResultStruct(
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
        enviados: deserializeStructParam<ItemUploadStruct>(
          data['enviados'],
          ParamType.DataStruct,
          true,
          structBuilder: ItemUploadStruct.fromSerializableMap,
        ),
      );

  @override
  String toString() => 'UploadPendenteResultStruct(${toMap()})';

  @override
  bool operator ==(Object other) {
    const listEquality = ListEquality();
    return other is UploadPendenteResultStruct &&
        success == other.success &&
        message == other.message &&
        listEquality.equals(enviados, other.enviados);
  }

  @override
  int get hashCode =>
      const ListEquality().hash([success, message, enviados]);
}

UploadPendenteResultStruct createUploadPendenteResultStruct({
  bool? success,
  String? message,
  List<ItemUploadStruct>? enviados,
}) =>
    UploadPendenteResultStruct(
      success: success,
      message: message,
      enviados: enviados,
    );
