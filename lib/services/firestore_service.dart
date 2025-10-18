// lib/services/firestore_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sincro_app_flutter/common/utils/string_sanitizer.dart';
import 'package:sincro_app_flutter/models/user_model.dart';
import 'package:sincro_app_flutter/features/tasks/models/task_model.dart';
import 'package:sincro_app_flutter/features/journal/models/journal_entry_model.dart';
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

  Future<void> updateUserData(String uid, Map<String, dynamic> data) async {
    try {
      await _db.collection('users').doc(uid).update(data);
    } catch (e) {
      print("Erro ao atualizar dados do usuário: $e");
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

  // --- MÉTODOS DE TAREFAS ---

  // *** NOVA FUNÇÃO ADICIONADA AQUI ***
  /// Busca as tarefas de um usuário com data para o dia de hoje,
  /// seguindo a estrutura de sub-coleção.
  Future<List<TaskModel>> getTasksForToday(String userId) async {
    try {
      final now = DateTime.now();
      final startOfToday = DateTime(now.year, now.month, now.day);
      final endOfToday = startOfToday.add(const Duration(days: 1));

      final snapshot = await _db
          .collection('users')
          .doc(userId)
          .collection('tasks')
          .where('dueDate', isGreaterThanOrEqualTo: startOfToday)
          .where('dueDate', isLessThan: endOfToday)
          .get();

      return snapshot.docs.map((doc) => TaskModel.fromFirestore(doc)).toList();
    } catch (e) {
      print("Erro ao buscar tarefas de hoje: $e");
      return [];
    }
  }

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

  Stream<List<TaskModel>> getTasksStream(String userId) {
    return _db
        .collection('users')
        .doc(userId)
        .collection('tasks')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => TaskModel.fromFirestore(doc)).toList();
    });
  }

  Stream<List<TaskModel>> getTasksForGoalStream(String userId, String goalId) {
    return _db
        .collection('users')
        .doc(userId)
        .collection('tasks')
        .where('journeyId', isEqualTo: goalId)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => TaskModel.fromFirestore(doc)).toList());
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

  Future<List<JournalEntry>> getJournalEntriesForMonth(
      String userId, DateTime month) async {
    try {
      final startOfMonth = DateTime(month.year, month.month, 1);
      final endOfMonth = DateTime(month.year, month.month + 1, 0, 23, 59, 59);

      final querySnapshot = await _db
          .collection('users')
          .doc(userId)
          .collection('journalEntries')
          .where('createdAt',
              isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth))
          .where('createdAt',
              isLessThanOrEqualTo: Timestamp.fromDate(endOfMonth))
          .get();

      return querySnapshot.docs
          .map((doc) => JournalEntry.fromFirestore(doc))
          .toList();
    } catch (e) {
      print("Erro ao buscar anotações do diário para o mês: $e");
      return [];
    }
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
  // *** MÉTODOS PARA AS METAS (JORNADAS) ***
  // =======================================================================

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

  Future<List<Goal>> getActiveGoals(String userId) async {
    try {
      final querySnapshot = await _db
          .collection('users')
          .doc(userId)
          .collection('goals')
          .orderBy('createdAt', descending: true)
          .get();
      return querySnapshot.docs.map((doc) => Goal.fromFirestore(doc)).toList();
    } catch (e) {
      print("Erro ao buscar as jornadas ativas: $e");
      return [];
    }
  }

  Future<DocumentReference> addGoal(
      String userId, Map<String, dynamic> data) async {
    return await _db
        .collection('users')
        .doc(userId)
        .collection('goals')
        .add(data);
  }

  Future<void> updateGoal(
      String userId, String goalId, Map<String, dynamic> data) async {
    await _db
        .collection('users')
        .doc(userId)
        .collection('goals')
        .doc(goalId)
        .update(data);
  }

  Future<void> updateGoalProgress(String userId, String goalId) async {
    final tasksSnapshot = await _db
        .collection('users')
        .doc(userId)
        .collection('tasks')
        .where('journeyId', isEqualTo: goalId)
        .get();

    if (tasksSnapshot.docs.isEmpty) {
      await updateGoal(userId, goalId, {'progress': 0});
      return;
    }

    final totalTasks = tasksSnapshot.docs.length;
    final completedTasks = tasksSnapshot.docs
        .where((doc) => doc.data()['completed'] == true)
        .length;

    final progress = (completedTasks / totalTasks * 100).round();
    await updateGoal(userId, goalId, {'progress': progress});
  }

  Future<void> deleteGoal(String userId, String goalId) async {
    final WriteBatch batch = _db.batch();
    final goalRef =
        _db.collection('users').doc(userId).collection('goals').doc(goalId);
    batch.delete(goalRef);
    final tasksQuery = _db
        .collection('users')
        .doc(userId)
        .collection('tasks')
        .where('journeyId', isEqualTo: goalId);
    final tasksSnapshot = await tasksQuery.get();
    for (final doc in tasksSnapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  Future<Goal?> getGoalById(String userId, String goalId) async {
    try {
      final doc = await _db
          .collection('users')
          .doc(userId)
          .collection('goals')
          .doc(goalId)
          .get();
      if (doc.exists) {
        return Goal.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      print("Erro ao buscar jornada por ID: $e");
      return null;
    }
  }

  Future<Goal?> findGoalBySanitizedTitle(
      String userId, String sanitizedTitle) async {
    try {
      final querySnapshot =
          await _db.collection('users').doc(userId).collection('goals').get();

      for (final doc in querySnapshot.docs) {
        final goal = Goal.fromFirestore(doc);
        if (StringSanitizer.toSimpleTag(goal.title).toLowerCase() ==
            sanitizedTitle.toLowerCase()) {
          return goal;
        }
      }
      return null;
    } catch (e) {
      print("Erro ao buscar meta pelo título simplificado: $e");
      return null;
    }
  }
}
