import 'dart:io';

void main(List<String> args) {
  final path = args.isNotEmpty
      ? args[0]
      : 'lib/features/tasks/presentation/foco_do_dia_screen.dart';
  final file = File(path);
  if (!file.existsSync()) {
    print('File not found: $path');
    return;
  }
  final lines = file.readAsLinesSync();
  final stack = <MapEntry<int, int>>[]; // (line, col)
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    for (var j = 0; j < line.length; j++) {
      final ch = line[j];
      if (ch == '(') {
        stack.add(MapEntry(i + 1, j + 1));
      } else if (ch == ')') {
        if (stack.isNotEmpty) {
          stack.removeLast();
        } else {
          print('Unmatched ) at ${i + 1}:${j + 1}');
        }
      }
    }
  }

  if (stack.isEmpty) {
    print('No unmatched opening parentheses found.');
  } else {
    print('Unmatched opening parentheses (line:col) count=${stack.length}:');
    for (var e in stack) {
      print('  ${e.key}:${e.value}');
    }
  }
}
