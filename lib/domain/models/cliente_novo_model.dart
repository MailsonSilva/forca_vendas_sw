/// Modelo de dados representativo para novos cadastros de clientes locais.
class ClienteNovo {
  final int? codigo;
  final int? codRep;
  final String razaoSocial;
  final String nomeFantasia;
  final String cpfCnpj;
  final String? inscricaoEstadual;
  final String? rg;
  final String endereco;
  final String? numero;
  final String? bairro;
  final String cidade;
  final String uf;
  final String cep;
  final String ddd;
  final String telefone;
  final String? email;
  final double? limiteCredito;
  final String statusEnvio;
  final int novoLocal;

  ClienteNovo({
    this.codigo,
    this.codRep,
    required this.razaoSocial,
    required this.nomeFantasia,
    required this.cpfCnpj,
    this.inscricaoEstadual,
    this.rg,
    required this.endereco,
    this.numero,
    this.bairro,
    required this.cidade,
    required this.uf,
    required this.cep,
    required this.ddd,
    required this.telefone,
    this.email,
    this.limiteCredito,
    this.statusEnvio = 'pendente_envio',
    this.novoLocal = 1,
  });

  Map<String, dynamic> toMap() {
    return {
      if (codigo != null && codigo! > 0) 'cli00_codigo': codigo,
      'cli00_codrep': codRep,
      'cli00_descri': razaoSocial.toUpperCase().trim(),
      'cli00_fantas': nomeFantasia.trim(),
      'cli00_cpfcnp': cpfCnpj.replaceAll(RegExp(r'\D'), ''),
      'cli00_insest': inscricaoEstadual ?? '-',
      'cli00_nrg': rg ?? '-',
      'cli00_endere': endereco.trim(),
      'cli00_endnum': (numero ?? '').trim(),
      'cli00_bairro': (bairro ?? '').trim(),
      'cli00_ciddes': cidade.trim(),
      'cli00_estsgl': uf.trim(),
      'cli00_endcep': cep.replaceAll(RegExp(r'\D'), ''),
      'cli00_fonddd': ddd.replaceAll(RegExp(r'\D'), ''),
      'cli00_fonnum': telefone.replaceAll(RegExp(r'\D'), ''),
      'cli00_observ': email ?? '',
      'cli00_crelim': limiteCredito ?? 0.0,
      'cli00_active': 1,
      'novo_local': novoLocal,
      'status_envio': statusEnvio,
    };
  }

  factory ClienteNovo.fromMap(Map<String, dynamic> map) {
    return ClienteNovo(
      codigo: (map['cli00_codigo'] as num?)?.toInt(),
      codRep: (map['cli00_codrep'] as num?)?.toInt(),
      razaoSocial: map['cli00_descri']?.toString() ?? '',
      nomeFantasia: map['cli00_fantas']?.toString() ?? '',
      cpfCnpj: map['cli00_cpfcnp']?.toString() ?? '',
      inscricaoEstadual: map['cli00_insest']?.toString(),
      rg: map['cli00_nrg']?.toString(),
      endereco: map['cli00_endere']?.toString() ?? '',
      numero: map['cli00_endnum']?.toString(),
      bairro: map['cli00_bairro']?.toString(),
      cidade: map['cli00_ciddes']?.toString() ?? '',
      uf: map['cli00_estsgl']?.toString() ?? '',
      cep: map['cli00_endcep']?.toString() ?? '',
      ddd: map['cli00_fonddd']?.toString() ?? '',
      telefone: map['cli00_fonnum']?.toString() ?? '',
      email: map['cli00_observ']?.toString(),
      limiteCredito: (map['cli00_crelim'] as num?)?.toDouble() ?? 0.0,
      statusEnvio: map['status_envio']?.toString() ?? 'pendente_envio',
      novoLocal: (map['novo_local'] as num?)?.toInt() ?? 1,
    );
  }
}
