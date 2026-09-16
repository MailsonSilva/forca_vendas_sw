import 'package:flutter_test/flutter_test.dart';
import 'package:forca_de_vendas/backend/ftp/ftp_transport.dart';
import 'package:forca_de_vendas/data/repositories/sales_database_repository.dart';

class _MockFtpTransport implements FtpTransport {
  final List<String> commands = [];
  final Map<String, String> renamedFiles = {};

  @override
  Future<void> cwd(String path) async {
    commands.add('CWD $path');
  }

  @override
  Future<void> mkd(String path) async {
    commands.add('MKD $path');
  }

  @override
  Future<List<int>> retr(String fileName) async {
    commands.add('RETR $fileName');
    return [1, 2, 3];
  }

  @override
  Future<void> stor(String fileName, List<int> bytes, {void Function(int sent)? onProgress}) async {
    commands.add('STOR $fileName');
  }

  @override
  Future<int> size(String fileName) async => 3;

  @override
  Future<List<String>> nlst([String? path]) async => [];

  @override
  Future<void> dele(String fileName) async {
    commands.add('DELE $fileName');
  }

  @override
  Future<void> rename(String oldName, String newName) async {
    commands.add('RENAME $oldName -> $newName');
    renamedFiles[oldName] = newName;
  }

  @override
  Future<void> quit() async {
    commands.add('QUIT');
  }
}

void main() {
  group('Regra de Renomeação no FTP pós-download de carga', () {
    test('formata o novo nome no padrão ven+codigo+.YYYY-MM-DD HH-mm-ss', () {
      final dataHora = DateTime(2025, 3, 7, 14, 8, 2);

      expect(
        SalesDatabaseRepository.gerarNomeArquivoRenomeado('ven105.crg', dataHora),
        'ven105.2025-03-07 14-08-02',
      );

      final dataHora2 = DateTime(2026, 9, 15, 14, 54, 40);
      expect(
        SalesDatabaseRepository.gerarNomeArquivoRenomeado('ven1.crg', dataHora2),
        'ven1.2026-09-15 14-54-40',
      );
    });

    test('executa renomeação no transporte FTP com sucesso', () async {
      final mockFtp = _MockFtpTransport();
      await mockFtp.rename('carga_105.db', 'carga_105_20260915_145440');

      expect(mockFtp.renamedFiles['carga_105.db'], 'carga_105_20260915_145440');
      expect(mockFtp.commands.contains('RENAME carga_105.db -> carga_105_20260915_145440'), isTrue);
    });
  });
}
