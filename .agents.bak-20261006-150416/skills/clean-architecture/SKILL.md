---
name: clean-architecture-tdd
description: Práticas de Test-Driven Development (Red-Green-Refactor), desacoplamento de domínio e criação de suítes de teste de alta velocidade.
---

# Skill: Clean Architecture & Disciplina TDD

Esta skill dita o comportamento dos subagentes `tdd_tester`, `mobile_builder` e `qa_validator` durante a criação de funcionalidades.

## 1. Protocolo Red-Green-Refactor
1. **Fase Vermelha (RED)**:
   - O agente `tdd_tester` lê o arquivo de especificação da funcionalidade (`_specs/features/*.md`).
   - Identifica os contratos necessários (entidades, repositórios, use cases).
   - Escreve os testes unitários ou de widgets cobrindo os critérios de aceitação.
   - Executa a suíte de testes e valida que ela **FALHOU** pelos motivos corretos (ausência da classe ou método).
2. **Fase Verde (GREEN)**:
   - O agente construtor (`builder`) lê a falha e escreve **apenas** o código suficiente para satisfazer os testes.
   - Não invente funcionalidades secundárias que não estejam cobertas por um teste.
3. **Fase de Refatoração (REFACTOR)**:
   - Limpeza de nomes, extração de métodos duplicados, tipagem rigorosa.
   - Reexecução imediata dos testes para garantir que nada foi quebrado durante a limpeza.

## 2. Isolamento de Dependências
- **Camada de Domínio Puro**: Entidades e contratos de repositório não devem importar Flutter, SQLite, HTTP, Supabase ou bibliotecas de terceiros.
- **Testes de Banco Ultrarrápidos**:
  - Testes que envolvam banco de dados local (ex: SQLite) devem ser executados em memória utilizando fábrica em memória (`sqflite_common_ffi` ou equivalente), garantindo execução em menos de 100ms sem necessidade de emulador ou simulador.
- **Mocks Determinísticos**: Dependências externas (APIs, serviços de rede, GPS) devem ser simuladas via interfaces mockadas.