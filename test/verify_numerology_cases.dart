import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sincro_app_flutter/services/numerology_engine.dart';
import 'package:sincro_app_flutter/services/harmony_service.dart';

void main() {
  test('Verify Profiles', () async {
    final buffer = StringBuffer();
    buffer.writeln('=== VERIFICATION: GUILHERME ===');
    final n1 = NumerologyEngine(
      nomeCompleto: 'Guilherme Malickovski Correa',
      dataNascimento: '14/02/1990',
    );
    final r1 = n1.calculateProfile();
    r1.numeros.forEach((k, v) => buffer.writeln('$k: $v'));
    buffer.writeln(
        'Harmonia Conjugal (Calculated): ${r1.numeros['harmoniaConjugal']}');

    buffer.writeln(
        'CHECK: Destino (${r1.numeros['destino']}) + Expressão (${r1.numeros['expressao']}) = ${r1.numeros['destino']! + r1.numeros['expressao']!}');

    // Test Harmony Service
    final hs = HarmonyService();
    final syn = hs.calculateSynastry(
        profileA: r1,
        profileB: NumerologyEngine(
                nomeCompleto: 'Cláudia Delanni Vitória',
                dataNascimento: '31/05/1991')
            .calculateProfile());
    buffer.writeln('Synastry Score: ${syn['score']} - ${syn['status']}');

    buffer.writeln('\n=== VERIFICATION: CLÁUDIA ===');
    final n2 = NumerologyEngine(
      nomeCompleto: 'Cláudia Delanni Vitória',
      dataNascimento: '31/05/1991',
    );
    final r2 = n2.calculateProfile();
    r2.numeros.forEach((k, v) => buffer.writeln('$k: $v'));
    buffer.writeln(
        'Harmonia Conjugal (Calculated): ${r2.numeros['harmoniaConjugal']}');
    buffer.writeln(
        'CHECK: Destino (${r2.numeros['destino']}) + Expressão (${r2.numeros['expressao']}) = ${r2.numeros['destino']! + r2.numeros['expressao']!}');

    buffer.writeln('\n=== VERIFICATION: CLAUDIA (SEM ACENTOS) ===');
    final n3 = NumerologyEngine(
      nomeCompleto: 'Claudia Delanni Vitoria',
      dataNascimento: '31/05/1991',
    );
    final r3 = n3.calculateProfile();
    r3.numeros.forEach((k, v) => buffer.writeln('$k: $v'));
    buffer.writeln(
        'Harmonia Conjugal (Calculated): ${r3.numeros['harmoniaConjugal']}');
    buffer.writeln(
        'CHECK: Destino (${r3.numeros['destino']}) + Expressão (${r3.numeros['expressao']}) = ${r3.numeros['destino']! + r3.numeros['expressao']!}');

    final file = File('test/verification_output.txt');
    await file.writeAsString(buffer.toString());
    print('Output written to test/verification_output.txt');
  });
}
