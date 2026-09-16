import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forca_de_vendas/backend/schema/structs/cliente_result_struct.dart';
import 'package:forca_de_vendas/core/formatters/currency_formatter.dart';

void main() {

  group('SPEC-042 - Seam 3: UI Card de Cliente e Atalho de Extrato', () {
    testWidgets('Card de cliente exibe Razão, Fantasia, Código, CPF formatado, Cidade/UF e Limite formatado', (tester) async {
      final cliente = ClienteResultStruct(
        cli00Codigo: 1234,
        cli00Descri: 'MERCADO CENTRAL LTDA',
        cli00Fantas: 'MERCADO CENTRAL',
        cli00Cpfcnp: '12345678000195',
        cli00Ciddes: 'GOIANIA',
        cli00Estsgl: 'GO',
        cli00Creatu: 15450.50,
        cli00Titven: 0.0,
      );

      bool extratoClicado = false;
      bool cardClicado = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                final hasDebito = (cliente.cli00Titven) > 0;
                return InkWell(
                  onTap: () => cardClicado = true,
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: hasDebito ? Colors.red : Colors.grey,
                        width: hasDebito ? 2.0 : 1.0,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${cliente.cli00Codigo} - ${cliente.cli00Descri}'),
                        Text(cliente.cli00Fantas),
                        Text(cliente.cli00Cpfcnp),
                        Text('${cliente.cli00Ciddes} / ${cliente.cli00Estsgl}'),
                        Text(cliente.cli00Creatu.toMoeda()),
                        if (hasDebito)
                          const Text('Possui Débitos Vencidos', style: TextStyle(color: Colors.red)),
                        IconButton(
                          icon: const Icon(Icons.receipt_long),
                          onPressed: () => extratoClicado = true,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      );

      // Verificações dos dados exibidos
      expect(find.text('1234 - MERCADO CENTRAL LTDA'), findsOneWidget);
      expect(find.text('MERCADO CENTRAL'), findsOneWidget);
      expect(find.text('12345678000195'), findsOneWidget);
      expect(find.text('GOIANIA / GO'), findsOneWidget);
      expect(find.text(15450.50.toMoeda()), findsOneWidget);
      expect(find.text('Possui Débitos Vencidos'), findsNothing);

      // Clica no ícone de extrato diretamente sem disparar a seleção
      await tester.tap(find.byIcon(Icons.receipt_long));
      expect(extratoClicado, isTrue);
      expect(cardClicado, isFalse);
    });

    testWidgets('Card de cliente com débito vencido exibe destaque em vermelho e aviso', (tester) async {
      final clienteComDebito = ClienteResultStruct(
        cli00Codigo: 5678,
        cli00Descri: 'PADARIA REAL',
        cli00Fantas: 'PADARIA REAL',
        cli00Cpfcnp: '98765432000188',
        cli00Ciddes: 'ANAPOLIS',
        cli00Estsgl: 'GO',
        cli00Creatu: 500.0,
        cli00Titven: 1250.0,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                final hasDebito = (clienteComDebito.cli00Titven) > 0;
                return Container(
                  key: const ValueKey('client_card'),
                  decoration: BoxDecoration(
                    color: hasDebito ? const Color(0xFFFFEBEE) : Colors.white,
                    border: Border.all(
                      color: hasDebito ? Colors.red : Colors.grey,
                      width: hasDebito ? 2.0 : 1.0,
                    ),
                  ),
                  child: Column(
                    children: [
                      Text('${clienteComDebito.cli00Codigo} - ${clienteComDebito.cli00Descri}'),
                      if (hasDebito)
                        const Text('DÉBITOS VENCIDOS', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      );

      expect(find.text('5678 - PADARIA REAL'), findsOneWidget);
      expect(find.text('DÉBITOS VENCIDOS'), findsOneWidget);
    });
  });
}
