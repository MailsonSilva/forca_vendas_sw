import '../../backend/schema/structs/cliente_result_struct.dart';

/// Gera o payload XML do cadastro de cliente (pckvencli00) no protocolo
/// legado Suportware.
///
/// Envelope estrito (conforme `refatoração.md`):
/// ```xml
/// <!DOCTYPE suportware>
/// <root sys_versao="1.0" rep00_codigo="[CODIGO_REPRESENTANTE]">
///   <pckvencli00>
///     <row cli00_codigo="..." cli00_codigoRep="..." ... />
///   </pckvencli00>
/// </root>
/// ```
class ClienteXmlGeneratorService {
  /// Constrói a string XML do cliente. Pura (sem I/O) — o chamador decide
  /// onde gravar o arquivo.
  static String build(ClienteResultStruct clienteData, String codigoVendedor) {
    final StringBuffer xml = StringBuffer();

    xml.writeln('<!DOCTYPE suportware>');
    xml.writeln('<root sys_versao="1.0" rep00_codigo="${codigoVendedor.trim()}">');
    xml.writeln(' <pckvencli00>');

    // Tratamento para Novo Cadastro vs Edicao
    // Se for 0, o ERP legado interpreta cli00_codigo="0" como inclusao
    final int codCliInt = clienteData.cli00Codigo;
    final String codigoClienteXml =
        codCliInt == 0 ? "0" : codCliInt.toString();

    // Mapeamento dos atributos principais (cadcli00)
    final String rSocial = clienteData.cli00Descri.trim();
    final String nFantasia = clienteData.cli00Fantas.trim();
    final String tPessoa = clienteData.cli00Pessoa.trim() == 'J' ? '2' : '1';
    final String cpfCnpj = clienteData.cli00Cpfcnp.trim();
    final String iEst = clienteData.cli00Insest.trim();
    final String email = clienteData.cli00Observ.trim();
    final String endEnt = clienteData.cli00Endere.trim();
    final String numEnt = clienteData.cli00Endnum.trim();
    final String bairroEnt = clienteData.cli00Bairro.trim();
    final String cidadeEnt = clienteData.cli00Ciddes.trim();
    final String ufEnt = clienteData.cli00Estsgl.trim();
    final String cepEnt = clienteData.cli00Endcep.trim();
    final String dddEnt = clienteData.cli00Fonddd.trim();
    final String foneEnt = clienteData.cli00Fonnum.trim();
    final String limite = clienteData.cli00Crelim.toStringAsFixed(2);

    // Dados Complementares do Proprietario (cadcli02)
    final String nProp = clienteData.cli02NProp.trim();
    final String endProp = clienteData.cli02EndProp.trim();
    final String numProp = clienteData.cli02NumProp.trim();
    final String bairroProp = clienteData.cli02BairroProp.trim();
    final String cidadeProp = clienteData.cli02CidadeProp.trim();
    final String ufProp = clienteData.cli02UfProp.trim();
    final String cpfProp = clienteData.cli02CpfProp.trim();
    final String rgProp = clienteData.cli02NRGProp.trim();
    final String orgProp = clienteData.cli02OrgaoProp.trim();
    final String conjProp = clienteData.cli02ConjugeProp.trim();
    final String cpfConj = clienteData.cli02CpfConjProp.trim();
    final String rgConj = clienteData.cli02NRGConjProp.trim();
    final String orgConj = clienteData.cli02OrgaoConjProp.trim();

    // Montagem da Tag com o cli00_codigoRep preenchido dinamicamente
    xml.write('   <row cli00_codigo="$codigoClienteXml" ');
    xml.write('cli00_codigoRep="${codigoVendedor.trim()}" ');
    xml.write('cli00_rSocial="$rSocial" ');
    xml.write('cli00_nFantasia="$nFantasia" ');
    xml.write('cli00_tPessoa="$tPessoa" ');
    xml.write('cli00_cpfcnpj="$cpfCnpj" ');
    xml.write('cli00_iEst="$iEst" ');
    xml.write('cli00_nRG="$rgProp" ');
    xml.write('cli00_email="$email" ');
    xml.write('cli00_ramo="" ');
    xml.write('cli00_emailDanfe="" ');
    xml.write('cli00_limite="$limite" ');
    xml.write('cli00_endEnt="$endEnt" ');
    xml.write('cli00_numEnt="$numEnt" ');
    xml.write('cli00_bairroEnt="$bairroEnt" ');
    xml.write('cli00_cidadeEnt="$cidadeEnt" ');
    xml.write('cli00_ufEnt="$ufEnt" ');
    xml.write('cli00_cepEnt="$cepEnt" ');
    xml.write('cli00_dddEnt="$dddEnt" ');
    xml.write('cli00_foneEnt="$foneEnt" ');
    xml.write('cli00_faxEnt="" ');
    xml.write('cli00_endCob="$endEnt" ');
    xml.write('cli00_numCob="$numEnt" ');
    xml.write('cli00_bairroCob="$bairroEnt" ');
    xml.write('cli00_cidadeCob="$cidadeEnt" ');
    xml.write('cli00_ufCob="$ufEnt" ');
    xml.write('cli00_cepCob="$cepEnt" ');
    xml.write('cli00_dddCob="$dddEnt" ');
    xml.write('cli00_foneCob="$foneEnt" ');
    xml.write('cli00_faxCob="" ');
    xml.write('cli00_nProp="$nProp" ');
    xml.write('cli00_endProp="$endProp" ');
    xml.write('cli00_numProp="$numProp" ');
    xml.write('cli00_bairroProp="$bairroProp" ');
    xml.write('cli00_cidadeProp="$cidadeProp" ');
    xml.write('cli00_ufProp="$ufProp" ');
    xml.write('cli00_cpfProp="$cpfProp" ');
    xml.write('cli00_orgaoProp="$orgProp" ');
    xml.write('cli00_conjugeProp="$conjProp" ');
    xml.write('cli00_cpfConjProp="$cpfConj" ');
    xml.write('cli00_nRGConjProp="$rgConj" ');
    xml.write('cli00_orgaoConjProp="$orgConj" ');

    // Referencias Bancarias (cadcli03)
    final listBanc = clienteData.bancosList;
    for (int i = 0; i < 6; i++) {
      final int idx = i + 1;
      String nBnc = "";
      String dddBnc = "";
      String foneBnc = "";

      if (i < listBanc.length) {
        nBnc = listBanc[i].nomeBanco;
        dddBnc = listBanc[i].ddd;
        foneBnc = listBanc[i].telefone;
      }
      xml.write('cli00_nBnc${idx}Ban="$nBnc" ');
      xml.write('cli00_dddBnc${idx}Ban="$dddBnc" ');
      xml.write('cli00_foneBnc${idx}Ban="$foneBnc" ');
    }

    xml.writeln('/>');
    xml.writeln(' </pckvencli00>');
    xml.writeln('</root>');

    return xml.toString();
  }
}
