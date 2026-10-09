# Diretrizes Técnicas para Desenvolvimento Mobile (Flutter)

Este guia estabelece os padrões arquiteturais, convenções de código, gestão de estado, persistência de dados e ergonomia de interface para a aplicação Flutter neste workspace (`./`).

---

## 1. Arquitetura de Software e Separação de Camadas
Adotamos uma abordagem modular e desacoplada inspirada em **Clean Architecture**:

```text
lib/
├── core/                  # Serviços globais, tema, utilitários e clientes (HTTP/DB)
│   ├── database/          # SQLite (migrations, helpers, DAOs)
│   ├── network/           # Clientes HTTP / Supabase SDK
│   └── theme/             # Design Tokens, tipografia e estilos globais
├── features/              # Módulos funcionais isolados
│   └── [feature_name]/
│       ├── data/          # Models, DTOs, DataSources e Repositórios concretos
│       ├── domain/        # Entidades de negócio e Contratos de repositório (Interfaces)
│       └── presentation/  # Telas, Widgets atômicos e State Holders (Bloc/Notifier)
└── main.dart
```

### Regras de Dependência:
- A camada de **Apresentação (Presentation)** depende apenas do **Domínio (Domain)**. Nunca chame o SQLite, Supabase ou HTTP diretamente de dentro de um Widget.
- A camada de **Dados (Data)** implementa os contratos da camada de **Domínio**.
- O **Domínio (Domain)** é composto por Dart puro: livre de dependências do framework Flutter, widgets ou pacotes externos de terceiros.

---

## 2. Gerenciamento de Estados de Tela (Regra dos 4 Estados)
Toda tela que consulta, carrega ou submete informações DEVE implementar explicitamente os quatro estados visuais da UI:

1. **Estado de Carregamento (`LoadingState`)**:
   - Usar *shimmer skeleton* ou indicador visual de progresso contextualizado.
   - Evitar bloquear a tela inteira se parte do conteúdo já estiver em cache.
2. **Estado de Conteúdo Vazio (`EmptyState`)**:
   - Mensagem amigável explicando por que não há itens na lista.
   - Ação visual clara e direta (*Call to Action*), por exemplo: *"Nenhum agendamento encontrado. Clique no botão abaixo para agendar."*
3. **Estado de Falha/Erro (`ErrorState`)**:
   - Mensagem em Português claro, sem termos técnicos indecifráveis para o usuário final.
   - Botão obrigatório de *"Tentar Novamente"* para reexecutar a consulta.
4. **Estado de Sucesso/Dados (`SuccessState`)**:
   - Renderização limpa, com paginação sob demanda quando houver listas extensas.

---

## 3. Diretrizes de UI, Widgets e Performance
1. **Construtores `const`**: Sempre declare construtores `const` em Widgets sem estado mutável para evitar reconstruções desnecessárias na árvore de renderização.
2. **Tamanho Mínimo de Alvo de Toque (Touch Target)**:
   - Todo botão, ícone interativo ou elemento clicável deve ter uma área de toque de no mínimo **$48 \times 48\text{ dp}$**, prevenindo toques acidentais ou frustração de uso.
3. **Alinhamento com Tokens Visuais**:
   - Cores, raios de borda, espaçamentos e fontes devem ser consumidos centralmente a partir de `core/theme/` (gerado a partir de `_specs/design-tokens.json`).
   - É proibido usar cores "mágicas" (`Color(0xFF123456)`) diretamente no corpo dos widgets.
4. **Desacoplamento de Widgets**:
   - Funções construtoras de widgets internas como `Widget _buildItem()` são desencorajadas para componentes complexos; prefira classes `StatelessWidget` dedicadas para isolar reconstruções.

---

## 4. Persistência de Dados e SQLite (Offline-First)
Quando o projeto utilizar persistência local em SQLite:

1. **Migrações Incrementais e Versionadas**:
   - Nunca altere o schema existente diretamente. Toda alteração de estrutura (coluna nova, índice novo) exige uma migration sequencial vinculada à versão do banco (`onUpgrade`).
2. **Índices Estruturados**:
   - Crie índices explícitos (`CREATE INDEX IF NOT EXISTS`) em qualquer campo utilizado com frequência em cláusulas `WHERE`, ordenações `ORDER BY` ou chaves estrangeiras.
3. **Operações em Lote (Transactions / Batch)**:
   - Mutações ou inserções de múltiplos registros devem obrigatoriamente ser executadas dentro de uma transação ou usando `batch.commit(noResult: true)` para evitar retenção de I/O em disco.
4. **Testabilidade do Banco de Dados**:
   - Testes unitários de repositórios e DAOs devem ser executados em memória utilizando `sqflite_common_ffi` (`databaseFactoryFfi`), garantindo execução em milissegundos sem depender de emulador ou dispositivo físico.

---

## 5. Qualidade de Código e Análise Estática
- O código deve compilar sem nenhum aviso de linter (`flutter analyze` deve retornar código de saída `0`).
- Use o formatador padrão do Dart (`dart format .`) antes de qualquer submissão de código.
- Nomes de classes em `UpperCamelCase`, nomes de variáveis e métodos em `lowerCamelCase`, e nomes de arquivos em `snake_case`.