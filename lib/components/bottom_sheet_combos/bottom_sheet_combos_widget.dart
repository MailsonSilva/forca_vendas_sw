import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as path_pkg;
import '/backend/schema/structs/index.dart';
import '/core/app_theme.dart';
import '/core/app_util.dart';
import 'bottom_sheet_combos_model.dart';
export 'bottom_sheet_combos_model.dart';

class BottomSheetCombosWidget extends StatefulWidget {
  const BottomSheetCombosWidget({
    super.key,
    required this.pedidoId,
    required this.codFilial,
    required this.codTabela,
    required this.codLinha,
  });

  final int pedidoId;
  final int codFilial;
  final int codTabela;
  final String? codLinha;

  @override
  State<BottomSheetCombosWidget> createState() =>
      _BottomSheetCombosWidgetState();
}

class _BottomSheetCombosWidgetState extends State<BottomSheetCombosWidget> {
  late BottomSheetCombosModel _model;

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => BottomSheetCombosModel());

    _model.txtQtdCombosController ??= TextEditingController(text: '1');
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _carregarCombos();
    });
  }

  @override
  void dispose() {
    _model.dispose();
    super.dispose();
  }

  Future<Database> _getDatabase() async {
    final dbPath = path_pkg.join(await getDatabasesPath(), 'dbforcacad001.db');
    return await openDatabase(dbPath);
  }

  Future<void> _carregarCombos() async {
    setState(() {
      _model.isLoading = true;
    });

    try {
      final db = await _getDatabase();
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

      final results = await db.rawQuery('''
        SELECT cmb00_codcmb, cmb00_descri
        FROM estdefcmb00
        WHERE cmb00_codfil = ? 
          AND cmb00_sttatu = 1
          AND (cmb00_datini <= ? OR cmb00_datini IS NULL OR cmb00_datini = '')
          AND (cmb00_datfim >= ? OR cmb00_datfim IS NULL OR cmb00_datfim = '')
      ''', [widget.codFilial, today, today]);

      setState(() {
        _model.listaCombos = List<Map<String, dynamic>>.from(results);
      });
    } catch (e) {
      print('Erro ao carregar combos: $e');
    } finally {
      setState(() {
        _model.isLoading = false;
      });
    }
  }

  Future<void> _carregarItensCombo(String comboId) async {
    setState(() {
      _model.isLoading = true;
    });

    try {
      final db = await _getDatabase();
      
      final results = await db.rawQuery('''
        SELECT 
          i.cmb01_procod,
          i.cmb01_proqtd,
          i.cmb01_propco,
          p.pro00_descri,
          p.pro00_unida,
          (COALESCE(e.pro00_qtdest, 0) - COALESCE(e.pro00_qtdpen, 0)) AS saldo
        FROM estdefcmb01 i
        LEFT JOIN cadpro00 p ON i.cmb01_procod = p.pro00_codpro
        LEFT JOIN estpro00 e ON i.cmb01_procod = e.pro00_codpro AND e.pro00_codfil = ?
        WHERE i.cmb01_codcmb = ?
      ''', [widget.codFilial, comboId]);

      setState(() {
        _model.listaItensCombo = List<Map<String, dynamic>>.from(results);
      });
    } catch (e) {
      print('Erro ao carregar itens do combo: $e');
    } finally {
      setState(() {
        _model.isLoading = false;
      });
    }
  }

  void _selecionarCombo(String id, String descri) {
    setState(() {
      _model.selectedComboId = id;
      _model.selectedComboDesc = descri;
    });
    _carregarItensCombo(id);
  }

  void _adicionarCombo() {
    if (_model.selectedComboId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecione um combo primeiro!'),
          backgroundColor: Colors.orangeAccent,
        ),
      );
      return;
    }
    // PRD 47: Combo inválida
    if (_model.listaItensCombo.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Combo inválida'), backgroundColor: Colors.redAccent),
      );
      return;
    }

    int qtdCombo = int.tryParse(_model.txtQtdCombosController!.text) ?? 1;
    if (qtdCombo <= 0) qtdCombo = 1;

    // PRD 47: Quantidade máxima excedida (se cmb00_qtdmax existir)
    final maxRaw = _model.listaCombos.firstWhere(
      (c) => c['cmb00_codcmb']?.toString() == _model.selectedComboId,
      orElse: () => {},
    )['cmb00_qtdmax'] ?? _model.listaCombos.firstWhere((c) => c['cmb00_codcmb']?.toString() == _model.selectedComboId, orElse: () => {})['cmb00_maxqtd'];
    final maxQtd = maxRaw is num ? maxRaw.toInt() : int.tryParse(maxRaw?.toString() ?? '') ?? 999999;
    if (qtdCombo > maxQtd) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Quantidade máxima excedida'), backgroundColor: Colors.orangeAccent),
      );
      return;
    }

    // Validação estrita de estoque — PRD 47 Estoque insuficiente
    for (var item in _model.listaItensCombo) {
      final double proqtd = (item['cmb01_proqtd'] as num).toDouble();
      final double saldo = (item['saldo'] as num?)?.toDouble() ?? 0.0;
      final String descri = item['pro00_descri']?.toString() ?? 'Desconhecido';
      
      final double qtdNecessaria = proqtd * qtdCombo;
      
      if (qtdNecessaria > saldo) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Estoque insuficiente para o produto $descri. Disponível: ${saldo.toInt()}, Necessário: ${qtdNecessaria.toInt()}'),
            backgroundColor: Colors.redAccent,
            duration: const Duration(seconds: 4),
          ),
        );
        return;
      }
    }

    // Se passou, adiciona itens
    List<ItemPedidoStruct> itensAdicionados = [];
    for (var item in _model.listaItensCombo) {
      final double proqtd = (item['cmb01_proqtd'] as num).toDouble();
      final double propco = (item['cmb01_propco'] as num).toDouble();
      final double qtdNecessaria = proqtd * qtdCombo;

      itensAdicionados.add(ItemPedidoStruct(
        codigoProduto: item['cmb01_procod']?.toString() ?? '',
        descricao: item['pro00_descri']?.toString() ?? '',
        unidade: item['pro00_unida']?.toString() ?? 'UN',
        precoUnitario: propco,
        quantidade: qtdNecessaria,
        totalItem: qtdNecessaria * propco,
        codigoCombo: _model.selectedComboId,
        isBonificacao: propco == 0.0,
      ));
    }

    Navigator.pop(context, itensAdicionados);
  }

  String _formatCurrency(double val) {
    return 'R\$ ${val.toStringAsFixed(2).replaceAll('.', ',')}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.0)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 16.0,
        left: 16.0,
        right: 16.0,
        top: 12.0,
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Handle e cabeçalho
          Center(
            child: Container(
              width: 40.0,
              height: 5.0,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2.5),
              ),
            ),
          ),
          const SizedBox(height: 16.0),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Combos Promocionais',
                style: GoogleFonts.inter(
                  fontSize: 18.0,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF14181B),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const Divider(),
          
          // Lista de combos
          Expanded(
            flex: 2,
            child: _model.isLoading && _model.listaCombos.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : _model.listaCombos.isEmpty
                    ? const Center(child: Text('Nenhum combo vigente.'))
                    : ListView.builder(
                        itemCount: _model.listaCombos.length,
                        itemBuilder: (context, index) {
                          final combo = _model.listaCombos[index];
                          final isSelected = _model.selectedComboId == combo['cmb00_codcmb']?.toString();
                          
                          return Card(
                            elevation: isSelected ? 3 : 1,
                            color: isSelected ? AppTheme.of(context).primary.withValues(alpha: 0.1) : Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8.0),
                              side: BorderSide(
                                color: isSelected ? AppTheme.of(context).primary : Colors.transparent,
                                width: 2,
                              ),
                            ),
                            child: ListTile(
                              leading: Icon(
                                Icons.card_giftcard,
                                color: isSelected ? AppTheme.of(context).primary : Colors.grey,
                              ),
                              title: Text(
                                combo['cmb00_descri']?.toString() ?? 'Combo',
                                style: TextStyle(
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                              subtitle: Text('Cód: ${combo['cmb00_codcmb']}'),
                              onTap: () => _selecionarCombo(
                                combo['cmb00_codcmb'].toString(),
                                combo['cmb00_descri']?.toString() ?? '',
                              ),
                            ),
                          );
                        },
                      ),
          ),
          const Divider(),
          
          // Lista de Itens do Combo
          Expanded(
            flex: 3,
            child: _model.selectedComboId == null
                ? const Center(child: Text('Selecione um combo acima para visualizar os itens.'))
                : _model.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _model.listaItensCombo.isEmpty
                        ? const Center(child: Text('Nenhum item vinculado a este combo.'))
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Itens de ${_model.selectedComboDesc}:',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 8.0),
                              Expanded(
                                child: ListView.builder(
                                  itemCount: _model.listaItensCombo.length,
                                  itemBuilder: (context, index) {
                                    final item = _model.listaItensCombo[index];
                                    final saldo = (item['saldo'] as num?)?.toDouble() ?? 0.0;
                                    final proqtd = (item['cmb01_proqtd'] as num?)?.toDouble() ?? 0.0;
                                    final propco = (item['cmb01_propco'] as num?)?.toDouble() ?? 0.0;
                                    
                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 8.0),
                                      padding: const EdgeInsets.all(12.0),
                                      decoration: BoxDecoration(
                                        border: Border.all(color: Colors.grey.shade300),
                                        borderRadius: BorderRadius.circular(8.0),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item['pro00_descri']?.toString() ?? '',
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.0),
                                          ),
                                          const SizedBox(height: 4.0),
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text('Cód: ${item['cmb01_procod']} | Un: ${item['pro00_unida']}'),
                                              Text(
                                                'Preço: ${_formatCurrency(propco)}',
                                                style: TextStyle(
                                                  color: AppTheme.of(context).primary,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4.0),
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text('Qtd por pacote: ${proqtd.toInt()}'),
                                              Text(
                                                'Estoque: ${saldo.toInt()}',
                                                style: TextStyle(
                                                  color: saldo < proqtd ? Colors.red : Colors.green,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
          ),
          
          // Rodapé - Ação
          const SizedBox(height: 12.0),
          Row(
            children: [
              Expanded(
                flex: 1,
                child: TextField(
                  controller: _model.txtQtdCombosController,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  decoration: InputDecoration(
                    labelText: 'Qtd Combos',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
                  ),
                ),
              ),
              const SizedBox(width: 12.0),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.of(context).primary,
                    padding: const EdgeInsets.symmetric(vertical: 16.0),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
                  ),
                  onPressed: _model.selectedComboId != null ? _adicionarCombo : null,
                  icon: const Icon(Icons.add_shopping_cart, color: Colors.white),
                  label: const Text('Adicionar Combo', style: TextStyle(color: Colors.white)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

