import 'package:intl/intl.dart';
import '../../backend/schema/structs/index.dart';
import '../../core/app_functions.dart';
import '../../app_state.dart';
import '../../domain/models/pedido_venda.dart';
import '../../services/concluir_venda_service.dart';
import 'salvar_carrinho_pedido.dart';

Future<bool> concluirVendaProcess({
  required int pedidoId,
  required int clienteCodigo,
  required String? linhaCodigo,
  required String? planoCodigo,
  required List<ItemPedidoStruct> carrinhoItens,
}) async {
  try {
    // 1. Validação
    if (carrinhoItens.isEmpty) {
      print('Erro: Carrinho vazio! Não é possível concluir a venda.');
      return false;
    }

    final String datSys = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final int codRep = AppState().vendedor_codigo;
    final int codFil = resolverCodFilial(AppState().empresa_codigo) ?? 1;
    final int codEqp = AppState().vendedor_equipe;

    // 2. Mapeamento para os modelos de domínio
    final List<ItemPedidoVenda> itemsVenda = [];
    for (int i = 0; i < carrinhoItens.length; i++) {
      final item = carrinhoItens[i];
      final isBon = item.isBonificacao;
      itemsVenda.add(
        ItemPedidoVenda(
          digpro: item.codigoProduto,
          digqtd: isBon ? item.quantidadeBonificada : item.quantidade,
          digpco: item.precoUnitario,
          pcomax: item.precoUnitario,
          pcomin: item.precoUnitario,
          destot: 0.0,
          subtot: isBon ? 0.0 : item.totalItem,
          bontyp: isBon ? 1 : 0,
          boncod: isBon ? (int.tryParse(item.codigoCombo) ?? 1) : 0,
          ccvtot: isBon ? item.totalItem : 0.0,
          digitm: i + 1,
        ),
      );
    }

    final pedido = PedidoVenda(
      codFil: codFil,
      codMov: pedidoId,
      codRep: codRep,
      codCli: clienteCodigo,
      codLin: int.tryParse(linhaCodigo ?? '') ?? 0,
      codPla: int.tryParse(planoCodigo ?? '') ?? 0,
      codAgt: codRep,
      codReg: codRep,
      datSys: datSys,
      items: itemsVenda,
    );

    // 3. Salva os itens do carrinho no SQLite
    final savedOk = await salvarCarrinhoPedido(
      pedidoId: pedidoId,
      clienteCodigo: clienteCodigo,
      linhaCodigo: linhaCodigo,
      planoCodigo: planoCodigo,
      carrinhoItens: carrinhoItens,
    );

    if (!savedOk) {
      print('Erro: Falha ao salvar o carrinho no SQLite.');
      return false;
    }

    // 4. Gera e salva o arquivo XML localmente (temp/ + documents/).
    //    NÃO realiza upload FTP aqui.
    //    O envio é feito exclusivamente via: Ferramentas → Dados → Subir Carga.
    final String empresa = AppState().empresa_codigo.trim().isEmpty
        ? 'diniz'
        : AppState().empresa_codigo.trim();

    final concluirService = ConcluirVendaService();
    await concluirService.gerarESalvarPedidoLocal(
      pedido: pedido,
      empresa: empresa,
      codigoEquipe: codEqp,
    );

    return true;
  } catch (e) {
    print('Erro crítico ao concluir a venda: $e');
    return false;
  }
}

