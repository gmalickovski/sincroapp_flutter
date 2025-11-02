import 'package:flutter_test/flutter_test.dart';
import 'package:sincro_app_flutter/services/numerology_engine.dart';

void main() {
  test('calculatePersonalDayForDate retorna 1 para 01/11/2025', () {
    final engine = NumerologyEngine(
      nomeCompleto: 'Teste',
      dataNascimento: '14/02/1990',
    );

    final result = engine.calculatePersonalDayForDate(
      DateTime.utc(2025, 11, 1),
    );

    expect(result, equals(1),
        reason: 'O dia pessoal para 01/11/2025 deve ser 1');
  });
}
