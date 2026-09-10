import '/action_code/index.dart';
import '/core/app_theme.dart';
import '/core/app_icon_button.dart';
import '/core/app_util.dart';
import '/functions/proximo_numero_pedido.dart';
import '/index.dart';
import '/domain/services/bloqueio_financeiro_service.dart';
import '/backend/schema/structs/index.dart';
import '/data/services/local_sales_database_service.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'pedido_novo_inicio_model.dart';
export 'pedido_novo_inicio_model.dart';

class PedidoNovoInicioWidget extends StatefulWidget {
  const PedidoNovoInicioWidget({super.key});

  static String routeName = 'PedidoNovoInicio';
  static String routePath = '/pedidoNovoInicio';

  @override
  State<PedidoNovoInicioWidget> createState() => _PedidoNovoInicioWidgetState();
}

class _PedidoNovoInicioWidgetState extends State<PedidoNovoInicioWidget> {
  late PedidoNovoInicioModel _model;
  final scaffoldKey = GlobalKey<ScaffoldState>();
  // PRD 1 §4A — pré-carregamento mandatório cli00_codage
  String? _agentePreCodigo;
  String? _agentePreDescricao;
  bool _agentePreLoading = false;

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => PedidoNovoInicioModel());

    // Load dropdown options from SQLite
    _loadDatabaseData();
  }

  Future<void> _loadDatabaseData() async {
    final result = await obterDadosPedidoNovo();
    safeSetState(() {
      _model.clientes = result.clientes;
      _model.linhas = result.linhas;
      _model.planos = result.planos;
      _model.isLoading = false;
    });
  }

  @override
  void dispose() {
    _model.dispose();
    super.dispose();
  }

  String _formatCpfCnpj(String val) {
    final clean = val.replaceAll(RegExp(r'[^0-9]'), '');
    if (clean.length == 11) {
      return '${clean.substring(0, 3)}.${clean.substring(3, 6)}.${clean.substring(6, 9)}-${clean.substring(9, 11)}';
    } else if (clean.length == 14) {
      return '${clean.substring(0, 2)}.${clean.substring(2, 5)}.${clean.substring(5, 8)}/${clean.substring(8, 12)}-${clean.substring(12, 14)}';
    }
    return val;
  }

  String _formatCurrency(double val) {
    return val.toMoeda();
  }

  // PRD 1 §4A — busca cli00_codage e descrição do agente em codage00/cadagt00
  Future<void> _prefetchAgente(ClienteResultStruct c) async {
    final cod = c.cli00Codage;
    if (cod == 0) {
      safeSetState(() {
        _agentePreCodigo = null;
        _agentePreDescricao = null;
        _agentePreLoading = false;
      });
      return;
    }
    safeSetState(() => _agentePreLoading = true);
    String? desc;
    final codStr = cod.toString();
    try {
      final db = await LocalSalesDatabaseService.getDatabase();
      for (final tbl in ['codage00', 'cadagt00', 'cadage00', 'cadcob00', 'codcob00', 'cadcob000', 'cadage000', 'cadagt000']) {
        try {
          final exists = await db.rawQuery(
              "SELECT name FROM sqlite_master WHERE type='table' AND lower(name)=?", [tbl]);
          if (exists.isEmpty) continue;
          final cols = await db.rawQuery('PRAGMA table_info($tbl)');
          final cn = cols.map((r) => r['name'].toString().toLowerCase()).toSet();
          String? codCol;
          String? descCol;
          for (final cand in ['age00_codigo', 'agt00_codigo', 'agt00_codage', 'agt00_codagt', 'cob00_codigo', 'cob00_codcob', 'cad00_codigo', 'codigo']) {
            if (cn.contains(cand)) { codCol = cand; break; }
          }
          for (final cand in ['age00_descri', 'agt00_descri', 'agt00_descricao', 'agt00_nome', 'age00_descricao', 'age00_nome', 'cob00_descri', 'cob00_descricao', 'cob00_nome', 'descricao', 'descri', 'nome']) {
            if (cn.contains(cand)) { descCol = cand; break; }
          }
          if (codCol == null || descCol == null) continue;
          final r = await db.rawQuery('SELECT $descCol as d FROM $tbl WHERE $codCol = ? LIMIT 1', [cod]);
          if (r.isNotEmpty && r.first['d'] != null) {
            desc = r.first['d'].toString();
            break;
          }
        } catch (_) {}
      }
    } catch (_) {}
    if (!mounted) return;
    safeSetState(() {
      _agentePreCodigo = codStr;
      // Se não achou descrição, mantém código; integridade referencial valida depois
      _agentePreDescricao = (desc != null && desc.trim().isNotEmpty) ? desc : null;
      _agentePreLoading = false;
    });
  }

  /// Modal informativo de títulos vencidos (dup00) ao selecionar o cliente
  Future<void> _exibirModalTitulosVencidos(BuildContext context, List<TituloVencidoItem> titulos, String clienteNome) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Align(
          alignment: Alignment.bottomCenter,
          heightFactor: 1.0,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600.0),
            child: Material(
              color: Colors.transparent,
              child: Container(
                height: MediaQuery.of(ctx).size.height * 0.75,
                decoration: BoxDecoration(
                  color: AppTheme.of(ctx).primaryBackground,
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
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          'Títulos Vencidos em Aberto',
                                          style: AppTheme.of(ctx).titleLarge.override(
                                                font: GoogleFonts.outfit(
                                                  fontWeight: FontWeight.w600,
                                                ),
                                                color: AppTheme.of(ctx).primaryText,
                                                fontSize: 18.0,
                                              ),
                                        ),
                                        Text(
                                          clienteNome,
                                          style: AppTheme.of(ctx).bodySmall.override(
                                                font: GoogleFonts.inter(),
                                                color: AppTheme.of(ctx).secondaryText,
                                                fontSize: 12.0,
                                              ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
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
                                color: AppTheme.of(ctx).primaryText,
                                size: 18.0,
                              ),
                              onPressed: () => Navigator.pop(ctx),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1.0, thickness: 1.0),
                      Expanded(
                        child: ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                          itemCount: titulos.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (context, idx) {
                            final t = titulos[idx];
                            return Container(
                              padding: const EdgeInsets.all(14.0),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF8E1),
                                borderRadius: BorderRadius.circular(12.0),
                                border: Border.all(color: const Color(0xFFFFE082)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Documento: ${t.numeroDocumento}',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1D2429)),
                                      ),
                                      Text(
                                        t.valor.toMoeda(),
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFFC62828)),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Vencimento: ${t.dataVencimento}',
                                        style: const TextStyle(fontSize: 13, color: Colors.black87),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 2.0),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFFCDD2),
                                          borderRadius: BorderRadius.circular(6.0),
                                        ),
                                        child: Text(
                                          '${t.diasAtraso}d atraso',
                                          style: const TextStyle(color: Color(0xFFB71C1C), fontSize: 11, fontWeight: FontWeight.bold),
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
                      SafeArea(
                        top: false,
                        child: Container(
                          padding: const EdgeInsets.all(16.0),
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, -2))],
                          ),
                          child: SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.of(context).primary,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              onPressed: () => Navigator.pop(ctx),
                              child: const Text(
                                'Continuar Digitação',
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                              ),
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
      },
    );
  }

  void _showClientBottomSheet() {
    String searchQuery = '';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            final filtered = _model.clientes.where((c) {
              final term = searchQuery.toLowerCase();
              final name = c.cli00Descri.toLowerCase();
              final fantas = c.cli00Fantas.toLowerCase();
              final cod = c.cli00Codigo.toString();
              return name.contains(term) || fantas.contains(term) || cod.contains(term);
            }).toList();

            return Align(
              alignment: Alignment.bottomCenter,
              heightFactor: 1.0,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600.0),
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    height: MediaQuery.of(context).size.height * 0.8,
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
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.people_outline_rounded,
                                        color: AppTheme.of(context).primary,
                                        size: 24.0,
                                      ),
                                      const SizedBox(width: 8.0),
                                      Expanded(
                                        child: Text(
                                          'Selecionar Cliente',
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
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: TextField(
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: 'Pesquise por nome, fantasia ou código...',
                        prefixIcon: Icon(Icons.search_rounded, color: AppTheme.of(context).secondaryText),
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
                      onChanged: (val) {
                        setStateDialog(() {
                          searchQuery = val;
                        });
                      },
                    ),
                  ),
                  const SizedBox(height: 12.0),
                  Expanded(
                    child: filtered.isEmpty
                        ? Center(
                            child: Text(
                              'Nenhum cliente encontrado.',
                              style: AppTheme.of(context).bodyMedium,
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                            itemCount: filtered.length,
                            itemBuilder: (context, index) {
                              final c = filtered[index];
                              final isSelected = _model.selectedCliente?.cli00Codigo == c.cli00Codigo;
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
                                child: ListTile(
                                  title: Text(
                                    '${c.cli00Codigo} - ${c.cli00Descri}',
                                    style: AppTheme.of(context).bodyLarge.override(
                                          font: GoogleFonts.inter(fontWeight: FontWeight.w600),
                                        ),
                                  ),
                                  subtitle: Text(
                                    c.cli00Fantas,
                                    style: AppTheme.of(context).bodyMedium.override(
                                          font: GoogleFonts.inter(
                                            color: AppTheme.of(context).secondaryText,
                                          ),
                                        ),
                                  ),
                                  trailing: isSelected ? Icon(Icons.check_circle_rounded, color: AppTheme.of(context).primary) : null,
                                  onTap: () async {
                                    final selected = c;
                                    safeSetState(() {
                                      _model.selectedCliente = selected;
                                    });
                                    // PRD 1 §4A — pré-carregamento mandatório cli00_codage
                                    _prefetchAgente(selected);

                                    // PRD Seção 2 — Filtragem cruzada de planos para o cliente selecionado
                                    final novosPlanos = await carregarPlanosDisponiveisCliente(
                                      clienteCodigo: selected.cli00Codigo,
                                    );
                                    if (mounted) {
                                      safeSetState(() {
                                        _model.planos = novosPlanos;
                                        if (_model.selectedPlano != null) {
                                          final exists = novosPlanos.any((p) => p.codigo == _model.selectedPlano!.codigo);
                                          if (!exists) {
                                            _model.selectedPlano = null;
                                          }
                                        }
                                      });
                                    }

                                    if (context.mounted) {
                                      Navigator.pop(context);
                                    }

                                    // Consulta se o cliente possui títulos em atraso (dup00)
                                    final titulos = await BloqueioFinanceiroService.listarTitulosVencidos(selected.cli00Codigo);
                                    if (titulos.isNotEmpty && mounted) {
                                      await _exibirModalTitulosVencidos(this.context, titulos, selected.cli00Descri);
                                    }
                                  },
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
          },
        );
      },
    );
  }

  void _showLinhaBottomSheet() {
    String searchQuery = '';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            final filtered = _model.linhas.where((l) {
              final term = searchQuery.toLowerCase();
              final desc = l.descricao.toLowerCase();
              final cod = l.codigo.toLowerCase();
              return desc.contains(term) || cod.contains(term);
            }).toList();

            return Align(
              alignment: Alignment.bottomCenter,
              heightFactor: 1.0,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600.0),
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    height: MediaQuery.of(context).size.height * 0.7,
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
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.layers_outlined,
                                        color: AppTheme.of(context).primary,
                                        size: 24.0,
                                      ),
                                      const SizedBox(width: 8.0),
                                      Expanded(
                                        child: Text(
                                          'Selecionar Linha de Produtos',
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
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: 'Pesquise por descrição ou código...',
                        prefixIcon: Icon(Icons.search_rounded, color: AppTheme.of(context).secondaryText),
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
                      onChanged: (val) {
                        setStateDialog(() {
                          searchQuery = val;
                        });
                      },
                    ),
                  ),
                  const SizedBox(height: 12.0),
                  Expanded(
                    child: filtered.isEmpty
                        ? Center(
                            child: Text(
                              'Nenhuma linha encontrada.',
                              style: AppTheme.of(context).bodyMedium,
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                            itemCount: filtered.length,
                            itemBuilder: (context, index) {
                              final l = filtered[index];
                              final isSelected = _model.selectedLinha?.codigo == l.codigo;
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
                                child: ListTile(
                                  leading: Icon(Icons.layers_outlined, color: isSelected ? AppTheme.of(context).primary : AppTheme.of(context).secondaryText),
                                  title: Text(
                                    l.descricao,
                                    style: AppTheme.of(context).bodyLarge.override(
                                          font: GoogleFonts.inter(fontWeight: FontWeight.w600),
                                        ),
                                  ),
                                  subtitle: Text(
                                    'Código: ${l.codigo}',
                                    style: AppTheme.of(context).bodyMedium,
                                  ),
                                  trailing: isSelected ? Icon(Icons.check_circle_rounded, color: AppTheme.of(context).primary) : null,
                                  onTap: () {
                                    safeSetState(() {
                                      _model.selectedLinha = l;
                                    });
                                    Navigator.pop(context);
                                  },
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
          },
        );
      },
    );
  }

  void _showPlanoBottomSheet() {
    String searchQuery = '';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            final filtered = _model.planos.where((p) {
              final term = searchQuery.toLowerCase();
              final desc = p.descricao.toLowerCase();
              final cod = p.codigo.toLowerCase();
              return desc.contains(term) || cod.contains(term);
            }).toList();

            return Align(
              alignment: Alignment.bottomCenter,
              heightFactor: 1.0,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600.0),
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    height: MediaQuery.of(context).size.height * 0.7,
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
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.credit_card_rounded,
                                        color: AppTheme.of(context).primary,
                                        size: 24.0,
                                      ),
                                      const SizedBox(width: 8.0),
                                      Expanded(
                                        child: Text(
                                          'Selecionar Plano de Pagamento',
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
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: 'Pesquise por descrição ou código...',
                        prefixIcon: Icon(Icons.search_rounded, color: AppTheme.of(context).secondaryText),
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
                      onChanged: (val) {
                        setStateDialog(() {
                          searchQuery = val;
                        });
                      },
                    ),
                  ),
                  const SizedBox(height: 12.0),
                  Expanded(
                    child: filtered.isEmpty
                        ? Center(
                            child: Text(
                              'Nenhum plano encontrado.',
                              style: AppTheme.of(context).bodyMedium,
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                            itemCount: filtered.length,
                            itemBuilder: (context, index) {
                              final p = filtered[index];
                              final isSelected = _model.selectedPlano?.codigo == p.codigo;
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
                                child: ListTile(
                                  leading: Icon(Icons.credit_card_outlined, color: isSelected ? AppTheme.of(context).primary : AppTheme.of(context).secondaryText),
                                  title: Text(
                                    p.descricao,
                                    style: AppTheme.of(context).bodyLarge.override(
                                          font: GoogleFonts.inter(fontWeight: FontWeight.w600),
                                        ),
                                  ),
                                  subtitle: Text(
                                    p.vlrmin > 0
                                        ? 'Código: ${p.codigo} • Mínimo: ${_formatCurrency(p.vlrmin)}'
                                        : 'Código: ${p.codigo}',
                                    style: AppTheme.of(context).bodyMedium,
                                  ),
                                  trailing: isSelected ? Icon(Icons.check_circle_rounded, color: AppTheme.of(context).primary) : null,
                                  onTap: () {
                                    safeSetState(() {
                                      _model.selectedPlano = p;
                                    });
                                    Navigator.pop(context);
                                  },
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
          },
        );
      },
    );
  }

  void _showSearchableClientDialog() {
    _showClientBottomSheet();
  }

  @override
  Widget build(BuildContext context) {
    final hasSelectedAll = _model.selectedCliente != null &&
        _model.selectedLinha != null &&
        _model.selectedPlano != null;

    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
        FocusManager.instance.primaryFocus?.unfocus();
      },
      child: Scaffold(
        key: scaffoldKey,
        backgroundColor: const Color(0xFFF1F4F8),
        appBar: AppBar(
          backgroundColor: AppTheme.of(context).primary,
          automaticallyImplyLeading: true,
          title: Text(
            'Novo Pedido',
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontSize: 22.0,
              fontWeight: FontWeight.w600,
            ),
          ),
          elevation: 0.0,
          centerTitle: false,
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: SafeArea(
          child: _model.isLoading
              ? Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppTheme.of(context).primary,
                    ),
                  ),
                )
              : Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Card 1: Dados do Pedido
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12.0),
                                border: Border.all(color: const Color(0xFFE0E3E7)),
                              ),
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Dados do Pedido',
                                    style: GoogleFonts.outfit(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 18.0,
                                      color: const Color(0xFF14181B),
                                    ),
                                  ),
                                  const SizedBox(height: 16.0),

                                  // Cliente Selector
                                  InkWell(
                                    onTap: _showSearchableClientDialog,
                                    borderRadius: BorderRadius.circular(8.0),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 12.0),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(8.0),
                                        border: Border.all(color: const Color(0xFFE0E3E7)),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.person_outline_rounded,
                                            color: AppTheme.of(context).primary,
                                            size: 24.0,
                                          ),
                                          const SizedBox(width: 12.0),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  _model.selectedCliente != null
                                                      ? _model.selectedCliente!.cli00Descri
                                                      : 'Selecione um cliente...',
                                                  style: GoogleFonts.inter(
                                                    fontWeight: FontWeight.bold,
                                                    color: const Color(0xFF14181B),
                                                    fontSize: 14.0,
                                                  ),
                                                ),
                                                if (_model.selectedCliente != null && _model.selectedCliente!.cli00Fantas.isNotEmpty)
                                                  Text(
                                                    _model.selectedCliente!.cli00Fantas,
                                                    style: GoogleFonts.inter(
                                                      color: const Color(0xFF57636C),
                                                      fontSize: 12.0,
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ),
                                          const Icon(
                                            Icons.chevron_right_rounded,
                                            color: Color(0xFF95A1AC),
                                            size: 20.0,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 16.0),

                                  // Linha de Produtos
                                  Text(
                                    'Linha de Produtos',
                                    style: GoogleFonts.inter(
                                      color: const Color(0xFF57636C),
                                      fontSize: 14.0,
                                    ),
                                  ),
                                  const SizedBox(height: 8.0),
                                  InkWell(
                                    onTap: _showLinhaBottomSheet,
                                    borderRadius: BorderRadius.circular(8.0),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 12.0),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(8.0),
                                        border: Border.all(color: const Color(0xFFE0E3E7)),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.layers_outlined,
                                            color: AppTheme.of(context).primary,
                                            size: 24.0,
                                          ),
                                          const SizedBox(width: 12.0),
                                          Expanded(
                                            child: Text(
                                              _model.selectedLinha != null
                                                  ? _model.selectedLinha!.descricao
                                                  : 'Selecione uma linha...',
                                              style: GoogleFonts.inter(
                                                fontWeight: FontWeight.bold,
                                                color: const Color(0xFF14181B),
                                                fontSize: 14.0,
                                              ),
                                            ),
                                          ),
                                          const Icon(
                                            Icons.chevron_right_rounded,
                                            color: Color(0xFF95A1AC),
                                            size: 20.0,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 16.0),

                                  // Plano de Pagamento
                                  Text(
                                    'Plano de Pagamento',
                                    style: GoogleFonts.inter(
                                      color: const Color(0xFF57636C),
                                      fontSize: 14.0,
                                    ),
                                  ),
                                  const SizedBox(height: 8.0),
                                  InkWell(
                                    onTap: _showPlanoBottomSheet,
                                    borderRadius: BorderRadius.circular(8.0),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 12.0),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(8.0),
                                        border: Border.all(color: const Color(0xFFE0E3E7)),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.credit_card_outlined,
                                            color: AppTheme.of(context).primary,
                                            size: 24.0,
                                          ),
                                          const SizedBox(width: 12.0),
                                          Expanded(
                                            child: Text(
                                              _model.selectedPlano != null
                                                  ? _model.selectedPlano!.descricao
                                                  : 'Selecione um plano...',
                                              style: GoogleFonts.inter(
                                                fontWeight: FontWeight.bold,
                                                color: const Color(0xFF14181B),
                                                fontSize: 14.0,
                                              ),
                                            ),
                                          ),
                                          const Icon(
                                            Icons.chevron_right_rounded,
                                            color: Color(0xFF95A1AC),
                                            size: 20.0,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Card 2: Resumo do Pedido
                            if (hasSelectedAll) ...[
                              const SizedBox(height: 16.0),
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12.0),
                                  border: Border.all(color: const Color(0xFFE0E3E7)),
                                ),
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Resumo do Pedido',
                                      style: GoogleFonts.outfit(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 18.0,
                                        color: const Color(0xFF14181B),
                                      ),
                                    ),
                                    const SizedBox(height: 16.0),
                                    _buildSummaryRow(
                                      'Filial',
                                      AppState().empresa_codigo.isNotEmpty ? AppState().empresa_codigo : '1234',
                                    ),
                                    _buildSummaryRow(
                                      'Razão Social',
                                      _model.selectedCliente!.cli00Descri,
                                    ),
                                    _buildSummaryRow(
                                      'Fantasia',
                                      _model.selectedCliente!.cli00Fantas.isNotEmpty ? _model.selectedCliente!.cli00Fantas : '-',
                                    ),
                                    _buildSummaryRow(
                                      'Cidade',
                                      _model.selectedCliente!.cli00Ciddes.isNotEmpty ? _model.selectedCliente!.cli00Ciddes : '-',
                                    ),
                                    _buildSummaryRow(
                                      'CNPJ / CPF',
                                      _formatCpfCnpj(_model.selectedCliente!.cli00Cpfcnp),
                                    ),
                                    _buildSummaryRow(
                                      'Limite Original',
                                      _formatCurrency(_model.selectedCliente!.cli00Crelim),
                                    ),
                                    _buildSummaryRow(
                                      'Limite Disponível',
                                      _formatCurrency(_model.selectedCliente!.cli00Crelim - _model.selectedCliente!.cli00Creatu),
                                      valueColor: AppTheme.of(context).primary,
                                    ),
                                    // PRD 1 §4A — agente pré-carregado via cli00_codage
                                    if (_agentePreCodigo != null)
                                      _buildSummaryRow(
                                        'Agente Cobrador',
                                        _agentePreDescricao != null
                                            ? '$_agentePreCodigo - $_agentePreDescricao'
                                            : _agentePreCodigo!,
                                        valueColor: AppTheme.of(context).primary,
                                      )
                                    else if (_agentePreLoading)
                                      _buildSummaryRow('Agente Cobrador', 'Carregando...'),
                                  ],
                                ),
                              ),
                            ],
                            // Mostra agente também quando só cliente selecionado (feedback imediato)
                            if (_model.selectedCliente != null && !hasSelectedAll && _agentePreCodigo != null) ...[
                              const SizedBox(height: 12.0),
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12.0),
                                  border: Border.all(color: const Color(0xFFE0E3E7)),
                                ),
                                padding: const EdgeInsets.all(12.0),
                                child: Row(
                                  children: [
                                    Icon(Icons.person_outline, size: 18, color: AppTheme.of(context).primary),
                                    const SizedBox(width: 8),
                                    Text('Agente: ', style: GoogleFonts.inter(color: const Color(0xFF57636C), fontSize: 13, fontWeight: FontWeight.w600)),
                                    Expanded(
                                      child: Text(
                                        _agentePreDescricao != null ? '$_agentePreCodigo - $_agentePreDescricao' : _agentePreCodigo!,
                                        style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            const SizedBox(height: 24.0),
                          ],
                        ),
                      ),
                    ),
                    
                    // Fixed Bottom Button
                    if (hasSelectedAll)
                      Container(
                        padding: const EdgeInsets.all(16.0),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          boxShadow: [
                            BoxShadow(
                              color: Color(0x0F000000),
                              blurRadius: 4.0,
                              offset: Offset(0, -2),
                            )
                          ],
                        ),
                        child: SizedBox(
                          width: double.infinity,
                          height: 50.0,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.of(context).primary,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12.0),
                              ),
                              elevation: 0,
                            ),
                            onPressed: () async {
                              final tempOrderId = await obterProximoNumeroPedido();
                              if (!context.mounted) return;
                              AppState().update(() {
                                AppState().pedido_numero = tempOrderId;
                              });

                              // Persiste o cabeçalho inicial como rascunho imediatamente
                              await salvarCarrinhoPedido(
                                pedidoId: tempOrderId,
                                clienteCodigo: _model.selectedCliente!.cli00Codigo,
                                linhaCodigo: _model.selectedLinha?.codigo,
                                planoCodigo: _model.selectedPlano?.codigo,
                                carrinhoItens: [],
                              );
                              if (!context.mounted) return;

                              context.pushNamed(
                                PedidoItensListaWidget.routeName,
                                queryParameters: {
                                  'pedidoId': tempOrderId.toString(),
                                  'clienteNome': _model.selectedCliente!.cli00Descri,
                                  'clienteCodigo': _model.selectedCliente!.cli00Codigo.toString(),
                                  'clienteCnpj': _model.selectedCliente!.cli00Cpfcnp,
                                  'clienteCidade': '${_model.selectedCliente!.cli00Ciddes} - ${_model.selectedCliente!.cli00Estsgl}',
                                  'clienteLimite': _model.selectedCliente!.cli00Crelim.toString(),
                                  'linhaCodigo': _model.selectedLinha?.codigo ?? '',
                                  'linhaDescricao': _model.selectedLinha?.descricao ?? '',
                                  'planoCodigo': _model.selectedPlano?.codigo ?? '',
                                  'planoDescricao': _model.selectedPlano?.descricao ?? '',
                                  'clienteEndereco': '${_model.selectedCliente!.cli00Endere}, ${_model.selectedCliente!.cli00Endnum} - ${_model.selectedCliente!.cli00Bairro}',
                                },
                              );
                            },
                            icon: const Icon(Icons.edit_outlined, color: Colors.white),
                            label: Text(
                              'Iniciar Digitação',
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                fontSize: 16.0,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildSummaryRow(
    String label,
    String value, {
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              color: const Color(0xFF57636C),
              fontSize: 14.0,
            ),
          ),
          const SizedBox(width: 16.0),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: GoogleFonts.inter(
                color: valueColor ?? const Color(0xFF14181B),
                fontWeight: FontWeight.bold,
                fontSize: 14.0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
