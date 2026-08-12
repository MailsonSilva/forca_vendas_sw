import '/backend/schema/structs/index.dart';
import '/components/loading/loading_widget.dart';
import '/core/app_util.dart';
import '/core/form_field_controller.dart';
import '/index.dart';
import 'form_clientes_page_widget.dart' show FormClientesPageWidget;
import 'package:flutter/material.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';

class FormClientesPageModel extends AppModel<FormClientesPageWidget> {
  ///  Local state fields for this page.

  String? tipoPessoa = 'F';

  ClienteResultStruct? cliData;
  void updateCliDataStruct(Function(ClienteResultStruct) updateFn) {
    updateFn(cliData ??= ClienteResultStruct());
  }

  /// Caminho do XML temporario gerado pelo botao SALVAR, pronto para subida
  /// assincrona ao FTP pela tela de Ferramentas.
  String? xmlPath;

  List<BancoInfoStructStruct> listaBancos = [];
  void addToListaBancos(BancoInfoStructStruct item) => listaBancos.add(item);
  void removeFromListaBancos(BancoInfoStructStruct item) =>
      listaBancos.remove(item);
  void removeAtIndexFromListaBancos(int index) => listaBancos.removeAt(index);
  void insertAtIndexInListaBancos(int index, BancoInfoStructStruct item) =>
      listaBancos.insert(index, item);
  void updateListaBancosAtIndex(
          int index, Function(BancoInfoStructStruct) updateFn) =>
      listaBancos[index] = updateFn(listaBancos[index]);

  ///  State fields for stateful widgets in this page.

  // Stores action output result for [Custom Action - carregarClienteOffline] action in FormClientesPage widget.
  ClienteResultStruct? clienteResult;
  // State field(s) for TabBarCli widget.
  TabController? tabBarCliController;
  int get tabBarCliCurrentIndex =>
      tabBarCliController != null ? tabBarCliController!.index : 0;
  int get tabBarCliPreviousIndex =>
      tabBarCliController != null ? tabBarCliController!.previousIndex : 0;

  // State field(s) for NomeField widget.
  FocusNode? nomeFieldFocusNode;
  TextEditingController? nomeFieldTextController;
  String? Function(BuildContext, String?)? nomeFieldTextControllerValidator;
  // State field(s) for FantasiaField widget.
  FocusNode? fantasiaFieldFocusNode;
  TextEditingController? fantasiaFieldTextController;
  String? Function(BuildContext, String?)? fantasiaFieldTextControllerValidator;
  // State field(s) for CpfField widget.
  FocusNode? cpfFieldFocusNode;
  TextEditingController? cpfFieldTextController;
  late MaskTextInputFormatter cpfFieldMask;
  String? Function(BuildContext, String?)? cpfFieldTextControllerValidator;
  // State field(s) for CnpjField widget.
  FocusNode? cnpjFieldFocusNode;
  TextEditingController? cnpjFieldTextController;
  late MaskTextInputFormatter cnpjFieldMask;
  String? Function(BuildContext, String?)? cnpjFieldTextControllerValidator;
  // State field(s) for IeField widget.
  FocusNode? ieFieldFocusNode;
  TextEditingController? ieFieldTextController;
  String? Function(BuildContext, String?)? ieFieldTextControllerValidator;
  // State field(s) for RgField widget.
  FocusNode? rgFieldFocusNode;
  TextEditingController? rgFieldTextController;
  late MaskTextInputFormatter rgFieldMask;
  String? Function(BuildContext, String?)? rgFieldTextControllerValidator;
  // State field(s) for TelefoneField widget.
  FocusNode? telefoneFieldFocusNode;
  TextEditingController? telefoneFieldTextController;
  late MaskTextInputFormatter telefoneFieldMask;
  String? Function(BuildContext, String?)? telefoneFieldTextControllerValidator;
  // State field(s) for DddField widget.
  FocusNode? dddFieldFocusNode;
  TextEditingController? dddFieldTextController;
  String? Function(BuildContext, String?)? dddFieldTextControllerValidator;
  // State field(s) for EmailField widget.
  FocusNode? emailFieldFocusNode;
  TextEditingController? emailFieldTextController;
  String? Function(BuildContext, String?)? emailFieldTextControllerValidator;
  // State field(s) for RamolField widget.
  FocusNode? ramolFieldFocusNode;
  TextEditingController? ramolFieldTextController;
  String? Function(BuildContext, String?)? ramolFieldTextControllerValidator;
  // State field(s) for LimiteField widget.
  FocusNode? limiteFieldFocusNode;
  TextEditingController? limiteFieldTextController;
  String? Function(BuildContext, String?)? limiteFieldTextControllerValidator;
  // State field(s) for CepField widget.
  FocusNode? cepFieldFocusNode;
  TextEditingController? cepFieldTextController;
  late MaskTextInputFormatter cepFieldMask;
  String? Function(BuildContext, String?)? cepFieldTextControllerValidator;
  // State field(s) for NumeroField widget.
  FocusNode? numeroFieldFocusNode;
  TextEditingController? numeroFieldTextController;
  String? Function(BuildContext, String?)? numeroFieldTextControllerValidator;
  // State field(s) for BairroField widget.
  FocusNode? bairroFieldFocusNode;
  TextEditingController? bairroFieldTextController;
  String? Function(BuildContext, String?)? bairroFieldTextControllerValidator;
  // State field(s) for EnderecoField widget.
  FocusNode? enderecoFieldFocusNode;
  TextEditingController? enderecoFieldTextController;
  String? Function(BuildContext, String?)? enderecoFieldTextControllerValidator;
  // State field(s) for CidadeField widget.
  FocusNode? cidadeFieldFocusNode;
  TextEditingController? cidadeFieldTextController;
  String? Function(BuildContext, String?)? cidadeFieldTextControllerValidator;
  // State field(s) for UfDropdown widget.
  String? ufDropdownValue;
  FormFieldController<String>? ufDropdownValueController;
  // State field(s) for NomePropField widget.
  FocusNode? nomePropFieldFocusNode;
  TextEditingController? nomePropFieldTextController;
  String? Function(BuildContext, String?)? nomePropFieldTextControllerValidator;
  // State field(s) for EnderecoPropField widget.
  FocusNode? enderecoPropFieldFocusNode;
  TextEditingController? enderecoPropFieldTextController;
  String? Function(BuildContext, String?)?
      enderecoPropFieldTextControllerValidator;
  // State field(s) for BairroPropField widget.
  FocusNode? bairroPropFieldFocusNode;
  TextEditingController? bairroPropFieldTextController;
  String? Function(BuildContext, String?)?
      bairroPropFieldTextControllerValidator;
  // State field(s) for CidadePropField widget.
  FocusNode? cidadePropFieldFocusNode;
  TextEditingController? cidadePropFieldTextController;
  String? Function(BuildContext, String?)?
      cidadePropFieldTextControllerValidator;
  // State field(s) for UfPropDropdown widget.
  String? ufPropDropdownValue;
  FormFieldController<String>? ufPropDropdownValueController;
  // State field(s) for RgPropField widget.
  FocusNode? rgPropFieldFocusNode;
  TextEditingController? rgPropFieldTextController;
  late MaskTextInputFormatter rgPropFieldMask;
  String? Function(BuildContext, String?)? rgPropFieldTextControllerValidator;
  // State field(s) for CpfPropField widget.
  FocusNode? cpfPropFieldFocusNode;
  TextEditingController? cpfPropFieldTextController;
  late MaskTextInputFormatter cpfPropFieldMask;
  String? Function(BuildContext, String?)? cpfPropFieldTextControllerValidator;
  // State field(s) for NomePropConjField widget.
  FocusNode? nomePropConjFieldFocusNode;
  TextEditingController? nomePropConjFieldTextController;
  String? Function(BuildContext, String?)?
      nomePropConjFieldTextControllerValidator;
  // State field(s) for RgPropConjField widget.
  FocusNode? rgPropConjFieldFocusNode;
  TextEditingController? rgPropConjFieldTextController;
  late MaskTextInputFormatter rgPropConjFieldMask;
  String? Function(BuildContext, String?)?
      rgPropConjFieldTextControllerValidator;
  // State field(s) for CpfPropConjField widget.
  FocusNode? cpfPropConjFieldFocusNode;
  TextEditingController? cpfPropConjFieldTextController;
  late MaskTextInputFormatter cpfPropConjFieldMask;
  String? Function(BuildContext, String?)?
      cpfPropConjFieldTextControllerValidator;
  // State field(s) for obsField widget.
  FocusNode? obsFieldFocusNode;
  TextEditingController? obsFieldTextController;
  String? Function(BuildContext, String?)? obsFieldTextControllerValidator;
  // Model for Loading component.
  late LoadingModel loadingModel;

  @override
  void initState(BuildContext context) {
    loadingModel = createModel(context, () => LoadingModel());
  }

  @override
  void dispose() {
    tabBarCliController?.dispose();
    nomeFieldFocusNode?.dispose();
    nomeFieldTextController?.dispose();

    fantasiaFieldFocusNode?.dispose();
    fantasiaFieldTextController?.dispose();

    cpfFieldFocusNode?.dispose();
    cpfFieldTextController?.dispose();

    cnpjFieldFocusNode?.dispose();
    cnpjFieldTextController?.dispose();

    ieFieldFocusNode?.dispose();
    ieFieldTextController?.dispose();

    rgFieldFocusNode?.dispose();
    rgFieldTextController?.dispose();

    telefoneFieldFocusNode?.dispose();
    telefoneFieldTextController?.dispose();

    dddFieldFocusNode?.dispose();
    dddFieldTextController?.dispose();

    emailFieldFocusNode?.dispose();
    emailFieldTextController?.dispose();

    ramolFieldFocusNode?.dispose();
    ramolFieldTextController?.dispose();

    limiteFieldFocusNode?.dispose();
    limiteFieldTextController?.dispose();

    cepFieldFocusNode?.dispose();
    cepFieldTextController?.dispose();

    numeroFieldFocusNode?.dispose();
    numeroFieldTextController?.dispose();

    bairroFieldFocusNode?.dispose();
    bairroFieldTextController?.dispose();

    enderecoFieldFocusNode?.dispose();
    enderecoFieldTextController?.dispose();

    cidadeFieldFocusNode?.dispose();
    cidadeFieldTextController?.dispose();

    nomePropFieldFocusNode?.dispose();
    nomePropFieldTextController?.dispose();

    enderecoPropFieldFocusNode?.dispose();
    enderecoPropFieldTextController?.dispose();

    bairroPropFieldFocusNode?.dispose();
    bairroPropFieldTextController?.dispose();

    cidadePropFieldFocusNode?.dispose();
    cidadePropFieldTextController?.dispose();

    rgPropFieldFocusNode?.dispose();
    rgPropFieldTextController?.dispose();

    cpfPropFieldFocusNode?.dispose();
    cpfPropFieldTextController?.dispose();

    nomePropConjFieldFocusNode?.dispose();
    nomePropConjFieldTextController?.dispose();

    rgPropConjFieldFocusNode?.dispose();
    rgPropConjFieldTextController?.dispose();

    cpfPropConjFieldFocusNode?.dispose();
    cpfPropConjFieldTextController?.dispose();

    obsFieldFocusNode?.dispose();
    obsFieldTextController?.dispose();

    loadingModel.dispose();
  }
}
