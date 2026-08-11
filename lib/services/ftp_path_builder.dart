// ─────────────────────────────────────────────────────────────────────────────
// FtpPathBuilder — centraliza a montagem de paths e nomes de arquivos FTP.
//
// ORIGEM DOS PARÂMETROS:
//   • empresa  → AppState().empresa_codigo  (String, ex: 'diniz')
//               Preenchido no login (first_access_login.dart / offline_login.dart).
//               Fallback: 'diniz' quando vazio.
//
//   • codReg   → AppState().vendedor_equipe  (int, ex: 7)
//               Origem ven00_codeqp, persistido em SharedPreferences.
//               Representa o CÓDIGO DA EQUIPE / vendedor logado.
//               Formatado com 2 dígitos (ex: 7 → '07', 71 → '71').
//
// FORMATO DO PATH RESULTANTE (exemplos):
//   Pedido  → /diniz/71/Externo/
//   Cliente → /diniz/71/Customer/
//   Geral   → /diniz/71/Upload/
//
// NOME DO ARQUIVO (sem extensão .xml, conforme protocolo legado):
//   Pedido  → p71-1007
//   Cliente → c71-36109
// ─────────────────────────────────────────────────────────────────────────────

enum TipoCarga { cliente, pedido, uploadGeral }

class FtpPathBuilder {
  /// Formata o código da equipe/vendedor com 2 dígitos (ex: 7 → '07', 71 → '71').
  /// Origem: AppState().vendedor_codigo (persistido em SharedPreferences).
  static String formatEquipe(int codReg) {
    return codReg.toString().padLeft(2, '0');
  }

  /// Retorna o diretório remoto do FTP no formato /{empresa}/{equipe}/{tipo}/.
  ///
  /// - [empresa]: AppState().empresa_codigo.trim().toLowerCase()
  ///   (fallback 'diniz' quando vazio — aplicado ANTES de chamar este método).
  /// - [codReg]: AppState().vendedor_codigo (código da equipe, ex: 71).
  /// - [tipo]: pedido → Externo/, cliente → Customer/, geral → Upload/.
  static String getRemotePath({
    required String empresa,
    required int codReg,
    required TipoCarga tipo,
  }) {
    final equipe = formatEquipe(codReg);
    final pastaEmpresa = empresa.toLowerCase().trim();

    switch (tipo) {
      case TipoCarga.cliente:
        return '/$pastaEmpresa/$equipe/Customer/';
      case TipoCarga.pedido:
        return '/$pastaEmpresa/$equipe/Externo/';
      case TipoCarga.uploadGeral:
        return '/$pastaEmpresa/$equipe/Upload/';
    }
  }

  /// Gera o nome do arquivo de pedido SEM extensão (protocolo legado Delphi).
  /// Formato: p{codRep}-{codMov}  →  ex: p71-1007
  static String getFileNamePedido(int codRep, int codMov) {
    return 'p$codRep-$codMov';
  }

  /// Gera o nome do arquivo de cliente SEM extensão.
  /// Formato: c{codRep}-{codCli}  →  ex: c71-36109
  static String getFileNameCliente(int codRep, int codCli) {
    return 'c$codRep-$codCli';
  }
}
