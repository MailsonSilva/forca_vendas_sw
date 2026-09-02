import 'package:sqflite/sqflite.dart';
import '../data/services/local_sales_database_service.dart';
import '../domain/models/carteira_roteirizacao_model.dart';

/// Serviço responsável por processar, filtrar e consultar a
/// Carteira de Clientes e Roteirização de Visitas (`ffrmrelclirot00`).
class CarteiraRoteirizacaoService {
  /// Retorna o dia da semana atual no padrão do sistema legado:
  /// 1 = Segunda-Feira ... 7 = Domingo.
  static int obterDiaSemanaAtual() {
    return DateTime.now().weekday; // 1 (Mon) a 7 (Sun)
  }

  /// Consulta a carteira de clientes aplicando os filtros de rota, crédito,
  /// tipo de pessoa e localização no SQLite local.
  static Future<CarteiraRoteirizacaoResumo> obterCarteiraRoteirizada({
    RoteirizacaoFiltro? filtro,
    Database? customDb,
  }) async {
    final db = customDb ?? await LocalSalesDatabaseService.getDatabase();
    final f = filtro ?? const RoteirizacaoFiltro();

    try {
      final whereClauses = <String>[];
      final whereArgs = <dynamic>[];

      // 1. Filtro de Dia de Visita / Rota (`cli00_flgven`)
      if (f.diaVisita != -1) {
        if (f.diaVisita == 0) {
          whereClauses.add('(cli00_flgven = 0 OR cli00_flgven IS NULL)');
        } else {
          whereClauses.add('cli00_flgven = ?');
          whereArgs.add(f.diaVisita);
        }
      }

      // 2. Filtro de Status de Ativação (`cli00_active`)
      if (f.statusAtivo != -1) {
        whereClauses.add('cli00_active = ?');
        whereArgs.add(f.statusAtivo);
      }

      // 3. Filtro de Tipo de Pessoa (`cli00_typpes`)
      if (f.tipoPessoa != -1) {
        whereClauses.add('cli00_typpes = ?');
        whereArgs.add(f.tipoPessoa);
      }

      // 4. Filtro por Estado / UF (`cli00_estsgl`)
      if (f.uf != null && f.uf!.trim().isNotEmpty && f.uf!.toUpperCase() != 'TODOS') {
        whereClauses.add('UPPER(cli00_estsgl) = ?');
        whereArgs.add(f.uf!.trim().toUpperCase());
      }

      // 5. Filtro por Município / Cidade (`cli00_ciddes`)
      if (f.cidade != null && f.cidade!.trim().isNotEmpty && f.cidade!.toUpperCase() != 'TODAS') {
        whereClauses.add('UPPER(cli00_ciddes) = ?');
        whereArgs.add(f.cidade!.trim().toUpperCase());
      }

      // 6. Filtro de Busca Textual (Razão, Fantasia, Código, CPF/CNPJ)
      if (f.buscaTexto != null && f.buscaTexto!.trim().isNotEmpty) {
        final queryClean = f.buscaTexto!.trim();
        whereClauses.add('''
          (
            cli00_descri LIKE ? OR
            cli00_fantas LIKE ? OR
            cli00_cpfcnp LIKE ? OR
            CAST(cli00_codigo AS TEXT) LIKE ?
          )
        ''');
        final searchParam = '%$queryClean%';
        whereArgs.addAll([searchParam, searchParam, searchParam, searchParam]);
      }

      final whereSql = whereClauses.isNotEmpty ? 'WHERE ${whereClauses.join(' AND ')}' : '';
      final query = 'SELECT * FROM cadcli00 $whereSql ORDER BY cli00_descri ASC';

      final rows = await db.rawQuery(query, whereArgs);
      final clientes = rows.map((r) => ClienteRoteiroItem.fromMap(r)).toList();

      return CarteiraRoteirizacaoResumo.fromClientes(clientes);
    } catch (e) {
      print('Erro ao obter carteira roteirizada de clientes: $e');
      return CarteiraRoteirizacaoResumo.empty();
    }
  }

  /// Obtém a lista de UFs únicas registradas na tabela `cadcli00`.
  static Future<List<String>> obterUfsDisponiveis({Database? customDb}) async {
    final db = customDb ?? await LocalSalesDatabaseService.getDatabase();
    try {
      final rows = await db.rawQuery('''
        SELECT DISTINCT cli00_estsgl 
        FROM cadcli00 
        WHERE cli00_estsgl IS NOT NULL AND cli00_estsgl != ''
        ORDER BY cli00_estsgl ASC
      ''');
      return rows.map((r) => r['cli00_estsgl'].toString().toUpperCase()).toList();
    } catch (_) {
      return [];
    }
  }

  /// Obtém a lista de Cidades únicas registradas na tabela `cadcli00` (com filtro opcional por UF).
  static Future<List<String>> obterCidadesDisponiveis({String? uf, Database? customDb}) async {
    final db = customDb ?? await LocalSalesDatabaseService.getDatabase();
    try {
      final where = (uf != null && uf.trim().isNotEmpty && uf.toUpperCase() != 'TODOS')
          ? 'WHERE UPPER(cli00_estsgl) = "${uf.trim().toUpperCase()}"'
          : '';
      final rows = await db.rawQuery('''
        SELECT DISTINCT cli00_ciddes 
        FROM cadcli00 
        $where
        WHERE cli00_ciddes IS NOT NULL AND cli00_ciddes != ''
        ORDER BY cli00_ciddes ASC
      ''');
      return rows.map((r) => r['cli00_ciddes'].toString()).toList();
    } catch (_) {
      return [];
    }
  }
}
