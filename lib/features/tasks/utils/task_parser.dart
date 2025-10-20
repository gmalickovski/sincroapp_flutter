// lib/features/tasks/utils/task_parser.dart

import 'package:intl/intl.dart';
import 'package:sincro_app_flutter/common/utils/string_sanitizer.dart';
import 'package:sincro_app_flutter/features/goals/models/goal_model.dart';
import 'package:sincro_app_flutter/services/firestore_service.dart';

class ParsedTask {
  final String cleanText;
  final List<String> tags;
  final String? journeyId; // Armazena o ID da meta
  final String? journeyTitle; // Armazena o Título original da meta
  final DateTime? dueDate;

  ParsedTask({
    required this.cleanText,
    this.tags = const [],
    this.journeyId,
    this.journeyTitle,
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
    // --- ADICIONADO (para bater com o regex do modal) ---
    'jan': 1,
    'fev': 2,
    'mar': 3,
    'abr': 4,
    'mai': 5,
    'jun': 6,
    'jul': 7,
    'ago': 8,
    'set': 9,
    'out': 10,
    'nov': 11,
    'dez': 12,
    // --- FIM DA ADIÇÃO ---
  };

  static String getMonthPattern() {
    return _monthMap.keys.join('|');
  }

  // --- REGEX UNIFICADOS ---
  static final String _monthPatternStr = getMonthPattern();
  static final _ddMmYyPattern =
      RegExp(r'/\s*(\d{1,2})/(\d{1,2})(?:/(\d{2,4}))?');
  static final _fullDatePattern = RegExp(r'/\s*dia\s+(\d{1,2})(?:\s+de)?\s+(' +
      _monthPatternStr +
      r')(?:\s+de\s+(\d{4}))?');
  // --- FIM ---

  static Future<ParsedTask> parse(String rawText, String userId) async {
    String cleanText = rawText;
    final tags = <String>[];
    String? journeyId;
    String? journeyTitle;

    final tagRegExp = RegExp(r"#(\w+)");
    tagRegExp.allMatches(rawText).forEach((match) {
      tags.add(match.group(1)!);
      cleanText = cleanText.replaceAll(match.group(0)!, '');
    });

    final journeyRegExp = RegExp(r"@(\w+)");
    final journeyMatch = journeyRegExp.firstMatch(rawText);

    if (journeyMatch != null) {
      final extractedTag = journeyMatch.group(1);
      if (extractedTag != null) {
        final firestoreService = FirestoreService();
        final goal = await firestoreService.findGoalBySanitizedTitle(
            userId, extractedTag);

        if (goal != null) {
          journeyId = goal.id;
          journeyTitle = goal.title;
        }
        cleanText = cleanText.replaceAll(journeyMatch.group(0)!, '');
      }
    }

    final dueDate = parseDateFromText(rawText);
    if (dueDate != null) {
      // Remove ambos os padrões de data
      cleanText = cleanText.replaceAll(_ddMmYyPattern, '');
      cleanText = cleanText.replaceAll(_fullDatePattern, '');
    }

    return ParsedTask(
      cleanText: cleanText.trim(),
      tags: tags,
      journeyId: journeyId,
      journeyTitle: journeyTitle,
      dueDate: dueDate,
    );
  }

  static DateTime? parseDateFromText(String text) {
    final textLower = text.toLowerCase();
    final now = DateTime.now();
    // final monthPattern = getMonthPattern(); // Removido, usando _fullDatePattern

    // Usa o RegExp unificado
    var match = _ddMmYyPattern.firstMatch(textLower);
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
        // CRÍTICO: Usa DateTime() para criar data LOCAL
        var date = DateTime(year, month, day);
        if (match.group(3) == null &&
            date.isBefore(DateTime(now.year, now.month, now.day))) {
          date = DateTime(now.year + 1, month, day);
        }
        return date;
      } catch (e) {/* Ignora */}
    }

    // Usa o RegExp unificado
    match = _fullDatePattern.firstMatch(textLower);
    if (match != null) {
      try {
        final day = int.parse(match.group(1)!);
        final monthName = match.group(2)!;
        final month = _monthMap[monthName];
        if (month != null) {
          final year =
              match.group(3) != null ? int.parse(match.group(3)!) : now.year;
          // CRÍTICO: Usa DateTime() para criar data LOCAL
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
