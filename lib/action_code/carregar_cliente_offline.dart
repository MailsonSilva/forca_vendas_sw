// Imports do app
import '/backend/schema/structs/index.dart';
// Imports other custom actions
// Imports custom functions
// Begin custom action code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

Future<ClienteResultStruct?> carregarClienteOffline(int codigo) async {
  try {
    final dbPath = join(await getDatabasesPath(), 'dbforcacad001.db');
    final db = await openDatabase(dbPath);

    final List<Map<String, dynamic>> results = await db.rawQuery(
      '''
      SELECT c.*, r.ram00_descri
      FROM cadcli00 c
      LEFT JOIN cadram00 r ON r.ram00_codigo = c.cli00_codram
      WHERE c.cli00_codigo = ?      
      ''',
      [codigo],
    );
    await db.close();

    if (results.isEmpty) {
      print('Nenhum cliente encontrado');
      return null;
    }

    final m = results.first;

// Lógica Customizada com o nome duplicado gerado pelo Flutter
/*    final List<BancoInfoStructStruct> listaBancos = [];
    for (int i = 1; i <= 6; i++) {
      final String? nomeBanco = m['cli03_nBnc${i}Ban']?.toString();
      final String ddd = m['cli03_dddBnc${i}Ban']?.toString() ?? '';
      final String fone = m['cli03_foneBnc${i}Ban']?.toString() ?? '';

      if (nomeBanco != null && nomeBanco.trim().isNotEmpty) {
        listaBancos.add(BancoInfoStructStruct(
          nomeBanco: nomeBanco.trim(),
          ddd: ddd.trim(),
          telefone: fone.trim(),
        ));
      }
    }
*/
    return ClienteResultStruct(
      cli00Codigo: m['cli00_codigo'] as int?,
      cli00Descri: m['cli00_descri']?.toString() ?? '',
      cli00Fantas: m['cli00_fantas']?.toString() ?? '',
      cli00Endere: m['cli00_endere']?.toString() ?? '',
      cli00Endnum: m['cli00_endnum']?.toString() ?? '',
      cli00Bairro: m['cli00_bairro']?.toString() ?? '',
      cli00Cidcod: m['cli00_cidcod'] as int?,
      cli00Ciddes: m['cli00_ciddes']?.toString() ?? '',
      cli00Estcod: m['cli00_estcod'] as int?,
      cli00Estsgl: m['cli00_estsgl']?.toString() ?? '',
      cli00Endcep: m['cli00_endcep']?.toString() ?? '',
      cli00Fonddd: m['cli00_fonddd']?.toString() ?? '',
      cli00Fonnum: m['cli00_fonnum']?.toString() ?? '',
      cli00Cpfcnp: m['cli00_cpfcnp']?.toString() ?? '',
      cli00Insest: m['cli00_insest']?.toString() ?? '',
      cli00Datcad: m['cli00_datcad'] != null
          ? DateTime.tryParse(m['cli00_datcad'].toString())
          : null,
      cli00Datcom: m['cli00_datcom'] != null
          ? DateTime.tryParse(m['cli00_datcom'].toString())
          : null,
      cli00Active: m['cli00_active'] as int?,
      cli00Observ: m['cli00_observ']?.toString() ?? '',
      cli00Crelim: (m['cli00_crelim'] as num?)?.toDouble() ?? 0.0,
      cli00Creatu: (m['cli00_creatu'] as num?)?.toDouble() ?? 0.0,
      cli00Pessoa: m['cli00_pessoa']?.toString() ?? '',
      cli00Typpes: m['cli00_typpes'] as int?,
      cli00Contat: m['cli00_contat']?.toString() ?? '',
      cli00Codram: m['cli00_codram'] as int?,
      ram00descri: m['ram00_descri']?.toString() ?? '',
      cli00Datfun: m['cli00_datfun'] != null
          ? DateTime.tryParse(m['cli00_datfun'].toString())
          : null,
      cli00Codrep: m['cli00_codrep'] as int?,
      cli00Codsup: m['cli00_codsup'] as int?,
      cli00Titven: (m['cli00_titven'] as num?)?.toDouble() ?? 0.0,
      cli00Titave: (m['cli00_titave'] as num?)?.toDouble() ?? 0.0,
      cli00Ttlrec: (m['cli00_ttlrec'] as num?)?.toDouble() ?? 0.0,
      cli00Flgven: m['cli00_flgven'] as int?,
      cli00Codage: m['cli00_codage'] as int?,
      cli00Deffidcod: m['cli00_deffidcod'] as int?,
      cli00Typpco: m['cli00_typpco'] as int?,
      cli00Codreg: m['cli00_codreg'] as int?,
      cli00Fattotign: m['cli00_fattotign'] as int?,
      cli00Vengerntf: m['cli00_vengerntf'] as int?,

      // Dados do Proprietário e Cônjuge (cadcli02)
      cli02NProp: m['cli02_nProp']?.toString() ?? '',
      cli02EndProp: m['cli02_endProp']?.toString() ?? '',
      cli02NumProp: m['cli02_numProp']?.toString() ?? '',
      cli02BairroProp: m['cli02_bairroProp']?.toString() ?? '',
      cli02CidadeProp: m['cli02_cidadeProp']?.toString() ?? '',
      cli02UfProp: m['cli02_ufProp']?.toString() ?? '',
      cli02NRGProp: m['cli02_nRGProp']?.toString() ?? '',
      cli02OrgaoProp: m['cli02_orgaoProp']?.toString() ?? '',
      cli02CpfProp: m['cli02_cpfProp']?.toString() ?? '',
      cli02ConjugeProp: m['cli02_conjugeProp']?.toString() ?? '',
      cli02NRGConjProp: m['cli02_nRGConjProp']?.toString() ?? '',
      cli02OrgaoConjProp: m['cli02_orgaoConjProp']?.toString() ?? '',
      cli02CpfConjProp: m['cli02_cpfConjProp']?.toString() ?? '',

      // Mapeamento da lista de bancos estruturada
      //bancosList: listaBancos,
    );
  } catch (e) {
    print('Erro fatal ao carregar cliente offline: \$e');
    return null;
  }
}
