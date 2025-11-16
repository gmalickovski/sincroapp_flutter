import 'dart:io';

void main() {
  const path = 'lib/features/tasks/presentation/foco_do_dia_screen.dart';
  final lines = File(path).readAsLinesSync();
  int cum = 0;
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    cum += '('.allMatches(line).length;
    cum -= ')'.allMatches(line).length;
    if (cum != 0) {
      print(
          '${i + 1}: $cum: ${line.length > 200 ? line.substring(0, 200) : line}');
    }
  }
  print('Final cum: $cum');
}
