import 'package:flutter_test/flutter_test.dart';
import 'package:forca_de_vendas/services/ftp_path_builder.dart';

void main() {
  group('FtpPathBuilder.formatEquipe', () {
    test('pads single digit to 2 digits', () {
      expect(FtpPathBuilder.formatEquipe(7), equals('07'));
      expect(FtpPathBuilder.formatEquipe(0), equals('00'));
    });

    test('keeps two-digit codes unchanged', () {
      expect(FtpPathBuilder.formatEquipe(71), equals('71'));
      expect(FtpPathBuilder.formatEquipe(10), equals('10'));
    });
  });

  group('FtpPathBuilder.getRemotePath', () {
    test('maps pedido to /{empresa}/{equipe}/Externo/', () {
      expect(
        FtpPathBuilder.getRemotePath(
          empresa: 'DINIZ',
          codReg: 7,
          tipo: TipoCarga.pedido,
        ),
        equals('/diniz/07/Externo/'),
      );
    });

    test('maps cliente to /{empresa}/{equipe}/Customer/', () {
      expect(
        FtpPathBuilder.getRemotePath(
          empresa: 'diniz',
          codReg: 71,
          tipo: TipoCarga.cliente,
        ),
        equals('/diniz/71/Customer/'),
      );
    });

    test('maps uploadGeral to /{empresa}/{equipe}/Upload/', () {
      expect(
        FtpPathBuilder.getRemotePath(
          empresa: 'diniz',
          codReg: 1,
          tipo: TipoCarga.uploadGeral,
        ),
        equals('/diniz/01/Upload/'),
      );
    });
  });

  group('FtpPathBuilder file names', () {
    test('getFileNamePedido has no .xml extension', () {
      expect(FtpPathBuilder.getFileNamePedido(71, 1007), equals('p71-1007'));
      expect(FtpPathBuilder.getFileNamePedido(71, 1007), isNot(endsWith('.xml')));
    });

    test('getFileNameCliente has no .xml extension', () {
      expect(FtpPathBuilder.getFileNameCliente(71, 36109), equals('c71-36109'));
      expect(FtpPathBuilder.getFileNameCliente(71, 36109), isNot(endsWith('.xml')));
    });
  });
}
