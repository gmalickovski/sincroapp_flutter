// lib/features/tasks/utils/task_parser.dart

import 'package:flutter/foundation.dart';

@immutable
class ParsedTask {
  final String cleanText;
  final List<String> tags;
  // Futuramente: final String? goalId;

  const ParsedTask({
    required this.cleanText,
    this.tags = const [],
  });
}

class TaskParser {
  static ParsedTask parse(String rawText) {
    // Regex para encontrar #tags (palavras que começam com #)
    final tagRegex = RegExp(r'#(\w+)');

    // Extrai todas as tags do texto
    final tags = tagRegex
        .allMatches(rawText)
        .map((match) => match.group(1)!) // Pega o texto da tag sem o '#'
        .toList();

    // Remove as tags e a data do texto para ter o texto "limpo" da tarefa
    final cleanText = rawText
        .replaceAll(tagRegex, '') // Remove as tags
        .replaceAll(
            RegExp(r'/\s*(\d{2}/\d{2}/\d{4}|\d{2}/\d{2})'), '') // Remove a data
        .trim(); // Remove espaços extras no início e fim

    return ParsedTask(
      cleanText: cleanText,
      tags: tags,
    );
  }
}
