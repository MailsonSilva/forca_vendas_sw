import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '/core/app_theme.dart';
import '/core/app_util.dart';
import '/action_code/listar_pedidos_pendentes.dart';
import '/action_code/listar_clientes_pendentes.dart';
import '/action_code/gerar_pacote.dart';
import '/action_code/enviar_arquivos_pendentes_ftp.dart';

class GerarPacotePageWidget extends StatefulWidget {
  const GerarPacotePageWidget({super.key});

  static String routeName = 'GerarPacotePage';
  static String routePath = '/gerarPacote';

  @override
  State<GerarPacotePageWidget> createState() => _GerarPacotePageWidgetState();
}

class _GerarPacotePageWidgetState extends State<GerarPacotePageWidget> {
  // Aba ativa: 0 = Pedidos Pendentes, 1 = Novos Clientes, 2 = Pacotes / Transmissão
  int _abaAtiva = 0;

  // Estado da Aba 0: Pedidos Pendentes de Empacotamento
  List<PedidoPendente> _pedidosPendentes = [];
  final Set<int> _pedidosSelecionados = {};
  bool _gerandoPacote = false;

  // Estado da Aba 1: Novos Clientes Pendentes
  List<ClientePendenteItem> _clientesPendentes = [];

  // Estado da Aba 2: Pacotes (.pac) e Arquivos Prontos
  List<PacoteItem> _todosPacotes = [];
  final Set<String> _pacotesSelecionados = {};
  String _filtroPacotes = 'pendentes'; // 'pendentes', 'enviados', 'todos'

  bool _loading = true;
  bool _enviando = false;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    safeSetState(() => _loading = true);

    try {
      final pacotes = await listarPacotesAgrupados(filtro: 'todos');
      final pedidos = await listarPedidosPendentes();
      final clientes = await listarClientesPendentes(filtro: 'todos');

      if (!mounted) return;
      safeSetState(() {
        _todosPacotes = pacotes;
        _pedidosPendentes = pedidos;
        _clientesPendentes = clientes;
        _loading = false;

        // Limpa seleções de itens que não existem mais
        final pedidosAtivos = pedidos.map((p) => p.pedidoId).toSet();
        _pedidosSelecionados.removeWhere((id) => !pedidosAtivos.contains(id));

        final pacotesAtivos = pacotes.map((p) => p.nomeArquivo).toSet();
        _pacotesSelecionados.removeWhere((name) => !pacotesAtivos.contains(name));
      });
    } catch (e) {
      if (mounted) safeSetState(() => _loading = false);
    }
  }

  // ── Métodos de Seleção ───────────────────────────────────────────────────────

  void _togglePedido(int pedidoId) {
    safeSetState(() {
      if (_pedidosSelecionados.contains(pedidoId)) {
        _pedidosSelecionados.remove(pedidoId);
      } else {
        _pedidosSelecionados.add(pedidoId);
      }
    });
  }

  void _toggleAllPedidos(bool selectAll) {
    safeSetState(() {
      if (selectAll) {
        _pedidosSelecionados.addAll(_pedidosPendentes.map((p) => p.pedidoId));
      } else {
        _pedidosSelecionados.clear();
      }
    });
  }

  void _togglePacote(String nomeArquivo) {
    safeSetState(() {
      if (_pacotesSelecionados.contains(nomeArquivo)) {
        _pacotesSelecionados.remove(nomeArquivo);
      } else {
        _pacotesSelecionados.add(nomeArquivo);
      }
    });
  }

  void _toggleAllPacotes(bool selectAll) {
    safeSetState(() {
      if (selectAll) {
        final pendentes = _pacotesFiltrados.where((p) => p.isPendente).map((e) => e.nomeArquivo);
        _pacotesSelecionados.addAll(pendentes);
      } else {
        _pacotesSelecionados.clear();
      }
    });
  }

  // ── Ação: Gerar Pacote Manualmente ──────────────────────────────────────────

  Future<void> _executarGerarPacote() async {
    final List<int> idsParaEmpacotar = _pedidosSelecionados.isNotEmpty
        ? _pedidosSelecionados.toList()
        : _pedidosPendentes.map((p) => p.pedidoId).toList();

    if (idsParaEmpacotar.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nenhum pedido pendente selecionado para empacotar.'),
          backgroundColor: Colors.orangeAccent,
        ),
      );
      return;
    }

    final bool? confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.inventory_2_rounded, color: Color(0xFFD97706)),
            SizedBox(width: 8.0),
            Text('Gerar Pacote (.pac)'),
          ],
        ),
        content: Text(
          'Deseja agrupar ${idsParaEmpacotar.length} pedido(s) selecionado(s) em um novo arquivo .pac comprimido?',
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
            child: const Text('Confirmar e Gerar'),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    safeSetState(() => _gerandoPacote = true);

    try {
      final int codRep = AppState().vendedor_codigo;
      final String nomePacote = await gerarPacote(
        pedidosIds: idsParaEmpacotar,
        codRep: codRep > 0 ? codRep : 71,
      );

      if (!mounted) return;

      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: const Icon(Icons.check_circle_rounded, size: 48.0, color: Color(0xFF2E7D32)),
          title: const Text('Pacote Gerado com Sucesso!'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Arquivo criado: $nomePacote',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.0),
              ),
              const SizedBox(height: 8.0),
              Text(
                'Total de ${idsParaEmpacotar.length} pedido(s) empacotado(s) e prontos na fila temp/ para envio via FTP.',
                style: const TextStyle(fontSize: 13.0),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
          ],
        ),
      );

      safeSetState(() {
        _pedidosSelecionados.clear();
        _abaAtiva = 2; // Redireciona para a aba de Pacotes Prontos
      });

      await _carregar();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao gerar pacote: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) safeSetState(() => _gerandoPacote = false);
    }
  }

  // ── Ação: Enviar Cargas via FTP ─────────────────────────────────────────────

  Future<void> _enviarCargaFtp({
    bool enviarPedidos = true,
    bool enviarClientes = true,
    List<String>? nomesAlvo,
  }) async {
    final bool? confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.cloud_upload_rounded, color: Color(0xFF0284C7)),
            SizedBox(width: 8.0),
            Text('Conectar e Enviar Carga'),
          ],
        ),
        content: const Text(
          'Deseja transmitir os pacotes de pedidos (.pac) e cadastros de clientes (.xml) para o servidor FTP?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0284C7),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Iniciar Envio'),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    safeSetState(() => _enviando = true);

    try {
      final result = await enviarArquivosPendentesFtp(
        enviarClientes: enviarClientes,
        enviarPedidos: enviarPedidos,
        arquivosSelecionados: nomesAlvo,
      );

      if (!mounted) return;

      if (result.success) {
        await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            icon: const Icon(Icons.check_circle_rounded, size: 48.0, color: Color(0xFF2E7D32)),
            title: const Text('Transmissão Concluída!'),
            content: Text(
              '${result.message}\n\nArquivos confirmados no servidor com verificação de integridade (SIZE) e status atualizado localmente.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('OK'),
              ),
            ],
          ),
        );

        safeSetState(() {
          _pacotesSelecionados.clear();
          _filtroPacotes = 'enviados';
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Falha na transmissão FTP: ${result.message}'),
            backgroundColor: Colors.red,
          ),
        );
      }

      await _carregar();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro na transmissão FTP: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) safeSetState(() => _enviando = false);
    }
  }

  // ── Contagens e Filtros ─────────────────────────────────────────────────────

  List<PacoteItem> get _pacotesFiltrados {
    switch (_filtroPacotes) {
      case 'pendentes':
        return _todosPacotes.where((p) => p.isPendente).toList();
      case 'enviados':
        return _todosPacotes.where((p) => p.isEnviado).toList();
      default:
        return _todosPacotes;
    }
  }

  int get _countPacotesPendentes => _todosPacotes.where((p) => p.isPendente).length;
  int get _countClientesPendentes => _clientesPendentes.where((c) => c.isPendente).length;

  String _fmt(double v) => v.toMoeda();

  String _formatarBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.of(context).primaryBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.of(context).primary,
        automaticallyImplyLeading: true,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          'Central de Transmissão',
          style: AppTheme.of(context).titleLarge.override(
                font: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w600,
                ),
                color: Colors.white,
                fontSize: 19.0,
              ),
        ),
        centerTitle: false,
        elevation: 2.0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            onPressed: _carregar,
            tooltip: 'Atualizar Central',
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // ── Menu de Navegação Superior (3 Abas Unificadas da Spec) ───────
            Container(
              color: AppTheme.of(context).secondaryBackground,
              padding: const EdgeInsets.fromLTRB(12.0, 10.0, 12.0, 8.0),
              child: Row(
                children: [
                  _buildAbaButton(
                    index: 0,
                    icon: Icons.pending_actions_rounded,
                    label: 'Pedidos',
                    badge: _pedidosPendentes.length,
                    badgeColor: const Color(0xFFD97706),
                  ),
                  const SizedBox(width: 8.0),
                  _buildAbaButton(
                    index: 1,
                    icon: Icons.person_add_alt_1_rounded,
                    label: 'Clientes',
                    badge: _countClientesPendentes,
                    badgeColor: const Color(0xFF7C3AED),
                  ),
                  const SizedBox(width: 8.0),
                  _buildAbaButton(
                    index: 2,
                    icon: Icons.inventory_2_rounded,
                    label: 'Pacotes / FTP',
                    badge: _countPacotesPendentes,
                    badgeColor: const Color(0xFF0284C7),
                  ),
                ],
              ),
            ),
            const Divider(height: 1.0, thickness: 1.0),

            // ── Conteúdo da Aba Ativa ───────────────────────────────────────
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _buildConteudoAba(),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomAction(),
    );
  }

  // ── Botão de Seleção de Aba ─────────────────────────────────────────────────

  Widget _buildAbaButton({
    required int index,
    required IconData icon,
    required String label,
    required int badge,
    required Color badgeColor,
  }) {
    final bool isSelected = _abaAtiva == index;
    return Expanded(
      child: InkWell(
        onTap: () => safeSetState(() => _abaAtiva = index),
        borderRadius: BorderRadius.circular(8.0),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
          decoration: BoxDecoration(
            color: isSelected
                ? AppTheme.of(context).primary.withValues(alpha: 0.10)
                : AppTheme.of(context).primaryBackground,
            borderRadius: BorderRadius.circular(8.0),
            border: Border.all(
              color: isSelected ? AppTheme.of(context).primary : AppTheme.of(context).alternate,
              width: isSelected ? 1.8 : 1.0,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    icon,
                    size: 16.0,
                    color: isSelected ? AppTheme.of(context).primary : Colors.grey[600],
                  ),
                  const SizedBox(width: 4.0),
                  Text(
                    label,
                    style: TextStyle(
                      color: isSelected ? AppTheme.of(context).primary : AppTheme.of(context).primaryText,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                      fontSize: 12.0,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 3.0),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 1.0),
                decoration: BoxDecoration(
                  color: badge > 0 ? badgeColor : Colors.grey[300],
                  borderRadius: BorderRadius.circular(10.0),
                ),
                child: Text(
                  badge.toString(),
                  style: TextStyle(
                    color: badge > 0 ? Colors.white : Colors.grey[700],
                    fontWeight: FontWeight.bold,
                    fontSize: 11.0,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Conteúdo por Aba ────────────────────────────────────────────────────────

  Widget _buildConteudoAba() {
    switch (_abaAtiva) {
      case 0:
        return _buildAbaPedidosPendentes();
      case 1:
        return _buildAbaClientesPendentes();
      case 2:
      default:
        return _buildAbaPacotesEnvio();
    }
  }

  // ── ABA 0: Pedidos Pendentes de Empacotamento ───────────────────────────────

  Widget _buildAbaPedidosPendentes() {
    if (_pedidosPendentes.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle_outline_rounded, size: 64.0, color: Color(0xFF2E7D32)),
              const SizedBox(height: 14.0),
              const Text(
                'Nenhum pedido aguardando pacote',
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16.0),
              ),
              const SizedBox(height: 6.0),
              Text(
                'Todos os pedidos concluídos já foram empacotados em lotes .pac.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600], fontSize: 13.0),
              ),
            ],
          ),
        ),
      );
    }

    final allSelected = _pedidosPendentes.isNotEmpty &&
        _pedidosPendentes.every((p) => _pedidosSelecionados.contains(p.pedidoId));

    return Column(
      children: [
        // Barra de Seleção em Lote
        Container(
          color: _pedidosSelecionados.isNotEmpty
              ? const Color(0xFFD97706).withValues(alpha: 0.10)
              : AppTheme.of(context).secondaryBackground,
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Checkbox(
                    value: allSelected,
                    onChanged: (v) => _toggleAllPedidos(v ?? false),
                    activeColor: const Color(0xFFD97706),
                    visualDensity: VisualDensity.compact,
                  ),
                  Text(
                    _pedidosSelecionados.isEmpty
                        ? 'Selecionar todos os pedidos (${_pedidosPendentes.length})'
                        : '${_pedidosSelecionados.length} pedido(s) selecionado(s)',
                    style: TextStyle(
                      fontWeight: _pedidosSelecionados.isNotEmpty ? FontWeight.bold : FontWeight.w500,
                      color: _pedidosSelecionados.isNotEmpty ? const Color(0xFFD97706) : AppTheme.of(context).secondaryText,
                      fontSize: 13.0,
                    ),
                  ),
                ],
              ),
              if (_pedidosSelecionados.isNotEmpty)
                TextButton.icon(
                  icon: const Icon(Icons.close_rounded, size: 16.0),
                  label: const Text('Limpar', style: TextStyle(fontSize: 12.0)),
                  onPressed: () => safeSetState(() => _pedidosSelecionados.clear()),
                ),
            ],
          ),
        ),
        const Divider(height: 1.0),

        // Lista de Pedidos Pendentes
        Expanded(
          child: RefreshIndicator(
            onRefresh: _carregar,
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16.0, 12.0, 16.0, 90.0),
              itemCount: _pedidosPendentes.length,
              itemBuilder: (context, index) {
                final p = _pedidosPendentes[index];
                final isSelected = _pedidosSelecionados.contains(p.pedidoId);

                return Container(
                  margin: const EdgeInsets.only(bottom: 10.0),
                  decoration: BoxDecoration(
                    color: AppTheme.of(context).secondaryBackground,
                    borderRadius: BorderRadius.circular(10.0),
                    border: Border.all(
                      color: isSelected ? const Color(0xFFD97706) : AppTheme.of(context).alternate,
                      width: isSelected ? 1.8 : 1.0,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        blurRadius: 3.0,
                        color: Color(0x15000000),
                        offset: Offset(0, 1),
                      )
                    ],
                  ),
                  child: InkWell(
                    onTap: () => _togglePedido(p.pedidoId),
                    borderRadius: BorderRadius.circular(10.0),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Checkbox(
                            value: isSelected,
                            onChanged: (_) => _togglePedido(p.pedidoId),
                            activeColor: const Color(0xFFD97706),
                            visualDensity: VisualDensity.compact,
                          ),
                          const SizedBox(width: 8.0),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Pedido #${p.pedidoId}',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.0),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.0),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFD97706).withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(4.0),
                                      ),
                                      child: const Text(
                                        'Aguardando Pacote',
                                        style: TextStyle(
                                          color: Color(0xFFD97706),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 10.0,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4.0),
                                Text(
                                  p.clienteNome,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13.0,
                                    color: AppTheme.of(context).primaryText,
                                  ),
                                ),
                                const SizedBox(height: 3.0),
                                Text(
                                  'Cód: ${p.clienteCodigo} • Linha: ${p.linhaDescricao}',
                                  style: TextStyle(fontSize: 12.0, color: Colors.grey[600]),
                                ),
                                Text(
                                  'Plano: ${p.planoDescricao} • Data: ${p.data}',
                                  style: TextStyle(fontSize: 12.0, color: Colors.grey[600]),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  // ── ABA 1: Novos Clientes Pendentes ─────────────────────────────────────────

  Widget _buildAbaClientesPendentes() {
    if (_clientesPendentes.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.people_outline_rounded, size: 64.0, color: Color(0xFF7C3AED)),
              const SizedBox(height: 14.0),
              const Text(
                'Nenhum cliente com sincronização pendente',
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16.0),
              ),
              const SizedBox(height: 6.0),
              Text(
                'Novos cadastros e edições de clientes geram arquivos XML prontos para transmissão FTP.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600], fontSize: 13.0),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _carregar,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16.0, 12.0, 16.0, 90.0),
        itemCount: _clientesPendentes.length,
        itemBuilder: (context, index) {
          final c = _clientesPendentes[index];
          final isPendente = c.isPendente;

          return Container(
            margin: const EdgeInsets.only(bottom: 10.0),
            decoration: BoxDecoration(
              color: AppTheme.of(context).secondaryBackground,
              borderRadius: BorderRadius.circular(10.0),
              border: Border.all(
                color: isPendente ? const Color(0xFF7C3AED).withValues(alpha: 0.5) : AppTheme.of(context).alternate,
                width: 1.0,
              ),
              boxShadow: const [
                BoxShadow(
                  blurRadius: 3.0,
                  color: Color(0x15000000),
                  offset: Offset(0, 1),
                )
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 40.0,
                    height: 40.0,
                    decoration: BoxDecoration(
                      color: isPendente
                          ? const Color(0xFF7C3AED).withValues(alpha: 0.15)
                          : const Color(0xFF2E7D32).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                    child: Icon(
                      Icons.person_rounded,
                      color: isPendente ? const Color(0xFF7C3AED) : const Color(0xFF2E7D32),
                      size: 22.0,
                    ),
                  ),
                  const SizedBox(width: 12.0),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Cliente #${c.clienteCodigo}',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.0),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.0),
                              decoration: BoxDecoration(
                                color: (isPendente ? const Color(0xFF7C3AED) : const Color(0xFF2E7D32)).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4.0),
                              ),
                              child: Text(
                                isPendente ? 'Aguardando FTP' : 'Transmitido',
                                style: TextStyle(
                                  color: isPendente ? const Color(0xFF7C3AED) : const Color(0xFF2E7D32),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 10.0,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4.0),
                        Text(
                          c.razaoSocial,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13.0,
                            color: AppTheme.of(context).primaryText,
                          ),
                        ),
                        if (c.cpfCnpj.isNotEmpty) ...[
                          const SizedBox(height: 2.0),
                          Text(
                            'Doc: ${c.cpfCnpj} • ${c.cidadeUf}',
                            style: TextStyle(fontSize: 12.0, color: Colors.grey[600]),
                          ),
                        ],
                        const SizedBox(height: 4.0),
                        Row(
                          children: [
                            const Icon(Icons.insert_drive_file_outlined, size: 14.0, color: Colors.grey),
                            const SizedBox(width: 4.0),
                            Text(
                              c.nomeArquivoXml,
                              style: const TextStyle(fontSize: 11.0, fontFamily: 'monospace', color: Colors.grey),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ── ABA 2: Pacotes (.pac) e Envio FTP ───────────────────────────────────────

  Widget _buildAbaPacotesEnvio() {
    final exibidos = _pacotesFiltrados;
    final pendentesNaLista = exibidos.where((p) => p.isPendente).toList();
    final allPendentesSelected = pendentesNaLista.isNotEmpty &&
        pendentesNaLista.every((p) => _pacotesSelecionados.contains(p.nomeArquivo));

    return Column(
      children: [
        // Filtros por Chip (Pendentes, Enviados, Todos)
        Container(
          color: AppTheme.of(context).secondaryBackground,
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            children: [
              _buildFiltroChip(
                label: 'Pendentes',
                count: _countPacotesPendentes,
                value: 'pendentes',
                activeColor: const Color(0xFFD97706),
              ),
              const SizedBox(width: 8.0),
              _buildFiltroChip(
                label: 'Enviados',
                count: _todosPacotes.where((p) => p.isEnviado).length,
                value: 'enviados',
                activeColor: const Color(0xFF2E7D32),
              ),
              const SizedBox(width: 8.0),
              _buildFiltroChip(
                label: 'Todos',
                count: _todosPacotes.length,
                value: 'todos',
                activeColor: AppTheme.of(context).primary,
              ),
            ],
          ),
        ),

        // Barra de Seleção em Lote de Pacotes
        if (pendentesNaLista.isNotEmpty)
          Container(
            color: _pacotesSelecionados.isNotEmpty
                ? AppTheme.of(context).primary.withValues(alpha: 0.08)
                : AppTheme.of(context).secondaryBackground,
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Checkbox(
                      value: allPendentesSelected,
                      onChanged: (v) => _toggleAllPacotes(v ?? false),
                      activeColor: AppTheme.of(context).primary,
                      visualDensity: VisualDensity.compact,
                    ),
                    Text(
                      _pacotesSelecionados.isEmpty
                          ? 'Selecionar todos os pendentes'
                          : '${_pacotesSelecionados.length} pacote(s) selecionado(s)',
                      style: TextStyle(
                        fontWeight: _pacotesSelecionados.isNotEmpty ? FontWeight.bold : FontWeight.w500,
                        color: _pacotesSelecionados.isNotEmpty
                            ? AppTheme.of(context).primary
                            : AppTheme.of(context).secondaryText,
                        fontSize: 13.0,
                      ),
                    ),
                  ],
                ),
                if (_pacotesSelecionados.isNotEmpty)
                  TextButton.icon(
                    icon: const Icon(Icons.close_rounded, size: 16.0),
                    label: const Text('Limpar', style: TextStyle(fontSize: 12.0)),
                    onPressed: () => safeSetState(() => _pacotesSelecionados.clear()),
                  ),
              ],
            ),
          ),
        const Divider(height: 1.0),

        Expanded(
          child: exibidos.isEmpty
              ? _buildEmptyStatePacotes()
              : RefreshIndicator(
                  onRefresh: _carregar,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16.0, 12.0, 16.0, 90.0),
                    itemCount: exibidos.length,
                    itemBuilder: (context, index) {
                      final pacote = exibidos[index];
                      return _buildPacoteCard(pacote);
                    },
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildFiltroChip({
    required String label,
    required int count,
    required String value,
    required Color activeColor,
  }) {
    final isSelected = _filtroPacotes == value;
    return Expanded(
      child: InkWell(
        onTap: () => safeSetState(() => _filtroPacotes = value),
        borderRadius: BorderRadius.circular(8.0),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 7.0, horizontal: 6.0),
          decoration: BoxDecoration(
            color: isSelected ? activeColor : AppTheme.of(context).primaryBackground,
            borderRadius: BorderRadius.circular(8.0),
            border: Border.all(
              color: isSelected ? activeColor : AppTheme.of(context).alternate,
              width: isSelected ? 1.5 : 1.0,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : AppTheme.of(context).primaryText,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                  fontSize: 12.0,
                ),
              ),
              const SizedBox(height: 2.0),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 1.0),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.white.withValues(alpha: 0.25)
                      : activeColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10.0),
                ),
                child: Text(
                  count.toString(),
                  style: TextStyle(
                    color: isSelected ? Colors.white : activeColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 11.0,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPacoteCard(PacoteItem pacote) {
    final isPending = pacote.isPendente;
    final isSelected = _pacotesSelecionados.contains(pacote.nomeArquivo);
    final statusColor = isPending ? const Color(0xFFD97706) : const Color(0xFF2E7D32);
    final statusLabel = isPending ? 'Aguardando FTP' : 'Transmitido com Sucesso';
    final statusIcon = isPending ? Icons.inventory_2_rounded : Icons.cloud_done_rounded;

    return Container(
      margin: const EdgeInsets.only(bottom: 12.0),
      decoration: BoxDecoration(
        color: AppTheme.of(context).secondaryBackground,
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(
          color: isSelected
              ? AppTheme.of(context).primary
              : isPending
                  ? const Color(0xFFD97706).withValues(alpha: 0.5)
                  : AppTheme.of(context).alternate,
          width: isSelected ? 2.0 : 1.0,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 4.0,
            offset: Offset(0, 2),
          )
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(10.0, 10.0, 14.0, 0.0),
            child: Row(
              children: [
                if (isPending)
                  Checkbox(
                    value: isSelected,
                    onChanged: (_) => _togglePacote(pacote.nomeArquivo),
                    activeColor: AppTheme.of(context).primary,
                    visualDensity: VisualDensity.compact,
                  ),
                const Icon(Icons.archive_outlined, color: Color(0xFF0284C7), size: 24.0),
                const SizedBox(width: 8.0),
                Expanded(
                  child: Text(
                    pacote.nomeArquivo,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15.0),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 3.0),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6.0),
                    border: Border.all(color: statusColor, width: 1.0),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, size: 13.0, color: statusColor),
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
          Padding(
            padding: const EdgeInsets.fromLTRB(14.0, 10.0, 14.0, 10.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.receipt_outlined, size: 16.0, color: Colors.grey),
                    const SizedBox(width: 6.0),
                    Expanded(
                      child: Builder(
                        builder: (context) {
                          final distinctIds = pacote.pedidosIds.toSet().toList();
                          final count = distinctIds.isNotEmpty
                              ? distinctIds.length
                              : (pacote.totalPedidos > 0 ? pacote.totalPedidos : 1);
                          return Text(
                            distinctIds.isNotEmpty
                                ? '$count pedido(s): ${distinctIds.map((id) => '#$id').join(', ')}'
                                : '$count pedido(s) contidos no lote',
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.0),
                          );
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6.0),
                Row(
                  children: [
                    const Icon(Icons.access_time_rounded, size: 15.0, color: Colors.grey),
                    const SizedBox(width: 6.0),
                    Text(
                      pacote.data.isNotEmpty ? pacote.data : '—',
                      style: TextStyle(color: Colors.grey[700], fontSize: 12.0),
                    ),
                    const SizedBox(width: 12.0),
                    const Icon(Icons.data_usage_rounded, size: 15.0, color: Colors.grey),
                    const SizedBox(width: 4.0),
                    Text(
                      _formatarBytes(pacote.tamanhoBytes),
                      style: TextStyle(color: Colors.grey[700], fontSize: 12.0),
                    ),
                  ],
                ),
                if (pacote.totalValor > 0) ...[
                  const SizedBox(height: 6.0),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Total do Lote:',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12.0),
                      ),
                      Text(
                        _fmt(pacote.totalValor),
                        style: TextStyle(
                          color: AppTheme.of(context).primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 14.0,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          if (isPending) ...[
            const Divider(height: 1.0),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 4.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Fila temp/',
                    style: TextStyle(fontSize: 11.0, color: Colors.grey[600]),
                  ),
                  TextButton.icon(
                    style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                    icon: const Icon(Icons.send_rounded, size: 15.0, color: Color(0xFF0284C7)),
                    label: const Text('Enviar este Pacote', style: TextStyle(color: Color(0xFF0284C7), fontSize: 12.0)),
                    onPressed: () => _enviarCargaFtp(nomesAlvo: [pacote.nomeArquivo]),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyStatePacotes() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inventory_2_outlined, size: 64.0, color: Colors.grey[400]),
            const SizedBox(height: 14.0),
            const Text(
              'Nenhum pacote na lista',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16.0),
            ),
            const SizedBox(height: 8.0),
            Text(
              'Selecione pedidos na aba "Pedidos" e clique em "Gerar Pacote (.pac)" para criar novos arquivos de transmissão.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600], fontSize: 13.0),
            ),
          ],
        ),
      ),
    );
  }

  // ── Botão Principal de Ação no Rodapé (Dinâmico por Aba) ─────────────────────

  Widget? _buildBottomAction() {
    if (_abaAtiva == 0) {
      // Aba de Pedidos: Botão "Gerar Pacote (.pac)"
      if (_pedidosPendentes.isEmpty) return null;

      final countSel = _pedidosSelecionados.isNotEmpty
          ? _pedidosSelecionados.length
          : _pedidosPendentes.length;

      return Container(
        padding: const EdgeInsets.fromLTRB(16.0, 10.0, 16.0, 14.0),
        decoration: BoxDecoration(
          color: AppTheme.of(context).secondaryBackground,
          boxShadow: const [
            BoxShadow(
              color: Color(0x1A000000),
              blurRadius: 6.0,
              offset: Offset(0, -2),
            )
          ],
        ),
        child: SafeArea(
          child: SizedBox(
            width: double.infinity,
            height: 48.0,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD97706), // Laranja / Empacotamento
                foregroundColor: Colors.white,
                elevation: 2.0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
              ),
              onPressed: _gerandoPacote ? null : _executarGerarPacote,
              icon: _gerandoPacote
                  ? const SizedBox(
                      width: 18.0,
                      height: 18.0,
                      child: CircularProgressIndicator(strokeWidth: 2.0, color: Colors.white),
                    )
                  : const Icon(Icons.inventory_2_rounded, size: 22.0),
              label: Text(
                _gerandoPacote
                    ? 'Empacotando Pedidos...'
                    : _pedidosSelecionados.isNotEmpty
                        ? 'Gerar Pacote (.pac) com $countSel Selecionado(s)'
                        : 'Gerar Pacote (.pac) com Todos ($countSel)',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.0),
              ),
            ),
          ),
        ),
      );
    } else if (_abaAtiva == 1) {
      // Aba de Clientes: Botão "Conectar e Enviar Clientes"
      if (_countClientesPendentes == 0) return null;

      return Container(
        padding: const EdgeInsets.fromLTRB(16.0, 10.0, 16.0, 14.0),
        decoration: BoxDecoration(
          color: AppTheme.of(context).secondaryBackground,
          boxShadow: const [
            BoxShadow(
              color: Color(0x1A000000),
              blurRadius: 6.0,
              offset: Offset(0, -2),
            )
          ],
        ),
        child: SafeArea(
          child: SizedBox(
            width: double.infinity,
            height: 48.0,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7C3AED), // Roxo / Clientes
                foregroundColor: Colors.white,
                elevation: 2.0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
              ),
              onPressed: _enviando
                  ? null
                  : () => _enviarCargaFtp(enviarPedidos: false, enviarClientes: true),
              icon: _enviando
                  ? const SizedBox(
                      width: 18.0,
                      height: 18.0,
                      child: CircularProgressIndicator(strokeWidth: 2.0, color: Colors.white),
                    )
                  : const Icon(Icons.cloud_upload_rounded, size: 22.0),
              label: Text(
                _enviando ? 'Transmitindo Clientes...' : 'Transmitir Clientes Pendentes ($_countClientesPendentes) ao FTP',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.0),
              ),
            ),
          ),
        ),
      );
    } else {
      // Aba de Pacotes: Botão "Conectar / Enviar Carga"
      if (_countPacotesPendentes == 0 && _pacotesSelecionados.isEmpty) return null;

      return Container(
        padding: const EdgeInsets.fromLTRB(16.0, 10.0, 16.0, 14.0),
        decoration: BoxDecoration(
          color: AppTheme.of(context).secondaryBackground,
          boxShadow: const [
            BoxShadow(
              color: Color(0x1A000000),
              blurRadius: 6.0,
              offset: Offset(0, -2),
            )
          ],
        ),
        child: SafeArea(
          child: SizedBox(
            width: double.infinity,
            height: 48.0,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0284C7), // Azul / FTP
                foregroundColor: Colors.white,
                elevation: 2.0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
              ),
              onPressed: _enviando
                  ? null
                  : () => _enviarCargaFtp(
                        enviarPedidos: true,
                        enviarClientes: true,
                        nomesAlvo: _pacotesSelecionados.isNotEmpty ? _pacotesSelecionados.toList() : null,
                      ),
              icon: _enviando
                  ? const SizedBox(
                      width: 18.0,
                      height: 18.0,
                      child: CircularProgressIndicator(strokeWidth: 2.0, color: Colors.white),
                    )
                  : const Icon(Icons.cloud_upload_rounded, size: 22.0),
              label: Text(
                _enviando
                    ? 'Transmitindo via FTP...'
                    : _pacotesSelecionados.isNotEmpty
                        ? 'Enviar Selecionados (${_pacotesSelecionados.length}) para o FTP'
                        : 'Conectar e Enviar Carga Completa ao FTP',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.0),
              ),
            ),
          ),
        ),
      );
    }
  }
}
