import 'package:cloud_firestore/cloud_firestore.dart';

enum EventType { task, journal }

class CalendarEvent {
  final String id;
  final String title;
  final EventType type;
  final DateTime date;
  final bool isCompleted; // Apenas para tarefas

  CalendarEvent({
    required this.id,
    required this.title,
    required this.type,
    required this.date,
    this.isCompleted = false,
  });

  factory CalendarEvent.fromFirestore(DocumentSnapshot doc, EventType type) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return CalendarEvent(
      id: doc.id,
      // Para o diário, o 'title' pode ser um resumo ou texto fixo
      title: type == EventType.journal
          ? 'Diário de Bordo'
          : (data['title'] ?? 'Tarefa sem título'),
      type: type,
      date: (data['createdAt'] as Timestamp).toDate(),
      isCompleted:
          type == EventType.task ? (data['completed'] ?? false) : false,
    );
  }
}
