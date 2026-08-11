import 'package:flutter_test/flutter_test.dart';
import 'package:forca_de_vendas/data/services/cliente_xml_generator_service.dart';
import 'package:forca_de_vendas/backend/schema/structs/cliente_result_struct.dart';
import 'package:forca_de_vendas/backend/schema/structs/banco_info_struct_struct.dart';

void main() {
  ClienteResultStruct sampleCliente() => ClienteResultStruct(
        cli00Codigo: 36109,
        cli00Descri: 'Mercado Central LTDA',
        cli00Fantas: 'Mercado Central',
        cli00Pessoa: 'J',
        cli00Cpfcnp: '12.345.678/0001-90',
        cli00Insest: '98765432',
        cli00Observ: 'cliente@exemplo.com',
        cli00Endere: 'Rua das Flores',
        cli00Endnum: '100',
        cli00Bairro: 'Centro',
        cli00Ciddes: 'Sao Paulo',
        cli00Estsgl: 'SP',
        cli00Endcep: '01000-000',
        cli00Fonddd: '11',
        cli00Fonnum: '4000-0000',
        cli00Crelim: 15000.5,
        cli02NProp: 'Joao Silva',
        bancosList: [
          BancoInfoStructStruct(
            nomeBanco: 'BANCO BRADESCO',
            ddd: '11',
            telefone: '99999-8888',
          ),
        ],
      );

  test('build() produces legacy envelope with sys_versao and rep00_codigo', () {
    final xml = ClienteXmlGeneratorService.build(sampleCliente(), '71');

    expect(xml, contains('<!DOCTYPE suportware>'));
    expect(xml, contains('<root sys_versao="1.0" rep00_codigo="71">'));
    expect(xml, contains('<pckvencli00>'));
    expect(xml, contains('</pckvencli00>'));
    expect(xml, contains('</root>'));
  });

  test('build() maps cli00 fields and bank references', () {
    final xml = ClienteXmlGeneratorService.build(sampleCliente(), '71');

    expect(xml, contains('cli00_codigo="36109"'));
    expect(xml, contains('cli00_codigoRep="71"'));
    expect(xml, contains('cli00_rSocial="Mercado Central LTDA"'));
    expect(xml, contains('cli00_cpfcnpj="12.345.678/0001-90"'));
    expect(xml, contains('cli00_limite="15000.50"'));
    expect(xml, contains('cli00_nBnc1Ban="BANCO BRADESCO"'));
    expect(xml, contains('cli00_dddBnc1Ban="11"'));
    expect(xml, contains('cli00_foneBnc1Ban="99999-8888"'));
    expect(xml, contains('cli00_foneBnc2Ban=""'));
  });

  test('build() treats codigo 0/null as new client (inclusao)', () {
    final novo = sampleCliente()..cli00Codigo = 0;
    final xml = ClienteXmlGeneratorService.build(novo, '71');

    expect(xml, contains('cli00_codigo="0"'));
  });
}
