// lib/features/tasks/utils/task_parser.dart

import 'package:intl/intl.dart';

class ParsedTask {
  final String cleanText;
  final List<String> tags;
  final String? journeyId;
  final DateTime? dueDate;

  ParsedTask({
    required this.cleanText,
    this.tags = const [],
    this.journeyId,
    this.dueDate,
  });
}

class TaskParser {
  static const Map<String, int> _monthMap = {
    'janeiro': 1,
    'fevereiro': 2,
    'março': 3,
    'marco': 3,
    'abril': 4,
    'maio': 5,
    'junho': 6,
    'julho': 7,
    'agosto': 8,
    'setembro': 9,
    'outubro': 10,
    'novembro': 11,
    'dezembro': 12,
  };

  static String getMonthPattern() {
    return _monthMap.keys.join('|');
  }

  static ParsedTask parse(String rawText) {
    String cleanText = rawText;
    final tags = <String>[];
    String? journeyId;

    final tagRegExp = RegExp(r"#(\w+)");
    tagRegExp.allMatches(rawText).forEach((match) {
      tags.add(match.group(1)!);
      cleanText = cleanText.replaceAll(match.group(0)!, '');
    });

    final journeyRegExp = RegExp(r"@(\w+)");
    final journeyMatch = journeyRegExp.firstMatch(rawText);
    if (journeyMatch != null) {
      journeyId = journeyMatch.group(1);
      cleanText = cleanText.replaceAll(journeyMatch.group(0)!, '');
    }

    final dueDate = parseDateFromText(rawText);
    if (dueDate != null) {
      final monthPattern = getMonthPattern();
      final dateRegExp = RegExp(r"/\s*(?:dia\s+\d{1,2}(?:\s+de)?\s+(" +
          monthPattern +
          r")(?:\s+de\s+\d{4})?|\d{1,2}/\d{1,2}(?:/\d{2,4})?)");
      cleanText = cleanText.replaceAll(dateRegExp, '');
    }

    return ParsedTask(
      cleanText: cleanText.trim(),
      tags: tags,
      journeyId: journeyId,
      dueDate: dueDate,
    );
  }

  static DateTime? parseDateFromText(String text) {
    // ... (código do parseDateFromText sem alterações)
    final textLower = text.toLowerCase();
    final now = DateTime.now();
    final monthPattern = getMonthPattern();

    var match =
        RegExp(r'/\s*(\d{1,2})/(\d{1,2})(?:/(\d{2,4}))?').firstMatch(textLower);
    if (match != null) {
      try {
        final day = int.parse(match.group(1)!);
        final month = int.parse(match.group(2)!);
        int year = now.year;
        if (match.group(3) != null) {
          final yearStr = match.group(3)!;
          year = yearStr.length == 2
              ? 2000 + int.parse(yearStr)
              : int.parse(yearStr);
        }
        var date = DateTime(year, month, day);
        if (match.group(3) == null &&
            date.isBefore(DateTime(now.year, now.month, now.day))) {
          date = DateTime(now.year + 1, month, day);
        }
        return date;
      } catch (e) {/* Ignora */}
    }

    match = RegExp(
            r'/\s*dia\s+(\d{1,2})(?:\s+de)?\s+($monthPattern)(?:\s+de\s+(\d{4}))?')
        .firstMatch(textLower);
    if (match != null) {
      try {
        final day = int.parse(match.group(1)!);
        final monthName = match.group(2)!;
        final month = _monthMap[monthName];
        if (month != null) {
          final year =
              match.group(3) != null ? int.parse(match.group(3)!) : now.year;
          var date = DateTime(year, month, day);
          if (match.group(3) == null &&
              date.isBefore(DateTime(now.year, now.month, now.day))) {
            date = DateTime(now.year + 1, month, day);
          }
          return date;
        }
      } catch (e) {/* Ignora */}
    }

    return null;
  }
}
