# ESPECIFICAÇÃO TÉCNICA E REGRAS DE NEGÓCIO: CARTEIRA DE CLIENTES E ROTEIRIZAÇÃO (ROTA)

Esta especificação técnica detalha todos os requisitos funcionais, regras de faturamento, interações no banco de dados SQLite local, fluxos visuais de interface e as diretrizes de migração para o módulo de **Carteira de Clientes e Roteirização** (Roteiro de Visitas) da aplicação móvel de Força de Vendas (FV). O documento baseia-se na engenharia reversa do formulário legado **`ffrmrelclirot00.cpp/.h`**, sua interface **`ui_ffrmrelclirot00.h`** e a classe de representação de registros **`ItemCLI`**.

---

## 1. Visão Geral do Módulo

O **Relatório de Carteira de Clientes e Roteirização** (`ffrmrelclirot00`) é a ferramenta de planejamento de campo do vendedor. Suas principais finalidades são:
1. **Roteirização Diária:** Listar os clientes cuja visita está agendada para o dia atual ou dias subsequentes da semana, de acordo com o plano de rotas gerado pela central.
2. **Análise de Crédito no Ponto de Venda:** Exibir um panorama imediato da saúde financeira dos clientes diretamente na listagem, sinalizando com cores de alerta aqueles que possuem inadimplência ou títulos vencidos/a vencer.
3. **Georreferenciamento:** Fornecer coordenadas geográficas (latitude e longitude) para orientar o deslocamento físico do representante até o cliente e permitir a auditoria de visitas presenciais.

---

## 2. Máquina de Estados Visual (Filtros vs. Lista de Resultados)

A interface de roteirização opera sob um modelo de **dois frames sobrepostos** que cobrem a tela principal (`centralWidget`) sequencialmente para poupar recursos em telas de baixa resolução:

```
    ┌──────────────────────────────────┐          Sincronizar / Carregar
    │   frmfilter (Página de Filtros)  │ ─────────────────────────────────┐
    └─────────────────▲────────────────┘                                  │
                      │                                                   ▼
            btnfilter00 (Voltar)                        ┌──────────────────────────────────┐
                      │                                 │   frmresult (Lista de Clientes)  │
                      └─────────────────────────────────│          - Grid: cgridcli        │
                                                        └──────────────────────────────────┘
```

*   **Página de Filtros (`frmfilter` / `doPageFilterShow()`):** Tela inicial de preenchimento obrigatório para segmentar a busca, contendo combos de seleção de Rota/Dia de Visita, Cidade, UF, Tipo de Pessoa e Situação. Ao abrir, o cursor foca automaticamente no controle de status (`txtactive`).
*   **Página de Resultados (`frmresult` / `doPageResultShow()`):** Exibe a grade analítica de clientes (`cgridcli`) correspondentes aos filtros selecionados, o totalizador de clientes listados (`lbltotcli`) e as ações de extrato financeiro.
*   **Comportamento de Redimensionamento (`doResize()`):** Alinha ambos os frames dinamicamente ao tamanho da tela física do aparelho (`setGeometry(ui->centralWidget->geometry())`), reajustando as colunas da grade de exibição.

---

## 3. Filtros Comerciais e Mapeamento no Banco SQLite Local

A seleção e carregamento de dados (`dodataload()`) ocorrem em tempo de execução no SQLite local (`dbforcacad001.db`). Os filtros da interface são mapeados diretamente para as colunas da tabela **`cadcli00`** e as tabelas acessórias de cidades (`cadcid00`) e estados (`cadest00`):

```sql
SELECT cli00_codigo, cli00_descri, cli00_fantas, cli00_endere, cli00_ciddes, cli00_estsgl,
       cli00_fonddd, cli00_fonnum, cli00_cpfcnp, cli00_crelim, cli00_creatu, cli00_datcom,
       cli00_pessoa, cli00_codage, cli00_active, cli00_observ, cli00_titven, cli00_titave
FROM cadcli00
WHERE (cli00_active = :active OR :active_all = 1)
  AND (cli00_flgven = :dia_visita OR :dia_visita_all = 1)
  AND (cli00_estsgl = :uf OR :uf_all = 1)
  AND (cli00_cidcod = :cidade OR :cidade_all = 1)
  AND (cli00_typpes = :tipo_pessoa OR :tipo_pessoa_all = 1)
ORDER BY cli00_descri;
```

### Mapeamento dos Filtros do ComboBox para o SQLite

#### A. Rota / Dia de Visita (`txtdiavis` ➔ `cli00_flgven`)
A coluna **`cli00_flgven`** (Flag do Vendedor / Rota) armazena o dia da semana em que o faturamento de retaguarda programou a visita comercial para aquele ponto de venda. Os valores do combobox são convertidos conforme a tabela:

| Opção Visual (`txtdiavis`) | Valor Inteiro no SQLite (`cli00_flgven`) | Regra de Negócio |
| :--- | :--- | :--- |
| **Segunda-Feira** | `1` | Filtra clientes roteirizados para segunda. |
| **Terça-Feira** | `2` | Filtra clientes roteirizados para terça. |
| **Quarta-Feira** | `3` | Filtra clientes roteirizados para quarta. |
| **Quinta-Feira** | `4` | Filtra clientes roteirizados para quinta. |
| **Sexta-Feira** | `5` | Filtra clientes roteirizados para sexta. |
| **Sábado** | `6` | Filtra clientes roteirizados para sábado. |
| **Domingo** | `7` | Filtra clientes roteirizados para domingo. |
| **Sem Rota** | `0` (ou `NULL`) | Clientes carteira avulsa (sem dia fixo de visita). |
| **Todos os dias** | `-1` | Ignora a validação de dia, listando a carteira completa. |

#### B. Situação do Cliente (`txtactive` ➔ `cli00_active`)
Filtra clientes com base em seu status de ativação comercial:
*   **Ativos (`cli00_active = 1`):** Lista clientes regulares liberados para digitação.
*   **Inativos (`cli00_active = 0`):** Lista clientes suspensos ou bloqueados pela central.
*   **Todos (`-1`):** Retorna ambos os estados.

#### C. Tipo de Pessoa (`txttyppes` ➔ `cli00_typpes`)
Filtra pela natureza tributária da inscrição:
*   **Física (`cli00_typpes = 1` / `F`):** CPF.
*   **Jurídica (`cli00_typpes = 2` / `J`):** CNPJ.
*   **Todos (`-1`):** Sem distinção.

#### D. Estado / UF (`txtcodest` ➔ `cli00_estsgl`)
*   Ao acionar o formulário (`doresetform()`), o app invoca o repositório de estados **`Tcadest00List::cloadItems()`** para carregar os estados sincronizados no aparelho e popular as opções de UF, vinculando o valor selecionado à sigla do cliente (`cli00_estsgl`).

#### E. Cidade (`txtCodCid` ➔ `cli00_cidcod`)
*   Carrega dinamicamente a listagem de municípios através do mapeamento em `QMap<int, QString> cidades` filtrado pelo estado selecionado. O código numérico da cidade é verificado contra a chave estrangeira **`cli00_cidcod`**.

---

## 4. Dicionário de Dados do Relatório (Classe `ItemCLI`)

Os resultados obtidos do SQLite alimentam uma coleção de ponteiros da classe **`ItemCLI`** (instanciados no vetor dinâmico `QVector<ItemCLI*> list`), cujas propriedades são exibidas na grade visual **`cgridcli`** no frame de resultados:

### Dicionário de Atributos da Carteira de Clientes

| Identificador do Legado | Tipo no SQLite | Equivalente de Negócio | Descrição Funcional |
| :--- | :--- | :--- | :--- |
| `cli00_codigo` | INTEGER | Código do Cliente | Código numérico unívoco gerado pelo ERP central. |
| `cli00_descri` | TEXT | Razão Social | Nome oficial de registro da pessoa jurídica ou física. |
| `cli00_fantas` | TEXT | Nome Fantasia | Nome de fachada/comercial do estabelecimento. |
| `cli00_endere` | TEXT | Endereço | Logradouro, número e bairro do cliente. |
| `cli00_ciddes` | TEXT | Cidade | Nome do município do cliente. |
| `cli00_estsgl` | TEXT (Char 2)| UF | Sigla do estado federativo (ex: SP, MG, RJ). |
| `cli00_fonddd` | TEXT | DDD | Código de área telefônica. |
| `cli00_fonnum` | TEXT | Telefone | Número de telefone de contato comercial. |
| `cli00_cpfcnp` | TEXT | CPF / CNPJ | Documento de identificação tributária limpo. |
| `cli00_crelim` | REAL | Limite Original | Limite de crédito global aprovado pela central. |
| `cli00_creatu` | REAL | Limite Atualizado | Margem de crédito disponível em tempo real. |
| `cli00_datcom` | DATE | Última Compra | Data histórica em que a última Nota Fiscal foi emitida. |
| `cli00_pessoa` | TEXT (Char 1)| Pessoa F/J | Identificador físico da inscrição (F ou J). |
| `cli00_codage` | INTEGER | Código do Agente | Código do Agente Cobrador / Carteira Bancária padrão. |
| `cli00_active` | BOOLEAN | Situação | Indicador lógico de ativação (`true`=Ativo, `false`=Inativo). |
| `cli00_observ` | TEXT | Observação | Texto informativo interno ou instrução comercial. |
| `cli00_titven` | REAL | Títulos Vencidos | Somatório de títulos em atraso registrados na tabela `dup00`. |
| `cli00_titave` | REAL | Títulos a Vencer | Somatório de faturas a prazo que ainda vão expirar. |

---

## 5. Destaque Visual de Clientes de Risco (Inadimplência)

Durante a montagem da grade de resultados (`dodataload()`), o sistema legado executa uma **regra de auditoria de risco de crédito** por cor de célula (*row background painting*). Esta lógica serve de barreira visual preventiva para o vendedor, antes mesmo de abrir a digitação de itens:

```
               CONDIÇÃO DE CRÉDITO DO CLIENTE (NA LISTAGEM):
               
    ┌──────────────────────────────────────────────┐
    │       Total de Vencidos (cli00_titven > 0)    │ ➔ Pinta Row em VERMELHO (Qt::red)
    └──────────────────────┬───────────────────────┘
                           │ Não
                           v
    ┌──────────────────────────────────────────────┐
    │       Total a Vencer (cli00_titave > 0)      │ ➔ Pinta Row em AMARELO (Qt::yellow)
    └──────────────────────┬───────────────────────┘
                           │ Não
                           v
    ┌──────────────────────────────────────────────┐
    │            Crédito Regular (Faturas OK)      │ ➔ Pinta Row em BRANCO (Qt::white)
    └──────────────────────────────────────────────┘
```

*   **Pintura em Vermelho (`Qt::red`):** Aplicada quando o cliente possui **títulos vencidos em aberto** (`cli00_titven > 0.00`). Representa bloqueio iminente. Para vender para este cliente, o vendedor deve realizar a cobrança local do débito ou solicitar liberação de senha ao supervisor.
*   **Pintura em Amarelo (`Qt::yellow`):** Aplicada quando o cliente possui **títulos a vencer** (`cli00_titave > 0.00`), mas nenhum vencido. Indica atenção quanto à proximidade de vencimentos de parcelas que podem esgotar sua margem de limite disponível.
*   **Pintura em Branco/Normal (`Qt::white`):** Aplicada para clientes totalmente em dia com o departamento financeiro da empresa.

---

## 6. Módulo de Geolocalização Integrada (Navegação Georreferenciada)

Ao selecionar um cliente no grid (`cgridcli`) e acionar o botão de geolocalização (**`btnlocalizacao`**), o aplicativo abre o formulário de localização georreferenciada (**`ffrmlocalizacao00.cpp`**):

1.  **Leitura de Coordenadas:** O formulário tenta carregar as coordenadas registradas na tabela estática de cadastros:
    *   `cli16_codlat` (Latitude) e `cli16_codlon` (Longitude) correspondentes ao ID do cliente.
2.  **Captura GPS:** Se o aparelho possuir receptor de satélite ativo, a classe de posicionamento móvel captura a localização física atual do vendedor.
3.  **Gravação da Coordenada (`on_btngravar_clicked()`):**
    *   Instancia a entidade `Cliente` e preenche `setlatitude16(Latitude)` e `setlongitude16(Longitude)`.
    *   Executa a gravação atômica no SQLite via método **`salvarNoDb`**:
        ```sql
        UPDATE cadcli00 SET 
            cli16_codlat = :latitude, 
            cli16_codlon = :longitude 
        WHERE cli00_codigo = :codcli;
        ```
    *   **Exportação:** Essa coordenada é salva no arquivo XML de atualização cadastral de georreferenciamento (`fileLOC()`), gerando a nomenclatura **`c<codRep>-<codigo16Cliente>.xml`** para envio automático via FTP remoto para o diretório `dirCAD` / `dirCLI`.

---

## 7. Requisitos de Reescrita e UI/UX Modernas em Flutter

A migração da interface antiga de frames sobrepostos em C++ para o ecossistema reativo do Flutter deve obedecer aos seguintes requisitos de usabilidade e arquitetura:

### A. Substituição de Frames por uma Interface com Abas (Tabs) e Filtros Rápidos
*   **Legado:** Oculta e exibe frames inteiros (`frmfilter` e `frmresult`), forçando o usuário a clicar em voltar para mudar um único critério de busca.
*   **Flutter (Moderno):** Utilizar um layout baseado em **Abas (`TabBar` / `TabBarView`)** ou uma única tela reativa contendo:
    *   **Header de Filtros (Chips):** Fileira deslizante horizontal de filtros ativos (Ex: *Hoje, Segunda, Inativos, Ativos, Campinas*). Ao tocar em um chip de filtro, o grid de clientes reage instantaneamente de forma declarativa.
    *   **Barra de Pesquisa Global (Floating Search Bar):** Campo de texto que executa filtro em tempo real (Fuzzy Search) nos campos de Razão Social (`cli00_descri`), Fantasia (`cli00_fantas`) e Código, sem necessidade de pressionar um botão de "Carregar" (`btcarregar`).

### B. Integração Nativa com Mapas (Google Maps / OpenStreetMap)
*   **Visualização Híbrida:** Fornecer uma alternância de exibição na tela de roteirização entre **Modo Lista** (grade clássica) e **Modo Mapa**.
*   **Modo Mapa:** Renderiza alfinetes (*pins*) geográficos de todos os clientes filtrados na rota do dia.
    *   **Indicador de Risco no Pin:** Pintar o pin do mapa com as cores da regra de crédito: **Vermelho** para inadimplente, **Amarelo** para faturas a vencer, e **Verde/Azul** para crédito saudável.
    *   **Traçar Rota:** Ao tocar no alfinete do cliente, exibir janela de contexto rápida com telefone, contato e botão flutuante para abrir rota de navegação diretamente no Google Maps, Waze ou Apple Maps através do pacote `url_launcher`.

### C. Implementação Offline-First com Gerenciamento de Estado Reativo
*   **Banco de Dados:** Utilizar o **`Drift`** (antigo Moor) como engine SQLite para Dart:
    *   Definir a tabela `Cadcli00Table` com mapeamento reativo de Streams. Qualquer atualização de faturamento ou carregamento de novos clientes atualizará o grid do roteiro de visitas de forma automática.
*   **Gerência de Estado (BLoC / Cubit):**
    *   **`ClientRoutingBloc`:** Controla os estados de carregamento da rota (`ClientRoutingLoading`, `ClientRoutingLoaded`, `ClientRoutingError`).
    *   Mantém em cache o estado dos filtros em uma entidade `RoutingFilter` (dia da semana, cidade, status).

### D. Exemplo de Modelo de Dados redefinido em Dart

```dart
enum TipoPessoa { fisica, juridica }

class ClienteRoteiro {
  final int codigo;
  final String razaoSocial;
  final String nomeFantasia;
  final String endereco;
  final String cidade;
  final String uf;
  final String telefone;
  final String ddd;
  final String cpfCnpj;
  final double limiteOriginal;
  final double limiteAtual;
  final DateTime? dataUltimaCompra;
  final TipoPessoa tipoPessoa;
  final int codigoAgenteCobrador;
  final bool ativo;
  final String observacao;
  final double titulosVencidos;
  final double titulosAVencer;
  final double? latitude;
  final double? longitude;
  final int diaVisita; // Mapeia cli00_flgven (1=Segunda, etc.)

  ClienteRoteiro({
    required this.codigo,
    required this.razaoSocial,
    required this.nomeFantasia,
    required this.endereco,
    required this.cidade,
    required this.uf,
    required this.telefone,
    required this.ddd,
    required this.cpfCnpj,
    required this.limiteOriginal,
    required this.limiteAtual,
    this.dataUltimaCompra,
    required this.tipoPessoa,
    required this.codigoAgenteCobrador,
    required this.ativo,
    required this.observacao,
    required this.titulosVencidos,
    required this.titulosAVencer,
    this.latitude,
    this.longitude,
    required this.diaVisita,
  });

  // Regra de Negócio: Determina a cor de alerta de crédito do cliente
  bool get possuiInadimplencia => titulosVencidos > 0.0;
  bool get possuiTitulosAVencer => titulosAVencer > 0.0 && titulosVencidos == 0.0;
}
```