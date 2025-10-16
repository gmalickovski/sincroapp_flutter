// lib/features/tasks/models/task_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class TaskModel {
  final String id;
  final String text;
  final bool completed; // CORRIGIDO: Revertido para 'completed'
  final DateTime createdAt;
  final DateTime? dueDate;
  final List<String> tags;
  final String? journeyId;
  final String? journeyTitle; // Título da Jornada para exibição
  final int? personalDay;

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
  });

  factory TaskModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return TaskModel(
      id: doc.id,
      text: data['text'] ?? '',
      completed: data['completed'] ?? false,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      dueDate: data['dueDate'] != null
          ? (data['dueDate'] as Timestamp).toDate()
          : null,
      tags: List<String>.from(data['tags'] ?? []),
      journeyId: data['journeyId'],
      journeyTitle: data['journeyTitle'],
      personalDay: data['personalDay'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'text': text,
      'completed': completed,
      'createdAt': createdAt,
      'dueDate': dueDate,
      'tags': tags,
      'journeyId': journeyId,
      'journeyTitle': journeyTitle,
      'personalDay': personalDay,
    };
  }
}
