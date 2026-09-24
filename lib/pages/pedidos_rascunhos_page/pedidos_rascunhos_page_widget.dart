import 'dart:async';
import '/action_code/index.dart' as actions;
import '/core/app_theme.dart';
import '/core/app_util.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'pedidos_rascunhos_page_model.dart';
import '/action_code/listar_pedidos_pendentes.dart';
import '/pages/pedido_resumo/pedido_resumo_widget.dart';
import '/pages/pedido_novo_inicio/pedido_novo_inicio_widget.dart';
import '/pages/pedido_itens_lista/pedido_itens_lista_widget.dart';
import '/pages/gerar_pacote/gerar_pacote_page_widget.dart';
export 'pedidos_rascunhos_page_model.dart';

/// Central de Extrato e Histórico de Pedidos (Ecossistema Flutter)
class PedidosRascunhosPageWidget extends StatefulWidget {
  const PedidosRascunhosPageWidget({super.key});

  static String routeName = 'PedidosRascunhosPage';
  static String routePath = '/pedidos';

  @override
  State<PedidosRascunhosPageWidget> createState() =>
      _PedidosRascunhosPageWidgetState();
}

class _PedidosRascunhosPageWidgetState
    extends State<PedidosRascunhosPageWidget> with SingleTickerProviderStateMixin {
  late PedidosRascunhosPageModel _model;
  final scaffoldKey = GlobalKey<ScaffoldState>();
  late AnimationController _speedDialController;
  late Animation<double> _speedDialAnimation;

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => PedidosRascunhosPageModel());
    _speedDialController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _speedDialAnimation = CurvedAnimation(
      parent: _speedDialController,
      curve: Curves.easeOut,
    );
    _carregar();
  }

  @override
  void dispose() {
    _speedDialController.dispose();
    _model.dispose();
    super.dispose();
  }

  Future<void> _carregar() async {
    safeSetState(() => _model.isLoading = true);
    final lista = await listarPedidosHistorico(
      filtroTexto: _model.searchController?.text ?? '',
      filtroStatus: _model.filtroStatus,
      filtroPeriodo: _model.filtroPeriodo,
    );
    print('[_carregar PedidosRascunhos] Recebidos ${lista.length} pedidos da busca (status: ${_model.filtroStatus}, periodo: ${_model.filtroPeriodo})');
    if (!mounted) return;
    safeSetState(() {
      _model.pedidos = lista;
      _model.isLoading = false;
      // Remove ids que não existem mais na lista recarregada
      final validIds = lista.map((p) => p.pedidoId).toSet();
      _model.selectedPedidos.removeWhere((id) => !validIds.contains(id));
    });
  }

  void _toggleSpeedDial() {
    safeSetState(() {
      _model.isSpeedDialOpen = !_model.isSpeedDialOpen;
      if (_model.isSpeedDialOpen) {
        _speedDialController.forward();
      } else {
        _speedDialController.reverse();
      }
    });
  }

  void _fecharSpeedDial() {
    if (_model.isSpeedDialOpen) {
      safeSetState(() {
        _model.isSpeedDialOpen = false;
        _speedDialController.reverse();
      });
    }
  }

  void _toggleSelectAll() {
    final elegiveis = _model.pedidos.where((p) => p.podeEmpacotar).map((p) => p.pedidoId).toList();
    if (elegiveis.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nenhum pedido disponível para empacotar.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    safeSetState(() {
      final todosElegiveisSelecionados = elegiveis.every((id) => _model.selectedPedidos.contains(id));
      if (todosElegiveisSelecionados) {
        _model.selectedPedidos.clear();
      } else {
        _model.selectedPedidos.clear();
        _model.selectedPedidos.addAll(elegiveis);
      }
    });
  }

  void _toggleItemSelection(PedidoHistoricoItem item) {
    if (!item.podeEmpacotar) {
      String msg;
      if (item.isEmpacotado) {
        msg = 'O pedido #${item.pedidoId} já foi incluído no pacote "${item.nomePacote}" e não pode ser re-empacotado.';
      } else if (item.isTransmitido) {
        msg = 'O pedido #${item.pedidoId} já foi transmitido ao servidor FTP.';
      } else if (item.isFaturado) {
        msg = 'O pedido #${item.pedidoId} já foi faturado no ERP.';
      } else if (item.isRascunho) {
        msg = 'O pedido #${item.pedidoId} ainda é um rascunho. Conclua a digitação antes de empacotar.';
      } else {
        msg = 'O pedido #${item.pedidoId} não está disponível para empacotamento.';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: Colors.orange.shade800,
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }
    safeSetState(() {
      if (_model.selectedPedidos.contains(item.pedidoId)) {
        _model.selectedPedidos.remove(item.pedidoId);
      } else {
        _model.selectedPedidos.add(item.pedidoId);
      }
    });
  }

  Future<void> _criarPacoteSelecionados() async {
    _fecharSpeedDial();

    List<int> ids = _model.selectedPedidos.toList();
    if (ids.isEmpty) {
      // Se nada selecionado explicitamente, busca os pendentes elegíveis para empacotar
      final pendentes = _model.pedidos
          .where((p) => p.podeEmpacotar)
          .map((p) => p.pedidoId)
          .toList();

      if (pendentes.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Nenhum pedido concluído disponível para empacotar.'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      final bool? confirmar = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Criar Pacote (.pac)'),
          content: Text(
            'Nenhum pedido selecionado. Deseja empacotar todos os ${pendentes.length} pedidos aguardando pacote?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD97706),
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Empacotar Todos'),
            ),
          ],
        ),
      );

      if (confirmar != true) return;
      ids = pendentes;
    }

    safeSetState(() => _model.isLoading = true);
    try {
      final codRep = AppState().vendedor_codigo > 0 ? AppState().vendedor_codigo : 1;
      final fileName = await actions.gerarPacote(pedidosIds: ids, codRep: codRep);
      if (!mounted) return;
      safeSetState(() {
        _model.selectedPedidos.clear();
        _model.isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Pacote "$fileName" gerado com ${ids.length} pedido(s)! Redirecionando para envio...'),
          backgroundColor: const Color(0xFF2E7D32),
          duration: const Duration(seconds: 3),
        ),
      );

      // Redireciona automaticamente para a Tela de Pacotes
      await context.pushNamed(GerarPacotePageWidget.routeName);
      _carregar();
    } catch (e) {
      if (!mounted) return;
      safeSetState(() => _model.isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao gerar pacote: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _fmt(double v) => v.toMoeda();

  Color _getStatusColor(PedidoHistoricoItem item) {
    if (item.isFaturado) return const Color(0xFF2E7D32); // Verde
    if (item.isTransmitido) return const Color(0xFF0284C7); // Azul/Teal (Transmitido)
    if (item.isInconsistente) return const Color(0xFFD32F2F); // Vermelho
    if (item.isEmpacotado) return const Color(0xFFD97706); // Âmbar (Empacotado)
    if (item.isPendentePacote) return const Color(0xFFE65100); // Laranja (Aguardando Pacote)
    return const Color(0xFF1976D2); // Azul (Em Digitação/Rascunho)
  }

  String _getStatusLabel(PedidoHistoricoItem item) {
    if (item.isFaturado) return 'Faturado';
    if (item.isTransmitido) return 'Transmitido';
    if (item.isInconsistente) return 'Inconsistente';
    if (item.isEmpacotado) return 'Empacotado';
    if (item.isPendentePacote) return 'Aguardando Pacote';
    return 'Em Digitação';
  }

  IconData _getStatusIcon(PedidoHistoricoItem item) {
    if (item.isFaturado) return Icons.check_circle_rounded;
    if (item.isTransmitido) return Icons.cloud_done_rounded;
    if (item.isInconsistente) return Icons.error_outline_rounded;
    if (item.isEmpacotado) return Icons.inventory_2_rounded;
    if (item.isPendentePacote) return Icons.pending_actions_rounded;
    return Icons.edit_note_rounded;
  }

  Future<void> _confirmarExcluir(PedidoHistoricoItem item) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir Pedido?'),
        content: Text('Deseja realmente excluir o pedido #${item.pedidoId}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Excluir', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final ok = await excluirPedidoLocal(item.pedidoId);
      if (!mounted) return;
      if (ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Pedido #${item.pedidoId} excluído com sucesso.'),
            backgroundColor: Colors.green,
          ),
        );
        _carregar();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erro ao excluir pedido.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _clonarPedido(int pedidoId) async {
    safeSetState(() => _model.isLoading = true);
    final info = await clonarPedidoLocal(pedidoId);
    if (!mounted) return;
    safeSetState(() => _model.isLoading = false);

    if (info != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Pedido #${info.novoPedidoId} clonado com sucesso! Abrindo para edição...'),
          backgroundColor: const Color(0xFF2E7D32),
        ),
      );

      // Navega imediatamente para a tela de itens em estado de rascunho
      await context.pushNamed(
        PedidoItensListaWidget.routeName,
        queryParameters: {
          'pedidoId': info.novoPedidoId.toString(),
          'clienteCodigo': info.clienteCodigo.toString(),
          'clienteNome': info.clienteNome,
          'clienteCnpj': info.clienteCnpj,
          'clienteCidade': info.clienteCidade,
          'clienteLimite': info.clienteLimite,
          'clienteEndereco': info.clienteEndereco,
          'linhaCodigo': info.linhaCodigo,
          'linhaDescricao': info.linhaDescricao,
          'planoCodigo': info.planoCodigo,
          'planoDescricao': info.planoDescricao,
        }..removeWhere((k, v) => v == null || v.isEmpty),
      );
      _carregar();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Erro ao clonar pedido.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (Navigator.canPop(context)) {
          context.pop();
        } else {
          context.go('/homePage');
        }
      },
      child: GestureDetector(
        onTap: () {
          _fecharSpeedDial();
          FocusScope.of(context).unfocus();
          FocusManager.instance.primaryFocus?.unfocus();
        },
        child: Scaffold(
          key: scaffoldKey,
          backgroundColor: AppTheme.of(context).primaryBackground,
          appBar: AppBar(
            backgroundColor: AppTheme.of(context).primary,
            automaticallyImplyLeading: false,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () {
                if (Navigator.canPop(context)) {
                  context.pop();
                } else {
                  context.go('/homePage');
                }
              },
              tooltip: 'Voltar',
            ),
            iconTheme: const IconThemeData(color: Colors.white),
            title: Text(
              'Extrato e Histórico de Pedidos',
              style: AppTheme.of(context).titleLarge.override(
                    font: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w600,
                    ),
                    color: Colors.white,
                    fontSize: 20.0,
                    letterSpacing: 0.0,
                  ),
            ),
            centerTitle: false,
            elevation: 2.0,
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                onPressed: _carregar,
                tooltip: 'Atualizar',
              ),
              IconButton(
                icon: const Icon(Icons.inventory_2_outlined, color: Colors.white),
                onPressed: () => context.pushNamed(GerarPacotePageWidget.routeName),
                tooltip: 'Tela de Pacotes (.pac)',
              ),
            ],
          ),
        floatingActionButton: _buildSpeedDialFab(),
        body: SafeArea(
          child: Column(
            children: [
              // ── Search & Filter Section ─────────────────────────────────────
              Container(
                color: AppTheme.of(context).secondaryBackground,
                padding: const EdgeInsets.fromLTRB(16.0, 12.0, 16.0, 8.0),
                child: Column(
                  children: [
                    // Campo de pesquisa preditiva
                    TextField(
                      controller: _model.searchController,
                      focusNode: _model.searchFocusNode,
                      decoration: InputDecoration(
                        hintText: 'Buscar por cliente, nº do pedido ou linha...',
                        prefixIcon: const Icon(Icons.search_rounded),
                        suffixIcon: _model.searchController?.text.isNotEmpty == true
                            ? IconButton(
                                icon: const Icon(Icons.clear_rounded),
                                onPressed: () {
                                  _model.searchController?.clear();
                                  _carregar();
                                },
                              )
                            : null,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10.0),
                          borderSide: BorderSide(color: AppTheme.of(context).alternate),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10.0),
                          borderSide: BorderSide(color: AppTheme.of(context).alternate),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10.0),
                          borderSide: BorderSide(color: AppTheme.of(context).primary, width: 2.0),
                        ),
                        filled: true,
                        fillColor: AppTheme.of(context).primaryBackground,
                        contentPadding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 12.0),
                      ),
                      onChanged: (val) => _carregar(),
                    ),
                    const SizedBox(height: 8.0),

                    // Filtro de período
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildFilterChip('Todos Períodos', 'todos', _model.filtroPeriodo, (v) {
                            setState(() => _model.filtroPeriodo = v);
                            _carregar();
                          }),
                          const SizedBox(width: 6.0),
                          _buildFilterChip('Hoje', 'hoje', _model.filtroPeriodo, (v) {
                            setState(() => _model.filtroPeriodo = v);
                            _carregar();
                          }),
                          const SizedBox(width: 6.0),
                          _buildFilterChip('Esta Semana', 'semana', _model.filtroPeriodo, (v) {
                            setState(() => _model.filtroPeriodo = v);
                            _carregar();
                          }),
                          const SizedBox(width: 6.0),
                          _buildFilterChip('Este Mês', 'mes', _model.filtroPeriodo, (v) {
                            setState(() => _model.filtroPeriodo = v);
                            _carregar();
                          }),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6.0),

                    // Filtro de status
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildStatusChip('Todos', 'todos', _model.filtroStatus, const Color(0xFF616161)),
                          const SizedBox(width: 6.0),
                          _buildStatusChip('Rascunhos', 'rascunho', _model.filtroStatus, const Color(0xFF1976D2)),
                          const SizedBox(width: 6.0),
                          _buildStatusChip('Aguardando Pacote', 'pronto', _model.filtroStatus, const Color(0xFFE65100)),
                          const SizedBox(width: 6.0),
                          _buildStatusChip('Empacotados', 'empacotado', _model.filtroStatus, const Color(0xFFD97706)),
                          const SizedBox(width: 6.0),
                          _buildStatusChip('Transmitidos', 'transmitido', _model.filtroStatus, const Color(0xFF0284C7)),
                          const SizedBox(width: 6.0),
                          _buildStatusChip('Faturados', 'faturado', _model.filtroStatus, const Color(0xFF2E7D32)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // ── Barra de Seleção em Lote ────────────────────────────────────
              if (_model.pedidos.isNotEmpty)
                Builder(
                  builder: (context) {
                    final elegiveis = _model.pedidos.where((p) => p.podeEmpacotar).toList();
                    final allSelected = elegiveis.isNotEmpty && elegiveis.every((p) => _model.selectedPedidos.contains(p.pedidoId));
                    final hasSome = _model.selectedPedidos.isNotEmpty;

                    return Container(
                      color: hasSome
                          ? AppTheme.of(context).primary.withValues(alpha: 0.1)
                          : AppTheme.of(context).secondaryBackground,
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Checkbox(
                                value: allSelected,
                                tristate: hasSome && !allSelected,
                                onChanged: elegiveis.isEmpty ? null : (_) => _toggleSelectAll(),
                                activeColor: AppTheme.of(context).primary,
                                visualDensity: VisualDensity.compact,
                              ),
                              Text(
                                !hasSome
                                    ? (elegiveis.isNotEmpty
                                        ? 'Selecionar pedidos (${elegiveis.length} disponíveis)'
                                        : 'Nenhum pedido pendente para empacotar')
                                    : '${_model.selectedPedidos.length} de ${elegiveis.length} selecionado(s)',
                                style: TextStyle(
                                  color: hasSome
                                      ? AppTheme.of(context).primary
                                      : AppTheme.of(context).secondaryText,
                                  fontWeight: hasSome ? FontWeight.bold : FontWeight.normal,
                                  fontSize: 13.0,
                                ),
                              ),
                            ],
                          ),
                          if (hasSome)
                            TextButton.icon(
                              icon: const Icon(Icons.close_rounded, size: 16.0),
                              label: const Text('Limpar', style: TextStyle(fontSize: 12.0)),
                              onPressed: () => safeSetState(() => _model.selectedPedidos.clear()),
                            ),
                        ],
                      ),
                    );
                  },
                ),

              const Divider(height: 1.0, thickness: 1.0),

              // ── Orders List ─────────────────────────────────────────────────
              Expanded(
                child: _model.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _model.pedidos.isEmpty
                        ? RefreshIndicator(
                            onRefresh: _carregar,
                            child: SingleChildScrollView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              child: Padding(
                                padding: const EdgeInsets.all(40.0),
                                child: Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.inbox_outlined, size: 64.0, color: Colors.grey[400]),
                                      const SizedBox(height: 16.0),
                                      Text(
                                        'Nenhum pedido encontrado',
                                        style: AppTheme.of(context).titleMedium.override(
                                              font: GoogleFonts.inter(fontWeight: FontWeight.bold),
                                              color: Colors.grey[700],
                                            ),
                                      ),
                                      const SizedBox(height: 8.0),
                                      Text(
                                        'Tente alterar os filtros ou crie um novo pedido no botão abaixo.',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(color: Colors.grey[600]),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _carregar,
                            child: ListView.builder(
                              padding: const EdgeInsets.fromLTRB(16.0, 12.0, 16.0, 90.0),
                              itemCount: _model.pedidos.length,
                              itemBuilder: (context, index) {
                                final item = _model.pedidos[index];
                                return _buildPedidoCard(item);
                              },
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

  Widget _buildSpeedDialFab() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (_model.isSpeedDialOpen) ...[
          // Opção 1: Novo Pedido
          _buildSpeedDialItem(
            icon: Icons.add_shopping_cart_rounded,
            label: 'Novo Pedido',
            color: AppTheme.of(context).primary,
            onTap: () async {
              _fecharSpeedDial();
              await context.pushNamed(PedidoNovoInicioWidget.routeName);
              _carregar();
            },
          ),
          const SizedBox(height: 10.0),

          // Opção 2: Criar Pacote
          _buildSpeedDialItem(
            icon: Icons.inventory_2_rounded,
            label: _model.selectedPedidos.isNotEmpty
                ? 'Criar Pacote (${_model.selectedPedidos.length})'
                : 'Criar Pacote (.pac)',
            color: const Color(0xFFD97706), // Âmbar
            onTap: _criarPacoteSelecionados,
          ),
          const SizedBox(height: 10.0),

          // Opção 3: Clonar Pedido
          _buildSpeedDialItem(
            icon: Icons.copy_rounded,
            label: _model.selectedPedidos.length == 1
                ? 'Clonar Pedido #${_model.selectedPedidos.first}'
                : 'Clonar Pedido',
            color: const Color(0xFF0284C7), // Azul / Celeste
            onTap: () {
              _fecharSpeedDial();
              if (_model.selectedPedidos.length == 1) {
                _clonarPedido(_model.selectedPedidos.first);
              } else if (_model.selectedPedidos.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Selecione 1 pedido na lista para clonar.'),
                    backgroundColor: Colors.orange,
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Selecione apenas 1 pedido por vez para clonar.'),
                    backgroundColor: Colors.orange,
                  ),
                );
              }
            },
          ),
          const SizedBox(height: 12.0),
        ],

        // Botão Principal Flutuante com Ícone Inicial Dourado/Destaque
        FloatingActionButton(
          backgroundColor: _model.isSpeedDialOpen
              ? Colors.grey[800]
              : const Color(0xFFD97706), // Dourado / Âmbar
          foregroundColor: Colors.white,
          elevation: 4.0,
          onPressed: _toggleSpeedDial,
          tooltip: _model.isSpeedDialOpen ? 'Fechar Menu' : 'Ações Rápidas de Pedidos',
          child: AnimatedRotation(
            turns: _model.isSpeedDialOpen ? 0.25 : 0.0,
            duration: const Duration(milliseconds: 200),
            child: Icon(
              _model.isSpeedDialOpen ? Icons.close_rounded : Icons.bolt_rounded,
              size: 28.0,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSpeedDialItem({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ScaleTransition(
      scale: _speedDialAnimation,
      alignment: Alignment.centerRight,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24.0),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 8.0),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(24.0),
            boxShadow: const [
              BoxShadow(
                color: Color(0x33000000),
                blurRadius: 6.0,
                offset: Offset(0, 3),
              )
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13.0,
                ),
              ),
              const SizedBox(width: 8.0),
              Icon(icon, color: Colors.white, size: 20.0),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, String value, String current, Function(String) onSelect) {
    final isSelected = current == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onSelect(value),
      selectedColor: AppTheme.of(context).primary,
      backgroundColor: AppTheme.of(context).primaryBackground,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : AppTheme.of(context).primaryText,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        fontSize: 12.0,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _buildStatusChip(String label, String value, String current, Color baseColor) {
    final isSelected = current == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) {
        setState(() => _model.filtroStatus = value);
        _carregar();
      },
      selectedColor: baseColor.withValues(alpha: 0.2),
      backgroundColor: AppTheme.of(context).primaryBackground,
      checkmarkColor: baseColor,
      labelStyle: TextStyle(
        color: isSelected ? baseColor : AppTheme.of(context).secondaryText,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        fontSize: 12.0,
      ),
      side: BorderSide(
        color: isSelected ? baseColor : AppTheme.of(context).alternate,
        width: isSelected ? 1.5 : 1.0,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _buildPedidoCard(PedidoHistoricoItem item) {
    final statusColor = _getStatusColor(item);
    final statusLabel = _getStatusLabel(item);
    final statusIcon = _getStatusIcon(item);
    final isSelected = _model.selectedPedidos.contains(item.pedidoId);

    return Container(
      margin: const EdgeInsets.only(bottom: 12.0),
      decoration: BoxDecoration(
        color: AppTheme.of(context).secondaryBackground,
        borderRadius: BorderRadius.circular(14.0),
        border: Border.all(
          color: isSelected
              ? AppTheme.of(context).primary
              : item.isRascunho
                  ? AppTheme.of(context).primary.withValues(alpha: 0.3)
                  : const Color(0xFFE0E3E7),
          width: isSelected ? 2.0 : 1.0,
        ),
        boxShadow: const [
          BoxShadow(
            blurRadius: 4.0,
            color: Color(0x12000000),
            offset: Offset(0.0, 2.0),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header do Card ────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.08),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(13.0)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    // Checkbox de seleção do pedido (apenas se disponível para empacotar)
                    if (item.podeEmpacotar)
                      Checkbox(
                        value: isSelected,
                        onChanged: (_) => _toggleItemSelection(item),
                        activeColor: AppTheme.of(context).primary,
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      )
                    else
                      Tooltip(
                        message: item.isEmpacotado
                            ? 'Já incluído no pacote ${item.nomePacote}'
                            : item.isRascunho
                                ? 'Pedido em digitação'
                                : 'Pedido já transmitido',
                        child: InkWell(
                          onTap: () => _toggleItemSelection(item),
                          borderRadius: BorderRadius.circular(4.0),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 2.0),
                            child: Icon(
                              item.isEmpacotado
                                  ? Icons.lock_outline_rounded
                                  : Icons.lock_clock_rounded,
                              size: 16.0,
                              color: item.isEmpacotado ? const Color(0xFFD97706) : Colors.grey.shade400,
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(width: 4.0),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                      decoration: BoxDecoration(
                        color: AppTheme.of(context).primary,
                        borderRadius: BorderRadius.circular(6.0),
                      ),
                      child: Text(
                        '#${item.pedidoId}',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13.0),
                      ),
                    ),
                    const SizedBox(width: 8.0),
                    Text(
                      item.dataEmissao.isNotEmpty ? item.dataEmissao : '—',
                      style: TextStyle(color: Colors.grey[700], fontSize: 12.0, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8.0),
                    border: Border.all(color: statusColor, width: 1.0),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, size: 14.0, color: statusColor),
                      const SizedBox(width: 4.0),
                      Text(
                        statusLabel,
                        style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 11.0),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Corpo do Card ─────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14.0, 12.0, 14.0, 8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Cliente
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.person_outline_rounded, size: 18.0, color: Colors.grey),
                    const SizedBox(width: 6.0),
                    Expanded(
                      child: Text(
                        '${item.clienteCodigo} - ${item.clienteNome}',
                        style: AppTheme.of(context).bodyLarge.override(
                              font: GoogleFonts.inter(fontWeight: FontWeight.w600),
                              fontSize: 14.0,
                            ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6.0),

                // Linha e Plano
                Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          const Icon(Icons.category_outlined, size: 15.0, color: Colors.grey),
                          const SizedBox(width: 4.0),
                          Expanded(
                            child: Text(
                              item.linhaDescricao.isNotEmpty ? item.linhaDescricao : 'Linha —',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: Colors.grey[700], fontSize: 12.0),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8.0),
                    Expanded(
                      child: Row(
                        children: [
                          const Icon(Icons.payment_outlined, size: 15.0, color: Colors.grey),
                          const SizedBox(width: 4.0),
                          Expanded(
                            child: Text(
                              item.planoDescricao.isNotEmpty ? item.planoDescricao : 'Plano —',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: Colors.grey[700], fontSize: 12.0),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                if (item.agenteDescricao.isNotEmpty) ...[
                  const SizedBox(height: 4.0),
                  Row(
                    children: [
                      const Icon(Icons.badge_outlined, size: 15.0, color: Colors.grey),
                      const SizedBox(width: 4.0),
                      Expanded(
                        child: Text(
                          'Agente: ${item.agenteDescricao}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: Colors.grey[700], fontSize: 12.0),
                        ),
                      ),
                    ],
                  ),
                ],

                if (item.nomePacote.isNotEmpty) ...[
                  const SizedBox(height: 4.0),
                  Row(
                    children: [
                      const Icon(Icons.inventory_2_outlined, size: 15.0, color: Colors.orange),
                      const SizedBox(width: 4.0),
                      Expanded(
                        child: Text(
                          'Pacote: ${item.nomePacote}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.orange, fontSize: 12.0, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ],

                const Divider(height: 16.0),

                // ── Totais e Valores ──────────────────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Itens: ${item.quantidadeItens.toStringAsFixed(0)}', style: TextStyle(color: Colors.grey[600], fontSize: 11.0)),
                        if (item.valorBonus > 0)
                          Text('Bônus: ${_fmt(item.valorBonus)}', style: const TextStyle(color: Colors.purple, fontSize: 11.0, fontWeight: FontWeight.w500)),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('Produtos: ${_fmt(item.valorProdutos)}', style: TextStyle(color: Colors.grey[600], fontSize: 11.0)),
                        Text(
                          'Total: ${_fmt(item.totalFatura)}',
                          style: AppTheme.of(context).titleMedium.override(
                                font: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold),
                                color: AppTheme.of(context).primary,
                                fontSize: 15.0,
                              ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ── Rodapé com Ações ──────────────────────────────────────────────
          const Divider(height: 1.0),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Ação: Extrato / Resumo
                TextButton.icon(
                  icon: const Icon(Icons.receipt_long_outlined, size: 16.0),
                  label: const Text('Extrato', style: TextStyle(fontSize: 12.0)),
                  onPressed: () async {
                    await context.pushNamed(
                      PedidoResumoWidget.routeName,
                      queryParameters: {'pedidoId': item.pedidoId.toString()},
                    );
                    _carregar();
                  },
                ),

                Row(
                  children: [
                    // Ação: Editar (se rascunho)
                    if (item.isRascunho)
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 18.0, color: Colors.blue),
                        tooltip: 'Editar Pedido',
                        onPressed: () async {
                          await context.pushNamed(
                            PedidoItensListaWidget.routeName,
                            queryParameters: {
                              'pedidoId': item.pedidoId.toString(),
                              'clienteCodigo': item.clienteCodigo.toString(),
                              'clienteNome': item.clienteNome,
                              'clienteCnpj': item.clienteCnpj,
                              'clienteCidade': item.clienteCidade,
                              'clienteLimite': item.clienteLimite,
                              'clienteEndereco': item.clienteEndereco,
                              'linhaCodigo': item.linhaCodigo,
                              'linhaDescricao': item.linhaDescricao,
                              'planoCodigo': item.planoCodigo,
                              'planoDescricao': item.planoDescricao,
                            }..removeWhere((k, v) => v == null || v.isEmpty),
                          );
                          _carregar();
                        },
                      ),

                    // Ação: Clonar
                    IconButton(
                      icon: const Icon(Icons.copy_outlined, size: 18.0, color: Colors.teal),
                      tooltip: 'Clonar Pedido',
                      onPressed: () => _clonarPedido(item.pedidoId),
                    ),

                    // Ação: Excluir (se rascunho)
                    if (item.isRascunho)
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, size: 18.0, color: Colors.redAccent),
                        tooltip: 'Excluir Rascunho',
                        onPressed: () => _confirmarExcluir(item),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

