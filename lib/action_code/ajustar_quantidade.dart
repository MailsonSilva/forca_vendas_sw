// Imports do app
// Imports other custom actions
// Imports custom functions
// Begin custom action code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

// Imports do app
// Imports other custom actions
// Imports custom functions
// Begin custom action code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

Future<int> ajustarQuantidade(int valorAtual, int delta) async {
  final novoValor = valorAtual + delta;
  return novoValor < 1 ? 1 : novoValor;
}
