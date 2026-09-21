import '/components/botao_menu_home/botao_menu_home_widget.dart';
import '/components/modal_cliente/modal_cliente_widget.dart';
import '/components/modal_pedidos/modal_pedidos_widget.dart';
import '/components/modal_relatorios/modal_relatorios_widget.dart';
import '/core/app_theme.dart';
import '/core/app_util.dart';
import '/index.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '/services/filial_service.dart';
import '/components/modal_selecao_filial/modal_selecao_filial_widget.dart';
import '/data/services/local_sales_database_service.dart';
import 'home_page_model.dart';
export 'home_page_model.dart';

class HomePageWidget extends StatefulWidget {
  const HomePageWidget({super.key});

  static String routeName = 'HomePage';
  static String routePath = '/homePage';

  @override
  State<HomePageWidget> createState() => _HomePageWidgetState();
}

class _HomePageWidgetState extends State<HomePageWidget> {
  late HomePageModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => HomePageModel());
  }

  @override
  void dispose() {
    _model.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    context.watch<AppState>();

    return GestureDetector(
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
          title: Text(
            'SWR - Força de Vendas',
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
          actions: [
            if (AppState().codFilialAtiva > 0)
              Padding(
                padding: const EdgeInsets.only(right: 12.0),
                child: Center(
                  child: InkWell(
                    onTap: () async {
                      if (AppState().ven_selfil == 1) {
                        final db = await LocalSalesDatabaseService.getDatabase(
                            readOnly: true);
                        final filiaisEstoque =
                            await FilialService.obterFiliaisDistintasEstoque(
                                db);
                        if (filiaisEstoque.length > 1) {
                          final filiais =
                              await FilialService.obterFiliaisComDescricao(
                                  db, filiaisEstoque);
                          if (context.mounted) {
                            final result = await showModalBottomSheet<String>(
                              isScrollControlled: true,
                              useSafeArea: true,
                              backgroundColor: Colors.transparent,
                              context: context,
                              builder: (context) => SafeArea(
                                bottom: true,
                                child: ModalSelecaoFilialWidget(
                                  filiais: filiais,
                                ),
                              ),
                            );
                            if (result != null) {
                              final cod = int.tryParse(result);
                              if (cod != null) {
                                AppState().codFilialAtiva = cod;
                                final desc = filiais
                                    .firstWhere((f) => f.codigo == result)
                                    .descricao;
                                AppState().filialAtivaDes = desc;
                              }
                            }
                          }
                        }
                      }
                    },
                    borderRadius: BorderRadius.circular(6.0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8.0, vertical: 4.0),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6.0),
                      ),
                      child: Text(
                        'Filial: ${AppState().codFilialAtiva.toString().padLeft(2, '0')}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12.0,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
          centerTitle: true,
          elevation: 2.0,
        ),
        body: SafeArea(
          top: true,
          child: Column(
            mainAxisSize: MainAxisSize.max,
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Container(
                  width: double.infinity,
                  height: 72.0,
                  decoration: const BoxDecoration(),
                  child: Column(
                    mainAxisSize: MainAxisSize.max,
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Painel Administrativo',
                        style: AppTheme.of(context).bodyMedium.override(
                              font: GoogleFonts.inter(
                                fontWeight: FontWeight.w600,
                                fontStyle:
                                    AppTheme.of(context).bodyMedium.fontStyle,
                              ),
                              fontSize: 24.0,
                              letterSpacing: 0.0,
                              fontWeight: FontWeight.w600,
                              fontStyle:
                                  AppTheme.of(context).bodyMedium.fontStyle,
                            ),
                      ),
                      Text(
                        'Bem vindo, ${AppState().vendedor_nome}',
                        style: AppTheme.of(context).bodyMedium.override(
                              font: GoogleFonts.inter(
                                fontWeight: FontWeight.w500,
                                fontStyle:
                                    AppTheme.of(context).bodyMedium.fontStyle,
                              ),
                              color: AppTheme.of(context).secondaryText,
                              fontSize: 16.0,
                              letterSpacing: 0.0,
                              fontWeight: FontWeight.w500,
                              fontStyle:
                                  AppTheme.of(context).bodyMedium.fontStyle,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(),
                  child: SingleChildScrollView(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 600.0),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.max,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.max,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Expanded(
                                    child: InkWell(
                                      splashColor: Colors.transparent,
                                      focusColor: Colors.transparent,
                                      hoverColor: Colors.transparent,
                                      highlightColor: Colors.transparent,
                                      onTap: () async {
                                        await showModalBottomSheet(
                                          isScrollControlled: true,
                                          useSafeArea: true,
                                          backgroundColor: Colors.transparent,
                                          context: context,
                                          builder: (context) {
                                            return GestureDetector(
                                              onTap: () {
                                                FocusScope.of(context)
                                                    .unfocus();
                                                FocusManager
                                                    .instance.primaryFocus
                                                    ?.unfocus();
                                              },
                                              child: Padding(
                                                padding:
                                                    MediaQuery.viewInsetsOf(
                                                        context),
                                                child:
                                                    const ModalPedidosWidget(),
                                              ),
                                            );
                                          },
                                        ).then((value) => safeSetState(() {}));
                                      },
                                      child: wrapWithModel(
                                        model: _model.botaoMenuHomeModel1,
                                        updateCallback: () =>
                                            safeSetState(() {}),
                                        child: BotaoMenuHomeWidget(
                                          description: 'Pedidos',
                                          icon: Icon(
                                            Icons.shopping_cart_outlined,
                                            color: AppTheme.of(context).primary,
                                            size: 32.0,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: InkWell(
                                      splashColor: Colors.transparent,
                                      focusColor: Colors.transparent,
                                      hoverColor: Colors.transparent,
                                      highlightColor: Colors.transparent,
                                      onTap: () async {
                                        await showModalBottomSheet(
                                          isScrollControlled: true,
                                          useSafeArea: true,
                                          backgroundColor: Colors.transparent,
                                          context: context,
                                          builder: (context) {
                                            return GestureDetector(
                                              onTap: () {
                                                FocusScope.of(context)
                                                    .unfocus();
                                                FocusManager
                                                    .instance.primaryFocus
                                                    ?.unfocus();
                                              },
                                              child: Padding(
                                                padding:
                                                    MediaQuery.viewInsetsOf(
                                                        context),
                                                child:
                                                    const ModalClienteWidget(),
                                              ),
                                            );
                                          },
                                        ).then((value) => safeSetState(() {}));
                                      },
                                      child: wrapWithModel(
                                        model: _model.botaoMenuHomeModel2,
                                        updateCallback: () =>
                                            safeSetState(() {}),
                                        child: BotaoMenuHomeWidget(
                                          description: 'Clientes',
                                          icon: Icon(
                                            Icons.people_outline_rounded,
                                            color: AppTheme.of(context).primary,
                                            size: 32.0,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ].divide(const SizedBox(width: 16.0)),
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.max,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Expanded(
                                    child: InkWell(
                                      splashColor: Colors.transparent,
                                      focusColor: Colors.transparent,
                                      hoverColor: Colors.transparent,
                                      highlightColor: Colors.transparent,
                                      onTap: () async {
                                        context.pushNamed(
                                            BuscaProdutoPageWidget.routeName);
                                      },
                                      child: wrapWithModel(
                                        model: _model.botaoMenuHomeModel3,
                                        updateCallback: () =>
                                            safeSetState(() {}),
                                        child: BotaoMenuHomeWidget(
                                          description: 'Produtos',
                                          icon: Icon(
                                            Icons.storage_rounded,
                                            color: AppTheme.of(context).primary,
                                            size: 32.0,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: InkWell(
                                      splashColor: Colors.transparent,
                                      focusColor: Colors.transparent,
                                      hoverColor: Colors.transparent,
                                      highlightColor: Colors.transparent,
                                      onTap: () async {
                                        context.pushNamed(
                                            ReceberPageWidget.routeName);
                                      },
                                      child: wrapWithModel(
                                        model: _model.botaoMenuHomeModel6,
                                        updateCallback: () =>
                                            safeSetState(() {}),
                                        child: BotaoMenuHomeWidget(
                                          description: 'Receber',
                                          icon: Icon(
                                            Icons.receipt_long_rounded,
                                            color: AppTheme.of(context).primary,
                                            size: 32.0,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ].divide(const SizedBox(width: 16.0)),
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.max,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Expanded(
                                    child: InkWell(
                                      splashColor: Colors.transparent,
                                      focusColor: Colors.transparent,
                                      hoverColor: Colors.transparent,
                                      highlightColor: Colors.transparent,
                                      onTap: () async {
                                        await showModalBottomSheet(
                                          isScrollControlled: true,
                                          useSafeArea: true,
                                          backgroundColor: Colors.transparent,
                                          context: context,
                                          builder: (context) {
                                            return GestureDetector(
                                              onTap: () {
                                                FocusScope.of(context)
                                                    .unfocus();
                                                FocusManager
                                                    .instance.primaryFocus
                                                    ?.unfocus();
                                              },
                                              child: Padding(
                                                padding:
                                                    MediaQuery.viewInsetsOf(
                                                        context),
                                                child:
                                                    const ModalRelatoriosWidget(),
                                              ),
                                            );
                                          },
                                        ).then((value) => safeSetState(() {}));
                                      },
                                      child: wrapWithModel(
                                        model: _model.botaoMenuHomeModel5,
                                        updateCallback: () =>
                                            safeSetState(() {}),
                                        child: BotaoMenuHomeWidget(
                                          description: 'Relatórios',
                                          icon: Icon(
                                            Icons.analytics_outlined,
                                            color: AppTheme.of(context).primary,
                                            size: 32.0,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: InkWell(
                                      splashColor: Colors.transparent,
                                      focusColor: Colors.transparent,
                                      hoverColor: Colors.transparent,
                                      highlightColor: Colors.transparent,
                                      onTap: () async {
                                        context.pushNamed(
                                            FerramentasPageWidget.routeName);
                                      },
                                      child: wrapWithModel(
                                        model: _model.botaoMenuHomeModel4,
                                        updateCallback: () =>
                                            safeSetState(() {}),
                                        child: BotaoMenuHomeWidget(
                                          description: 'Ferramentas',
                                          icon: Icon(
                                            Icons.tune_rounded,
                                            color: AppTheme.of(context).primary,
                                            size: 32.0,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ].divide(const SizedBox(width: 16.0)),
                              ),
                            ].divide(const SizedBox(height: 16.0)),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              // Rodapé: Data e Hora da Última Carga (abaixo dos botões do menu e protegido por SafeArea(bottom: true))
              SafeArea(
                bottom: true,
                top: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      vertical: 10.0, horizontal: 16.0),
                  child: Center(
                    child: Text(
                      AppState().dataHoraUltimaCargaFormatada,
                      textAlign: TextAlign.center,
                      style: AppTheme.of(context).bodySmall.override(
                            font: GoogleFonts.inter(
                              fontWeight: FontWeight.w500,
                            ),
                            color: AppTheme.of(context).secondaryText,
                            fontSize: 12.0,
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
}
