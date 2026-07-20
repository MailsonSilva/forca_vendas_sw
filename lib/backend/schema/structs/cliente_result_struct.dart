// ignore_for_file: unnecessary_getters_setters

import '/backend/schema/util/schema_util.dart';

import 'index.dart';
import '/core/app_util.dart';

/// DSL struct ClienteResult
class ClienteResultStruct extends BaseStruct {
  ClienteResultStruct({
    String? uuid,

    /// ClienteResult.success
    bool? success,

    /// ClienteResult.message
    String? message,

    /// ClienteResult.codigo
    int? cli00Codigo,

    /// ClienteResult.nome
    String? cli00Descri,
    String? cli00Fantas,

    /// ClienteResult.endereco
    String? cli00Endere,

    /// ClienteResult.numero
    String? cli00Endnum,

    /// ClienteResult.bairro
    String? cli00Bairro,
    int? cli00Cidcod,
    String? cli00Ciddes,
    int? cli00Estcod,
    String? cli00Estsgl,

    /// ClienteResult.cep
    String? cli00Endcep,
    String? cli00Fonddd,

    /// ClienteResult.telefone
    String? cli00Fonnum,

    /// ClienteResult.cpfCnpj
    String? cli00Cpfcnp,

    /// ClienteResult.ie
    String? cli00Insest,
    DateTime? cli00Datcad,
    DateTime? cli00Datcom,
    int? cli00Active,
    String? cli00Observ,
    double? cli00Crelim,
    double? cli00Creatu,

    /// ClienteResult.tipo
    String? cli00Pessoa,
    int? cli00Typpes,
    String? cli00Contat,
    int? cli00Codram,
    String? ram00descri,
    DateTime? cli00Datfun,
    int? cli00Codrep,
    int? cli00Codsup,
    double? cli00Titven,
    double? cli00Titave,
    double? cli00Ttlrec,
    int? cli00Flgven,
    int? cli00Codage,
    int? cli00Deffidcod,
    int? cli00Typpco,
    int? cli00Codreg,
    int? cli00Fattotign,
    int? cli00Vengerntf,
    Color? corBorda,
    bool? isNovoCliente,
    bool? isModificado,
    String? situacaoFinanceira,
    double? saldoCredito,
    String? cli02NProp,
    String? cli02EndProp,
    String? cli02NumProp,
    String? cli02BairroProp,
    String? cli02CidadeProp,
    String? cli02UfProp,
    String? cli02NRGProp,
    String? cli02OrgaoProp,
    String? cli02CpfProp,
    String? cli02ConjugeProp,
    String? cli02NRGConjProp,
    String? cli02OrgaoConjProp,
    String? cli02CpfConjProp,
    List<BancoInfoStructStruct>? bancosList,
  })  : _uuid = uuid,
        _success = success,
        _message = message,
        _cli00Codigo = cli00Codigo,
        _cli00Descri = cli00Descri,
        _cli00Fantas = cli00Fantas,
        _cli00Endere = cli00Endere,
        _cli00Endnum = cli00Endnum,
        _cli00Bairro = cli00Bairro,
        _cli00Cidcod = cli00Cidcod,
        _cli00Ciddes = cli00Ciddes,
        _cli00Estcod = cli00Estcod,
        _cli00Estsgl = cli00Estsgl,
        _cli00Endcep = cli00Endcep,
        _cli00Fonddd = cli00Fonddd,
        _cli00Fonnum = cli00Fonnum,
        _cli00Cpfcnp = cli00Cpfcnp,
        _cli00Insest = cli00Insest,
        _cli00Datcad = cli00Datcad,
        _cli00Datcom = cli00Datcom,
        _cli00Active = cli00Active,
        _cli00Observ = cli00Observ,
        _cli00Crelim = cli00Crelim,
        _cli00Creatu = cli00Creatu,
        _cli00Pessoa = cli00Pessoa,
        _cli00Typpes = cli00Typpes,
        _cli00Contat = cli00Contat,
        _cli00Codram = cli00Codram,
        _ram00descri = ram00descri,
        _cli00Datfun = cli00Datfun,
        _cli00Codrep = cli00Codrep,
        _cli00Codsup = cli00Codsup,
        _cli00Titven = cli00Titven,
        _cli00Titave = cli00Titave,
        _cli00Ttlrec = cli00Ttlrec,
        _cli00Flgven = cli00Flgven,
        _cli00Codage = cli00Codage,
        _cli00Deffidcod = cli00Deffidcod,
        _cli00Typpco = cli00Typpco,
        _cli00Codreg = cli00Codreg,
        _cli00Fattotign = cli00Fattotign,
        _cli00Vengerntf = cli00Vengerntf,
        _corBorda = corBorda,
        _isNovoCliente = isNovoCliente,
        _isModificado = isModificado,
        _situacaoFinanceira = situacaoFinanceira,
        _saldoCredito = saldoCredito,
        _cli02NProp = cli02NProp,
        _cli02EndProp = cli02EndProp,
        _cli02NumProp = cli02NumProp,
        _cli02BairroProp = cli02BairroProp,
        _cli02CidadeProp = cli02CidadeProp,
        _cli02UfProp = cli02UfProp,
        _cli02NRGProp = cli02NRGProp,
        _cli02OrgaoProp = cli02OrgaoProp,
        _cli02CpfProp = cli02CpfProp,
        _cli02ConjugeProp = cli02ConjugeProp,
        _cli02NRGConjProp = cli02NRGConjProp,
        _cli02OrgaoConjProp = cli02OrgaoConjProp,
        _cli02CpfConjProp = cli02CpfConjProp,
        _bancosList = bancosList;

  // "uuid" field.
  String? _uuid;
  String get uuid => _uuid ?? '';
  set uuid(String? val) => _uuid = val;

  bool hasUuid() => _uuid != null;

  // "success" field.
  bool? _success;
  bool get success => _success ?? false;
  set success(bool? val) => _success = val;

  bool hasSuccess() => _success != null;

  // "message" field.
  String? _message;
  String get message => _message ?? '';
  set message(String? val) => _message = val;

  bool hasMessage() => _message != null;

  // "cli00Codigo" field.
  int? _cli00Codigo;
  int get cli00Codigo => _cli00Codigo ?? 0;
  set cli00Codigo(int? val) => _cli00Codigo = val;

  void incrementCli00Codigo(int amount) => cli00Codigo = cli00Codigo + amount;

  bool hasCli00Codigo() => _cli00Codigo != null;

  // "cli00Descri" field.
  String? _cli00Descri;
  String get cli00Descri => _cli00Descri ?? '';
  set cli00Descri(String? val) => _cli00Descri = val;

  bool hasCli00Descri() => _cli00Descri != null;

  // "cli00Fantas" field.
  String? _cli00Fantas;
  String get cli00Fantas => _cli00Fantas ?? '';
  set cli00Fantas(String? val) => _cli00Fantas = val;

  bool hasCli00Fantas() => _cli00Fantas != null;

  // "cli00Endere" field.
  String? _cli00Endere;
  String get cli00Endere => _cli00Endere ?? '';
  set cli00Endere(String? val) => _cli00Endere = val;

  bool hasCli00Endere() => _cli00Endere != null;

  // "cli00Endnum" field.
  String? _cli00Endnum;
  String get cli00Endnum => _cli00Endnum ?? '';
  set cli00Endnum(String? val) => _cli00Endnum = val;

  bool hasCli00Endnum() => _cli00Endnum != null;

  // "cli00Bairro" field.
  String? _cli00Bairro;
  String get cli00Bairro => _cli00Bairro ?? '';
  set cli00Bairro(String? val) => _cli00Bairro = val;

  bool hasCli00Bairro() => _cli00Bairro != null;

  // "cli00Cidcod" field.
  int? _cli00Cidcod;
  int get cli00Cidcod => _cli00Cidcod ?? 0;
  set cli00Cidcod(int? val) => _cli00Cidcod = val;

  void incrementCli00Cidcod(int amount) => cli00Cidcod = cli00Cidcod + amount;

  bool hasCli00Cidcod() => _cli00Cidcod != null;

  // "cli00Ciddes" field.
  String? _cli00Ciddes;
  String get cli00Ciddes => _cli00Ciddes ?? '';
  set cli00Ciddes(String? val) => _cli00Ciddes = val;

  bool hasCli00Ciddes() => _cli00Ciddes != null;

  // "cli00Estcod" field.
  int? _cli00Estcod;
  int get cli00Estcod => _cli00Estcod ?? 0;
  set cli00Estcod(int? val) => _cli00Estcod = val;

  void incrementCli00Estcod(int amount) => cli00Estcod = cli00Estcod + amount;

  bool hasCli00Estcod() => _cli00Estcod != null;

  // "cli00Estsgl" field.
  String? _cli00Estsgl;
  String get cli00Estsgl => _cli00Estsgl ?? '';
  set cli00Estsgl(String? val) => _cli00Estsgl = val;

  bool hasCli00Estsgl() => _cli00Estsgl != null;

  // "cli00Endcep" field.
  String? _cli00Endcep;
  String get cli00Endcep => _cli00Endcep ?? '';
  set cli00Endcep(String? val) => _cli00Endcep = val;

  bool hasCli00Endcep() => _cli00Endcep != null;

  // "cli00Fonddd" field.
  String? _cli00Fonddd;
  String get cli00Fonddd => _cli00Fonddd ?? '';
  set cli00Fonddd(String? val) => _cli00Fonddd = val;

  bool hasCli00Fonddd() => _cli00Fonddd != null;

  // "cli00Fonnum" field.
  String? _cli00Fonnum;
  String get cli00Fonnum => _cli00Fonnum ?? '';
  set cli00Fonnum(String? val) => _cli00Fonnum = val;

  bool hasCli00Fonnum() => _cli00Fonnum != null;

  // "cli00Cpfcnp" field.
  String? _cli00Cpfcnp;
  String get cli00Cpfcnp => _cli00Cpfcnp ?? '';
  set cli00Cpfcnp(String? val) => _cli00Cpfcnp = val;

  bool hasCli00Cpfcnp() => _cli00Cpfcnp != null;

  // "cli00Insest" field.
  String? _cli00Insest;
  String get cli00Insest => _cli00Insest ?? '';
  set cli00Insest(String? val) => _cli00Insest = val;

  bool hasCli00Insest() => _cli00Insest != null;

  // "cli00Datcad" field.
  DateTime? _cli00Datcad;
  DateTime? get cli00Datcad => _cli00Datcad;
  set cli00Datcad(DateTime? val) => _cli00Datcad = val;

  bool hasCli00Datcad() => _cli00Datcad != null;

  // "cli00Datcom" field.
  DateTime? _cli00Datcom;
  DateTime? get cli00Datcom => _cli00Datcom;
  set cli00Datcom(DateTime? val) => _cli00Datcom = val;

  bool hasCli00Datcom() => _cli00Datcom != null;

  // "cli00Active" field.
  int? _cli00Active;
  int get cli00Active => _cli00Active ?? 0;
  set cli00Active(int? val) => _cli00Active = val;

  void incrementCli00Active(int amount) => cli00Active = cli00Active + amount;

  bool hasCli00Active() => _cli00Active != null;

  // "cli00Observ" field.
  String? _cli00Observ;
  String get cli00Observ => _cli00Observ ?? '';
  set cli00Observ(String? val) => _cli00Observ = val;

  bool hasCli00Observ() => _cli00Observ != null;

  // "cli00Crelim" field.
  double? _cli00Crelim;
  double get cli00Crelim => _cli00Crelim ?? 0.0;
  set cli00Crelim(double? val) => _cli00Crelim = val;

  void incrementCli00Crelim(double amount) =>
      cli00Crelim = cli00Crelim + amount;

  bool hasCli00Crelim() => _cli00Crelim != null;

  // "cli00Creatu" field.
  double? _cli00Creatu;
  double get cli00Creatu => _cli00Creatu ?? 0.0;
  set cli00Creatu(double? val) => _cli00Creatu = val;

  void incrementCli00Creatu(double amount) =>
      cli00Creatu = cli00Creatu + amount;

  bool hasCli00Creatu() => _cli00Creatu != null;

  // "cli00Pessoa" field.
  String? _cli00Pessoa;
  String get cli00Pessoa => _cli00Pessoa ?? '';
  set cli00Pessoa(String? val) => _cli00Pessoa = val;

  bool hasCli00Pessoa() => _cli00Pessoa != null;

  // "cli00Typpes" field.
  int? _cli00Typpes;
  int get cli00Typpes => _cli00Typpes ?? 0;
  set cli00Typpes(int? val) => _cli00Typpes = val;

  void incrementCli00Typpes(int amount) => cli00Typpes = cli00Typpes + amount;

  bool hasCli00Typpes() => _cli00Typpes != null;

  // "cli00Contat" field.
  String? _cli00Contat;
  String get cli00Contat => _cli00Contat ?? '';
  set cli00Contat(String? val) => _cli00Contat = val;

  bool hasCli00Contat() => _cli00Contat != null;

  // "cli00Codram" field.
  int? _cli00Codram;
  int get cli00Codram => _cli00Codram ?? 0;
  set cli00Codram(int? val) => _cli00Codram = val;

  void incrementCli00Codram(int amount) => cli00Codram = cli00Codram + amount;

  bool hasCli00Codram() => _cli00Codram != null;

  // "ram00descri" field.
  String? _ram00descri;
  String get ram00descri => _ram00descri ?? '';
  set ram00descri(String? val) => _ram00descri = val;

  bool hasRam00descri() => _ram00descri != null;

  // "cli00Datfun" field.
  DateTime? _cli00Datfun;
  DateTime? get cli00Datfun => _cli00Datfun;
  set cli00Datfun(DateTime? val) => _cli00Datfun = val;

  bool hasCli00Datfun() => _cli00Datfun != null;

  // "cli00Codrep" field.
  int? _cli00Codrep;
  int get cli00Codrep => _cli00Codrep ?? 0;
  set cli00Codrep(int? val) => _cli00Codrep = val;

  void incrementCli00Codrep(int amount) => cli00Codrep = cli00Codrep + amount;

  bool hasCli00Codrep() => _cli00Codrep != null;

  // "cli00Codsup" field.
  int? _cli00Codsup;
  int get cli00Codsup => _cli00Codsup ?? 0;
  set cli00Codsup(int? val) => _cli00Codsup = val;

  void incrementCli00Codsup(int amount) => cli00Codsup = cli00Codsup + amount;

  bool hasCli00Codsup() => _cli00Codsup != null;

  // "cli00Titven" field.
  double? _cli00Titven;
  double get cli00Titven => _cli00Titven ?? 0.0;
  set cli00Titven(double? val) => _cli00Titven = val;

  void incrementCli00Titven(double amount) =>
      cli00Titven = cli00Titven + amount;

  bool hasCli00Titven() => _cli00Titven != null;

  // "cli00Titave" field.
  double? _cli00Titave;
  double get cli00Titave => _cli00Titave ?? 0.0;
  set cli00Titave(double? val) => _cli00Titave = val;

  void incrementCli00Titave(double amount) =>
      cli00Titave = cli00Titave + amount;

  bool hasCli00Titave() => _cli00Titave != null;

  // "cli00Ttlrec" field.
  double? _cli00Ttlrec;
  double get cli00Ttlrec => _cli00Ttlrec ?? 0.0;
  set cli00Ttlrec(double? val) => _cli00Ttlrec = val;

  void incrementCli00Ttlrec(double amount) =>
      cli00Ttlrec = cli00Ttlrec + amount;

  bool hasCli00Ttlrec() => _cli00Ttlrec != null;

  // "cli00Flgven" field.
  int? _cli00Flgven;
  int get cli00Flgven => _cli00Flgven ?? 0;
  set cli00Flgven(int? val) => _cli00Flgven = val;

  void incrementCli00Flgven(int amount) => cli00Flgven = cli00Flgven + amount;

  bool hasCli00Flgven() => _cli00Flgven != null;

  // "cli00Codage" field.
  int? _cli00Codage;
  int get cli00Codage => _cli00Codage ?? 0;
  set cli00Codage(int? val) => _cli00Codage = val;

  void incrementCli00Codage(int amount) => cli00Codage = cli00Codage + amount;

  bool hasCli00Codage() => _cli00Codage != null;

  // "cli00Deffidcod" field.
  int? _cli00Deffidcod;
  int get cli00Deffidcod => _cli00Deffidcod ?? 0;
  set cli00Deffidcod(int? val) => _cli00Deffidcod = val;

  void incrementCli00Deffidcod(int amount) =>
      cli00Deffidcod = cli00Deffidcod + amount;

  bool hasCli00Deffidcod() => _cli00Deffidcod != null;

  // "cli00Typpco" field.
  int? _cli00Typpco;
  int get cli00Typpco => _cli00Typpco ?? 0;
  set cli00Typpco(int? val) => _cli00Typpco = val;

  void incrementCli00Typpco(int amount) => cli00Typpco = cli00Typpco + amount;

  bool hasCli00Typpco() => _cli00Typpco != null;

  // "cli00Codreg" field.
  int? _cli00Codreg;
  int get cli00Codreg => _cli00Codreg ?? 0;
  set cli00Codreg(int? val) => _cli00Codreg = val;

  void incrementCli00Codreg(int amount) => cli00Codreg = cli00Codreg + amount;

  bool hasCli00Codreg() => _cli00Codreg != null;

  // "cli00Fattotign" field.
  int? _cli00Fattotign;
  int get cli00Fattotign => _cli00Fattotign ?? 0;
  set cli00Fattotign(int? val) => _cli00Fattotign = val;

  void incrementCli00Fattotign(int amount) =>
      cli00Fattotign = cli00Fattotign + amount;

  bool hasCli00Fattotign() => _cli00Fattotign != null;

  // "cli00Vengerntf" field.
  int? _cli00Vengerntf;
  int get cli00Vengerntf => _cli00Vengerntf ?? 0;
  set cli00Vengerntf(int? val) => _cli00Vengerntf = val;

  void incrementCli00Vengerntf(int amount) =>
      cli00Vengerntf = cli00Vengerntf + amount;

  bool hasCli00Vengerntf() => _cli00Vengerntf != null;

  // "corBorda" field.
  Color? _corBorda;
  Color? get corBorda => _corBorda;
  set corBorda(Color? val) => _corBorda = val;

  bool hasCorBorda() => _corBorda != null;

  // "isNovoCliente" field.
  bool? _isNovoCliente;
  bool get isNovoCliente => _isNovoCliente ?? false;
  set isNovoCliente(bool? val) => _isNovoCliente = val;

  bool hasIsNovoCliente() => _isNovoCliente != null;

  // "isModificado" field.
  bool? _isModificado;
  bool get isModificado => _isModificado ?? false;
  set isModificado(bool? val) => _isModificado = val;

  bool hasIsModificado() => _isModificado != null;

  // "situacaoFinanceira" field.
  String? _situacaoFinanceira;
  String get situacaoFinanceira => _situacaoFinanceira ?? '';
  set situacaoFinanceira(String? val) => _situacaoFinanceira = val;

  bool hasSituacaoFinanceira() => _situacaoFinanceira != null;

  // "saldoCredito" field.
  double? _saldoCredito;
  double get saldoCredito => _saldoCredito ?? 0.0;
  set saldoCredito(double? val) => _saldoCredito = val;

  void incrementSaldoCredito(double amount) =>
      saldoCredito = saldoCredito + amount;

  bool hasSaldoCredito() => _saldoCredito != null;

  // "cli02NProp" field.
  String? _cli02NProp;
  String get cli02NProp => _cli02NProp ?? '';
  set cli02NProp(String? val) => _cli02NProp = val;

  bool hasCli02NProp() => _cli02NProp != null;

  // "cli02EndProp" field.
  String? _cli02EndProp;
  String get cli02EndProp => _cli02EndProp ?? '';
  set cli02EndProp(String? val) => _cli02EndProp = val;

  bool hasCli02EndProp() => _cli02EndProp != null;

  // "cli02NumProp" field.
  String? _cli02NumProp;
  String get cli02NumProp => _cli02NumProp ?? '';
  set cli02NumProp(String? val) => _cli02NumProp = val;

  bool hasCli02NumProp() => _cli02NumProp != null;

  // "cli02BairroProp" field.
  String? _cli02BairroProp;
  String get cli02BairroProp => _cli02BairroProp ?? '';
  set cli02BairroProp(String? val) => _cli02BairroProp = val;

  bool hasCli02BairroProp() => _cli02BairroProp != null;

  // "cli02CidadeProp" field.
  String? _cli02CidadeProp;
  String get cli02CidadeProp => _cli02CidadeProp ?? '';
  set cli02CidadeProp(String? val) => _cli02CidadeProp = val;

  bool hasCli02CidadeProp() => _cli02CidadeProp != null;

  // "cli02UfProp" field.
  String? _cli02UfProp;
  String get cli02UfProp => _cli02UfProp ?? '';
  set cli02UfProp(String? val) => _cli02UfProp = val;

  bool hasCli02UfProp() => _cli02UfProp != null;

  // "cli02NRGProp" field.
  String? _cli02NRGProp;
  String get cli02NRGProp => _cli02NRGProp ?? '';
  set cli02NRGProp(String? val) => _cli02NRGProp = val;

  bool hasCli02NRGProp() => _cli02NRGProp != null;

  // "cli02OrgaoProp" field.
  String? _cli02OrgaoProp;
  String get cli02OrgaoProp => _cli02OrgaoProp ?? '';
  set cli02OrgaoProp(String? val) => _cli02OrgaoProp = val;

  bool hasCli02OrgaoProp() => _cli02OrgaoProp != null;

  // "cli02CpfProp" field.
  String? _cli02CpfProp;
  String get cli02CpfProp => _cli02CpfProp ?? '';
  set cli02CpfProp(String? val) => _cli02CpfProp = val;

  bool hasCli02CpfProp() => _cli02CpfProp != null;

  // "cli02ConjugeProp" field.
  String? _cli02ConjugeProp;
  String get cli02ConjugeProp => _cli02ConjugeProp ?? '';
  set cli02ConjugeProp(String? val) => _cli02ConjugeProp = val;

  bool hasCli02ConjugeProp() => _cli02ConjugeProp != null;

  // "cli02NRGConjProp" field.
  String? _cli02NRGConjProp;
  String get cli02NRGConjProp => _cli02NRGConjProp ?? '';
  set cli02NRGConjProp(String? val) => _cli02NRGConjProp = val;

  bool hasCli02NRGConjProp() => _cli02NRGConjProp != null;

  // "cli02OrgaoConjProp" field.
  String? _cli02OrgaoConjProp;
  String get cli02OrgaoConjProp => _cli02OrgaoConjProp ?? '';
  set cli02OrgaoConjProp(String? val) => _cli02OrgaoConjProp = val;

  bool hasCli02OrgaoConjProp() => _cli02OrgaoConjProp != null;

  // "cli02CpfConjProp" field.
  String? _cli02CpfConjProp;
  String get cli02CpfConjProp => _cli02CpfConjProp ?? '';
  set cli02CpfConjProp(String? val) => _cli02CpfConjProp = val;

  bool hasCli02CpfConjProp() => _cli02CpfConjProp != null;

  // "bancosList" field.
  List<BancoInfoStructStruct>? _bancosList;
  List<BancoInfoStructStruct> get bancosList => _bancosList ?? const [];
  set bancosList(List<BancoInfoStructStruct>? val) => _bancosList = val;

  void updateBancosList(Function(List<BancoInfoStructStruct>) updateFn) {
    updateFn(_bancosList ??= []);
  }

  bool hasBancosList() => _bancosList != null;

  static ClienteResultStruct fromMap(Map<String, dynamic> data) =>
      ClienteResultStruct(
        uuid: data['uuid'] as String?,
        success: data['success'] as bool?,
        message: data['message'] as String?,
        cli00Codigo: castToType<int>(data['cli00Codigo']),
        cli00Descri: data['cli00Descri'] as String?,
        cli00Fantas: data['cli00Fantas'] as String?,
        cli00Endere: data['cli00Endere'] as String?,
        cli00Endnum: data['cli00Endnum'] as String?,
        cli00Bairro: data['cli00Bairro'] as String?,
        cli00Cidcod: castToType<int>(data['cli00Cidcod']),
        cli00Ciddes: data['cli00Ciddes'] as String?,
        cli00Estcod: castToType<int>(data['cli00Estcod']),
        cli00Estsgl: data['cli00Estsgl'] as String?,
        cli00Endcep: data['cli00Endcep'] as String?,
        cli00Fonddd: data['cli00Fonddd'] as String?,
        cli00Fonnum: data['cli00Fonnum'] as String?,
        cli00Cpfcnp: data['cli00Cpfcnp'] as String?,
        cli00Insest: data['cli00Insest'] as String?,
        cli00Datcad: data['cli00Datcad'] as DateTime?,
        cli00Datcom: data['cli00Datcom'] as DateTime?,
        cli00Active: castToType<int>(data['cli00Active']),
        cli00Observ: data['cli00Observ'] as String?,
        cli00Crelim: castToType<double>(data['cli00Crelim']),
        cli00Creatu: castToType<double>(data['cli00Creatu']),
        cli00Pessoa: data['cli00Pessoa'] as String?,
        cli00Typpes: castToType<int>(data['cli00Typpes']),
        cli00Contat: data['cli00Contat'] as String?,
        cli00Codram: castToType<int>(data['cli00Codram']),
        ram00descri: data['ram00descri'] as String?,
        cli00Datfun: data['cli00Datfun'] as DateTime?,
        cli00Codrep: castToType<int>(data['cli00Codrep']),
        cli00Codsup: castToType<int>(data['cli00Codsup']),
        cli00Titven: castToType<double>(data['cli00Titven']),
        cli00Titave: castToType<double>(data['cli00Titave']),
        cli00Ttlrec: castToType<double>(data['cli00Ttlrec']),
        cli00Flgven: castToType<int>(data['cli00Flgven']),
        cli00Codage: castToType<int>(data['cli00Codage']),
        cli00Deffidcod: castToType<int>(data['cli00Deffidcod']),
        cli00Typpco: castToType<int>(data['cli00Typpco']),
        cli00Codreg: castToType<int>(data['cli00Codreg']),
        cli00Fattotign: castToType<int>(data['cli00Fattotign']),
        cli00Vengerntf: castToType<int>(data['cli00Vengerntf']),
        corBorda: getSchemaColor(data['corBorda']),
        isNovoCliente: data['isNovoCliente'] as bool?,
        isModificado: data['isModificado'] as bool?,
        situacaoFinanceira: data['situacaoFinanceira'] as String?,
        saldoCredito: castToType<double>(data['saldoCredito']),
        cli02NProp: data['cli02NProp'] as String?,
        cli02EndProp: data['cli02EndProp'] as String?,
        cli02NumProp: data['cli02NumProp'] as String?,
        cli02BairroProp: data['cli02BairroProp'] as String?,
        cli02CidadeProp: data['cli02CidadeProp'] as String?,
        cli02UfProp: data['cli02UfProp'] as String?,
        cli02NRGProp: data['cli02NRGProp'] as String?,
        cli02OrgaoProp: data['cli02OrgaoProp'] as String?,
        cli02CpfProp: data['cli02CpfProp'] as String?,
        cli02ConjugeProp: data['cli02ConjugeProp'] as String?,
        cli02NRGConjProp: data['cli02NRGConjProp'] as String?,
        cli02OrgaoConjProp: data['cli02OrgaoConjProp'] as String?,
        cli02CpfConjProp: data['cli02CpfConjProp'] as String?,
        bancosList: getStructList(
          data['bancosList'],
          BancoInfoStructStruct.fromMap,
        ),
      );

  static ClienteResultStruct? maybeFromMap(dynamic data) => data is Map
      ? ClienteResultStruct.fromMap(data.cast<String, dynamic>())
      : null;

  Map<String, dynamic> toMap() => {
        'uuid': _uuid,
        'success': _success,
        'message': _message,
        'cli00Codigo': _cli00Codigo,
        'cli00Descri': _cli00Descri,
        'cli00Fantas': _cli00Fantas,
        'cli00Endere': _cli00Endere,
        'cli00Endnum': _cli00Endnum,
        'cli00Bairro': _cli00Bairro,
        'cli00Cidcod': _cli00Cidcod,
        'cli00Ciddes': _cli00Ciddes,
        'cli00Estcod': _cli00Estcod,
        'cli00Estsgl': _cli00Estsgl,
        'cli00Endcep': _cli00Endcep,
        'cli00Fonddd': _cli00Fonddd,
        'cli00Fonnum': _cli00Fonnum,
        'cli00Cpfcnp': _cli00Cpfcnp,
        'cli00Insest': _cli00Insest,
        'cli00Datcad': _cli00Datcad,
        'cli00Datcom': _cli00Datcom,
        'cli00Active': _cli00Active,
        'cli00Observ': _cli00Observ,
        'cli00Crelim': _cli00Crelim,
        'cli00Creatu': _cli00Creatu,
        'cli00Pessoa': _cli00Pessoa,
        'cli00Typpes': _cli00Typpes,
        'cli00Contat': _cli00Contat,
        'cli00Codram': _cli00Codram,
        'ram00descri': _ram00descri,
        'cli00Datfun': _cli00Datfun,
        'cli00Codrep': _cli00Codrep,
        'cli00Codsup': _cli00Codsup,
        'cli00Titven': _cli00Titven,
        'cli00Titave': _cli00Titave,
        'cli00Ttlrec': _cli00Ttlrec,
        'cli00Flgven': _cli00Flgven,
        'cli00Codage': _cli00Codage,
        'cli00Deffidcod': _cli00Deffidcod,
        'cli00Typpco': _cli00Typpco,
        'cli00Codreg': _cli00Codreg,
        'cli00Fattotign': _cli00Fattotign,
        'cli00Vengerntf': _cli00Vengerntf,
        'corBorda': _corBorda,
        'isNovoCliente': _isNovoCliente,
        'isModificado': _isModificado,
        'situacaoFinanceira': _situacaoFinanceira,
        'saldoCredito': _saldoCredito,
        'cli02NProp': _cli02NProp,
        'cli02EndProp': _cli02EndProp,
        'cli02NumProp': _cli02NumProp,
        'cli02BairroProp': _cli02BairroProp,
        'cli02CidadeProp': _cli02CidadeProp,
        'cli02UfProp': _cli02UfProp,
        'cli02NRGProp': _cli02NRGProp,
        'cli02OrgaoProp': _cli02OrgaoProp,
        'cli02CpfProp': _cli02CpfProp,
        'cli02ConjugeProp': _cli02ConjugeProp,
        'cli02NRGConjProp': _cli02NRGConjProp,
        'cli02OrgaoConjProp': _cli02OrgaoConjProp,
        'cli02CpfConjProp': _cli02CpfConjProp,
        'bancosList': _bancosList?.map((e) => e.toMap()).toList(),
      }.withoutNulls;

  @override
  Map<String, dynamic> toSerializableMap() => {
        'uuid': serializeParam(
          _uuid,
          ParamType.String,
        ),
        'success': serializeParam(
          _success,
          ParamType.bool,
        ),
        'message': serializeParam(
          _message,
          ParamType.String,
        ),
        'cli00Codigo': serializeParam(
          _cli00Codigo,
          ParamType.int,
        ),
        'cli00Descri': serializeParam(
          _cli00Descri,
          ParamType.String,
        ),
        'cli00Fantas': serializeParam(
          _cli00Fantas,
          ParamType.String,
        ),
        'cli00Endere': serializeParam(
          _cli00Endere,
          ParamType.String,
        ),
        'cli00Endnum': serializeParam(
          _cli00Endnum,
          ParamType.String,
        ),
        'cli00Bairro': serializeParam(
          _cli00Bairro,
          ParamType.String,
        ),
        'cli00Cidcod': serializeParam(
          _cli00Cidcod,
          ParamType.int,
        ),
        'cli00Ciddes': serializeParam(
          _cli00Ciddes,
          ParamType.String,
        ),
        'cli00Estcod': serializeParam(
          _cli00Estcod,
          ParamType.int,
        ),
        'cli00Estsgl': serializeParam(
          _cli00Estsgl,
          ParamType.String,
        ),
        'cli00Endcep': serializeParam(
          _cli00Endcep,
          ParamType.String,
        ),
        'cli00Fonddd': serializeParam(
          _cli00Fonddd,
          ParamType.String,
        ),
        'cli00Fonnum': serializeParam(
          _cli00Fonnum,
          ParamType.String,
        ),
        'cli00Cpfcnp': serializeParam(
          _cli00Cpfcnp,
          ParamType.String,
        ),
        'cli00Insest': serializeParam(
          _cli00Insest,
          ParamType.String,
        ),
        'cli00Datcad': serializeParam(
          _cli00Datcad,
          ParamType.DateTime,
        ),
        'cli00Datcom': serializeParam(
          _cli00Datcom,
          ParamType.DateTime,
        ),
        'cli00Active': serializeParam(
          _cli00Active,
          ParamType.int,
        ),
        'cli00Observ': serializeParam(
          _cli00Observ,
          ParamType.String,
        ),
        'cli00Crelim': serializeParam(
          _cli00Crelim,
          ParamType.double,
        ),
        'cli00Creatu': serializeParam(
          _cli00Creatu,
          ParamType.double,
        ),
        'cli00Pessoa': serializeParam(
          _cli00Pessoa,
          ParamType.String,
        ),
        'cli00Typpes': serializeParam(
          _cli00Typpes,
          ParamType.int,
        ),
        'cli00Contat': serializeParam(
          _cli00Contat,
          ParamType.String,
        ),
        'cli00Codram': serializeParam(
          _cli00Codram,
          ParamType.int,
        ),
        'ram00descri': serializeParam(
          _ram00descri,
          ParamType.String,
        ),
        'cli00Datfun': serializeParam(
          _cli00Datfun,
          ParamType.DateTime,
        ),
        'cli00Codrep': serializeParam(
          _cli00Codrep,
          ParamType.int,
        ),
        'cli00Codsup': serializeParam(
          _cli00Codsup,
          ParamType.int,
        ),
        'cli00Titven': serializeParam(
          _cli00Titven,
          ParamType.double,
        ),
        'cli00Titave': serializeParam(
          _cli00Titave,
          ParamType.double,
        ),
        'cli00Ttlrec': serializeParam(
          _cli00Ttlrec,
          ParamType.double,
        ),
        'cli00Flgven': serializeParam(
          _cli00Flgven,
          ParamType.int,
        ),
        'cli00Codage': serializeParam(
          _cli00Codage,
          ParamType.int,
        ),
        'cli00Deffidcod': serializeParam(
          _cli00Deffidcod,
          ParamType.int,
        ),
        'cli00Typpco': serializeParam(
          _cli00Typpco,
          ParamType.int,
        ),
        'cli00Codreg': serializeParam(
          _cli00Codreg,
          ParamType.int,
        ),
        'cli00Fattotign': serializeParam(
          _cli00Fattotign,
          ParamType.int,
        ),
        'cli00Vengerntf': serializeParam(
          _cli00Vengerntf,
          ParamType.int,
        ),
        'corBorda': serializeParam(
          _corBorda,
          ParamType.Color,
        ),
        'isNovoCliente': serializeParam(
          _isNovoCliente,
          ParamType.bool,
        ),
        'isModificado': serializeParam(
          _isModificado,
          ParamType.bool,
        ),
        'situacaoFinanceira': serializeParam(
          _situacaoFinanceira,
          ParamType.String,
        ),
        'saldoCredito': serializeParam(
          _saldoCredito,
          ParamType.double,
        ),
        'cli02NProp': serializeParam(
          _cli02NProp,
          ParamType.String,
        ),
        'cli02EndProp': serializeParam(
          _cli02EndProp,
          ParamType.String,
        ),
        'cli02NumProp': serializeParam(
          _cli02NumProp,
          ParamType.String,
        ),
        'cli02BairroProp': serializeParam(
          _cli02BairroProp,
          ParamType.String,
        ),
        'cli02CidadeProp': serializeParam(
          _cli02CidadeProp,
          ParamType.String,
        ),
        'cli02UfProp': serializeParam(
          _cli02UfProp,
          ParamType.String,
        ),
        'cli02NRGProp': serializeParam(
          _cli02NRGProp,
          ParamType.String,
        ),
        'cli02OrgaoProp': serializeParam(
          _cli02OrgaoProp,
          ParamType.String,
        ),
        'cli02CpfProp': serializeParam(
          _cli02CpfProp,
          ParamType.String,
        ),
        'cli02ConjugeProp': serializeParam(
          _cli02ConjugeProp,
          ParamType.String,
        ),
        'cli02NRGConjProp': serializeParam(
          _cli02NRGConjProp,
          ParamType.String,
        ),
        'cli02OrgaoConjProp': serializeParam(
          _cli02OrgaoConjProp,
          ParamType.String,
        ),
        'cli02CpfConjProp': serializeParam(
          _cli02CpfConjProp,
          ParamType.String,
        ),
        'bancosList': serializeParam(
          _bancosList,
          ParamType.DataStruct,
          isList: true,
        ),
      }.withoutNulls;

  static ClienteResultStruct fromSerializableMap(Map<String, dynamic> data) =>
      ClienteResultStruct(
        uuid: deserializeParam(
          data['uuid'],
          ParamType.String,
          false,
        ),
        success: deserializeParam(
          data['success'],
          ParamType.bool,
          false,
        ),
        message: deserializeParam(
          data['message'],
          ParamType.String,
          false,
        ),
        cli00Codigo: deserializeParam(
          data['cli00Codigo'],
          ParamType.int,
          false,
        ),
        cli00Descri: deserializeParam(
          data['cli00Descri'],
          ParamType.String,
          false,
        ),
        cli00Fantas: deserializeParam(
          data['cli00Fantas'],
          ParamType.String,
          false,
        ),
        cli00Endere: deserializeParam(
          data['cli00Endere'],
          ParamType.String,
          false,
        ),
        cli00Endnum: deserializeParam(
          data['cli00Endnum'],
          ParamType.String,
          false,
        ),
        cli00Bairro: deserializeParam(
          data['cli00Bairro'],
          ParamType.String,
          false,
        ),
        cli00Cidcod: deserializeParam(
          data['cli00Cidcod'],
          ParamType.int,
          false,
        ),
        cli00Ciddes: deserializeParam(
          data['cli00Ciddes'],
          ParamType.String,
          false,
        ),
        cli00Estcod: deserializeParam(
          data['cli00Estcod'],
          ParamType.int,
          false,
        ),
        cli00Estsgl: deserializeParam(
          data['cli00Estsgl'],
          ParamType.String,
          false,
        ),
        cli00Endcep: deserializeParam(
          data['cli00Endcep'],
          ParamType.String,
          false,
        ),
        cli00Fonddd: deserializeParam(
          data['cli00Fonddd'],
          ParamType.String,
          false,
        ),
        cli00Fonnum: deserializeParam(
          data['cli00Fonnum'],
          ParamType.String,
          false,
        ),
        cli00Cpfcnp: deserializeParam(
          data['cli00Cpfcnp'],
          ParamType.String,
          false,
        ),
        cli00Insest: deserializeParam(
          data['cli00Insest'],
          ParamType.String,
          false,
        ),
        cli00Datcad: deserializeParam(
          data['cli00Datcad'],
          ParamType.DateTime,
          false,
        ),
        cli00Datcom: deserializeParam(
          data['cli00Datcom'],
          ParamType.DateTime,
          false,
        ),
        cli00Active: deserializeParam(
          data['cli00Active'],
          ParamType.int,
          false,
        ),
        cli00Observ: deserializeParam(
          data['cli00Observ'],
          ParamType.String,
          false,
        ),
        cli00Crelim: deserializeParam(
          data['cli00Crelim'],
          ParamType.double,
          false,
        ),
        cli00Creatu: deserializeParam(
          data['cli00Creatu'],
          ParamType.double,
          false,
        ),
        cli00Pessoa: deserializeParam(
          data['cli00Pessoa'],
          ParamType.String,
          false,
        ),
        cli00Typpes: deserializeParam(
          data['cli00Typpes'],
          ParamType.int,
          false,
        ),
        cli00Contat: deserializeParam(
          data['cli00Contat'],
          ParamType.String,
          false,
        ),
        cli00Codram: deserializeParam(
          data['cli00Codram'],
          ParamType.int,
          false,
        ),
        ram00descri: deserializeParam(
          data['ram00descri'],
          ParamType.String,
          false,
        ),
        cli00Datfun: deserializeParam(
          data['cli00Datfun'],
          ParamType.DateTime,
          false,
        ),
        cli00Codrep: deserializeParam(
          data['cli00Codrep'],
          ParamType.int,
          false,
        ),
        cli00Codsup: deserializeParam(
          data['cli00Codsup'],
          ParamType.int,
          false,
        ),
        cli00Titven: deserializeParam(
          data['cli00Titven'],
          ParamType.double,
          false,
        ),
        cli00Titave: deserializeParam(
          data['cli00Titave'],
          ParamType.double,
          false,
        ),
        cli00Ttlrec: deserializeParam(
          data['cli00Ttlrec'],
          ParamType.double,
          false,
        ),
        cli00Flgven: deserializeParam(
          data['cli00Flgven'],
          ParamType.int,
          false,
        ),
        cli00Codage: deserializeParam(
          data['cli00Codage'],
          ParamType.int,
          false,
        ),
        cli00Deffidcod: deserializeParam(
          data['cli00Deffidcod'],
          ParamType.int,
          false,
        ),
        cli00Typpco: deserializeParam(
          data['cli00Typpco'],
          ParamType.int,
          false,
        ),
        cli00Codreg: deserializeParam(
          data['cli00Codreg'],
          ParamType.int,
          false,
        ),
        cli00Fattotign: deserializeParam(
          data['cli00Fattotign'],
          ParamType.int,
          false,
        ),
        cli00Vengerntf: deserializeParam(
          data['cli00Vengerntf'],
          ParamType.int,
          false,
        ),
        corBorda: deserializeParam(
          data['corBorda'],
          ParamType.Color,
          false,
        ),
        isNovoCliente: deserializeParam(
          data['isNovoCliente'],
          ParamType.bool,
          false,
        ),
        isModificado: deserializeParam(
          data['isModificado'],
          ParamType.bool,
          false,
        ),
        situacaoFinanceira: deserializeParam(
          data['situacaoFinanceira'],
          ParamType.String,
          false,
        ),
        saldoCredito: deserializeParam(
          data['saldoCredito'],
          ParamType.double,
          false,
        ),
        cli02NProp: deserializeParam(
          data['cli02NProp'],
          ParamType.String,
          false,
        ),
        cli02EndProp: deserializeParam(
          data['cli02EndProp'],
          ParamType.String,
          false,
        ),
        cli02NumProp: deserializeParam(
          data['cli02NumProp'],
          ParamType.String,
          false,
        ),
        cli02BairroProp: deserializeParam(
          data['cli02BairroProp'],
          ParamType.String,
          false,
        ),
        cli02CidadeProp: deserializeParam(
          data['cli02CidadeProp'],
          ParamType.String,
          false,
        ),
        cli02UfProp: deserializeParam(
          data['cli02UfProp'],
          ParamType.String,
          false,
        ),
        cli02NRGProp: deserializeParam(
          data['cli02NRGProp'],
          ParamType.String,
          false,
        ),
        cli02OrgaoProp: deserializeParam(
          data['cli02OrgaoProp'],
          ParamType.String,
          false,
        ),
        cli02CpfProp: deserializeParam(
          data['cli02CpfProp'],
          ParamType.String,
          false,
        ),
        cli02ConjugeProp: deserializeParam(
          data['cli02ConjugeProp'],
          ParamType.String,
          false,
        ),
        cli02NRGConjProp: deserializeParam(
          data['cli02NRGConjProp'],
          ParamType.String,
          false,
        ),
        cli02OrgaoConjProp: deserializeParam(
          data['cli02OrgaoConjProp'],
          ParamType.String,
          false,
        ),
        cli02CpfConjProp: deserializeParam(
          data['cli02CpfConjProp'],
          ParamType.String,
          false,
        ),
        bancosList: deserializeStructParam<BancoInfoStructStruct>(
          data['bancosList'],
          ParamType.DataStruct,
          true,
          structBuilder: BancoInfoStructStruct.fromSerializableMap,
        ),
      );

  @override
  String toString() => 'ClienteResultStruct(${toMap()})';

  @override
  bool operator ==(Object other) {
    const listEquality = ListEquality();
    return other is ClienteResultStruct &&
        uuid == other.uuid &&
        success == other.success &&
        message == other.message &&
        cli00Codigo == other.cli00Codigo &&
        cli00Descri == other.cli00Descri &&
        cli00Fantas == other.cli00Fantas &&
        cli00Endere == other.cli00Endere &&
        cli00Endnum == other.cli00Endnum &&
        cli00Bairro == other.cli00Bairro &&
        cli00Cidcod == other.cli00Cidcod &&
        cli00Ciddes == other.cli00Ciddes &&
        cli00Estcod == other.cli00Estcod &&
        cli00Estsgl == other.cli00Estsgl &&
        cli00Endcep == other.cli00Endcep &&
        cli00Fonddd == other.cli00Fonddd &&
        cli00Fonnum == other.cli00Fonnum &&
        cli00Cpfcnp == other.cli00Cpfcnp &&
        cli00Insest == other.cli00Insest &&
        cli00Datcad == other.cli00Datcad &&
        cli00Datcom == other.cli00Datcom &&
        cli00Active == other.cli00Active &&
        cli00Observ == other.cli00Observ &&
        cli00Crelim == other.cli00Crelim &&
        cli00Creatu == other.cli00Creatu &&
        cli00Pessoa == other.cli00Pessoa &&
        cli00Typpes == other.cli00Typpes &&
        cli00Contat == other.cli00Contat &&
        cli00Codram == other.cli00Codram &&
        ram00descri == other.ram00descri &&
        cli00Datfun == other.cli00Datfun &&
        cli00Codrep == other.cli00Codrep &&
        cli00Codsup == other.cli00Codsup &&
        cli00Titven == other.cli00Titven &&
        cli00Titave == other.cli00Titave &&
        cli00Ttlrec == other.cli00Ttlrec &&
        cli00Flgven == other.cli00Flgven &&
        cli00Codage == other.cli00Codage &&
        cli00Deffidcod == other.cli00Deffidcod &&
        cli00Typpco == other.cli00Typpco &&
        cli00Codreg == other.cli00Codreg &&
        cli00Fattotign == other.cli00Fattotign &&
        cli00Vengerntf == other.cli00Vengerntf &&
        corBorda == other.corBorda &&
        isNovoCliente == other.isNovoCliente &&
        isModificado == other.isModificado &&
        situacaoFinanceira == other.situacaoFinanceira &&
        saldoCredito == other.saldoCredito &&
        cli02NProp == other.cli02NProp &&
        cli02EndProp == other.cli02EndProp &&
        cli02NumProp == other.cli02NumProp &&
        cli02BairroProp == other.cli02BairroProp &&
        cli02CidadeProp == other.cli02CidadeProp &&
        cli02UfProp == other.cli02UfProp &&
        cli02NRGProp == other.cli02NRGProp &&
        cli02OrgaoProp == other.cli02OrgaoProp &&
        cli02CpfProp == other.cli02CpfProp &&
        cli02ConjugeProp == other.cli02ConjugeProp &&
        cli02NRGConjProp == other.cli02NRGConjProp &&
        cli02OrgaoConjProp == other.cli02OrgaoConjProp &&
        cli02CpfConjProp == other.cli02CpfConjProp &&
        listEquality.equals(bancosList, other.bancosList);
  }

  @override
  int get hashCode => const ListEquality().hash([
        uuid,
        success,
        message,
        cli00Codigo,
        cli00Descri,
        cli00Fantas,
        cli00Endere,
        cli00Endnum,
        cli00Bairro,
        cli00Cidcod,
        cli00Ciddes,
        cli00Estcod,
        cli00Estsgl,
        cli00Endcep,
        cli00Fonddd,
        cli00Fonnum,
        cli00Cpfcnp,
        cli00Insest,
        cli00Datcad,
        cli00Datcom,
        cli00Active,
        cli00Observ,
        cli00Crelim,
        cli00Creatu,
        cli00Pessoa,
        cli00Typpes,
        cli00Contat,
        cli00Codram,
        ram00descri,
        cli00Datfun,
        cli00Codrep,
        cli00Codsup,
        cli00Titven,
        cli00Titave,
        cli00Ttlrec,
        cli00Flgven,
        cli00Codage,
        cli00Deffidcod,
        cli00Typpco,
        cli00Codreg,
        cli00Fattotign,
        cli00Vengerntf,
        corBorda,
        isNovoCliente,
        isModificado,
        situacaoFinanceira,
        saldoCredito,
        cli02NProp,
        cli02EndProp,
        cli02NumProp,
        cli02BairroProp,
        cli02CidadeProp,
        cli02UfProp,
        cli02NRGProp,
        cli02OrgaoProp,
        cli02CpfProp,
        cli02ConjugeProp,
        cli02NRGConjProp,
        cli02OrgaoConjProp,
        cli02CpfConjProp,
        bancosList
      ]);
}

ClienteResultStruct createClienteResultStruct({
  String? uuid,
  bool? success,
  String? message,
  int? cli00Codigo,
  String? cli00Descri,
  String? cli00Fantas,
  String? cli00Endere,
  String? cli00Endnum,
  String? cli00Bairro,
  int? cli00Cidcod,
  String? cli00Ciddes,
  int? cli00Estcod,
  String? cli00Estsgl,
  String? cli00Endcep,
  String? cli00Fonddd,
  String? cli00Fonnum,
  String? cli00Cpfcnp,
  String? cli00Insest,
  DateTime? cli00Datcad,
  DateTime? cli00Datcom,
  int? cli00Active,
  String? cli00Observ,
  double? cli00Crelim,
  double? cli00Creatu,
  String? cli00Pessoa,
  int? cli00Typpes,
  String? cli00Contat,
  int? cli00Codram,
  String? ram00descri,
  DateTime? cli00Datfun,
  int? cli00Codrep,
  int? cli00Codsup,
  double? cli00Titven,
  double? cli00Titave,
  double? cli00Ttlrec,
  int? cli00Flgven,
  int? cli00Codage,
  int? cli00Deffidcod,
  int? cli00Typpco,
  int? cli00Codreg,
  int? cli00Fattotign,
  int? cli00Vengerntf,
  Color? corBorda,
  bool? isNovoCliente,
  bool? isModificado,
  String? situacaoFinanceira,
  double? saldoCredito,
  String? cli02NProp,
  String? cli02EndProp,
  String? cli02NumProp,
  String? cli02BairroProp,
  String? cli02CidadeProp,
  String? cli02UfProp,
  String? cli02NRGProp,
  String? cli02OrgaoProp,
  String? cli02CpfProp,
  String? cli02ConjugeProp,
  String? cli02NRGConjProp,
  String? cli02OrgaoConjProp,
  String? cli02CpfConjProp,
}) =>
    ClienteResultStruct(
      uuid: uuid,
      success: success,
      message: message,
      cli00Codigo: cli00Codigo,
      cli00Descri: cli00Descri,
      cli00Fantas: cli00Fantas,
      cli00Endere: cli00Endere,
      cli00Endnum: cli00Endnum,
      cli00Bairro: cli00Bairro,
      cli00Cidcod: cli00Cidcod,
      cli00Ciddes: cli00Ciddes,
      cli00Estcod: cli00Estcod,
      cli00Estsgl: cli00Estsgl,
      cli00Endcep: cli00Endcep,
      cli00Fonddd: cli00Fonddd,
      cli00Fonnum: cli00Fonnum,
      cli00Cpfcnp: cli00Cpfcnp,
      cli00Insest: cli00Insest,
      cli00Datcad: cli00Datcad,
      cli00Datcom: cli00Datcom,
      cli00Active: cli00Active,
      cli00Observ: cli00Observ,
      cli00Crelim: cli00Crelim,
      cli00Creatu: cli00Creatu,
      cli00Pessoa: cli00Pessoa,
      cli00Typpes: cli00Typpes,
      cli00Contat: cli00Contat,
      cli00Codram: cli00Codram,
      ram00descri: ram00descri,
      cli00Datfun: cli00Datfun,
      cli00Codrep: cli00Codrep,
      cli00Codsup: cli00Codsup,
      cli00Titven: cli00Titven,
      cli00Titave: cli00Titave,
      cli00Ttlrec: cli00Ttlrec,
      cli00Flgven: cli00Flgven,
      cli00Codage: cli00Codage,
      cli00Deffidcod: cli00Deffidcod,
      cli00Typpco: cli00Typpco,
      cli00Codreg: cli00Codreg,
      cli00Fattotign: cli00Fattotign,
      cli00Vengerntf: cli00Vengerntf,
      corBorda: corBorda,
      isNovoCliente: isNovoCliente,
      isModificado: isModificado,
      situacaoFinanceira: situacaoFinanceira,
      saldoCredito: saldoCredito,
      cli02NProp: cli02NProp,
      cli02EndProp: cli02EndProp,
      cli02NumProp: cli02NumProp,
      cli02BairroProp: cli02BairroProp,
      cli02CidadeProp: cli02CidadeProp,
      cli02UfProp: cli02UfProp,
      cli02NRGProp: cli02NRGProp,
      cli02OrgaoProp: cli02OrgaoProp,
      cli02CpfProp: cli02CpfProp,
      cli02ConjugeProp: cli02ConjugeProp,
      cli02NRGConjProp: cli02NRGConjProp,
      cli02OrgaoConjProp: cli02OrgaoConjProp,
      cli02CpfConjProp: cli02CpfConjProp,
    );
