// ignore_for_file: unused_import

import '/core/app_theme.dart';
import '/core/app_util.dart';
import '/core/app_widgets.dart';
import '/backend/schema/structs/index.dart';
import 'dart:ui';
import '/action_code/index.dart' as actions;
import 'envio_detalhes_widget.dart' show EnvioDetalhesWidget;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:percent_indicator/percent_indicator.dart';
import 'package:provider/provider.dart';

class EnvioDetalhesModel extends AppModel<EnvioDetalhesWidget> {
  ///  Local state fields for this component.

  /// Lista de arquivos exibida no dialog de status.
  /// Atualizada antes do envio (via listarArquivosPendentes) e durante
  /// o envio (pelo callback de progresso de enviarArquivosPendentesFtp).
  List<ItemUploadStruct> arquivos = [];

  /// Flag de controle: true enquanto a action de envio esta em andamento.
  bool enviando = false;

  /// Resultado agregado apos o envio (success/message/enviados).
  UploadPendenteResultStruct? resultado;

  /// Filtro visual ativo: todos, espera, enviados ou erro.
  String filtroStatus = 'espera';

  ///  State fields for stateful widgets in this component.

  @override
  void initState(BuildContext context) {}

  @override
  void dispose() {}
}
