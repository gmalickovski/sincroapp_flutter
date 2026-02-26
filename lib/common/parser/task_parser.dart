// lib/common/parser/task_parser.dart

import 'package:flutter/material.dart';
import 'package:sincro_app_flutter/models/recurrence_rule.dart';
import 'package:sincro_app_flutter/features/tasks/models/task_model.dart';

// ─── Tipos de chave do parser ───
enum ParserKeyType { tag, mention, goal }

// ─── Informação de trigger ativo (para popups) ───
class ParserTrigger {
  final ParserKeyType type;
  final String query;
  final int startIndex;
  const ParserTrigger({
    required this.type,
    required this.query,
    required this.startIndex,
  });
}

// ─── Sugestão genérica para o popup ───
class ParserSuggestion {
  final String id;
  final String label;
  final String? description;
  final ParserKeyType type;

  const ParserSuggestion({
    required this.id,
    required this.label,
    required this.type,
    this.description,
  });
}

// ─── Resultado do parsing ───
class ParsedTask {
  final String cleanText;
  final List<String> tags;
  final List<String> sharedWith;
  final List<String> goals;
  final String? journeyId;
  final String? journeyTitle;
  final DateTime? dueDate;
  final TimeOfDay? reminderTime;
  final DateTime? reminderAt;
  final List<int>? reminderOffsets;
  final RecurrenceRule recurrenceRule;

  ParsedTask({
    required this.cleanText,
    this.tags = const [],
    this.sharedWith = const [],
    this.goals = const [],
    this.journeyId,
    this.journeyTitle,
    this.dueDate,
    this.reminderTime,
    this.reminderAt,
    this.reminderOffsets,
    RecurrenceRule? recurrenceRule,
  }) : recurrenceRule = recurrenceRule ?? RecurrenceRule();

  ParsedTask copyWith({
    String? cleanText,
    List<String>? tags,
    List<String>? sharedWith,
    List<String>? goals,
    String? journeyId,
    String? journeyTitle,
    DateTime? dueDate,
    TimeOfDay? reminderTime,
    DateTime? reminderAt,
    List<int>? reminderOffsets,
    RecurrenceRule? recurrenceRule,
  }) {
    return ParsedTask(
      cleanText: cleanText ?? this.cleanText,
      tags: tags ?? this.tags,
      sharedWith: sharedWith ?? this.sharedWith,
      goals: goals ?? this.goals,
      journeyId: journeyId ?? this.journeyId,
      journeyTitle: journeyTitle ?? this.journeyTitle,
      dueDate: dueDate ?? this.dueDate,
      reminderTime: reminderTime ?? this.reminderTime,
      reminderAt: reminderAt ?? this.reminderAt,
      reminderOffsets: reminderOffsets ?? this.reminderOffsets,
      recurrenceRule: recurrenceRule ?? this.recurrenceRule,
    );
  }
}

// ─── Parser Principal ───
class TaskParser {
  // ─── Cores padrão por tipo de chave ───
  static const Color tagColor = Colors.purpleAccent;
  static const Color mentionColor = Color(0xFF3B82F6); // AppColors.taskMarker (Deep Blue)
  static const Color goalColor = Color(0xFF06B6D4); // AppColors.goalTaskMarker (Cyan)

  // ─── Regex patterns (públicos para reuso) ───
  static final tagPattern = RegExp(r'#[a-zA-Z0-9_À-ÿ]+');
  static final mentionPattern = RegExp(r'@[a-z0-9_.]+');
  static final goalPattern = RegExp(r'![a-zA-Z0-9_À-ÿ]+');

  /// Regex combinado para todos os tipos
  static final combinedPattern =
      RegExp(r'(@[a-z0-9_.]+|#[a-zA-Z0-9_À-ÿ]+|![a-zA-Z0-9_À-ÿ]+)');

  /// Retorna a cor para um tipo de chave
  static Color colorForType(ParserKeyType type) {
    switch (type) {
      case ParserKeyType.tag:
        return tagColor;
      case ParserKeyType.mention:
        return mentionColor;
      case ParserKeyType.goal:
        return goalColor;
    }
  }

  /// Retorna o ícone para um tipo de chave
  static IconData iconForType(ParserKeyType type) {
    switch (type) {
      case ParserKeyType.tag:
        return Icons.label_rounded;
      case ParserKeyType.mention:
        return Icons.person;
      case ParserKeyType.goal:
        return Icons.flag_rounded;
    }
  }

  /// Identifica o trigger ativo na posição do cursor.
  /// Usado pelos widgets de popup para saber quando mostrar sugestões.
  static ParserTrigger? detectActiveTrigger(String text, int cursorPos) {
    if (cursorPos <= 0 || cursorPos > text.length) return null;

    int closestIndex = -1;
    ParserTrigger? activeTrigger;

    // Procura o último trigger antes do cursor, priorizando o mais próximo
    for (final trigger in ['@', '#', '!']) {
      final lastIndex = text.lastIndexOf(trigger, cursorPos - 1);
      if (lastIndex == -1) continue;

      if (lastIndex > closestIndex) {
        // Valida: deve estar no início ou precedido por espaço/nova linha
        final isValidStart =
            lastIndex == 0 || [' ', '\n'].contains(text[lastIndex - 1]);
        if (!isValidStart) continue;

        final query = text.substring(lastIndex + 1, cursorPos);
        // Verifica se contém espaço ou quebra de linha (se sim, o trigger foi interrompido/terminado)
        if (query.contains(' ') || query.contains('\n')) continue;

        // CORREÇÃO: Só ativa o trigger após digitar pelo menos 1 caractere após a chave
        if (query.isEmpty) continue;

        closestIndex = lastIndex;
        final type = trigger == '#'
            ? ParserKeyType.tag
            : trigger == '@'
                ? ParserKeyType.mention
                : ParserKeyType.goal;

        activeTrigger = ParserTrigger(
          type: type,
          query: query,
          startIndex: lastIndex,
        );
      }
    }
    return activeTrigger;
  }

  /// Remove caracteres acentuados de uma string
  static String removeAccents(String str) {
    var withDia =
        'ÀÁÂÃÄÅàáâãäåÒÓÔÕÕÖØòóôõöøÈÉÊËèéêëðÇçÐÌÍÎÏìíîïÙÚÛÜùúûüÑñŠšŸÿýŽž';
    var withoutDia =
        'AAAAAAaaaaaaOOOOOOOooooooEEEEeeeeeCcDIIIIiiiiUUUUuuuuNnSsYyyZz';

    for (int i = 0; i < withDia.length; i++) {
      str = str.replaceAll(withDia[i], withoutDia[i]);
    }
    return str;
  }

  /// Normaliza a chave do parser baseado no tipo (ex: goals sáo maiusculos e sem acento)
  static String normalizeParserKey(String input, ParserKeyType type) {
    if (type == ParserKeyType.goal) {
      return removeAccents(input).replaceAll(' ', '').toLowerCase();
    } else {
      return input.replaceAll(' ', '');
    }
  }

  // ─── Método parse principal ───
  static ParsedTask parse(String rawText) {
    String text = rawText;
    final List<String> extractedTags = [];
    final List<String> extractedMentions = [];
    final List<String> extractedGoals = [];

    // 1. Extrair Tags (#) e REMOVER do texto
    final tagMatches = tagPattern.allMatches(text);
    for (final match in tagMatches) {
      extractedTags.add(match.group(0)!.substring(1));
    }
    text = text.replaceAll(tagPattern, '').trim();

    // 2. Extrair Goals (!) e REMOVER do texto
    // EXCLUSIVITY RULE: Prioritize the one that appears first.
    final firstGoalMatch = goalPattern.firstMatch(text);
    final firstMentionMatch = mentionPattern.firstMatch(text);

    bool extractMentions = true;
    bool extractGoals = true;

    if (firstGoalMatch != null && firstMentionMatch != null) {
      if (firstMentionMatch.start < firstGoalMatch.start) {
        extractGoals = false; // Mention wins
      } else {
        extractMentions = false; // Goal wins
      }
    }

    if (extractGoals) {
      final goalMatches = goalPattern.allMatches(text);
      for (final match in goalMatches) {
        extractedGoals.add(match.group(0)!.substring(1));
      }
      text = text.replaceAll(goalPattern, '').trim();
    }

    // 3. Extrair Mentions (@) e MANTER no texto
    if (extractMentions) {
      final mentionMatches = mentionPattern.allMatches(text);
      for (final match in mentionMatches) {
        extractedMentions.add(match.group(0)!.substring(1));
      }
    }

    // 4. Limpa espaços extras
    text = text.replaceAll(RegExp(r'\s+'), ' ').trim();

    return ParsedTask(
      cleanText: text,
      tags: extractedTags,
      sharedWith: extractedMentions,
      goals: extractedGoals,
    );
  }

  // ─── Date parsing ───
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

  static String getMonthPattern() => _monthMap.keys.join('|');

  static final String _monthPatternStr = getMonthPattern();
  static final _ddMmYyPattern =
      RegExp(r'/\s*(\d{1,2})/(\d{1,2})(?:/(\d{2,4}))?', caseSensitive: false);
  static final _fullDatePattern = RegExp(
      r'/\s*dia\s+(\d{1,2})(?:\s+de)?\s+(' +
          _monthPatternStr +
          r')(?:\s+de\s+(\d{4}))?',
      caseSensitive: false);

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

  /// Reconstructs the canonical text representation of a task
  /// used for sync comparison in Journal.
  static String toText(TaskModel task) {
    final sb = StringBuffer(task.text);

    // Append Tags
    for (final tag in task.tags) {
      sb.write(' #$tag');
    }

    // Append Mentions
    for (final mention in task.sharedWith) {
      sb.write(' @$mention');
    }

    // Append Date (if present)
    if (task.dueDate != null) {
      final dt = task.dueDate!;
      final now = DateTime.now();
      // Use shorter format if current year
      if (dt.year == now.year) {
        sb.write(
            ' /${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}');
      } else {
        sb.write(
            ' /${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}');
      }

      // Append time if exists
      if (task.dueDate!.hour != 0 || task.dueDate!.minute != 0) {
        // This parser currently doesn't support time in text (it gets stripped or processed separately?)
        // For now, only date is safe to append without confusing the parser if it doesn't support time.
        // checking regex: _ddMmYyPattern supports /dd/mm/yyyy.
      }
    }

    // Append Goal (if journeyTitle is present)
    // Note: Model has journeyTitle (goal title).
    if (task.journeyTitle != null && task.journeyTitle!.isNotEmpty) {
      sb.write(' !${task.journeyTitle}');
    }

    return sb.toString();
  }
}
