import '/core/app_theme.dart';
import '/core/app_icon_button.dart';
import '/core/app_util.dart';
import '/backend/schema/structs/index.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as path_pkg;
import '/functions/resolver_cod_filial.dart';
import 'bottom_sheet_selecao_bonificacao_model.dart';
export 'bottom_sheet_selecao_bonificacao_model.dart';

class BottomSheetSelecaoBonificacaoWidget extends StatefulWidget {
  const BottomSheetSelecaoBonificacaoWidget({
    super.key,
    required this.pedidoId,
    required this.linhaCodigo,
    required this.tabelaCodigo,
  });

  final int pedidoId;
  final String? linhaCodigo;
  final String? tabelaCodigo;

  @override
  State<BottomSheetSelecaoBonificacaoWidget> createState() =>
      _BottomSheetSelecaoBonificacaoWidgetState();
}

class _BottomSheetSelecaoBonificacaoWidgetState
    extends State<BottomSheetSelecaoBonificacaoWidget> {
  late BottomSheetSelecaoBonificacaoModel _model;

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => BottomSheetSelecaoBonificacaoModel());
    _loadRegras();
  }

  @override
  void dispose() {
    _model.maybeDispose();
    super.dispose();
  }

  Future<void> _loadRegras() async {
    setState(() {
      _model.isBusy = true;
    });

    try {
      final dbPath = path_pkg.join(await getDatabasesPath(), 'dbforcacad001.db');
      final db = await openDatabase(dbPath);

      // Check which table name exists
      String tableName = 'estdefbon00';
      final List<Map<String, dynamic>> checkTable = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='estdefbon00'"
      );
      if (checkTable.isEmpty) {
        final List<Map<String, dynamic>> checkTable2 = await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND name='cadbon00'"
        );
        if (checkTable2.isNotEmpty) {
          tableName = 'cadbon00';
        }
      }

      final currentDate = DateTime.now().toIso8601String().substring(0, 10);
      final filial = resolverCodFilial(AppState().empresa_codigo) ?? 1;
      final tabela = int.tryParse(widget.tabelaCodigo ?? '') ?? 0;
      final linha = int.tryParse(widget.linhaCodigo ?? '') ?? 0;

      final results = await db.rawQuery(
        "SELECT * FROM $tableName "
        "WHERE (bon00_datini <= ? OR bon00_datini IS NULL) "
        "  AND (bon00_datfim >= ? OR bon00_datfim IS NULL) "
        "  AND (bon00_codfil = ? OR bon00_codfil = 0 OR bon00_codfil IS NULL) "
        "  AND (bon00_codtab = ? OR bon00_codtab = 0 OR bon00_codtab IS NULL) "
        "  AND (bon00_codlin = ? OR bon00_codlin = 0 OR bon00_codlin IS NULL)",
        [currentDate, currentDate, filial, tabela, linha]
      );

      _model.regras = results;
      await db.close();
    } catch (e) {
      print('Erro ao carregar regras de bonificação: $e');
    }

    setState(() {
      _model.isBusy = false;
    });
  }

  Future<void> _selectRegra(Map<String, dynamic> regra) async {
    setState(() {
      _model.selectedRegra = regra;
      _model.produtosElegiveis = [];
      _model.quantidadesDigitadas = {};
      _model.estoquesDisponiveis = {};
      _model.isBusy = true;
    });

    try {
      final dbPath = path_pkg.join(await getDatabasesPath(), 'dbforcacad001.db');
      final db = await openDatabase(dbPath);

      String itemsTableName = 'estdefbon01';
      final List<Map<String, dynamic>> checkItems = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='estdefbon01'"
      );
      if (checkItems.isEmpty) {
        final List<Map<String, dynamic>> checkItems2 = await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND name='cadbon01'"
        );
        if (checkItems2.isNotEmpty) {
          itemsTableName = 'cadbon01';
        }
      }

      final ruleId = regra['bon00_codigo'] ?? regra['bon00_codbon'];
      final filial = resolverCodFilial(AppState().empresa_codigo) ?? 1;

      // Query items joined with product catalog to get details
      final itemResults = await db.rawQuery(
        "SELECT items.*, pro.pro00_descri, pro.pro00_unidpri, pro.pro00_unidade "
        "FROM $itemsTableName items "
        "LEFT JOIN estpro00 pro ON (pro.pro00_codpro = items.bon01_probon OR pro.pro00_codpro = CAST(items.bon01_probon AS TEXT)) AND pro.pro00_codfil = ? "
        "WHERE items.bon01_codbon = ?",
        [filial, ruleId]
      );

      _model.produtosElegiveis = itemResults;

      // Consult inventory for each product
      for (final row in itemResults) {
        final productCode = row['bon01_probon']?.toString() ?? '';
        if (productCode.isNotEmpty) {
          final stockResults = await db.rawQuery(
            "SELECT (COALESCE(pro00_qtdest, 0) - COALESCE(pro00_qtdpen, 0)) AS saldo "
            "FROM estpro00 WHERE (pro00_codpro = ? OR pro00_codpro = CAST(? AS TEXT)) AND pro00_codfil = ?",
            [productCode, productCode, filial]
          );
          double saldo = 0.0;
          if (stockResults.isNotEmpty) {
            final val = stockResults.first['saldo'];
            if (val is num) {
              saldo = val.toDouble();
            } else if (val != null) {
              saldo = double.tryParse(val.toString()) ?? 0.0;
            }
          }
          _model.estoquesDisponiveis[productCode] = saldo;
          _model.quantidadesDigitadas[productCode] = 0.0;
        }
      }

      await db.close();
    } catch (e) {
      print('Erro ao carregar itens da regra selecionada: $e');
    }

    setState(() {
      _model.isBusy = false;
    });
  }

  void _confirmarBonificacao() {
    // 1. Validations
    final List<ItemPedidoStruct> novosItens = [];
    for (final row in _model.produtosElegiveis) {
      final productCode = row['bon01_probon']?.toString() ?? '';
      final qtd = _model.quantidadesDigitadas[productCode] ?? 0.0;
      if (qtd <= 0.0) continue;

      final estoque = _model.estoquesDisponiveis[productCode] ?? 0.0;
      if (qtd > estoque) {
        final desc = row['pro00_descri'] ?? 'Produto $productCode';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Quantidade informada supera o estoque disponível para $desc (Estoque: $estoque).",
            ),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final desc = row['pro00_descri']?.toString() ?? 'Produto Bonificado';
      final unidade = row['pro00_unidpri']?.toString() ?? row['pro00_unidade']?.toString() ?? 'UN';

      novosItens.add(
        ItemPedidoStruct(
          codigoProduto: productCode,
          descricao: desc,
          unidade: unidade,
          precoUnitario: 0.0,
          quantidade: 0.0,
          totalItem: 0.0,
          isBonificacao: true,
          quantidadeBonificada: qtd,
        ),
      );
    }

    if (novosItens.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Nenhuma quantidade de bonificação preenchida."),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // 2. Add to app state items list
    Navigator.pop(context, novosItens);
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      heightFactor: 1.0,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600.0),
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: double.infinity,
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
              child: SingleChildScrollView(
                padding: EdgeInsets.only(
                  left: 16.0,
                  right: 16.0,
                  top: 8.0,
                  bottom: MediaQuery.viewInsetsOf(context).bottom + 16.0,
                ),
                child: AnimatedSize(
                  duration: const Duration(milliseconds: 200),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Top Drag bar
                      Padding(
                        padding: const EdgeInsets.only(top: 4.0, bottom: 4.0),
                        child: Center(
                          child: Container(
                            width: 40.0,
                            height: 4.0,
                            decoration: BoxDecoration(
                              color: Colors.grey.withValues(alpha: 0.35),
                              borderRadius: BorderRadius.circular(2.0),
                            ),
                          ),
                        ),
                      ),
                      // Header
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 8.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.card_giftcard_rounded,
                                    color: AppTheme.of(context).primary,
                                    size: 24.0,
                                  ),
                                  const SizedBox(width: 8.0),
                                  Expanded(
                                    child: Text(
                                      'Incluir Bonificação',
                                      style: AppTheme.of(context).titleLarge.override(
                                            font: GoogleFonts.outfit(
                                              fontWeight: FontWeight.w600,
                                            ),
                                            color: AppTheme.of(context).primaryText,
                                            fontSize: 20.0,
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
                              onPressed: () => Navigator.pop(context),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1.0, thickness: 1.0),
                      const SizedBox(height: 8.0),

            if (_model.isBusy)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(24.0),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_model.regras.isEmpty)
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Center(
                  child: Text(
                    'Nenhuma regra de bonificação ativa para este cliente/pedido.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      color: Colors.grey,
                      fontSize: 14.0,
                    ),
                  ),
                ),
              )
            else ...[
              // Regras list if not selected
              if (_model.selectedRegra == null) ...[
                Text(
                  'Selecione uma Promoção/Regra:',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.bold,
                    fontSize: 14.0,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 8.0),
                Container(
                  constraints: const BoxConstraints(maxHeight: 250.0),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _model.regras.length,
                    itemBuilder: (context, index) {
                      final r = _model.regras[index];
                      final id = r['bon00_codigo'] ?? r['bon00_codbon'] ?? '';
                      final desc = r['bon00_descri'] ?? 'Sem descrição';
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 6.0),
                        elevation: 1,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                        child: ListTile(
                          title: Text(
                            desc,
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.bold,
                              fontSize: 14.0,
                            ),
                          ),
                          subtitle: Text('Código da Regra: $id'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => _selectRegra(r),
                        ),
                      );
                    },
                  ),
                ),
              ] else ...[
                // Back to rules button
                Row(
                  children: [
                    TextButton.icon(
                      icon: const Icon(Icons.arrow_back, size: 16.0),
                      label: const Text('Voltar para regras'),
                      onPressed: () {
                        setState(() {
                          _model.selectedRegra = null;
                          _model.produtosElegiveis = [];
                        });
                      },
                    ),
                  ],
                ),
                Text(
                  'Regra selecionada: ${_model.selectedRegra!['bon00_descri'] ?? ''}',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.bold,
                    fontSize: 14.0,
                    color: AppTheme.of(context).primary,
                  ),
                ),
                const SizedBox(height: 12.0),

                // Selected rule items list
                Text(
                  'Produtos Bonificados:',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    fontSize: 13.0,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 8.0),
                Container(
                  constraints: const BoxConstraints(maxHeight: 300.0),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _model.produtosElegiveis.length,
                    itemBuilder: (context, index) {
                      final row = _model.produtosElegiveis[index];
                      final productCode = row['bon01_probon']?.toString() ?? '';
                      final desc = row['pro00_descri'] ?? 'Carregando descrição...';
                      final estoque = _model.estoquesDisponiveis[productCode] ?? 0.0;
                      final qtd = _model.quantidadesDigitadas[productCode] ?? 0.0;

                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 4.0),
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                desc,
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13.0,
                                ),
                              ),
                              const SizedBox(height: 4.0),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Código: $productCode | Estoque: $estoque',
                                    style: GoogleFonts.inter(
                                      color: Colors.grey[600],
                                      fontSize: 12.0,
                                    ),
                                  ),
                                  // Counter stepper
                                  Row(
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                                        onPressed: () {
                                          if (qtd > 0) {
                                            setState(() {
                                              _model.quantidadesDigitadas[productCode] = qtd - 1;
                                            });
                                          }
                                        },
                                      ),
                                      Text(
                                        qtd.toInt().toString(),
                                        style: GoogleFonts.inter(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14.0,
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.add_circle_outline, color: Colors.green),
                                        onPressed: () {
                                          // PRD 48: bon00_venmax
                                          final venmaxRaw = _model.selectedRegra?['bon00_venmax'] ?? _model.selectedRegra?['bon00_qtdmax'] ?? _model.selectedRegra?['bon00_maxbon'];
                                          final venmax = venmaxRaw is num ? venmaxRaw.toDouble() : double.tryParse(venmaxRaw?.toString() ?? '') ?? 999999;
                                          if (qtd + 1 > venmax) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(content: Text("Você está excedendo o nº máximo de bonificações.")),
                                            );
                                            return;
                                          }
                                          if (qtd < estoque) {
                                            setState(() {
                                              _model.quantidadesDigitadas[productCode] = qtd + 1;
                                            });
                                          } else {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(
                                                content: Text("Quantidade máxima de estoque atingida."),
                                                duration: Duration(seconds: 1),
                                              ),
                                            );
                                          }
                                        },
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16.0),
                SizedBox(
                  width: double.infinity,
                  height: 48.0,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.of(context).primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                    ),
                    onPressed: _confirmarBonificacao,
                    child: Text(
                      'Adicionar Bonificações ao Pedido',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.bold,
                        fontSize: 14.0,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    ),
  ),
),
),
),
);
  }
}
