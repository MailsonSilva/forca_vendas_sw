// ignore_for_file: avoid_print

import 'dart:io';
import 'dart:async';

import 'package:workmanager/workmanager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '/action_code/download_database_from_ftp.dart';

// ─── Task names ─────────────────────────────────────────────────────────────
const String kTaskSyncImgParcial = 'syncImagesParcial';
const String kTaskSyncImgTotal = 'syncImagesTotal';
const String kTaskSyncDb = 'syncDatabase';

// ─── SharedPreferences keys (IPC bridge between WorkManager isolate & UI) ───
const String kPrefImgStatus = 'bg_img_status';
const String kPrefImgProgress = 'bg_img_progress';
const String kPrefImgText = 'bg_img_text';
const String kPrefDbStatus = 'bg_db_status';
const String kPrefDbProgress = 'bg_db_progress';
const String kPrefDbText = 'bg_db_text';

// ─── Image sync constants ────────────────────────────────────────────────────
const String _imageBaseUrl =
    'http://heh08x312dp.sn.mynetname.net:8080/catalogo';
const String _imageSubdir = 'images/catalogo_imagens';

// ─── WorkManager dispatcher (MUST be top-level) ─────────────────────────────
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    final prefs = await SharedPreferences.getInstance();
    try {
      switch (taskName) {
        case kTaskSyncImgParcial:
          await _imageDownloadWork(modo: 'parcial', prefs: prefs);
          break;
        case kTaskSyncImgTotal:
          await _imageDownloadWork(modo: 'total', prefs: prefs);
          break;
        case kTaskSyncDb:
          await _dbDownloadWork(
            empresaCodigo: inputData?['empresaCodigo'] ?? '',
            vendedorCodigo: inputData?['vendedorCodigo'] ?? '',
            prefs: prefs,
          );
          break;
        default:
          print('[WorkManager] Unknown task: $taskName');
          return false;
      }
      return true;
    } catch (e) {
      print('[WorkManager] Task $taskName error: $e');
      if (taskName == kTaskSyncDb) {
        await prefs.setString(kPrefDbStatus, 'error');
        await prefs.setString(kPrefDbText, 'Erro: ${e.toString()}');
        await prefs.setDouble(kPrefDbProgress, 0.0);
      } else {
        await prefs.setString(kPrefImgStatus, 'error');
        await prefs.setString(kPrefImgText, 'Erro: ${e.toString()}');
        await prefs.setDouble(kPrefImgProgress, 0.0);
      }
      return false;
    }
  });
}

// ─── Image download implementation ──────────────────────────────────────────
Future<void> _imageDownloadWork({
  required String modo,
  required SharedPreferences prefs,
}) async {
  await prefs.setString(kPrefImgStatus, 'baixando');
  await prefs.setDouble(kPrefImgProgress, 0.0);
  await prefs.setString(kPrefImgText, 'Preparando carga de fotos...');

  final directory = await getApplicationDocumentsDirectory();
  final targetDir = Directory('${directory.path}/$_imageSubdir');
  if (!await targetDir.exists()) {
    await targetDir.create(recursive: true);
  }

  final String manifestoFile =
      (modo == 'parcial') ? '_partial.txt' : '_full.txt';
  final response = await http
      .get(Uri.parse('$_imageBaseUrl/$manifestoFile'))
      .timeout(const Duration(seconds: 15));

  if (response.statusCode != 200) {
    throw Exception(
        'Manifesto HTTP ${response.statusCode} em $manifestoFile');
  }

  final List<String> listaImagens = response.body
      .split('\n')
      .map((l) => l.trim())
      .where((l) => l.isNotEmpty)
      .toList();

  final int total = listaImagens.length;
  int ok = 0;
  int falhas = 0;

  for (var imgName in listaImagens) {
    try {
      final file = File('${targetDir.path}/$imgName');
      if (modo == 'parcial' && await file.exists()) {
        ok++;
      } else {
        final imgResp = await http
            .get(Uri.parse('$_imageBaseUrl/$imgName'))
            .timeout(const Duration(seconds: 15));
        if (imgResp.statusCode == 200) {
          await file.writeAsBytes(imgResp.bodyBytes);
          ok++;
        } else {
          falhas++;
        }
      }
    } catch (_) {
      falhas++;
    }

    if (total > 0) {
      await prefs.setDouble(kPrefImgProgress, ok / total);
      await prefs.setString(
          kPrefImgText, 'Baixando imagem $ok de $total...');
    }
  }

  await prefs.setString(kPrefImgStatus, 'complete');
  await prefs.setDouble(kPrefImgProgress, 1.0);
  await prefs.setString(
      kPrefImgText, 'Concluido! $ok fotos salvas. Falhas: $falhas');
}

// ─── DB download implementation ─────────────────────────────────────────────
Future<void> _dbDownloadWork({
  required String empresaCodigo,
  required String vendedorCodigo,
  required SharedPreferences prefs,
}) async {
  await prefs.setString(kPrefDbStatus, 'baixando');
  await prefs.setDouble(kPrefDbProgress, 0.0);
  await prefs.setString(kPrefDbText, 'Baixando carga via FTP...');

  final result =
      await downloadDatabaseFromFtp(empresaCodigo, vendedorCodigo);

  if (result.success) {
    await prefs.setString(kPrefDbStatus, 'complete');
    await prefs.setDouble(kPrefDbProgress, 1.0);
    await prefs.setString(kPrefDbText, result.message);
  } else {
    await prefs.setString(kPrefDbStatus, 'error');
    await prefs.setDouble(kPrefDbProgress, 1.0);
    await prefs.setString(kPrefDbText, result.message);
  }
}

// ─── Public singleton service ─────────────────────────────────────────────────
class BackgroundSyncService {
  BackgroundSyncService._();
  static final BackgroundSyncService instance = BackgroundSyncService._();

  bool _initialized = false;

  /// Must be called once in main(), before runApp().
  void initialize() {
    if (_initialized) return;
    _initialized = true;
    Workmanager().initialize(
      callbackDispatcher,
    );
  }

  // ── Image sync ──────────────────────────────────────────────────────────────

  Future<void> startImageSync(String modo) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(kPrefImgStatus, 'baixando');
    await prefs.setDouble(kPrefImgProgress, 0.0);
    await prefs.setString(kPrefImgText, 'Iniciando download em background...');

    final taskName =
        modo == 'parcial' ? kTaskSyncImgParcial : kTaskSyncImgTotal;
    await Workmanager().cancelByUniqueName(taskName);
    await Workmanager().registerOneOffTask(
      taskName,
      taskName,
      constraints: Constraints(
        networkType: NetworkType.connected,
      ),
      existingWorkPolicy: ExistingWorkPolicy.replace,
    );
  }

  Future<Map<String, dynamic>> pollImageSyncStatus() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    return {
      'status': prefs.getString(kPrefImgStatus) ?? 'idle',
      'progress': prefs.getDouble(kPrefImgProgress) ?? 0.0,
      'text': prefs.getString(kPrefImgText) ?? '',
    };
  }

  Future<void> resetImageStatus() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(kPrefImgStatus, 'idle');
    await prefs.setDouble(kPrefImgProgress, 0.0);
    await prefs.setString(kPrefImgText, '');
  }

  // ── DB sync ─────────────────────────────────────────────────────────────────

  Future<void> startDbSync({
    required String empresaCodigo,
    required String vendedorCodigo,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(kPrefDbStatus, 'baixando');
    await prefs.setDouble(kPrefDbProgress, 0.0);
    await prefs.setString(kPrefDbText, 'Iniciando download em background...');

    await Workmanager().cancelByUniqueName(kTaskSyncDb);
    await Workmanager().registerOneOffTask(
      kTaskSyncDb,
      kTaskSyncDb,
      inputData: {
        'empresaCodigo': empresaCodigo,
        'vendedorCodigo': vendedorCodigo,
      },
      constraints: Constraints(
        networkType: NetworkType.connected,
      ),
      existingWorkPolicy: ExistingWorkPolicy.replace,
    );
  }

  Future<Map<String, dynamic>> pollDbSyncStatus() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    return {
      'status': prefs.getString(kPrefDbStatus) ?? 'idle',
      'progress': prefs.getDouble(kPrefDbProgress) ?? 0.0,
      'text': prefs.getString(kPrefDbText) ?? '',
    };
  }

  Future<void> resetDbStatus() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(kPrefDbStatus, 'idle');
    await prefs.setDouble(kPrefDbProgress, 0.0);
    await prefs.setString(kPrefDbText, '');
  }
}
