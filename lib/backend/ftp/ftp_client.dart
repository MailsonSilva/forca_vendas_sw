import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Configuracao central das credenciais FTP do host legado homologado.
///
/// Mantenha aqui as unicas credenciais usadas por todas as actions que
/// precisam falar com o servidor FTP (download de carga, upload de carga,
/// upload de cadastros pendentes, etc.). Evita espalhar host/user/password
/// em varios arquivos.
class FtpConfig {
  static const String host = 'ftp.suportware.com.br';
  static const int port = 21;
  static const String user = 'suportware8';
  static const String password = 'sw@660031';
}

/// Cliente FTP minimo baseado em sockets, usado por todas as actions de
/// integracao com o ERP legado Suportware.
///
/// Suporta:
///   - `connect`                -> AUTENTICACAO (USER/PASS) + TYPE I
///   - `cwd(String path)`       -> troca de diretorio
///   - `retr(String fileName)`  -> download (retorna bytes)
///   - `stor(String, List<int>)`-> upload (envia bytes)
///   - `quit()`                 -> encerra conexao
///
/// Todas as transferencias usam modo passivo (PASV) e transferencia binaria
/// (TYPE I). Implementacao extraida e unificada das antigas duplicatas
/// presentes em `first_access_login.dart`,
/// `download_database_from_ftp.dart` e `upload_database_to_ftp.dart`.
class FtpClient {
  FtpClient._(this._socket, this._lines);

  final Socket _socket;
  final StreamIterator<String> _lines;

  /// Conecta ao host, autentica e ja entra em modo binario (TYPE I).
  static Future<FtpClient> connect({
    String host = FtpConfig.host,
    int port = FtpConfig.port,
    String user = FtpConfig.user,
    String password = FtpConfig.password,
    Duration timeout = const Duration(seconds: 20),
  }) async {
    final socket = await Socket.connect(host, port, timeout: timeout);
    final lines = StreamIterator(
      socket
          .map<List<int>>((chunk) => chunk)
          .transform(utf8.decoder)
          .transform(const LineSplitter()),
    );
    final client = FtpClient._(socket, lines);
    await client._expect([220]);
    await client._cmd('USER $user', [230, 331]);
    await client._cmd('PASS $password', [230]);
    await client._cmd('TYPE I', [200]);
    return client;
  }

  /// Troca de diretorio. Aceita path absoluto (`/x/y`) ou relativo (`pasta`).
  Future<void> cwd(String path) => _cmd('CWD $path', [250]);

  /// Criar diretorio no FTP (se nao existir).
  Future<void> mkd(String path) => _cmd('MKD $path', [257, 250, 550]);

  /// Download de um arquivo do diretorio atual. Retorna os bytes em memoria.
  Future<List<int>> retr(String fileName) async {
    final dataSocket = await _openPassiveDataSocket();
    _write('RETR $fileName');
    final preliminary = await _readReply();
    if (preliminary.code != 125 && preliminary.code != 150) {
      dataSocket.destroy();
      throw StateError('FTP RETR recusado: ${preliminary.message}');
    }
    final completer = Completer<List<int>>();
    final buffer = <int>[];

    dataSocket.listen(
      buffer.addAll,
      onError: completer.completeError,
      onDone: () {
        dataSocket.destroy();
        completer.complete(buffer);
      },
      cancelOnError: true,
    );

    final bytes = await completer.future.timeout(const Duration(seconds: 60));
    await _expect([226, 250]);
    return bytes;
  }

  /// Upload de bytes para o diretorio atual com o nome informado.
  /// Dispara [onProgress] (opcional) com o total de bytes ja enviados para
  /// atualizar barras de progresso na UI.
  Future<void> stor(
    String fileName,
    List<int> bytes, {
    void Function(int sent)? onProgress,
  }) async {
    final dataSocket = await _openPassiveDataSocket();
    _write('STOR $fileName');
    final preliminary = await _readReply();
    if (preliminary.code != 125 && preliminary.code != 150) {
      dataSocket.destroy();
      throw StateError('FTP STOR recusado: ${preliminary.message}');
    }

    if (onProgress == null) {
      dataSocket.add(bytes);
      await dataSocket.flush();
    } else {
      // Envio em chunks para reportar progresso real da transferencia.
      const chunkSize = 8 * 1024;
      int offset = 0;
      while (offset < bytes.length) {
        final end = (offset + chunkSize > bytes.length)
            ? bytes.length
            : offset + chunkSize;
        dataSocket.add(bytes.sublist(offset, end));
        await dataSocket.flush();
        offset = end;
        onProgress(offset);
      }
    }
    await dataSocket.flush();
    await dataSocket.close();
    await _expect([226, 250]);
  }

  /// Retorna o tamanho remoto do arquivo no diretorio atual.
  ///
  /// Usado apos `stor` para confirmar que o servidor realmente recebeu a
  /// quantidade de bytes esperada antes de mover o arquivo local para enviados.
  Future<int> size(String fileName) async {
    final reply = await _cmd('SIZE $fileName', [213]);
    final parts = reply.message.trim().split(RegExp(r'\s+'));
    if (parts.length < 2) {
      throw StateError('Resposta SIZE invalida: ${reply.message}');
    }
    return int.parse(parts[1]);
  }

  /// Encerramento limpo da conexao. Ignora erros de desconexao.
  Future<void> quit() async {
    try {
      await _cmd('QUIT', [221]);
    } catch (_) {}
    await _lines.cancel();
    await _socket.close();
  }

  Future<Socket> _openPassiveDataSocket() async {
    final reply = await _cmd('PASV', [227]);
    final match = RegExp(r'\((\d+),(\d+),(\d+),(\d+),(\d+),(\d+)\)')
        .firstMatch(reply.message);
    if (match == null) {
      throw StateError('Resposta PASV invalida: ${reply.message}');
    }
    final parts = List<int>.generate(6, (i) => int.parse(match.group(i + 1)!));
    final host = '${parts[0]}.${parts[1]}.${parts[2]}.${parts[3]}';
    final port = parts[4] * 256 + parts[5];
    return Socket.connect(host, port, timeout: const Duration(seconds: 20));
  }

  Future<_FtpReply> _cmd(String command, List<int> expected) async {
    _write(command);
    return _expect(expected);
  }

  Future<_FtpReply> _expect(List<int> expected) async {
    final reply = await _readReply();
    if (!expected.contains(reply.code)) {
      throw StateError('FTP ${reply.code}: ${reply.message}');
    }
    return reply;
  }

  void _write(String command) {
    _socket.write('$command\r\n');
  }

  Future<_FtpReply> _readReply() async {
    if (!await _lines.moveNext()) {
      throw const SocketException('Conexao FTP encerrada.');
    }
    final first = _lines.current;
    if (first.length < 3) {
      throw StateError('Resposta FTP invalida: $first');
    }
    final code = int.parse(first.substring(0, 3));
    final messages = <String>[first];
    if (first.length > 3 && first[3] == '-') {
      while (await _lines.moveNext()) {
        final line = _lines.current;
        messages.add(line);
        if (line.startsWith('$code ')) break;
      }
    }
    return _FtpReply(code, messages.join('\n'));
  }
}

class _FtpReply {
  const _FtpReply(this.code, this.message);
  final int code;
  final String message;
}
