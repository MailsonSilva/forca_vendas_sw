import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/app_theme.dart';
import '../../core/app_icon_button.dart';
import '../../core/app_util.dart';
import '../../index.dart';
import '../../services/receber_duplicatas_service.dart';

/// Modal deslizante (Sliding BottomSheet) do Extrato Detalhado de Duplicatas (ffrmrelrecdup01)
class ExtratoDuplicatasWidget extends StatefulWidget {
  final ClienteReceberItem? clienteInicial;
  final int? codigoCliente;

  const ExtratoDuplicatasWidget({
    super.key,
    this.clienteInicial,
    this.codigoCliente,
  });

  /// Método estático utilitário para abrir o BottomSheet facilmente
  static Future<void> show(
    BuildContext context, {
    ClienteReceberItem? cliente,
    int? codigoCliente,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ExtratoDuplicatasWidget(
        clienteInicial: cliente,
        codigoCliente: codigoCliente,
      ),
    );
  }

  @override
  State<ExtratoDuplicatasWidget> createState() => _ExtratoDuplicatasWidgetState();
}

class _ExtratoDuplicatasWidgetState extends State<ExtratoDuplicatasWidget> {
  bool _isLoading = false;
  ClienteReceberItem? _cliente;

  @override
  void initState() {
    super.initState();
    if (widget.clienteInicial != null) {
      _cliente = widget.clienteInicial;
    } else if (widget.codigoCliente != null) {
      _carregarCliente(widget.codigoCliente!);
    }
  }

  Future<void> _carregarCliente(int codCli) async {
    setState(() => _isLoading = true);
    final codRep = AppState().vendedor_codigo;
    final taxaJuros = await ReceberDuplicatasService.obterTaxaJurosVendedor(codRep);
    final lista = await ReceberDuplicatasService.listarClientesComDebito(
      busca: codCli.toString(),
      taxaJurosOverride: taxaJuros,
    );
    if (mounted) {
      setState(() {
        _cliente = lista.isNotEmpty ? lista.firstWhere((c) => c.codCli == codCli, orElse: () => lista.first) : null;
        _isLoading = false;
      });
    }
  }

  void _abrirMenuCompartilhamento() {
    if (_cliente == null) return;
    final nomeVendedor = AppState().vendedor_nome;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600.0),
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: SafeArea(
              top: false,
              bottom: true,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 48,
                        height: 5,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE0E3E7),
                          borderRadius: BorderRadius.circular(2.5),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.share_rounded,
                              color: Color(0xFF0288D1),
                              size: 24.0,
                            ),
                            const SizedBox(width: 8.0),
                            Text(
                              'Compartilhar Extrato',
                              style: GoogleFonts.inter(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF14181B),
                              ),
                            ),
                          ],
                        ),
                        AppIconButton(
                          borderColor: Colors.transparent,
                          borderRadius: 20.0,
                          borderWidth: 1.0,
                          buttonSize: 38.0,
                          fillColor: const Color(0xFFF1F4F8),
                          icon: const Icon(
                            Icons.close_rounded,
                            color: Color(0xFF57636C),
                            size: 20.0,
                          ),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Divider(height: 1.0, thickness: 1.0, color: Color(0xFFE0E3E7)),
                    const SizedBox(height: 16),
                    Text(
                      'Envie a cobrança amigável diretamente para o cliente:',
                      style: GoogleFonts.inter(fontSize: 14, color: Colors.black54),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.chat_bubble_outline_rounded, color: Colors.white),
                      label: Text(
                        'Enviar via WhatsApp',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 15),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF25D366),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () {
                        Navigator.pop(ctx);
                        ReceberDuplicatasService.compartilharWhatsApp(
                          context,
                          _cliente!,
                          nomeVendedor: nomeVendedor,
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.copy_rounded, color: Colors.black87),
                      label: Text(
                        'Copiar Texto do Extrato',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 15, color: Colors.black87),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        side: BorderSide(color: Colors.grey.shade400),
                      ),
                      onPressed: () {
                        Navigator.pop(ctx);
                        ReceberDuplicatasService.copiarClipboard(
                          context,
                          _cliente!,
                          nomeVendedor: nomeVendedor,
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _iniciarPedidoComCliente() async {
    if (_cliente == null) return;

    // Barreira de Checkout (Fluxo 3): Se o cliente possui títulos vencidos
    if (_cliente!.totalVencido > 0) {
      final bool? confirmar = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
              SizedBox(width: 8),
              Expanded(child: Text('Atenção: Cliente com Débitos')),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'O cliente (${_cliente!.codCli}) ${_cliente!.razaoSocial} possui títulos em atraso somando ${ReceberDuplicatasService.formatarMoeda(_cliente!.totalVencido)}.',
                style: GoogleFonts.inter(fontSize: 14, height: 1.4),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Text(
                  'Deseja auditar os títulos e assumir a responsabilidade de liberação para digitar um novo pedido?',
                  style: GoogleFonts.inter(fontSize: 13, color: Colors.red.shade900, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.of(context).primary,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Liberar e Iniciar Pedido'),
            ),
          ],
        ),
      );

      if (confirmar != true) return;
    }

    if (mounted) {
      Navigator.pop(context);
      context.pushNamed(PedidoNovoInicioWidget.routeName);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.45,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return SafeArea(
          top: false,
          bottom: true,
          child: Container(
          decoration: const BoxDecoration(
            color: Color(0xFFF8F9FA),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24.0)),
          ),
          child: Column(
            children: [
              // Barra de arraste
              const SizedBox(height: 12),
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2.5),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Cabeçalho
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: theme.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(Icons.receipt_long_rounded, color: theme.primary, size: 24),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Extrato de Duplicatas',
                              style: GoogleFonts.inter(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF1E293B),
                              ),
                            ),
                            Text(
                              'Auditoria financeira offline',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    AppIconButton(
                      borderColor: Colors.transparent,
                      borderRadius: 20.0,
                      borderWidth: 1.0,
                      buttonSize: 38.0,
                      fillColor: const Color(0xFFF1F4F8),
                      icon: const Icon(
                        Icons.close_rounded,
                        color: Color(0xFF57636C),
                        size: 20.0,
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(height: 24),

              // Conteúdo rolável
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _cliente == null
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24.0),
                              child: Text(
                                'Nenhuma duplicata em aberto encontrada para este cliente.',
                                style: GoogleFonts.inter(fontSize: 15, color: Colors.grey.shade600),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          )
                        : ListView(
                            controller: scrollController,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                            children: [
                              // Cartão de Informações do Cliente
                              _buildClientInfoCard(theme),
                              const SizedBox(height: 16),

                              // Grade de Totais Financeiros
                              _buildFinancialSummaryGrid(theme),
                              const SizedBox(height: 20),

                              // Seção de Lista de Duplicatas
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Títulos em Aberto (${_cliente!.titulos.length})',
                                    style: GoogleFonts.inter(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF1E293B),
                                    ),
                                  ),
                                  if (_cliente!.totalJuros > 0)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.orange.shade50,
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: Colors.orange.shade200),
                                      ),
                                      child: Text(
                                        'Juros: ${ReceberDuplicatasService.formatarMoeda(_cliente!.totalJuros)}',
                                        style: GoogleFonts.inter(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.orange.shade900,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 12),

                              // Itens individuais de duplicata
                              ..._cliente!.titulos.map((t) => _buildTituloCard(t, theme)),
                              const SizedBox(height: 24),
                            ],
                          ),
              ),

              // Barra fixa inferior de ações
              if (_cliente != null)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 10,
                        offset: const Offset(0, -4),
                      ),
                    ],
                  ),
                  child: SafeArea(
                    top: false,
                    child: Row(
                      children: [
                        Expanded(
                          flex: 1,
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.share_outlined, size: 20),
                            label: Text(
                              'Compartilhar',
                              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: theme.primary,
                              side: BorderSide(color: theme.primary),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: _abrirMenuCompartilhamento,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 1,
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.shopping_cart_checkout_rounded, size: 20),
                            label: Text(
                              'Novo Pedido',
                              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: theme.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: _iniciarPedidoComCliente,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        );
      },
    );
  }

  Widget _buildClientInfoCard(AppTheme theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Cód: ${_cliente!.codCli}',
                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _cliente!.razaoSocial,
                  style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          if (_cliente!.fantasia.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              _cliente!.fantasia,
              style: GoogleFonts.inter(fontSize: 13, color: Colors.grey.shade600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          if (_cliente!.cidadeUf.isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.location_on_outlined, size: 14, color: Colors.grey.shade500),
                const SizedBox(width: 4),
                Text(
                  _cliente!.cidadeUf,
                  style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFinancialSummaryGrid(AppTheme theme) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildSummaryBox(
                titulo: 'Total Vencido',
                valor: ReceberDuplicatasService.formatarMoeda(_cliente!.totalVencido),
                subtitulo: _cliente!.qtdTitulosVencidos > 0
                    ? '${_cliente!.qtdTitulosVencidos} títulos (${_cliente!.maiorDiasAtraso}d atraso)'
                    : 'Em dia',
                corFundo: _cliente!.totalVencido > 0 ? const Color(0xFFFEE2E2) : const Color(0xFFECFDF5),
                corTexto: _cliente!.totalVencido > 0 ? const Color(0xFFB91C1C) : const Color(0xFF047857),
                icone: _cliente!.totalVencido > 0 ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSummaryBox(
                titulo: 'Total A Vencer',
                valor: ReceberDuplicatasService.formatarMoeda(_cliente!.totalAVencer),
                subtitulo: 'No prazo regular',
                corFundo: const Color(0xFFEFF6FF),
                corTexto: const Color(0xFF1D4ED8),
                icone: Icons.schedule_rounded,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildSummaryBox(
                titulo: 'Saldo Devedor Total',
                valor: ReceberDuplicatasService.formatarMoeda(_cliente!.totalDevedor),
                subtitulo: 'Soma geral em aberto',
                corFundo: Colors.white,
                corTexto: const Color(0xFF0F172A),
                icone: Icons.account_balance_wallet_outlined,
                temBorda: true,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSummaryBox(
                titulo: 'Limite Disponível',
                valor: ReceberDuplicatasService.formatarMoeda(_cliente!.limiteAtual),
                subtitulo: 'Limite: ${ReceberDuplicatasService.formatarMoeda(_cliente!.limiteCredito)}',
                corFundo: Colors.white,
                corTexto: _cliente!.limiteAtual < 0 ? Colors.red.shade700 : const Color(0xFF0F172A),
                icone: Icons.credit_card_rounded,
                temBorda: true,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSummaryBox({
    required String titulo,
    required String valor,
    required String subtitulo,
    required Color corFundo,
    required Color corTexto,
    required IconData icone,
    bool temBorda = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: corFundo,
        borderRadius: BorderRadius.circular(14),
        border: temBorda ? Border.all(color: Colors.grey.shade200) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icone, size: 16, color: corTexto.withValues(alpha: 0.8)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  titulo,
                  style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: corTexto.withValues(alpha: 0.9)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            valor,
            style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold, color: corTexto),
          ),
          const SizedBox(height: 2),
          Text(
            subtitulo,
            style: GoogleFonts.inter(fontSize: 10, color: corTexto.withValues(alpha: 0.75)),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildTituloCard(TituloDuplicataItem t, AppTheme theme) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: t.isVencido ? Colors.red.shade200 : Colors.grey.shade200,
          width: t.isVencido ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row: Número e Status
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.description_outlined, size: 18, color: Colors.black54),
                  const SizedBox(width: 6),
                  Text(
                    'Título #${t.numeroDocumento}',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1E293B),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: t.isVencido ? Colors.red.shade50 : Colors.green.shade50,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: t.isVencido ? Colors.red.shade200 : Colors.green.shade200,
                  ),
                ),
                child: Text(
                  t.isVencido ? '${t.diasAtraso}d em atraso' : 'No prazo',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: t.isVencido ? Colors.red.shade800 : Colors.green.shade800,
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 16),

          // Informações de datas e valores
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (t.dataEmissao != null)
                    Text(
                      'Emissão: ${ReceberDuplicatasService.formatarData(t.dataEmissao)}',
                      style: GoogleFonts.inter(fontSize: 11, color: Colors.grey.shade600),
                    ),
                  Text(
                    'Vencimento: ${ReceberDuplicatasService.formatarData(t.dataVencimento)}',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: t.isVencido ? Colors.red.shade700 : Colors.black87,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Saldo: ${ReceberDuplicatasService.formatarMoeda(t.saldoDevedor)}',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1E293B),
                    ),
                  ),
                  if (t.valorJuros > 0)
                    Text(
                      '+ Juros: ${ReceberDuplicatasService.formatarMoeda(t.valorJuros)}',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: Colors.orange.shade800,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                ],
              ),
            ],
          ),

          if (t.valorOriginal != t.saldoDevedor && t.valorPago > 0) ...[
            const SizedBox(height: 6),
            Text(
              'Valor Original: ${ReceberDuplicatasService.formatarMoeda(t.valorOriginal)} | Amortizado: ${ReceberDuplicatasService.formatarMoeda(t.valorPago)}',
              style: GoogleFonts.inter(fontSize: 10, color: Colors.grey.shade500),
            ),
          ],
        ],
      ),
    );
  }
}
