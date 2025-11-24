// lib/features/tasks/models/task_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sincro_app_flutter/common/widgets/custom_recurrence_picker_modal.dart';
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
  final List<int> recurrenceDaysOfWeek; // Dias da semana (1-7)
  final DateTime? recurrenceEndDate; // Data final da recorrência
  final TimeOfDay? reminderTime; // Horário do lembrete (hora/minuto)

  final String? recurrenceId; // ID para agrupar tarefas recorrentes geradas
  final String? goalId; // ID da meta vinculada (Marco)

  // --- INÍCIO DA MUDANÇA (Solicitação 2): Campo 'completedAt' adicionado ---
  final DateTime? completedAt;
  // --- FIM DA MUDANÇA ---

  TaskModel({
    required this.id,
    required this.text,
    this.completed = false,
    required this.createdAt,
    this.dueDate,
    this.tags = const [],
    this.journeyId,
    this.journeyTitle,
    this.personalDay,
    this.recurrenceType = RecurrenceType.none,
    this.recurrenceDaysOfWeek = const [],
    this.recurrenceEndDate,
    this.reminderTime,
    this.recurrenceId,
    this.goalId,
    // --- INÍCIO DA MUDANÇA (Solicitação 2) ---
    this.completedAt,
    // --- FIM DA MUDANÇA ---
  });

  // copyWith atualizado para incluir os novos campos
  TaskModel copyWith({
    String? id,
    String? text,
    bool? completed,
    DateTime? createdAt,
    Object? dueDate = const _Undefined(),
    List<String>? tags,
    Object? journeyId = const _Undefined(),
    Object? journeyTitle = const _Undefined(),
    Object? personalDay = const _Undefined(),
    RecurrenceType? recurrenceType,
    List<int>? recurrenceDaysOfWeek,
    Object? recurrenceEndDate = const _Undefined(),
    Object? reminderTime = const _Undefined(),
    Object? recurrenceId = const _Undefined(),
    Object? goalId = const _Undefined(),
    // --- INÍCIO DA MUDANÇA (Solicitação 2) ---
    Object? completedAt = const _Undefined(),
    // --- FIM DA MUDANÇA ---
  }) {
    return TaskModel(
      id: id ?? this.id,
      text: text ?? this.text,
      completed: completed ?? this.completed,
      createdAt: createdAt ?? this.createdAt,
      dueDate: dueDate is _Undefined ? this.dueDate : dueDate as DateTime?,
      tags: tags ?? this.tags,
      journeyId:
          journeyId is _Undefined ? this.journeyId : journeyId as String?,
      journeyTitle: journeyTitle is _Undefined
          ? this.journeyTitle
          : journeyTitle as String?,
      personalDay:
          personalDay is _Undefined ? this.personalDay : personalDay as int?,
      recurrenceType: recurrenceType ?? this.recurrenceType,
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
    );
  }

  // fromFirestore atualizado para ler os novos campos
  factory TaskModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

    RecurrenceType recType = RecurrenceType.none;
    if (data['recurrenceType'] != null && data['recurrenceType'] is String) {
      recType = RecurrenceType.values.firstWhere(
        (e) => e.toString() == data['recurrenceType'],
        orElse: () => RecurrenceType.none,
      );
    }

    List<int> recDays = [];
    if (data['recurrenceDaysOfWeek'] != null &&
        data['recurrenceDaysOfWeek'] is List) {
      recDays = List<int>.from(data['recurrenceDaysOfWeek']);
    }

    TimeOfDay? reminder;
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
    }

    return TaskModel(
      id: doc.id,
      text: data['text'] ?? '',
      completed: data['completed'] ?? false,
      createdAt: (data['createdAt'] as Timestamp? ?? Timestamp.now()).toDate(),
      dueDate: (data['dueDate'] as Timestamp?)?.toDate(),
      tags: List<String>.from(data['tags'] ?? []),
      journeyId: data['journeyId'],
      journeyTitle: data['journeyTitle'],
      personalDay: data['personalDay'],
      recurrenceType: recType,
      recurrenceDaysOfWeek: recDays,
      recurrenceEndDate: (data['recurrenceEndDate'] as Timestamp?)?.toDate(),
      reminderTime: reminder,
      recurrenceId: data['recurrenceId'],
      goalId: data['goalId'],
      // --- INÍCIO DA MUDANÇA (Solicitação 2) ---
      completedAt: (data['completedAt'] as Timestamp?)?.toDate(),
      // --- FIM DA MUDANÇA ---
    );
  }

  // toFirestore atualizado para salvar os novos campos
  Map<String, dynamic> toFirestore() {
    String? recurrenceTypeString;
    if (recurrenceType != RecurrenceType.none) {
      recurrenceTypeString = recurrenceType.toString();
    }

    int? reminderHour;
    int? reminderMinute;
    if (reminderTime != null) {
      reminderHour = reminderTime!.hour;
      reminderMinute = reminderTime!.minute;
    }

    DateTime? dateOnlyDueDate;
    if (dueDate != null) {
      dateOnlyDueDate = DateTime(dueDate!.year, dueDate!.month, dueDate!.day);
    }

    return {
      'text': text,
      'completed': completed,
      'createdAt': Timestamp.fromDate(createdAt),
      'dueDate':
          dateOnlyDueDate != null ? Timestamp.fromDate(dateOnlyDueDate) : null,
      'tags': tags,
      'journeyId': journeyId,
      'journeyTitle': journeyTitle,
      'personalDay': personalDay,
      'recurrenceType': recurrenceTypeString,
      'recurrenceDaysOfWeek': recurrenceDaysOfWeek,
      'recurrenceEndDate': recurrenceEndDate != null
          ? Timestamp.fromDate(recurrenceEndDate!)
          : null,
      'reminderHour': reminderHour,
      'reminderMinute': reminderMinute,
      'recurrenceId': recurrenceId,
      'goalId': goalId,
      // --- INÍCIO DA MUDANÇA (Solicitação 2) ---
      'completedAt':
          completedAt != null ? Timestamp.fromDate(completedAt!) : null,
      // --- FIM DA MUDANÇA ---
    };
  }
}

// Classe auxiliar para o copyWith permitir definir campos como null
class _Undefined {
  const _Undefined();
}
