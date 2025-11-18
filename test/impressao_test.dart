import 'package:flutter_test/flutter_test.dart';
import 'package:sincro_app_flutter/services/numerology_engine.dart';

void main() {
  group('Numero de Impressao', () {
    test('Adriana Gomes -> 3', () {
      final engine = NumerologyEngine(
        nomeCompleto: 'Adriana Gomes',
        dataNascimento: '01/01/1990',
      );
      final result = engine.calcular();
      expect(result, isNotNull);
      expect(result!.numeros['impressao'], 3);
    });

    test('Fábio Costa -> 2', () {
      final engine = NumerologyEngine(
        nomeCompleto: 'Fábio Costa',
        dataNascimento: '02/02/1992',
      );
      final result = engine.calcular();
      expect(result, isNotNull);
      expect(result!.numeros['impressao'], 2);
    });

    test('Ana Elias (11 deve reduzir a 2)', () {
      final engine = NumerologyEngine(
        nomeCompleto: 'Ana Elias',
        dataNascimento: '03/03/1993',
      );
      final result = engine.calcular();
      expect(result, isNotNull);
      expect(result!.numeros['impressao'], 2);
    });
  });
}
