import 'package:flutter/material.dart';
import 'package:sincro_app_flutter/models/recurrence_rule.dart';

// Classe de retorno do modal, incluindo data/hora e regra de recorrência
class DatePickerResult {
  final DateTime? dateTime; // Nullable to represent a 'Clear' action
  final RecurrenceRule recurrenceRule;
  final TimeOfDay? reminderTime;
  final List<int>? reminderOffsets; // Array de offsets em minutos
  final bool hasTime;
  final int? durationMinutes;

  DatePickerResult(
    this.dateTime,
    this.recurrenceRule, {
    this.reminderTime,
    this.reminderOffsets,
    this.hasTime = false,
    this.durationMinutes,
  });
}
