import 'package:flutter_test/flutter_test.dart';
import 'package:forca_de_vendas/app_constants.dart';
import 'package:forca_de_vendas/domain/models/pedido_venda.dart';
import 'package:forca_de_vendas/domain/services/icms_st_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart' as p;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('Fase 3 - Motor Fiscal (ICMS-ST)', () {
    test('kEnableIcmsSt flag is enabled', () {
      expect(kEnableIcmsSt, isTrue);
    });

    test('calcBaseST applies MVA over liquid item value', () {
      // Valor Item = 100.0, Frete = 10.0, Despesas = 5.0, Desconto = 15.0 => Base Líquida = 100.0
      // MVA = 40% (0.40) => Base ST = 100.0 * 1.40 = 140.0
      final baseST = IcmsStService.calcBaseST(
        base: 100.0,
        frete: 10.0,
        despesas: 5.0,
        descontos: 15.0,
        mva: 0.40,
      );
      expect(baseST, closeTo(140.0, 0.001));
    });

    test('calcIcmsProprio calculates standard ICMS value', () {
      // Valor Item = 100.0, Alíquota = 18% (0.18) => ICMS Próprio = 18.0
      final proprio = IcmsStService.calcIcmsProprio(
        valorItem: 100.0,
        aliqPropria: 0.18,
      );
      expect(proprio, closeTo(18.0, 0.001));
    });

    test('calcIcmsST deducts ICMS Próprio from BaseST * AliqDestino', () {
      // Base ST = 140.0, AliqDestino = 18% => Debito ST = 25.20
      // ICMS Próprio = 18.0 => ICMS-ST = 25.20 - 18.0 = 7.20
      final st = IcmsStService.calcIcmsST(
        baseST: 140.0,
        aliqDestino: 0.18,
        icmsProprio: 18.0,
      );
      expect(st, closeTo(7.20, 0.001));
    });

    test('calcIcmsST returns 0 if result is negative', () {
      // ICMS Próprio maior que débito ST
      final st = IcmsStService.calcIcmsST(
        baseST: 100.0,
        aliqDestino: 0.12,
        icmsProprio: 18.0,
      );
      expect(st, equals(0.0));
    });

    test('calcularItem executes full dynamic ICMS-ST calculation', () {
      final st = IcmsStService.calcularItem(
        valorItem: 100.0,
        mva: 0.40,
        aliqPropria: 0.18,
        aliqDestino: 0.18,
      );
      // Base ST = 140.0, ICMS Destino = 25.20, ICMS Próprio = 18.0 => ST = 7.20
      expect(st, closeTo(7.20, 0.001));
    });
  });

  group('Fase 3 - Calendário e Postergação de Vencimentos (cadfer00)', () {
    test('postergarParaDiaUtil advances Saturday and Sunday to Monday', () {
      final sabado = DateTime(2026, 8, 29); // Sábado
      final vencimentoSab = PedidoVenda.postergarParaDiaUtil(sabado);
      expect(vencimentoSab.weekday, equals(DateTime.monday));
      expect(vencimentoSab.day, equals(31));

      final domingo = DateTime(2026, 8, 30); // Domingo
      final vencimentoDom = PedidoVenda.postergarParaDiaUtil(domingo);
      expect(vencimentoDom.weekday, equals(DateTime.monday));
      expect(vencimentoDom.day, equals(31));
    });

    test('postergarParaDiaUtil advances holiday to next business day', () {
      final segundaFeriado = DateTime(2026, 9, 7); // Feriado Independência (segunda-feira)
      final feriados = {'2026-09-07'};

      final vencimento = PedidoVenda.postergarParaDiaUtil(segundaFeriado, feriados: feriados);
      expect(vencimento.weekday, equals(DateTime.tuesday));
      expect(vencimento.day, equals(8));
    });

    test('postergarParaDiaUtil handles consecutive holiday + weekend', () {
      final sextaFeriado = DateTime(2026, 5, 1); // Sexta 1º Maio
      final feriados = {'2026-05-01'};

      final vencimento = PedidoVenda.postergarParaDiaUtil(sextaFeriado, feriados: feriados);
      // Sexta feriado -> Sábado -> Domingo -> Segunda 4 de Maio
      expect(vencimento.weekday, equals(DateTime.monday));
      expect(vencimento.day, equals(4));
    });

    test('projetarParcelas generates installments with cent adjustments and business day dates', () {
      final dataBase = DateTime(2026, 8, 1); // Sábado
      final parcelas = PedidoVenda.projetarParcelas(
        valorTotal: 100.00,
        dataBase: dataBase,
        prazosDias: [30, 60, 90],
      );

      expect(parcelas.length, equals(3));
      expect(parcelas[0].numero, equals(1));
      expect(parcelas[0].valor, equals(33.33));
      expect(parcelas[1].valor, equals(33.33));
      // Última parcela absorve centavos (100 - 66.66 = 33.34)
      expect(parcelas[2].valor, equals(33.34));

      // Vencimentos nunca devem cair no sábado ou domingo
      for (final p in parcelas) {
        expect(p.dataVencimento.weekday, isNot(equals(DateTime.saturday)));
        expect(p.dataVencimento.weekday, isNot(equals(DateTime.sunday)));
      }
    });

    test('carregarFeriadosLocal reads cadfer00 from SQLite', () async {
      final dbPath = p.join(await getDatabasesPath(), 'test_cadfer.db');
      final db = await openDatabase(dbPath);
      await db.execute('DROP TABLE IF EXISTS cadfer00');
      await db.execute('''
        CREATE TABLE cadfer00 (
          fer00_data TEXT PRIMARY KEY,
          fer00_descri TEXT
        )
      ''');
      await db.insert('cadfer00', {'fer00_data': '2026-12-25', 'fer00_descri': 'Natal'});
      await db.insert('cadfer00', {'fer00_data': '2026-01-01', 'fer00_descri': 'Ano Novo'});
      await db.close();

      final feriados = await PedidoVenda.carregarFeriadosLocal(dbPath: dbPath);
      expect(feriados.contains('2026-12-25'), isTrue);
      expect(feriados.contains('2026-01-01'), isTrue);
    });
  });
}
