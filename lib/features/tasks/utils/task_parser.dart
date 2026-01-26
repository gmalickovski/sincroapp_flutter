// lib/features/tasks/utils/task_parser.dart
import 'package:flutter/material.dart'; // Necessário para TimeOfDay
// REMOVIDO: import 'package:sincro_app_flutter/common/utils/string_sanitizer.dart';
import 'package:sincro_app_flutter/models/recurrence_rule.dart';
// REMOVIDO: import 'package:sincro_app_flutter/features/goals/models/goal_model.dart';
// REMOVIDO: import 'package:sincro_app_flutter/services/firestore_service.dart';

class ParsedTask {
  final String cleanText;
  final List<String> tags;
  final List<String> sharedWith; // NOVO
  final String? journeyId;
  final String? journeyTitle;
  final DateTime? dueDate;

  final TimeOfDay? reminderTime;
  final DateTime? reminderAt; // Precise reminder timestamp
  final RecurrenceRule recurrenceRule;

  ParsedTask({
    required this.cleanText,
    this.tags = const [],
    this.sharedWith = const [], // NOVO
    this.journeyId,
    this.journeyTitle,
    this.dueDate,
    this.reminderTime,
    this.reminderAt,
    RecurrenceRule? recurrenceRule,
  }) : recurrenceRule =
            recurrenceRule ?? RecurrenceRule(); // Garante que nunca seja nulo

  ParsedTask copyWith({
    String? cleanText,
    List<String>? tags,
    List<String>? sharedWith, // NOVO
    String? journeyId,
    String? journeyTitle,
    DateTime? dueDate,
    TimeOfDay? reminderTime,
    DateTime? reminderAt,
    RecurrenceRule? recurrenceRule,
  }) {
    return ParsedTask(
      cleanText: cleanText ?? this.cleanText,
      tags: tags ?? this.tags,
      sharedWith: sharedWith ?? this.sharedWith, // NOVO
      journeyId: journeyId ?? this.journeyId,
      journeyTitle: journeyTitle ?? this.journeyTitle,
      dueDate: dueDate ?? this.dueDate,
      reminderTime: reminderTime ?? this.reminderTime,
      reminderAt: reminderAt ?? this.reminderAt,
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

  // Regex para Tags e Mentions
  static final _tagPattern = RegExp(r'#[a-zA-Z0-9_À-ÿ]+');
  static final _mentionPattern = RegExp(r'@[a-z0-9_.]+');

  // --- MÉTODO PARSE ATUALIZADO ---
  static ParsedTask parse(String rawText) {
    String text = rawText;
    final List<String> extractedTags = [];
    final List<String> extractedMentions = [];

    // 1. Extrair Tags (#) e REMOVER do texto (para não duplicar na visualização)
    final tagMatches = _tagPattern.allMatches(text);
    for (final match in tagMatches) {
      // Remove o '#'
      extractedTags.add(match.group(0)!.substring(1));
    }
    // Remove as tags do texto limpo
    text = text.replaceAll(_tagPattern, '').trim();

    // 2. Extrair Mentions (@) e MANTER no texto (contexto)
    final mentionMatches = _mentionPattern.allMatches(text);
    for (final match in mentionMatches) {
      // Remove o '@'
      extractedMentions.add(match.group(0)!.substring(1));
    }
    // NÃO remove mentions do texto

    // 3. Limpa espaços extras que podem ter sobrado após remover tags
    text = text.replaceAll(RegExp(r'\s+'), ' ').trim();

    return ParsedTask(
      cleanText: text,
      tags: extractedTags,
      sharedWith: extractedMentions,
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
