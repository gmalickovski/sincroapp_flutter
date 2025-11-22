// lib/features/calendar/models/event_model.dart

// 1. Enum atualizado para incluir tarefas de metas/jornadas.
enum EventType {
  task,
  goalTask,
  journal,
}

// 2. Modelo de dados simplificado para a UI do calendário.
// Ele não contém mais lógica de conversão do Firestore.
class CalendarEvent {
  final String title;
  final EventType type;
  final DateTime date;
  final bool isCompleted;

  CalendarEvent({
    required this.title,
    required this.type,
    required this.date,
    this.isCompleted = false,
  });

  @override
  String toString() => title;
}
