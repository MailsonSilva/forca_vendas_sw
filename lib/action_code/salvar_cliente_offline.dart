import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '/backend/schema/structs/index.dart';
import '../data/services/cliente_xml_generator_service.dart';
import '../data/services/local_sales_database_service.dart';
import '../functions/retorna_mil.dart';
import '../services/carga_registry_service.dart';
import '../services/ftp_path_builder.dart';

/// Remove pontuação e caracteres especiais de textos como CPF/CNPJ, CEP, Telefone e DDD
String removerMascara(String text) {
  return text.replaceAll(RegExp(r'[.\-/\(\)\s]'), '');
}

class ResultadoSalvarCliente {
  ResultadoSalvarCliente({
    required this.success,
    required this.clienteId,
    this.xmlPath,
    this.xmlNome,
    this.mensagem = '',
  });

  final bool success;
  final int clienteId;
  final String? xmlPath;
  final String? xmlNome;
  final String mensagem;
}

/// Realiza a persistência do cliente no SQLite local (`cadcli00`) e a
/// geração obrigatória do arquivo XML de exportação no diretório de clientes (`cli/`),
/// registrando o arquivo no manifesto de sincronização (`CargaRegistryService`).
Future<ResultadoSalvarCliente> salvarClienteOffline({
  required ClienteResultStruct clienteData,
  required String codigoVendedor,
  bool usarMesmoEnderecoCobranca = true,
  Directory? tempDirOverride,
  Directory? docsDirOverride,
}) async {
  try {
    final db = await LocalSalesDatabaseService.getDatabase();

    // 1. Limpeza de máscaras e padronizações fiscais
    final String rSocial = clienteData.cli00Descri.trim().toUpperCase();
    final String nFantasia = clienteData.cli00Fantas.trim();
    final String cpfCnpjLimpo = removerMascara(clienteData.cli00Cpfcnp);
    final String cepLimpo = removerMascara(clienteData.cli00Endcep);
    final String dddLimpo = removerMascara(clienteData.cli00Fonddd);
    final String foneLimpo = removerMascara(clienteData.cli00Fonnum);

    final bool isPessoaJuridica = (clienteData.cli00Pessoa.trim() == 'J' ||
        clienteData.cli00Pessoa.trim() == '2');
    final int tipoPessoaInt = isPessoaJuridica ? 2 : 1;
    final String tipoPessoaStr = isPessoaJuridica ? 'J' : 'F';

    // Inscrição Estadual: obrigatório para PJ; para PF grava '-'
    String iEst = clienteData.cli00Insest.trim();
    if (!isPessoaJuridica) {
      iEst = '-';
    }

    final String numRg = (!isPessoaJuridica)
        ? (clienteData.cli02NRGProp.trim().isNotEmpty
            ? clienteData.cli02NRGProp.trim()
            : clienteData.cli00Insest.trim())
        : '-';

    final String endEnt = clienteData.cli00Endere.trim();
    final String numEnt = clienteData.cli00Endnum.trim();
    final String bairroEnt = clienteData.cli00Bairro.trim();
    final String cidEnt = clienteData.cli00Ciddes.trim();
    final String ufEnt = clienteData.cli00Estsgl.trim();
    final String email = clienteData.cli00Observ.trim();
    final String emailDanfe = clienteData.cli00Contat.trim();
    final String ramo = clienteData.ram00descri.trim();
    final double limite = clienteData.cli00Crelim;

    // Endereço de Cobrança
    final String endCob = usarMesmoEnderecoCobranca ? endEnt : endEnt;
    final String numCob = usarMesmoEnderecoCobranca ? numEnt : numEnt;
    final String bairroCob = usarMesmoEnderecoCobranca ? bairroEnt : bairroEnt;
    final String cidCob = usarMesmoEnderecoCobranca ? cidEnt : cidEnt;
    final String ufCob = usarMesmoEnderecoCobranca ? ufEnt : ufEnt;
    final String cepCob = usarMesmoEnderecoCobranca ? cepLimpo : cepLimpo;
    final String dddCob = usarMesmoEnderecoCobranca ? dddLimpo : dddLimpo;
    final String foneCob = usarMesmoEnderecoCobranca ? foneLimpo : foneLimpo;

    // 2. Determinação de Código do Cliente
    int idCliente = clienteData.cli00Codigo;
    final bool isNovo = (idCliente <= 0);
    if (isNovo) {
      idCliente = await LocalSalesDatabaseService.obterProximoCodigoCliente();
    }

    final String codigo16 = idCliente.toString().padLeft(16, '0');

    // 3. Persistência no SQLite local (cadcli00)
    final existing = await db.rawQuery(
      'SELECT cli00_codigo FROM cadcli00 WHERE cli00_codigo = ? LIMIT 1',
      [idCliente],
    );

    final Map<String, dynamic> rowValues = {
      'cli00_codigo': idCliente,
      'cli00_codigo16': codigo16,
      'cli00_descri': rSocial,
      'cli00_fantas': nFantasia,
      'cli00_typpes': tipoPessoaInt,
      'cli00_cpfcnp': cpfCnpjLimpo,
      'cli00_insest': iEst,
      'cli00_nrg': numRg,
      'cli00_email': email,
      'cli00_emaildanfe': emailDanfe,
      'cli00_ramo': ramo,
      'cli00_crelim': limite,
      'cli00_endere': endEnt,
      'cli00_endnum': numEnt,
      'cli00_bairro': bairroEnt,
      'cli00_ciddes': cidEnt,
      'cli00_estsgl': ufEnt,
      'cli00_endcep': cepLimpo,
      'cli00_fonddd': dddLimpo,
      'cli00_fonnum': foneLimpo,
      'cli00_observ': email,
      'cli00_active': 1,
      'cli00_endcob': endCob,
      'cli00_numcob': numCob,
      'cli00_bairrocob': bairroCob,
      'cli00_cidadecob': cidCob,
      'cli00_ufcob': ufCob,
      'cli00_cepcob': cepCob,
      'cli00_dddcob': dddCob,
      'cli00_fonecob': foneCob,
      'cli00_sttenv': 0, // Pendente de envio
    };

    if (existing.isNotEmpty) {
      final updateCols = rowValues.keys
          .where((k) => k != 'cli00_codigo')
          .map((k) => '$k = ?')
          .join(', ');
      final updateVals = rowValues.keys
          .where((k) => k != 'cli00_codigo')
          .map((k) => rowValues[k])
          .toList()
        ..add(idCliente);
      await db.rawUpdate(
        'UPDATE cadcli00 SET $updateCols WHERE cli00_codigo = ?',
        updateVals,
      );
    } else {
      final insertCols = rowValues.keys.join(', ');
      final insertPlaceholders =
          List.filled(rowValues.length, '?').join(', ');
      await db.rawInsert(
        'INSERT OR REPLACE INTO cadcli00 ($insertCols) VALUES ($insertPlaceholders)',
        rowValues.values.toList(),
      );
    }

    // 4. Geração do Arquivo XML de Integração
    final clientePayload = clienteData
      ..cli00Codigo = idCliente
      ..cli00Descri = rSocial
      ..cli00Fantas = nFantasia
      ..cli00Pessoa = tipoPessoaStr
      ..cli00Cpfcnp = cpfCnpjLimpo
      ..cli00Insest = iEst
      ..cli00Endcep = cepLimpo
      ..cli00Fonddd = dddLimpo
      ..cli00Fonnum = foneLimpo;

    final String xmlContent =
        ClienteXmlGeneratorService.build(clientePayload, codigoVendedor);

    final int codRep = int.tryParse(codigoVendedor.trim()) ?? 0;
    final int milId = retornaMil();

    // Nomenclatura oficial da especificação:
    // Novo cadastro: c<rep>-<mil>.xml
    // Edição: c<rep>-<codigo16>.xml
    final String fileName = isNovo
        ? FtpPathBuilder.getFileNameClienteMil(codRep, ms: milId)
        : 'c$codRep-$codigo16.xml';

    final tempDir = tempDirOverride ?? await getTemporaryDirectory();
    final docsDir = docsDirOverride ?? await getApplicationDocumentsDirectory();

    // Cria subpastas cli/ dedicadas
    final cliTempDir = Directory(p.join(tempDir.path, 'cli'));
    if (!await cliTempDir.exists()) {
      await cliTempDir.create(recursive: true);
    }

    final cliDocsDir = Directory(p.join(docsDir.path, 'cli'));
    if (!await cliDocsDir.exists()) {
      await cliDocsDir.create(recursive: true);
    }

    // Salva na subpasta cli/ e na raiz de temp para compatibilidade com o upload
    final fileSubdir = File(p.join(cliTempDir.path, fileName));
    await fileSubdir.writeAsString(xmlContent, flush: true);

    final fileTempRoot = File(p.join(tempDir.path, fileName));
    await fileTempRoot.writeAsString(xmlContent, flush: true);

    final fileDocs = File(p.join(cliDocsDir.path, fileName));
    await fileDocs.writeAsString(xmlContent, flush: true);

    // 5. Registra no manifesto de carga
    await CargaRegistryService().registrar(CargaRegistro(
      arquivo: fileName,
      tipo: TipoCarga.cliente,
      id: idCliente,
    ));

    return ResultadoSalvarCliente(
      success: true,
      clienteId: idCliente,
      xmlPath: fileSubdir.path,
      xmlNome: fileName,
      mensagem: isNovo
          ? 'Cliente cadastrado com sucesso!'
          : 'Cliente atualizado com sucesso!',
    );
  } catch (e, stack) {
    print('Erro ao salvar cliente offline: $e\n$stack');
    return ResultadoSalvarCliente(
      success: false,
      clienteId: 0,
      mensagem: 'Falha ao salvar cliente: $e',
    );
  }
}
