import '../../domain/models/pedido_venda.dart';
import '../../functions/format_currency.dart';

/// PRD 1 §5A — schema alternativo PacoteVendas para retaguarda nova.
/// Mantido atrás de kEnablePacoteVendasSchema=false (legado default).
/// Estrutura exigida:
/// <PacoteVendas>
///   <Representante><Codigo>105</Codigo></Representante>
///   <Pedido><Cabecalho><CodigoPedido>99823</CodigoPedido><CodigoAgente>7</CodigoAgente><ValorTotal>1500.50</ValorTotal></Cabecalho><Itens>...</Itens></Pedido>
/// </PacoteVendas>
class PacoteVendasXmlService {
  static String generate(PedidoVenda pedido) {
    final sb = StringBuffer();
    sb.writeln('<PacoteVendas>');
    sb.writeln('  <Representante><Codigo>${pedido.codRep}</Codigo></Representante>');
    sb.writeln('  <Pedido>');
    sb.writeln('    <Cabecalho>');
    sb.writeln('      <CodigoPedido>${pedido.codMov}</CodigoPedido>');
    sb.writeln('      <CodigoAgente>${pedido.codAgt}</CodigoAgente>');
    sb.writeln('      <ValorTotal>${fmtCurrencyPac(pedido.digtot)}</ValorTotal>');
    // Campos adicionais úteis para compat
    sb.writeln('      <CodigoCliente>${pedido.codCli}</CodigoCliente>');
    sb.writeln('      <CodigoFilial>${pedido.codFil}</CodigoFilial>');
    sb.writeln('      <DataEmissao>${pedido.datSys}</DataEmissao>');
    sb.writeln('      <QuantidadeItens>${pedido.items.length}</QuantidadeItens>');
    sb.writeln('      <ValorBontot>${fmtCurrencyPac(pedido.bontot)}</ValorBontot>');
    sb.writeln('      <ValorSubtot>${fmtCurrencyPac(pedido.subtot)}</ValorSubtot>');
    sb.writeln('      <ValorFattot>${fmtCurrencyPac(pedido.fattot)}</ValorFattot>');
    sb.writeln('    </Cabecalho>');
    sb.writeln('    <Itens>');
    for (final item in pedido.items) {
      sb.writeln('      <Item>');
      sb.writeln('        <CodigoProduto>${item.digpro}</CodigoProduto>');
      sb.writeln('        <Quantidade>${fmtCurrencyPac(item.digqtd)}</Quantidade>');
      sb.writeln('        <Preco>${fmtCurrencyPac(item.digpco)}</Preco>');
      sb.writeln('        <Subtotal>${fmtCurrencyPac(item.subtot)}</Subtotal>');
      sb.writeln('        <TipoBonificacao>${item.bontyp}</TipoBonificacao>');
      sb.writeln('        <CodigoBonificacao>${item.boncod}</CodigoBonificacao>');
      sb.writeln('      </Item>');
    }
    sb.writeln('    </Itens>');
    sb.writeln('  </Pedido>');
    sb.writeln('</PacoteVendas>');
    return sb.toString();
  }
}
