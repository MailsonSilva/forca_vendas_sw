import 'package:flutter_test/flutter_test.dart';
import 'package:forca_de_vendas/domain/models/status_envio.dart';

void main() {
  test('StatusEnvio maps legacy enum values', () {
    expect(StatusEnvio.naoEnviado.value, equals(0));
    expect(StatusEnvio.jaEnviado.value, equals(1));
    expect(StatusEnvio.retornado.value, equals(2));
  });

  test('StatusEnvio exposes stable order', () {
    expect(StatusEnvio.values, [
      StatusEnvio.naoEnviado,
      StatusEnvio.jaEnviado,
      StatusEnvio.retornado,
    ]);
  });
}
