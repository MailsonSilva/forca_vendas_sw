import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'ftp_path_builder.dart';

/// Registro de carga: associa o nome do arquivo gerado (ex: `p7-12345.pac`)
/// ao identificador do registro no SQLite local.
///
/// Como a nomenclatura legada do guia usa `p{codRep}-{ms}.pac` (pedido) e
/// `c{codRep}-{ms}.xml` (cliente), o id do pedido/cliente NÃO está no nome do
/// arquivo. A responsabilidade de saber o que está sendo enviado fica na camada
/// de geração (em memória), que registra aqui o mapeamento arquivo → id.
class CargaRegistro {
  const CargaRegistro({
    required this.arquivo,
    required this.tipo,
    required this.id,
  });

  final String arquivo;
  final TipoCarga tipo;
  final int id;

  Map<String, dynamic> toMap() => {
        'arquivo': arquivo,
        'tipo': tipo.name,
        'id': id,
      };

  factory CargaRegistro.fromMap(Map<String, dynamic> map) => CargaRegistro(
        arquivo: map['arquivo'] as String,
        tipo: TipoCarga.values.byName(map['tipo'] as String),
        id: (map['id'] as num).toInt(),
      );
}

/// Persistência do manifesto de cargas em `getTemporaryDirectory()/carga_manifest.json`.
///
/// O manifesto é escrito pela camada de geração e lido pela camada de upload
/// para autorizar a atualização de flags (JEnviado) no repositório do banco de
/// dados usando a lista que estava em memória — sem parse de nome de arquivo.
class CargaRegistryService {
  CargaRegistryService({this.manifestPath});

  /// Caminho do manifesto. Nulo → usa o default `carga_manifest.json` em temp.
  final String? manifestPath;

  Future<String> _resolvePath() async {
    if (manifestPath != null) return manifestPath!;
    Directory dir;
    try {
      dir = await getTemporaryDirectory();
    } catch (_) {
      dir = Directory.systemTemp;
    }
    return p.join(dir.path, 'carga_manifest.json');
  }

  /// Registra (ou atualiza) a entrada do [registro] no manifesto.
  Future<void> registrar(CargaRegistro registro) async {
    final path = await _resolvePath();
    final itens = await _load(path);
    itens[registro.arquivo] = registro.toMap();
    await _save(path, itens);
  }

  /// Lista todos os registros atualmente no manifesto.
  Future<List<CargaRegistro>> listar() async {
    final path = await _resolvePath();
    final itens = await _load(path);
    return itens.values
        .map((map) => CargaRegistro.fromMap(map))
        .toList(growable: false);
  }

  /// Remove a entrada do arquivo [arquivo] do manifesto (após envio bem-sucedido).
  Future<void> remover(String arquivo) async {
    final path = await _resolvePath();
    final itens = await _load(path);
    if (itens.remove(arquivo) != null) {
      await _save(path, itens);
    }
  }

  Future<Map<String, dynamic>> _load(String path) async {
    final file = File(path);
    if (!await file.exists()) return {};
    try {
      final raw = await file.readAsString();
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }

  Future<void> _save(String path, Map<String, dynamic> itens) async {
    final file = File(path);
    await file.parent.create(recursive: true);
    await file.writeAsString(
      jsonEncode(itens),
      flush: true,
    );
  }
}
