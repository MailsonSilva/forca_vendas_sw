import 'dart:async';
import 'package:flutter/material.dart';
import '/core/app_theme.dart';
import '/core/app_util.dart';
import '/pages/home_page/home_page_widget.dart';
import '/services/ftp_upload_service.dart';
import '/services/nav_bar_service.dart';
import '/action_code/enviar_arquivos_pendentes_ftp.dart';

/// Tela de Envio de Cargas e Comunicação FTP (ffrmcom00 / EnvioPage)
///
/// Implementa SPEC-056:
/// - Upload do arquivo p<codrep>-<ipac>.pac
/// - Diálogo modal bloqueante com PopScope canPop: false
/// - Polling remoto a cada 5s com timeout de 60s
/// - Atualização dos pedidos locais para dig00_sttenv = 3 ao confirmar
/// - Retorno seguro ao Menu Principal (Home)
class EnvioPageWidget extends StatefulWidget {
  const EnvioPageWidget({
    super.key,
    this.nomePacote,
    this.sequencialPacote,
  });

  static String routeName = 'EnvioPage';
  static String routePath = '/envioPage';

  final String? nomePacote;
  final int? sequencialPacote;

  @override
  State<EnvioPageWidget> createState() => _EnvioPageWidgetState();
}

/// Alias para conformidade com a especificação técnica legada ffrmcom00
typedef Ffrmcom00Widget = EnvioPageWidget;

class _EnvioPageWidgetState extends State<EnvioPageWidget> {
  bool _enviando = false;
  bool _aguardandoRetorno = false;
  String _statusMensagem = '';
  int _segundosRestantes = 60;
  Timer? _timerRegressivo;

  @override
  void dispose() {
    _timerRegressivo?.cancel();
    super.dispose();
  }

  Future<void> _iniciarEnvioEHandshake() async {
    if (_enviando || _aguardandoRetorno) return;

    safeSetState(() {
      _enviando = true;
      _aguardandoRetorno = true;
      _statusMensagem = 'Enviando lote... Aguardando processamento da retaguarda';
      _segundosRestantes = 60;
    });

    // Inicia contagem regressiva para feedback ao vendedor
    _timerRegressivo?.cancel();
    _timerRegressivo = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_segundosRestantes > 0) {
        if (mounted) safeSetState(() => _segundosRestantes--);
      } else {
        t.cancel();
      }
    });

    // Exibe diálogo modal bloqueante
    _exibirModalBloqueante();

    try {
      final String empresa = AppState().empresa_codigo.trim().isEmpty
          ? 'diniz'
          : AppState().empresa_codigo.trim();
      final int codRep = AppState().vendedor_codigo > 0 ? AppState().vendedor_codigo : 71;
      final int codigoEquipe = AppState().vendedor_equipe > 0 ? AppState().vendedor_equipe : codRep;

      // Extrai número do pacote do nome (ex: p71-1001.pac -> 1001)
      int seqPac = widget.sequencialPacote ?? 0;
      if (seqPac <= 0 && widget.nomePacote != null) {
        final digits = RegExp(r'-(\d+)').firstMatch(widget.nomePacote!);
        if (digits != null) {
          seqPac = int.tryParse(digits.group(1) ?? '') ?? 0;
        }
      }

      // Passo 1: Upload dos pacotes pendentes
      final uploadResult = await enviarArquivosPendentesFtp(
        enviarPedidos: true,
        enviarClientes: true,
        arquivosSelecionados: widget.nomePacote != null ? [widget.nomePacote!] : null,
      );

      if (!uploadResult.success) {
        _fecharModalSeAberto();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Falha no upload: ${uploadResult.message}'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // Passo 3: Polling de retorno da retaguarda ERP
      safeSetState(() {
        _statusMensagem = 'Lote enviado! Aguardando processamento da retaguarda...';
      });

      final uploadService = FtpUploadService();
      final pollingResult = await uploadService.aguardarRetornoPacote(
        empresa: empresa,
        codigoEquipe: codigoEquipe,
        codRep: codRep,
        ipac: seqPac > 0 ? seqPac : 1000,
        intervalo: const Duration(seconds: 5),
        timeout: const Duration(seconds: 60),
        onPoll: (tentativa, msg) {
          if (mounted) {
            safeSetState(() {
              _statusMensagem = '$msg (${_segundosRestantes}s)';
            });
          }
        },
      );

      _fecharModalSeAberto();

      // Passo 4: Finalização e navegação segura
      if (pollingResult.isConfirmado) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Lote processado e confirmado com sucesso pela retaguarda!'),
            backgroundColor: Color(0xFF2E7D32),
            duration: Duration(seconds: 4),
          ),
        );

        // Retorna ao Menu Principal (Home)
        NavBarService().navegarParaHome();
        try {
          context.goNamed(HomePageWidget.routeName);
        } catch (_) {}
      } else if (pollingResult.isTimeout) {
        if (!mounted) return;
        await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            icon: const Icon(Icons.info_outline_rounded, color: Colors.orange, size: 48.0),
            title: const Text('Aguardando Retaguarda'),
            content: const Text(
              'Lote enviado, aguardando confirmação da retaguarda em segundo plano.\n\n'
              'Você pode continuar suas atividades. O status será atualizado na próxima sincronização.',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  NavBarService().navegarParaHome();
                  try {
                    context.goNamed(HomePageWidget.routeName);
                  } catch (_) {}
                },
                child: const Text('OK, Voltar ao Menu'),
              ),
            ],
          ),
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(pollingResult.mensagem),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      _fecharModalSeAberto();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro na transmissão: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      _timerRegressivo?.cancel();
      if (mounted) {
        safeSetState(() {
          _enviando = false;
          _aguardandoRetorno = false;
        });
      }
    }
  }

  void _exibirModalBloqueante() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14.0)),
              title: const Row(
                children: [
                  Icon(Icons.sync_rounded, color: Color(0xFF0284C7)),
                  SizedBox(width: 10.0),
                  Text('Transmissão FTP'),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 12.0),
                  const CircularProgressIndicator(
                    strokeWidth: 3.5,
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0284C7)),
                  ),
                  const SizedBox(height: 20.0),
                  Text(
                    _statusMensagem,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14.0,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8.0),
                  Text(
                    'Tempo limite de espera: ${_segundosRestantes}s',
                    style: const TextStyle(fontSize: 12.0, color: Colors.grey),
                  ),
                  const SizedBox(height: 12.0),
                  const Text(
                    'Por favor, não saia desta tela até a conclusão do handshake com a retaguarda.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11.0, color: Colors.black54),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  void _fecharModalSeAberto() {
    if (Navigator.of(context, rootNavigator: true).canPop()) {
      Navigator.of(context, rootNavigator: true).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool bloqueado = _enviando || _aguardandoRetorno;

    return PopScope(
      canPop: !bloqueado,
      child: Scaffold(
        backgroundColor: AppTheme.of(context).primaryBackground,
        appBar: AppBar(
          backgroundColor: AppTheme.of(context).primary,
          automaticallyImplyLeading: !bloqueado,
          title: Text(
            'Comunicação FTP (ffrmcom00)',
            style: AppTheme.of(context).titleMedium.override(
                  font: const TextStyle(
                    fontWeight: FontWeight.w600,
                  ),
                  color: Colors.white,
                  fontSize: 18.0,
                ),
          ),
          centerTitle: false,
          elevation: 2.0,
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(16.0),
                  decoration: BoxDecoration(
                    color: AppTheme.of(context).secondaryBackground,
                    borderRadius: BorderRadius.circular(12.0),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 4.0,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.inventory_2_outlined, color: AppTheme.of(context).primary),
                          const SizedBox(width: 8.0),
                          Text(
                            widget.nomePacote != null
                                ? 'Pacote: ${widget.nomePacote}'
                                : 'Envio de Lotes e Pacotes Pendentes',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16.0),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10.0),
                      Text(
                        'O envio enviará o arquivo para o diretório remoto do FTP e aguardará '
                        'a confirmação do ERP com polling a cada 5 segundos.',
                        style: TextStyle(color: AppTheme.of(context).secondaryText, fontSize: 13.0),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: bloqueado ? null : _iniciarEnvioEHandshake,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0284C7),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16.0),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10.0),
                    ),
                  ),
                  icon: const Icon(Icons.cloud_upload_rounded),
                  label: Text(
                    bloqueado ? 'Aguardando Handshake...' : 'Transmitir e Aguardar Retorno',
                    style: const TextStyle(fontSize: 16.0, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 16.0),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
