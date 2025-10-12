import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sincro_app_flutter/models/user_model.dart';
import 'package:sincro_app_flutter/features/calendar/models/event_model.dart';

// --- NOVA IMPORTAÇÃO ---
import 'package:sincro_app_flutter/features/tasks/models/task_model.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // --- SEU CÓDIGO ORIGINAL (INTACTO) ---
  Future<void> saveUserData(UserModel user) async {
    try {
      await _db.collection('users').doc(user.uid).set(user.toFirestore());
    } catch (e) {
      print("Erro ao salvar dados do usuário: $e");
      rethrow;
    }
  }

  Future<UserModel?> getUserData(String uid) async {
    try {
      DocumentSnapshot doc = await _db.collection('users').doc(uid).get();
      if (doc.exists) {
        return UserModel.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      print("Erro ao buscar dados do usuário: $e");
      return null;
    }
  }

  Future<List<CalendarEvent>> getEventsForMonth(
      String userId, DateTime month) async {
    final startOfMonth = DateTime.utc(month.year, month.month, 1);
    final endOfMonth = DateTime.utc(month.year, month.month + 1, 0, 23, 59, 59);

    final tasksQuery = _db
        .collection('users')
        .doc(userId)
        .collection('tasks')
        .where('createdAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth))
        .where('createdAt',
            isLessThanOrEqualTo: Timestamp.fromDate(endOfMonth));

    final journalQuery = _db
        .collection('users')
        .doc(userId)
        .collection('journalEntries')
        .where('createdAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth))
        .where('createdAt',
            isLessThanOrEqualTo: Timestamp.fromDate(endOfMonth));

    try {
      final tasksSnapshot = await tasksQuery.get();
      final journalSnapshot = await journalQuery.get();

      final tasks = tasksSnapshot.docs
          .map((doc) => CalendarEvent.fromFirestore(doc, EventType.task))
          .toList();

      final journalEntries = journalSnapshot.docs
          .map((doc) => CalendarEvent.fromFirestore(doc, EventType.journal))
          .toList();

      return [...tasks, ...journalEntries];
    } catch (e) {
      print("Erro ao buscar eventos: $e");
      return [];
    }
  }

  // --- MÉTODOS NOVOS ADICIONADOS PARA A FUNCIONALIDADE DE TAREFAS ---

  // Retorna um Stream (ouvinte em tempo real) de tarefas, com filtro opcional.
  Stream<List<TaskModel>> getTasksStream(String userId,
      {bool todayOnly = true}) {
    Query query = _db.collection('users').doc(userId).collection('tasks');

    // Se o filtro 'todayOnly' estiver ativo, aplica a condição na data de vencimento
    if (todayOnly) {
      final todayStart = DateTime(
          DateTime.now().year, DateTime.now().month, DateTime.now().day);
      final todayEnd = todayStart.add(const Duration(days: 1));
      query = query
          .where('dueDate',
              isGreaterThanOrEqualTo: Timestamp.fromDate(todayStart))
          .where('dueDate', isLessThan: Timestamp.fromDate(todayEnd));
    }

    // Ordena os resultados pela data de criação
    return query
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => TaskModel.fromFirestore(doc)).toList();
    });
  }

  // Adiciona uma nova tarefa à base de dados
  Future<void> addTask(String userId, TaskModel task) async {
    await _db
        .collection('users')
        .doc(userId)
        .collection('tasks')
        .add(task.toFirestore());
  }

  // Atualiza o estado 'completed' de uma tarefa
  Future<void> updateTask(String userId, String taskId,
      {required bool completed}) async {
    await _db
        .collection('users')
        .doc(userId)
        .collection('tasks')
        .doc(taskId)
        .update({'completed': completed});
  }

  // Apaga uma tarefa da base de dados
  Future<void> deleteTask(String userId, String taskId) async {
    await _db
        .collection('users')
        .doc(userId)
        .collection('tasks')
        .doc(taskId)
        .delete();
  }
}
