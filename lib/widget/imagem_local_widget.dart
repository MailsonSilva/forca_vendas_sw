// Imports do app
// Imports other custom widgets
// Imports custom actions
// Imports custom functions
import 'package:flutter/material.dart';
// Begin custom widget code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

// Set your widget name, define your parameter, and then add the
// boilerplate code using the `</>` button on the right!

import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '/widgets/imagem_preview_dialog.dart';

class ImagemLocalWidget extends StatefulWidget {
  const ImagemLocalWidget({
    super.key,
    this.width,
    this.height,
    this.caminhoArquivo,
    this.enablePreview = true,
    this.titulo,
    this.subtitulo,
  });

  final double? width;
  final double? height;
  final String? caminhoArquivo;
  final bool enablePreview;
  final String? titulo;
  final String? subtitulo;

  @override
  State<ImagemLocalWidget> createState() => _ImagemLocalWidgetState();
}

class _ImagemLocalWidgetState extends State<ImagemLocalWidget> {
  Future<String?>? _fileCheckFuture;

  @override
  void initState() {
    super.initState();
    _initFileCheck();
  }

  // ATUALIZAÇÃO CRÍTICA: Faz o PageView/Carrossel renderizar ao deslizar
  @override
  void didUpdateWidget(ImagemLocalWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.caminhoArquivo != widget.caminhoArquivo) {
      _initFileCheck();
    }
  }

  void _initFileCheck() {
    final path = widget.caminhoArquivo;
    if (path == null || path.trim().isEmpty) {
      setState(() => _fileCheckFuture = Future.value(null));
      return;
    }

    setState(() {
      final trimmedPath = path.trim();
      String relativePath = trimmedPath;

      // O SEU CÓDIGO ORIGINAL: Trata a mudança de diretórios do Android/iOS
      if (trimmedPath.contains('app_flutter/')) {
        relativePath = trimmedPath.substring(
            trimmedPath.indexOf('app_flutter/') + 'app_flutter/'.length);
      } else if (trimmedPath.contains('Documents/')) {
        relativePath = trimmedPath
            .substring(trimmedPath.indexOf('Documents/') + 'Documents/'.length);
      }

      if (!relativePath.startsWith('/') &&
          !relativePath.contains(':\\') &&
          !relativePath.contains(':/')) {
        _fileCheckFuture = getApplicationDocumentsDirectory().then((dir) async {
          final fullPath = "${dir.path}/$relativePath";
          if (await File(fullPath).exists()) {
            return fullPath;
          }
          if (await File(trimmedPath).exists()) {
            return trimmedPath;
          }

          // Fallback: Se enviar apenas o código "1046" ou "1046_1", procura direto no catálogo
          String nomeArquivo = trimmedPath.split('/').last;
          if (!nomeArquivo.toLowerCase().endsWith('.jpg') &&
              !nomeArquivo.toLowerCase().endsWith('.png')) {
            nomeArquivo = "$nomeArquivo.jpg";
          }
          final fallbackPath =
              "${dir.path}/images/catalogo_imagens/$nomeArquivo";
          if (await File(fallbackPath).exists()) {
            return fallbackPath;
          }

          return null;
        });
      } else {
        _fileCheckFuture = File(trimmedPath).exists().then((exists) {
          return exists ? trimmedPath : null;
        });
      }
    });
  }

  Widget _buildPlaceholder() {
    return Container(
      width: widget.width ?? 120,
      height: widget.height ?? 120,
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(
        Icons.image_not_supported_outlined,
        color: Color(0xFF94A3B8),
        size: 32,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: _fileCheckFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            width: widget.width,
            height: widget.height,
            color: const Color(0xFFF1F5F9),
            child: const Center(
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Color(0xFF94A3B8)),
            ),
          );
        }
        if (snapshot.hasError || snapshot.data == null) {
          return _buildPlaceholder();
        }

        final imageWidget = ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.file(
            File(snapshot.data!),
            width: widget.width,
            height: widget.height,
            fit: BoxFit.contain,
            cacheWidth: 150,
            errorBuilder: (context, error, stackTrace) {
              return _buildPlaceholder();
            },
          ),
        );

        if (widget.enablePreview) {
          return GestureDetector(
            onTap: () {
              abrirImagemPreview(
                context,
                caminhoArquivo: snapshot.data!,
                titulo: widget.titulo,
                subtitulo: widget.subtitulo,
              );
            },
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: imageWidget,
            ),
          );
        }

        return imageWidget;
      },
    );
  }
}
