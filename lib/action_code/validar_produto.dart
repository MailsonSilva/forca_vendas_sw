// Imports do app
import '/backend/schema/structs/index.dart';
// Imports other custom actions
// Imports custom functions
// Begin custom action code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

// Imports do app
// Imports other custom actions
// Imports custom functions
// Begin custom action code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!


import '../domain/services/valide_pco_service.dart';

Future<ValidationResultStruct> validarProduto(
  double precoUnitario,
  double saldoEstoque, {
  double pcomin = 0,
  double pcomax = 999999,
  double commax = 100,
  double destot = 0,
  bool freadpco = true,
}) async {
  if (precoUnitario <= 0) {
    return ValidationResultStruct(
      valido: false,
      mensagem: 'Produto indisponível: Produto sem preço de venda definido.',
    );
  }
  // PRD B6: ValidePCOValues
  final pco = ValidePcoService.validePCOValues(
    pcomin: pcomin,
    pcomax: pcomax,
    commax: commax,
    digpco: precoUnitario,
    destot: destot,
    freadpco: freadpco,
  );
  if (!pco.valido) return pco;

  final qtd = ValidePcoService.valideQTDValues(quantidade: 1, saldo: saldoEstoque);
  if (!qtd.valido) {
    return ValidationResultStruct(
      valido: false,
      mensagem: 'Estoque esgotado: O produto está com saldo zerado no momento.',
    );
  }
  return ValidationResultStruct(
    valido: true,
    mensagem: '',
  );
}
