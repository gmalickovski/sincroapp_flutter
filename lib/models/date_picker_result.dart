import 'package:flutter/material.dart';
import 'package:sincro_app_flutter/models/recurrence_rule.dart';

// Classe de retorno do modal, incluindo data/hora e regra de recorrência
class DatePickerResult {
  final DateTime dateTime;
  final RecurrenceRule recurrenceRule;
  final TimeOfDay? reminderTime;
  final Duration? reminderOffset; // Novo campo
  final bool hasTime;
  
  DatePickerResult(
    this.dateTime, 
    this.recurrenceRule, 
    {
      this.reminderTime, 
      this.reminderOffset,
      this.hasTime = false
    }
  );
}
