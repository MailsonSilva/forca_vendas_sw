import '../domain/models/cliente_novo_model.dart';

/// Serviço responsável pela formatação XML de novos clientes e sincronização FTP (fcfPUTCAD = 10)
class ClienteFtpSyncService {
  /// Gera o XML estruturado do novo cliente conforme protocolo oficial legado
  static String gerarXmlNovoCliente({
    required ClienteNovo cliente,
    required String codVendedor,
  }) {
    final rep = codVendedor.trim();
    final rSocial = cliente.razaoSocial.toUpperCase().trim();
    final nFantasia = cliente.nomeFantasia.trim();
    final cpfCnpj = cliente.cpfCnpj.replaceAll(RegExp(r'\D'), '');
    final endereco = cliente.endereco.trim();
    final cidade = cliente.cidade.trim();
    final uf = cliente.uf.trim();
    final cep = cliente.cep.replaceAll(RegExp(r'\D'), '');
    final ddd = cliente.ddd.replaceAll(RegExp(r'\D'), '');
    final telefone = cliente.telefone.replaceAll(RegExp(r'\D'), '');

    final StringBuffer xml = StringBuffer();
    xml.writeln('<?xml version="1.0" encoding="UTF-8"?>');
    xml.writeln('<cadcli00>');
    xml.writeln('  <cli00_codrep>$rep</cli00_codrep>');
    xml.writeln('  <cli00_descri>$rSocial</cli00_descri>');
    xml.writeln('  <cli00_fantas>$nFantasia</cli00_fantas>');
    xml.writeln('  <cli00_cpfcnp>$cpfCnpj</cli00_cpfcnp>');
    xml.writeln('  <cli00_endere>$endereco</cli00_endere>');
    xml.writeln('  <cli00_ciddes>$cidade</cli00_ciddes>');
    xml.writeln('  <cli00_estsgl>$uf</cli00_estsgl>');
    xml.writeln('  <cli00_endcep>$cep</cli00_endcep>');
    xml.writeln('  <cli00_fonddd>$ddd</cli00_fonddd>');
    xml.writeln('  <cli00_fonnum>$telefone</cli00_fonnum>');
    xml.writeln('</cadcli00>');

    return xml.toString();
  }
}
