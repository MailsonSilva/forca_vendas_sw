import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forca_de_vendas/core/formatters/upper_case_text_formatter.dart';
import 'package:forca_de_vendas/services/filial_service.dart';
import 'package:forca_de_vendas/backend/schema/structs/lista_padrao_struct.dart';

void main() {
  group('SPEC-049 - Seam 1: UpperCaseTextFormatter', () {
    final formatter = UpperCaseTextFormatter();

    test('converte texto em minúsculas para maiúsculas', () {
      const oldValue = TextEditingValue.empty;
      const newValue = TextEditingValue(
        text: 'empresa123abc',
        selection: TextSelection.collapsed(offset: 13),
      );

      final result = formatter.formatEditUpdate(oldValue, newValue);

      expect(result.text, equals('EMPRESA123ABC'));
      expect(result.selection.baseOffset, equals(13));
    });

    test('preserva texto já em maiúsculas e caracteres especiais', () {
      const oldValue = TextEditingValue(text: 'ABC');
      const newValue = TextEditingValue(
        text: 'ABC-01_X',
        selection: TextSelection.collapsed(offset: 8),
      );

      final result = formatter.formatEditUpdate(oldValue, newValue);

      expect(result.text, equals('ABC-01_X'));
    });
  });

  group('SPEC-049 - Seam 2: Auto-seleção de Linha Única', () {
    test('retorna a linha quando a lista possui exatamente 1 registro', () {
      final linhas = [
        ListaPadraoStruct(codigo: '10', descricao: 'LINHA PRINCIPAL'),
      ];

      final selecionada = autoSelecionarLinhaSeUnica(linhas);

      expect(selecionada, isNotNull);
      expect(selecionada!.codigo, equals('10'));
      expect(selecionada.descricao, equals('LINHA PRINCIPAL'));
    });

    test('retorna null quando a lista possui mais de 1 registro', () {
      final linhas = [
        ListaPadraoStruct(codigo: '10', descricao: 'LINHA 1'),
        ListaPadraoStruct(codigo: '20', descricao: 'LINHA 2'),
      ];

      final selecionada = autoSelecionarLinhaSeUnica(linhas);

      expect(selecionada, isNull);
    });

    test('retorna null quando a lista estiver vazia', () {
      final selecionada = autoSelecionarLinhaSeUnica([]);
      expect(selecionada, isNull);
    });
  });

  group('SPEC-049 - Seam 3: Regra Canônica de Decisão de Filiais (ven00_selfil)', () {
    test('ven00_selfil == 0 (Monofilial travada): define ven00_codfil diretamente sem abrir modal', () {
      final decisao = avaliarRegraSelecaoFilial(
        venSelfil: 0,
        venCodfil: 2,
        filiaisEstoque: ['01', '02', '03'],
      );

      expect(decisao.precisaAbrirModal, isFalse);
      expect(decisao.filialDefinida, equals(2));
    });

    test('ven00_selfil == 0 com ven00_codfil <= 0: fallback seguro para 1', () {
      final decisao = avaliarRegraSelecaoFilial(
        venSelfil: 0,
        venCodfil: 0,
        filiaisEstoque: ['05'],
      );

      expect(decisao.precisaAbrirModal, isFalse);
      expect(decisao.filialDefinida, equals(1));
    });

    test('ven00_selfil == 1 com 2 ou mais filiais em estoque: exige abertura do modal', () {
      final decisao = avaliarRegraSelecaoFilial(
        venSelfil: 1,
        venCodfil: 1,
        filiaisEstoque: ['01', '02'],
      );

      expect(decisao.precisaAbrirModal, isTrue);
      expect(decisao.filiaisDisponiveis, equals(['01', '02']));
    });

    test('ven00_selfil == 1 com apenas 1 filial em estoque: seleciona diretamente sem abrir modal', () {
      final decisao = avaliarRegraSelecaoFilial(
        venSelfil: 1,
        venCodfil: 1,
        filiaisEstoque: ['03'],
      );

      expect(decisao.precisaAbrirModal, isFalse);
      expect(decisao.filialDefinida, equals(3));
    });

    test('ven00_selfil == 1 com 0 filiais em estoque: fallback para ven00_codfil sem modal', () {
      final decisao = avaliarRegraSelecaoFilial(
        venSelfil: 1,
        venCodfil: 4,
        filiaisEstoque: [],
      );

      expect(decisao.precisaAbrirModal, isFalse);
      expect(decisao.filialDefinida, equals(4));
    });
  });
}
