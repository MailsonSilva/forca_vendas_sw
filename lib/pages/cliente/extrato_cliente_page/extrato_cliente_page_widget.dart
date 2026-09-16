import 'dart:io';
import '/core/app_theme.dart';
import '/core/app_util.dart';
import '/index.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sqflite/sqflite.dart';
import '/data/services/local_sales_database_service.dart';
import '/services/receber_duplicatas_service.dart';
import 'extrato_cliente_page_model.dart';
export 'extrato_cliente_page_model.dart';

class _ClienteExtratoInfo {
  final int codigo;
  final String razaoSocial;
  final String fantasia;
  final String cpfCnpj;
  final String cidadeUf;
  final double limiteCredito;
  final double limiteUtilizado;
  final double limiteDisponivel;
  final double totalVencido;
  final double totalAVencer;
  final double totalDevedor;
  final double totalJuros;
  final int maiorDiasAtraso;
  final int qtdTitulosVencidos;
  final int qtdTitulosTotal;

  _ClienteExtratoInfo({
    required this.codigo,
    required this.razaoSocial,
    required this.fantasia,
    required this.cpfCnpj,
    required this.cidadeUf,
    required this.limiteCredito,
    required this.limiteUtilizado,
    required this.limiteDisponivel,
    this.totalVencido = 0.0,
    this.totalAVencer = 0.0,
    this.totalDevedor = 0.0,
    this.totalJuros = 0.0,
    this.maiorDiasAtraso = 0,
    this.qtdTitulosVencidos = 0,
    this.qtdTitulosTotal = 0,
  });
}

class _PedidoExtratoItem {
  final int id;
  final String data;
  final double valorTotal;
  final double valorProdutos;
  final double valorBonus;
  final String planoDesc;
  final String linhaDesc;
  final int sttDig;
  final int sttEnv;

  _PedidoExtratoItem({
    required this.id,
    required this.data,
    required this.valorTotal,
    required this.valorProdutos,
    required this.valorBonus,
    required this.planoDesc,
    required this.linhaDesc,
    required this.sttDig,
    required this.sttEnv,
  });

  bool get isRascunho => sttDig == 0;
  bool get isPronto => sttDig != 0 && sttEnv < 2;
  bool get isTransmitido => sttEnv == 2;
}



/// Tela de Extrato Detalhado do Cliente
class ExtratoClientePageWidget extends StatefulWidget {
  const ExtratoClientePageWidget({
    super.key,
    this.codigoCliente,
    this.clienteId,
    this.clienteInicial,
    this.modoBloqueio = false,
  });

  final String? codigoCliente;
  final int? clienteId;
  final ClienteReceberItem? clienteInicial;
  final bool modoBloqueio;

  static String routeName = 'ExtratoClientePage';
  static String routePath = '/extratoCliente';

  static Future<bool?> show(
    BuildContext context, {
    ClienteReceberItem? cliente,
    int? codigoCliente,
    int? clienteId,
    bool modoBloqueio = false,
  }) {
    final cod = cliente?.codCli ?? codigoCliente ?? clienteId;
    return Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ExtratoClientePageWidget(
          codigoCliente: cod?.toString(),
          clienteId: cod,
          clienteInicial: cliente,
          modoBloqueio: modoBloqueio,
        ),
      ),
    );
  }

  @override
  State<ExtratoClientePageWidget> createState() =>
      _ExtratoClientePageWidgetState();
}

class _ExtratoClientePageWidgetState extends State<ExtratoClientePageWidget>
    with SingleTickerProviderStateMixin {
  late ExtratoClientePageModel _model;
  final scaffoldKey = GlobalKey<ScaffoldState>();
  late TabController _tabController;

  bool _loading = true;
  _ClienteExtratoInfo? _clienteInfo;
  ClienteReceberItem? _clienteReceber;
  List<_PedidoExtratoItem> _pedidosLocais = [];
  List<TituloDuplicataItem> _titulosDetalhados = [];

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => ExtratoClientePageModel());
    _tabController = TabController(length: 3, vsync: this);
    if (widget.clienteInicial != null) {
      _loading = false;
      _clienteReceber = widget.clienteInicial;
      _titulosDetalhados = widget.clienteInicial!.titulos;
      _clienteInfo = _ClienteExtratoInfo(
        codigo: widget.clienteInicial!.codCli,
        razaoSocial: widget.clienteInicial!.razaoSocial,
        fantasia: widget.clienteInicial!.fantasia,
        cpfCnpj: '',
        cidadeUf: widget.clienteInicial!.cidadeUf,
        limiteCredito: widget.clienteInicial!.limiteCredito,
        limiteUtilizado: widget.clienteInicial!.limiteAtual,
        limiteDisponivel: widget.clienteInicial!.limiteCredito - widget.clienteInicial!.limiteAtual,
        totalVencido: widget.clienteInicial!.totalVencido,
        totalAVencer: widget.clienteInicial!.totalAVencer,
        totalDevedor: widget.clienteInicial!.totalDevedor,
        totalJuros: widget.clienteInicial!.totalJuros,
        maiorDiasAtraso: widget.clienteInicial!.maiorDiasAtraso,
        qtdTitulosVencidos: widget.clienteInicial!.qtdTitulosVencidos,
        qtdTitulosTotal: widget.clienteInicial!.qtdTitulosTotal,
      );
    }
    _carregarDados();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _model.dispose();
    super.dispose();
  }

  Future<void> _carregarDados() async {
    if (widget.clienteInicial == null) {
      setState(() => _loading = true);
    }
    final codInt = widget.clienteId ?? int.tryParse(widget.codigoCliente ?? '') ?? 0;
    if (codInt == 0) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    try {
      final dbPath = await LocalSalesDatabaseService.getDatabasePath();
      if (!await File(dbPath).exists()) {
        if (mounted) setState(() => _loading = false);
        return;
      }

      final db = await openDatabase(dbPath, readOnly: true);
      try {
        // 1. Dados do cliente
        final cliCols = await db.rawQuery('PRAGMA table_info(cadcli00)');
        final cnCli = cliCols.map((r) => r['name'].toString().toLowerCase()).toSet();
        String cCod = cnCli.contains('cli00_codigo') ? 'cli00_codigo' : 'codigo';
        final cliRows = await db.rawQuery('SELECT * FROM cadcli00 WHERE $cCod = ? LIMIT 1', [codInt]);

        if (cliRows.isNotEmpty) {
          final cr = cliRows.first;
          final descri = cr['cli00_descri']?.toString() ?? cr['cli00_nome']?.toString() ?? 'Cliente #$codInt';
          final fantas = cr['cli00_fantasi']?.toString() ?? cr['cli00_fantas']?.toString() ?? '';
          final cnpj = cr['cli00_cpfcnp']?.toString() ?? cr['cli00_cnpj']?.toString() ?? '';
          final cid = cr['cli00_ciddes']?.toString() ?? '';
          final uf = cr['cli00_estsgl']?.toString() ?? '';
          final crelim = (cr['cli00_crelim'] is num) ? (cr['cli00_crelim'] as num).toDouble() : (double.tryParse(cr['cli00_crelim']?.toString() ?? '') ?? 0.0);
          final creatu = (cr['cli00_creatu'] is num) ? (cr['cli00_creatu'] as num).toDouble() : (double.tryParse(cr['cli00_creatu']?.toString() ?? '') ?? 0.0);

          _clienteInfo = _ClienteExtratoInfo(
            codigo: codInt,
            razaoSocial: descri,
            fantasia: fantas,
            cpfCnpj: cnpj,
            cidadeUf: cid.isNotEmpty ? '$cid - $uf' : uf,
            limiteCredito: crelim,
            limiteUtilizado: creatu,
            limiteDisponivel: crelim - creatu,
          );
        }

        // 2. Pedidos locais (pckvendig000)
        final List<_PedidoExtratoItem> pList = [];
        final tPed = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table' AND lower(name)='pckvendig000'");
        if (tPed.isNotEmpty) {
          final pCols = await db.rawQuery('PRAGMA table_info(pckvendig000)');
          final cnP = pCols.map((r) => r['name'].toString().toLowerCase()).toSet();
          String colNum = 'ped00_numped';
          for (final c in ['ped00_numped', 'ped00_pedcod', 'ped00_codmov']) {
            if (cnP.contains(c)) { colNum = c; break; }
          }
          String colCli = 'ped00_codcli';
          for (final c in ['ped00_codcli', 'ped00_clicod']) {
            if (cnP.contains(c)) { colCli = c; break; }
          }

          final pRows = await db.rawQuery('SELECT * FROM pckvendig000 WHERE $colCli = ? ORDER BY $colNum DESC', [codInt]);
          for (final pr in pRows) {
            final id = pr[colNum] is int ? pr[colNum] as int : (int.tryParse(pr[colNum]?.toString() ?? '') ?? 0);
            final dat = pr['ped00_datsys']?.toString() ?? pr['ped00_datemi']?.toString() ?? '';
            final digTot = (pr['ped00_digtot'] is num) ? (pr['ped00_digtot'] as num).toDouble() : (double.tryParse(pr['ped00_digtot']?.toString() ?? '') ?? 0.0);
            final subTot = (pr['ped00_subtot'] is num) ? (pr['ped00_subtot'] as num).toDouble() : 0.0;
            final bonTot = (pr['ped00_bontot'] is num) ? (pr['ped00_bontot'] as num).toDouble() : 0.0;
            final fatTot = (pr['ped00_fattot'] is num) ? (pr['ped00_fattot'] as num).toDouble() : (double.tryParse(pr['ped00_fattot']?.toString() ?? '') ?? (digTot + subTot));
            final sDig = (pr['ped00_sttdig'] is int) ? pr['ped00_sttdig'] as int : (int.tryParse(pr['ped00_sttdig']?.toString() ?? '') ?? 0);
            final sEnv = (pr['ped00_sttenv'] is int) ? pr['ped00_sttenv'] as int : (int.tryParse(pr['ped00_sttenv']?.toString() ?? '') ?? 0);
            final pla = pr['ped00_plades']?.toString() ?? pr['ped00_codpla']?.toString() ?? '';
            final lin = pr['ped00_lindes']?.toString() ?? pr['ped00_codlin']?.toString() ?? '';

            pList.add(_PedidoExtratoItem(
              id: id,
              data: dat,
              valorTotal: fatTot > 0 ? fatTot : digTot,
              valorProdutos: digTot,
              valorBonus: bonTot,
              planoDesc: pla,
              linhaDesc: lin,
              sttDig: sDig,
              sttEnv: sEnv,
            ));
          }
        }
        _pedidosLocais = pList;

        // 3. Títulos / Duplicatas (SPEC-045: centralizado via ReceberDuplicatasService com suporte a finrecdup00 e multi-bancos)
        final taxaJuros = await ReceberDuplicatasService.obterTaxaJurosVendedor(AppState().vendedor_codigo);
        var titulosService = await ReceberDuplicatasService.carregarTitulosCliente(
          codInt,
          dbOverride: db,
          taxaJurosOverride: taxaJuros,
        );
        if (titulosService.isEmpty) {
          // Se não encontrou no banco principal, tenta busca multi-banco (dbforcadig001.db)
          titulosService = await ReceberDuplicatasService.carregarTitulosCliente(
            codInt,
            taxaJurosOverride: taxaJuros,
          );
        }
        if (titulosService.isEmpty && widget.clienteInicial != null && widget.clienteInicial!.titulos.isNotEmpty) {
          titulosService = widget.clienteInicial!.titulos;
        }
        _titulosDetalhados = titulosService;

        // 4. Apuração dos Totais Financeiros das Duplicatas
        double totVenc = 0.0;
        double totAVenc = 0.0;
        double totJuros = 0.0;
        int maiorAtraso = 0;
        int qtdVenc = 0;
        for (final t in titulosService) {
          if (t.isVencido) {
            qtdVenc++;
            totVenc += (t.saldoDevedor + t.valorJuros);
            totJuros += t.valorJuros;
            if (t.diasAtraso > maiorAtraso) maiorAtraso = t.diasAtraso;
          } else {
            totAVenc += t.saldoDevedor;
          }
        }

        if (_clienteInfo != null) {
          _clienteInfo = _ClienteExtratoInfo(
            codigo: _clienteInfo!.codigo,
            razaoSocial: _clienteInfo!.razaoSocial,
            fantasia: _clienteInfo!.fantasia,
            cpfCnpj: _clienteInfo!.cpfCnpj,
            cidadeUf: _clienteInfo!.cidadeUf,
            limiteCredito: _clienteInfo!.limiteCredito,
            limiteUtilizado: _clienteInfo!.limiteUtilizado,
            limiteDisponivel: _clienteInfo!.limiteDisponivel,
            totalVencido: totVenc,
            totalAVencer: totAVenc,
            totalDevedor: totVenc + totAVenc,
            totalJuros: totJuros,
            maiorDiasAtraso: maiorAtraso,
            qtdTitulosVencidos: qtdVenc,
            qtdTitulosTotal: titulosService.length,
          );
        }

        _clienteReceber = ClienteReceberItem(
          codCli: codInt,
          razaoSocial: _clienteInfo?.razaoSocial ?? 'Cliente $codInt',
          fantasia: _clienteInfo?.fantasia ?? '',
          cidadeUf: _clienteInfo?.cidadeUf ?? '',
          limiteCredito: _clienteInfo?.limiteCredito ?? 0.0,
          limiteAtual: _clienteInfo?.limiteUtilizado ?? 0.0,
          totalVencido: totVenc,
          totalAVencer: totAVenc,
          totalDevedor: totVenc + totAVenc,
          totalJuros: totJuros,
          maiorDiasAtraso: maiorAtraso,
          qtdTitulosVencidos: qtdVenc,
          qtdTitulosTotal: titulosService.length,
          titulos: titulosService,
        );


      } finally {
        await db.close();
      }
    } catch (e) {
      print('Erro ao carregar extrato do cliente: $e');
    }

    if (mounted) setState(() => _loading = false);
  }

  String _fmtMoeda(double v) => v.toMoeda();

  String _fmtData(String dat) {
    if (dat.isEmpty) return '—';
    try {
      final p = dat.split(' ')[0].split('-');
      if (p.length == 3) return '${p[2]}/${p[1]}/${p[0]}';
    } catch (_) {}
    return dat;
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);

    return Scaffold(
      key: scaffoldKey,
      backgroundColor: theme.primaryBackground,
      appBar: AppBar(
        backgroundColor: theme.primary,
        automaticallyImplyLeading: true,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          'Extrato do Cliente',
          style: theme.titleLarge.override(
            font: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
            color: Colors.white,
            fontSize: 20.0,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            tooltip: 'Atualizar',
            onPressed: _carregarDados,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3.0,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          labelStyle: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13.0),
          tabs: [
            Tab(
              text: 'Pedidos (${_pedidosLocais.length})',
              icon: const Icon(Icons.shopping_bag_outlined, size: 18.0),
            ),
            Tab(
              text: 'Títulos (${_titulosDetalhados.length})',
              icon: const Icon(Icons.receipt_outlined, size: 18.0),
            ),
            const Tab(
              text: 'Faturamento',
              icon: Icon(Icons.analytics_outlined, size: 18.0),
            ),
          ],
        ),
        elevation: 2.0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              bottom: !widget.modoBloqueio,
              child: Column(
                children: [
                  // ── Resumo do Cliente (Header Card) ─────────────────────────
                  _buildClienteHeaderCard(theme),

                  // ── Abas de Detalhes ─────────────────────────────────────────
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildTabPedidos(theme),
                        _buildTabTitulos(theme),
                        _buildTabFaturamento(theme),
                      ],
                    ),
                  ),
                ],
              ),
            ),
      bottomNavigationBar: (widget.modoBloqueio && !_loading)
          ? _buildBottomBar(theme)
          : null,
    );
  }

  Widget _buildClienteHeaderCard(AppTheme theme) {
    final info = _clienteInfo;
    if (info == null) {
      return Container(
        margin: const EdgeInsets.all(12.0),
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: theme.secondaryBackground,
          borderRadius: BorderRadius.circular(12.0),
        ),
        child: Text(
          'Cliente #${widget.codigoCliente ?? "—"} não encontrado na base local.',
          style: TextStyle(color: theme.secondaryText),
        ),
      );
    }

    final temVencido = info.totalVencido > 0 || info.qtdTitulosVencidos > 0;

    return Container(
      margin: const EdgeInsets.fromLTRB(12.0, 12.0, 12.0, 6.0),
      padding: const EdgeInsets.all(14.0),
      decoration: BoxDecoration(
        color: theme.secondaryBackground,
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(
          color: temVencido ? Colors.red.shade200 : theme.alternate.withValues(alpha: 0.5),
          width: temVencido ? 1.5 : 1.0,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x11000000),
            blurRadius: 4.0,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 20.0,
                backgroundColor: (temVencido ? Colors.red : theme.primary).withValues(alpha: 0.12),
                child: Icon(
                  temVencido ? Icons.warning_amber_rounded : Icons.person,
                  color: temVencido ? Colors.red.shade700 : theme.primary,
                  size: 24.0,
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
                        Expanded(
                          child: Text(
                            '${info.codigo} - ${info.razaoSocial}',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.bold,
                              fontSize: 15.0,
                              color: theme.primaryText,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: temVencido ? Colors.red.shade50 : Colors.green.shade50,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: temVencido ? Colors.red.shade200 : Colors.green.shade200),
                          ),
                          child: Text(
                            temVencido ? 'Inadimplência Ativa' : 'Em Dia',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: temVencido ? Colors.red.shade800 : Colors.green.shade800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (info.fantasia.isNotEmpty)
                      Text(
                        info.fantasia,
                        style: GoogleFonts.inter(
                          fontSize: 13.0,
                          color: theme.secondaryText,
                        ),
                      ),
                    if (info.cpfCnpj.isNotEmpty || info.cidadeUf.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2.0),
                        child: Text(
                          [info.cpfCnpj, info.cidadeUf].where((s) => s.isNotEmpty).join(' • '),
                          style: GoogleFonts.inter(
                            fontSize: 12.0,
                            color: theme.secondaryText,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10.0),
          const Divider(height: 1.0),
          const SizedBox(height: 10.0),

          // Painel de Totais Financeiros das Duplicatas
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: temVencido ? const Color(0xFFFEF2F2) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: temVencido ? Colors.red.shade100 : Colors.blueGrey.shade100),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Total Vencido',
                      style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.red.shade800),
                    ),
                    Text(
                      _fmtMoeda(info.totalVencido),
                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.red.shade800),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Total A Vencer',
                      style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.blueGrey.shade700),
                    ),
                    Text(
                      _fmtMoeda(info.totalAVencer),
                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.blueGrey.shade700),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Total Devedor Geral',
                      style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B)),
                    ),
                    Text(
                      _fmtMoeda(info.totalDevedor),
                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B)),
                    ),
                  ],
                ),
                if (info.maiorDiasAtraso > 0) ...[
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Maior Dias de Atraso',
                        style: GoogleFonts.inter(fontSize: 10, color: Colors.red.shade700),
                      ),
                      Text(
                        '${info.maiorDiasAtraso} dias',
                        style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.red.shade700),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 10.0),

          // Métricas de Limite de Crédito
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildMetric(
                'Limite Crédito',
                _fmtMoeda(info.limiteCredito),
                Colors.blue.shade700,
              ),
              _buildMetric(
                'Utilizado',
                _fmtMoeda(info.limiteUtilizado),
                Colors.orange.shade800,
              ),
              _buildMetric(
                'Disponível',
                _fmtMoeda(info.limiteDisponivel),
                info.limiteDisponivel >= 0 ? Colors.green.shade700 : Colors.red.shade700,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetric(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: GoogleFonts.inter(fontSize: 11.0, color: const Color(0xFF677681)),
        ),
        const SizedBox(height: 2.0),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 13.0,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildTabPedidos(AppTheme theme) {
    if (_pedidosLocais.isEmpty) {
      return _buildEmptyState(
        icon: Icons.shopping_bag_outlined,
        title: 'Nenhum pedido encontrado',
        subtitle: 'Não existem pedidos registrados para este cliente na base local.',
      );
    }

    final totalGeral = _pedidosLocais.fold<double>(0.0, (acc, p) => acc + p.valorTotal);

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          color: theme.primary.withValues(alpha: 0.06),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${_pedidosLocais.length} pedidos encontrados',
                style: GoogleFonts.inter(fontSize: 13.0, fontWeight: FontWeight.w600),
              ),
              Text(
                'Total: ${_fmtMoeda(totalGeral)}',
                style: GoogleFonts.inter(fontSize: 13.0, fontWeight: FontWeight.bold, color: theme.primary),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(12.0),
            itemCount: _pedidosLocais.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8.0),
            itemBuilder: (context, index) {
              final item = _pedidosLocais[index];
              Color statusColor;
              String statusLabel;
              if (item.isTransmitido) {
                statusColor = Colors.green;
                statusLabel = 'Transmitido';
              } else if (item.isPronto) {
                statusColor = Colors.teal;
                statusLabel = 'Pronto p/ Envio';
              } else {
                statusColor = Colors.orange;
                statusLabel = 'Rascunho';
              }

              return InkWell(
                onTap: () {
                  context.pushNamed(
                    PedidoResumoWidget.routeName,
                    queryParameters: {'pedidoId': item.id.toString()},
                  );
                },
                borderRadius: BorderRadius.circular(10.0),
                child: Container(
                  padding: const EdgeInsets.all(12.0),
                  decoration: BoxDecoration(
                    color: theme.secondaryBackground,
                    borderRadius: BorderRadius.circular(10.0),
                    border: Border.all(color: theme.alternate.withValues(alpha: 0.5)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Text(
                                'Pedido #${item.id}',
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14.0,
                                ),
                              ),
                              const SizedBox(width: 8.0),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.0),
                                decoration: BoxDecoration(
                                  color: statusColor.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(4.0),
                                ),
                                child: Text(
                                  statusLabel,
                                  style: GoogleFonts.inter(
                                    fontSize: 11.0,
                                    fontWeight: FontWeight.w600,
                                    color: statusColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          Text(
                            _fmtMoeda(item.valorTotal),
                            style: GoogleFonts.inter(
                              fontSize: 14.0,
                              fontWeight: FontWeight.bold,
                              color: theme.primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6.0),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Data: ${_fmtData(item.data)}',
                            style: GoogleFonts.inter(fontSize: 12.0, color: theme.secondaryText),
                          ),
                          if (item.planoDesc.isNotEmpty)
                            Text(
                              'Plano: ${item.planoDesc}',
                              style: GoogleFonts.inter(fontSize: 12.0, color: theme.secondaryText),
                            ),
                        ],
                      ),
                      if (item.valorBonus > 0)
                        Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Text(
                            'Bônus: ${_fmtMoeda(item.valorBonus)}',
                            style: GoogleFonts.inter(fontSize: 11.0, color: Colors.purple.shade600),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTabTitulos(AppTheme theme) {
    final titulos = _titulosDetalhados.where((t) => t.saldoDevedor > 0).toList();
    if (titulos.isEmpty) {
      return _buildEmptyState(
        icon: Icons.receipt_outlined,
        title: 'Nenhum título a receber',
        subtitle: 'Não há duplicatas ou títulos pendentes para este cliente.',
      );
    }

    final titulosVencidos = titulos.where((t) => t.isVencido).toList();
    final totalAberto = titulos.fold<double>(0.0, (acc, t) => acc + t.saldoDevedor);

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          color: theme.primary.withValues(alpha: 0.06),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Títulos Pendentes (${titulos.length})',
                  style: GoogleFonts.inter(fontSize: 13.0, fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (titulosVencidos.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Text(
                        'Inadimplência Ativa',
                        style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.red.shade800),
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Text(
                        'Em Dia',
                        style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blue.shade800),
                      ),
                    ),
                  Text(
                    'Total: ${_fmtMoeda(totalAberto)}',
                    style: GoogleFonts.inter(fontSize: 13.0, fontWeight: FontWeight.bold, color: Colors.redAccent.shade700),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(12.0),
            itemCount: titulos.length,
            itemBuilder: (context, index) {
              final t = titulos[index];
              return _buildTituloItemCard(t, theme);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTituloItemCard(TituloDuplicataItem t, AppTheme theme) {
    final isVencido = t.isVencido;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isVencido ? Colors.red.shade200 : Colors.grey.shade200,
          width: isVencido ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Linha 1: Documento e Status Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Documento: ${t.numeroDocumento}',
                  style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B)),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: isVencido ? Colors.red.shade50 : Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: isVencido ? Colors.red.shade200 : Colors.blue.shade200),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      isVencido ? 'Vencido' : 'A Vencer',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isVencido ? Colors.red.shade800 : Colors.blue.shade800,
                      ),
                    ),
                    if (isVencido && t.diasAtraso > 0)
                      Text(
                        ' (${t.diasAtraso}d)',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.red.shade800,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Linha 2: Emissão e Vencimento
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Emissão: ${ReceberDuplicatasService.formatarData(t.dataEmissao)}',
                style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade700),
              ),
              Text(
                'Vencimento: ${ReceberDuplicatasService.formatarData(t.dataVencimento)}',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isVencido ? Colors.red.shade700 : const Color(0xFF1E293B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Linha 3: Valor Original e Valor Recebido
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Valor Original: ${t.valorOriginal.toMoeda()}',
                style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade800),
              ),
              Text(
                'Recebido: ${t.valorPago.toMoeda()}',
                style: GoogleFonts.inter(fontSize: 12, color: Colors.green.shade800),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Linha 4: Juros e Saldo Devedor
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Juros: ${(isVencido ? t.valorJuros : 0.0).toMoeda()}',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isVencido ? Colors.orange.shade800 : Colors.grey.shade600,
                ),
              ),
              Text(
                'Saldo Devedor: ${t.saldoDevedor.toMoeda()}',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: isVencido ? const Color(0xFFB91C1C) : const Color(0xFF1E293B),
                ),
              ),
            ],
          ),
          const Divider(height: 14),

          // Linha 5: Vendedor | Agente Cobrador | Tipo Cobrança
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildMetaTag('Vendedor', t.codVen.toString()),
              _buildMetaTag('Agente', t.codAgt.toString()),
              _buildMetaTag('Tipo Cob.', t.codCob.toString()),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetaTag(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        '$label: $value',
        style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w500, color: Colors.grey.shade700),
      ),
    );
  }

  Widget _buildTabFaturamento(AppTheme theme) {
    final titulos = _titulosDetalhados.where((t) => t.saldoDevedor > 0).toList();
    final titulosVencidos = titulos.where((t) => t.isVencido).toList();

    double totalValOriVencidos = 0.0;
    double totalJuros = 0.0;
    int somaDiasAtraso = 0;

    for (final t in titulosVencidos) {
      totalValOriVencidos += t.saldoDevedor;
      totalJuros += t.valorJuros;
      somaDiasAtraso += t.diasAtraso;
    }

    double totalValDevGeral = 0.0;
    for (final t in titulos) {
      totalValDevGeral += t.totalComJuros;
    }

    final info = _clienteInfo;
    final totalVencido = (info != null && info.totalVencido > 0) ? info.totalVencido : totalValOriVencidos;
    final totalDevedor = (info != null && info.totalDevedor > 0) ? info.totalDevedor : totalValDevGeral;
    final totalJurosFinal = (info != null && info.totalJuros > 0) ? info.totalJuros : totalJuros;
    final diasAtrasoFinal = (info != null && info.maiorDiasAtraso > 0 && somaDiasAtraso == 0)
        ? info.maiorDiasAtraso
        : somaDiasAtraso;

    if (titulos.isEmpty) {
      return _buildEmptyState(
        icon: Icons.analytics_outlined,
        title: 'Nenhum título pendente',
        subtitle: 'Não há duplicatas ou pendências financeiras em aberto para este cliente.',
      );
    }

    return Column(
      children: [
        // ── Lista Rolável de Títulos no Formato do Legado (Conforme Imagem) ──
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(14.0, 10.0, 14.0, 16.0),
            itemCount: titulos.length + 1,
            itemBuilder: (context, index) {
              if (index < titulos.length) {
                return _buildItemFaturamentoLegado(titulos[index], index, theme);
              }
              // Item final: Ações de Cobrança e Compartilhamento
              return Padding(
                padding: const EdgeInsets.only(top: 4.0, bottom: 8.0),
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.chat_bubble_outline_rounded, color: Colors.white, size: 18),
                        label: Text(
                          'Enviar via WhatsApp',
                          style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF25D366),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          elevation: 1,
                        ),
                        onPressed: () {
                          final cli = _obterClienteReceberCompleto();
                          if (cli != null) {
                            ReceberDuplicatasService.compartilharWhatsApp(
                              context,
                              cli,
                              nomeVendedor: AppState().vendedor_nome,
                            );
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.copy_rounded, color: Colors.black87, size: 18),
                        label: Text(
                          'Copiar Texto',
                          style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.black87),
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          side: BorderSide(color: Colors.grey.shade400),
                        ),
                        onPressed: () {
                          final cli = _obterClienteReceberCompleto();
                          if (cli != null) {
                            ReceberDuplicatasService.copiarClipboard(
                              context,
                              cli,
                              nomeVendedor: AppState().vendedor_nome,
                            );
                          }
                        },
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),

        // ── Tabela Inferior Fixa de Totais Legados (Conforme Imagem) ──────────
        _buildTabelaTotaisLegada(
          totVencido: totalVencido,
          totJuros: totalJurosFinal,
          diasAtraso: diasAtrasoFinal,
          valorDevedor: totalDevedor,
        ),
      ],
    );
  }

  Widget _buildItemFaturamentoLegado(TituloDuplicataItem t, int index, AppTheme theme) {
    final dtEmi = ReceberDuplicatasService.formatarData(t.dataEmissao);
    final dtVen = ReceberDuplicatasService.formatarData(t.dataVencimento);
    final txJuros = t.taxaJurosDiaria.toStringAsFixed(2).replaceAll('.', ',');
    final isVencido = t.isVencido;

    return Container(
      margin: const EdgeInsets.only(bottom: 10.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10.0),
        border: Border.all(
          color: isVencido ? const Color(0xFFFCA5A5) : const Color(0xFFE2E8F0),
          width: isVencido ? 1.2 : 1.0,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 4.0,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Cabeçalho do Card: Número do Título + Badge de Status
          Padding(
            padding: const EdgeInsets.fromLTRB(12.0, 10.0, 12.0, 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Text(
                        'TÍTULO: ',
                        style: GoogleFonts.inter(
                          fontSize: 14.0,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      Flexible(
                        child: Text(
                          t.numeroDocumento,
                          style: GoogleFonts.inter(
                            fontSize: 15.0,
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFF0F172A),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 3.0),
                  decoration: BoxDecoration(
                    color: isVencido ? const Color(0xFFFEF2F2) : const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(6.0),
                    border: Border.all(
                      color: isVencido ? const Color(0xFFFECACA) : const Color(0xFFBBF7D0),
                    ),
                  ),
                  child: Text(
                    isVencido
                        ? 'VENCIDO${t.diasAtraso > 0 ? ' (${t.diasAtraso}d)' : ''}'
                        : 'EM DIA',
                    style: GoogleFonts.inter(
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                      color: isVencido ? const Color(0xFFB91C1C) : const Color(0xFF15803D),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1.0, thickness: 1.0, color: Color(0xFFF1F5F9)),

          // 2. Grade de Dados: Emissão, Vencimento, Juros e Dias de Atraso
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _buildInfoItem(
                        label: 'EMISSÃO',
                        value: dtEmi,
                      ),
                    ),
                    const SizedBox(width: 12.0),
                    Expanded(
                      child: _buildInfoItem(
                        label: 'VENCIMENTO',
                        value: dtVen,
                        valueColor: isVencido ? const Color(0xFFDC2626) : const Color(0xFF1E293B),
                        isBold: isVencido,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8.0),
                Row(
                  children: [
                    Expanded(
                      child: _buildInfoItem(
                        label: '% JUROS/DIA',
                        value: '$txJuros%',
                      ),
                    ),
                    const SizedBox(width: 12.0),
                    Expanded(
                      child: _buildInfoItem(
                        label: 'DIAS/ATRASO',
                        value: '${t.diasAtraso}',
                        valueColor: isVencido ? const Color(0xFFDC2626) : const Color(0xFF1E293B),
                        isBold: isVencido,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8.0),
                Row(
                  children: [
                    Expanded(
                      child: _buildInfoItem(
                        label: 'VALOR TÍTULO',
                        value: _fmtMoeda(t.saldoDevedor),
                        isBold: true,
                      ),
                    ),
                    const SizedBox(width: 12.0),
                    Expanded(
                      child: _buildInfoItem(
                        label: 'VALOR JUROS',
                        value: _fmtMoeda(t.valorJuros),
                        valueColor: t.valorJuros > 0 ? const Color(0xFFDC2626) : const Color(0xFF1E293B),
                        isBold: t.valorJuros > 0,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // 3. Barra de Destaque Inferior: SALDO DEVEDOR
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
            decoration: BoxDecoration(
              color: isVencido ? const Color(0xFFFEF2F2) : const Color(0xFFF8FAFC),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(9.0),
                bottomRight: Radius.circular(9.0),
              ),
              border: Border(
                top: BorderSide(
                  color: isVencido ? const Color(0xFFFECACA) : const Color(0xFFE2E8F0),
                  width: 1.0,
                ),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'SALDO DEVEDOR:',
                  style: GoogleFonts.inter(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: isVencido ? const Color(0xFF991B1B) : const Color(0xFF334155),
                  ),
                ),
                Text(
                  _fmtMoeda(t.totalComJuros),
                  style: GoogleFonts.inter(
                    fontSize: 15.0,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFFDC2626), // Vermelho vivo idêntico ao legado
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem({
    required String label,
    required String value,
    Color? valueColor,
    bool isBold = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF64748B),
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 2.0),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 13.0,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
            color: valueColor ?? const Color(0xFF1E293B),
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildTabelaTotaisLegada({
    required double totVencido,
    required double totJuros,
    required int diasAtraso,
    required double valorDevedor,
  }) {
    final borderSide = BorderSide(color: Colors.grey.shade300, width: 1.0);
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: borderSide,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 4,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Linha 1: Tot.Vencido | <valor> | Total Juros | <valor>
          Row(
            children: [
              _buildTabelaCelula(
                texto: 'Tot.Vencido',
                isHeader: true,
                flex: 3,
                border: Border(right: borderSide, bottom: borderSide),
              ),
              _buildTabelaCelula(
                texto: _fmtMoeda(totVencido),
                isHeader: false,
                alignRight: true,
                flex: 3,
                valueColor: totVencido > 0 ? const Color(0xFFB91C1C) : null,
                border: Border(right: borderSide, bottom: borderSide),
              ),
              _buildTabelaCelula(
                texto: 'Total Juros',
                isHeader: true,
                flex: 3,
                border: Border(right: borderSide, bottom: borderSide),
              ),
              _buildTabelaCelula(
                texto: _fmtMoeda(totJuros),
                isHeader: false,
                alignRight: true,
                flex: 3,
                border: Border(bottom: borderSide),
              ),
            ],
          ),
          // Linha 2: Dias/Atraso | <valor> | Valor Devedor | <valor>
          Row(
            children: [
              _buildTabelaCelula(
                texto: 'Dias/Atraso',
                isHeader: true,
                flex: 3,
                border: Border(right: borderSide),
              ),
              _buildTabelaCelula(
                texto: diasAtraso.toString(),
                isHeader: false,
                alignRight: true,
                flex: 3,
                border: Border(right: borderSide),
              ),
              _buildTabelaCelula(
                texto: 'Valor Devedor',
                isHeader: true,
                flex: 3,
                border: Border(right: borderSide),
              ),
              _buildTabelaCelula(
                texto: _fmtMoeda(valorDevedor),
                isHeader: false,
                alignRight: true,
                flex: 3,
                valueColor: const Color(0xFFDC2626),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTabelaCelula({
    required String texto,
    required bool isHeader,
    required int flex,
    bool alignRight = false,
    BoxBorder? border,
    Color? valueColor,
  }) {
    return Expanded(
      flex: flex,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 7.0),
        decoration: BoxDecoration(
          color: isHeader ? const Color(0xFFF1F5F9) : Colors.white,
          border: border,
        ),
        alignment: alignRight ? Alignment.centerRight : Alignment.centerLeft,
        child: Text(
          texto,
          style: GoogleFonts.inter(
            fontSize: 11.5,
            fontWeight: isHeader ? FontWeight.w600 : FontWeight.bold,
            color: isHeader
                ? const Color(0xFF475569)
                : (valueColor ?? const Color(0xFF0F172A)),
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  ClienteReceberItem? _obterClienteReceberCompleto() {
    if (_clienteReceber != null) return _clienteReceber;
    final info = _clienteInfo;
    if (info == null) return null;
    return ClienteReceberItem(
      codCli: info.codigo,
      razaoSocial: info.razaoSocial,
      fantasia: info.fantasia,
      cidadeUf: info.cidadeUf,
      limiteCredito: info.limiteCredito,
      limiteAtual: info.limiteUtilizado,
      totalVencido: info.totalVencido,
      totalAVencer: info.totalAVencer,
      totalDevedor: info.totalDevedor,
      totalJuros: info.totalJuros,
      maiorDiasAtraso: info.maiorDiasAtraso,
      qtdTitulosVencidos: info.qtdTitulosVencidos,
      qtdTitulosTotal: _titulosDetalhados.length,
      titulos: _titulosDetalhados,
    );
  }

  Widget _buildBottomBar(AppTheme theme) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Colors.grey.shade300, width: 1.0),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 6.0,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
          child: SizedBox(
            width: double.infinity,
            height: 48.0,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.check_circle_outline_rounded, color: Colors.white, size: 20.0),
              label: Text(
                'Liberar Pedido',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.bold,
                  fontSize: 15.0,
                  letterSpacing: 0.3,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626), // Vermelho vivo
                foregroundColor: Colors.white,
                elevation: 1.0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10.0),
                ),
              ),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 48.0, color: const Color(0xFFADB5BD)),
            const SizedBox(height: 10.0),
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 15.0,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF495057),
              ),
            ),
            const SizedBox(height: 4.0),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 12.0,
                color: const Color(0xFF6C757D),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
