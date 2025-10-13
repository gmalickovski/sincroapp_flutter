import 'package:cloud_firestore/cloud_firestore.dart';

class TaskModel {
  final String id;
  final String text;
  final bool completed;
  final DateTime createdAt;
  final DateTime? dueDate; // Mantido como opcional (nullable)
  final List<String> tags;
  final String? journeyId; // Mantido
  final int? personalDay; // Adicionado como opcional (nullable)

  TaskModel({
    required this.id,
    required this.text,
    required this.completed,
    required this.createdAt,
    this.dueDate,
    this.tags = const [],
    this.journeyId,
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
      personalDay: data['personalDay'], // Lê o novo campo
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
      'personalDay': personalDay, // Salva o novo campo
    };
  }
}
