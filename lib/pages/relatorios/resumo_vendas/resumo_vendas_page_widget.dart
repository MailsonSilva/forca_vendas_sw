import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '/core/app_icon_button.dart';
import '/core/app_theme.dart';
import '/core/app_util.dart';
import '/core/app_functions.dart';
import '/domain/models/resumo_vendas_model.dart';
import '/services/resumo_vendas_service.dart';
import 'resumo_vendas_page_model.dart';
export 'resumo_vendas_page_model.dart';

class ResumoVendasPageWidget extends StatefulWidget {
  const ResumoVendasPageWidget({super.key});

  static String routeName = 'ResumoVendasPage';
  static String routePath = '/resumoVendasPage';

  @override
  State<ResumoVendasPageWidget> createState() => _ResumoVendasPageWidgetState();
}

class _ResumoVendasPageWidgetState extends State<ResumoVendasPageWidget> {
  late ResumoVendasPageModel _model;
  final scaffoldKey = GlobalKey<ScaffoldState>();

  final DateFormat _dateFormat = DateFormat('dd/MM/yyyy');

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => ResumoVendasPageModel());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _carregarDados();
    });
  }

  Future<void> _carregarDados() async {
    if (!mounted) return;
    safeSetState(() => _model.isLoading = true);
    await _model.carregarDados(context: context);
    if (mounted) {
      safeSetState(() {});
    }
  }

  @override
  void dispose() {
    _model.dispose();
    super.dispose();
  }

  Future<void> _abrirSeletorData() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: DateTimeRange(
        start: _model.dataInicio,
        end: _model.dataFim,
      ),
      helpText: 'Selecione o Período de Vendas',
      cancelText: 'Cancelar',
      confirmText: 'Aplicar',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppTheme.of(context).primary,
              onPrimary: Colors.white,
              surface: AppTheme.of(context).secondaryBackground,
            ),
          ),
          child: child!,
        );
      },
    );

    if (range != null) {
      await _model.alterarPeriodoCustomizado(range.start, range.end);
      if (mounted) safeSetState(() {});
    }
  }

  void _compartilharResumo(ResumoVendasConsolidado resumo) {
    final texto = ResumoVendasService.gerarTextoCompartilhamento(resumo);
    Clipboard.setData(ClipboardData(text: texto));

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline_rounded, color: Colors.white),
            const SizedBox(width: 8.0),
            Expanded(
              child: Text(
                'Resumo de vendas copiado para a área de transferência!',
                style: GoogleFonts.inter(color: Colors.white, fontSize: 13.0),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF24A148),
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final resumo = _model.resumo ??
        ResumoVendasConsolidado.empty(
          dataInicio: _model.dataInicio,
          dataFim: _model.dataFim,
        );

    final periodoTexto = _dateFormat.format(_model.dataInicio) == _dateFormat.format(_model.dataFim)
        ? _dateFormat.format(_model.dataInicio)
        : '${_dateFormat.format(_model.dataInicio)} até ${_dateFormat.format(_model.dataFim)}';

    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
        FocusManager.instance.primaryFocus?.unfocus();
      },
      child: Scaffold(
        key: scaffoldKey,
        backgroundColor: AppTheme.of(context).primaryBackground,
        appBar: AppBar(
          backgroundColor: AppTheme.of(context).primary,
          automaticallyImplyLeading: false,
          leading: AppIconButton(
            borderColor: Colors.transparent,
            borderRadius: 30.0,
            borderWidth: 1.0,
            buttonSize: 60.0,
            icon: const Icon(
              Icons.arrow_back_rounded,
              color: Colors.white,
              size: 28.0,
            ),
            onPressed: () async {
              context.safePop();
            },
          ),
          title: Column(
            children: [
              Text(
                'Resumo de Vendas',
                style: AppTheme.of(context).headlineMedium.override(
                      font: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w600,
                      ),
                      color: Colors.white,
                      fontSize: 18.0,
                      letterSpacing: 0.0,
                    ),
              ),
              Text(
                periodoTexto,
                style: GoogleFonts.inter(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 12.0,
                ),
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.share_outlined, color: Colors.white),
              tooltip: 'Copiar/Compartilhar Resumo',
              onPressed: () => _compartilharResumo(resumo),
            ),
            IconButton(
              icon: const Icon(Icons.refresh_rounded, color: Colors.white),
              tooltip: 'Recarregar dados',
              onPressed: () => _carregarDados(),
            ),
          ],
          centerTitle: true,
          elevation: 2.0,
        ),
        body: SafeArea(
          top: true,
          child: RefreshIndicator(
            onRefresh: () => _carregarDados(),
            child: _model.isLoading
                ? const Center(child: CircularProgressIndicator())
                : CustomScrollView(
                    slivers: [
                      // Painel de Filtros e Atalhos
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _buildAtalhosPeriodo(context),
                              const SizedBox(height: 16.0),
                              // 4 Cards Principais de Totais
                              _buildGridCards(context, resumo),
                              const SizedBox(height: 16.0),
                              // Cabeçalho da Lista Analítica
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Detalhamento por Dia',
                                    style: AppTheme.of(context).titleMedium.override(
                                          font: GoogleFonts.inter(
                                            fontWeight: FontWeight.w600,
                                          ),
                                          fontSize: 16.0,
                                        ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                                    decoration: BoxDecoration(
                                      color: AppTheme.of(context).secondaryBackground,
                                      borderRadius: BorderRadius.circular(12.0),
                                      border: Border.all(
                                        color: AppTheme.of(context).alternate,
                                        width: 1.0,
                                      ),
                                    ),
                                    child: Text(
                                      '${resumo.totalPedidos} pedido(s)',
                                      style: AppTheme.of(context).bodySmall.override(
                                            font: GoogleFonts.inter(),
                                            color: AppTheme.of(context).secondaryText,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Lista Diária Sanfonada
                      if (resumo.dias.isEmpty)
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: _buildEmptyState(context),
                        )
                      else
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(16.0, 4.0, 16.0, 24.0),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                final dia = resumo.dias[index];
                                return _buildDiaAccordion(context, dia);
                              },
                              childCount: resumo.dias.length,
                            ),
                          ),
                        ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildAtalhosPeriodo(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildChipAtalho('Hoje', 'HOJE'),
          const SizedBox(width: 8.0),
          _buildChipAtalho('Últimos 7 dias', '7DIAS'),
          const SizedBox(width: 8.0),
          _buildChipAtalho('Mês Atual', 'MES'),
          const SizedBox(width: 8.0),
          ActionChip(
            avatar: const Icon(Icons.date_range_rounded, size: 16.0),
            label: Text(
              _model.filtroAtalho == 'CUSTOM' ? 'Outro Período ✏️' : 'Outro Período...',
              style: GoogleFonts.inter(fontSize: 12.0, fontWeight: FontWeight.w500),
            ),
            backgroundColor: _model.filtroAtalho == 'CUSTOM'
                ? AppTheme.of(context).primary.withValues(alpha: 0.15)
                : AppTheme.of(context).secondaryBackground,
            side: BorderSide(
              color: _model.filtroAtalho == 'CUSTOM'
                  ? AppTheme.of(context).primary
                  : AppTheme.of(context).alternate,
            ),
            onPressed: () => _abrirSeletorData(),
          ),
        ],
      ),
    );
  }

  Widget _buildChipAtalho(String label, String valor) {
    final isSelected = _model.filtroAtalho == valor;
    final primary = AppTheme.of(context).primary;

    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          color: isSelected ? Colors.white : AppTheme.of(context).primaryText,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
          fontSize: 12.0,
        ),
      ),
      selected: isSelected,
      selectedColor: primary,
      backgroundColor: AppTheme.of(context).secondaryBackground,
      onSelected: (selected) async {
        if (selected) {
          await _model.selecionarAtalho(valor);
          if (mounted) safeSetState(() {});
        }
      },
    );
  }

  Widget _buildGridCards(BuildContext context, ResumoVendasConsolidado resumo) {
    return Column(
      children: [
        Row(
          children: [
            // Card 1: Venda Bruta
            Expanded(
              child: _buildCardMetrica(
                context,
                titulo: 'Venda Bruta',
                subtitulo: 'Captada em campo',
                valor: resumo.totalVendaBruta,
                icone: Icons.shopping_bag_outlined,
                corDestaque: const Color(0xFF1192E8),
              ),
            ),
            const SizedBox(width: 12.0),
            // Card 2: Devoluções / Cortes
            Expanded(
              child: _buildCardMetrica(
                context,
                titulo: 'Devoluções / Cortes',
                subtitulo: 'Rupturas e estornos',
                valor: resumo.totalDevolucoes,
                icone: Icons.remove_shopping_cart_outlined,
                corDestaque: const Color(0xFFDA1E28),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12.0),
        Row(
          children: [
            // Card 3: Venda Líquida
            Expanded(
              child: _buildCardMetrica(
                context,
                titulo: 'Venda Líquida',
                subtitulo: 'Faturamento real',
                valor: resumo.totalVendaLiquida,
                icone: Icons.check_circle_outline_rounded,
                corDestaque: const Color(0xFF24A148),
              ),
            ),
            const SizedBox(width: 12.0),
            // Card 4: Comissão Estimada
            Expanded(
              child: _buildCardMetrica(
                context,
                titulo: 'Comissão Estimada',
                subtitulo: 'Apuração por produto',
                valor: resumo.totalComissao,
                icone: Icons.monetization_on_outlined,
                corDestaque: const Color(0xFFD49500),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCardMetrica(
    BuildContext context, {
    required String titulo,
    required String subtitulo,
    required double valor,
    required IconData icone,
    required Color corDestaque,
  }) {
    return Container(
      padding: const EdgeInsets.all(14.0),
      decoration: BoxDecoration(
        color: AppTheme.of(context).secondaryBackground,
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(
          color: corDestaque.withValues(alpha: 0.3),
          width: 1.5,
        ),
        boxShadow: const [
          BoxShadow(
            blurRadius: 4.0,
            color: Color(0x10000000),
            offset: Offset(0.0, 2.0),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6.0),
                decoration: BoxDecoration(
                  color: corDestaque.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8.0),
                ),
                child: Icon(icone, size: 18.0, color: corDestaque),
              ),
              const SizedBox(width: 8.0),
              Expanded(
                child: Text(
                  titulo,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.of(context).bodyMedium.override(
                        font: GoogleFonts.inter(
                          fontWeight: FontWeight.w600,
                        ),
                        fontSize: 12.0,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10.0),
          Text(
            formatPreco(valor) ?? 'R\$ 0,00',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.outfit(
              fontSize: 18.0,
              fontWeight: FontWeight.bold,
              color: corDestaque,
            ),
          ),
          const SizedBox(height: 2.0),
          Text(
            subtitulo,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTheme.of(context).bodySmall.override(
                  font: GoogleFonts.inter(),
                  color: AppTheme.of(context).secondaryText,
                  fontSize: 10.0,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildDiaAccordion(BuildContext context, ResumoVendasDia dia) {
    DateTime? dt;
    try {
      dt = DateTime.parse(dia.data);
    } catch (_) {}
    final dataFormatada = dt != null ? _dateFormat.format(dt) : dia.data;

    return Container(
      margin: const EdgeInsets.only(bottom: 12.0),
      decoration: BoxDecoration(
        color: AppTheme.of(context).secondaryBackground,
        borderRadius: BorderRadius.circular(10.0),
        border: Border.all(
          color: AppTheme.of(context).alternate,
          width: 1.0,
        ),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: true,
          tilePadding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 4.0),
          leading: Container(
            padding: const EdgeInsets.all(8.0),
            decoration: BoxDecoration(
              color: AppTheme.of(context).primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.calendar_today_rounded,
              color: AppTheme.of(context).primary,
              size: 20.0,
            ),
          ),
          title: Text(
            dataFormatada,
            style: AppTheme.of(context).titleMedium.override(
                  font: GoogleFonts.inter(
                    fontWeight: FontWeight.bold,
                  ),
                  fontSize: 14.0,
                ),
          ),
          subtitle: Text(
            '${dia.pedidos.length} pedido(s) • Líquido: ${formatPreco(dia.totalLiquido)} • Comis: ${formatPreco(dia.totalComissao)}',
            style: AppTheme.of(context).bodySmall.override(
                  font: GoogleFonts.inter(),
                  color: AppTheme.of(context).secondaryText,
                  fontSize: 11.0,
                ),
          ),
          children: [
            const Divider(height: 1.0),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
              child: Column(
                children: dia.pedidos.map((pedido) => _buildPedidoItemCard(context, pedido)).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPedidoItemCard(BuildContext context, ResumoVendasPedidoItem pedido) {
    final bool isFaturado = pedido.isFaturado;
    final statusColor = isFaturado ? const Color(0xFF24A148) : const Color(0xFF1192E8);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4.0),
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: AppTheme.of(context).primaryBackground,
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(
          color: AppTheme.of(context).alternate,
          width: 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Pedido #${pedido.numeroPedido}',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.bold,
                  fontSize: 13.0,
                  color: AppTheme.of(context).primaryText,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 2.0),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12.0),
                ),
                child: Text(
                  pedido.statusDescricao,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 10.0,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4.0),
          Text(
            pedido.nomeCliente,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              fontSize: 12.0,
              color: AppTheme.of(context).secondaryText,
            ),
          ),
          const SizedBox(height: 8.0),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Venda: ${formatPreco(pedido.valorBruto)}',
                style: GoogleFonts.inter(fontSize: 11.0, color: AppTheme.of(context).secondaryText),
              ),
              if (pedido.hasCortes)
                Text(
                  'Corte: -${formatPreco(pedido.valorDevolucaoCortes)}',
                  style: GoogleFonts.inter(fontSize: 11.0, color: const Color(0xFFDA1E28), fontWeight: FontWeight.w600),
                ),
              Text(
                'Líquido: ${formatPreco(pedido.valorLiquido)}',
                style: GoogleFonts.inter(fontSize: 11.0, fontWeight: FontWeight.w600, color: const Color(0xFF24A148)),
              ),
              Text(
                'Comissão: ${formatPreco(pedido.valorComissao)}',
                style: GoogleFonts.inter(fontSize: 11.0, fontWeight: FontWeight.bold, color: const Color(0xFFD49500)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72.0,
              height: 72.0,
              decoration: BoxDecoration(
                color: AppTheme.of(context).alternate.withValues(alpha: 0.5),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.receipt_long_outlined,
                size: 36.0,
                color: AppTheme.of(context).secondaryText,
              ),
            ),
            const SizedBox(height: 16.0),
            Text(
              'Nenhuma venda encontrada no período',
              style: AppTheme.of(context).titleMedium.override(
                    font: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                    ),
                    fontSize: 16.0,
                  ),
            ),
            const SizedBox(height: 8.0),
            Text(
              'Selecione outro intervalo de datas ou cadastre novos pedidos para visualizar a prestação de contas e comissões.',
              textAlign: TextAlign.center,
              style: AppTheme.of(context).bodySmall.override(
                    font: GoogleFonts.inter(),
                    color: AppTheme.of(context).secondaryText,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
