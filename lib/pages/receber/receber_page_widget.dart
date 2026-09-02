import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../components/extrato_duplicatas/extrato_duplicatas_widget.dart';
import '../../core/app_theme.dart';
import '../../core/app_util.dart';
import '../../services/receber_duplicatas_service.dart';
import 'receber_page_model.dart';
export 'receber_page_model.dart';

/// Tela consolidada de Contas a Receber / Duplicatas (ffrmrelrecdup00)
class ReceberPageWidget extends StatefulWidget {
  const ReceberPageWidget({super.key});

  static String routeName = 'ReceberPage';
  static String routePath = '/receber';

  @override
  State<ReceberPageWidget> createState() => _ReceberPageWidgetState();
}

class _ReceberPageWidgetState extends State<ReceberPageWidget> {
  late ReceberPageModel _model;
  final scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => ReceberPageModel());
    _carregarDados();
  }

  @override
  void dispose() {
    _model.dispose();
    super.dispose();
  }

  Future<void> _carregarDados() async {
    setState(() => _model.isLoading = true);

    final codRep = AppState().vendedor_codigo;
    final taxaJuros = await ReceberDuplicatasService.obterTaxaJurosVendedor(codRep);

    final clientes = await ReceberDuplicatasService.listarClientesComDebito(
      filtro: _model.filtroAtual,
      ordenacao: _model.ordenacaoAtual,
      busca: _model.buscaTextController?.text ?? '',
      taxaJurosOverride: taxaJuros,
    );

    // Totais de cabeçalho
    double totDev = 0;
    double totVen = 0;
    double totAVen = 0;
    int qtdInad = 0;

    for (final c in clientes) {
      totDev += c.totalDevedor;
      totVen += c.totalVencido;
      totAVen += c.totalAVencer;
      if (c.temInadimplencia) qtdInad++;
    }

    if (mounted) {
      setState(() {
        _model.clientesFiltrados = clientes;
        _model.totalGeralDevedor = totDev;
        _model.totalGeralVencido = totVen;
        _model.totalGeralAVencer = totAVen;
        _model.qtdClientesInadimplentes = qtdInad;
        _model.isLoading = false;
      });
    }
  }

  void _onFiltroChanged(FiltroReceber novoFiltro) {
    if (_model.filtroAtual == novoFiltro) return;
    _model.filtroAtual = novoFiltro;
    _carregarDados();
  }

  void _onOrdenacaoChanged(OrdenacaoReceber novaOrdenacao) {
    if (_model.ordenacaoAtual == novaOrdenacao) return;
    _model.ordenacaoAtual = novaOrdenacao;
    _carregarDados();
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);

    return Scaffold(
      key: scaffoldKey,
      backgroundColor: const Color(0xFFF1F4F8),
      appBar: AppBar(
        backgroundColor: theme.primary,
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Contas a Receber',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 20.0,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            tooltip: 'Atualizar duplicatas',
            onPressed: _carregarDados,
          ),
        ],
        centerTitle: true,
        elevation: 2.0,
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _carregarDados,
          color: theme.primary,
          child: Column(
            children: [
              // Card de Resumo de Carteira
              _buildResumoCarteiraCard(theme),

              // Barra de Pesquisa e Ordenação
              _buildSearchAndSortBar(theme),

              // Filtros por Chips
              _buildFilterChips(theme),

              // Lista de Clientes com Débito
              Expanded(
                child: _model.isLoading
                    ? Center(
                        child: CircularProgressIndicator(color: theme.primary),
                      )
                    : _model.clientesFiltrados.isEmpty
                        ? _buildEmptyState()
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                            itemCount: _model.clientesFiltrados.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final item = _model.clientesFiltrados[index];
                              return _buildClienteCard(item, theme);
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResumoCarteiraCard(AppTheme theme) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Posição Geral de Débitos',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _model.qtdClientesInadimplentes > 0 ? Colors.red.shade50 : Colors.green.shade50,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: _model.qtdClientesInadimplentes > 0 ? Colors.red.shade200 : Colors.green.shade200,
                  ),
                ),
                child: Text(
                  '${_model.clientesFiltrados.length} clientes com saldo',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: _model.qtdClientesInadimplentes > 0 ? Colors.red.shade800 : Colors.green.shade800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total Devedor',
                      style: GoogleFonts.inter(fontSize: 11, color: Colors.grey.shade600),
                    ),
                    Text(
                      ReceberDuplicatasService.formatarMoeda(_model.totalGeralDevedor),
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
              ),
              Container(width: 1, height: 36, color: Colors.grey.shade200),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total Vencido',
                      style: GoogleFonts.inter(fontSize: 11, color: Colors.red.shade700, fontWeight: FontWeight.w600),
                    ),
                    Text(
                      ReceberDuplicatasService.formatarMoeda(_model.totalGeralVencido),
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.red.shade700,
                      ),
                    ),
                  ],
                ),
              ),
              Container(width: 1, height: 36, color: Colors.grey.shade200),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'A Vencer',
                      style: GoogleFonts.inter(fontSize: 11, color: Colors.blue.shade700, fontWeight: FontWeight.w600),
                    ),
                    Text(
                      ReceberDuplicatasService.formatarMoeda(_model.totalGeralAVencer),
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndSortBar(AppTheme theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: TextField(
                controller: _model.buscaTextController,
                focusNode: _model.buscaFocusNode,
                onChanged: (_) => _carregarDados(),
                decoration: InputDecoration(
                  hintText: 'Pesquisar cliente ou código...',
                  hintStyle: GoogleFonts.inter(fontSize: 13, color: Colors.grey.shade400),
                  prefixIcon: const Icon(Icons.search_rounded, size: 20, color: Colors.black45),
                  suffixIcon: _model.buscaTextController?.text.isNotEmpty == true
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 18, color: Colors.black45),
                          onPressed: () {
                            _model.buscaTextController?.clear();
                            _carregarDados();
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
                style: GoogleFonts.inter(fontSize: 13),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: PopupMenuButton<OrdenacaoReceber>(
              icon: Icon(
                Icons.sort_rounded,
                color: theme.primary,
                size: 22,
              ),
              tooltip: 'Ordenar lista',
              initialValue: _model.ordenacaoAtual,
              onSelected: _onOrdenacaoChanged,
              itemBuilder: (ctx) => [
                CheckedPopupMenuItem(
                  value: OrdenacaoReceber.maiorAtraso,
                  checked: _model.ordenacaoAtual == OrdenacaoReceber.maiorAtraso,
                  child: Text(
                    'Maior Tempo de Atraso (Aging)',
                    style: GoogleFonts.inter(fontSize: 13),
                  ),
                ),
                CheckedPopupMenuItem(
                  value: OrdenacaoReceber.maiorValor,
                  checked: _model.ordenacaoAtual == OrdenacaoReceber.maiorValor,
                  child: Text(
                    'Maior Valor Devedor',
                    style: GoogleFonts.inter(fontSize: 13),
                  ),
                ),
                CheckedPopupMenuItem(
                  value: OrdenacaoReceber.alfabetica,
                  checked: _model.ordenacaoAtual == OrdenacaoReceber.alfabetica,
                  child: Text(
                    'Ordem Alfabética (A-Z)',
                    style: GoogleFonts.inter(fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips(AppTheme theme) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _buildChip(
            label: 'Todos com Débito',
            selecionado: _model.filtroAtual == FiltroReceber.todos,
            onTap: () => _onFiltroChanged(FiltroReceber.todos),
            theme: theme,
          ),
          const SizedBox(width: 8),
          _buildChip(
            label: 'Apenas Vencidos',
            selecionado: _model.filtroAtual == FiltroReceber.apenasVencidos,
            onTap: () => _onFiltroChanged(FiltroReceber.apenasVencidos),
            theme: theme,
            corDestaque: Colors.red.shade700,
          ),
          const SizedBox(width: 8),
          _buildChip(
            label: 'A Vencer',
            selecionado: _model.filtroAtual == FiltroReceber.aVencer,
            onTap: () => _onFiltroChanged(FiltroReceber.aVencer),
            theme: theme,
            corDestaque: Colors.blue.shade700,
          ),
        ],
      ),
    );
  }

  Widget _buildChip({
    required String label,
    required bool selecionado,
    required VoidCallback onTap,
    required AppTheme theme,
    Color? corDestaque,
  }) {
    final activeColor = corDestaque ?? theme.primary;

    return ChoiceChip(
      label: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: selecionado ? FontWeight.bold : FontWeight.w500,
          color: selecionado ? Colors.white : Colors.grey.shade700,
        ),
      ),
      selected: selecionado,
      selectedColor: activeColor,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: selecionado ? activeColor : Colors.grey.shade300,
        ),
      ),
      onSelected: (_) => onTap(),
    );
  }

  Widget _buildClienteCard(ClienteReceberItem item, AppTheme theme) {
    final temVencido = item.qtdTitulosVencidos > 0;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          ExtratoDuplicatasWidget.show(context, cliente: item);
        },
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: temVencido ? Colors.red.shade200 : Colors.grey.shade200,
              width: temVencido ? 1.5 : 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Linha Superior: Código, Razão Social e Badge de Status
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '#${item.codCli}',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.razaoSocial,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF1E293B),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (item.fantasia.isNotEmpty)
                          Text(
                            item.fantasia,
                            style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: temVencido ? Colors.red.shade50 : Colors.green.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: temVencido ? Colors.red.shade200 : Colors.green.shade200,
                      ),
                    ),
                    child: Text(
                      temVencido ? '${item.maiorDiasAtraso}d atraso' : 'No prazo',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: temVencido ? Colors.red.shade800 : Colors.green.shade800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Linha de Cidade e Badges de Títulos
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (item.cidadeUf.isNotEmpty)
                    Row(
                      children: [
                        Icon(Icons.location_on_outlined, size: 14, color: Colors.grey.shade500),
                        const SizedBox(width: 4),
                        Text(
                          item.cidadeUf,
                          style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade600),
                        ),
                      ],
                    )
                  else
                    const SizedBox.shrink(),
                  Text(
                    '${item.qtdTitulosTotal} títulos (${item.qtdTitulosVencidos} vencidos)',
                    style: GoogleFonts.inter(fontSize: 11, color: Colors.grey.shade600),
                  ),
                ],
              ),
              const Divider(height: 16),

              // Linha de Saldos Financeiros
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Total Vencido',
                        style: GoogleFonts.inter(fontSize: 11, color: Colors.red.shade700, fontWeight: FontWeight.w500),
                      ),
                      Text(
                        ReceberDuplicatasService.formatarMoeda(item.totalVencido),
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.red.shade700,
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'A Vencer',
                        style: GoogleFonts.inter(fontSize: 11, color: Colors.blue.shade700, fontWeight: FontWeight.w500),
                      ),
                      Text(
                        ReceberDuplicatasService.formatarMoeda(item.totalAVencer),
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.blue.shade800,
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Saldo Total',
                        style: GoogleFonts.inter(fontSize: 11, color: Colors.grey.shade600),
                      ),
                      Row(
                        children: [
                          Text(
                            ReceberDuplicatasService.formatarMoeda(item.totalDevedor),
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.chevron_right_rounded, size: 18, color: Colors.black45),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.check_circle_outline_rounded, size: 48, color: Colors.green.shade600),
            ),
            const SizedBox(height: 16),
            Text(
              'Nenhum débito encontrado',
              style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B)),
            ),
            const SizedBox(height: 8),
            Text(
              'Não existem títulos em aberto para os filtros selecionados.',
              style: GoogleFonts.inter(fontSize: 13, color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
