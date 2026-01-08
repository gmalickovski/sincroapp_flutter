
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sincro_app_flutter/services/numerology_engine.dart';

void main() {
  test('Verify Profiles', () async {
    final buffer = StringBuffer();
    buffer.writeln('=== VERIFICATION: GUILHERME ===');
    final n1 = NumerologyEngine(
      nomeCompleto: 'Guilherme Malickovski Correa',
      dataNascimento: '14/02/1990',
    );
    final r1 = n1.calculateProfile()!;
    r1.numeros.forEach((k, v) => buffer.writeln('$k: $v'));
    buffer.writeln('Harmonia Conjugal (Calculated): ${r1.numeros['harmoniaConjugal']}');
    
    final harmonia1 = r1.estruturas['harmoniaConjugal'];
    if (harmonia1 != null) {
       buffer.writeln('Harmonia Rule: Vibra: ${harmonia1['vibra']}, Atrai: ${harmonia1['atrai']}, Oposto: ${harmonia1['oposto']}');
    }

    buffer.writeln('\n=== VERIFICATION: CLÁUDIA ===');
    final n2 = NumerologyEngine(
      nomeCompleto: 'Cláudia Delanni Vitória',
      dataNascimento: '31/05/1991',
    );
    final r2 = n2.calculateProfile()!;
    r2.numeros.forEach((k, v) => buffer.writeln('$k: $v'));
    buffer.writeln('Harmonia Conjugal (Calculated): ${r2.numeros['harmoniaConjugal']}');
    final harmonia2 = r2.estruturas['harmoniaConjugal'];
    if (harmonia2 != null) {
       buffer.writeln('Harmonia Rule: Vibra: ${harmonia2['vibra']}, Atrai: ${harmonia2['atrai']}, Oposto: ${harmonia2['oposto']}');
    }
    
    final file = File('test/verification_output.txt');
    await file.writeAsString(buffer.toString());
    print('Output written to test/verification_output.txt');
  });
}
