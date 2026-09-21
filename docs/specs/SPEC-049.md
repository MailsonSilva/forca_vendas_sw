# SPEC-049: Pacote de Melhorias de Usabilidade, Performance e Multi-Filial

| Metadado | Detalhe |
| :--- | :--- |
| **Módulos Afetados** | Autenticação (`LoginPage`), Home (`HomePage`), Catálogo (`BuscaProdutoPageWidget`), Digitação (`PedidoNovoInicioWidget`, `CardProdutoItem`), Configurações (`ConfiguracoesPage`) |
| **Tabelas / Banco** | `cadrep00` (`ven00_selfil`, `ven00_codfil`), `estpro00` (`pro00_codfil`), `cadlin00`, `pckvendig00` |
| **Status** | Pronto para Execução via TDD / Triagem |

---

## 1. Tela de Login & Carga Inicial

### 1.1. Dimensão da Logo Inicial
* **Problema:** No primeiro acesso (sem banco local ou carga prévia), o asset `assets/images/logo.png` é renderizado muito pequeno.
* **Correção:** Dobrar as dimensões do widget de imagem (ex.: de `height: 80, width: 80` para `height: 160, width: 160` ou aplicar restrições proporcionais com `MediaQuery.sizeOf(context).width * 0.5`)[cite: 4].

### 1.2. Sanitização de Inputs (Caixa Alta Obrigatória)
* **Campos:** `Código da Empresa` e `Código do Vendedor`.
* **Implementação:** Aplicar `inputFormatters` com `UpperCaseTextFormatter` nativo nos `TextFormField`:
  ```dart
  class UpperCaseTextFormatter extends TextInputFormatter {
    @override
    TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
      return TextEditingValue(
        text: newValue.text.toUpperCase(),
        selection: newValue.selection,
      );
    }
  }
1.3. Gestão de Foco e Ação do Teclado Virtual (TextInputAction)Campo Código da Empresa:textInputAction: TextInputAction.nextonFieldSubmitted: (_) => FocusScope.of(context).requestFocus(_vendedorFocusNode)Regra: Não disparar a submissão de login ao tocar em "Avançar/Next" neste campo.Campo Código do Vendedor:textInputAction: TextInputAction.go (ou .done)onFieldSubmitted: (_) => _executarLogin()O login só é acionado se o usuário clicar no botão principal de acesso ou confirmar no teclado nativo dentro do campo de vendedor preenchido.1.4. Feedback Visual de Carga e Tratamento Amigável de FalhaIndicador de Progresso: Durante o download e importação da primeira carga (fcfGETCRG = 3), exibir overlay/card com CircularProgressIndicator e a mensagem:"Atualizando Carga Inicial..."Tratamento de Exceção/Ausência de Carga: Se o download falhar ou o servidor FTP não responder:Apresentar diálogo com tom colaborativo e claro:"Não foi possível obter a carga inicial de dados. Verifique sua conexão com a internet ou entre em contato com a equipe de suporte técnico."Adicionar botão com ícone do WhatsApp que executa launchUrl:Dartfinal uri = Uri.parse("[https://wa.me/559881283380?text=Ol%C3%A1%2C%20ocorreu%20uma%20falha%20ao%20baixar%20a%20carga%20inicial%20no%20app](https://wa.me/559881283380?text=Ol%C3%A1%2C%20ocorreu%20uma%20falha%20ao%20baixar%20a%20carga%20inicial%20no%20app).");
[cite: 5]2. Reordenação dos Menus da HomeOrganização do grid de navegação principal da HomePage:Plaintext┌───────────────────────┬───────────────────────┐
│        Pedidos        │        Clientes       │
├───────────────────────┼───────────────────────┤
│        Produtos       │        Receber        │
├───────────────────────┼───────────────────────┤
│       Relatórios      │      Ferramentas      │
└───────────────────────┴───────────────────────┘
Regra: O item Ferramentas passa a ser posicionado estritamente na 6ª posição (último quadrante inferior direito).3. Catálogo de Produtos & Otimização de Performance3.1. Ajuste Tipográfico do PlaceholderNo TextField de busca da BuscaProdutoPageWidget, reduzir o hintStyle:DarthintStyle: TextStyle(fontSize: 12.0, color: Colors.grey.shade500)
3.2. Paginação Infinita com Scroll Virtual (100 em 100)Problema: O carregamento síncrono ou massivo de toda a base de cadpro00 gera travamentos de frame e latência na abertura da página.Mecanismo:Manter a busca por texto intocada.Implementar paginação incremental via SQLite utilizando LIMIT 100 OFFSET :offset.Vincular ScrollController ao ListView.builder:Dart_scrollController.addListener(() {
  if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 300) {
    if (!_isLoadingMore && _hasMoreItems) {
      _carregarProximaPaginaProdutos();
    }
  }
});
3.3. Cache em Memória dos Filtros AvançadosProblema: Demora ao abrir o modal/combobox de filtros avançados.Causa: Execução recorrente de consultas pesadas com SELECT DISTINCT em tabelas cadastrais no momento da abertura do modal.Correção: Carregar as listas de Linhas, Grupos e Marcas uma única vez durante o initState da página e mantê-las em cache na memória do controller (List<FiltroItemDTO>). O clique no filtro deve abrir o modal de forma síncrona e instantânea.4. Fluxo de Digitação de Novo Pedido4.1. Auto-seleção de Componentes ÚnicosNa etapa inicial do pedido (PedidoNovoInicioWidget):Se a consulta de Linhas de Produtos (cadlin00) retornar exatamente 1 registro, aplicar a seleção automática deste item (linhaSelecionada = linhas.first), eliminando a necessidade de clique do operador.O mesmo comportamento aplica-se a dropdowns similares que possuam apenas uma opção elegível.4.2. Digitação Numérica Direta da QuantidadeComponente: Seletor de quantidade no item do pedido (CardProdutoItem / modal de adição).Problema: Inserir altas quantidades (ex: 100 unidades) exigia 100 toques sequenciais no botão [+].Correção:Substituir o widget Text estático central entre os botões [-] e [+] por um TextFormField numérico.Parâmetros do campo:keyboardType: TextInputType.numberinputFormatters: [FilteringTextInputFormatter.digitsOnly]textAlign: TextAlign.centerAo receber foco (onTap), executar seleção total do texto (controller.selection = TextSelection(baseOffset: 0, extentOffset: controller.text.length)).onChanged(val): Recalcular em tempo real o subtotal do item ($\text{quantidade} \times \text{preço}$) com suporte aos limites mínimos e múltiplos de embalagem (pro02_mulemb).   5. Tela de Configurações: Versão do AppNa parte inferior da ConfiguracoesPage:Utilizar o pacote package_info_plus para obter os metadados do binário:Dartfinal info = await PackageInfo.fromPlatform();
// Exibe: "Versão: ${info.version}+${info.buildNumber}"
Centralizar o texto em tipografia discreta (fontSize: 11.0, color: Colors.grey).6. Regra Canônica de Negócio: Múltiplas FiliaisA dinâmica de filiais segue rigorosamente os dados da carga do representante (cadrep00):Parâmetros no Banco Local (cadrep00):ven00_selfil: Flag de permissão (0 = Monofilial travada; 1 = Permite seleção de filiais).ven00_codfil: Código da filial padrão do representante.   Avaliação no Pós-Login:Caso A (ven00_selfil == 0):O sistema define a filial ativa da sessão como cadrep00.ven00_codfil sem exibir diálogos.   Caso B (ven00_selfil == 1):O sistema consulta as filiais ativas através do estoque da base:SQLSELECT DISTINCT pro00_codfil FROM estpro00 ORDER BY pro00_codfil ASC;
   Se houver 2 ou mais filiais distintas, abre compulsoriamente o ModalSelecaoFilialWidget via showAppModalBottomSheet com useSafeArea: true e SafeArea(bottom: true).A filial selecionada é gravada no estado da sessão (AppSession.filialAtiva).Propagação nas Operações:Pedidos: Cabeçalho com pckvendig00.dig00_digfil = filialAtiva.   Itens: Cada item com pckvendig01.dig01_digfil = filialAtiva.   Estoque do Catálogo: Saldo isolado onde estpro00.pro00_codfil = filialAtiva.   Identificador no Menu: Exibir na barra superior ou drawer a filial ativa corrente (ex: "Filial: 01").