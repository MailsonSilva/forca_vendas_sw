import '/core/app_theme.dart';
import '/core/app_util.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '/action_code/index.dart';
import '/index.dart';
import '/services/nav_bar_service.dart';
import 'configuracao_page_model.dart';
export 'configuracao_page_model.dart';

class ConfiguracaoPageWidget extends StatefulWidget {
  const ConfiguracaoPageWidget({super.key});

  static String routeName = 'ConfiguracaoPage';
  static String routePath = '/configuracaoPage';

  @override
  State<ConfiguracaoPageWidget> createState() => _ConfiguracaoPageWidgetState();
}

class _ConfiguracaoPageWidgetState extends State<ConfiguracaoPageWidget> {
  late ConfiguracaoPageModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => ConfiguracaoPageModel());
    _model.carregarConfiguracoes().then((_) {
      if (mounted) safeSetState(() {});
    });
  }

  @override
  void dispose() {
    _model.dispose();
    super.dispose();
  }

  void _voltarParaHome() {
    if (!mounted) return;
    // 1. Notifica o NavBarService para trocar a tab para HomePage
    NavBarService().navegarParaHome();

    // 2. Se a tela foi aberta via push no Navigator, desempilha
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
      return;
    }

    // 3. Se estiver em rota direta (/configuracaoPage), redireciona
    try {
      context.goNamed(HomePageWidget.routeName);
    } catch (_) {}
  }

  Future<void> _abrirSuporteWhatsApp() async {
    final uri = Uri.parse(
      'https://wa.me/559881283380?text=Ol%C3%A1%2C%20preciso%20de%20suporte%20no%20For%C3%A7a%20de%20Vendas',
    );
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      try {
        await launchUrl(uri);
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _voltarParaHome();
      },
      child: GestureDetector(
        onTap: () {
          FocusScope.of(context).unfocus();
          FocusManager.instance.primaryFocus?.unfocus();
        },
        child: Scaffold(
          key: scaffoldKey,
          backgroundColor: AppTheme.of(context).primaryBackground,
          appBar: AppBar(
            backgroundColor: AppTheme.of(context).primary,
            automaticallyImplyLeading: false,
            leading: IconButton(
              icon: const Icon(
                Icons.arrow_back_rounded,
                color: Colors.white,
                size: 24.0,
              ),
              tooltip: 'Voltar ao Menu Principal',
              onPressed: _voltarParaHome,
            ),
            title: Text(
              'Configurações',
              style: AppTheme.of(context).headlineMedium.override(
                  font: GoogleFonts.plusJakartaSans(
                    fontWeight: AppTheme.of(context).headlineMedium.fontWeight,
                    fontStyle: AppTheme.of(context).headlineMedium.fontStyle,
                  ),
                  color: Colors.white,
                  fontSize: 22.0,
                  letterSpacing: 0.0,
                  fontWeight: AppTheme.of(context).headlineMedium.fontWeight,
                  fontStyle: AppTheme.of(context).headlineMedium.fontStyle,
                ),
          ),
          actions: const [],
          centerTitle: true,
          elevation: 2.0,
        ),
        body: SafeArea(
          top: true,
          child: SingleChildScrollView(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── SEÇÃO: RELATÓRIOS E IMPRESSÃO ──
                Padding(
                  padding: const EdgeInsets.only(left: 4.0, bottom: 8.0),
                  child: Text(
                    'Relatórios e Impressão',
                    style: AppTheme.of(context).bodyMedium.override(
                          font: GoogleFonts.inter(
                            fontWeight: FontWeight.bold,
                          ),
                          color: AppTheme.of(context).secondaryText,
                          fontSize: 14.0,
                          letterSpacing: 0.5,
                        ),
                  ),
                ),
                Card(
                  elevation: 1.5,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                  color: AppTheme.of(context).secondaryBackground,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: SwitchListTile.adaptive(
                      value: _model.exibirLogoPdf,
                      activeTrackColor: AppTheme.of(context).primary,
                      onChanged: (bool val) async {
                        await _model.alterarExibicaoLogoPdf(val);
                        safeSetState(() {});
                      },
                      secondary: Container(
                        padding: const EdgeInsets.all(8.0),
                        decoration: BoxDecoration(
                          color: AppTheme.of(context)
                              .primary
                              .withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                        child: Icon(
                          Icons.picture_as_pdf_rounded,
                          color: AppTheme.of(context).primary,
                          size: 24.0,
                        ),
                      ),
                      title: Text(
                        'Exibir logotipo no PDF do Pedido',
                        style: AppTheme.of(context).bodyLarge.override(
                              font: GoogleFonts.inter(
                                fontWeight: FontWeight.w600,
                              ),
                              fontSize: 15.0,
                            ),
                      ),
                      subtitle: Text(
                        'Imprime a logomarca da distribuidora no cabeçalho do espelho de venda',
                        style: AppTheme.of(context).labelMedium.override(
                              font: GoogleFonts.inter(),
                              color: AppTheme.of(context).secondaryText,
                              fontSize: 12.0,
                            ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 24.0),

                // ── SEÇÃO: AJUDA & ATENDIMENTO ──
                Padding(
                  padding: const EdgeInsets.only(left: 4.0, bottom: 8.0),
                  child: Text(
                    'Ajuda & Atendimento',
                    style: AppTheme.of(context).bodyMedium.override(
                          font: GoogleFonts.inter(
                            fontWeight: FontWeight.bold,
                          ),
                          color: AppTheme.of(context).secondaryText,
                          fontSize: 14.0,
                          letterSpacing: 0.5,
                        ),
                  ),
                ),
                Card(
                  elevation: 1.5,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                  color: AppTheme.of(context).secondaryBackground,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12.0),
                    onTap: _abrirSuporteWhatsApp,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16.0, vertical: 14.0),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10.0),
                            decoration: BoxDecoration(
                              color: const Color(0xFF25D366)
                                  .withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10.0),
                            ),
                            child: const FaIcon(
                              FontAwesomeIcons.whatsapp,
                              color: Color(0xFF25D366),
                              size: 26.0,
                            ),
                          ),
                          const SizedBox(width: 14.0),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Suporte Técnico',
                                  style:
                                      AppTheme.of(context).bodyLarge.override(
                                            font: GoogleFonts.inter(
                                              fontWeight: FontWeight.w600,
                                            ),
                                            fontSize: 15.0,
                                          ),
                                ),
                                const SizedBox(height: 2.0),
                                Text(
                                  '+55 (98) 8128-3380',
                                  style: AppTheme.of(context)
                                      .labelMedium
                                      .override(
                                        font: GoogleFonts.inter(),
                                        color:
                                            AppTheme.of(context).secondaryText,
                                        fontSize: 13.0,
                                      ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.arrow_forward_ios_rounded,
                            color: AppTheme.of(context).secondaryText,
                            size: 16.0,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 24.0),

                // ── SEÇÃO: CONTA / SESSÃO ──
                Padding(
                  padding: const EdgeInsets.only(left: 4.0, bottom: 8.0),
                  child: Text(
                    'Conta',
                    style: AppTheme.of(context).bodyMedium.override(
                          font: GoogleFonts.inter(
                            fontWeight: FontWeight.bold,
                          ),
                          color: AppTheme.of(context).secondaryText,
                          fontSize: 14.0,
                          letterSpacing: 0.5,
                        ),
                  ),
                ),
                Card(
                  elevation: 1.5,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                  color: AppTheme.of(context).secondaryBackground,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12.0),
                    onTap: () async {
                      final bool? confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Sair do Sistema'),
                          content: const Text(
                              'Deseja realmente encerrar a sessão e realizar o logout?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text('Cancelar'),
                            ),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red),
                              onPressed: () => Navigator.pop(ctx, true),
                              child: const Text('Sair',
                                  style: TextStyle(color: Colors.white)),
                            ),
                          ],
                        ),
                      );
                      if (confirm == true) {
                        await logoutVendedor();
                        if (context.mounted) {
                          context.goNamed(LoginPageWidget.routeName);
                        }
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16.0, vertical: 14.0),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10.0),
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10.0),
                            ),
                            child: const Icon(
                              Icons.logout_rounded,
                              color: Colors.red,
                              size: 24.0,
                            ),
                          ),
                          const SizedBox(width: 14.0),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Sair do Sistema',
                                  style:
                                      AppTheme.of(context).bodyLarge.override(
                                            font: GoogleFonts.inter(
                                              fontWeight: FontWeight.w600,
                                            ),
                                            color: Colors.red,
                                            fontSize: 15.0,
                                          ),
                                ),
                                const SizedBox(height: 2.0),
                                Text(
                                  'Encerrar sessão e voltar à tela de login',
                                  style: AppTheme.of(context)
                                      .labelMedium
                                      .override(
                                        font: GoogleFonts.inter(),
                                        color:
                                            AppTheme.of(context).secondaryText,
                                        fontSize: 13.0,
                                      ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.arrow_forward_ios_rounded,
                            color: AppTheme.of(context).secondaryText,
                            size: 16.0,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24.0),
                FutureBuilder<PackageInfo>(
                  future: PackageInfo.fromPlatform(),
                  builder: (context, snapshot) {
                    final versionText = snapshot.hasData
                        ? 'Versão: ${snapshot.data!.version}'
                        : 'Versão: Carregando...';
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 8.0, bottom: 16.0),
                        child: Text(
                          versionText,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 11.0,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                    );
                  },
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
