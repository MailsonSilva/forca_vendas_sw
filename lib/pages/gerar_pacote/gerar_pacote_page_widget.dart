import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '/core/app_theme.dart';
import '/core/app_util.dart';
import '/action_code/listar_pedidos_pendentes.dart';
import '/action_code/gerar_pacote.dart';

class GerarPacotePageWidget extends StatefulWidget {
  const GerarPacotePageWidget({super.key});

  static String routeName = 'GerarPacotePage';
  static String routePath = '/gerarPacote';

  @override
  State<GerarPacotePageWidget> createState() => _GerarPacotePageWidgetState();
}

class _GerarPacotePageWidgetState extends State<GerarPacotePageWidget> {
  List<PedidoPendente> _pedidos = [];
  Set<int> _selecionados = {};
  bool _loading = true;
  bool _gerando = false;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() => _loading = true);
    final lista = await listarPedidosPendentes();
    if (!mounted) return;
    setState(() {
      _pedidos = lista;
      _loading = false;
    });
  }

  void _toggle(int id) {
    setState(() {
      if (_selecionados.contains(id)) {
        _selecionados.remove(id);
      } else {
        _selecionados.add(id);
      }
    });
  }

  void _toggleAll(bool selectAll) {
    setState(() {
      if (selectAll) {
        _selecionados = _pedidos.map((e) => e.pedidoId).toSet();
      } else {
        _selecionados.clear();
      }
    });
  }

  Future<void> _gerarPacotes() async {
    if (_selecionados.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Selecione ao menos um pedido.'), backgroundColor: Colors.orangeAccent));
      return;
    }
    setState(() => _gerando = true);
    try {
      final codRep = AppState().vendedor_codigo;
      final nomePacote = await gerarPacote(pedidosIds: _selecionados.toList(), codRep: codRep == 0 ? 1 : codRep);
      if (!mounted) return;
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Row(children: [Icon(Icons.check_circle, color: Colors.green), SizedBox(width: 8), Text('Pacote gerado')]),
          content: Text('Processo concluído!\nPacote $nomePacote gerado com sucesso!'),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
        ),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Pacote $nomePacote gerado com sucesso!'), backgroundColor: Colors.green));
      await _carregar();
      setState(() => _selecionados.clear());
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao gerar pacote: $e'), backgroundColor: Colors.redAccent));
    } finally {
      if (mounted) setState(() => _gerando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final allSelected = _pedidos.isNotEmpty && _selecionados.length == _pedidos.length;
    return Scaffold(
      backgroundColor: AppTheme.of(context).primaryBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.of(context).primary,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text('Geração de Pacotes', style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 20)),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _pedidos.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey),
                      const SizedBox(height: 12),
                      Text('Nenhum pedido aguardando empacotamento.', textAlign: TextAlign.center, style: AppTheme.of(context).bodyLarge),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: AppTheme.of(context).primary),
                        onPressed: () => context.go('/homePage'),
                        child: const Text('Voltar ao Menu', style: TextStyle(color: Colors.white)),
                      ),
                    ]),
                  ),
                )
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                      child: Row(
                        children: [
                          Checkbox(value: allSelected, onChanged: (v) => _toggleAll(v ?? false)),
                          const Text('Selecionar todos', style: TextStyle(fontWeight: FontWeight.w600)),
                          const Spacer(),
                          Text('${_selecionados.length} selecionado(s)', style: const TextStyle(color: Colors.grey)),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.all(12.0),
                        itemCount: _pedidos.length,
                        itemBuilder: (context, index) {
                          final p = _pedidos[index];
                          final sel = _selecionados.contains(p.pedidoId);
                          return Card(
                            color: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
                            margin: const EdgeInsets.only(bottom: 10),
                            child: CheckboxListTile(
                              value: sel,
                              onChanged: (_) => _toggle(p.pedidoId),
                              title: Text('Pedido #${p.pedidoId} — ${p.clienteNome}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 4),
                                  Text('Cliente: ${p.clienteCodigo}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                  Text('Data: ${p.data.isNotEmpty ? p.data : '—'}  •  Plano: ${p.planoDescricao}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                  Text('Linha: ${p.linhaDescricao}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                ],
                              ),
                              secondary: Icon(Icons.description_outlined, color: sel ? AppTheme.of(context).primary : Colors.grey),
                              activeColor: AppTheme.of(context).primary,
                            ),
                          );
                        },
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(16.0),
                      decoration: const BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, -2))]),
                      child: SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.of(context).primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0))),
                          onPressed: _gerando ? null : _gerarPacotes,
                          icon: _gerando ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.archive_outlined, color: Colors.white),
                          label: Text(_gerando ? 'Gerando...' : 'Gerar pacotes', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }
}
