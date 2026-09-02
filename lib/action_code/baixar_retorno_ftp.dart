// ignore_for_file: avoid_print

import '/backend/schema/structs/index.dart';
import '/data/services/pacote_retorno_service.dart';

/// Action FlutterFlow para buscar, descompactar e processar os arquivos de retorno (.ret) do FTP.
Future<FirstAccessResultStruct> baixarRetornoFtp({
  String? empresaCodigo,
  String? vendedorCodigo,
}) async {
  try {
    final int codRep = int.tryParse(vendedorCodigo ?? '') ?? 0;
    final service = PacoteRetornoService();

    final result = await service.processarRetornos(
      empresa: empresaCodigo,
      codRep: codRep > 0 ? codRep : null,
    );

    return FirstAccessResultStruct.fromMap({
      'success': result.sucesso,
      'message': result.mensagem,
    });
  } catch (e) {
    return FirstAccessResultStruct.fromMap({
      'success': false,
      'message': 'Falha ao baixar retorno: $e',
    });
  }
}
