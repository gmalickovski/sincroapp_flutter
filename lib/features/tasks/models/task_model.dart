// lib/features/tasks/models/task_model.dart
// import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sincro_app_flutter/models/recurrence_rule.dart';
import 'package:flutter/material.dart';

class TaskModel {
  final String id;
  final String text;
  final bool completed;
  final DateTime createdAt;
  final DateTime? dueDate; // Representa APENAS a data (dia/mês/ano)
  final List<String> tags;
  final List<String> sharedWith;
  final String? journeyId;
  final String? journeyTitle;
  final int? personalDay;

  final RecurrenceType recurrenceType; // Tipo de recorrência
  final int recurrenceInterval; // Intervalo da recorrência (novo)
  final List<int> recurrenceDaysOfWeek; // Dias da semana (1-7)
  final DateTime? recurrenceEndDate; // Data final da recorrência
  final TimeOfDay? reminderTime; // Horário do lembrete (hora/minuto)

  final String? recurrenceId; // ID para agrupar tarefas recorrentes geradas
  final String? goalId; // ID da meta vinculada (Marco)

  // --- INÍCIO DA MUDANÇA (Solicitação 2): Campo 'completedAt' adicionado ---
  final DateTime? completedAt;
  // --- FIM DA MUDANÇA ---
  final DateTime? reminderAt; // Precise reminder timestamp
  final String? taskType; // 'appointment' or 'task'
  final int? durationMinutes; // Duração em minutos


  TaskModel({
    required this.id,
    required this.text,
    this.completed = false,
    required this.createdAt,
    this.dueDate,
    this.tags = const [],
    this.sharedWith = const [],
    this.journeyId,
    this.journeyTitle,
    this.personalDay,
    this.recurrenceType = RecurrenceType.none,
    this.recurrenceInterval = 1,
    this.recurrenceDaysOfWeek = const [],
    this.recurrenceEndDate,
    this.reminderTime,
    this.recurrenceId,
    this.goalId,
    this.completedAt,
    this.reminderAt,
    this.taskType,
    this.durationMinutes,
  });

  bool get isAppointment {
      // Se taskType estiver definido no banco, confia nele.
      if (taskType != null) return taskType == 'appointment';
      
      // Fallback para lógica baseada em tempo (compatibilidade com dados antigos)
      return reminderTime != null || 
             (dueDate != null && (dueDate!.hour != 0 || dueDate!.minute != 0));
  }

  TaskModel copyWith({
    String? id,
    String? text,
    bool? completed,
    DateTime? createdAt,
    Object? dueDate = const _Undefined(),
    List<String>? tags,
    List<String>? sharedWith,
    Object? journeyId = const _Undefined(),
    Object? journeyTitle = const _Undefined(),
    Object? personalDay = const _Undefined(),
    RecurrenceType? recurrenceType,
    int? recurrenceInterval,
    List<int>? recurrenceDaysOfWeek,
    Object? recurrenceEndDate = const _Undefined(),
    Object? reminderTime = const _Undefined(),
    Object? recurrenceId = const _Undefined(),
    Object? goalId = const _Undefined(),
    Object? completedAt = const _Undefined(),
    Object? reminderAt = const _Undefined(),
    Object? taskType = const _Undefined(),
    Object? durationMinutes = const _Undefined(),
  }) {
    return TaskModel(
      id: id ?? this.id,
      text: text ?? this.text,
      completed: completed ?? this.completed,
      createdAt: createdAt ?? this.createdAt,
      dueDate: dueDate is _Undefined ? this.dueDate : dueDate as DateTime?,
      tags: tags ?? this.tags,
      sharedWith: sharedWith ?? this.sharedWith,
      journeyId:
          journeyId is _Undefined ? this.journeyId : journeyId as String?,
      journeyTitle: journeyTitle is _Undefined
          ? this.journeyTitle
          : journeyTitle as String?,
      personalDay:
          personalDay is _Undefined ? this.personalDay : personalDay as int?,
      recurrenceType: recurrenceType ?? this.recurrenceType,
      recurrenceInterval: recurrenceInterval ?? this.recurrenceInterval,
      recurrenceDaysOfWeek: recurrenceDaysOfWeek ?? this.recurrenceDaysOfWeek,
      recurrenceEndDate: recurrenceEndDate is _Undefined
          ? this.recurrenceEndDate
          : recurrenceEndDate as DateTime?,
      reminderTime: reminderTime is _Undefined
          ? this.reminderTime
          : reminderTime as TimeOfDay?,
      recurrenceId: recurrenceId is _Undefined
          ? this.recurrenceId
          : recurrenceId as String?,
      goalId: goalId is _Undefined ? this.goalId : goalId as String?,
      completedAt: completedAt is _Undefined
          ? this.completedAt
          : completedAt as DateTime?,
      reminderAt: reminderAt is _Undefined ? this.reminderAt : reminderAt as DateTime?,
      taskType: taskType is _Undefined ? this.taskType : taskType as String?,
      durationMinutes: durationMinutes is _Undefined ? this.durationMinutes : durationMinutes as int?,
    );
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  factory TaskModel.fromMap(Map<String, dynamic> data) {
    RecurrenceType recType = RecurrenceType.none;
    final rTypeStr = data['recurrence_type'] ?? data['recurrenceType'];
    if (rTypeStr != null && rTypeStr is String) {
      recType = RecurrenceType.values.firstWhere(
        (e) => e.toString() == rTypeStr,
        orElse: () => RecurrenceType.none,
      );
    }
    
    int recInterval = 1;
    final rIntervalVal = data['recurrence_interval'] ?? data['recurrenceInterval'];
    if (rIntervalVal != null) {
      recInterval = rIntervalVal is int ? rIntervalVal : 1;
    }

    List<int> recDays = [];
    final rDaysVal = data['recurrence_days_of_week'] ?? data['recurrenceDaysOfWeek'];
    if (rDaysVal != null && rDaysVal is List) {
      recDays = List<int>.from(rDaysVal);
    }

    TimeOfDay? reminder;
    if (data['reminder_hour'] != null && data['reminder_minute'] != null) {
       reminder = TimeOfDay(hour: data['reminder_hour'], minute: data['reminder_minute']);
    } else if (data['reminderHour'] != null && data['reminderMinute'] != null) {
       reminder = TimeOfDay(hour: data['reminderHour'], minute: data['reminderMinute']);
    } else {
      DateTime? due = _parseDate(data['due_date'] ?? data['dueDate']);
      if (due != null) {
          final localDue = due.toLocal();
          if (localDue.hour != 0 || localDue.minute != 0) {
              reminder = TimeOfDay.fromDateTime(localDue);
          }
      }
    }

    return TaskModel(
      id: data['id'] ?? data['id'] ?? '',
      text: data['text'] ?? '',
      completed: data['completed'] ?? false,
      createdAt: _parseDate(data['created_at'] ?? data['createdAt']) ?? DateTime.now(),
      dueDate: _parseDate(data['due_date'] ?? data['dueDate']),
      tags: List<String>.from(data['tags'] ?? []),
      sharedWith: List<String>.from(data['shared_with'] ?? data['sharedWith'] ?? []),
      journeyId: data['journey_id'] ?? data['journeyId'],
      journeyTitle: data['journey_title'] ?? data['journeyTitle'],
      personalDay: data['personal_day'] ?? data['personalDay'],
      recurrenceType: recType,
      recurrenceInterval: recInterval,
      recurrenceDaysOfWeek: recDays,
      recurrenceEndDate: _parseDate(data['recurrence_end_date'] ?? data['recurrenceEndDate']),
      reminderTime: reminder,
      recurrenceId: data['recurrence_id'] ?? data['recurrenceId'],
      goalId: data['goal_id'] ?? data['goalId'],
      completedAt: _parseDate(data['completed_at'] ?? data['completedAt']),
      reminderAt: _parseDate(data['reminder_at']),
      taskType: data['task_type'] ?? data['taskType'],
      durationMinutes: data['duration_minutes'] ?? data['durationMinutes'],
    );
  }

  Map<String, dynamic> toMap() {
    String? recurrenceTypeString;
    if (recurrenceType != RecurrenceType.none) {
      recurrenceTypeString = recurrenceType.toString();
    }

    return {
      'text': text,
      'completed': completed,
      'created_at': createdAt.toIso8601String(),
      'due_date': dueDate?.toIso8601String(),
      'tags': tags,
      'shared_with': sharedWith,
      'journey_id': journeyId,
      'journey_title': journeyTitle,
      'personal_day': personalDay,
      'recurrence_type': recurrenceTypeString,
      'recurrence_interval': recurrenceInterval,
      'recurrence_days_of_week': recurrenceDaysOfWeek,
      'recurrence_end_date': recurrenceEndDate?.toIso8601String(),
      'recurrence_id': recurrenceId,
      'goal_id': goalId,
      'completed_at': completedAt?.toIso8601String(),
      'reminder_at': reminderAt?.toIso8601String(),
      'task_type': taskType,
      'duration_minutes': durationMinutes, // Escrita do novo campo
    };
  }

  Map<String, dynamic> toJson() => toMap();

  bool get isOverdue {
    if (completed || dueDate == null) return false;
    final now = DateTime.now();
    final localDue = dueDate!.toLocal();

    // Se tiver horário definido (não for meia-noite exata) ou tiver reminderTime, considera horário exato
    if ((localDue.hour != 0 || localDue.minute != 0) || reminderTime != null) {
      if (durationMinutes != null) {
        // Se tiver duração, o "late" é só depois que ACABA
        final end = localDue.add(Duration(minutes: durationMinutes!));
        return end.isBefore(now);
      }
      return localDue.isBefore(now);
    }
    
    // Senão, compara apenas data (tarefa de dia inteiro)
    final today = DateTime(now.year, now.month, now.day);
    final localDueDateOnly = DateTime(localDue.year, localDue.month, localDue.day);
    
    return localDueDateOnly.isBefore(today);
  }
}

// Classe auxiliar para o copyWith permitir definir campos como null
class _Undefined {
  const _Undefined();
}

