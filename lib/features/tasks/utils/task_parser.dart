// lib/features/tasks/utils/task_parser.dart
import 'package:flutter/material.dart'; // Necessário para TimeOfDay
// REMOVIDO: import 'package:sincro_app_flutter/common/utils/string_sanitizer.dart';
import 'package:sincro_app_flutter/common/widgets/custom_recurrence_picker_modal.dart';
// REMOVIDO: import 'package:sincro_app_flutter/features/goals/models/goal_model.dart';
// REMOVIDO: import 'package:sincro_app_flutter/services/firestore_service.dart';

class ParsedTask {
  final String cleanText;
  final List<String> tags;
  final String? journeyId;
  final String? journeyTitle;
  final DateTime? dueDate;

  final TimeOfDay? reminderTime;
  final RecurrenceRule recurrenceRule;

  ParsedTask({
    required this.cleanText,
    this.tags = const [],
    this.journeyId,
    this.journeyTitle,
    this.dueDate,
    this.reminderTime,
    RecurrenceRule? recurrenceRule,
  }) : recurrenceRule =
            recurrenceRule ?? RecurrenceRule(); // Garante que nunca seja nulo

  ParsedTask copyWith({
    String? cleanText,
    List<String>? tags,
    String? journeyId,
    String? journeyTitle,
    DateTime? dueDate,
    TimeOfDay? reminderTime,
    RecurrenceRule? recurrenceRule,
  }) {
    return ParsedTask(
      cleanText: cleanText ?? this.cleanText,
      tags: tags ?? this.tags,
      journeyId: journeyId ?? this.journeyId,
      journeyTitle: journeyTitle ?? this.journeyTitle,
      dueDate: dueDate ?? this.dueDate,
      reminderTime: reminderTime ?? this.reminderTime,
      recurrenceRule: recurrenceRule ?? this.recurrenceRule,
    );
  }
}

class TaskParser {
  // Mapas e Regex de DATA (Mantidos para _parseDateFromText, se necessário em outro lugar)
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
  };

  static String getMonthPattern() {
    return _monthMap.keys.join('|');
  }

  static final String _monthPatternStr = getMonthPattern();
  static final _ddMmYyPattern =
      RegExp(r'/\s*(\d{1,2})/(\d{1,2})(?:/(\d{2,4}))?', caseSensitive: false);
  static final _fullDatePattern = RegExp(
      r'/\s*dia\s+(\d{1,2})(?:\s+de)?\s+(' +
          _monthPatternStr +
          r')(?:\s+de\s+(\d{4}))?',
      caseSensitive: false);

  // --- MÉTODO PARSE (SUPER SIMPLIFICADO) ---
  // Apenas retorna o texto limpo. Tags, Metas e Datas são tratadas pela UI.
  static ParsedTask parse(String rawText) {
    return ParsedTask(
      cleanText: rawText.trim(),
    );
  }

  // --- Funções de parse de data mantidas, pois o DatePicker as usava ---

  static DateTime? parseDateFromText(String text) {
    final textLower = text.toLowerCase();
    final now = DateTime.now();

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
        var date = DateTime(year, month, day);
        if (match.group(3) == null &&
            date.isBefore(DateTime(now.year, now.month, now.day))) {
          date = DateTime(now.year + 1, month, day);
        }
        return date;
      } catch (e) {/* Ignora */}
    }

    match = _fullDatePattern.firstMatch(textLower);
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

  static String removeDatePatterns(String text) {
    String cleanedText = text;
    cleanedText = cleanedText.replaceAll(_ddMmYyPattern, '');
    cleanedText = cleanedText.replaceAll(_fullDatePattern, '');
    return cleanedText.trim();
  }
}
