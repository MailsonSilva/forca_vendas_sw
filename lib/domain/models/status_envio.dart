/// Mapeamento dos enums de status legados da Suportware (protocolo Delphi).
///
/// Valores referenciais do sistema legado (pvpsp):
///   - [StatusEnvio.naoEnviado] = 0 → Não Enviado / PENDENTE
///   - [StatusEnvio.jaEnviado]  = 1 → Enviado / TRANSMITIDO
///   - [StatusEnvio.retornado]  = 2 → Retornado com Erro / Confirmado
enum StatusEnvio {
  naoEnviado(0),
  jaEnviado(1),
  retornado(2);

  const StatusEnvio(this.value);

  /// Valor numérico gravado nas colunas de status do SQLite local.
  final int value;
}
