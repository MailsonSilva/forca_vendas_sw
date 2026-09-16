import 'package:flutter_test/flutter_test.dart';
import 'package:forca_de_vendas/services/receber_duplicatas_service.dart';
import 'package:forca_de_vendas/domain/services/bloqueio_financeiro_service.dart';
import 'package:forca_de_vendas/data/services/local_sales_database_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('SPEC-042 - Seam 2: Algoritmo de Dias de Atraso e Juros de Mora', () {
    final hoje = DateTime(2026, 9, 16);

    test('calcularDiasAtraso retorna 0 para títulos vencendo hoje ou no futuro', () {
      final venHoje = DateTime(2026, 9, 16);
      final venFuturo = DateTime(2026, 9, 20);

      expect(ReceberDuplicatasService.calcularDiasAtraso(venHoje, hoje: hoje), equals(0));
      expect(ReceberDuplicatasService.calcularDiasAtraso(venFuturo, hoje: hoje), equals(0));
    });

    test('calcularDiasAtraso calcula diferença exata de dias para títulos vencidos', () {
      final ven10Dias = DateTime(2026, 9, 6);
      final ven30Dias = DateTime(2026, 8, 17);

      expect(ReceberDuplicatasService.calcularDiasAtraso(ven10Dias, hoje: hoje), equals(10));
      expect(ReceberDuplicatasService.calcularDiasAtraso(ven30Dias, hoje: hoje), equals(30));
    });

    test('calcularJurosMora aplica fórmula exata: saldoDevedor * (taxa / 100) * diasAtraso', () {
      // Saldo devedor: R$ 1.000,00 | Taxa: 0.1% ao dia | Dias: 30 dias
      // Juros esperados: 1000 * 0.001 * 30 = 30.00
      final juros = ReceberDuplicatasService.calcularJurosMora(
        saldoDevedor: 1000.0,
        taxaJurosDiaria: 0.1,
        diasAtraso: 30,
      );
      expect(juros, equals(30.0));
    });

    test('calcularJurosMora retorna 0.0 se diasAtraso <= 0 ou taxa <= 0', () {
      expect(
        ReceberDuplicatasService.calcularJurosMora(
          saldoDevedor: 500.0,
          taxaJurosDiaria: 0.1,
          diasAtraso: 0,
        ),
        equals(0.0),
      );
      expect(
        ReceberDuplicatasService.calcularJurosMora(
          saldoDevedor: 500.0,
          taxaJurosDiaria: 0.0,
          diasAtraso: 15,
        ),
        equals(0.0),
      );
    });
  });

  group('SPEC-042 - Seam 2: Carregamento de dup00 com Vendedor, Cobrador e Tipo de Cobrança', () {
    test('carregarTitulosCliente popula codVen, codAgt e codCob em TituloDuplicataItem', () async {
      final db = await LocalSalesDatabaseService.getDatabase();

      await db.execute('''
        CREATE TABLE IF NOT EXISTS dup00 (
          dup00_codigo INTEGER PRIMARY KEY,
          dup00_codcli INTEGER,
          dup00_datemi TEXT,
          dup00_datven TEXT,
          dup00_valori REAL,
          dup00_valdev REAL,
          dup00_valpag REAL,
          dup00_codven INTEGER,
          dup00_codagt INTEGER,
          dup00_codcob INTEGER
        )
      ''');

      await db.rawInsert('''
        INSERT OR REPLACE INTO dup00 (
          dup00_codigo, dup00_codcli, dup00_datemi, dup00_datven,
          dup00_valori, dup00_valdev, dup00_valpag,
          dup00_codven, dup00_codagt, dup00_codcob
        ) VALUES (
          98765, 8888, '2026-08-01', '2026-08-15',
          250.0, 200.0, 50.0,
          71, 10, 1
        )
      ''');

      final titulos = await ReceberDuplicatasService.carregarTitulosCliente(
        8888,
        taxaJurosOverride: 0.1,
        hojeRef: DateTime(2026, 9, 16),
      );

      expect(titulos.isNotEmpty, isTrue);
      final t = titulos.first;
      expect(t.codigo, equals(98765));
      expect(t.valorOriginal, equals(250.0));
      expect(t.saldoDevedor, equals(200.0));
      expect(t.valorPago, equals(50.0));
      expect(t.codVen, equals(71));
      expect(t.codAgt, equals(10));
      expect(t.codCob, equals(1));
      expect(t.isVencido, isTrue);
      expect(t.diasAtraso, equals(32));
      expect(t.valorJuros, equals(6.4)); // 200 * 0.001 * 32 = 6.4
    });
  });

  group('SPEC-042 - Seam 2: Validação de Crédito e Bloqueio por cli00_titven > 0', () {
    test('verificaInadimplenciaCliente bloqueia cliente com cli00_titven > 0', () async {
      final db = await LocalSalesDatabaseService.getDatabase();

      await db.execute('''
        CREATE TABLE IF NOT EXISTS cadcli00 (
          cli00_codigo INTEGER PRIMARY KEY,
          cli00_descri TEXT,
          cli00_titven REAL,
          cli00_creatu REAL,
          cli00_crelim REAL
        )
      ''');

      // Cliente 7771: possui débitos vencidos (cli00_titven = 450.00)
      await db.rawInsert('''
        INSERT OR REPLACE INTO cadcli00 (
          cli00_codigo, cli00_descri, cli00_titven, cli00_creatu, cli00_crelim
        ) VALUES (7771, 'CLIENTE COM DEBITO', 450.0, 1000.0, 2000.0)
      ''');

      // Cliente 7772: adimplente (cli00_titven = 0)
      await db.rawInsert('''
        INSERT OR REPLACE INTO cadcli00 (
          cli00_codigo, cli00_descri, cli00_titven, cli00_creatu, cli00_crelim
        ) VALUES (7772, 'CLIENTE EM DIA', 0.0, 1000.0, 2000.0)
      ''');

      final resultBloqueado = await BloqueioFinanceiroService.verificaInadimplenciaCliente(7771);
      expect(resultBloqueado.bloqueado, isTrue);
      expect(resultBloqueado.motivo, contains('450,00'));

      final resultLiberado = await BloqueioFinanceiroService.verificaInadimplenciaCliente(7772);
      expect(resultLiberado.bloqueado, isFalse);
    });

    test('verificaInadimplenciaCliente bloqueia se limite estiver estourado (creatu <= 0)', () async {
      final db = await LocalSalesDatabaseService.getDatabase();
      await db.rawInsert('''
        INSERT OR REPLACE INTO cadcli00 (
          cli00_codigo, cli00_descri, cli00_titven, cli00_creatu, cli00_crelim
        ) VALUES (7773, 'CLIENTE LIMITE ESTOURADO', 0.0, 0.0, 500.0)
      ''');

      final result = await BloqueioFinanceiroService.verificaInadimplenciaCliente(7773);
      expect(result.bloqueado, isTrue);
      expect(result.motivo, contains('Limite de crédito'));
    });
  });
}
