import 'package:flutter_test/flutter_test.dart';
import 'package:forca_de_vendas/action_code/offline_login.dart';
import 'package:forca_de_vendas/app_state.dart';
import 'package:forca_de_vendas/domain/models/status_envio.dart';
import 'package:forca_de_vendas/functions/retorna_mil.dart';
import 'package:forca_de_vendas/services/ftp_path_builder.dart';
import 'package:forca_de_vendas/services/status_envio_db.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart' as p;

import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AppState().initializePersistedState();
  });

  group('Fase 2 - Integridade de Dados, Enums e Sincronização', () {
    test('PedidoSttEnv semantic enum values (0=digitado, 1=empacote, 2=enviados, 3=recebido)', () {
      expect(PedidoSttEnv.digitado.value, equals(0));
      expect(PedidoSttEnv.empacote.value, equals(1));
      expect(PedidoSttEnv.enviados.value, equals(2));
      expect(PedidoSttEnv.recebido.value, equals(3));
    });

    test('StatusEnvioDb writes sttenv = 2 on marcarPedidoEnviado & marcarPedidosEnviados', () async {
      final dbPath = p.join(await getDatabasesPath(), 'test_status_envio.db');
      final db = await openDatabase(dbPath);

      await db.execute('DROP TABLE IF EXISTS pckvendig000');
      await db.execute('''
        CREATE TABLE pckvendig000 (
          ped00_numped INTEGER PRIMARY KEY,
          ped00_sttenv INTEGER DEFAULT 0
        )
      ''');
      await db.insert('pckvendig000', {'ped00_numped': 101, 'ped00_sttenv': 1});
      await db.insert('pckvendig000', {'ped00_numped': 102, 'ped00_sttenv': 1});
      await db.close();

      final statusDb = StatusEnvioDb(dbPath: dbPath);

      // Envio individual
      await statusDb.marcarPedidoEnviado(101);

      // Envio em lote
      await statusDb.marcarPedidosEnviados([102]);

      final verifyDb = await openDatabase(dbPath);
      final rows = await verifyDb.query('pckvendig000');
      await verifyDb.close();

      final row101 = rows.firstWhere((r) => r['ped00_numped'] == 101);
      final row102 = rows.firstWhere((r) => r['ped00_numped'] == 102);

      expect(row101['ped00_sttenv'], equals(2));
      expect(row102['ped00_sttenv'], equals(2));
    });

    test('Nomenclatura XML Cliente usa retornaMil() com 5 digitos', () {
      final now = DateTime(2026, 3, 1, 10, 30, 45, 123);
      final mil = retornaMil(now: now);
      expect(mil, isNotNull);
      expect(mil.toString().length, lessThanOrEqualTo(5));

      final fileName = FtpPathBuilder.getFileNameClienteMil(71, ms: mil);
      expect(fileName, equals('c71-$mil.xml'));
    });

    test('offlineLogin loads cadrep00 parameters into AppState', () async {
      final dbPath = p.join(await getDatabasesPath(), 'test_cadrep_fase2.db');
      final db = await openDatabase(dbPath);

      await db.execute('DROP TABLE IF EXISTS cadrep00');
      await db.execute('''
        CREATE TABLE cadrep00 (
          ven00_codigo INTEGER PRIMARY KEY,
          ven00_descri TEXT,
          ven00_passwo TEXT,
          ven00_codeqp INTEGER,
          ven00_chkest INTEGER,
          ven00_gerbonfor INTEGER,
          ven00_chkage INTEGER,
          ven00_ignlimfis INTEGER,
          ven00_maxitmdig INTEGER,
          ven00_passet TEXT
        )
      ''');

      await db.insert('cadrep00', {
        'ven00_codigo': 10,
        'ven00_descri': 'Representante Master',
        'ven00_passwo': '1234',
        'ven00_codeqp': 7,
        'ven00_chkest': 1,
        'ven00_gerbonfor': 1,
        'ven00_chkage': 1,
        'ven00_ignlimfis': 1,
        'ven00_maxitmdig': 50,
        'ven00_passet': 'SUPER999',
      });
      await db.close();

      final result = await offlineLogin('10', dbPath: dbPath);
      expect(result.success, isTrue);
      expect(AppState().ven_chkage, equals(1));
      expect(AppState().ven_ignlimfis, equals(1));
      expect(AppState().ven_maxitmdig, equals(50));
      expect(AppState().ven_passet, equals('SUPER999'));

      try { await databaseFactory.deleteDatabase(dbPath); } catch (_) {}
    });
  });
}
