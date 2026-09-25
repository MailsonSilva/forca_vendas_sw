import '/action_code/index.dart';
import '/core/app_theme.dart';
import '/core/app_icon_button.dart';
import '/core/app_util.dart';
import '/functions/proximo_numero_pedido.dart';
import '/index.dart';
import '/domain/services/bloqueio_financeiro_service.dart';
import '/services/filial_service.dart';
import '/data/services/local_sales_database_service.dart';
import '/functions/resolver_cod_filial.dart';
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


  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => PedidoNovoInicioModel());

    // Load dropdown options from SQLite
    _loadDatabaseData();
  }

  Future<void> _loadDatabaseData() async {
    // Garante inicialização e vinculação da filial ativa no AppState
    if (AppState().filialAtiva <= 0) {
      try {
        final db = await LocalSalesDatabaseService.getDatabase();
        final repRows = await db.rawQuery(
          'SELECT ven00_codfil FROM cadrep00 WHERE ven00_codigo = ? LIMIT 1',
          [AppState().vendedor_codigo],
        );
        if (repRows.isNotEmpty && repRows.first['ven00_codfil'] != null) {
          final fil = int.tryParse(repRows.first['ven00_codfil'].toString()) ?? 1;
          if (fil > 0) {
            AppState().filialAtiva = fil;
          }
        }
        if (AppState().filialAtiva <= 0) {
          final filRows = await db.rawQuery('SELECT fil00_codigo, fil00_descri FROM cadfil00 LIMIT 1');
          if (filRows.isNotEmpty && filRows.first['fil00_codigo'] != null) {
            AppState().filialAtiva = int.tryParse(filRows.first['fil00_codigo'].toString()) ?? 1;
            AppState().filialAtivaDes = filRows.first['fil00_descri']?.toString() ?? '';
          }
        }
      } catch (_) {}
    }

    final result = await obterDadosPedidoNovo();
    safeSetState(() {
      _model.clientes = result.clientes;
      _model.linhas = result.linhas;
      _model.planos = result.planos;
      if (_model.linhas.length == 1) {
        _model.selectedLinha = autoSelecionarLinhaSeUnica(_model.linhas);
      }
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
              final term = searchQuery.trim().toLowerCase();
              if (term.isEmpty) return true;
              final name = c.cli00Descri.toLowerCase();
              final fantas = c.cli00Fantas.toLowerCase();
              final cod = c.cli00Codigo.toString();
              final cpfClean = c.cli00Cpfcnp.replaceAll(RegExp(r'[^0-9]'), '');
              final termClean = term.replaceAll(RegExp(r'[^0-9]'), '');
              final matchCpf = termClean.isNotEmpty && cpfClean.contains(termClean);
              return name.contains(term) || fantas.contains(term) || cod.contains(term) || matchCpf;
            }).toList();

            return Align(
              alignment: Alignment.bottomCenter,
              heightFactor: 1.0,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600.0),
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    height: MediaQuery.of(context).size.height * 0.85,
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
                        hintText: 'Pesquise por razão, fantasia, código ou CPF/CNPJ...',
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
                              final hasDebito = (c.cli00Titven) > 0;

                              return Container(
                                margin: const EdgeInsets.only(bottom: 10.0),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? AppTheme.of(context).primary.withValues(alpha: 0.08)
                                      : (hasDebito ? const Color(0xFFFFF5F5) : Colors.white),
                                  borderRadius: BorderRadius.circular(12.0),
                                  border: Border.all(
                                    color: hasDebito
                                        ? const Color(0xFFE53935)
                                        : (isSelected ? AppTheme.of(context).primary : const Color(0xFFE0E3E7)),
                                    width: (hasDebito || isSelected) ? 1.5 : 1.0,
                                  ),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Color(0x0A000000),
                                      blurRadius: 3,
                                      offset: Offset(0, 1),
                                    )
                                  ],
                                ),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(12.0),
                                  onTap: () async {
                                    final selected = c;

                                    // SPEC-042 Requisito 3: Validação de Crédito e Disparo Compulsório do Extrato
                                    final statusBloqueio = await BloqueioFinanceiroService.verificaInadimplenciaCliente(selected.cli00Codigo);
                                    if (statusBloqueio.bloqueado) {
                                      if (!context.mounted) return;
                                      // Abre compulsoriamente o Extrato em modo bloqueio
                                      final bool? liberado = await ExtratoClientePageWidget.show(
                                        context,
                                        codigoCliente: selected.cli00Codigo,
                                        modoBloqueio: true,
                                      );

                                      // Se o vendedor não confirmou ciência ("Ciência e Liberar Pedido"), bloqueia o avanço
                                      if (liberado != true) {
                                        return;
                                      }
                                    }

                                    safeSetState(() {
                                      _model.selectedCliente = selected;
                                    });


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
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.all(12.0),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // Corpo principal das informações do cliente
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              // Linha 1: Código e Razão Social
                                              Text(
                                                '${c.cli00Codigo} - ${c.cli00Descri}',
                                                style: AppTheme.of(context).bodyLarge.override(
                                                      font: GoogleFonts.inter(fontWeight: FontWeight.bold),
                                                      fontSize: 14.0,
                                                      color: hasDebito ? const Color(0xFFB71C1C) : AppTheme.of(context).primaryText,
                                                    ),
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              const SizedBox(height: 3.0),
                                              // Linha 2: Nome Fantasia
                                              if (c.cli00Fantas.isNotEmpty)
                                                Text(
                                                  c.cli00Fantas,
                                                  style: AppTheme.of(context).bodyMedium.override(
                                                        font: GoogleFonts.inter(fontWeight: FontWeight.w500),
                                                        color: AppTheme.of(context).secondaryText,
                                                        fontSize: 13.0,
                                                      ),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              const SizedBox(height: 6.0),
                                              // Linha 3: CPF / CNPJ e Cidade / UF
                                              Wrap(
                                                spacing: 12.0,
                                                runSpacing: 4.0,
                                                children: [
                                                  if (c.cli00Cpfcnp.isNotEmpty)
                                                    Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        Icon(Icons.badge_outlined, size: 14.0, color: AppTheme.of(context).secondaryText),
                                                        const SizedBox(width: 4.0),
                                                        Text(
                                                          _formatCpfCnpj(c.cli00Cpfcnp),
                                                          style: AppTheme.of(context).bodySmall.override(
                                                                font: GoogleFonts.inter(),
                                                                fontSize: 12.0,
                                                                color: AppTheme.of(context).secondaryText,
                                                              ),
                                                        ),
                                                      ],
                                                    ),
                                                  if (c.cli00Ciddes.isNotEmpty || c.cli00Estsgl.isNotEmpty)
                                                    Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        Icon(Icons.location_on_outlined, size: 14.0, color: AppTheme.of(context).secondaryText),
                                                        const SizedBox(width: 4.0),
                                                        Text(
                                                          '${c.cli00Ciddes}${c.cli00Ciddes.isNotEmpty && c.cli00Estsgl.isNotEmpty ? " / " : ""}${c.cli00Estsgl}',
                                                          style: AppTheme.of(context).bodySmall.override(
                                                                font: GoogleFonts.inter(),
                                                                fontSize: 12.0,
                                                                color: AppTheme.of(context).secondaryText,
                                                              ),
                                                        ),
                                                      ],
                                                    ),
                                                ],
                                              ),
                                              const SizedBox(height: 8.0),
                                              // Linha 4: Limite Atual e Tag de Débitos Vencidos
                                              Row(
                                                children: [
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 3.0),
                                                    decoration: BoxDecoration(
                                                      color: Colors.blueGrey.withValues(alpha: 0.1),
                                                      borderRadius: BorderRadius.circular(6.0),
                                                    ),
                                                    child: Text(
                                                      'Limite: ${c.cli00Creatu.toMoeda()}',
                                                      style: GoogleFonts.inter(
                                                        fontSize: 12.0,
                                                        fontWeight: FontWeight.w600,
                                                        color: Colors.blueGrey.shade800,
                                                      ),
                                                    ),
                                                  ),
                                                  if (hasDebito) ...[
                                                    const SizedBox(width: 8.0),
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 3.0),
                                                      decoration: BoxDecoration(
                                                        color: const Color(0xFFFFEBEE),
                                                        borderRadius: BorderRadius.circular(6.0),
                                                        border: Border.all(color: const Color(0xFFEF9A9A)),
                                                      ),
                                                      child: Row(
                                                        mainAxisSize: MainAxisSize.min,
                                                        children: [
                                                          const Icon(Icons.warning_amber_rounded, size: 13.0, color: Color(0xFFC62828)),
                                                          const SizedBox(width: 4.0),
                                                          Text(
                                                            'Débito: ${c.cli00Titven.toMoeda()}',
                                                            style: GoogleFonts.inter(
                                                              fontSize: 11.5,
                                                              fontWeight: FontWeight.bold,
                                                              color: const Color(0xFFC62828),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ],
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                        // Atalho direto de Extrato e Indicador de Seleção
                                        Column(
                                          children: [
                                            // Botão de Atalho de Extrato (SPEC-042 Requisito 2)
                                            IconButton(
                                              tooltip: 'Extrato de Títulos',
                                              icon: const Icon(
                                                Icons.receipt_long_rounded,
                                                color: Color(0xFF1976D2),
                                                size: 24.0,
                                              ),
                                              onPressed: () {
                                                ExtratoClientePageWidget.show(
                                                  context,
                                                  codigoCliente: c.cli00Codigo,
                                                );
                                              },
                                            ),
                                            if (isSelected)
                                              Padding(
                                                padding: const EdgeInsets.only(top: 4.0),
                                                child: Icon(
                                                  Icons.check_circle_rounded,
                                                  color: AppTheme.of(context).primary,
                                                  size: 22.0,
                                                ),
                                              ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
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
                                      AppState().filialAtiva > 0
                                          ? '${AppState().filialAtiva}${AppState().filialAtivaDes.isNotEmpty ? ' - ${AppState().filialAtivaDes}' : ''}'
                                          : (AppState().empresa_codigo.isNotEmpty ? AppState().empresa_codigo : '1'),
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
                              try {
                                final int filialAtiva = AppState().filialAtiva > 0
                                    ? AppState().filialAtiva
                                    : (AppState().codFilialAtiva > 0
                                        ? AppState().codFilialAtiva
                                        : (resolverCodFilial(AppState().empresa_codigo) ?? 1));

                                int tempOrderId = 0;
                                try {
                                  tempOrderId = await obterProximoNumeroPedido(codFilial: filialAtiva);
                                } catch (e) {
                                  print('Aviso ao obter proximo numero do pedido: $e');
                                  tempOrderId = 1;
                                }
                                if (tempOrderId <= 0) tempOrderId = 1;

                                if (!context.mounted) return;
                                AppState().update(() {
                                  AppState().pedido_numero = tempOrderId;
                                });

                                final cli = _model.selectedCliente;

                                // Persiste o cabeçalho inicial como rascunho de forma segura com a filial ativa
                                try {
                                  await salvarCarrinhoPedido(
                                    pedidoId: tempOrderId,
                                    clienteCodigo: cli?.cli00Codigo ?? 0,
                                    linhaCodigo: _model.selectedLinha?.codigo,
                                    planoCodigo: _model.selectedPlano?.codigo,
                                    codFilial: filialAtiva,
                                    carrinhoItens: [],
                                  );
                                } catch (e) {
                                  print('Aviso ao salvar rascunho inicial do pedido: $e');
                                }

                                if (!context.mounted) return;

                                context.pushNamed(
                                  PedidoItensListaWidget.routeName,
                                  queryParameters: {
                                    'pedidoId': tempOrderId.toString(),
                                    'clienteNome': cli?.cli00Descri ?? '',
                                    'clienteCodigo': (cli?.cli00Codigo ?? 0).toString(),
                                    'clienteCnpj': cli?.cli00Cpfcnp ?? '',
                                    'clienteCidade': '${cli?.cli00Ciddes ?? ''} - ${cli?.cli00Estsgl ?? ''}',
                                    'clienteLimite': (cli?.cli00Crelim ?? 0.0).toString(),
                                    'linhaCodigo': _model.selectedLinha?.codigo ?? '',
                                    'linhaDescricao': _model.selectedLinha?.descricao ?? '',
                                    'planoCodigo': _model.selectedPlano?.codigo ?? '',
                                    'planoDescricao': _model.selectedPlano?.descricao ?? '',
                                    'clienteEndereco': '${cli?.cli00Endere ?? ''}, ${cli?.cli00Endnum ?? ''} - ${cli?.cli00Bairro ?? ''}',
                                  },
                                );
                              } catch (e, s) {
                                print('Erro ao iniciar digitacao: $e\n$s');
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Nao foi possivel iniciar a digitacao: $e'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              }
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
