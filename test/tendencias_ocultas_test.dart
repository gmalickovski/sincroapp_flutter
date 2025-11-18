import 'package:flutter_test/flutter_test.dart';
import 'package:sincro_app_flutter/services/numerology_engine.dart';

void main() {
  group('Tendencias Ocultas', () {
    test('Pedro Lima -> nenhuma', () {
      final engine = NumerologyEngine(
        nomeCompleto: 'Pedro Lima',
        dataNascimento: '14/02/1990',
      );
      final result = engine.calcular();
      expect(result, isNotNull);
      expect(result!.listas['tendenciasOcultas'], isEmpty);
    });

    test('Jaqueline Martins -> 1 e 5', () {
      final engine = NumerologyEngine(
        nomeCompleto: 'Jaqueline Martins',
        dataNascimento: '01/01/1990',
      );
      final result = engine.calcular();
      expect(result, isNotNull);
      final tendencias = (result!.listas['tendenciasOcultas'] as List<int>);
      expect(tendencias.contains(1), isTrue);
      expect(tendencias.contains(5), isTrue);
    });

    test('Cláudia Delanni Vitória -> 1 e 3', () {
      final engine = NumerologyEngine(
        nomeCompleto: 'Cláudia Delanni Vitória',
        dataNascimento: '31/05/1991',
      );
      final result = engine.calcular();
      expect(result, isNotNull);
      final tendencias = (result!.listas['tendenciasOcultas'] as List<int>);
      expect(tendencias, contains(1));
      expect(tendencias, contains(3));
      expect(tendencias.length, 2);
    });
  });
}
