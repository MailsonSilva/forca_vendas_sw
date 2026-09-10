import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '/core/app_theme.dart';
import '/core/app_icon_button.dart';
import '/backend/schema/structs/lista_padrao_struct.dart';
import '/action_code/carregar_agentes_cobrador.dart';

class ModalAgenteCobradorWidget extends StatefulWidget {
  const ModalAgenteCobradorWidget({
    super.key,
    this.agentePreSelecionado,
    this.clienteCodigo,
    this.planoCodigo,
  });

  final String? agentePreSelecionado;
  final int? clienteCodigo;
  final int? planoCodigo;

  @override
  State<ModalAgenteCobradorWidget> createState() => _ModalAgenteCobradorWidgetState();
}

class _ModalAgenteCobradorWidgetState extends State<ModalAgenteCobradorWidget> {
  List<ListaPadraoStruct> _agentes = [];
  String? _selecionado;
  bool _loading = true;
  String _filtro = '';

  @override
  void initState() {
    super.initState();
    _selecionado = widget.agentePreSelecionado;
    _carregar();
  }

  Future<void> _carregar() async {
    final lista = await carregarAgentesCobrador(
      clienteCodigo: widget.clienteCodigo,
      planoCodigo: widget.planoCodigo,
    );
    if (!mounted) return;
    setState(() {
      _agentes = lista;
      _loading = false;
      // se pre-selecionado não existe na lista, mantém null
      if (_selecionado != null && _agentes.isNotEmpty) {
        final exists = _agentes.any((a) => a.codigo == _selecionado);
        if (!exists) _selecionado = null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final filtrados = _agentes.where((a) {
      final term = _filtro.toLowerCase();
      return a.descricao.toLowerCase().contains(term) || a.codigo.toLowerCase().contains(term);
    }).toList();

    return Align(
      alignment: Alignment.bottomCenter,
      heightFactor: 1.0,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600.0),
        child: Material(
          color: Colors.transparent,
          child: Container(
            height: MediaQuery.sizeOf(context).height * 0.75,
            decoration: BoxDecoration(
              color: AppTheme.of(context).primaryBackground,
              boxShadow: const [
                BoxShadow(
                  blurRadius: 10.0,
                  color: Color(0x33000000),
                  offset: Offset(0.0, -2.0),
                )
              ],
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20.0),
                topRight: Radius.circular(20.0),
              ),
            ),
            child: SafeArea(
              top: false,
              bottom: true,
              child: Column(
                children: [
                  // Drag handle
                  Padding(
                    padding: const EdgeInsets.only(top: 10.0, bottom: 4.0),
                    child: Container(
                      width: 40.0,
                      height: 4.0,
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(2.0),
                      ),
                    ),
                  ),
                  // Header
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Icon(
                                Icons.person_search_rounded,
                                color: AppTheme.of(context).primary,
                                size: 24.0,
                              ),
                              const SizedBox(width: 8.0),
                              Expanded(
                                child: Text(
                                  'Selecione o Agente Cobrador',
                                  style: AppTheme.of(context).titleLarge.override(
                                        font: GoogleFonts.outfit(
                                          fontWeight: FontWeight.w600,
                                        ),
                                        color: AppTheme.of(context).primaryText,
                                        fontSize: 18.0,
                                      ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        AppIconButton(
                          borderColor: const Color(0xFFE0E3E7),
                          borderRadius: 12.0,
                          borderWidth: 1.0,
                          buttonSize: 38.0,
                          icon: Icon(
                            Icons.close_rounded,
                            color: AppTheme.of(context).primaryText,
                            size: 18.0,
                          ),
                          onPressed: () async {
                            Navigator.pop(context);
                          },
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1.0, thickness: 1.0),
                  const SizedBox(height: 8.0),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Pesquisar agente...',
                prefixIcon: const Icon(Icons.search_rounded),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.0),
                  borderSide: BorderSide(color: AppTheme.of(context).alternate),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.0),
                  borderSide: BorderSide(color: AppTheme.of(context).alternate),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.0),
                  borderSide: BorderSide(color: AppTheme.of(context).primary, width: 2.0),
                ),
                filled: true,
                fillColor: AppTheme.of(context).primaryBackground,
                contentPadding: const EdgeInsets.symmetric(vertical: 12.0),
              ),
              onChanged: (val) => setState(() => _filtro = val),
            ),
          ),
          const SizedBox(height: 12.0),
          if (_loading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (_agentes.isEmpty)
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.person_off_outlined, size: 48, color: Colors.grey),
                      const SizedBox(height: 12),
                      Text('Nenhum agente cobrador homologado para este cliente e plano.\nSerá usado o vendedor logado.',
                          textAlign: TextAlign.center,
                          style: AppTheme.of(context).bodyMedium),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: AppTheme.of(context).primary),
                        onPressed: () => Navigator.pop(context, ''),
                        child: const Text('Continuar sem agente', style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            Expanded(
              child: RadioGroup<String>(
                groupValue: _selecionado ?? '',
                onChanged: (val) => setState(() => _selecionado = val),
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  itemCount: filtrados.length,
                  itemBuilder: (context, index) {
                    final a = filtrados[index];
                    final isSelected = _selecionado == a.codigo;
                    return InkWell(
                      onTap: () => setState(() => _selecionado = a.codigo),
                      borderRadius: BorderRadius.circular(12.0),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8.0),
                        decoration: BoxDecoration(
                          color: isSelected ? AppTheme.of(context).primary.withValues(alpha: 0.08) : Colors.white,
                          borderRadius: BorderRadius.circular(12.0),
                          border: Border.all(
                            color: isSelected ? AppTheme.of(context).primary : const Color(0xFFE0E3E7),
                            width: isSelected ? 2.0 : 1.0,
                          ),
                        ),
                        child: RadioListTile<String>(
                          value: a.codigo,
                          title: Text(a.descricao, style: AppTheme.of(context).bodyLarge.override(font: GoogleFonts.inter(fontWeight: FontWeight.w600))),
                          subtitle: Text('Código: ${a.codigo}', style: AppTheme.of(context).bodyMedium),
                          secondary: Icon(Icons.person_outline, color: isSelected ? AppTheme.of(context).primary : Colors.grey),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          if (!_loading)
            SafeArea(
              top: false,
              bottom: true,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: SizedBox(
                  width: double.infinity,
                  height: 48.0,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.of(context).primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
                    ),
                    onPressed: () {
                      final sel = _selecionado ?? (_agentes.isNotEmpty ? _agentes.first.codigo : '');
                      Navigator.pop(context, sel);
                    },
                    child: const Text('Confirmar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
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
