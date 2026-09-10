# 📋 Especificação Técnica e Regras de Negócio: Cadastro/Edição de Clientes e Empacotamento no Menu Ferramentas

Este documento especifica o diagnóstico de problemas, as regras de negócio, a estrutura de arquivos e as telas necessárias para a refatoração e melhoria do **Cadastro/Edição de Clientes** (`cadcli` / `Cliente`) e a implementação do **Empacotamento Manual de Pedidos e Clientes no Menu Ferramentas** (`ffrmmentoo00` / `ffrmconnect00`).

---

## 1. 🔍 Diagnóstico do Problema Atual (Cadastro/Edição de Clientes)

### O que estava acontecendo?
No fluxo legado (`ffrmcadcli.cpp`, `cliente.cpp`, `ffrmlocalizacao00.cpp`), o cadastro ou edição de clientes realiza duas operações simultâneas:
1. **Gravação no Banco Local (SQLite):** Insere ou atualiza o registro na tabela `cadcli00` / `cli00` no banco de dados da aplicação (`dbforcadig001.db`).
2. **Geração do Arquivo XML de Envio:** Invoca os métodos `fileCAD()` para novos clientes ou `fileLOC()` para atualizações/geolocalização, gravando um arquivo XML em disco na pasta de clientes do sistema (`CPathCLI()`).

### Por que o app não estava atualizando a tela e não mostrava o arquivo gerado?
* **Falta de Reatividade na Interface:** A lista de clientes não utilizava um padrão de escuta ativa (*Stream* / *Reactive State*). Ao salvar no banco SQLite, a tela anterior permanecia com o cache antigo sem recarregar os dados.
* **Ausência de Feedback de Caminho:** O arquivo XML era gerado silenciosamente no diretório temporário/local (`CPathCLI()`) sem exibir um alerta visual (*Toast* / *SnackBar* / *Dialog*) informando o nome e o caminho do arquivo gerado.
* **Filtros de Situação (`cli00_active`):** Novos clientes gravados com ID temporário ou pendentes de confirmação do ERP não apareciam na busca por estarem sem o filtro de clientes não sincronizados/locais.

---

## 2. 📝 Regras de Negócio para Cadastro e Edição de Clientes

### A. Dicionário de Dados e Campos da Entidade Cliente (`cadcli00` / `Cliente`)

| Campo no Flutter | Campo SQLite / Legado | Tipo | Obrigatoriedade | Regra de Negócio |
| :--- | :--- | :--- | :--- | :--- |
| **Código** | `cli00_codigo` / `_codigo` | `INTEGER` | Autogerado | ID interno local (para novos clientes, gera sequencial temporário). |
| **Código 16** | `cli00_codigo16` / `_codigo16` | `INTEGER` | Opcional | Identificador de 16 dígitos para rastreamento de alteração/GPS. |
| **Razão Social** | `cli00_rSocial` / `_razaoSocial` | `TEXT` | **Obrigatório** | Razão Social do cliente (convertido para caixa alta). |
| **Nome Fantasia** | `cli00_nFantasia` / `_nomeFantasia` | `TEXT` | **Obrigatório** | Nome Fantasia comercial. |
| **Tipo de Pessoa** | `cli00_tPessoa` / `_tipoPessoa` | `INTEGER` | **Obrigatório** | `1` = Pessoa Física (PF), `2` = Pessoa Jurídica (PJ). |
| **CPF / CNPJ** | `cli00_cpfcnpj` / `_cpf` / `_cnpj` | `TEXT` | **Obrigatório** | CPF (11 dígitos para PF) ou CNPJ (14 dígitos para PJ). Deve sofrer limpeza de máscara. |
| **Inscrição Estadual** | `cli00_iEst` / `_inscricaoEstadual`| `TEXT` | Condicional | Obrigatório para PJ (`tipoPessoa = 2`). Se PF, gravar `"-"`. |
| **Número RG** | `cli00_nRG` / `_numeroRG` | `TEXT` | Condicional | Requerido para PF (`tipoPessoa = 1`). |
| **E-mail Principal** | `cli00_email` / `_email` | `TEXT` | Opcional | E-mail de contato comercial do cliente. |
| **E-mail DANFE** | `cli00_emailDanfe` / `_emailDanfe` | `TEXT` | Opcional | E-mail para envio de Nota Fiscal Eletrônica. |
| **Ramo de Atividade** | `cli00_ramo` / `_ramo` | `TEXT` | Opcional | Categoria/Segmento de atuação do cliente. |
| **Limite de Crédito** | `cli00_limite` / `_limite` | `REAL` | Opcional | Limite solicitado/sugerido (se vazio, grava `-1` ou `0.00`). |
| **Observações** | `cli00_descObs` / `_descObs` | `TEXT` | Opcional | Informações adicionais do cadastro. |

### B. Módulo de Endereços Múltiplos e Contatos
* **Endereço de Entrega (`endEnt`):** Logradouro, Número, Bairro, Cidade, UF, CEP, DDD, Telefone, Fax.
* **Endereço de Cobrança (`endCob`):** Logradouro, Número, Bairro, Cidade, UF, CEP, DDD, Telefone, Fax.
* **Opção de Reutilização (`_cbUsarEndCom` / `_cbUsarEndCb`):** Checkbox para copiar automaticamente os dados do Endereço de Entrega para o Endereço de Cobrança.

### C. Limpeza de Máscaras e Validações
O sistema deve executar o expurgo de caracteres especiais antes de persistir no banco e gerar o XML (`RemoveMascara`):
```dart
String removerMascara(String text) {
  return text.replaceAll(RegExp(r'[.\-/\(\)\s]'), '');
}
```

---

## 3. 📄 Estrutura e Localização dos Arquivos XML de Clientes

Quando um cliente é cadastrado ou editado, o sistema gera o arquivo XML de integração sem compactação `.pac` e salva na pasta de clientes local (`CPathCLI()`).

### A. Nomenclatura Oficial dos Arquivos de Clientes
1. **Novo Cadastro de Cliente (`fileCAD()`):**
   * **Máscara:** `c<codigoRepresentante>-<milissegundos>.xml`
   * **Exemplo:** `c71-893021.xml` (utiliza milissegundos/timestamp para evitar colisão).
2. **Edição / Atualização de Geolocalização GPS (`fileLOC()`):**
   * **Máscara:** `c<codigoRepresentante>-<codigo16Cliente>.xml`
   * **Exemplo:** `c71-0000000000002780.xml`

### B. Estrutura do XML de Novo Cadastro
```xml
<?xml version="1.0" encoding="UTF-8"?>
<cliente>
    <cli00_codigoRep>71</cli00_codigoRep>
    <cli00_rSocial>MERCADO SILVA E SOUZA LTDA</cli00_rSocial>
    <cli00_nFantasia>MERCADO SILVA</cli00_nFantasia>
    <cli00_tPessoa>2</cli00_tPessoa>
    <cli00_cpfcnpj>12345678000195</cli00_cpfcnpj>
    <cli00_iEst>109876543</cli00_iEst>
    <cli00_nRG>-</cli00_nRG>
    <cli00_email>contato@mercadosilva.com.br</cli00_email>
    <cli00_emailDanfe>nfe@mercadosilva.com.br</cli00_emailDanfe>
    <cli00_limite>5000.00</cli00_limite>
    <cli00_endEnt>RUA DAS FLORES</cli00_endEnt>
    <cli00_numEnt>100</cli00_numEnt>
    <cli00_bairroEnt>CENTRO</cli00_bairroEnt>
    <cli00_cidadeEnt>SAO PAULO</cli00_cidadeEnt>
    <cli00_ufEnt>SP</cli00_ufEnt>
    <cli00_cepEnt>01001000</cli00_cepEnt>
    <cli00_dddEnt>11</cli00_dddEnt>
    <cli00_foneEnt>33334444</cli00_foneEnt>
</cliente>
```

### C. Exibição Obrigatória de Feedback Visual ao Usuário
Ao concluir a gravação do cliente, o aplicativo no Flutter **deve exibir um modal ou SnackBar explicativo**:
> ℹ️ **Cadastro Salvo com Sucesso!**
> 
> Arquivo de exportação gerado em:
> `/storage/emulated/0/Android/data/com.empresa.fv/files/cli/c71-893021.xml`

---

## 4. 🛠️ Novo Módulo no Menu Ferramentas: Empacotamento Manual e Envio FTP

Para alinhar com o comportamento das telas `ffrmmentoo00`, `ffrmconnect00` e `ffrmdiggerpac00`, a área de **Ferramentas / Central de Cargas** deve disponibilizar o botão de **Empacotamento e Transmissão Manual**.

```
 ┌────────────────────────────────────────────────────────────────────────┐
 │                    MENU FERRAMENTAS (FerramentasPage)                   │
 ├────────────────────────────────────────────────────────────────────────┤
 │  [ Localizador ]   [ Calculadora ]   [ Configurações ]   [ Sobre ]     │
 │                                                                        │
 │  ┌──────────────────────────────────────────────────────────────────┐  │
 │  │ 📦 [NOVO] GERAR PACOTES E ENVIAR CARGA (Central de Transmissão)   │  │
 │  └──────────────────────────────────────────────────────────────────┘  │
 └────────────────────────────────────┬───────────────────────────────────┘
                                      │
                                      ▼
 ┌────────────────────────────────────────────────────────────────────────┐
 │                  CENTRAL DE EMPACOTAMENTO E TRANSMISSÃO                │
 ├──────────────────────────────────┬─────────────────────────────────────┤
 │ PAINEL DE PENDÊNCIAS (Esquerda)  │ PAINEL DE PACOTES / ARQUIVOS (Direita)│
 │                                  │                                     │
 │ 🔘 Pedidos Aguardando (3)        │ 📄 p71-1001.pac (Pronto)            │
 │ 🔘 Novos Clientes (2)            │ 📄 c71-893021.xml (Pronto)          │
 │ 🔘 Mensagens/Recados (0)         │                                     │
 ├──────────────────────────────────┴─────────────────────────────────────┤
 │ [☑️ Selecionar Todos]    [📦 GERAR PACOTE (.pac)]    [🚀 CONECTAR / ENVIAR] │
 └────────────────────────────────────────────────────────────────────────┘
```

### A. Funcionalidades do Botão de Empacotamento no Menu Ferramentas
1. **Visualização Unificada de Pendências:**
   * **Aba 1 (Pedidos Pendentes):** Exibe a lista de pedidos gravados offline que ainda não foram empacotados (`dig00_sttenv = 0`). Exibe: Pedido, Cliente, Data, Plano, Linha e Checkbox de seleção.
   * **Aba 2 (Cadastros de Clientes Pendentes):** Exibe a lista de novos clientes cadastrados localmente ou atualizações de geolocalização pendentes de envio.
2. **Geração do Pacote (`.pac` / `.xml`):**
   * Ao selecionar os pedidos e clicar em **"Gerar Pacote"**:
     * Agrupa os XMLs dos pedidos em um arquivo `.pac` (formato ZIP) sob a nomenclatura `p<codRep>-<seqPacote>.pac` (ex: `p71-1002.pac`).
     * Exibe um alerta de confirmação em tela com o nome do pacote gerado.
     * Atualiza o status dos pedidos para **Empacotado (`dig00_sttenv = 1`)**.
3. **Conexão e Transmissão FTP (`fcfPUTCAD = 10` e `fcfPUTPED = 8`):**
   * Ao clicar em **"Conectar / Enviar Carga"**:
     * Transmite os arquivos `.pac` de pedidos para a pasta remota **`dirPAC`** via `fcfPUTPED = 8`.
     * Transmite os arquivos `.xml` de clientes para a pasta remota **`dirCAD` / `dirCLI`** via `fcfPUTCAD = 10`.
     * Após o encerramento do upload com sucesso, atualiza o status no banco local para **Enviado (`sttenv = 2 / JEnviado`)** e remove os arquivos temporários da pasta local.

---

## 5. 💻 Guia de Implementação no Flutter (Drift ORM + BLoC)

### A. Repositório de Clientes e Atualização Reativa no Flutter
```dart
// Exemplo de Stream reativo no Drift/Sqflite para atualização em tempo real
Stream<List<ClienteData>> watchTodosClientes() {
  return (select(clientes)..orderBy([(t) => OrderingTerm.desc(t.codigo)])).watch();
}

Future<void> salvarClienteComFeedback({
  required ClienteCompanion cliente,
  required BuildContext context,
}) async {
  // 1. Salva no SQLite local
  final idGerado = await into(clientes).insert(cliente);

  // 2. Gera o arquivo XML no diretório de clientes (CPathCLI)
  final xmlFile = await ClienteXmlService.gerarXmlCliente(
    codRepresentante: '71',
    clienteId: idGerado,
    dados: cliente,
  );

  // 3. Exibe Feedback Visual do Caminho do Arquivo
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Cliente cadastrado com sucesso!\nArquivo XML: ${xmlFile.path.split('/').last}',
        ),
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'Ver no Menu',
          onPressed: () => Navigator.pushNamed(context, '/ferramentas'),
        ),
      ),
    );
  }
}
```

### B. Correção das Rotas de Navegação
 Ao concluir a digitação de um pedido ou o cadastro de um cliente, o aplicativo **não deve fazer logout ou fechar a sessão**. A rota deve redirecionar o usuário de forma fluida para a tela de **Resumo do Pedido**, **Central de Ferramentas** ou retornar para a **HomePageWidget** mantendo o estado de sessão ativo.
