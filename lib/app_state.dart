import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppState extends ChangeNotifier {
  static const _vendedorCodigoKey = 'app_vendedor_codigo';
  static const _imgSyncStatusKey = 'app_imgSyncStatus';
  static const _imgSyncProgressKey = 'app_imgSyncProgress';
  static const _imgSyncTextKey = 'app_imgSyncText';
  static const _dbSyncStatusKey = 'app_dbSyncStatus';
  static const _dbSyncProgressKey = 'app_dbSyncProgress';
  static const _dbSyncTextKey = 'app_dbSyncText';
  static const _pastaDownloadKey = 'app_pastaDownload0';
  static const _pastaUploadKey = 'app_pastaUpload0';
  static const _dataHoraUltimaCargaKey = 'app_data_hora_ultima_carga';
  static const _ultimaAtualizacaoCargaKey = 'ultima_atualizacao_carga';
  static const _venEstnegKey = 'app_ven_estneg';
  static const _venSelfilKey = 'app_ven_selfil';

  static AppState _instance = AppState._internal();

  factory AppState() {
    return _instance;
  }

  AppState._internal();

  static void reset() {
    _instance = AppState._internal();
  }

  Future initializePersistedState() async {
    prefs = await SharedPreferences.getInstance();
    _safeInit(() {
      _vendedor_codigo = prefs.getInt(_vendedorCodigoKey) ?? _vendedor_codigo;
    });
    _safeInit(() {
      _imgSyncStatus = prefs.getString(_imgSyncStatusKey) ?? _imgSyncStatus;
    });
    _safeInit(() {
      _imgSyncProgress = prefs.getDouble(_imgSyncProgressKey) ??
          _imgSyncProgress;
    });
    _safeInit(() {
      _imgSyncText = prefs.getString(_imgSyncTextKey) ?? _imgSyncText;
    });
    _safeInit(() {
      _dbSyncStatus = prefs.getString(_dbSyncStatusKey) ?? _dbSyncStatus;
    });
    _safeInit(() {
      _dbSyncProgress = prefs.getDouble(_dbSyncProgressKey) ?? _dbSyncProgress;
    });
    _safeInit(() {
      _dbSyncText = prefs.getString(_dbSyncTextKey) ?? _dbSyncText;
    });
    _safeInit(() {
      _pastaDownload0 = prefs.getString(_pastaDownloadKey) ??
          _pastaDownload0;
    });
    _safeInit(() {
      _pastaUpload0 = prefs.getString(_pastaUploadKey) ?? _pastaUpload0;
    });
    _safeInit(() {
      final str = prefs.getString(_ultimaAtualizacaoCargaKey) ?? prefs.getString(_dataHoraUltimaCargaKey);
      if (str != null && str.isNotEmpty) {
        _dataHoraUltimaCarga = DateTime.tryParse(str);
      }
    });
    _safeInit(() {
      _codFilialAtiva = prefs.getInt(_codFilialAtivaKey) ?? _codFilialAtiva;
    });
    _safeInit(() {
      _filialAtivaDes = prefs.getString(_filialAtivaDesKey) ?? _filialAtivaDes;
    });
    _safeInit(() {
      _ven_chkage = prefs.getInt(_venChkageKey) ?? _ven_chkage;
    });
    _safeInit(() {
      _ven_ignlimfis = prefs.getInt(_venIgnlimfisKey) ?? _ven_ignlimfis;
    });
    _safeInit(() {
      _ven_maxitmdig = prefs.getInt(_venMaxitmdigKey) ?? _ven_maxitmdig;
    });
    _safeInit(() {
      _ven_passet = prefs.getString(_venPassetKey) ?? _ven_passet;
    });
    _safeInit(() {
      _ven_estneg = prefs.getInt(_venEstnegKey) ?? _ven_estneg;
    });
    _safeInit(() {
      _ven_selfil = prefs.getInt(_venSelfilKey) ?? _ven_selfil;
    });
  }

  void update(VoidCallback callback) {
    callback();
    notifyListeners();
  }

  late SharedPreferences prefs;

  /// DSL app state vendedor_codigo
  int _vendedor_codigo = 0;
  int get vendedor_codigo => _vendedor_codigo;
  set vendedor_codigo(int value) {
    _vendedor_codigo = value;
    prefs.setInt(_vendedorCodigoKey, value);
  }

  /// DSL app state vendedor_nome
  String _vendedor_nome = '';
  String get vendedor_nome => _vendedor_nome;
  set vendedor_nome(String value) {
    _vendedor_nome = value;
  }

  /// DSL app state vendedor_equipe (ven00_codeqp)
  int _vendedor_equipe = 0;
  int get vendedor_equipe => _vendedor_equipe;
  set vendedor_equipe(int value) {
    _vendedor_equipe = value;
  }

  /// DSL app state empresa_codigo
  String _empresa_codigo = '';
  String get empresa_codigo => _empresa_codigo;
  set empresa_codigo(String value) {
    _empresa_codigo = value;
  }

  /// DSL app state is_first_access
  bool _is_first_access = true;
  bool get is_first_access => _is_first_access;
  set is_first_access(bool value) {
    _is_first_access = value;
  }

  /// DSL app state is_loading
  bool _is_loading = false;
  bool get is_loading => _is_loading;
  set is_loading(bool value) {
    _is_loading = value;
  }

  /// DSL app state vendedor_logado_codigo
  int _vendedor_logado_codigo = 0;
  int get vendedor_logado_codigo => _vendedor_logado_codigo;
  set vendedor_logado_codigo(int value) {
    _vendedor_logado_codigo = value;
  }

  /// DSL app state vendedor_logado_nome
  String _vendedor_logado_nome = '';
  String get vendedor_logado_nome => _vendedor_logado_nome;
  set vendedor_logado_nome(String value) {
    _vendedor_logado_nome = value;
  }

  /// DSL app state pedido_numero
  int _pedido_numero = 0;
  int get pedido_numero => _pedido_numero;
  set pedido_numero(int value) {
    _pedido_numero = value;
  }

  /// DSL app state pedido_items_json
  String _pedido_items_json = '';
  String get pedido_items_json => _pedido_items_json;
  set pedido_items_json(String value) {
    _pedido_items_json = value;
  }

  /// DSL app state quantidade_item
  int _quantidade_item = 1;
  int get quantidade_item => _quantidade_item;
  set quantidade_item(int value) {
    _quantidade_item = value;
  }

  /// DSL app state produto_selecionado_codigo
  String _produto_selecionado_codigo = '';
  String get produto_selecionado_codigo => _produto_selecionado_codigo;
  set produto_selecionado_codigo(String value) {
    _produto_selecionado_codigo = value;
  }

  /// DSL app state produto_selecionado_descricao
  String _produto_selecionado_descricao = '';
  String get produto_selecionado_descricao => _produto_selecionado_descricao;
  set produto_selecionado_descricao(String value) {
    _produto_selecionado_descricao = value;
  }

  /// DSL app state produto_selecionado_preco
  double _produto_selecionado_preco = 0.0;
  double get produto_selecionado_preco => _produto_selecionado_preco;
  set produto_selecionado_preco(double value) {
    _produto_selecionado_preco = value;
  }

  /// DSL app state produto_selecionado_saldo
  double _produto_selecionado_saldo = 0.0;
  double get produto_selecionado_saldo => _produto_selecionado_saldo;
  set produto_selecionado_saldo(double value) {
    _produto_selecionado_saldo = value;
  }

  /// Controla se está parado (idle), baixando (baixando), concluído (complete)
  /// ou com erro (error).
  String _imgSyncStatus = 'idle';
  String get imgSyncStatus => _imgSyncStatus;
  set imgSyncStatus(String value) {
    _imgSyncStatus = value;
    prefs.setString(_imgSyncStatusKey, value);
  }

  /// Armazena o valor do progresso de 0.0 a 1.0 para a barra de carregamento.
  double _imgSyncProgress = 0.0;
  double get imgSyncProgress => _imgSyncProgress;
  set imgSyncProgress(double value) {
    _imgSyncProgress = value;
    prefs.setDouble(_imgSyncProgressKey, value);
  }

  /// Texto descritivo (ex: "Baixando 5 de 42...").
  String _imgSyncText = '';
  String get imgSyncText => _imgSyncText;
  set imgSyncText(String value) {
    _imgSyncText = value;
    prefs.setString(_imgSyncTextKey, value);
  }

  /// Controla o status de sincronização do banco de dados (idle, baixando, complete, error)
  String _dbSyncStatus = 'idle';
  String get dbSyncStatus => _dbSyncStatus;
  set dbSyncStatus(String value) {
    _dbSyncStatus = value;
    prefs.setString(_dbSyncStatusKey, value);
  }

  /// Progresso da sincronização de banco de dados
  double _dbSyncProgress = 0.0;
  double get dbSyncProgress => _dbSyncProgress;
  set dbSyncProgress(double value) {
    _dbSyncProgress = value;
    prefs.setDouble(_dbSyncProgressKey, value);
  }

  /// Texto descritivo do banco de dados
  String _dbSyncText = '';
  String get dbSyncText => _dbSyncText;
  set dbSyncText(String value) {
    _dbSyncText = value;
    prefs.setString(_dbSyncTextKey, value);
  }

  String _pastaDownload0 = '';
  String get pastaDownload0 => _pastaDownload0;
  set pastaDownload0(String value) {
    _pastaDownload0 = value;
    prefs.setString(_pastaDownloadKey, value);
  }

  String _pastaUpload0 = '';
  String get pastaUpload0 => _pastaUpload0;
  set pastaUpload0(String value) {
    _pastaUpload0 = value;
    prefs.setString(_pastaUploadKey, value);
  }

  /// PRD B4 — ven00_chkest (controla validação de estoque)
  int _ven_chkest = 1;
  int get ven_chkest => _ven_chkest;
  set ven_chkest(int value) {
    _ven_chkest = value;
  }

  /// PRD C3 — ven00_gerbonfor (permite bonificação força de venda)
  int _ven_gerbonfor = 0;
  int get ven_gerbonfor => _ven_gerbonfor;
  set ven_gerbonfor(int value) {
    _ven_gerbonfor = value;
  }

  /// PRD 1 §1.5 — filial ativa selecionada no login quando count(cadfil00) > 1
  static const _codFilialAtivaKey = 'app_cod_filial_ativa';
  static const _filialAtivaDesKey = 'app_filial_ativa_des';
  static const _venChkageKey = 'app_ven_chkage';
  static const _venIgnlimfisKey = 'app_ven_ignlimfis';
  static const _venMaxitmdigKey = 'app_ven_maxitmdig';
  static const _venPassetKey = 'app_ven_passet';

  int _codFilialAtiva = 0;
  int get codFilialAtiva => _codFilialAtiva;
  set codFilialAtiva(int value) {
    _codFilialAtiva = value;
    try { prefs.setInt(_codFilialAtivaKey, value); } catch (_) {}
    notifyListeners();
  }

  /// Alias de conveniência para filial ativa
  int get filialAtiva => _codFilialAtiva;
  set filialAtiva(int value) {
    codFilialAtiva = value;
  }

  String _filialAtivaDes = '';
  String get filialAtivaDes => _filialAtivaDes;
  set filialAtivaDes(String value) {
    _filialAtivaDes = value;
    try { prefs.setString(_filialAtivaDesKey, value); } catch (_) {}
    notifyListeners();
  }

  /// ven00_chkage (obrigatoriedade de agente cobrador)
  int _ven_chkage = 0;
  int get ven_chkage => _ven_chkage;
  set ven_chkage(int value) {
    _ven_chkage = value;
    try { prefs.setInt(_venChkageKey, value); } catch (_) {}
    notifyListeners();
  }

  /// ven00_ignlimfis (permissão para ignorar limite de crédito)
  int _ven_ignlimfis = 0;
  int get ven_ignlimfis => _ven_ignlimfis;
  set ven_ignlimfis(int value) {
    _ven_ignlimfis = value;
    try { prefs.setInt(_venIgnlimfisKey, value); } catch (_) {}
    notifyListeners();
  }

  /// ven00_maxitmdig (teto máximo de itens por pedido)
  int _ven_maxitmdig = 0;
  int get ven_maxitmdig => _ven_maxitmdig;
  set ven_maxitmdig(int value) {
    _ven_maxitmdig = value;
    try { prefs.setInt(_venMaxitmdigKey, value); } catch (_) {}
    notifyListeners();
  }

  /// ven00_passet (senha de supervisor para desbloqueio)
  String _ven_passet = '';
  String get ven_passet => _ven_passet;
  set ven_passet(String value) {
    _ven_passet = value;
    try { prefs.setString(_venPassetKey, value); } catch (_) {}
    notifyListeners();
  }

  /// ven00_estneg (permissão para venda de estoque negativo: 1 = permite, 0 = bloqueia)
  int _ven_estneg = 0;
  int get ven_estneg => _ven_estneg;
  set ven_estneg(int value) {
    _ven_estneg = value;
    try { prefs.setInt(_venEstnegKey, value); } catch (_) {}
    notifyListeners();
  }

  /// ven00_selfil (permissão para selecionar filial: 1 = permite, 0 = bloqueia)
  int _ven_selfil = 0;
  int get ven_selfil => _ven_selfil;
  set ven_selfil(int value) {
    _ven_selfil = value;
    try { prefs.setInt(_venSelfilKey, value); } catch (_) {}
    notifyListeners();
  }

  /// Data e hora da última carga recebida com sucesso (fcfGETCRG = 3)
  DateTime? _dataHoraUltimaCarga;
  DateTime? get dataHoraUltimaCarga => _dataHoraUltimaCarga;
  set dataHoraUltimaCarga(DateTime? value) {
    _dataHoraUltimaCarga = value;
    try {
      if (value != null) {
        prefs.setString(_dataHoraUltimaCargaKey, value.toIso8601String());
        prefs.setString(_ultimaAtualizacaoCargaKey, value.toIso8601String());
      } else {
        prefs.remove(_dataHoraUltimaCargaKey);
        prefs.remove(_ultimaAtualizacaoCargaKey);
      }
    } catch (_) {}
    notifyListeners();
  }

  String get dataHoraUltimaCargaFormatada {
    if (_dataHoraUltimaCarga == null) {
      return 'Última atualização: Não realizada';
    }
    final dt = _dataHoraUltimaCarga!;
    final d = dt.day.toString().padLeft(2, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final y = dt.year.toString();
    final h = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return 'Última atualização: $d/$m/$y às $h:$min';
  }
}

void _safeInit(Function() initializeField) {
  try {
    initializeField();
  } catch (_) {}
}
