// Mapeamento dos enums de status legados da Suportware (protocolo Delphi).
// Valores referenciais do sistema legado (pvpsp):
//   - StatusEnvio.naoEnviado = 0 → Não Enviado / PENDENTE
//   - StatusEnvio.jaEnviado  = 1 → Enviado / TRANSMITIDO
//   - StatusEnvio.retornado  = 2 → Retornado com Erro / Confirmado
// PRD docs/specs/pedidos_prd.md:22 — Tpckvendig00SttDIG / SttENV
// Novos enums alinhados ao PRD. StatusEnvio mantido como @deprecated alias.

// ── PRD: Status de Digitação (Tpckvendig00SttDIG) ──────────────────────────
// pvddsEDITANDO (0) → pvddsDIGITADO (1) → pdddsFINALIZA (2)
enum PedidoSttDig {
  editando(0),
  digitado(1),
  finaliza(2);

  const PedidoSttDig(this.value);
  final int value;

  static PedidoSttDig fromValue(int v) =>
      PedidoSttDig.values.firstWhere((e) => e.value == v, orElse: () => PedidoSttDig.editando);
}

// ── PRD: Status de Transmissão (Tpckvendig00SttENV) ────────────────────────
// pvddeDIGITADO (0) → pvddeEMPACOTE (1) → pvddeENVIADOS (2) → pvddeRECEBIDO (3)
enum PedidoSttEnv {
  digitado(0),
  empacote(1),
  enviados(2),
  recebido(3);

  const PedidoSttEnv(this.value);
  final int value;

  static PedidoSttEnv fromValue(int v) =>
      PedidoSttEnv.values.firstWhere((e) => e.value == v, orElse: () => PedidoSttEnv.digitado);
}

extension PedidoSttEnvX on PedidoSttEnv {
  StatusEnvio toStatusEnvio() {
    switch (this) {
      case PedidoSttEnv.digitado:
        return StatusEnvio.naoEnviado;
      case PedidoSttEnv.empacote:
        return StatusEnvio.naoEnviado;
      case PedidoSttEnv.enviados:
        return StatusEnvio.jaEnviado;
      case PedidoSttEnv.recebido:
        return StatusEnvio.retornado;
    }
  }
}

@Deprecated('Use PedidoSttEnv. Mantido para compatibilidade com StatusEnvioDb/CargaRegistry')
enum StatusEnvio {
  naoEnviado(0),
  jaEnviado(1),
  retornado(2);

  const StatusEnvio(this.value);

  /// Valor numérico gravado nas colunas de status do SQLite local.
  final int value;
}

// ── Status do Pacote (Tpckvenpac00StatePAC) ──────────────────────────────────
// pvpspNEnviado (0) → pvpspJEnviado (1)
enum PacoteSttPac {
  nEnviado(0),
  jEnviado(1);

  const PacoteSttPac(this.value);
  final int value;

  static PacoteSttPac fromValue(int v) =>
      PacoteSttPac.values.firstWhere((e) => e.value == v, orElse: () => PacoteSttPac.nEnviado);
}

// ── Status de Transmissão do Pacote (Tpckvenpac00StateENV) ───────────────────
// pvpseNEnviado (0) → pvpseJEnviado (1) → pvpseRetornad (2)
enum PacoteSttEnv {
  nEnviado(0),
  jEnviado(1),
  retornado(2);

  const PacoteSttEnv(this.value);
  final int value;

  static PacoteSttEnv fromValue(int v) =>
      PacoteSttEnv.values.firstWhere((e) => e.value == v, orElse: () => PacoteSttEnv.nEnviado);
}

