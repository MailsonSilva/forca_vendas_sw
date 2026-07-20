import '/core/app_theme.dart';
import '/core/app_util.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'pedido_resumo_model.dart';
export 'pedido_resumo_model.dart';

class PedidoResumoWidget extends StatefulWidget {
  const PedidoResumoWidget({
    super.key,
    required this.pedidoId,
  });

  final int? pedidoId;

  static String routeName = 'PedidoResumo';
  static String routePath = '/pedidoResumo';

  @override
  State<PedidoResumoWidget> createState() => _PedidoResumoWidgetState();
}

class _PedidoResumoWidgetState extends State<PedidoResumoWidget> {
  late PedidoResumoModel _model;
  final scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => PedidoResumoModel());
  }

  @override
  void dispose() {
    _model.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // Impede que o botão Voltar retorne à tela de itens após conclusão.
      // O único caminho de saída é o botão "Ir para o Menu Principal".
      canPop: false,
      child: GestureDetector(
        onTap: () {
          FocusScope.of(context).unfocus();
          FocusManager.instance.primaryFocus?.unfocus();
        },
        child: Scaffold(
          key: scaffoldKey,
          backgroundColor: AppTheme.of(context).primaryBackground,
          appBar: AppBar(
            backgroundColor: AppTheme.of(context).primary,
            automaticallyImplyLeading: false, // oculta seta voltar no AppBar
            title: Text(
              'Resumo do Pedido',
              style: AppTheme.of(context).headlineMedium.override(
                    font: GoogleFonts.plusJakartaSans(),
                    color: Colors.white,
                    fontSize: 22.0,
                  ),
            ),
            elevation: 2.0,
          ),
          body: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppTheme.of(context).secondaryBackground,
                    borderRadius: BorderRadius.circular(12.0),
                    boxShadow: [
                      BoxShadow(
                        blurRadius: 4.0,
                        color: const Color(0x1A000000),
                        offset: const Offset(0.0, 2.0),
                        spreadRadius: 0.0,
                      )
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.check_circle_rounded,
                          color: AppTheme.of(context).success,
                          size: 64.0,
                        ),
                        const SizedBox(height: 16.0),
                        Text(
                          'Pedido #${widget.pedidoId}',
                          style: AppTheme.of(context).headlineSmall.override(
                                font: GoogleFonts.outfit(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                        ),
                        const SizedBox(height: 12.0),
                        Text(
                          'Pedido salvo com sucesso! O arquivo está na fila de envio. '
                          'Para transmitir ao servidor, acesse: Ferramentas → Dados → Subir Carga.',
                          textAlign: TextAlign.center,
                          style: AppTheme.of(context).bodyMedium.override(
                                font: GoogleFonts.inter(
                                  color: AppTheme.of(context).secondaryText,
                                ),
                              ),
                        ),
                        const SizedBox(height: 24.0),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.of(context).primary,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24.0,
                                vertical: 12.0,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12.0),
                              ),
                            ),
                            icon: const Icon(Icons.home_rounded, color: Colors.white),
                            label: Text(
                              'Ir para o Menu Principal',
                              style: AppTheme.of(context).bodyLarge.override(
                                    font: GoogleFonts.inter(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                            ),
                            onPressed: () {
                              // Limpa o stack completo e vai para Home
                              context.go('/');
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

