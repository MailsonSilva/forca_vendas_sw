import 'package:flutter_test/flutter_test.dart';
import 'package:forca_de_vendas/domain/models/pedido_venda.dart';
import 'package:forca_de_vendas/data/services/pac_xml_generator_service.dart';
import 'package:forca_de_vendas/services/concluir_venda_service.dart';
import 'package:forca_de_vendas/action_code/carregar_pedido_resumo.dart';
import 'package:forca_de_vendas/data/services/local_sales_database_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  PedidoVenda samplePedido({String observacao = ''}) {
    final pedido = PedidoVenda(
      codFil: 1,
      codMov: 42001,
      codRep: 71,
      codCli: 1542,
      codLin: 5,
      codPla: 3,
      codAgt: 71,
      datSys: '2026-09-16',
      observacao: observacao,
      items: [
        ItemPedidoVenda(
          digpro: '99901',
          digqtd: 2.0,
          digpco: 50.0,
          pcomax: 50.0,
          pcomin: 50.0,
          destot: 0.0,
          subtot: 100.0,
          bontyp: 0,
          boncod: 0,
          ccvtot: 0.0,
          digitm: 1,
        ),
      ],
    );
    pedido.calcularTotais();
    return pedido;
  }

  group('SPEC-042 - Seam 1: Observação do Pedido no Modelo e no XML', () {
    test('PedidoVenda armazena e expõe campo observacao', () {
      final pedido = samplePedido(observacao: 'ENTREGAR APOS AS 14H');
      expect(pedido.observacao, equals('ENTREGAR APOS AS 14H'));
    });

    test('PacXmlGeneratorService.generate inclui <digobs> no nó <dig00> e atributo dig00_digobs', () {
      final pedido = samplePedido(observacao: 'CLIENTE SOLICITOU BOLETO IMPRESSO');
      final xml = PacXmlGeneratorService.generate(pedido);

      // Deve incluir a tag <digobs> no nó <dig00>
      expect(xml, contains('<dig00>'));
      expect(xml, contains('<digobs>CLIENTE SOLICITOU BOLETO IMPRESSO</digobs>'));
      expect(xml, contains('</dig00>'));

      // E também conter o atributo dig00_digobs na tag do cabeçalho
      expect(xml, contains('dig00_digobs="CLIENTE SOLICITOU BOLETO IMPRESSO"'));
    });

    test('PacXmlGeneratorService.generateBatch inclui observação em cada pedido do lote', () {
      final p1 = samplePedido(observacao: 'OBS DO PEDIDO 1');
      final p2 = PedidoVenda(
        codFil: 1,
        codMov: 42002,
        codRep: 71,
        codCli: 1543,
        codLin: 5,
        codPla: 3,
        codAgt: 71,
        datSys: '2026-09-16',
        observacao: 'OBS DO PEDIDO 2',
        items: [
          ItemPedidoVenda(
            digpro: '99902',
            digqtd: 1.0,
            digpco: 20.0,
            pcomax: 20.0,
            pcomin: 20.0,
            destot: 0.0,
            subtot: 20.0,
            bontyp: 0,
            boncod: 0,
            ccvtot: 0.0,
            digitm: 1,
          ),
        ],
      );
      p2.calcularTotais();

      final xml = PacXmlGeneratorService.generateBatch([p1, p2], 71);
      expect(xml, contains('<digobs>OBS DO PEDIDO 1</digobs>'));
      expect(xml, contains('<digobs>OBS DO PEDIDO 2</digobs>'));
    });
  });

  group('SPEC-042 - Seam 1: Persistência SQLite e Leitura do Resumo', () {
    test('salvarPedidoConcluidoLocal persiste observacao em dig00_digobs e ped00_digobs', () async {
      final db = await LocalSalesDatabaseService.getDatabase();
      final service = ConcluirVendaService();
      final pedido = samplePedido(observacao: 'OBS TESTE PERSISTENCIA');

      await service.salvarPedidoConcluidoLocal(
        pedido: pedido,
        empresa: 'empresa_teste',
        codigoEquipe: 1,
      );

      final rows = await db.rawQuery(
        'SELECT ped00_digobs, dig00_digobs FROM pckvendig000 WHERE ped00_numped = ?',
        [pedido.codMov],
      );
      expect(rows.isNotEmpty, isTrue);
      final row = rows.first;
      final obsSalva = row['ped00_digobs'] ?? row['dig00_digobs'];
      expect(obsSalva, equals('OBS TESTE PERSISTENCIA'));

      // Verifica que carregarPedidoResumo lê a observação
      final resumo = await carregarPedidoResumo(pedido.codMov);
      expect(resumo, isNotNull);
      expect(resumo!.observacao, equals('OBS TESTE PERSISTENCIA'));
    });
  });
}
