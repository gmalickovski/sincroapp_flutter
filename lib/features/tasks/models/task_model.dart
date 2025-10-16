// lib/features/tasks/models/task_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class TaskModel {
  final String id;
  final String text;
  final bool completed;
  final DateTime createdAt;
  final DateTime? dueDate;
  final List<String> tags;
  final String? journeyId;
  // NOVO: Garante que a propriedade journeyTitle exista.
  final String? journeyTitle;
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

  // Adiciona o método 'copyWith' para facilitar a edição
  TaskModel copyWith({
    String? id,
    String? text,
    bool? completed,
    DateTime? createdAt,
    DateTime? dueDate,
    List<String>? tags,
    String? journeyId,
    String? journeyTitle,
    int? personalDay,
  }) {
    return TaskModel(
      id: id ?? this.id,
      text: text ?? this.text,
      completed: completed ?? this.completed,
      createdAt: createdAt ?? this.createdAt,
      dueDate: dueDate ?? this.dueDate,
      tags: tags ?? this.tags,
      journeyId: journeyId ?? this.journeyId,
      journeyTitle: journeyTitle ?? this.journeyTitle,
      personalDay: personalDay ?? this.personalDay,
    );
  }

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
      journeyTitle: data['journeyTitle'], // Mapeia o campo do Firestore
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
      'journeyTitle': journeyTitle, // Adiciona o campo ao Firestore
      'personalDay': personalDay,
    };
  }
}
