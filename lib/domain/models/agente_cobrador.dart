// PRD 1 §2 — Tcadage00 / codage00
// age00_codigo -> dig00_digagt, age00_descri -> exibido lblagetxt, age00_tipo -> dig00_digcob
class AgenteCobrador {
  const AgenteCobrador({
    required this.codigo,
    required this.descricao,
    required this.tipo,
  });

  final int codigo;
  final String descricao;
  final int tipo;

  factory AgenteCobrador.fromMap(Map<String, dynamic> m) {
    // Tolerante a variações legadas cadagt00 vs codage00
    int parseInt(dynamic v) {
      if (v == null) return 0;
      if (v is int) return v;
      if (v is num) return v.toInt();
      return int.tryParse(v.toString()) ?? 0;
    }

    // Código: age00_codigo / agt00_codigo / agt00_codage / agt00_codagt / cob00_codigo
    int cod = 0;
    for (final k in ['age00_codigo', 'agt00_codigo', 'agt00_codage', 'agt00_codagt', 'cob00_codigo', 'cob00_codcob', 'cad00_codigo', 'codigo', 'cod']) {
      if (m.containsKey(k) && m[k] != null) { cod = parseInt(m[k]); if (cod != 0) break; }
      // case-insensitive fallback
      final lk = k.toLowerCase();
      for (final ek in m.keys) {
        if (ek.toString().toLowerCase() == lk && m[ek] != null) { cod = parseInt(m[ek]); break; }
      }
      if (cod != 0) break;
    }

    String desc = '';
    for (final k in ['age00_descri', 'agt00_descri', 'agt00_descricao', 'agt00_nome', 'age00_descricao', 'age00_nome', 'cob00_descri', 'cob00_descricao', 'cob00_nome', 'descricao', 'descri', 'nome']) {
      if (m.containsKey(k) && m[k] != null && m[k].toString().trim().isNotEmpty) { desc = m[k].toString().trim(); break; }
      final lk = k.toLowerCase();
      for (final ek in m.keys) {
        if (ek.toString().toLowerCase() == lk && m[ek] != null && m[ek].toString().trim().isNotEmpty) { desc = m[ek].toString().trim(); break; }
      }
      if (desc.isNotEmpty) break;
    }

    int tipo = 0;
    for (final k in ['age00_tipo', 'agt00_tipo', 'agt00_tipage', 'cob00_tipo', 'tipo']) {
      if (m.containsKey(k) && m[k] != null) { tipo = parseInt(m[k]); break; }
      final lk = k.toLowerCase();
      for (final ek in m.keys) {
        if (ek.toString().toLowerCase() == lk && m[ek] != null) { tipo = parseInt(m[ek]); break; }
      }
      if (tipo != 0) break;
    }

    return AgenteCobrador(codigo: cod, descricao: desc, tipo: tipo);
  }

  Map<String, dynamic> toMapCodage() => {
        'age00_codigo': codigo,
        'age00_descri': descricao,
        'age00_tipo': tipo,
      };
}
