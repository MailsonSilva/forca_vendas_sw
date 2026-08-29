import '../../backend/schema/structs/validation_result_struct.dart';

/// PRD B6 — ValidePCOValues / ValideQTDValues (PRD 532 / ffrmdigvenmov07 validation)
class ValidePcoService {
  static ValidationResultStruct validePCOValues({
    required double pcomin,
    required double pcomax,
    required double commax,
    required double digpco,
    required double destot,
    required bool freadpco,
  }) {
    if (!freadpco) {
      // Preço não editável — só verifica se foi alterado externamente
      return ValidationResultStruct(valido: true, mensagem: '');
    }
    if (digpco < pcomin) {
      return ValidationResultStruct(valido: false, mensagem: 'Preço abaixo do mínimo');
    }
    if (digpco > pcomax) {
      return ValidationResultStruct(valido: false, mensagem: 'Preço acima do máximo');
    }
    if (destot > commax) {
      return ValidationResultStruct(valido: false, mensagem: 'Desconto acima do máximo permitido');
    }
    return ValidationResultStruct(valido: true, mensagem: '');
  }

  static ValidationResultStruct valideQTDValues({
    required double quantidade,
    required double saldo,
  }) {
    if (quantidade <= 0) {
      return ValidationResultStruct(valido: false, mensagem: 'Quantidade inválida');
    }
    if (quantidade > saldo) {
      return ValidationResultStruct(valido: false, mensagem: 'Estoque insuficiente');
    }
    return ValidationResultStruct(valido: true, mensagem: '');
  }
}
