SPEC-046: Gerenciamento dos Sequenciais de Pedido (dig00_digcod) e Pacote (pac00_paccod)MetadadoDetalheMóduloDigitação de Pedidos (pckvendig00) e Geração de Pacotes (pckvenpac00)  Arquivo Referênciaffrmdiggerpac00.cpp (método TGerPacvendig00List::doIncludePAC)  Bancos SQLitedbforcadig001.db (Movimento local de digitação e pacotes)  StatusPronto para Execução1. Regra de Negócio: Sequencial do Pedido (dig00_digcod)Origem Inicial: O ERP envia na carga inicial o último sequencial faturado/gerado para o vendedor.Comportamento no Flutter ao Criar Novo Pedido:A aplicação consulta o banco de digitação local:SQLSELECT COALESCE(MAX(dig00_digcod), 0) AS ultimo_pedido 
FROM pckvendig00;
Se a tabela local retornar 0, recupera o valor padrão de cadrep00 / configuração de carga inicial.O novo pedido é instanciado com:$$\text{novoCodigoPedido} = \text{ultimo\_pedido} + 1$$O cabeçalho é persistido em pckvendig00 com dig00_digcod = novoCodigoPedido.  2. Regra de Negócio: Sequencial do Pacote (pac00_paccod / .pac)Comportamento no Flutter ao Gerar Pacote (ffrmdiggerpac00):  O código busca o último sequencial de pacote gerado localmente na tabela pckvenpac00:  SQLSELECT COALESCE(MAX(pac00_paccod), 0) AS ultimo_pacote 
FROM pckvenpac00;
Regra de Faixa (C++ Legado):Se ultimo_pacote < 1000 ou ultimo_pacote >= 9999, reinicia a sequência em 1000.  Caso contrário:$$\text{ipac} = \text{ultimo\_pacote} + 1$$Persistência na pckvenpac00:  Insere o registro do pacote com pac00_paccod = ipac e pac00_pacrep = ven00_codigo.  Atualização nos Pedidos Vinculados (pckvendig00):  Atualiza os pedidos que foram marcados no checkbox:dig00_paccod = ipac  dig00_pacstr = 'p' + ven00_codigo + '-' + ipac (exemplo: p71-1000)  dig00_sttenv = 2 (pvddeEMPACOTE)  dig00_datenv = DataAtual  Nomenclatura do Arquivo Físico:$$\text{nomeArquivo} = \mathbf{p\langle ven00\_codigo\rangle-\langle ipac\rangle.pac} \quad \text{[cite: 1, 2]}$$3. Implementação de Referência em DartDartclass SequenceGeneratorService {
  final Database dbDig; // Instância de dbforcadig001.db

  SequenceGeneratorService(this.dbDig);

  /// Obtém o próximo código sequencial do pedido (+1)
  Future<int> obterProximoCodigoPedido(int filial, int codigoVendedor) async {
    final result = await dbDig.rawQuery('''
      SELECT COALESCE(MAX(dig00_digcod), 0) AS max_cod 
      FROM pckvendig00 
      WHERE dig00_digfil = ?
    ''', [filial]);

    final maxCod = (result.first['max_cod'] as int?) ?? 0;
    return maxCod + 1;
  }

  /// Obtém o próximo código de pacote (+1) mantendo a faixa 1000-9999
  Future<int> obterProximoCodigoPacote(int codigoVendedor) async {
    final result = await dbDig.rawQuery('''
      SELECT COALESCE(MAX(pac00_paccod), 0) AS max_pac 
      FROM pckvenpac00 
      WHERE pac00_pacrep = ?
    ''', [codigoVendedor]);

    final maxPac = (result.first['max_pac'] as int?) ?? 0;
    
    // Regra oficial do ffrmdiggerpac00.cpp:
    if (maxPac < 1000 || maxPac >= 9999) {
      return 1000;
    }
    return maxPac + 1;
  }
}
4. Critérios de Aceite[ ] A geração de novo pedido busca sempre MAX(dig00_digcod) + 1 dentro da tabela local pckvendig00.[ ] A geração de pacote busca MAX(pac00_paccod) + 1 dentro da tabela pckvenpac00.  [ ] Caso não haja pacotes no aparelho ou ultrapasse 9999, a numeração do pacote começa obrigatoriamente em 1000.  [ ] O nome do arquivo .pac e o campo dig00_pacstr são gravados estritamente no padrão p<ven00_codigo>-<ipac>.pac (ex: p71-1000.pac).  [ ] Os pedidos incluídos no pacote são atualizados com dig00_sttenv = 2 (pvddeEMPACOTE) e dig00_paccod = ipac.  