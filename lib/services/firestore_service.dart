// lib/services/firestore_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
// --- INÍCIO DA ADIÇÃO ---
import 'package:rxdart/rxdart.dart'; // Importar rxdart para combinar streams
// --- FIM DA ADIÇÃO ---
import 'package:sincro_app_flutter/common/utils/string_sanitizer.dart';
import 'package:sincro_app_flutter/models/user_model.dart';
import 'package:sincro_app_flutter/features/tasks/models/task_model.dart';
import 'package:sincro_app_flutter/features/journal/models/journal_entry_model.dart';
import 'package:sincro_app_flutter/features/goals/models/goal_model.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // --- MÉTODOS DE USUÁRIO (sem alterações) ---
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

  Future<void> updateUserDashboardOrder(String uid, List<String> order) async {
    try {
      await _db
          .collection('users')
          .doc(uid)
          .update({'dashboardCardOrder': order});
    } catch (e) {
      print("Erro ao atualizar a ordem dos cards: $e");
      rethrow;
    }
  }

  // --- MÉTODOS DE TAREFAS ---

  Future<List<TaskModel>> getTasksForToday(String userId) async {
    // (Seu método original - mantido)
    try {
      final now = DateTime.now();
      final startOfDayLocal = DateTime(now.year, now.month, now.day);
      final endOfDayLocal = startOfDayLocal.add(const Duration(days: 1));
      // Convertendo para UTC para comparação correta com Timestamps do Firestore
      final startTimestamp = Timestamp.fromDate(startOfDayLocal.toUtc());
      final endTimestamp = Timestamp.fromDate(endOfDayLocal.toUtc());
      final tasksRef = _db.collection('users').doc(userId).collection('tasks');

      final queryDueDate = tasksRef
          .where('dueDate', isGreaterThanOrEqualTo: startTimestamp)
          .where('dueDate', isLessThan: endTimestamp);
      final queryCreatedAt = tasksRef
          .where('dueDate', isEqualTo: null)
          .where('createdAt', isGreaterThanOrEqualTo: startTimestamp)
          .where('createdAt', isLessThan: endTimestamp);

      final results =
          await Future.wait([queryDueDate.get(), queryCreatedAt.get()]);
      final tasksMap = <String, TaskModel>{};
      for (var doc in results[0].docs) {
        tasksMap[doc.id] = TaskModel.fromFirestore(doc);
      }
      for (var doc in results[1].docs) {
        if (!tasksMap.containsKey(doc.id)) {
          tasksMap[doc.id] = TaskModel.fromFirestore(doc);
        }
      }
      final sortedTasks = tasksMap.values.toList()
        ..sort((a, b) =>
            (a.dueDate ?? a.createdAt).compareTo(b.dueDate ?? b.createdAt));
      return sortedTasks;
    } catch (e, stackTrace) {
      print("Erro ao buscar tarefas de hoje (Future): $e\n$stackTrace");
      return [];
    }
  }

  Future<List<TaskModel>> getTasksForCalendar(
      String userId, DateTime month) async {
    // (Seu método original - sem alterações)
    final startOfMonth = DateTime.utc(month.year, month.month, 1);
    final endOfMonth = DateTime.utc(month.year, month.month + 1, 1);
    final tasksRef = _db.collection('users').doc(userId).collection('tasks');

    final queryDueDate = tasksRef
        .where('dueDate',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth))
        .where('dueDate', isLessThan: Timestamp.fromDate(endOfMonth));
    final queryCreatedAt = tasksRef
        .where('dueDate', isEqualTo: null)
        .where('createdAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth))
        .where('createdAt', isLessThan: Timestamp.fromDate(endOfMonth));

    try {
      final results =
          await Future.wait([queryDueDate.get(), queryCreatedAt.get()]);
      final dueDateDocs = results[0].docs;
      final createdAtDocs = results[1].docs;
      final tasksMap = <String, TaskModel>{};
      for (var doc in dueDateDocs) {
        try {
          tasksMap[doc.id] = TaskModel.fromFirestore(doc);
        } catch (e) {
          print("Erro ao converter tarefa (dueDate query) ID ${doc.id}: $e");
        }
      }
      for (var doc in createdAtDocs) {
        if (!tasksMap.containsKey(doc.id)) {
          try {
            tasksMap[doc.id] = TaskModel.fromFirestore(doc);
          } catch (e) {
            print(
                "Erro ao converter tarefa (createdAt query) ID ${doc.id}: $e");
          }
        }
      }
      return tasksMap.values.toList();
    } catch (e, stackTrace) {
      print("Erro ao buscar tarefas para o calendário: $e\n$stackTrace");
      return [];
    }
  }

  Stream<List<TaskModel>> getTasksStream(String userId) {
    // (Seu método original - sem alterações)
    return _db
        .collection('users')
        .doc(userId)
        .collection('tasks')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => TaskModel.fromFirestore(doc)).toList();
    }).handleError((error, stackTrace) {
      print("Erro no stream de Tasks: $error\n$stackTrace");
      return [];
    });
  }

  Stream<List<TaskModel>> getTasksForGoalStream(String userId, String goalId) {
    // (Seu método original - sem alterações)
    return _db
        .collection('users')
        .doc(userId)
        .collection('tasks')
        .where('journeyId', isEqualTo: goalId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => TaskModel.fromFirestore(doc)).toList())
        .handleError((error, stackTrace) {
      print("Erro no stream de Tasks para Goal $goalId: $error\n$stackTrace");
      return [];
    });
  }

  Future<void> addTask(String userId, TaskModel task) async {
    // (Seu método original - sem alterações)
    final data = task.toFirestore();
    if (data['createdAt'] is DateTime) {
      data['createdAt'] = Timestamp.fromDate(data['createdAt']);
    } else if (data['createdAt'] == null) {
      data['createdAt'] = Timestamp.now();
    }
    if (data['dueDate'] is DateTime) {
      data['dueDate'] = Timestamp.fromDate(data['dueDate']);
    }
    await _db.collection('users').doc(userId).collection('tasks').add(data);
  }

  Future<void> updateTask(String userId, TaskModel task) async {
    // (Seu método original - sem alterações)
    final data = task.toFirestore();
    if (data.containsKey('createdAt') && data['createdAt'] is DateTime) {
      data['createdAt'] = Timestamp.fromDate(data['createdAt']);
    }
    if (data.containsKey('dueDate') && data['dueDate'] is DateTime) {
      data['dueDate'] = Timestamp.fromDate(data['dueDate']);
    } else if (data.containsKey('dueDate') && data['dueDate'] == null) {
      data['dueDate'] = null;
    }
    await _db
        .collection('users')
        .doc(userId)
        .collection('tasks')
        .doc(task.id)
        .update(data);
  }

  Future<void> updateTaskCompletion(String userId, String taskId,
      {required bool completed}) async {
    // (Seu método original - sem alterações)
    await _db
        .collection('users')
        .doc(userId)
        .collection('tasks')
        .doc(taskId)
        .update({'completed': completed});
  }

  Future<void> deleteTask(String userId, String taskId) async {
    // (Seu método original - sem alterações)
    await _db
        .collection('users')
        .doc(userId)
        .collection('tasks')
        .doc(taskId)
        .delete();
  }

  // --- MÉTODOS PARA O DIÁRIO DE BORDO (sem alterações) ---
  Stream<List<JournalEntry>> getJournalEntriesStream(
    String userId, {
    DateTime? date,
    int? mood,
    int? vibration,
  }) {
    Query query =
        _db.collection('users').doc(userId).collection('journalEntries');
    if (date != null) {
      final utcDate = DateTime.utc(date.year, date.month, date.day);
      final startOfDay = Timestamp.fromDate(utcDate);
      final endOfDay = Timestamp.fromDate(utcDate
          .add(const Duration(days: 1))
          .subtract(const Duration(milliseconds: 1)));
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
        return <JournalEntry>[];
      }
      List<JournalEntry> entries = [];
      for (var doc in snapshot.docs) {
        try {
          entries.add(JournalEntry.fromFirestore(doc));
        } catch (e, stackTrace) {/* Log erro */}
      }
      return entries;
    }).handleError((error, stackTrace) {
      print("Erro geral no stream de Journal Entries: $error\n$stackTrace");
      return <JournalEntry>[];
    });
  }

  Future<List<JournalEntry>> getJournalEntriesForMonth(
      String userId, DateTime month) async {
    // (Seu método original - sem alterações)
    try {
      final startOfMonth = DateTime.utc(month.year, month.month, 1);
      final endOfMonth = DateTime.utc(month.year, month.month + 1, 1)
          .subtract(const Duration(milliseconds: 1));
      final querySnapshot = await _db
          .collection('users')
          .doc(userId)
          .collection('journalEntries')
          .where('createdAt',
              isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth))
          .where('createdAt',
              isLessThanOrEqualTo: Timestamp.fromDate(endOfMonth))
          .orderBy('createdAt', descending: true)
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
    // (Seu método original - sem alterações)
    if (data['createdAt'] is DateTime) {
      data['createdAt'] =
          Timestamp.fromDate((data['createdAt'] as DateTime).toUtc());
    } else if (data['createdAt'] == null) {
      data['createdAt'] = Timestamp.now();
    }
    if (data['personalDay'] != null && data['personalDay'] is! int) {
      data['personalDay'] = int.tryParse(data['personalDay'].toString()) ?? 0;
    }
    if (data['mood'] != null && data['mood'] is! int) {
      data['mood'] = int.tryParse(data['mood'].toString()) ?? 0;
    }
    await _db
        .collection('users')
        .doc(userId)
        .collection('journalEntries')
        .add(data);
  }

  Future<void> updateJournalEntry(
      String userId, String entryId, Map<String, dynamic> data) async {
    // (Seu método original - sem alterações)
    if (data.containsKey('createdAt') && data['createdAt'] is DateTime) {
      data['createdAt'] =
          Timestamp.fromDate((data['createdAt'] as DateTime).toUtc());
    }
    if (data.containsKey('personalDay') &&
        data['personalDay'] != null &&
        data['personalDay'] is! int) {
      data['personalDay'] = int.tryParse(data['personalDay'].toString()) ?? 0;
    }
    if (data.containsKey('mood') &&
        data['mood'] != null &&
        data['mood'] is! int) {
      data['mood'] = int.tryParse(data['mood'].toString()) ?? 0;
    }
    await _db
        .collection('users')
        .doc(userId)
        .collection('journalEntries')
        .doc(entryId)
        .update(data);
  }

  Future<void> deleteJournalEntry(String userId, String entryId) async {
    // (Seu método original - sem alterações)
    await _db
        .collection('users')
        .doc(userId)
        .collection('journalEntries')
        .doc(entryId)
        .delete();
  }

  // --- MÉTODOS PARA AS METAS (JORNADAS) (sem alterações) ---
  Stream<List<Goal>> getGoalsStream(String userId) {
    // (Seu método original - sem alterações)
    return _db
        .collection('users')
        .doc(userId)
        .collection('goals')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Goal.fromFirestore(doc)).toList())
        .handleError((error, stackTrace) {
      print("Erro no stream de Goals: $error\n$stackTrace");
      return <Goal>[];
    });
  }

  Future<List<Goal>> getActiveGoals(String userId) async {
    // (Seu método original - sem alterações)
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
    // (Seu método original - sem alterações)
    if (data['createdAt'] is DateTime) {
      data['createdAt'] =
          Timestamp.fromDate((data['createdAt'] as DateTime).toUtc());
    } else if (data['createdAt'] == null) {
      data['createdAt'] = Timestamp.now();
    }
    data['progress'] = data['progress'] ?? 0;
    return await _db
        .collection('users')
        .doc(userId)
        .collection('goals')
        .add(data);
  }

  Future<void> updateGoal(
      String userId, String goalId, Map<String, dynamic> data) async {
    // (Seu método original - sem alterações)
    if (data.containsKey('createdAt') && data['createdAt'] is DateTime) {
      data['createdAt'] =
          Timestamp.fromDate((data['createdAt'] as DateTime).toUtc());
    }
    if (data.containsKey('progress') && data['progress'] is! int) {
      data['progress'] = (data['progress'] as num?)?.round() ?? 0;
    }
    await _db
        .collection('users')
        .doc(userId)
        .collection('goals')
        .doc(goalId)
        .update(data);
  }

  Future<void> updateGoalProgress(String userId, String goalId) async {
    // (Seu método original - sem alterações)
    try {
      final goalRef =
          _db.collection('users').doc(userId).collection('goals').doc(goalId);
      final goalDoc = await goalRef.get();
      if (!goalDoc.exists) {
        print("Tentativa de atualizar progresso de meta inexistente: $goalId");
        return;
      }
      final tasksSnapshot = await _db
          .collection('users')
          .doc(userId)
          .collection('tasks')
          .where('journeyId', isEqualTo: goalId)
          .get();
      final totalTasks = tasksSnapshot.docs.length;
      final completedTasks = tasksSnapshot.docs.where((doc) {
        final taskData = doc.data();
        return taskData.containsKey('completed') &&
            taskData['completed'] == true;
      }).length;
      final progress =
          totalTasks > 0 ? (completedTasks / totalTasks * 100).round() : 0;
      await goalRef.update({'progress': progress});
    } catch (e, stackTrace) {
      print("Erro ao atualizar progresso da meta $goalId: $e\n$stackTrace");
    }
  }

  Future<void> deleteGoal(String userId, String goalId) async {
    // (Seu método original - sem alterações)
    try {
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
    } catch (e, stackTrace) {
      print("Erro ao deletar meta $goalId e/ou suas tarefas: $e\n$stackTrace");
      rethrow;
    }
  }

  Future<Goal?> getGoalById(String userId, String goalId) async {
    // (Seu método original - sem alterações)
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
      print("Erro ao buscar jornada por ID $goalId: $e");
      return null;
    }
  }

  Future<Goal?> findGoalBySanitizedTitle(
      String userId, String sanitizedTitle) async {
    // (Seu método original - sem alterações)
    try {
      final querySnapshot =
          await _db.collection('users').doc(userId).collection('goals').get();
      for (final doc in querySnapshot.docs) {
        try {
          final goal = Goal.fromFirestore(doc);
          if (StringSanitizer.toSimpleTag(goal.title).toLowerCase() ==
              sanitizedTitle.toLowerCase()) {
            return goal;
          }
        } catch (e) {/* Log erro */}
      }
      return null;
    } catch (e) {
      print(
          "Erro ao buscar meta pelo título simplificado '$sanitizedTitle': $e");
      return null;
    }
  }

  // --- MÉTODOS DE STREAM PARA O CALENDÁRIO (sem alterações) ---
  Stream<List<TaskModel>> getTasksDueDateStreamForMonth(
      String userId, DateTime month) {
    final startOfMonth = DateTime.utc(month.year, month.month, 1);
    final endOfMonth = DateTime.utc(month.year, month.month + 1, 1);
    final query = _db
        .collection('users')
        .doc(userId)
        .collection('tasks')
        .where('dueDate',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth))
        .where('dueDate', isLessThan: Timestamp.fromDate(endOfMonth))
        .orderBy('dueDate');
    return query.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => TaskModel.fromFirestore(doc)).toList();
    }).handleError((error, stackTrace) {
      print(
          "Erro no stream de tasks (dueDate - Calendar): $error\n$stackTrace");
      return <TaskModel>[];
    });
  }

  Stream<List<TaskModel>> getTasksCreatedAtStreamForMonth(
      String userId, DateTime month) {
    final startOfMonth = DateTime.utc(month.year, month.month, 1);
    final endOfMonth = DateTime.utc(month.year, month.month + 1, 1);
    final query = _db
        .collection('users')
        .doc(userId)
        .collection('tasks')
        .where('dueDate', isEqualTo: null)
        .where('createdAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth))
        .where('createdAt', isLessThan: Timestamp.fromDate(endOfMonth))
        .orderBy('createdAt');
    return query.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => TaskModel.fromFirestore(doc)).toList();
    }).handleError((error, stackTrace) {
      print(
          "Erro no stream de tasks (createdAt - Calendar): $error\n$stackTrace");
      return <TaskModel>[];
    });
  }

  Stream<List<JournalEntry>> getJournalEntriesStreamForMonth(
      String userId, DateTime month) {
    final startOfMonth = DateTime.utc(month.year, month.month, 1);
    final endOfMonth = DateTime.utc(month.year, month.month + 1, 1);
    final query = _db
        .collection('users')
        .doc(userId)
        .collection('journalEntries')
        .where('createdAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth))
        .where('createdAt', isLessThan: Timestamp.fromDate(endOfMonth))
        .orderBy('createdAt', descending: true);
    return query.snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => JournalEntry.fromFirestore(doc))
          .toList();
    }).handleError((error, stackTrace) {
      print(
          "Erro no stream de Journal Entries (Calendar): $error\n$stackTrace");
      return <JournalEntry>[];
    });
  }

  // --- INÍCIO DA ADIÇÃO: NOVO MÉTODO DE STREAM PARA O FOCO DO DIA ---
  /// Retorna um Stream de tarefas [TaskModel] para o dia de HOJE.
  /// Combina tarefas com dueDate para hoje E tarefas sem dueDate criadas hoje.
  Stream<List<TaskModel>> getTasksStreamForToday(String userId) {
    final now = DateTime.now();
    final startOfDayLocal = DateTime(now.year, now.month, now.day);
    final endOfDayLocal = startOfDayLocal.add(const Duration(days: 1));

    // Converte para Timestamps UTC (Firestore compara Timestamps)
    final startTimestamp = Timestamp.fromDate(startOfDayLocal.toUtc());
    final endTimestamp = Timestamp.fromDate(endOfDayLocal.toUtc());

    final tasksRef = _db.collection('users').doc(userId).collection('tasks');

    // Stream 1: Tarefas COM dueDate para hoje (Requer índice: dueDate ASC)
    final streamDueDate = tasksRef
        .where('dueDate', isGreaterThanOrEqualTo: startTimestamp)
        .where('dueDate', isLessThan: endTimestamp)
        .orderBy('dueDate')
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => TaskModel.fromFirestore(doc)).toList())
        .handleError((error, stackTrace) {
      print("Erro no stream de tasks (dueDate - Today): $error\n$stackTrace");
      return <TaskModel>[];
    });

    // Stream 2: Tarefas SEM dueDate (null) E criadas hoje (Requer índice: dueDate == null, createdAt ASC)
    final streamCreatedAt = tasksRef
        .where('dueDate', isEqualTo: null)
        .where('createdAt', isGreaterThanOrEqualTo: startTimestamp)
        .where('createdAt', isLessThan: endTimestamp)
        .orderBy('createdAt')
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => TaskModel.fromFirestore(doc)).toList())
        .handleError((error, stackTrace) {
      print("Erro no stream de tasks (createdAt - Today): $error\n$stackTrace");
      return <TaskModel>[];
    });

    // Combina os dois streams usando rxdart
    return Rx.combineLatest2<List<TaskModel>, List<TaskModel>, List<TaskModel>>(
      streamDueDate,
      streamCreatedAt,
      (dueDateTasks, createdAtTasks) {
        // Lógica de combinação idêntica ao Future getTasksForToday
        final tasksMap = <String, TaskModel>{};
        for (var task in dueDateTasks) {
          tasksMap[task.id] = task;
        }
        for (var task in createdAtTasks) {
          if (!tasksMap.containsKey(task.id)) {
            tasksMap[task.id] = task;
          }
        }
        final combinedList = tasksMap.values.toList()
          ..sort((a, b) =>
              (a.dueDate ?? a.createdAt).compareTo(b.dueDate ?? b.createdAt));
        return combinedList;
      },
    );
  }
  // --- FIM DA ADIÇÃO ---

  // --- FUNÇÃO getTasksForFocusDay (sem alterações) ---
  Future<List<TaskModel>> getTasksForFocusDay(
      String userId, DateTime day) async {
    try {
      final startOfDayLocal = DateTime(day.year, day.month, day.day);
      final endOfDayLocal = startOfDayLocal.add(const Duration(days: 1));
      // Convertendo para UTC
      final startTimestamp = Timestamp.fromDate(startOfDayLocal.toUtc());
      final endTimestamp = Timestamp.fromDate(endOfDayLocal.toUtc());
      final tasksRef = _db.collection('users').doc(userId).collection('tasks');

      final dueDateSnapshot = await tasksRef
          .where('dueDate', isGreaterThanOrEqualTo: startTimestamp)
          .where('dueDate', isLessThan: endTimestamp)
          .get();
      final createdAtSnapshot = await tasksRef
          .where('dueDate', isEqualTo: null)
          .where('createdAt', isGreaterThanOrEqualTo: startTimestamp)
          .where('createdAt', isLessThan: endTimestamp)
          .get();

      final tasksMap = <String, TaskModel>{};
      for (var doc in dueDateSnapshot.docs) {
        tasksMap[doc.id] = TaskModel.fromFirestore(doc);
      }
      for (var doc in createdAtSnapshot.docs) {
        if (!tasksMap.containsKey(doc.id)) {
          tasksMap[doc.id] = TaskModel.fromFirestore(doc);
        }
      }
      final sortedTasks = tasksMap.values.toList()
        ..sort((a, b) =>
            (a.dueDate ?? a.createdAt).compareTo(b.dueDate ?? b.createdAt));
      return sortedTasks;
    } catch (e, stackTrace) {
      print("Erro ao buscar tarefas para o Foco do Dia: $e\n$stackTrace");
      return [];
    }
  }
} // Fim da classe FirestoreService
