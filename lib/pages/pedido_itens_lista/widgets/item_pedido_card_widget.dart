import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '/core/app_theme.dart';
import '/backend/schema/structs/item_pedido_struct.dart';
import '/widget/imagem_local_widget.dart';

/// Card de exibição do item de pedido na tela de Digitação do Pedido.
///
/// Layout:
/// ┌──────────────────────────────────────┐
/// │ [Foto]  ABA LATERAL TANQUE BROS-125/150 PT 09/13    [🗑] │
/// │            Marca: HONDA  |  Ref: 17500-KRE-B00                         │
/// │            Emb: PC              |  EAN: 7891000241501                      │
/// │                                                                                R$ 51,03 ✏│
/// │ [-] 1 [+]                                                               Total R$ 51,03│
/// └──────────────────────────────────────┘
class ItemPedidoCardWidget extends StatelessWidget {
  const ItemPedidoCardWidget({
    super.key,
    required this.item,
    required this.onRemover,
    required this.onIncrementar,
    required this.onDecrementar,
    required this.onEditarPreco,
    this.pedidoDigitado = false,
  });

  final ItemPedidoStruct item;
  final VoidCallback onRemover;
  final VoidCallback onIncrementar;
  final VoidCallback onDecrementar;
  final VoidCallback onEditarPreco;
  final bool pedidoDigitado;

  String _formatCurrency(double val) {
    return 'R\$ ${val.toStringAsFixed(2).replaceAll('.', ',')}';
  }

  @override
  Widget build(BuildContext context) {
    final marcaTexto = item.marca.trim().isNotEmpty ? item.marca.trim() : 'SEM MARCA';
    final refTexto = item.referencia.trim().isNotEmpty ? item.referencia.trim() : 'N/A';
    final embTexto = item.embalagem.trim().isNotEmpty ? item.embalagem.trim() : (item.unidade.trim().isNotEmpty ? item.unidade.trim() : 'UN');
    final eanTexto = item.codbar.trim();

    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 12.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Linha 1: Foto + Título + Lixeira
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 50.0,
                  height: 50.0,
                  child: ImagemLocalWidget(
                    width: 50.0,
                    height: 50.0,
                    caminhoArquivo: item.codigoProduto,
                    titulo: item.descricao,
                    subtitulo: 'Cód: ${item.codigoProduto} • ${_formatCurrency(item.precoUnitario)}',
                    enablePreview: true,
                  ),
                ),
                const SizedBox(width: 12.0),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (item.isBonificacao)
                        Container(
                          margin: const EdgeInsets.only(bottom: 4.0),
                          padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.0),
                          decoration: BoxDecoration(
                            color: Colors.green[100],
                            borderRadius: BorderRadius.circular(4.0),
                          ),
                          child: Text(
                            'BONIFICAÇÃO',
                            style: GoogleFonts.inter(
                              color: Colors.green[800],
                              fontWeight: FontWeight.bold,
                              fontSize: 10.0,
                            ),
                          ),
                        ),
                      Text(
                        item.descricao,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.0),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4.0),
                      // Linha 2: Marca: HONDA  |  Ref: 17500-KRE-B00
                      Row(
                        mainAxisSize: MainAxisSize.max,
                        children: [
                          Text(
                            'Marca: $marcaTexto',
                            style: GoogleFonts.inter(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF57636C),
                            ),
                          ),
                          const Text(
                            '  |  ',
                            style: TextStyle(color: Color(0xFFD0D7DE), fontSize: 11.5),
                          ),
                          Expanded(
                            child: Text(
                              'Ref: $refTexto',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w500,
                                color: const Color(0xFF57636C),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2.0),
                      // Linha 3: Emb: PC  |  EAN: 7891000241501
                      Row(
                        mainAxisSize: MainAxisSize.max,
                        children: [
                          Text(
                            'Emb: $embTexto',
                            style: GoogleFonts.inter(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFF57636C),
                            ),
                          ),
                          if (eanTexto.isNotEmpty) ...[
                            const Text(
                              '  |  ',
                              style: TextStyle(color: Color(0xFFD0D7DE), fontSize: 11.5),
                            ),
                            Expanded(
                              child: Text(
                                'EAN: $eanTexto',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.inter(
                                  fontSize: 11.0,
                                  fontWeight: FontWeight.w500,
                                  color: const Color(0xFF57636C),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: onRemover,
                ),
              ],
            ),
            const SizedBox(height: 8.0),
            // Linha 4: Preço unitário alinhado à direita com caneta de edição
            Align(
              alignment: Alignment.centerRight,
              child: InkWell(
                onTap: onEditarPreco,
                borderRadius: BorderRadius.circular(6.0),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 2.0),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        item.isBonificacao ? 'R\$ 0,00' : _formatCurrency(item.precoUnitario),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14.0,
                          color: item.isBonificacao ? Colors.black87 : AppTheme.of(context).primary,
                        ),
                      ),
                      if (!item.isBonificacao && !pedidoDigitado) ...[
                        const SizedBox(width: 4),
                        Icon(Icons.edit_outlined, size: 14, color: AppTheme.of(context).primary),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6.0),
            // Linha 5: [-] 1 [+] no lado esquerdo, Total R$ 51,03 no lado direito
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (item.isBonificacao)
                  Text(
                    'Qtd: ${item.quantidadeBonificada.toInt()}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16.0),
                  )
                else
                  Row(
                    children: [
                      Container(
                        decoration: BoxDecoration(color: const Color(0xFFAED5E6), borderRadius: BorderRadius.circular(8.0)),
                        child: IconButton(
                          icon: const Icon(Icons.remove, color: Colors.white),
                          onPressed: onDecrementar,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                        ),
                      ),
                      Container(
                        constraints: const BoxConstraints(minWidth: 40.0),
                        alignment: Alignment.center,
                        child: Text('${item.quantidade.toInt()}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16.0)),
                      ),
                      Container(
                        decoration: BoxDecoration(color: const Color(0xFF0288D1), borderRadius: BorderRadius.circular(8.0)),
                        child: IconButton(
                          icon: const Icon(Icons.add, color: Colors.white),
                          onPressed: onIncrementar,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                        ),
                      ),
                    ],
                  ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    const Text('Total ', style: TextStyle(color: Colors.grey, fontSize: 12.0)),
                    Text(
                      item.isBonificacao ? 'R\$ 0,00' : _formatCurrency(item.totalItem),
                      style: TextStyle(color: AppTheme.of(context).primary, fontWeight: FontWeight.bold, fontSize: 16.0),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
