import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';

/// Abre o visualizador expandido de imagem com suporte a zoom/pan e compartilhamento.
Future<void> abrirImagemPreview(
  BuildContext context, {
  required String caminhoArquivo,
  String? titulo,
  String? subtitulo,
}) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.85),
    builder: (dialogCtx) => ImagemPreviewDialog(
      caminhoArquivo: caminhoArquivo,
      titulo: titulo,
      subtitulo: subtitulo,
    ),
  );
}

/// Dialog imersivo com InteractiveViewer, zoom, pan, compartilhamento e cópia.
class ImagemPreviewDialog extends StatefulWidget {
  const ImagemPreviewDialog({
    super.key,
    required this.caminhoArquivo,
    this.titulo,
    this.subtitulo,
  });

  final String caminhoArquivo;
  final String? titulo;
  final String? subtitulo;

  @override
  State<ImagemPreviewDialog> createState() => _ImagemPreviewDialogState();
}

class _ImagemPreviewDialogState extends State<ImagemPreviewDialog> {
  final TransformationController _transformationController =
      TransformationController();

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  void _resetZoom() {
    _transformationController.value = Matrix4.identity();
  }

  Future<void> _compartilharImagem() async {
    try {
      final file = File(widget.caminhoArquivo);
      if (await file.exists()) {
        final xFile = XFile(widget.caminhoArquivo);
        final String texto = [
          if (widget.titulo != null && widget.titulo!.isNotEmpty)
            widget.titulo!,
          if (widget.subtitulo != null && widget.subtitulo!.isNotEmpty)
            widget.subtitulo!,
        ].join(' - ');

        // ignore: deprecated_member_use
        await Share.shareXFiles(
          [xFile],
          text: texto.isNotEmpty ? texto : null,
          subject: widget.titulo ?? 'Imagem do Produto',
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Arquivo de imagem não encontrado no armazenamento local.'),
            backgroundColor: Colors.orangeAccent,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao compartilhar imagem: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Future<void> _copiarDados() async {
    try {
      final texto = [
        if (widget.titulo != null && widget.titulo!.isNotEmpty)
          'Produto: ${widget.titulo}',
        if (widget.subtitulo != null && widget.subtitulo!.isNotEmpty)
          'Detalhes: ${widget.subtitulo}',
        'Arquivo: ${widget.caminhoArquivo.split('/').last}',
      ].join('\n');

      await Clipboard.setData(ClipboardData(text: texto));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Informações copiadas para a área de transferência!'),
          backgroundColor: Color(0xFF24A148),
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao copiar: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final file = File(widget.caminhoArquivo);
    final fileExists = file.existsSync();

    return Dialog.fullscreen(
      backgroundColor: Colors.black.withValues(alpha: 0.92),
      child: SafeArea(
        child: Column(
          children: [
            // Barra superior
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white, size: 26),
                    onPressed: () => Navigator.pop(context),
                    tooltip: 'Fechar',
                  ),
                  const SizedBox(width: 8.0),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (widget.titulo != null && widget.titulo!.isNotEmpty)
                          Text(
                            widget.titulo!,
                            style: GoogleFonts.outfit(
                              color: Colors.white,
                              fontSize: 17.0,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        if (widget.subtitulo != null && widget.subtitulo!.isNotEmpty)
                          Text(
                            widget.subtitulo!,
                            style: GoogleFonts.inter(
                              color: Colors.white70,
                              fontSize: 12.0,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.restart_alt_rounded, color: Colors.white70, size: 22),
                    onPressed: _resetZoom,
                    tooltip: 'Resetar Zoom',
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy_rounded, color: Colors.white, size: 22),
                    onPressed: _copiarDados,
                    tooltip: 'Copiar informações',
                  ),
                  IconButton(
                    icon: const Icon(Icons.share_rounded, color: Colors.white, size: 22),
                    onPressed: _compartilharImagem,
                    tooltip: 'Compartilhar imagem',
                  ),
                ],
              ),
            ),
            const Divider(height: 1.0, color: Colors.white24),

            // Área da imagem com InteractiveViewer (Zoom / Pan)
            Expanded(
              child: Center(
                child: !fileExists
                    ? const Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.broken_image_rounded, color: Colors.white54, size: 64),
                          SizedBox(height: 12),
                          Text(
                            'Arquivo de imagem não encontrado.',
                            style: TextStyle(color: Colors.white70),
                          ),
                        ],
                      )
                    : InteractiveViewer(
                        transformationController: _transformationController,
                        minScale: 0.5,
                        maxScale: 4.5,
                        panEnabled: true,
                        scaleEnabled: true,
                        clipBehavior: Clip.none,
                        child: Image.file(
                          file,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) {
                            return const Center(
                              child: Icon(
                                Icons.image_not_supported_outlined,
                                color: Colors.white54,
                                size: 64,
                              ),
                            );
                          },
                        ),
                      ),
              ),
            ),

            // Barra inferior com instrução e atalhos rápidos
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.pinch_rounded, color: Colors.white54, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    'Use dois dedos para zoom ou arraste para mover',
                    style: GoogleFonts.inter(
                      color: Colors.white60,
                      fontSize: 12.0,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
