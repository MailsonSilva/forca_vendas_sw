import 'package:pdf/widgets.dart' as pw;
import '../dtos/espelho_pedido_dto.dart';

/// Contrato para templates visuais do espelho de venda em PDF.
///
/// Cada implementação controla o layout visual do documento mantendo
/// a mesma estrutura de dados ([EspelhoPedidoDTO]) e regras de negócio.
abstract class IPdfOrderTemplate {
  pw.Widget buildHeader(EspelhoPedidoDTO pedido, pw.Context context, pw.Font boldFont, pw.Font regularFont);
  pw.Widget buildCustomerAndOrderInfo(EspelhoPedidoDTO pedido, pw.Font boldFont, pw.Font regularFont);
  pw.Widget buildItemsTable(List<ItemEspelhoDTO> itens, pw.Font boldFont, pw.Font regularFont);
  pw.Widget buildFinancialAndDuplicates(EspelhoPedidoDTO pedido, pw.Font boldFont, pw.Font regularFont);
  pw.Widget buildTotalsSummary(EspelhoPedidoDTO pedido, pw.Font boldFont, pw.Font regularFont);
  pw.Widget buildNotes(String observacoes, pw.Font boldFont, pw.Font regularFont);
  pw.Widget buildFooter(pw.Context context, pw.Font regularFont);
}
