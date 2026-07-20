// ignore_for_file: unnecessary_getters_setters

import '/backend/schema/util/schema_util.dart';

import 'index.dart';
import '/core/app_util.dart';

/// DSL struct ItemUpload
///
/// Representa o resultado do envioftp de UM arquivo pendente.
/// Usado por `UploadPendenteResultStruct.enviados` para alimentar a UI
/// (dialog detalhado) com status por arquivo.
class ItemUploadStruct extends BaseStruct {
  ItemUploadStruct({
    String? nome,
    bool? sucesso,
    String? mensagem,
    int? bytesEnviados,
    String? caminhoLocal,
  })  : _nome = nome,
        _sucesso = sucesso,
        _mensagem = mensagem,
        _bytesEnviados = bytesEnviados,
        _caminhoLocal = caminhoLocal;

  // "nome" field.
  String? _nome;
  String get nome => _nome ?? '';
  set nome(String? val) => _nome = val;

  bool hasNome() => _nome != null;

  // "sucesso" field.
  bool? _sucesso;
  bool get sucesso => _sucesso ?? false;
  set sucesso(bool? val) => _sucesso = val;

  bool hasSucesso() => _sucesso != null;

  // "mensagem" field.
  String? _mensagem;
  String get mensagem => _mensagem ?? '';
  set mensagem(String? val) => _mensagem = val;

  bool hasMensagem() => _mensagem != null;

  // "bytesEnviados" field.
  int? _bytesEnviados;
  int get bytesEnviados => _bytesEnviados ?? 0;
  set bytesEnviados(int? val) => _bytesEnviados = val;

  void incrementBytesEnviados(int amount) =>
      bytesEnviados = bytesEnviados + amount;

  bool hasBytesEnviados() => _bytesEnviados != null;

  // "caminhoLocal" field.
  String? _caminhoLocal;
  String get caminhoLocal => _caminhoLocal ?? '';
  set caminhoLocal(String? val) => _caminhoLocal = val;

  bool hasCaminhoLocal() => _caminhoLocal != null;

  static ItemUploadStruct fromMap(Map<String, dynamic> data) =>
      ItemUploadStruct(
        nome: data['nome'] as String?,
        sucesso: data['sucesso'] as bool?,
        mensagem: data['mensagem'] as String?,
        bytesEnviados: castToType<int>(data['bytesEnviados']),
        caminhoLocal: data['caminhoLocal'] as String?,
      );

  static ItemUploadStruct? maybeFromMap(dynamic data) => data is Map
      ? ItemUploadStruct.fromMap(data.cast<String, dynamic>())
      : null;

  Map<String, dynamic> toMap() => {
        'nome': _nome,
        'sucesso': _sucesso,
        'mensagem': _mensagem,
        'bytesEnviados': _bytesEnviados,
        'caminhoLocal': _caminhoLocal,
      }.withoutNulls;

  @override
  Map<String, dynamic> toSerializableMap() => {
        'nome': serializeParam(
          _nome,
          ParamType.String,
        ),
        'sucesso': serializeParam(
          _sucesso,
          ParamType.bool,
        ),
        'mensagem': serializeParam(
          _mensagem,
          ParamType.String,
        ),
        'bytesEnviados': serializeParam(
          _bytesEnviados,
          ParamType.int,
        ),
        'caminhoLocal': serializeParam(
          _caminhoLocal,
          ParamType.String,
        ),
      }.withoutNulls;

  static ItemUploadStruct fromSerializableMap(Map<String, dynamic> data) =>
      ItemUploadStruct(
        nome: deserializeParam(
          data['nome'],
          ParamType.String,
          false,
        ),
        sucesso: deserializeParam(
          data['sucesso'],
          ParamType.bool,
          false,
        ),
        mensagem: deserializeParam(
          data['mensagem'],
          ParamType.String,
          false,
        ),
        bytesEnviados: deserializeParam(
          data['bytesEnviados'],
          ParamType.int,
          false,
        ),
        caminhoLocal: deserializeParam(
          data['caminhoLocal'],
          ParamType.String,
          false,
        ),
      );

  @override
  String toString() => 'ItemUploadStruct(${toMap()})';

  @override
  bool operator ==(Object other) {
    return other is ItemUploadStruct &&
        nome == other.nome &&
        sucesso == other.sucesso &&
        mensagem == other.mensagem &&
        bytesEnviados == other.bytesEnviados &&
        caminhoLocal == other.caminhoLocal;
  }

  @override
  int get hashCode =>
      const ListEquality().hash([nome, sucesso, mensagem, bytesEnviados, caminhoLocal]);
}

ItemUploadStruct createItemUploadStruct({
  String? nome,
  bool? sucesso,
  String? mensagem,
  int? bytesEnviados,
  String? caminhoLocal,
}) =>
    ItemUploadStruct(
      nome: nome,
      sucesso: sucesso,
      mensagem: mensagem,
      bytesEnviados: bytesEnviados,
      caminhoLocal: caminhoLocal,
    );
