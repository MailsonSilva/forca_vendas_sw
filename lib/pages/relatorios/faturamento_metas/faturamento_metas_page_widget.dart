// ignore_for_file: deprecated_member_use, unnecessary_import

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '/core/app_icon_button.dart';
import '/core/app_theme.dart';
import '/core/app_util.dart';

import '/domain/models/faturamento_metas_model.dart';
import '/services/faturamento_metas_service.dart';
import 'faturamento_metas_page_model.dart';

export 'faturamento_metas_page_model.dart';

class FaturamentoMetasPageWidget extends StatefulWidget {
  const FaturamentoMetasPageWidget({super.key});

  static String routeName = 'FaturamentoMetasPage';
  static String routePath = '/faturamentoMetasPage';

  @override
  State<FaturamentoMetasPageWidget> createState() =>
      _FaturamentoMetasPageWidgetState();
}

class _FaturamentoMetasPageWidgetState
    extends State<FaturamentoMetasPageWidget> {
  late FaturamentoMetasPageModel _model;
  final scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => FaturamentoMetasPageModel());
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _model.carregarMetas();
      safeSetState(() {});
    });
  }

  @override
  void dispose() {
    _model.dispose();
    super.dispose();
  }

  Color _obterCorProgresso(double percentual) {
    if (percentual >= 100.0) {
      return const Color(0xFF24A148); // Verde
    } else if (percentual >= 50.0) {
      return const Color(0xFFF59E0B); // Amarelo/Âmbar
    } else {
      return const Color(0xFFDA1E28); // Vermelho
    }
  }

  Widget _buildCardGeral(FaturamentoConsolidadoResumo resumo) {
    final corProgresso = _obterCorProgresso(resumo.percentualGeralAtingido);
    final progressoFracao = (resumo.percentualGeralAtingido / 100.0).clamp(0.0, 1.0);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E3A8A), Color(0xFF3B82F6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16.0),
        boxShadow: const [
          BoxShadow(
            blurRadius: 8.0,
            color: Color(0x33000000),
            offset: Offset(0.0, 4.0),
          )
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8.0),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(10.0),
                      ),
                      child: const Icon(
                        Icons.track_changes_rounded,
                        color: Colors.white,
                        size: 24.0,
                      ),
                    ),
                    const SizedBox(width: 10.0),
                    Text(
                      'Meta Geral Consolidada',
                      style: AppTheme.of(context).bodyMedium.override(
                            font: GoogleFonts.inter(fontWeight: FontWeight.w600),
                            color: Colors.white,
                            fontSize: 16.0,
                          ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 4.0),
                  decoration: BoxDecoration(
                    color: corProgresso.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(20.0),
                  ),
                  child: Text(
                    '${resumo.percentualGeralAtingido.toStringAsFixed(1)}%',
                    style: AppTheme.of(context).bodyMedium.override(
                          font: GoogleFonts.inter(fontWeight: FontWeight.bold),
                          color: Colors.white,
                          fontSize: 13.0,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16.0),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Meta Estipulada',
                      style: AppTheme.of(context).bodyMedium.override(
                            font: GoogleFonts.inter(),
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 12.0,
                          ),
                    ),
                    const SizedBox(height: 2.0),
                    Text(
                      FaturamentoMetasService.formatarMoeda(resumo.totalGeralMeta),
                      style: AppTheme.of(context).bodyLarge.override(
                            font: GoogleFonts.inter(fontWeight: FontWeight.bold),
                            color: Colors.white,
                            fontSize: 18.0,
                          ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Realizado Total',
                      style: AppTheme.of(context).bodyMedium.override(
                            font: GoogleFonts.inter(),
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 12.0,
                          ),
                    ),
                    const SizedBox(height: 2.0),
                    Text(
                      FaturamentoMetasService.formatarMoeda(resumo.totalGeralRealizado),
                      style: AppTheme.of(context).bodyLarge.override(
                            font: GoogleFonts.inter(fontWeight: FontWeight.bold),
                            color: const Color(0xFF6EE7B7),
                            fontSize: 18.0,
                          ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 14.0),
            ClipRRect(
              borderRadius: BorderRadius.circular(8.0),
              child: LinearProgressIndicator(
                value: progressoFracao,
                minHeight: 10.0,
                backgroundColor: Colors.white.withOpacity(0.25),
                valueColor: AlwaysStoppedAnimation<Color>(
                  resumo.percentualGeralAtingido >= 100.0
                      ? const Color(0xFF34D399)
                      : const Color(0xFFFBBF24),
                ),
              ),
            ),
            const SizedBox(height: 10.0),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Oficial ERP: ${FaturamentoMetasService.formatarMoeda(resumo.pessoaJuridica.faturadoErp + resumo.pessoaFisica.faturadoErp)}',
                  style: AppTheme.of(context).bodyMedium.override(
                        font: GoogleFonts.inter(),
                        color: Colors.white.withOpacity(0.75),
                        fontSize: 11.0,
                      ),
                ),
                Text(
                  'Em Trânsito: ${FaturamentoMetasService.formatarMoeda(resumo.pessoaJuridica.digitadoTransito + resumo.pessoaJuridica.rascunhoLocal + resumo.pessoaFisica.digitadoTransito + resumo.pessoaFisica.rascunhoLocal)}',
                  style: AppTheme.of(context).bodyMedium.override(
                        font: GoogleFonts.inter(),
                        color: Colors.white.withOpacity(0.75),
                        fontSize: 11.0,
                      ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSegmentoCard({
    required String title,
    required IconData icon,
    required Color iconColor,
    required MetaSegmentoModel model,
  }) {
    final cor = _obterCorProgresso(model.percentualAtingido);
    final fracao = (model.percentualAtingido / 100.0).clamp(0.0, 1.0);
    final emTransito = model.digitadoTransito + model.rascunhoLocal;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppTheme.of(context).secondaryBackground,
        borderRadius: BorderRadius.circular(14.0),
        boxShadow: const [
          BoxShadow(
            blurRadius: 4.0,
            color: Color(0x1A000000),
            offset: Offset(0.0, 2.0),
          )
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7.0),
                      decoration: BoxDecoration(
                        color: iconColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      child: Icon(icon, color: iconColor, size: 20.0),
                    ),
                    const SizedBox(width: 10.0),
                    Text(
                      title,
                      style: AppTheme.of(context).bodyMedium.override(
                            font: GoogleFonts.inter(fontWeight: FontWeight.w600),
                            fontSize: 15.0,
                          ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 3.0),
                  decoration: BoxDecoration(
                    color: cor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                  child: Text(
                    '${model.percentualAtingido.toStringAsFixed(1)}%',
                    style: AppTheme.of(context).bodyMedium.override(
                          font: GoogleFonts.inter(fontWeight: FontWeight.bold),
                          color: cor,
                          fontSize: 13.0,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12.0),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildInfoColumn('Meta Estipulada', FaturamentoMetasService.formatarMoeda(model.valorMeta)),
                _buildInfoColumn('Faturado ERP', FaturamentoMetasService.formatarMoeda(model.faturadoErp)),
                _buildInfoColumn('Em Trânsito', FaturamentoMetasService.formatarMoeda(emTransito)),
                _buildInfoColumn('Consolidado', FaturamentoMetasService.formatarMoeda(model.totalConsolidado), isHighlight: true),
              ],
            ),
            const SizedBox(height: 10.0),
            ClipRRect(
              borderRadius: BorderRadius.circular(6.0),
              child: LinearProgressIndicator(
                value: fracao,
                minHeight: 6.0,
                backgroundColor: Colors.grey.withOpacity(0.2),
                valueColor: AlwaysStoppedAnimation<Color>(cor),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoColumn(String label, String value, {bool isHighlight = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTheme.of(context).bodyMedium.override(
                font: GoogleFonts.inter(),
                color: AppTheme.of(context).secondaryText,
                fontSize: 11.0,
              ),
        ),
        const SizedBox(height: 2.0),
        Text(
          value,
          style: AppTheme.of(context).bodyMedium.override(
                font: GoogleFonts.inter(
                  fontWeight: isHighlight ? FontWeight.bold : FontWeight.w500,
                ),
                color: isHighlight
                    ? AppTheme.of(context).primary
                    : AppTheme.of(context).primaryText,
                fontSize: 12.0,
              ),
        ),
      ],
    );
  }

  Widget _buildCardLimitePessoaFisica(MetaSegmentoModel pf) {
    final limiteLiberado = pf.limiteLiberadoPf;
    final realizadoPf = pf.totalConsolidado;
    final saldoDisponivel = limiteLiberado - realizadoPf;
    final excedido = limiteLiberado > 0.0 && saldoDisponivel < 0.0;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: excedido ? const Color(0xFFFDF2F2) : const Color(0xFFF0FDF4),
        border: Border.all(
          color: excedido ? const Color(0xFFEF4444) : const Color(0xFF86EFAC),
          width: 1.2,
        ),
        borderRadius: BorderRadius.circular(14.0),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  excedido ? Icons.warning_amber_rounded : Icons.verified_user_rounded,
                  color: excedido ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
                  size: 22.0,
                ),
                const SizedBox(width: 8.0),
                Text(
                  'Cota / Limite Fiscal Pessoa Física (PF)',
                  style: AppTheme.of(context).bodyMedium.override(
                        font: GoogleFonts.inter(fontWeight: FontWeight.bold),
                        color: excedido ? const Color(0xFF991B1B) : const Color(0xFF166534),
                        fontSize: 14.0,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 10.0),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildInfoColumn('Limite Autorizado', FaturamentoMetasService.formatarMoeda(limiteLiberado)),
                _buildInfoColumn('Total Consolidado PF', FaturamentoMetasService.formatarMoeda(realizadoPf)),
                _buildInfoColumn(
                  'Saldo Restante',
                  FaturamentoMetasService.formatarMoeda(saldoDisponivel > 0.0 ? saldoDisponivel : 0.0),
                  isHighlight: true,
                ),
              ],
            ),
            if (excedido) ...[
              const SizedBox(height: 8.0),
              Text(
                '⚠️ Limite de Pessoa Física atingido/excedido! Novas vendas PF serão bloqueadas pelo sistema.',
                style: AppTheme.of(context).bodyMedium.override(
                      font: GoogleFonts.inter(fontWeight: FontWeight.w500),
                      color: const Color(0xFFDC2626),
                      fontSize: 11.0,
                    ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    context.watch<AppState>();
    final resumo = _model.dadosMetas ?? FaturamentoConsolidadoResumo.empty();

    return Scaffold(
      key: scaffoldKey,
      backgroundColor: AppTheme.of(context).primaryBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.of(context).primary,
        automaticallyImplyLeading: false,
        leading: AppIconButton(
          borderColor: Colors.transparent,
          borderRadius: 30.0,
          borderWidth: 1.0,
          buttonSize: 60.0,
          icon: const Icon(
            Icons.arrow_back_rounded,
            color: Colors.white,
            size: 24.0,
          ),
          onPressed: () async {
            Navigator.pop(context);
          },
        ),
        title: Text(
          'Faturamento e Metas',
          style: AppTheme.of(context).headlineMedium.override(
                font: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
                color: Colors.white,
                fontSize: 20.0,
              ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            tooltip: 'Atualizar Metas',
            onPressed: () async {
              await _model.carregarMetas();
              safeSetState(() {});
            },
          ),
        ],
        centerTitle: true,
        elevation: 2.0,
      ),
      body: SafeArea(
        top: true,
        child: _model.isLoading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: () async {
                  await _model.carregarMetas();
                  safeSetState(() {});
                },
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Subheader Vendedor & Sincronização
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Vendedor: ${AppState().vendedor_nome}',
                            style: AppTheme.of(context).bodyMedium.override(
                                  font: GoogleFonts.inter(fontWeight: FontWeight.w600),
                                  fontSize: 14.0,
                                ),
                          ),
                          if (resumo.dataSincronizacao != null)
                            Text(
                              'Sinc: ${resumo.dataSincronizacao}',
                              style: AppTheme.of(context).bodyMedium.override(
                                    font: GoogleFonts.inter(),
                                    color: AppTheme.of(context).secondaryText,
                                    fontSize: 11.0,
                                  ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 14.0),

                      // Card Geral
                      _buildCardGeral(resumo),
                      const SizedBox(height: 16.0),

                      // Card PJ
                      _buildSegmentoCard(
                        title: 'Pessoa Jurídica (PJ)',
                        icon: Icons.business_rounded,
                        iconColor: const Color(0xFF2563EB),
                        model: resumo.pessoaJuridica,
                      ),
                      const SizedBox(height: 14.0),

                      // Card PF
                      _buildSegmentoCard(
                        title: 'Pessoa Física (PF)',
                        icon: Icons.person_rounded,
                        iconColor: const Color(0xFF7C3AED),
                        model: resumo.pessoaFisica,
                      ),
                      const SizedBox(height: 14.0),

                      // Card Trava PF
                      _buildCardLimitePessoaFisica(resumo.pessoaFisica),
                      const SizedBox(height: 20.0),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}
