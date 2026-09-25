import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:forca_de_vendas/app_state.dart';
import 'package:forca_de_vendas/action_code/offline_login.dart';
import 'package:forca_de_vendas/domain/models/sales_database_install_result.dart';
import 'package:forca_de_vendas/domain/models/sales_access_config.dart';
import 'package:forca_de_vendas/data/services/local_sales_database_service.dart';
import 'package:forca_de_vendas/services/estoque_filial_service.dart';
import 'package:forca_de_vendas/services/nav_bar_service.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AppState().initializePersistedState();
    NavBarService().navegarParaConfiguracao();
  });

  group('Item 1: Nome da Empresa Dinâmico na Sessão e AppState', () {
    test('AppState persiste e recupera empresaNome corretamente', () async {
      final state = AppState();
      expect(state.empresaNome, isEmpty);

      state.empresaNome = 'Distribuidora São Paulo LTDA';
      expect(state.empresaNome, equals('Distribuidora São Paulo LTDA'));

      // Simula reinicialização do AppState
      AppState.reset();
      await AppState().initializePersistedState();
      expect(AppState().empresaNome, equals('Distribuidora São Paulo LTDA'));
    });

    test('offlineLogin extrai empresaNome de cadace00 (srv00_descri)', () async {
      final db = await openDatabase(inMemoryDatabasePath, version: 1,
          onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE cadrep00 (
            ven00_codigo INTEGER PRIMARY KEY,
            ven00_descri TEXT,
            ven00_codeqp INTEGER,
            ven00_codfil INTEGER
          );
        ''');
        await db.execute('''
          CREATE TABLE cadace00 (
            srv00_descri TEXT,
            srv00_imglog BLOB
          );
        ''');
        await db.insert('cadrep00', {
          'ven00_codigo': 105,
          'ven00_descri': 'Representante Teste',
          'ven00_codeqp': 1,
          'ven00_codfil': 2,
        });
        await db.insert('cadace00', {
          'srv00_descri': 'Empresa Comercial Alfa',
          'srv00_imglog': null,
        });
      });

      try {
        final result = await offlineLogin('105', dbPath: db.path);
        expect(result.success, isTrue);
        expect(AppState().empresaNome, equals('Empresa Comercial Alfa'));
      } finally {
        await db.close();
      }
    });

    test('offlineLogin extrai empresaNome de cadrep00 caso cadace00 não possua descrição', () async {
      final db = await openDatabase(inMemoryDatabasePath, version: 1,
          onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE cadrep00 (
            ven00_codigo INTEGER PRIMARY KEY,
            ven00_descri TEXT,
            ven00_codeqp INTEGER,
            ven00_codfil INTEGER,
            ven00_empresa TEXT
          );
        ''');
        await db.insert('cadrep00', {
          'ven00_codigo': 200,
          'ven00_descri': 'Vendedor 200',
          'ven00_codeqp': 1,
          'ven00_codfil': 1,
          'ven00_empresa': 'Distribuidora Beta',
        });
      });

      try {
        AppState().empresaNome = '';
        final result = await offlineLogin('200', dbPath: db.path);
        expect(result.success, isTrue);
        expect(AppState().empresaNome, equals('Distribuidora Beta'));
      } finally {
        await db.close();
      }
    });

    test('SalesAccessConfig extrai nome_empresa do arquivo /config/acesso do FTP', () {
      final jsonExemplo = {
        'nome_empresa': 'Diniz',
        'pasta_download': '/diniz/download/',
        'pasta_upload': '/diniz/upload/',
        'nome_arquivo_db': 'ven'
      };

      final config = SalesAccessConfig.fromMap(jsonExemplo);
      expect(config.nomeEmpresa, equals('Diniz'));
      expect(config.downloadPath, equals('/diniz/download/'));
      expect(config.uploadPath, equals('/diniz/upload/'));
      expect(config.databaseFilePrefix, equals('ven'));
    });

    test('AppState persiste e recupera empresa_codigo corretamente', () async {
      AppState().empresa_codigo = 'DZ1000SW';
      expect(AppState().empresa_codigo, equals('DZ1000SW'));

      // Simula reinicialização do AppState
      AppState.reset();
      await AppState().initializePersistedState();
      expect(AppState().empresa_codigo, equals('DZ1000SW'));
    });
  });

  group('Item 2 e 3: Navegação pós-carga e NavBarService', () {
    test('NavBarService.navegarParaHome atualiza a tab atual para HomePage', () {
      final navBar = NavBarService();
      navBar.selectTab('FerramentasPage');
      expect(navBar.currentTab, equals('FerramentasPage'));

      navBar.navegarParaHome();
      expect(navBar.currentTab, equals(NavBarService.homeTab));
    });
  });

  group('Item 4: Consulta de Estoque com Filial e Fallback cadpro00', () {
    test('obterEstoqueDisponivel retorna saldo da estpro00 quando existe registro para a filial', () async {
      final db = await openDatabase(inMemoryDatabasePath, version: 1,
          onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE cadpro00 (
            pro00_codigo INTEGER PRIMARY KEY,
            pro00_descri TEXT,
            pro00_qtdest REAL
          );
        ''');
        await db.execute('''
          CREATE TABLE estpro00 (
            pro00_codfil INTEGER,
            pro00_codpro INTEGER,
            pro00_qtdest REAL,
            pro00_qtdpen REAL
          );
        ''');

        await db.insert('cadpro00', {
          'pro00_codigo': 1001,
          'pro00_descri': 'Produto A',
          'pro00_qtdest': 50.0,
        });

        await db.insert('estpro00', {
          'pro00_codfil': 1,
          'pro00_codpro': 1001,
          'pro00_qtdest': 35.0,
          'pro00_qtdpen': 0.0,
        });
        await db.insert('estpro00', {
          'pro00_codfil': 2,
          'pro00_codpro': 1001,
          'pro00_qtdest': 15.0,
          'pro00_qtdpen': 0.0,
        });
      });

      try {
        final service = EstoqueFilialService(database: db);
        final estoqueFilial1 = await service.obterEstoqueDisponivel(
          codigoProduto: 1001,
          filialAtiva: 1,
        );
        expect(estoqueFilial1, equals(35.0));

        final estoqueFilial2 = await service.obterEstoqueDisponivel(
          codigoProduto: 1001,
          filialAtiva: 2,
        );
        expect(estoqueFilial2, equals(15.0));
      } finally {
        await db.close();
      }
    });

    test('obterEstoqueDisponivel faz fallback para cadpro00.pro00_qtdest se estpro00 for nulo/ausente', () async {
      final db = await openDatabase(inMemoryDatabasePath, version: 1,
          onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE cadpro00 (
            pro00_codigo INTEGER PRIMARY KEY,
            pro00_descri TEXT,
            pro00_qtdest REAL
          );
        ''');
        await db.execute('''
          CREATE TABLE estpro00 (
            pro00_codfil INTEGER,
            pro00_codpro INTEGER,
            pro00_qtdest REAL,
            pro00_qtdpen REAL
          );
        ''');

        await db.insert('cadpro00', {
          'pro00_codigo': 2002,
          'pro00_descri': 'Produto Sem Registro em estpro00',
          'pro00_qtdest': 42.0,
        });
      });

      try {
        final service = EstoqueFilialService(database: db);
        final estoque = await service.obterEstoqueDisponivel(
          codigoProduto: 2002,
          filialAtiva: 1,
        );
        // Fallback COALESCE(e.pro00_qtdest, p.pro00_qtdest, 0.0) -> 42.0
        expect(estoque, equals(42.0));
      } finally {
        await db.close();
      }
    });

    test('LocalSalesDatabaseService.closeAndResetConnectionPool fecha e limpa conexões', () async {
      await expectLater(
        LocalSalesDatabaseService.closeAndResetConnectionPool(),
        completes,
      );
    });
  });

  group('Item 5: Verificação de Carga Remota e Mensagem sem Carga', () {
    test('SalesDatabaseInstallResult suporta propriedade success e mensagem amigável', () {
      const resultSemCarga = SalesDatabaseInstallResult(
        message: 'Não há carga disponível para download no momento.',
        success: false,
      );
      expect(resultSemCarga.success, isFalse);
      expect(resultSemCarga.message, equals('Não há carga disponível para download no momento.'));

      const resultSucesso = SalesDatabaseInstallResult(
        message: 'Base local atualizada.',
        success: true,
      );
      expect(resultSucesso.success, isTrue);
    });
  });
}
