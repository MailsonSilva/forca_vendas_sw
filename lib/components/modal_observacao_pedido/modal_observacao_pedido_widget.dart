import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/app_bottom_sheet.dart';
import '../../core/app_theme.dart';

/// Modal para preenchimento de observação do pedido (dig00_digobs)
/// Acionado compulsoriamente no fechamento, imediatamente após a seleção do agente cobrador.
class ModalObservacaoPedidoWidget extends StatefulWidget {
  const ModalObservacaoPedidoWidget({
    super.key,
    this.observacaoInicial = '',
  });

  final String observacaoInicial;

  static Future<String?> show(BuildContext context, {String observacaoInicial = ''}) {
    return showAppModalBottomSheet<String?>(
      context: context,
      builder: (ctx) => ModalObservacaoPedidoWidget(
        observacaoInicial: observacaoInicial,
      ),
    );
  }

  @override
  State<ModalObservacaoPedidoWidget> createState() => _ModalObservacaoPedidoWidgetState();
}

class _ModalObservacaoPedidoWidgetState extends State<ModalObservacaoPedidoWidget> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.observacaoInicial);
    _focusNode = FocusNode();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _confirmar() {
    final texto = _controller.text.trim();
    Navigator.of(context).pop(texto);
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);

    return AppBottomSheet(
      title: 'Observação do Pedido',
      subtitle: 'Instruções comerciais ou de entrega (limite: 500 caracteres)',
      icon: Icon(
        Icons.edit_note_rounded,
        color: theme.primary,
        size: 26.0,
      ),
      isScrollable: true,
      maxHeightFactor: 0.75,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 8.0),
          TextField(
            controller: _controller,
            focusNode: _focusNode,
            autofocus: true,
            maxLines: 4,
            minLines: 3,
            maxLength: 500,
            textCapitalization: TextCapitalization.characters,
            style: theme.bodyMedium.override(
              font: GoogleFonts.inter(),
              fontSize: 14.0,
            ),
            decoration: InputDecoration(
              hintText: 'Ex: ENTREGAR APÓS AS 14H, BOLETO FIXO COM VENCIMENTO...',
              hintStyle: theme.bodyMedium.override(
                font: GoogleFonts.inter(),
                color: theme.secondaryText,
                fontSize: 13.0,
              ),
              filled: true,
              fillColor: Colors.grey.withValues(alpha: 0.06),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.0),
                borderSide: BorderSide(color: theme.alternate),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.0),
                borderSide: BorderSide(color: theme.alternate),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.0),
                borderSide: BorderSide(color: theme.primary, width: 2.0),
              ),
              contentPadding: const EdgeInsets.all(14.0),
            ),
          ),
          const SizedBox(height: 16.0),
          Row(
            children: [
              Expanded(
                flex: 1,
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(null),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14.0),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.0),
                    ),
                    side: BorderSide(color: theme.alternate),
                  ),
                  child: Text(
                    'Cancelar',
                    style: theme.bodyMedium.override(
                      font: GoogleFonts.inter(fontWeight: FontWeight.w600),
                      color: theme.secondaryText,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12.0),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: _confirmar,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14.0),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.0),
                    ),
                    elevation: 1.0,
                  ),
                  child: Text(
                    'Confirmar e Concluir',
                    style: theme.bodyMedium.override(
                      font: GoogleFonts.inter(fontWeight: FontWeight.bold),
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8.0),
        ],
      ),
    );
  }
}
