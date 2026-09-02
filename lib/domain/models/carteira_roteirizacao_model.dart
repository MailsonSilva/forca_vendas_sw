library;

/// Modelos de domínio para o Módulo de Carteira de Clientes e Roteirização (`ffrmrelclirot00`).
/// Mapeia a tabela `cadcli00`, status de crédito e coordenadas georreferenciadas.

enum StatusCreditoCliente {
  inadimplente, // cli00_titven > 0 (Vermelho)
  titulosAVencer, // cli00_titave > 0 e titven == 0 (Amarelo)
  regular, // titven == 0 e titave == 0 (Verde)
}

class ClienteRoteiroItem {
  final int codigo;
  final String razaoSocial;
  final String nomeFantasia;
  final String endereco;
  final String cidade;
  final String uf;
  final String ddd;
  final String telefone;
  final String cpfCnpj;
  final double limiteOriginal;
  final double limiteAtual;
  final DateTime? dataUltimaCompra;
  final int tipoPessoa; // 1 = Física, 2 = Jurídica
  final bool ativo; // cli00_active == 1
  final String observacao;
  final double titulosVencidos;
  final double titulosAVencer;
  final int diaVisita; // 1=Segunda ... 7=Domingo, 0=Sem Rota
  final double? latitude;
  final double? longitude;

  const ClienteRoteiroItem({
    required this.codigo,
    required this.razaoSocial,
    required this.nomeFantasia,
    required this.endereco,
    required this.cidade,
    required this.uf,
    required this.ddd,
    required this.telefone,
    required this.cpfCnpj,
    required this.limiteOriginal,
    required this.limiteAtual,
    this.dataUltimaCompra,
    required this.tipoPessoa,
    required this.ativo,
    required this.observacao,
    required this.titulosVencidos,
    required this.titulosAVencer,
    required this.diaVisita,
    this.latitude,
    this.longitude,
  });

  bool get possuiInadimplencia => titulosVencidos > 0.0;
  bool get possuiTitulosAVencer => titulosAVencer > 0.0 && titulosVencidos == 0.0;
  bool get isRegular => titulosVencidos == 0.0 && titulosAVencer == 0.0;
  bool get hasCoordenadas => latitude != null && longitude != null && latitude != 0.0 && longitude != 0.0;

  StatusCreditoCliente get statusCredito {
    if (possuiInadimplencia) return StatusCreditoCliente.inadimplente;
    if (possuiTitulosAVencer) return StatusCreditoCliente.titulosAVencer;
    return StatusCreditoCliente.regular;
  }

  String get statusCreditoDescricao {
    switch (statusCredito) {
      case StatusCreditoCliente.inadimplente:
        return 'Inadimplente (Títulos Vencidos)';
      case StatusCreditoCliente.titulosAVencer:
        return 'Títulos a Vencer';
      case StatusCreditoCliente.regular:
        return 'Crédito Regular';
    }
  }

  String get diaVisitaDescricao {
    switch (diaVisita) {
      case 1:
        return 'Segunda-Feira';
      case 2:
        return 'Terça-Feira';
      case 3:
        return 'Quarta-Feira';
      case 4:
        return 'Quinta-Feira';
      case 5:
        return 'Sexta-Feira';
      case 6:
        return 'Sábado';
      case 7:
        return 'Domingo';
      case 0:
      default:
        return 'Sem Rota Fixa';
    }
  }

  String get telefoneFormatado {
    final t = telefone.trim();
    final d = ddd.trim();
    if (t.isEmpty) return '';
    return d.isNotEmpty ? '($d) $t' : t;
  }

  String get enderecoCompleto {
    final parts = [endereco, cidade, uf].where((s) => s.trim().isNotEmpty).toList();
    return parts.join(' - ');
  }

  factory ClienteRoteiroItem.fromMap(Map<String, dynamic> map) {
    final cod = (map['cli00_codigo'] as num?)?.toInt() ?? 0;
    final razao = map['cli00_descri']?.toString() ?? 'Cliente #$cod';
    final fantasia = map['cli00_fantas']?.toString() ?? '';
    final end = map['cli00_endere']?.toString() ?? '';
    final cid = map['cli00_ciddes']?.toString() ?? '';
    final siglaUf = map['cli00_estsgl']?.toString() ?? '';
    final dddNum = map['cli00_fonddd']?.toString() ?? '';
    final fone = map['cli00_fonnum']?.toString() ?? '';
    final doc = map['cli00_cpfcnp']?.toString() ?? '';
    final limOrig = (map['cli00_crelim'] as num?)?.toDouble() ?? 0.0;
    final limAtu = (map['cli00_creatu'] as num?)?.toDouble() ?? 0.0;
    final tipPes = (map['cli00_typpes'] as num?)?.toInt() ?? (map['cli00_pessoa'] == 'F' ? 1 : 2);
    final isAtivo = (map['cli00_active'] as num?)?.toInt() == 1 || map['cli00_active'] == true;
    final obs = map['cli00_observ']?.toString() ?? '';
    final titVen = (map['cli00_titven'] as num?)?.toDouble() ?? 0.0;
    final titAve = (map['cli00_titave'] as num?)?.toDouble() ?? 0.0;
    final diaVis = (map['cli00_flgven'] as num?)?.toInt() ?? 0;

    DateTime? ultCompra;
    if (map['cli00_datcom'] != null) {
      ultCompra = DateTime.tryParse(map['cli00_datcom'].toString());
    }

    final lat = (map['cli16_codlat'] as num?)?.toDouble() ?? (map['cli00_lat'] as num?)?.toDouble();
    final lon = (map['cli16_codlon'] as num?)?.toDouble() ?? (map['cli00_lon'] as num?)?.toDouble();

    return ClienteRoteiroItem(
      codigo: cod,
      razaoSocial: razao,
      nomeFantasia: fantasia,
      endereco: end,
      cidade: cid,
      uf: siglaUf,
      ddd: dddNum,
      telefone: fone,
      cpfCnpj: doc,
      limiteOriginal: limOrig,
      limiteAtual: limAtu,
      dataUltimaCompra: ultCompra,
      tipoPessoa: tipPes,
      ativo: isAtivo,
      observacao: obs,
      titulosVencidos: titVen,
      titulosAVencer: titAve,
      diaVisita: diaVis,
      latitude: lat,
      longitude: lon,
    );
  }
}

class RoteirizacaoFiltro {
  final int diaVisita; // 1=Seg ... 7=Dom, 0=Sem Rota, -1=Todos
  final int statusAtivo; // 1=Ativos, 0=Inativos, -1=Todos
  final int tipoPessoa; // 1=Física, 2=Jurídica, -1=Todos
  final String? uf;
  final String? cidade;
  final String? buscaTexto;

  const RoteirizacaoFiltro({
    this.diaVisita = -1,
    this.statusAtivo = 1, // Default apenas ativos
    this.tipoPessoa = -1,
    this.uf,
    this.cidade,
    this.buscaTexto,
  });

  RoteirizacaoFiltro copyWith({
    int? diaVisita,
    int? statusAtivo,
    int? tipoPessoa,
    String? uf,
    String? cidade,
    String? buscaTexto,
  }) {
    return RoteirizacaoFiltro(
      diaVisita: diaVisita ?? this.diaVisita,
      statusAtivo: statusAtivo ?? this.statusAtivo,
      tipoPessoa: tipoPessoa ?? this.tipoPessoa,
      uf: uf ?? this.uf,
      cidade: cidade ?? this.cidade,
      buscaTexto: buscaTexto ?? this.buscaTexto,
    );
  }
}

class CarteiraRoteirizacaoResumo {
  final int totalClientes;
  final int totalInadimplentes;
  final int totalTitulosAVencer;
  final int totalRegulares;
  final List<ClienteRoteiroItem> clientes;

  const CarteiraRoteirizacaoResumo({
    required this.totalClientes,
    required this.totalInadimplentes,
    required this.totalTitulosAVencer,
    required this.totalRegulares,
    required this.clientes,
  });

  factory CarteiraRoteirizacaoResumo.fromClientes(List<ClienteRoteiroItem> clientes) {
    int inad = 0;
    int aVencer = 0;
    int reg = 0;

    for (final c in clientes) {
      if (c.possuiInadimplencia) {
        inad++;
      } else if (c.possuiTitulosAVencer) {
        aVencer++;
      } else {
        reg++;
      }
    }

    return CarteiraRoteirizacaoResumo(
      totalClientes: clientes.length,
      totalInadimplentes: inad,
      totalTitulosAVencer: aVencer,
      totalRegulares: reg,
      clientes: clientes,
    );
  }

  factory CarteiraRoteirizacaoResumo.empty() {
    return const CarteiraRoteirizacaoResumo(
      totalClientes: 0,
      totalInadimplentes: 0,
      totalTitulosAVencer: 0,
      totalRegulares: 0,
      clientes: [],
    );
  }
}
