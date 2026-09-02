import 'dart:io';
import '/core/app_theme.dart';
import '/core/app_util.dart';
import '/index.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sqflite/sqflite.dart';
import '/data/services/local_sales_database_service.dart';
import '/components/extrato_duplicatas/extrato_duplicatas_widget.dart';
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

  _ClienteExtratoInfo({
    required this.codigo,
    required this.razaoSocial,
    required this.fantasia,
    required this.cpfCnpj,
    required this.cidadeUf,
    required this.limiteCredito,
    required this.limiteUtilizado,
    required this.limiteDisponivel,
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

class _TituloExtratoItem {
  final String documento;
  final String vencimento;
  final double valor;
  final bool vencido;

  _TituloExtratoItem({
    required this.documento,
    required this.vencimento,
    required this.valor,
    required this.vencido,
  });
}

class _FaturamentoExtratoItem {
  final String documento;
  final String data;
  final double valor;

  _FaturamentoExtratoItem({
    required this.documento,
    required this.data,
    required this.valor,
  });
}

/// Tela de Extrato Detalhado do Cliente
class ExtratoClientePageWidget extends StatefulWidget {
  const ExtratoClientePageWidget({
    super.key,
    this.codigoCliente,
  });

  final String? codigoCliente;

  static String routeName = 'ExtratoClientePage';
  static String routePath = '/extratoCliente';

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
  List<_PedidoExtratoItem> _pedidosLocais = [];
  List<_TituloExtratoItem> _titulos = [];
  List<_FaturamentoExtratoItem> _faturamentos = [];

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => ExtratoClientePageModel());
    _tabController = TabController(length: 3, vsync: this);
    _carregarDados();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _model.dispose();
    super.dispose();
  }

  Future<void> _carregarDados() async {
    setState(() => _loading = true);
    final codInt = int.tryParse(widget.codigoCliente ?? '') ?? 0;
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

        // 3. Títulos / Duplicatas
        final List<_TituloExtratoItem> tList = [];
        final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
        for (final tbl in ['findup00', 'dup00', 'finrec00', 'cadrec00']) {
          try {
            final tExists = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table' AND lower(name)=?", [tbl]);
            if (tExists.isEmpty) continue;
            final dCols = await db.rawQuery('PRAGMA table_info($tbl)');
            final cnD = dCols.map((r) => r['name'].toString().toLowerCase()).toSet();
            String? cCli;
            String? cNum;
            String? cVen;
            String? cVal;
            for (final c in ['dup00_codcli', 'dup00_clicod', 'rec00_codcli', 'codcli', 'clicod']) {
              if (cnD.contains(c)) { cCli = c; break; }
            }
            for (final c in ['dup00_numero', 'dup00_numdup', 'rec00_numero', 'numero', 'documento']) {
              if (cnD.contains(c)) { cNum = c; break; }
            }
            for (final c in ['dup00_datven', 'rec00_datven', 'datven', 'vencimento']) {
              if (cnD.contains(c)) { cVen = c; break; }
            }
            for (final c in ['dup00_valdup', 'dup00_valor', 'dup00_valabe', 'rec00_valor', 'valor', 'valtot']) {
              if (cnD.contains(c)) { cVal = c; break; }
            }
            if (cCli != null && cNum != null && cVen != null && cVal != null) {
              final dRows = await db.rawQuery('SELECT * FROM $tbl WHERE $cCli = ? ORDER BY $cVen ASC', [codInt]);
              for (final dr in dRows) {
                final numDoc = dr[cNum]?.toString() ?? '';
                final dtVen = dr[cVen]?.toString() ?? '';
                final val = (dr[cVal] is num) ? (dr[cVal] as num).toDouble() : (double.tryParse(dr[cVal]?.toString() ?? '') ?? 0.0);
                final vencido = dtVen.isNotEmpty && dtVen.compareTo(todayStr) < 0;
                tList.add(_TituloExtratoItem(
                  documento: numDoc,
                  vencimento: dtVen,
                  valor: val,
                  vencido: vencido,
                ));
              }
              if (tList.isNotEmpty) break;
            }
          } catch (_) {}
        }
        _titulos = tList;

        // 4. Histórico de faturamento (ESTFATCVD00)
        final List<_FaturamentoExtratoItem> fList = [];
        try {
          final tFat = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table' AND lower(name)='estfatcvd00'");
          if (tFat.isNotEmpty) {
            final fRows = await db.rawQuery('SELECT * FROM ESTFATCVD00 WHERE fat00_codcli = ? ORDER BY fat00_datfat DESC', [codInt]);
            for (final fr in fRows) {
              final doc = fr['fat00_codmov']?.toString() ?? '';
              final dat = fr['fat00_datfat']?.toString() ?? '';
              final val = (fr['fat00_valtot'] is num) ? (fr['fat00_valtot'] as num).toDouble() : (double.tryParse(fr['fat00_valtot']?.toString() ?? '') ?? 0.0);
              fList.add(_FaturamentoExtratoItem(
                documento: doc,
                data: dat,
                valor: val,
              ));
            }
          }
        } catch (_) {}
        _faturamentos = fList;
      } finally {
        await db.close();
      }
    } catch (e) {
      print('Erro ao carregar extrato do cliente: $e');
    }

    if (mounted) setState(() => _loading = false);
  }

  String _fmtMoeda(double v) =>
      'R\$ ${v.toStringAsFixed(2).replaceAll('.', ',')}';

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
            icon: const Icon(Icons.receipt_long_rounded, color: Colors.white),
            tooltip: 'Auditoria de Duplicatas (Receber)',
            onPressed: () {
              final codInt = int.tryParse(widget.codigoCliente ?? '') ?? 0;
              if (codInt > 0) {
                ExtratoDuplicatasWidget.show(context, codigoCliente: codInt);
              }
            },
          ),
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
              text: 'Títulos (${_titulos.length})',
              icon: const Icon(Icons.receipt_outlined, size: 18.0),
            ),
            Tab(
              text: 'Faturamento (${_faturamentos.length})',
              icon: const Icon(Icons.history_edu_outlined, size: 18.0),
            ),
          ],
        ),
        elevation: 2.0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
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

    return Container(
      margin: const EdgeInsets.fromLTRB(12.0, 12.0, 12.0, 6.0),
      padding: const EdgeInsets.all(14.0),
      decoration: BoxDecoration(
        color: theme.secondaryBackground,
        borderRadius: BorderRadius.circular(12.0),
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
                backgroundColor: theme.primary.withValues(alpha: 0.12),
                child: Icon(Icons.person, color: theme.primary, size: 24.0),
              ),
              const SizedBox(width: 12.0),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${info.codigo} - ${info.razaoSocial}',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.bold,
                        fontSize: 15.0,
                        color: theme.primaryText,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
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
          const SizedBox(height: 12.0),
          const Divider(height: 1.0),
          const SizedBox(height: 10.0),
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
    if (_titulos.isEmpty) {
      return _buildEmptyState(
        icon: Icons.receipt_outlined,
        title: 'Nenhum título a receber',
        subtitle: 'Não há duplicatas ou títulos pendentes para este cliente.',
      );
    }

    final totalAberto = _titulos.fold<double>(0.0, (acc, t) => acc + t.valor);

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          color: theme.primary.withValues(alpha: 0.06),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${_titulos.length} títulos',
                style: GoogleFonts.inter(fontSize: 13.0, fontWeight: FontWeight.w600),
              ),
              Text(
                'Total: ${_fmtMoeda(totalAberto)}',
                style: GoogleFonts.inter(fontSize: 13.0, fontWeight: FontWeight.bold, color: Colors.redAccent.shade700),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(12.0),
            itemCount: _titulos.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8.0),
            itemBuilder: (context, index) {
              final t = _titulos[index];
              return Container(
                padding: const EdgeInsets.all(12.0),
                decoration: BoxDecoration(
                  color: theme.secondaryBackground,
                  borderRadius: BorderRadius.circular(10.0),
                  border: Border.all(color: t.vencido ? Colors.red.shade200 : theme.alternate.withValues(alpha: 0.5)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Documento: ${t.documento}',
                          style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13.0),
                        ),
                        const SizedBox(height: 4.0),
                        Text(
                          'Vencimento: ${_fmtData(t.vencimento)}',
                          style: GoogleFonts.inter(
                            fontSize: 12.0,
                            color: t.vencido ? Colors.red.shade700 : theme.secondaryText,
                            fontWeight: t.vencido ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          _fmtMoeda(t.valor),
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.bold,
                            fontSize: 14.0,
                            color: t.vencido ? Colors.red.shade700 : theme.primaryText,
                          ),
                        ),
                        if (t.vencido)
                          Container(
                            margin: const EdgeInsets.only(top: 2.0),
                            padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 1.0),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(4.0),
                            ),
                            child: Text(
                              'Vencido',
                              style: TextStyle(color: Colors.red.shade700, fontSize: 10.0, fontWeight: FontWeight.bold),
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
    );
  }

  Widget _buildTabFaturamento(AppTheme theme) {
    if (_faturamentos.isEmpty) {
      return _buildEmptyState(
        icon: Icons.history_edu_outlined,
        title: 'Nenhum faturamento registrado',
        subtitle: 'Não há registros de faturamento histórico para este cliente.',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(12.0),
      itemCount: _faturamentos.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8.0),
      itemBuilder: (context, index) {
        final f = _faturamentos[index];
        return Container(
          padding: const EdgeInsets.all(12.0),
          decoration: BoxDecoration(
            color: theme.secondaryBackground,
            borderRadius: BorderRadius.circular(10.0),
            border: Border.all(color: theme.alternate.withValues(alpha: 0.5)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Fatura #${f.documento}',
                    style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13.0),
                  ),
                  const SizedBox(height: 4.0),
                  Text(
                    'Data: ${_fmtData(f.data)}',
                    style: GoogleFonts.inter(fontSize: 12.0, color: theme.secondaryText),
                  ),
                ],
              ),
              Text(
                _fmtMoeda(f.valor),
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.bold,
                  fontSize: 14.0,
                  color: Colors.blue.shade700,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 56.0, color: const Color(0xFFADB5BD)),
            const SizedBox(height: 12.0),
            Text(
              title,
              style: GoogleFonts.inter(
                fontSize: 16.0,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF495057),
              ),
            ),
            const SizedBox(height: 6.0),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 13.0,
                color: const Color(0xFF6C757D),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
