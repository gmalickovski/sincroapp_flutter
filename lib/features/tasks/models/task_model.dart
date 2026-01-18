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
  
  final List<String> sharedWith; // NOVO: Usernames ou IDs com quem foi compartilhado

  TaskModel({
    required this.id,
    required this.text,
    this.completed = false,
    required this.createdAt,
    this.dueDate,
    this.tags = const [],
    this.sharedWith = const [], // NOVO
    this.journeyId,
    this.journeyTitle,
    this.personalDay,
    this.recurrenceType = RecurrenceType.none,
    this.recurrenceInterval = 1, // Default 1
    this.recurrenceDaysOfWeek = const [],
    this.recurrenceEndDate,
    this.reminderTime,
    this.recurrenceId,
    this.goalId,
    // --- INÍCIO DA MUDANÇA (Solicitação 2) ---
    this.completedAt,
    // --- FIM DA MUDANÇA ---
    this.reminderAt,
  });

  // copyWith atualizado para incluir os novos campos
  TaskModel copyWith({
    String? id,
    String? text,
    bool? completed,
    DateTime? createdAt,
    Object? dueDate = const _Undefined(),
    List<String>? tags,
    List<String>? sharedWith, // NOVO
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
    // --- INÍCIO DA MUDANÇA (Solicitação 2) ---
    Object? completedAt = const _Undefined(),
    // --- FIM DA MUDANÇA ---
    Object? reminderAt = const _Undefined(),
  }) {
    return TaskModel(
      id: id ?? this.id,
      text: text ?? this.text,
      completed: completed ?? this.completed,
      createdAt: createdAt ?? this.createdAt,
      dueDate: dueDate is _Undefined ? this.dueDate : dueDate as DateTime?,
      tags: tags ?? this.tags,
      sharedWith: sharedWith ?? this.sharedWith, // NOVO
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
      // --- INÍCIO DA MUDANÇA (Solicitação 2) ---
      completedAt: completedAt is _Undefined
          ? this.completedAt
          : completedAt as DateTime?,
      // --- FIM DA MUDANÇA ---
      reminderAt: reminderAt is _Undefined ? this.reminderAt : reminderAt as DateTime?,
    );
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is String) return DateTime.tryParse(value);
    // Fallback if needed
    return null;
  }

  // fromMap atualizado para ler os novos campos
  factory TaskModel.fromMap(Map<String, dynamic> data) {
    RecurrenceType recType = RecurrenceType.none;
    if (data['recurrenceType'] != null && data['recurrenceType'] is String) {
      recType = RecurrenceType.values.firstWhere(
        (e) => e.toString() == data['recurrenceType'],
        orElse: () => RecurrenceType.none,
      );
    }
    
    int recInterval = 1;
    if (data['recurrenceInterval'] != null) {
      recInterval = data['recurrenceInterval'] is int ? data['recurrenceInterval'] : 1;
    }

    List<int> recDays = [];
    if (data['recurrenceDaysOfWeek'] != null &&
        data['recurrenceDaysOfWeek'] is List) {
      recDays = List<int>.from(data['recurrenceDaysOfWeek']);
    }

    // Modificado: Tentar obter o tempo do próprio dueDate (se contiver hora)
    TimeOfDay? reminder;
    // Se tivermos as colunas antigas, usamos (backward compatibility)
    if (data['reminderHour'] != null &&
        data['reminderMinute'] != null &&
        data['reminderHour'] is int &&
        data['reminderMinute'] is int) {
      try {
        reminder = TimeOfDay(
            hour: data['reminderHour'], minute: data['reminderMinute']);
      } catch (e) {
        reminder = null;
      }
    } else {
      // Se não, tentamos extrair do dueDate (parse string if needed)
      DateTime? due = _parseDate(data['dueDate']);
      if (due != null) {
          final localDue = due.toLocal();
          if (localDue.hour != 0 || localDue.minute != 0) {
              reminder = TimeOfDay.fromDateTime(localDue);
          }
      }
    }

    return TaskModel(
      id: data['id'] ?? data['id'] ?? '', // Assume ID is generic or passed
      text: data['text'] ?? '',
      completed: data['completed'] ?? false,
      createdAt: _parseDate(data['createdAt']) ?? DateTime.now(),
      dueDate: _parseDate(data['dueDate']),
      tags: List<String>.from(data['tags'] ?? []),
      sharedWith: List<String>.from(data['sharedWith'] ?? []), // NOVO
      journeyId: data['journeyId'],
      journeyTitle: data['journeyTitle'],
      personalDay: data['personalDay'],
      recurrenceType: recType,
      recurrenceInterval: recInterval,
      recurrenceDaysOfWeek: recDays,
      recurrenceEndDate: _parseDate(data['recurrenceEndDate']),
      reminderTime: reminder,
      recurrenceId: data['recurrenceId'],
      goalId: data['goalId'],
      // --- INÍCIO DA MUDANÇA (Solicitação 2) ---
      completedAt: _parseDate(data['completedAt']),
      // --- FIM DA MUDANÇA ---
      reminderAt: _parseDate(data['reminder_at']),
    );
  }

  // toMap atualizado para salvar os novos campos
  Map<String, dynamic> toMap() {
    String? recurrenceTypeString;
    if (recurrenceType != RecurrenceType.none) {
      recurrenceTypeString = recurrenceType.toString();
    }

    // REMOVIDO: reminderHour e reminderMinute pois não existem na schema
    // Em vez disso, salvamos o dueDate COM o horário, se existir.

    return {
      'text': text,
      'completed': completed,
      'createdAt': createdAt.toIso8601String(),
      // Salva o dueDate completo (com hora)
      'dueDate': dueDate?.toIso8601String(),
      'tags': tags,
      'sharedWith': sharedWith, // NOVO
      'journeyId': journeyId,
      'journeyTitle': journeyTitle,
      'personalDay': personalDay,
      'recurrenceType': recurrenceTypeString,
      'recurrenceInterval': recurrenceInterval,
      'recurrenceDaysOfWeek': recurrenceDaysOfWeek,
      'recurrenceEndDate': recurrenceEndDate?.toIso8601String(),
      'recurrenceId': recurrenceId,
      'goalId': goalId,
      // --- INÍCIO DA MUDANÇA (Solicitação 2) ---
      'completedAt': completedAt?.toIso8601String(),
      // --- FIM DA MUDANÇA ---
      'reminder_at': reminderAt?.toIso8601String(),
    };
  }

  Map<String, dynamic> toJson() => toMap();
  // --- INÍCIO DA MUDANÇA (Solicitação 2) ---
  bool get isOverdue {
    if (completed || dueDate == null) return false;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    // dueDate é armazenado como UTC 00:00. Precisamos converter para local para comparar corretamente com "hoje" local?
    // Ou assumimos que dueDate é "data pura" independente de fuso?
    // O app parece converter para UTC ao salvar: DateTime.utc(dateLocal.year, ...).
    // Se dueDate é 2023-12-01 00:00 UTC.
    // E hoje é 2023-12-02 (Brasil -3).
    // 2023-12-01 UTC é antes de 2023-12-02 Local?
    // Melhor comparar dueDate (convertido para local) com today.
    
    final localDueDate = dueDate!.toLocal();
    final localDueDateOnly = DateTime(localDueDate.year, localDueDate.month, localDueDate.day);
    
    return localDueDateOnly.isBefore(today);
  }
  // --- FIM DA MUDANÇA ---
}

// Classe auxiliar para o copyWith permitir definir campos como null
class _Undefined {
  const _Undefined();
}
