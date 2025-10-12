import 'package:cloud_firestore/cloud_firestore.dart';

class TaskModel {
  final String id;
  final String text;
  final bool completed;
  final DateTime createdAt;
  final DateTime? dueDate; // Data de vencimento (opcional)
  final List<String> tags; // Lista de tags (ex: #pessoal)
  final String? journeyId; // ID da jornada/meta associada (ex: @projetoX)

  TaskModel({
    required this.id,
    required this.text,
    required this.completed,
    required this.createdAt,
    this.dueDate,
    this.tags = const [],
    this.journeyId,
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
    };
  }
}
