import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '/core/app_theme.dart';
import '/core/app_util.dart';
import '/action_code/listar_pedidos_pendentes.dart';
import '/action_code/enviar_arquivos_pendentes_ftp.dart';
import '/pages/pedidos_rascunhos_page/pedidos_rascunhos_page_widget.dart';

class GerarPacotePageWidget extends StatefulWidget {
  const GerarPacotePageWidget({super.key});

  static String routeName = 'GerarPacotePage';
  static String routePath = '/gerarPacote';

  @override
  State<GerarPacotePageWidget> createState() => _GerarPacotePageWidgetState();
}

class _GerarPacotePageWidgetState extends State<GerarPacotePageWidget> {
  List<PacoteItem> _todosPacotes = [];
  Set<String> _selecionados = {};
  String _filtroAtual = 'pendentes'; // 'pendentes', 'enviados', 'todos'
  bool _loading = true;
  bool _enviando = false;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    safeSetState(() => _loading = true);
    final lista = await listarPacotesAgrupados(filtro: 'todos');
    if (!mounted) return;
    safeSetState(() {
      _todosPacotes = lista;
      _loading = false;
      // Remove da seleção arquivos que não existem mais
      final nomesAtivos = lista.map((p) => p.nomeArquivo).toSet();
      _selecionados.removeWhere((nome) => !nomesAtivos.contains(nome));
    });
  }

  List<PacoteItem> get _pacotesFiltrados {
    switch (_filtroAtual) {
      case 'pendentes':
        return _todosPacotes.where((p) => p.isPendente).toList();
      case 'enviados':
        return _todosPacotes.where((p) => p.isEnviado).toList();
      default:
        return _todosPacotes;
    }
  }

  int get _countPendentes => _todosPacotes.where((p) => p.isPendente).length;
  int get _countEnviados => _todosPacotes.where((p) => p.isEnviado).length;

  void _toggle(String nomeArquivo) {
    safeSetState(() {
      if (_selecionados.contains(nomeArquivo)) {
        _selecionados.remove(nomeArquivo);
      } else {
        _selecionados.add(nomeArquivo);
      }
    });
  }

  void _toggleAll(bool selectAll) {
    safeSetState(() {
      if (selectAll) {
        final pendentes = _pacotesFiltrados.where((p) => p.isPendente).map((e) => e.nomeArquivo);
        _selecionados = pendentes.toSet();
      } else {
        _selecionados.clear();
      }
    });
  }

  Future<void> _enviarPacotesParaFtp({List<String>? nomesAlvo}) async {
    final List<String> arquivosParaEnviar = (nomesAlvo != null && nomesAlvo.isNotEmpty)
        ? nomesAlvo
        : (_selecionados.isNotEmpty
            ? _selecionados.toList()
            : _todosPacotes.where((p) => p.isPendente).map((p) => p.nomeArquivo).toList());

    if (arquivosParaEnviar.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nenhum pacote pendente para envio.'),
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
            Icon(Icons.cloud_upload_rounded, color: Color(0xFF0284C7)),
            SizedBox(width: 8.0),
            Text('Enviar Pacotes ao FTP'),
          ],
        ),
        content: Text(
          'Deseja transmitir ${arquivosParaEnviar.length} pacote(s) (.pac) para o servidor FTP?',
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
            child: const Text('Confirmar Envio'),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    safeSetState(() {
      _enviando = true;
    });

    try {
      final result = await enviarArquivosPendentesFtp(
        enviarClientes: true,
        enviarPedidos: true,
        arquivosSelecionados: arquivosParaEnviar,
      );

      if (!mounted) return;

      if (result.success) {
        await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            icon: const Icon(Icons.check_circle_rounded, size: 48.0, color: Color(0xFF2E7D32)),
            title: const Text('Upload FTP Concluído!'),
            content: Text(
              '${arquivosParaEnviar.length} pacote(s) transmitido(s) com confirmação SIZE no servidor.\n\nStatus dos pedidos migrado para "Transmitido (sttenv = 2)".',
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
          _selecionados.clear();
          _filtroAtual = 'enviados'; // Migra visualização para enviados
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Falha no upload FTP: ${result.message}'),
            backgroundColor: Colors.red,
          ),
        );
      }

      await _carregar();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao enviar via FTP: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) safeSetState(() => _enviando = false);
    }
  }

  String _fmt(double v) => 'R\$ ${v.toStringAsFixed(2).replaceAll('.', ',')}';

  String _formatarBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final exibidos = _pacotesFiltrados;
    final pendentesNaLista = exibidos.where((p) => p.isPendente).toList();
    final allPendentesSelected = pendentesNaLista.isNotEmpty &&
        pendentesNaLista.every((p) => _selecionados.contains(p.nomeArquivo));

    return Scaffold(
      backgroundColor: AppTheme.of(context).primaryBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.of(context).primary,
        automaticallyImplyLeading: true,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          'Gestão de Pacotes (.pac)',
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
            tooltip: 'Atualizar Lista',
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // ── Filtros por Aba/Chip no Topo ─────────────────────────────────
            Container(
              color: AppTheme.of(context).secondaryBackground,
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
              child: Row(
                children: [
                  _buildFiltroChip(
                    label: 'Pendentes',
                    count: _countPendentes,
                    value: 'pendentes',
                    activeColor: const Color(0xFFD97706),
                  ),
                  const SizedBox(width: 8.0),
                  _buildFiltroChip(
                    label: 'Enviados',
                    count: _countEnviados,
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

            // ── Barra de Seleção em Lote (visível se houver pendentes) ────────
            if (pendentesNaLista.isNotEmpty)
              Container(
                color: _selecionados.isNotEmpty
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
                          onChanged: (v) => _toggleAll(v ?? false),
                          activeColor: AppTheme.of(context).primary,
                          visualDensity: VisualDensity.compact,
                        ),
                        Text(
                          _selecionados.isEmpty
                              ? 'Selecionar todos os pendentes'
                              : '${_selecionados.length} pacote(s) selecionado(s)',
                          style: TextStyle(
                            fontWeight: _selecionados.isNotEmpty ? FontWeight.bold : FontWeight.w500,
                            color: _selecionados.isNotEmpty
                                ? AppTheme.of(context).primary
                                : AppTheme.of(context).secondaryText,
                            fontSize: 13.0,
                          ),
                        ),
                      ],
                    ),
                    if (_selecionados.isNotEmpty)
                      TextButton.icon(
                        icon: const Icon(Icons.close_rounded, size: 16.0),
                        label: const Text('Limpar', style: TextStyle(fontSize: 12.0)),
                        onPressed: () => safeSetState(() => _selecionados.clear()),
                      ),
                  ],
                ),
              ),

            const Divider(height: 1.0, thickness: 1.0),

            // ── Lista de Pacotes ─────────────────────────────────────────────
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : exibidos.isEmpty
                      ? _buildEmptyState()
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
        ),
      ),

      // ── Botão Principal Fixo no Rodapé: Enviar para o FTP ──────────────────
      bottomNavigationBar: (_filtroAtual == 'pendentes' || _selecionados.isNotEmpty || _countPendentes > 0)
          ? Container(
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
                      backgroundColor: const Color(0xFF0284C7), // Azul / Envio FTP
                      foregroundColor: Colors.white,
                      elevation: 2.0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10.0),
                      ),
                    ),
                    onPressed: _enviando ? null : () => _enviarPacotesParaFtp(),
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
                          : _selecionados.isNotEmpty
                              ? 'Enviar Selecionados (${_selecionados.length}) para o FTP'
                              : 'Enviar Todos Pendentes ($_countPendentes) para o FTP',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.0),
                    ),
                  ),
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildFiltroChip({
    required String label,
    required int count,
    required String value,
    required Color activeColor,
  }) {
    final isSelected = _filtroAtual == value;
    return Expanded(
      child: InkWell(
        onTap: () => safeSetState(() => _filtroAtual = value),
        borderRadius: BorderRadius.circular(8.0),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 6.0),
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
    final isSelected = _selecionados.contains(pacote.nomeArquivo);
    final statusColor = isPending ? const Color(0xFFD97706) : const Color(0xFF2E7D32);
    final statusLabel = isPending ? 'Aguardando Envio (FTP)' : 'Transmitido com Sucesso';
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
                  ? const Color(0xFFD97706).withValues(alpha: 0.4)
                  : const Color(0xFFE0E3E7),
          width: isSelected ? 2.0 : 1.0,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F000000),
            blurRadius: 4.0,
            offset: Offset(0, 2),
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
              borderRadius: const BorderRadius.vertical(top: Radius.circular(11.0)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    if (isPending) ...[
                      Checkbox(
                        value: isSelected,
                        onChanged: (_) => _toggle(pacote.nomeArquivo),
                        activeColor: AppTheme.of(context).primary,
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      const SizedBox(width: 4.0),
                    ],
                    Icon(Icons.inventory_2_outlined, size: 18.0, color: statusColor),
                    const SizedBox(width: 6.0),
                    Text(
                      pacote.nomeArquivo,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.0),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
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

          // ── Corpo do Card ─────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14.0, 10.0, 14.0, 10.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Pedidos no Pacote
                Row(
                  children: [
                    const Icon(Icons.receipt_outlined, size: 16.0, color: Colors.grey),
                    const SizedBox(width: 6.0),
                    Expanded(
                      child: Text(
                        pacote.pedidosIds.isNotEmpty
                            ? '${pacote.pedidosIds.length} pedido(s): ${pacote.pedidosIds.map((id) => '#$id').join(', ')}'
                            : '${pacote.totalPedidos > 0 ? pacote.totalPedidos : 1} pedido(s) contidos no lote',
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.0),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6.0),

                // Data e Tamanho
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

          // ── Rodapé do Card com Ação Rápida ────────────────────────────────
          if (isPending) ...[
            const Divider(height: 1.0),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 4.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Armazenado na fila temp/',
                    style: TextStyle(fontSize: 11.0, color: Colors.grey[600]),
                  ),
                  TextButton.icon(
                    style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                    icon: const Icon(Icons.send_rounded, size: 15.0, color: Color(0xFF0284C7)),
                    label: const Text('Enviar este Pacote', style: TextStyle(color: Color(0xFF0284C7), fontSize: 12.0)),
                    onPressed: () => _enviarPacotesParaFtp(nomesAlvo: [pacote.nomeArquivo]),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    IconData icon;
    String title;
    String subtitle;

    if (_filtroAtual == 'pendentes') {
      icon = Icons.mark_email_read_rounded;
      title = 'Nenhum pacote pendente de envio';
      subtitle = 'Todos os pacotes gerados já foram transmitidos com sucesso via FTP.';
    } else if (_filtroAtual == 'enviados') {
      icon = Icons.cloud_queue_rounded;
      title = 'Nenhum pacote transmitido ainda';
      subtitle = 'Os pacotes enviados via FTP aparecerão aqui com status confirmado.';
    } else {
      icon = Icons.inventory_2_outlined;
      title = 'Nenhum pacote registrado';
      subtitle = 'Selecione pedidos no Extrato e clique em "Gerar Pacote" para criar lotes .pac.';
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64.0, color: Colors.grey[400]),
            const SizedBox(height: 14.0),
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppTheme.of(context).titleMedium.override(
                    font: GoogleFonts.inter(fontWeight: FontWeight.bold),
                    color: Colors.grey[700],
                  ),
            ),
            const SizedBox(height: 8.0),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600], fontSize: 13.0),
            ),
            const SizedBox(height: 20.0),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.of(context).primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
              ),
              onPressed: () => context.pushNamed(PedidosRascunhosPageWidget.routeName),
              icon: const Icon(Icons.receipt_long_rounded, size: 18.0),
              label: const Text('Ver Histórico de Pedidos'),
            ),
          ],
        ),
      ),
    );
  }
}
