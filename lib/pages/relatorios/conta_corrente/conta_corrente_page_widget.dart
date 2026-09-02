import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '/core/app_icon_button.dart';
import '/core/app_theme.dart';
import '/core/app_util.dart';
import '/core/app_functions.dart';
import '/domain/models/conta_corrente_model.dart';
import 'conta_corrente_page_model.dart';
export 'conta_corrente_page_model.dart';

class ContaCorrentePageWidget extends StatefulWidget {
  const ContaCorrentePageWidget({super.key});

  static String routeName = 'ContaCorrentePage';
  static String routePath = '/contaCorrentePage';

  @override
  State<ContaCorrentePageWidget> createState() => _ContaCorrentePageWidgetState();
}

class _ContaCorrentePageWidgetState extends State<ContaCorrentePageWidget> {
  late ContaCorrentePageModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => ContaCorrentePageModel());
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

  @override
  Widget build(BuildContext context) {
    final saldo = _model.saldo ?? ContaCorrenteSaldo.empty();

    final Color statusColor = saldo.saldoDisponivel > 0
        ? const Color(0xFF24A148) // Green
        : (saldo.saldoDisponivel < 0
            ? const Color(0xFFDA1E28) // Red
            : const Color(0xFF8D8D8D)); // Neutral

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
          title: Text(
            'Conta-Corrente (CCV)',
            style: AppTheme.of(context).headlineMedium.override(
                  font: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w600,
                  ),
                  color: Colors.white,
                  fontSize: 20.0,
                  letterSpacing: 0.0,
                ),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh_rounded, color: Colors.white),
              tooltip: 'Recarregar extrato',
              onPressed: () async {
                await _carregarDados();
              },
            ),
          ],
          centerTitle: true,
          elevation: 2.0,
        ),
        body: SafeArea(
          top: true,
          child: RefreshIndicator(
            onRefresh: () async {
              await _carregarDados();
            },
            child: _model.isLoading
                ? const Center(
                    child: CircularProgressIndicator(),
                  )
                : CustomScrollView(
                    slivers: [
                      // Header / Painel de Resumo (Consolidação de Saldos)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Card Principal: Saldo Disponível (Líquido)
                              _buildCardSaldoPrincipal(context, saldo, statusColor),
                              const SizedBox(height: 12.0),
                              // Grid de Saldos Secundários: Base, Em Digitação, Em Trânsito
                              _buildCardsSaldosDetalhados(context, saldo),
                              const SizedBox(height: 16.0),
                              // Barra de Busca e Filtros
                              _buildFiltrosEBusca(context),
                              const SizedBox(height: 12.0),
                              // Cabeçalho da Seção de Lançamentos
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Histórico de Lançamentos',
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
                                      '${_model.movimentacoes.length} registros',
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

                      // Grade Analítica / Lista de Lançamentos
                      if (_model.movimentacoes.isEmpty)
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
                                final mov = _model.movimentacoes[index];
                                return _buildMovimentacaoItem(context, mov);
                              },
                              childCount: _model.movimentacoes.length,
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

  Widget _buildCardSaldoPrincipal(
    BuildContext context,
    ContaCorrenteSaldo saldo,
    Color statusColor,
  ) {
    final bool isPositivo = saldo.saldoDisponivel >= 0;
    final String statusTexto = isPositivo
        ? 'Verba Liberada para Descontos'
        : 'Bloqueio Ativo de Descontos no Checkout';
    final IconData statusIcon = isPositivo
        ? Icons.check_circle_outline_rounded
        : Icons.warning_amber_rounded;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.of(context).secondaryBackground,
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(
          color: statusColor.withValues(alpha: 0.3),
          width: 1.5,
        ),
        boxShadow: const [
          BoxShadow(
            blurRadius: 6.0,
            color: Color(0x1A000000),
            offset: Offset(0.0, 3.0),
          )
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.account_balance_wallet_rounded,
                      color: AppTheme.of(context).primary,
                      size: 22.0,
                    ),
                    const SizedBox(width: 8.0),
                    Text(
                      'Saldo Disponível (Líquido)',
                      style: AppTheme.of(context).bodyMedium.override(
                            font: GoogleFonts.inter(
                              fontWeight: FontWeight.w600,
                            ),
                            fontSize: 15.0,
                          ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 4.0),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20.0),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, color: statusColor, size: 14.0),
                      const SizedBox(width: 4.0),
                      Text(
                        isPositivo ? 'Positivo' : 'Negativo',
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 12.0,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12.0),
            Text(
              formatPreco(saldo.saldoDisponivel) ?? 'R\$ 0,00',
              style: GoogleFonts.outfit(
                fontSize: 32.0,
                fontWeight: FontWeight.bold,
                color: statusColor,
              ),
            ),
            const SizedBox(height: 8.0),
            Row(
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 14.0,
                  color: AppTheme.of(context).secondaryText,
                ),
                const SizedBox(width: 6.0),
                Expanded(
                  child: Text(
                    statusTexto,
                    style: AppTheme.of(context).bodySmall.override(
                          font: GoogleFonts.inter(),
                          color: AppTheme.of(context).secondaryText,
                        ),
                  ),
                ),
              ],
            ),
            if (saldo.dataSincronizacao != null && saldo.dataSincronizacao!.isNotEmpty) ...[
              const Divider(height: 16.0),
              Text(
                'Última sincronização retaguarda: ${saldo.dataSincronizacao}',
                style: AppTheme.of(context).bodySmall.override(
                      font: GoogleFonts.inter(),
                      color: AppTheme.of(context).secondaryText,
                      fontSize: 11.0,
                    ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCardsSaldosDetalhados(
    BuildContext context,
    ContaCorrenteSaldo saldo,
  ) {
    return Row(
      children: [
        // Saldo Base
        Expanded(
          child: _buildMiniCard(
            context,
            titulo: 'Saldo Base',
            subtitulo: 'ERP Oficial',
            valor: saldo.saldoBase,
            icone: Icons.account_balance_rounded,
            corIcone: AppTheme.of(context).primary,
          ),
        ),
        const SizedBox(width: 8.0),
        // Em Digitação
        Expanded(
          child: _buildMiniCard(
            context,
            titulo: 'Em Digitação',
            subtitulo: 'Rascunhos',
            valor: saldo.saldoEmDigitacao,
            icone: Icons.edit_note_rounded,
            corIcone: const Color(0xFFF1C21B),
          ),
        ),
        const SizedBox(width: 8.0),
        // Em Trânsito
        Expanded(
          child: _buildMiniCard(
            context,
            titulo: 'Em Trânsito',
            subtitulo: 'Pacotes (.pac)',
            valor: saldo.saldoEmTransito,
            icone: Icons.local_shipping_outlined,
            corIcone: const Color(0xFF1192E8),
          ),
        ),
      ],
    );
  }

  Widget _buildMiniCard(
    BuildContext context, {
    required String titulo,
    required String subtitulo,
    required double valor,
    required IconData icone,
    required Color corIcone,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 12.0),
      decoration: BoxDecoration(
        color: AppTheme.of(context).secondaryBackground,
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(
          color: AppTheme.of(context).alternate,
          width: 1.0,
        ),
        boxShadow: const [
          BoxShadow(
            blurRadius: 3.0,
            color: Color(0x10000000),
            offset: Offset(0.0, 1.0),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icone, size: 16.0, color: corIcone),
              const SizedBox(width: 4.0),
              Expanded(
                child: Text(
                  titulo,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.of(context).bodySmall.override(
                        font: GoogleFonts.inter(
                          fontWeight: FontWeight.w600,
                        ),
                        fontSize: 11.0,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6.0),
          Text(
            formatPreco(valor) ?? 'R\$ 0,00',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              fontWeight: FontWeight.bold,
              fontSize: 13.0,
              color: valor < 0 ? const Color(0xFFDA1E28) : AppTheme.of(context).primaryText,
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

  Widget _buildFiltrosEBusca(BuildContext context) {
    return Column(
      children: [
        // Campo de busca
        Container(
          height: 44.0,
          decoration: BoxDecoration(
            color: AppTheme.of(context).secondaryBackground,
            borderRadius: BorderRadius.circular(8.0),
            border: Border.all(
              color: AppTheme.of(context).alternate,
              width: 1.0,
            ),
          ),
          child: TextField(
            controller: _model.searchController,
            focusNode: _model.searchFocusNode,
            onChanged: (_) async {
              await _model.carregarDados(context: context);
              if (mounted) safeSetState(() {});
            },
            decoration: InputDecoration(
              hintText: 'Buscar lançamento por histórico...',
              hintStyle: AppTheme.of(context).bodySmall.override(
                    font: GoogleFonts.inter(),
                    color: AppTheme.of(context).secondaryText,
                  ),
              prefixIcon: Icon(
                Icons.search_rounded,
                size: 20.0,
                color: AppTheme.of(context).secondaryText,
              ),
              suffixIcon: _model.searchController?.text.isNotEmpty == true
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 18.0),
                      onPressed: () async {
                        _model.searchController?.clear();
                        await _model.carregarDados(context: context);
                        if (mounted) safeSetState(() {});
                      },
                    )
                  : null,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
            ),
          ),
        ),
        const SizedBox(height: 8.0),
        // Filter Chips
        Row(
          children: [
            _buildFilterChip(context, label: 'Todos', valor: 'TODOS'),
            const SizedBox(width: 8.0),
            _buildFilterChip(context, label: 'Créditos (+)', valor: 'C', cor: const Color(0xFF24A148)),
            const SizedBox(width: 8.0),
            _buildFilterChip(context, label: 'Débitos (-)', valor: 'D', cor: const Color(0xFFDA1E28)),
          ],
        ),
      ],
    );
  }

  Widget _buildFilterChip(
    BuildContext context, {
    required String label,
    required String valor,
    Color? cor,
  }) {
    final bool isSelected = _model.filtroTipo == valor;
    final primary = AppTheme.of(context).primary;

    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          color: isSelected
              ? Colors.white
              : (cor ?? AppTheme.of(context).primaryText),
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
          fontSize: 12.0,
        ),
      ),
      selected: isSelected,
      selectedColor: cor ?? primary,
      backgroundColor: AppTheme.of(context).secondaryBackground,
      onSelected: (selected) async {
        if (selected) {
          await _model.alterarFiltro(valor);
          if (mounted) safeSetState(() {});
        }
      },
    );
  }

  Widget _buildMovimentacaoItem(
    BuildContext context,
    ContaCorrenteMovimentacao mov,
  ) {
    final bool isCredito = mov.isCredito;
    final Color itemColor = isCredito ? const Color(0xFF24A148) : const Color(0xFFDA1E28);
    final String sinal = isCredito ? '+ ' : '- ';
    final IconData icon = isCredito ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded;

    return Container(
      margin: const EdgeInsets.only(bottom: 8.0),
      decoration: BoxDecoration(
        color: AppTheme.of(context).secondaryBackground,
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(
          color: AppTheme.of(context).alternate,
          width: 1.0,
        ),
        boxShadow: const [
          BoxShadow(
            blurRadius: 2.0,
            color: Color(0x0D000000),
            offset: Offset(0.0, 1.0),
          )
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            // Ícone circular
            Container(
              width: 40.0,
              height: 40.0,
              decoration: BoxDecoration(
                color: itemColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: itemColor, size: 22.0),
            ),
            const SizedBox(width: 12.0),
            // Informações descritivas
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    mov.observacao.isNotEmpty
                        ? mov.observacao
                        : (isCredito ? 'Crédito de Conta-Corrente' : 'Débito de Conta-Corrente'),
                    style: AppTheme.of(context).bodyMedium.override(
                          font: GoogleFonts.inter(
                            fontWeight: FontWeight.w600,
                          ),
                          fontSize: 14.0,
                        ),
                  ),
                  const SizedBox(height: 4.0),
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today_outlined,
                        size: 12.0,
                        color: AppTheme.of(context).secondaryText,
                      ),
                      const SizedBox(width: 4.0),
                      Text(
                        mov.dataFormatada,
                        style: AppTheme.of(context).bodySmall.override(
                              font: GoogleFonts.inter(),
                              color: AppTheme.of(context).secondaryText,
                              fontSize: 12.0,
                            ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8.0),
            // Valor e Saldo
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '$sinal${formatPreco(mov.valorMovimento)}',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.bold,
                    fontSize: 14.0,
                    color: itemColor,
                  ),
                ),
                const SizedBox(height: 4.0),
                Text(
                  'Saldo: ${formatPreco(mov.saldoAcumulado)}',
                  style: AppTheme.of(context).bodySmall.override(
                        font: GoogleFonts.inter(),
                        color: AppTheme.of(context).secondaryText,
                        fontSize: 11.0,
                      ),
                ),
              ],
            ),
          ],
        ),
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
              'Nenhuma movimentação encontrada',
              style: AppTheme.of(context).titleMedium.override(
                    font: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                    ),
                    fontSize: 16.0,
                  ),
            ),
            const SizedBox(height: 8.0),
            Text(
              'As alterações de margem de preço (CCV) e créditos homologados pela retaguarda serão exibidos aqui.',
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
