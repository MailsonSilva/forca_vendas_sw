import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '/core/app_theme.dart';
import '/action_code/contar_filiais.dart';

/// PRD 1 §1.5 — Modal/Card obrigatório para seleção de filial quando count(cadfil00) > 1.
/// Bloqueante: barrierDismissible false + WillPopScope canPop false.
class ModalSelecaoFilialWidget extends StatefulWidget {
  const ModalSelecaoFilialWidget({
    super.key,
    required this.filiais,
  });

  final List<FilialInfo> filiais;

  @override
  State<ModalSelecaoFilialWidget> createState() => _ModalSelecaoFilialWidgetState();
}

class _ModalSelecaoFilialWidgetState extends State<ModalSelecaoFilialWidget> {
  String? _selecionado;
  String _filtro = '';

  @override
  Widget build(BuildContext context) {
    final filtrados = widget.filiais.where((f) {
      final term = _filtro.toLowerCase();
      return f.descricao.toLowerCase().contains(term) || f.codigo.toLowerCase().contains(term);
    }).toList();

    return PopScope(
      canPop: false,
      child: Container(
        height: MediaQuery.of(context).size.height * 0.65,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20.0)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12.0),
            Container(
              width: 40.0,
              height: 5.0,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2.5),
              ),
            ),
            const SizedBox(height: 16.0),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                children: [
                  Icon(Icons.store_outlined, color: AppTheme.of(context).primary),
                  const SizedBox(width: 8.0),
                  Expanded(
                    child: Text(
                      'Selecione a Filial',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.bold,
                        fontSize: 18.0,
                        color: const Color(0xFF14181B),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Text(
                'Sua empresa possui múltiplas filiais. Selecione a filial ativa para isolar estoque, preços e sequenciais.',
                style: AppTheme.of(context).bodyMedium.override(
                      font: GoogleFonts.inter(color: AppTheme.of(context).secondaryText, fontSize: 13),
                    ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Pesquisar filial...',
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
            Expanded(
              child: RadioGroup<String>(
                groupValue: _selecionado ?? '',
                onChanged: (val) => setState(() => _selecionado = val),
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  itemCount: filtrados.length,
                  itemBuilder: (context, index) {
                    final f = filtrados[index];
                    final isSelected = _selecionado == f.codigo;
                    return Container(
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
                        value: f.codigo,
                        title: Text(f.descricao, style: AppTheme.of(context).bodyLarge.override(font: GoogleFonts.inter(fontWeight: FontWeight.w600))),
                        subtitle: Text('Código: ${f.codigo}', style: AppTheme.of(context).bodyMedium),
                        secondary: Icon(Icons.business_outlined, color: isSelected ? AppTheme.of(context).primary : Colors.grey),
                      ),
                    );
                  },
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: SizedBox(
                width: double.infinity,
                height: 48.0,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.of(context).primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
                  ),
                  onPressed: _selecionado == null ? null : () => Navigator.pop(context, _selecionado),
                  child: const Text('Confirmar Filial', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
