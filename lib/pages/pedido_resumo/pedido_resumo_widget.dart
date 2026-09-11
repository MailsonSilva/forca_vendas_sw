import '/core/app_theme.dart';
import '/core/app_util.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:printing/printing.dart';
import 'pedido_resumo_model.dart';
import '/action_code/carregar_pedido_resumo.dart';
import '../../modules/pdf/dtos/espelho_pedido_dto.dart';
import '../../modules/pdf/services/carregar_espelho_pedido_service.dart';
import '../../modules/pdf/services/pdf_generator_service.dart';
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

  PedidoResumoData? _dados;
  bool _loading = true;
  bool _gerandoPdf = false;

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => PedidoResumoModel());
    _carregar();
  }

  Future<void> _carregar() async {
    if (widget.pedidoId == null) {
      setState(() => _loading = false);
      return;
    }
    final d = await carregarPedidoResumo(widget.pedidoId!);
    if (!mounted) return;
    setState(() {
      _dados = d;
      _loading = false;
    });
  }

  Future<void> _abrirOpcoesPdf() async {
    if (widget.pedidoId == null) return;
    if (_dados == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aguarde o carregamento do pedido...')),
      );
      return;
    }

    setState(() => _gerandoPdf = true);
    EspelhoPedidoDTO? espelho;
    try {
      espelho = await carregarEspelhoPedido(widget.pedidoId!);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar dados do espelho: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _gerandoPdf = false);
    }

    if (espelho == null || !mounted) {
      if (mounted && espelho == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Dados do pedido não encontrados para gerar o PDF.')),
        );
      }
      return;
    }

    FiltroItensPdf filtroSelecionado = FiltroItensPdf.todos;
    final hasCortes = espelho.itens.any((i) => i.corte > 0);
    final hasBonif = espelho.itens.any((i) => i.isBonificacao);

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (bottomContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            Widget buildFiltroOption(String title, String subtitle, FiltroItensPdf value) {
              final isSelected = filtroSelecionado == value;
              final primaryColor = AppTheme.of(context).primary;
                      return InkWell(
                        onTap: () => setModalState(() => filtroSelecionado = value),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 3),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected ? primaryColor.withValues(alpha: 0.08) : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isSelected ? primaryColor : Colors.grey[300]!,
                              width: isSelected ? 1.5 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                                color: isSelected ? primaryColor : Colors.grey[600],
                                size: 20,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(title, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.w600, fontSize: 14)),
                                    Text(subtitle, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    return SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Center(
                              child: Container(
                                width: 40,
                                height: 4,
                                decoration: BoxDecoration(
                                  color: Colors.grey[300],
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Icon(Icons.picture_as_pdf_rounded, color: AppTheme.of(context).primary, size: 26),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Espelho do Pedido #${widget.pedidoId}',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Filtre os itens e escolha como deseja emitir o PDF:',
                              style: TextStyle(color: Colors.grey[600], fontSize: 13),
                            ),
                            const Divider(height: 16),

                            buildFiltroOption(
                              'Todos os itens (Padrão)',
                              '${espelho!.itens.length} itens no pedido',
                              FiltroItensPdf.todos,
                            ),
                            if (hasCortes)
                              buildFiltroOption(
                                'Apenas cortes de estoque',
                                'Itens que sofreram corte parcial ou total',
                                FiltroItensPdf.apenasCortes,
                              ),
                            if (hasCortes)
                              buildFiltroOption(
                                'Sem cortes (Itens faturados)',
                                'Apenas produtos liberados/faturados',
                                FiltroItensPdf.semCortes,
                              ),
                            if (hasBonif)
                              buildFiltroOption(
                                'Apenas bonificações',
                                'Apenas produtos bonificados/brinde',
                                FiltroItensPdf.apenasBonificados,
                              ),

                            const SizedBox(height: 14),

                    ElevatedButton.icon(
                      icon: const Icon(Icons.share_rounded, color: Colors.white),
                      label: const Text('Compartilhar PDF (WhatsApp / Email)', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.of(context).primary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () {
                        Navigator.pop(bottomContext);
                        _executarCompartilhamento(espelho!, filtroSelecionado);
                      },
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      icon: Icon(Icons.print_rounded, color: AppTheme.of(context).primary),
                      label: Text('Visualizar / Imprimir', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.of(context).primary)),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: AppTheme.of(context).primary),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () {
                        Navigator.pop(bottomContext);
                        _executarVisualizacaoImpressao(espelho!, filtroSelecionado);
                      },
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _executarCompartilhamento(EspelhoPedidoDTO espelho, FiltroItensPdf filtro) async {
    setState(() => _gerandoPdf = true);
    try {
      final service = PdfGeneratorService();
      await service.shareOrderPdf(pedido: espelho, filtro: filtro);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao compartilhar PDF: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _gerandoPdf = false);
    }
  }

  Future<void> _executarVisualizacaoImpressao(EspelhoPedidoDTO espelho, FiltroItensPdf filtro) async {
    setState(() => _gerandoPdf = true);
    try {
      final service = PdfGeneratorService();
      await Printing.layoutPdf(
        onLayout: (format) => service.generateOrderPdf(
          pedido: espelho,
          filtro: filtro,
          pageFormat: format,
        ),
        name: 'Pedido_${espelho.numeroPedido}',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao abrir visualização do PDF: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _gerandoPdf = false);
    }
  }

  String _fmt(double v) => v.toMoeda();

  Widget _linha(String label, String value, {bool bold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey[700],
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: bold ? FontWeight.bold : FontWeight.w500,
                color: color ?? AppTheme.of(context).primaryText,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _model.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
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
            automaticallyImplyLeading: true,
            iconTheme: const IconThemeData(color: Colors.white),
            title: Text(
              'Extrato do Pedido',
              style: AppTheme.of(context).headlineMedium.override(
                    font: GoogleFonts.plusJakartaSans(),
                    color: Colors.white,
                    fontSize: 20.0,
                  ),
            ),
            elevation: 2.0,
            actions: [
              if (_gerandoPdf)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.0),
                  child: Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    ),
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: TextButton.icon(
                    onPressed: _abrirOpcoesPdf,
                    icon: const Icon(Icons.picture_as_pdf_rounded, color: Colors.white, size: 22),
                    label: const Text(
                      'PDF',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          body: SafeArea(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: AppTheme.of(context).secondaryBackground,
                            borderRadius: BorderRadius.circular(14.0),
                            boxShadow: const [
                              BoxShadow(
                                blurRadius: 4.0,
                                color: Color(0x1A000000),
                                offset: Offset(0.0, 2.0),
                              )
                            ],
                          ),
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Center(
                                child: Column(
                                  children: [
                                    Icon(Icons.check_circle_rounded, color: AppTheme.of(context).success, size: 52.0),
                                    const SizedBox(height: 6.0),
                                    Text(
                                      'Pedido #${widget.pedidoId}',
                                      style: AppTheme.of(context).headlineSmall.override(
                                            font: GoogleFonts.outfit(fontWeight: FontWeight.bold),
                                          ),
                                    ),
                                    const SizedBox(height: 2.0),
                                    Text(
                                      'Pedido registrado com sucesso!',
                                      style: TextStyle(color: AppTheme.of(context).success, fontWeight: FontWeight.w600, fontSize: 13.0),
                                    ),
                                  ],
                                ),
                              ),
                              const Divider(height: 24),
                              if (_dados != null) ...[
                                const Text('DADOS DO PEDIDO', style: TextStyle(color: Colors.grey, fontSize: 11.0, fontWeight: FontWeight.bold, letterSpacing: 0.8)),
                                const SizedBox(height: 6.0),
                                _linha('1. Nº Pedido:', '${_dados!.numeroPedido}', bold: true),
                                _linha('2. Data Emissão:', _dados!.dataEmissao.isNotEmpty ? _dados!.dataEmissao : DateTime.now().toString().split(' ').first),
                                _linha('3. Cliente:', '${_dados!.clienteCodigo} - ${_dados!.clienteNome}'),
                                _linha('4. Plano de Pagamento:', '${_dados!.planoCodigo} - ${_dados!.planoDescricao}'),
                                _linha('5. Linha de Produto:', '${_dados!.linhaCodigo} - ${_dados!.linhaDescricao}'),
                                _linha('6. Agente Cobrador:', _dados!.agenteCodigo.isNotEmpty ? '${_dados!.agenteCodigo} - ${_dados!.agenteDescricao}' : '—'),
                                _linha('7. Qtd. de Itens:', '${_dados!.quantidadeItens}'),

                                const Divider(height: 20),
                                const Text('VALORES FINANCEIROS', style: TextStyle(color: Colors.grey, fontSize: 11.0, fontWeight: FontWeight.bold, letterSpacing: 0.8)),
                                const SizedBox(height: 6.0),
                                _linha('8. Valor Produtos:', _fmt(_dados!.valorProdutos)),
                                _linha('9. Valor Substituição (ST):', _fmt(_dados!.valorSubstituicao)),
                                _linha('10. Valor Bonificação:', _fmt(_dados!.valorBonus)),
                                _linha(
                                  '11. Total da Fatura:',
                                  _fmt(_dados!.totalFatura),
                                  bold: true,
                                  color: AppTheme.of(context).primary,
                                ),
                                const SizedBox(height: 6.0),
                                if (_dados!.observacao.isNotEmpty)
                                  _linha('12. Observação:', _dados!.observacao)
                                else
                                  _linha('12. Observação:', 'Nenhuma observação registrada.'),
                              ] else
                                const Center(
                                  child: Padding(
                                    padding: EdgeInsets.all(16.0),
                                    child: Text('Detalhes do pedido não encontrados no banco local.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16.0),

                        // Botão 1: Ver Histórico de Pedidos / Criar Pacote
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.receipt_long_rounded, color: Colors.white),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.of(context).primary,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
                            ),
                            onPressed: () => context.go('/pedidos'),
                            label: const Text('Ver Histórico de Pedidos (Empacotar)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                          ),
                        ),
                        const SizedBox(height: 10.0),

                        // Botão 2: Novo Pedido
                        SizedBox(
                          width: double.infinity,
                          height: 46,
                          child: OutlinedButton.icon(
                            icon: Icon(Icons.add_shopping_cart_rounded, color: AppTheme.of(context).primary),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: AppTheme.of(context).primary),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
                            ),
                            onPressed: () => context.pushNamed('PedidoNovoInicio'),
                            label: Text('Digitar Novo Pedido', style: TextStyle(color: AppTheme.of(context).primary, fontWeight: FontWeight.bold)),
                          ),
                        ),
                        const SizedBox(height: 10.0),

                        // Botão 3: Menu Principal
                        SizedBox(
                          width: double.infinity,
                          child: TextButton(
                            onPressed: () => context.go('/homePage'),
                            child: Text('Ir para o Menu Principal', style: TextStyle(color: Colors.grey[700], fontWeight: FontWeight.w600)),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
