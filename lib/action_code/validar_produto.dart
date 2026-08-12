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


Future<ValidationResultStruct> validarProduto(
  double precoUnitario,
  double saldoEstoque,
) async {
  if (precoUnitario <= 0) {
    return ValidationResultStruct(
      valido: false,
      mensagem: 'Produto indisponível: Produto sem preço de venda definido.',
    );
  }
  if (saldoEstoque <= 0) {
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
