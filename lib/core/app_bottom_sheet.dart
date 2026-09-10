import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_icon_button.dart';
import 'app_theme.dart';

/// Helper centralizado para exibição de modais (Bottom Sheets) padronizados.
///
/// Garante estritamente:
/// - `useSafeArea: true`
/// - `isScrollControlled: true`
/// - `backgroundColor: Colors.transparent`
/// - Fechamento de teclado ao tocar fora (`unfocus`)
/// - Ajuste automático de padding de teclado (`viewInsetsOf`)
Future<T?> showAppModalBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isDismissible = true,
  bool enableDrag = true,
  bool isScrollControlled = true,
  bool useSafeArea = true,
  Color backgroundColor = Colors.transparent,
  Color? barrierColor,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    useSafeArea: useSafeArea,
    isDismissible: isDismissible,
    enableDrag: enableDrag,
    backgroundColor: backgroundColor,
    barrierColor: barrierColor,
    builder: (ctx) {
      return GestureDetector(
        onTap: () {
          FocusScope.of(ctx).unfocus();
          FocusManager.instance.primaryFocus?.unfocus();
        },
        child: Padding(
          padding: MediaQuery.viewInsetsOf(ctx),
          child: builder(ctx),
        ),
      );
    },
  );
}

/// Componente visual reutilizável de Bottom Sheet padronizado.
///
/// Inspirado na estrutura do Menu de Relatórios:
/// - Barra de arraste (drag handle) no topo
/// - Cabeçalho com ícone, título e botão de fechar 'X' (AppIconButton 38x38)
/// - Linha divisória fina
/// - Cantos superiores arredondados (20px) e sombra elegante
/// - Envoltório `ConstrainedBox(maxWidth: 600.0)` para compatibilidade responsiva (tablets/desktops)
/// - `SafeArea(top: false, bottom: true)` para nunca invadir a barra de navegação nativa do aparelho
class AppBottomSheet extends StatelessWidget {
  const AppBottomSheet({
    super.key,
    required this.child,
    this.title,
    this.subtitle,
    this.icon,
    this.headerTrailing,
    this.onClose,
    this.showDragHandle = true,
    this.showCloseButton = true,
    this.maxHeightFactor = 0.85,
    this.maxHeight,
    this.padding = const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
    this.backgroundColor,
    this.isScrollable = false,
  });

  /// Conteúdo do modal.
  final Widget child;

  /// Título opcional exibido no cabeçalho.
  final String? title;

  /// Subtítulo opcional exibido logo abaixo do título.
  final String? subtitle;

  /// Ícone opcional exibido à esquerda do título.
  final Widget? icon;

  /// Widget customizado opcional no canto superior direito (substitui ou acompanha o botão fechar).
  final Widget? headerTrailing;

  /// Callback customizado ao clicar no botão fechar. Se nulo, executa `Navigator.pop(context)`.
  final VoidCallback? onClose;

  /// Se deve exibir a barra de arraste no topo.
  final bool showDragHandle;

  /// Se deve exibir o botão de fechar 'X'.
  final bool showCloseButton;

  /// Fração da altura máxima da tela ocupada pelo modal (padrão 0.85).
  final double maxHeightFactor;

  /// Altura máxima fixa opcional. Se informada, sobrepõe [maxHeightFactor].
  final double? maxHeight;

  /// Espaçamento interno do conteúdo.
  final EdgeInsetsGeometry padding;

  /// Cor de fundo do modal. Se nula, utiliza `AppTheme.of(context).primaryBackground` ou branco.
  final Color? backgroundColor;

  /// Se o child deve ser automaticamente envolvido em SingleChildScrollView.
  final bool isScrollable;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final bgColor = backgroundColor ?? theme.primaryBackground;
    final screenHeight = MediaQuery.sizeOf(context).height;
    final resolvedMaxHeight = maxHeight ?? (screenHeight * maxHeightFactor);

    final hasHeader = (title != null && title!.isNotEmpty) ||
        icon != null ||
        showCloseButton ||
        headerTrailing != null;

    Widget content = Padding(
      padding: padding,
      child: child,
    );

    if (isScrollable) {
      content = Flexible(
        fit: FlexFit.loose,
        child: SingleChildScrollView(
          child: content,
        ),
      );
    } else {
      content = Flexible(
        fit: FlexFit.loose,
        child: content,
      );
    }

    return Align(
      alignment: Alignment.bottomCenter,
      heightFactor: 1.0,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600.0),
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: double.infinity,
            constraints: BoxConstraints(
              maxHeight: resolvedMaxHeight,
            ),
            decoration: BoxDecoration(
              color: bgColor,
              boxShadow: const [
                BoxShadow(
                  blurRadius: 10.0,
                  color: Color(0x33000000),
                  offset: Offset(0.0, -2.0),
                )
              ],
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20.0),
                topRight: Radius.circular(20.0),
              ),
            ),
            child: SafeArea(
              top: false,
              bottom: true,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Barra de arraste (drag handle)
                  if (showDragHandle)
                    Padding(
                      padding: const EdgeInsets.only(top: 10.0, bottom: 4.0),
                      child: Center(
                        child: Container(
                          width: 40.0,
                          height: 4.0,
                          decoration: BoxDecoration(
                            color: Colors.grey.withValues(alpha: 0.35),
                            borderRadius: BorderRadius.circular(2.0),
                          ),
                        ),
                      ),
                    ),

                  // Cabeçalho padronizado
                  if (hasHeader) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20.0,
                        vertical: 8.0,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                if (icon != null) ...[
                                  icon!,
                                  const SizedBox(width: 8.0),
                                ],
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (title != null && title!.isNotEmpty)
                                        Text(
                                          title!,
                                          style: theme.titleLarge.override(
                                                font: GoogleFonts.outfit(
                                                  fontWeight: FontWeight.w600,
                                                ),
                                                color: theme.primaryText,
                                                fontSize: 20.0,
                                              ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      if (subtitle != null && subtitle!.isNotEmpty)
                                        Padding(
                                          padding: const EdgeInsets.only(top: 2.0),
                                          child: Text(
                                            subtitle!,
                                            style: theme.bodySmall.override(
                                                  font: GoogleFonts.inter(),
                                                  color: theme.secondaryText,
                                                  fontSize: 12.0,
                                                ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (headerTrailing != null) headerTrailing!,
                          if (showCloseButton) ...[
                            if (headerTrailing != null) const SizedBox(width: 8.0),
                            AppIconButton(
                              borderColor: const Color(0xFFE0E3E7),
                              borderRadius: 12.0,
                              borderWidth: 1.0,
                              buttonSize: 38.0,
                              icon: Icon(
                                Icons.close_rounded,
                                color: theme.primaryText,
                                size: 18.0,
                              ),
                              onPressed: () async {
                                if (onClose != null) {
                                  onClose!();
                                } else {
                                  Navigator.pop(context);
                                }
                              },
                            ),
                          ],
                        ],
                      ),
                    ),
                    const Divider(height: 1.0, thickness: 1.0),
                  ],

                  // Conteúdo do modal
                  content,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
