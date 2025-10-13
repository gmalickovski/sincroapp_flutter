import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sincro_app_flutter/models/user_model.dart';
import 'package:sincro_app_flutter/features/calendar/models/event_model.dart';
import 'package:sincro_app_flutter/features/tasks/models/task_model.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

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

  Stream<List<TaskModel>> getTasksStream(String userId,
      {bool todayOnly = true}) {
    Query query = _db.collection('users').doc(userId).collection('tasks');

    if (todayOnly) {
      final todayStart = DateTime(
          DateTime.now().year, DateTime.now().month, DateTime.now().day);
      final todayEnd = todayStart.add(const Duration(days: 1));
      query = query
          .where('dueDate',
              isGreaterThanOrEqualTo: Timestamp.fromDate(todayStart))
          .where('dueDate', isLessThan: Timestamp.fromDate(todayEnd));
    }

    // ATUALIZAÇÃO: A ordenação foi alterada de 'createdAt' para 'dueDate'.
    // Isso garante que a consulta funcione corretamente sem a necessidade de um
    // índice composto manual no Firestore e ordena as tarefas de forma lógica.
    return query
        .orderBy('dueDate', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => TaskModel.fromFirestore(doc)).toList();
    });
  }

  Future<void> addTask(String userId, TaskModel task) async {
    await _db
        .collection('users')
        .doc(userId)
        .collection('tasks')
        .add(task.toFirestore());
  }

  Future<void> updateTask(String userId, String taskId,
      {required bool completed}) async {
    await _db
        .collection('users')
        .doc(userId)
        .collection('tasks')
        .doc(taskId)
        .update({'completed': completed});
  }

  Future<void> deleteTask(String userId, String taskId) async {
    await _db
        .collection('users')
        .doc(userId)
        .collection('tasks')
        .doc(taskId)
        .delete();
  }
}
