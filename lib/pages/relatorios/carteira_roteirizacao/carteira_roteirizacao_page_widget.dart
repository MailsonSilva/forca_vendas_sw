import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '/core/app_icon_button.dart';
import '/core/app_theme.dart';
import '/core/app_util.dart';
import '/core/app_functions.dart';
import '/domain/models/carteira_roteirizacao_model.dart';
import '/services/carteira_roteirizacao_service.dart';
import 'carteira_roteirizacao_page_model.dart';
export 'carteira_roteirizacao_page_model.dart';

class CarteiraRoteirizacaoPageWidget extends StatefulWidget {
  const CarteiraRoteirizacaoPageWidget({super.key});

  static String routeName = 'CarteiraRoteirizacaoPage';
  static String routePath = '/carteiraRoteirizacaoPage';

  @override
  State<CarteiraRoteirizacaoPageWidget> createState() => _CarteiraRoteirizacaoPageWidgetState();
}

class _CarteiraRoteirizacaoPageWidgetState extends State<CarteiraRoteirizacaoPageWidget> {
  late CarteiraRoteirizacaoPageModel _model;
  final scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => CarteiraRoteirizacaoPageModel());
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

  Future<void> _fazerLigacao(String telefone) async {
    final cleanPhone = telefone.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleanPhone.isEmpty) return;
    final uri = Uri.parse('tel:$cleanPhone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _abrirMapa(ClienteRoteiroItem cliente) async {
    Uri uri;
    if (cliente.hasCoordenadas) {
      uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=${cliente.latitude},${cliente.longitude}');
    } else {
      final query = Uri.encodeComponent('${cliente.endereco}, ${cliente.cidade} - ${cliente.uf}');
      uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$query');
    }

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final resumo = _model.resumo ?? CarteiraRoteirizacaoResumo.empty();
    final diaHoje = CarteiraRoteirizacaoService.obterDiaSemanaAtual();

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
                'Roteiro de Visitas',
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
                'Carteira Comercial de Campo',
                style: GoogleFonts.inter(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 12.0,
                ),
              ),
            ],
          ),
          actions: [
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
            child: CustomScrollView(
              slivers: [
                // Barra de Busca e Filtros
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Campo de Busca
                        _buildCampoBusca(context),
                        const SizedBox(height: 12.0),
                        // Barra deslizante de Dias da Semana
                        _buildChipsDiasSemana(context, diaHoje),
                        const SizedBox(height: 12.0),
                        // Filtros Secundários (Status / Tipo Pessoa)
                        _buildFiltrosSecundarios(context),
                        const SizedBox(height: 12.0),
                        // Indicadores Resumo de Crédito da Rota
                        _buildBadgesResumo(context, resumo),
                        const SizedBox(height: 12.0),
                      ],
                    ),
                  ),
                ),

                // Listagem dos Clientes do Roteiro
                if (_model.isLoading)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (resumo.clientes.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _buildEmptyState(context),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16.0, 0.0, 16.0, 24.0),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final cliente = resumo.clientes[index];
                          return _buildClienteCard(context, cliente);
                        },
                        childCount: resumo.clientes.length,
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

  Widget _buildCampoBusca(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.of(context).secondaryBackground,
        borderRadius: BorderRadius.circular(10.0),
        border: Border.all(
          color: AppTheme.of(context).alternate,
          width: 1.0,
        ),
      ),
      child: TextField(
        controller: _model.searchController,
        focusNode: _model.searchFocusNode,
        onChanged: (_) => _carregarDados(),
        decoration: InputDecoration(
          hintText: 'Buscar por Razão, Fantasia, Código ou CPF/CNPJ...',
          hintStyle: GoogleFonts.inter(
            fontSize: 13.0,
            color: AppTheme.of(context).secondaryText,
          ),
          prefixIcon: Icon(Icons.search_rounded, color: AppTheme.of(context).secondaryText),
          suffixIcon: _model.searchController?.text.isNotEmpty == true
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded, size: 20.0),
                  onPressed: () {
                    _model.searchController?.clear();
                    _carregarDados();
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 12.0),
        ),
      ),
    );
  }

  Widget _buildChipsDiasSemana(BuildContext context, int diaHoje) {
    final dias = [
      {'label': 'Hoje', 'val': diaHoje},
      {'label': 'Seg', 'val': 1},
      {'label': 'Ter', 'val': 2},
      {'label': 'Qua', 'val': 3},
      {'label': 'Qui', 'val': 4},
      {'label': 'Sex', 'val': 5},
      {'label': 'Sáb', 'val': 6},
      {'label': 'Dom', 'val': 7},
      {'label': 'Sem Rota', 'val': 0},
      {'label': 'Todos', 'val': -1},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: dias.map((d) {
          final val = d['val'] as int;
          final isSelected = _model.filtro.diaVisita == val;

          return Padding(
            padding: const EdgeInsets.only(right: 6.0),
            child: ChoiceChip(
              label: Text(
                d['label'] as String,
                style: TextStyle(
                  color: isSelected ? Colors.white : AppTheme.of(context).primaryText,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  fontSize: 12.0,
                ),
              ),
              selected: isSelected,
              selectedColor: AppTheme.of(context).primary,
              backgroundColor: AppTheme.of(context).secondaryBackground,
              onSelected: (selected) async {
                if (selected) {
                  await _model.alterarDiaVisita(val);
                  if (mounted) safeSetState(() {});
                }
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildFiltrosSecundarios(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          // Filtro de Situação Ativo/Inativo
          _buildChipFiltro(
            label: _model.filtro.statusAtivo == 1
                ? 'Apenas Ativos'
                : _model.filtro.statusAtivo == 0
                    ? 'Apenas Inativos'
                    : 'Todos os Status',
            icon: Icons.check_circle_outline_rounded,
            onTap: () {
              final next = _model.filtro.statusAtivo == 1 ? 0 : (_model.filtro.statusAtivo == 0 ? -1 : 1);
              _model.alterarStatusAtivo(next);
            },
          ),
          const SizedBox(width: 8.0),
          // Filtro de Tipo de Pessoa
          _buildChipFiltro(
            label: _model.filtro.tipoPessoa == 1
                ? 'Pessoa Física (PF)'
                : _model.filtro.tipoPessoa == 2
                    ? 'Pessoa Jurídica (PJ)'
                    : 'PF / PJ (Todos)',
            icon: Icons.badge_outlined,
            onTap: () {
              final next = _model.filtro.tipoPessoa == -1 ? 2 : (_model.filtro.tipoPessoa == 2 ? 1 : -1);
              _model.alterarTipoPessoa(next);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildChipFiltro({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return ActionChip(
      avatar: Icon(icon, size: 16.0, color: AppTheme.of(context).primary),
      label: Text(
        label,
        style: GoogleFonts.inter(fontSize: 11.0, fontWeight: FontWeight.w500),
      ),
      backgroundColor: AppTheme.of(context).secondaryBackground,
      side: BorderSide(color: AppTheme.of(context).alternate),
      onPressed: onTap,
    );
  }

  Widget _buildBadgesResumo(BuildContext context, CarteiraRoteirizacaoResumo resumo) {
    return Row(
      children: [
        _buildBadgeItem(
          label: 'Total',
          valor: '${resumo.totalClientes}',
          cor: AppTheme.of(context).primary,
        ),
        const SizedBox(width: 8.0),
        _buildBadgeItem(
          label: 'Inadimplentes',
          valor: '${resumo.totalInadimplentes}',
          cor: const Color(0xFFDA1E28),
        ),
        const SizedBox(width: 8.0),
        _buildBadgeItem(
          label: 'A Vencer',
          valor: '${resumo.totalTitulosAVencer}',
          cor: const Color(0xFFD49500),
        ),
        const SizedBox(width: 8.0),
        _buildBadgeItem(
          label: 'Regulares',
          valor: '${resumo.totalRegulares}',
          cor: const Color(0xFF24A148),
        ),
      ],
    );
  }

  Widget _buildBadgeItem({
    required String label,
    required String valor,
    required Color cor,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 4.0),
        decoration: BoxDecoration(
          color: cor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8.0),
          border: Border.all(color: cor.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Text(
              valor,
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.bold,
                fontSize: 14.0,
                color: cor,
              ),
            ),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontSize: 10.0,
                color: cor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClienteCard(BuildContext context, ClienteRoteiroItem cliente) {
    final statusColor = cliente.possuiInadimplencia
        ? const Color(0xFFDA1E28)
        : cliente.possuiTitulosAVencer
            ? const Color(0xFFD49500)
            : const Color(0xFF24A148);

    return Container(
      margin: const EdgeInsets.only(bottom: 12.0),
      decoration: BoxDecoration(
        color: AppTheme.of(context).secondaryBackground,
        borderRadius: BorderRadius.circular(10.0),
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
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10.0),
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color: statusColor,
                width: 5.0,
              ),
            ),
          ),
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Cabeçalho: Nome e Badge de Risco
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          cliente.razaoSocial,
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.bold,
                            fontSize: 14.0,
                            color: AppTheme.of(context).primaryText,
                          ),
                        ),
                        if (cliente.nomeFantasia.isNotEmpty && cliente.nomeFantasia != cliente.razaoSocial)
                          Text(
                            cliente.nomeFantasia,
                            style: GoogleFonts.inter(
                              fontSize: 12.0,
                              color: AppTheme.of(context).secondaryText,
                            ),
                          ),
                        Text(
                          'Cód: ${cliente.codigo} • ${cliente.cpfCnpj.isNotEmpty ? cliente.cpfCnpj : 'Doc s/ cadastro'}',
                          style: GoogleFonts.inter(
                            fontSize: 11.0,
                            color: AppTheme.of(context).secondaryText,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 3.0),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12.0),
                      border: Border.all(color: statusColor.withValues(alpha: 0.4)),
                    ),
                    child: Text(
                      cliente.statusCreditoDescricao,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 10.0,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8.0),
              // Endereço e Localização
              if (cliente.enderecoCompleto.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4.0),
                  child: Row(
                    children: [
                      Icon(Icons.location_on_outlined, size: 14.0, color: AppTheme.of(context).secondaryText),
                      const SizedBox(width: 4.0),
                      Expanded(
                        child: Text(
                          cliente.enderecoCompleto,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 11.0,
                            color: AppTheme.of(context).secondaryText,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              // Linha Financeira e Limite
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Limite Disponível: ${formatPreco(cliente.limiteAtual) ?? 'R\$ 0,00'}',
                    style: GoogleFonts.inter(
                      fontSize: 11.0,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.of(context).primary,
                    ),
                  ),
                  if (cliente.possuiInadimplencia)
                    Text(
                      'Vencidos: ${formatPreco(cliente.titulosVencidos)}',
                      style: GoogleFonts.inter(
                        fontSize: 11.0,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFFDA1E28),
                      ),
                    )
                  else if (cliente.possuiTitulosAVencer)
                    Text(
                      'A Vencer: ${formatPreco(cliente.titulosAVencer)}',
                      style: GoogleFonts.inter(
                        fontSize: 11.0,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFFD49500),
                      ),
                    ),
                ],
              ),
              const Divider(height: 16.0),
              // Botões de Ação Rápida
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (cliente.telefoneFormatado.isNotEmpty)
                    OutlinedButton.icon(
                      onPressed: () => _fazerLigacao(cliente.telefone),
                      icon: const Icon(Icons.phone_rounded, size: 14.0),
                      label: const Text('Ligar'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 6.0),
                        textStyle: GoogleFonts.inter(fontSize: 11.0, fontWeight: FontWeight.w600),
                        side: BorderSide(color: AppTheme.of(context).alternate),
                      ),
                    ),
                  const SizedBox(width: 8.0),
                  OutlinedButton.icon(
                    onPressed: () => _abrirMapa(cliente),
                    icon: const Icon(Icons.directions_rounded, size: 14.0),
                    label: const Text('Mapa'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 6.0),
                      textStyle: GoogleFonts.inter(fontSize: 11.0, fontWeight: FontWeight.w600),
                      side: BorderSide(color: AppTheme.of(context).alternate),
                    ),
                  ),
                  const SizedBox(width: 8.0),
                  ElevatedButton.icon(
                    onPressed: () {
                      context.pushNamed(
                        'ExtratoClientePage',
                        queryParameters: {
                          'clienteId': serializeParam(cliente.codigo, ParamType.int),
                        }.withoutNulls,
                      );
                    },
                    icon: const Icon(Icons.receipt_long_rounded, size: 14.0),
                    label: const Text('Extrato'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.of(context).primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 6.0),
                      textStyle: GoogleFonts.inter(fontSize: 11.0, fontWeight: FontWeight.w600),
                      elevation: 0.0,
                    ),
                  ),
                ],
              ),
            ],
          ),
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
                Icons.people_outline_rounded,
                size: 36.0,
                color: AppTheme.of(context).secondaryText,
              ),
            ),
            const SizedBox(height: 16.0),
            Text(
              'Nenhum cliente roteirizado para este filtro',
              style: AppTheme.of(context).titleMedium.override(
                    font: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                    ),
                    fontSize: 16.0,
                  ),
            ),
            const SizedBox(height: 8.0),
            Text(
              'Tente selecionar outro dia da semana ou limpar a busca textual para visualizar outros clientes da sua carteira.',
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
