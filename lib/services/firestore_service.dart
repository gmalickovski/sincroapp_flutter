// lib/services/firestore_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sincro_app_flutter/models/user_model.dart';
import 'package:sincro_app_flutter/features/tasks/models/task_model.dart';
import 'package:sincro_app_flutter/features/journal/models/journal_entry_model.dart';
// ADIÇÃO: Importa o novo modelo de dados para as Metas.
import 'package:sincro_app_flutter/features/goals/models/goal_model.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // --- MÉTODOS DE USUÁRIO ---
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

  // --- MÉTODOS DE TAREFAS (Foco do Dia / Calendário / Marcos de Metas) ---
  Future<List<TaskModel>> getTasksForCalendar(
      String userId, DateTime month) async {
    final startOfMonth = DateTime.utc(month.year, month.month, 1);
    final endOfMonth = DateTime.utc(month.year, month.month + 1, 1)
        .subtract(const Duration(seconds: 1));
    final tasksRef = _db.collection('users').doc(userId).collection('tasks');
    final queryDueDate = tasksRef
        .where('dueDate',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth))
        .where('dueDate', isLessThanOrEqualTo: Timestamp.fromDate(endOfMonth));
    final queryCreatedAt = tasksRef
        .where('dueDate', isEqualTo: null)
        .where('createdAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth))
        .where('createdAt',
            isLessThanOrEqualTo: Timestamp.fromDate(endOfMonth));
    try {
      final results = await Future.wait([
        queryDueDate.get(),
        queryCreatedAt.get(),
      ]);
      final dueDateTasks =
          results[0].docs.map((doc) => TaskModel.fromFirestore(doc));
      final createdAtTasks =
          results[1].docs.map((doc) => TaskModel.fromFirestore(doc));
      final allTasks = <String, TaskModel>{};
      for (var task in dueDateTasks) {
        allTasks[task.id] = task;
      }
      for (var task in createdAtTasks) {
        allTasks[task.id] = task;
      }
      return allTasks.values.toList();
    } catch (e) {
      print("Erro ao buscar tarefas para o calendário: $e");
      return [];
    }
  }

  Future<List<TaskModel>> getTasksForToday(String userId) async {
    final todayStart =
        DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    final todayEnd = todayStart.add(const Duration(days: 1));
    try {
      final querySnapshot = await _db
          .collection('users')
          .doc(userId)
          .collection('tasks')
          .where('dueDate',
              isGreaterThanOrEqualTo: Timestamp.fromDate(todayStart))
          .where('dueDate', isLessThan: Timestamp.fromDate(todayEnd))
          .get();
      return querySnapshot.docs
          .map((doc) => TaskModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      print("Erro ao buscar tarefas de hoje: $e");
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

  Future<void> updateTask(String userId, TaskModel task) async {
    await _db
        .collection('users')
        .doc(userId)
        .collection('tasks')
        .doc(task.id)
        .update(task.toFirestore());
  }

  Future<void> updateTaskCompletion(String userId, String taskId,
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

  // --- MÉTODOS PARA O DIÁRIO DE BORDO ---
  Stream<List<JournalEntry>> getJournalEntriesStream(
    String userId, {
    DateTime? date,
    int? mood,
    int? vibration,
  }) {
    Query query =
        _db.collection('users').doc(userId).collection('journalEntries');
    if (date != null) {
      final startOfDay =
          Timestamp.fromDate(DateTime(date.year, date.month, date.day));
      final endOfDay = Timestamp.fromDate(
          DateTime(date.year, date.month, date.day, 23, 59, 59));
      query = query
          .where('createdAt', isGreaterThanOrEqualTo: startOfDay)
          .where('createdAt', isLessThanOrEqualTo: endOfDay);
    }
    if (mood != null) {
      query = query.where('mood', isEqualTo: mood);
    }
    if (vibration != null) {
      query = query.where('personalDay', isEqualTo: vibration);
    }
    query = query.orderBy('createdAt', descending: true);
    return query.snapshots().map((snapshot) {
      if (snapshot.docs.isEmpty) {
        return [];
      }
      return snapshot.docs
          .map((doc) => JournalEntry.fromFirestore(doc))
          .toList();
    });
  }

  Future<void> addJournalEntry(String userId, Map<String, dynamic> data) async {
    await _db
        .collection('users')
        .doc(userId)
        .collection('journalEntries')
        .add(data);
  }

  Future<void> updateJournalEntry(
      String userId, String entryId, Map<String, dynamic> data) async {
    await _db
        .collection('users')
        .doc(userId)
        .collection('journalEntries')
        .doc(entryId)
        .update(data);
  }

  Future<void> deleteJournalEntry(String userId, String entryId) async {
    await _db
        .collection('users')
        .doc(userId)
        .collection('journalEntries')
        .doc(entryId)
        .delete();
  }

  // =======================================================================
  // *** INÍCIO DOS NOVOS MÉTODOS PARA AS METAS (JORNADAS) ***
  // =======================================================================

  /// Retorna um Stream com a lista de metas do usuário.
  Stream<List<Goal>> getGoalsStream(String userId) {
    return _db
        .collection('users')
        .doc(userId)
        .collection('goals')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Goal.fromFirestore(doc)).toList());
  }

  /// Adiciona uma nova meta.
  Future<DocumentReference> addGoal(
      String userId, Map<String, dynamic> data) async {
    return await _db
        .collection('users')
        .doc(userId)
        .collection('goals')
        .add(data);
  }

  /// Atualiza uma meta existente.
  Future<void> updateGoal(
      String userId, String goalId, Map<String, dynamic> data) async {
    await _db
        .collection('users')
        .doc(userId)
        .collection('goals')
        .doc(goalId)
        .update(data);
  }

  /// Deleta uma meta e todas as suas tarefas (marcos) associadas.
  Future<void> deleteGoal(String userId, String goalId) async {
    final WriteBatch batch = _db.batch();

    // 1. Deleta a meta
    final goalRef =
        _db.collection('users').doc(userId).collection('goals').doc(goalId);
    batch.delete(goalRef);

    // 2. Encontra e deleta todas as tarefas associadas
    // ATENÇÃO: Verifique se o campo no seu TaskModel é 'journeyId' ou 'goalId'
    final tasksQuery = _db
        .collection('users')
        .doc(userId)
        .collection('tasks')
        .where('journeyId', isEqualTo: goalId);

    final tasksSnapshot = await tasksQuery.get();
    for (final doc in tasksSnapshot.docs) {
      batch.delete(doc.reference);
    }

    // 3. Executa a operação em lote
    await batch.commit();
  }
}
