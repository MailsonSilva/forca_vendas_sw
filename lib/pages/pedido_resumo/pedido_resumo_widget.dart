import '/core/app_theme.dart';
import '/core/app_util.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'pedido_resumo_model.dart';
import '/action_code/carregar_pedido_resumo.dart';
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

  String _fmt(double v) => 'R\$ ${v.toStringAsFixed(2).replaceAll('.', ',')}';

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
              IconButton(
                icon: const Icon(Icons.list_alt_rounded, color: Colors.white),
                tooltip: 'Histórico de Pedidos',
                onPressed: () => context.go('/pedidos'),
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
