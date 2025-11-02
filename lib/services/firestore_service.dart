// lib/services/firestore_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
// ADICIONADO: Import para debugPrint
import 'package:flutter/foundation.dart';
import 'package:rxdart/rxdart.dart';
import 'package:sincro_app_flutter/common/utils/string_sanitizer.dart';
import 'package:sincro_app_flutter/models/user_model.dart';
import 'package:sincro_app_flutter/features/tasks/models/task_model.dart';
import 'package:sincro_app_flutter/features/journal/models/journal_entry_model.dart';
import 'package:sincro_app_flutter/features/goals/models/goal_model.dart'; // Mantido como Goal
// ADICIONADO: Importa ParsedTask e RecurrenceRule
import 'package:sincro_app_flutter/features/tasks/utils/task_parser.dart';
import 'package:sincro_app_flutter/common/widgets/custom_recurrence_picker_modal.dart';
import 'package:flutter/material.dart'; // Para TimeOfDay

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // --- MÉTODOS DE USUÁRIO (Seu código original, mantido) ---
  Future<void> saveUserData(UserModel user) async {
    try {
      await _db.collection('users').doc(user.uid).set({
        'email': user.email,
        'photoUrl': user.photoUrl,
        'primeiroNome': user.primeiroNome,
        'sobrenome': user.sobrenome,
        'nomeAnalise': user.nomeAnalise,
        'dataNasc': user.dataNasc,
        'plano': user.plano,
        'isAdmin': user.isAdmin,
        'dashboardCardOrder': user.dashboardCardOrder,
      }, SetOptions(merge: true)); // Usa merge para não sobrescrever
    } catch (e) {
      debugPrint("Erro ao salvar dados do usuário: $e");
      rethrow;
    }
  }

  Future<void> updateUserData(String uid, Map<String, dynamic> data) async {
    try {
      await _db.collection('users').doc(uid).update(data);
    } catch (e) {
      debugPrint("Erro ao atualizar dados do usuário: $e");
      rethrow;
    }
  }

  Future<UserModel?> getUserData(String uid) async {
    try {
      DocumentSnapshot doc = await _db.collection('users').doc(uid).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        // Tratamento robusto para lista (caso null ou tipo errado)
        List<String> cardOrder = UserModel.defaultCardOrder;
        if (data['dashboardCardOrder'] is List) {
          try {
            cardOrder = List<String>.from(data['dashboardCardOrder']);
          } catch (e) {
            debugPrint(
                "Erro ao converter dashboardCardOrder: $e. Usando padrão.");
          }
        }
        return UserModel(
          uid: doc.id,
          email: data['email'] ?? '',
          photoUrl: data['photoUrl'] as String?,
          primeiroNome: data['primeiroNome'] ?? '',
          sobrenome: data['sobrenome'] ?? '',
          nomeAnalise: data['nomeAnalise'] ?? '',
          dataNasc: data['dataNasc'] ?? '',
          plano: data['plano'] ?? 'gratuito',
          isAdmin: data['isAdmin'] ?? false,
          dashboardCardOrder: cardOrder,
        );
      }
      return null;
    } catch (e) {
      debugPrint("Erro ao buscar dados do usuário: $e");
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
      debugPrint("Erro ao atualizar a ordem dos cards: $e");
      rethrow;
    }
  }

  // --- MÉTODOS DE TAREFAS (Seu código original, mantido) ---
  Future<List<TaskModel>> getRecentTasks(String userId,
      {int limit = 20}) async {
    try {
      final querySnapshot = await _db
          .collection('users')
          .doc(userId)
          .collection('tasks')
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();

      return querySnapshot.docs
          .map((doc) => TaskModel.fromFirestore(doc))
          .toList();
    } catch (e, stackTrace) {
      debugPrint("Erro ao buscar tarefas recentes: $e\n$stackTrace");
      return [];
    }
  }

  Future<List<TaskModel>> getTasksForToday(String userId) async {
    try {
      final now = DateTime.now();
      // Usa UTC para queries
      final startOfDayUtc = DateTime.utc(now.year, now.month, now.day);
      final endOfDayUtc = startOfDayUtc.add(const Duration(days: 1));
      final startTimestamp = Timestamp.fromDate(startOfDayUtc);
      final endTimestamp = Timestamp.fromDate(endOfDayUtc);
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
        try {
          tasksMap[doc.id] = TaskModel.fromFirestore(doc);
        } catch (e) {
          debugPrint("Parse Error dueDate Tsk ID ${doc.id}: $e");
        }
      }
      for (var doc in results[1].docs) {
        if (!tasksMap.containsKey(doc.id)) {
          try {
            tasksMap[doc.id] = TaskModel.fromFirestore(doc);
          } catch (e) {
            debugPrint("Parse Error createdAt Tsk ID ${doc.id}: $e");
          }
        }
      }
      final sortedTasks = tasksMap.values.toList()
        ..sort((a, b) =>
            (a.dueDate ?? a.createdAt).compareTo(b.dueDate ?? b.createdAt));
      return sortedTasks;
    } catch (e, stackTrace) {
      debugPrint("Erro ao buscar tarefas de hoje (Future): $e\n$stackTrace");
      return [];
    }
  }

  Future<List<TaskModel>> getTasksForCalendar(
      String userId, DateTime month) async {
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
          debugPrint(
              "Erro ao converter tarefa (dueDate query - Cal) ID ${doc.id}: $e");
        }
      }
      for (var doc in createdAtDocs) {
        if (!tasksMap.containsKey(doc.id)) {
          try {
            tasksMap[doc.id] = TaskModel.fromFirestore(doc);
          } catch (e) {
            debugPrint(
                "Erro ao converter tarefa (createdAt query - Cal) ID ${doc.id}: $e");
          }
        }
      }
      return tasksMap.values.toList();
    } catch (e, stackTrace) {
      debugPrint("Erro ao buscar tarefas para o calendário: $e\n$stackTrace");
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
      try {
        return snapshot.docs
            .map((doc) => TaskModel.fromFirestore(doc))
            .toList();
      } catch (e, st) {
        debugPrint("Parse Error in Tasks Stream: $e\n$st");
        return <TaskModel>[];
      }
    }).handleError((error, stackTrace) {
      debugPrint("Erro no stream de Tasks: $error\n$stackTrace");
      return <TaskModel>[]; // Retorna stream vazio em caso de erro
    });
  }

  Stream<List<TaskModel>> getTasksForGoalStream(String userId, String goalId) {
    return _db
        .collection('users')
        .doc(userId)
        .collection('tasks')
        .where('journeyId', isEqualTo: goalId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      try {
        return snapshot.docs
            .map((doc) => TaskModel.fromFirestore(doc))
            .toList();
      } catch (e, st) {
        debugPrint("Parse Error in Tasks Goal Stream (Goal $goalId): $e\n$st");
        return <TaskModel>[];
      }
    }).handleError((error, stackTrace) {
      debugPrint(
          "Erro no stream de Tasks para Goal $goalId: $error\n$stackTrace");
      return <TaskModel>[];
    });
  }

  Future<void> addTask(String userId, TaskModel task) async {
    // Seu método original validava/convertia Timestamps aqui.
    // Assumindo que toFirestore() já faz isso corretamente.
    try {
      // --- INÍCIO DA MUDANÇA: Garantir que o ID seja salvo ---
      final docRef = await _db
          .collection('users')
          .doc(userId)
          .collection('tasks')
          .add(task.toFirestore());

      // Atualiza o documento com seu próprio ID
      await docRef.update({'id': docRef.id});
      // --- FIM DA MUDANÇA ---
    } catch (e) {
      debugPrint("Erro ao adicionar tarefa no Firestore: $e");
      rethrow;
    }
  }

  Future<void> updateTask(String userId, TaskModel task) async {
    // Seu método original validava/convertia Timestamps aqui.
    // Assumindo que toFirestore() já faz isso corretamente.
    try {
      await _db
          .collection('users')
          .doc(userId)
          .collection('tasks')
          .doc(task.id)
          .update(task.toFirestore());
    } catch (e) {
      debugPrint("Erro ao atualizar tarefa completa ID ${task.id}: $e");
      rethrow;
    }
  }

  Future<void> updateTaskFields(
      String userId, String taskId, Map<String, dynamic> updates) async {
    try {
      // Seu método original convertia Timestamps aqui.
      // É mais seguro fazer isso aqui do que depender do chamador.
      final Map<String, dynamic> finalUpdates = Map.from(updates);

      if (finalUpdates.containsKey('createdAt') &&
          finalUpdates['createdAt'] is DateTime) {
        finalUpdates['createdAt'] =
            Timestamp.fromDate((finalUpdates['createdAt'] as DateTime).toUtc());
      }
      if (finalUpdates.containsKey('dueDate')) {
        if (finalUpdates['dueDate'] is DateTime) {
          // Garante que só a data (sem hora) em UTC seja salva
          final localDate = (finalUpdates['dueDate'] as DateTime).toLocal();
          final dateOnlyUtc =
              DateTime.utc(localDate.year, localDate.month, localDate.day);
          finalUpdates['dueDate'] = Timestamp.fromDate(dateOnlyUtc);
        } else {
          finalUpdates['dueDate'] = null; // Garante null se não for DateTime
        }
      }
      if (finalUpdates.containsKey('recurrenceEndDate')) {
        if (finalUpdates['recurrenceEndDate'] is DateTime) {
          finalUpdates['recurrenceEndDate'] = Timestamp.fromDate(
              (finalUpdates['recurrenceEndDate'] as DateTime).toUtc());
        } else {
          finalUpdates['recurrenceEndDate'] = null;
        }
      }

      await _db
          .collection('users')
          .doc(userId)
          .collection('tasks')
          .doc(taskId)
          .update(finalUpdates);
    } catch (e) {
      debugPrint("Erro ao atualizar campos da tarefa ID $taskId: $e");
      rethrow;
    }
  }

  Future<void> updateTaskCompletion(String userId, String taskId,
      {required bool completed}) async {
    try {
      // --- INÍCIO DA MUDANÇA (Solicitação 2) ---
      await _db
          .collection('users')
          .doc(userId)
          .collection('tasks')
          .doc(taskId)
          .update({
        'completed': completed,
        // Adiciona/remove o timestamp de conclusão
        'completedAt': completed ? FieldValue.serverTimestamp() : null,
      });
      // --- FIM DA MUDANÇA ---
    } catch (e) {
      debugPrint("Erro ao atualizar status da tarefa ID $taskId: $e");
      rethrow; // Relança para a UI poder reagir
    }
  }

  Future<void> deleteTask(String userId, String taskId) async {
    try {
      await _db
          .collection('users')
          .doc(userId)
          .collection('tasks')
          .doc(taskId)
          .delete();
    } catch (e) {
      debugPrint("Erro ao deletar tarefa ID $taskId: $e");
      rethrow;
    }
  }

  // --- INÍCIO DA MUDANÇA: (Solicitação 1) ---
  /// Exclui uma lista de tarefas usando um WriteBatch.
  Future<void> deleteTasks(String userId, List<String> taskIds) async {
    if (taskIds.isEmpty) return;

    try {
      final WriteBatch batch = _db.batch();
      final collectionRef =
          _db.collection('users').doc(userId).collection('tasks');

      for (final taskId in taskIds) {
        if (taskId.isNotEmpty) {
          final docRef = collectionRef.doc(taskId);
          batch.delete(docRef);
        } else {
          debugPrint("Aviso: Tentativa de excluir tarefa com ID vazio.");
        }
      }

      await batch.commit();
    } catch (e) {
      debugPrint("Erro ao excluir tarefas em lote: $e");
      rethrow;
    }
  }
  // --- FIM DA MUDANÇA ---

  // --- MÉTODOS PARA O DIÁRIO DE BORDO (Seu código original, mantido) ---
  Stream<List<JournalEntry>> getJournalEntriesStream(
    String userId, {
    DateTime? date, // Data LOCAL
    int? mood,
    int? vibration,
  }) {
    Query query =
        _db.collection('users').doc(userId).collection('journalEntries');

    if (date != null) {
      // Converte a data LOCAL para UTC para a query
      final startOfDayUtc = DateTime.utc(date.year, date.month, date.day);
      final endOfDayUtc = startOfDayUtc.add(const Duration(days: 1));
      query = query
          .where('createdAt',
              isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDayUtc))
          .where('createdAt', isLessThan: Timestamp.fromDate(endOfDayUtc));
    }
    if (mood != null) {
      query = query.where('mood', isEqualTo: mood);
    }
    if (vibration != null) {
      query = query.where('personalDay', isEqualTo: vibration);
    }
    query = query.orderBy('createdAt', descending: true); // Ordena sempre

    return query.snapshots().map((snapshot) {
      List<JournalEntry> entries = [];
      for (var doc in snapshot.docs) {
        try {
          entries.add(JournalEntry.fromFirestore(doc));
        } catch (e, stackTrace) {
          debugPrint(
              "Erro ao converter Journal Entry ID ${doc.id}: $e\n$stackTrace");
        }
      }
      return entries;
    }).handleError((error, stackTrace) {
      debugPrint(
          "Erro geral no stream de Journal Entries: $error\n$stackTrace");
      return <JournalEntry>[];
    });
  }

  Future<List<JournalEntry>> getJournalEntriesForMonth(
      String userId, DateTime month) async {
    try {
      final startOfMonth = DateTime.utc(month.year, month.month, 1);
      final endOfMonth = DateTime.utc(month.year, month.month + 1, 1);
      final querySnapshot = await _db
          .collection('users')
          .doc(userId)
          .collection('journalEntries')
          .where('createdAt',
              isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth))
          .where('createdAt', isLessThan: Timestamp.fromDate(endOfMonth))
          .orderBy('createdAt', descending: true)
          .get();
      // Adiciona tratamento de erro no mapeamento
      List<JournalEntry> entries = [];
      for (var doc in querySnapshot.docs) {
        try {
          entries.add(JournalEntry.fromFirestore(doc));
        } catch (e) {
          debugPrint(
              "Erro ao converter Journal Entry (Month) ID ${doc.id}: $e");
        }
      }
      return entries;
    } catch (e) {
      debugPrint("Erro ao buscar anotações do diário para o mês: $e");
      return [];
    }
  }

  Future<void> addJournalEntry(String userId, Map<String, dynamic> data) async {
    try {
      final Map<String, dynamic> finalData = Map.from(data);
      // Garante Timestamp UTC
      if (finalData['createdAt'] is DateTime) {
        finalData['createdAt'] =
            Timestamp.fromDate((finalData['createdAt'] as DateTime).toUtc());
      } else {
        finalData['createdAt'] = Timestamp.now();
      }
      // Garante int ou null
      finalData['personalDay'] =
          int.tryParse(finalData['personalDay']?.toString() ?? '');
      finalData['mood'] = int.tryParse(finalData['mood']?.toString() ?? '');

      await _db
          .collection('users')
          .doc(userId)
          .collection('journalEntries')
          .add(finalData);
    } catch (e) {
      debugPrint("Erro ao adicionar anotação no diário: $e");
      rethrow;
    }
  }

  Future<void> updateJournalEntry(
      String userId, String entryId, Map<String, dynamic> data) async {
    try {
      final Map<String, dynamic> finalUpdates = Map.from(data);
      // Garante Timestamp UTC se presente
      if (finalUpdates.containsKey('createdAt') &&
          finalUpdates['createdAt'] is DateTime) {
        finalUpdates['createdAt'] =
            Timestamp.fromDate((finalUpdates['createdAt'] as DateTime).toUtc());
      }
      // Garante int ou null se presentes
      if (finalUpdates.containsKey('personalDay')) {
        finalUpdates['personalDay'] =
            int.tryParse(finalUpdates['personalDay']?.toString() ?? '');
      }
      if (finalUpdates.containsKey('mood')) {
        finalUpdates['mood'] =
            int.tryParse(finalUpdates['mood']?.toString() ?? '');
      }

      await _db
          .collection('users')
          .doc(userId)
          .collection('journalEntries')
          .doc(entryId)
          .update(finalUpdates);
    } catch (e) {
      debugPrint("Erro ao atualizar anotação do diário ID $entryId: $e");
      rethrow;
    }
  }

  Future<void> deleteJournalEntry(String userId, String entryId) async {
    try {
      await _db
          .collection('users')
          .doc(userId)
          .collection('journalEntries')
          .doc(entryId)
          .delete();
    } catch (e) {
      debugPrint("Erro ao deletar anotação do diário ID $entryId: $e");
      rethrow;
    }
  }

  // --- MÉTODOS PARA AS METAS (JORNADAS) (Seu código original, mantido com 'Goal') ---
  Future<void> updateGoal(Goal goal) async {
    // <-- Mantido Goal
    try {
      final data = goal.toFirestore();
      // Garante Timestamps UTC antes de salvar
      if (data.containsKey('createdAt') && data['createdAt'] is DateTime) {
        data['createdAt'] =
            Timestamp.fromDate((data['createdAt'] as DateTime).toUtc());
      }
      if (data.containsKey('targetDate')) {
        if (data['targetDate'] is DateTime) {
          data['targetDate'] =
              Timestamp.fromDate((data['targetDate'] as DateTime).toUtc());
        } else {
          data['targetDate'] = null; // Garante null se não for DateTime
        }
      }

      await _db
          .collection('users')
          .doc(goal.userId) // Assume que Goal tem userId
          .collection('goals')
          .doc(goal.id)
          .update(data);
    } catch (e) {
      debugPrint("Erro ao atualizar a meta ${goal.id}: $e");
      rethrow;
    }
  }

  Stream<List<Goal>> getGoalsStream(String userId) {
    // <-- Mantido Goal
    return _db
        .collection('users')
        .doc(userId)
        .collection('goals')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      try {
        // Assume que GoalModel.fromFirestore é o construtor correto
        return snapshot.docs
            .map((doc) => Goal.fromFirestore(doc))
            .toList(); // <-- Mantido Goal
      } catch (e, st) {
        debugPrint("Parse Error in Goals Stream: $e\n$st");
        return <Goal>[]; // <-- Mantido Goal
      }
    }).handleError((error, stackTrace) {
      debugPrint("Erro no stream de Goals: $error\n$stackTrace");
      return <Goal>[]; // <-- Mantido Goal
    });
  }

  Future<List<Goal>> getActiveGoals(String userId) async {
    // <-- Mantido Goal
    try {
      final querySnapshot = await _db
          .collection('users')
          .doc(userId)
          .collection('goals')
          // .where('status', isEqualTo: 'active') // Mantido comentado como original
          .orderBy('createdAt', descending: true)
          .get();
      List<Goal> goals = []; // <-- Mantido Goal
      for (var doc in querySnapshot.docs) {
        try {
          goals.add(Goal.fromFirestore(doc)); // <-- Mantido Goal
        } catch (e) {
          debugPrint("Erro ao converter Goal (Active) ID ${doc.id}: $e");
        }
      }
      return goals;
    } catch (e) {
      debugPrint("Erro ao buscar as jornadas ativas: $e");
      return [];
    }
  }

  Future<DocumentReference> addGoal(
      String userId, Map<String, dynamic> data) async {
    // Seu método original já está aqui e parece correto
    try {
      final Map<String, dynamic> finalData = Map.from(data);
      if (finalData['createdAt'] is DateTime) {
        finalData['createdAt'] =
            Timestamp.fromDate((finalData['createdAt'] as DateTime).toUtc());
      } else {
        finalData['createdAt'] = Timestamp.now();
      }
      if (finalData['targetDate'] is DateTime) {
        finalData['targetDate'] =
            Timestamp.fromDate((finalData['targetDate'] as DateTime).toUtc());
      } else {
        finalData['targetDate'] = null;
      }
      finalData['progress'] = finalData['progress'] ?? 0;
      finalData['subTasks'] = finalData['subTasks'] ?? [];
      finalData['userId'] = userId; // Garante userId
      // Garante sanitizedTitle
      if (!finalData.containsKey('sanitizedTitle') &&
          finalData.containsKey('title') &&
          finalData['title'] is String) {
        finalData['sanitizedTitle'] =
            StringSanitizer.toSimpleTag(finalData['title']);
      }

      return await _db
          .collection('users')
          .doc(userId)
          .collection('goals')
          .add(finalData);
    } catch (e) {
      debugPrint("Erro ao adicionar Goal: $e");
      rethrow;
    }
  }

  Future<void> updateGoalProgress(String userId, String goalId) async {
    // Seu método original já está aqui e parece correto
    try {
      final goalRef =
          _db.collection('users').doc(userId).collection('goals').doc(goalId);
      final tasksSnapshot = await _db
          .collection('users')
          .doc(userId)
          .collection('tasks')
          .where('journeyId', isEqualTo: goalId)
          .get();

      final totalTasks = tasksSnapshot.docs.length;
      int completedTasks = 0;
      if (totalTasks > 0) {
        completedTasks = tasksSnapshot.docs.where((doc) {
          final taskData = doc.data();
          return taskData['completed'] == true;
        }).length;
      }

      final progress =
          totalTasks > 0 ? (completedTasks / totalTasks * 100).round() : 0;
      await goalRef.update({'progress': progress});
    } catch (e, stackTrace) {
      debugPrint(
          "Erro ao atualizar progresso da meta $goalId: $e\n$stackTrace");
    }
  }

  Future<void> deleteGoal(String userId, String goalId) async {
    // Seu método original já está aqui e parece correto
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
        // Desvincula em vez de deletar (como no seu original)
        batch.update(doc.reference, {'journeyId': null, 'journeyTitle': null});
        // batch.delete(doc.reference); // Se preferir deletar
      }

      await batch.commit();
    } catch (e, stackTrace) {
      debugPrint("Erro ao deletar/desvincular meta $goalId: $e\n$stackTrace");
      rethrow;
    }
  }

  Future<Goal?> getGoalById(String userId, String goalId) async {
    // <-- Mantido Goal
    try {
      final doc = await _db
          .collection('users')
          .doc(userId)
          .collection('goals')
          .doc(goalId)
          .get();
      if (doc.exists) {
        try {
          return Goal.fromFirestore(doc); // <-- Mantido Goal
        } catch (e) {
          debugPrint("Parse Error Goal ID $goalId: $e");
          return null;
        }
      }
      return null;
    } catch (e) {
      debugPrint("Erro ao buscar jornada por ID $goalId: $e");
      return null;
    }
  }

  Future<Goal?> findGoalBySanitizedTitle(
      // <-- Mantido Goal
      String userId,
      String sanitizedTitle) async {
    // Seu método original já está aqui e parece correto
    // Apenas adicionado toLowerCase para garantir case-insensitivity
    final lowerSanitizedTitle = sanitizedTitle.toLowerCase();
    try {
      // Query mais eficiente usando where e limit(1)
      final querySnapshot = await _db
          .collection('users')
          .doc(userId)
          .collection('goals')
          .where('sanitizedTitle',
              isEqualTo:
                  lowerSanitizedTitle) // Assume que 'sanitizedTitle' está salvo em minúsculas
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        try {
          return Goal.fromFirestore(
              querySnapshot.docs.first); // <-- Mantido Goal
        } catch (e) {
          debugPrint(
              "Parse Error Goal (sanitized title) ID ${querySnapshot.docs.first.id}: $e");
          return null;
        }
      }
      return null; // Nenhum encontrado
    } catch (e) {
      debugPrint(
          "Erro ao buscar meta pelo título simplificado '$lowerSanitizedTitle': $e");
      return null;
    }
  }

  // --- MÉTODOS DE STREAM PARA O CALENDÁRIO (Seu código original, mantido) ---
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
      try {
        return snapshot.docs
            .map((doc) => TaskModel.fromFirestore(doc))
            .toList();
      } catch (e, st) {
        debugPrint("Parse Error Tasks (dueDate - Cal Stream): $e\n$st");
        return <TaskModel>[];
      }
    }).handleError((error, stackTrace) {
      debugPrint(
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
      try {
        return snapshot.docs
            .map((doc) => TaskModel.fromFirestore(doc))
            .toList();
      } catch (e, st) {
        debugPrint("Parse Error Tasks (createdAt - Cal Stream): $e\n$st");
        return <TaskModel>[];
      }
    }).handleError((error, stackTrace) {
      debugPrint(
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
      try {
        return snapshot.docs
            .map((doc) => JournalEntry.fromFirestore(doc))
            .toList();
      } catch (e, st) {
        debugPrint("Parse Error Journal Entries (Cal Stream): $e\n$st");
        // --- CORREÇÃO (da sua versão): Retornar o tipo correto no erro ---
        return <JournalEntry>[];
        // --- FIM DA CORREÇÃO ---
      }
    }).handleError((error, stackTrace) {
      debugPrint(
          "Erro no stream de Journal Entries (Calendar): $error\n$stackTrace");
      return <JournalEntry>[];
    });
  }

  // --- STREAM PARA O FOCO DO DIA (Seu código original, mantido) ---
  Stream<List<TaskModel>> getTasksStreamForToday(String userId) {
    final now = DateTime.now().toUtc();
    final startOfDayUtc = DateTime.utc(now.year, now.month, now.day);
    final endOfDayUtc = startOfDayUtc.add(const Duration(days: 1));
    final startTimestamp = Timestamp.fromDate(startOfDayUtc);
    final endTimestamp = Timestamp.fromDate(endOfDayUtc);
    final tasksRef = _db.collection('users').doc(userId).collection('tasks');

    final streamDueDate = tasksRef
        .where('dueDate', isGreaterThanOrEqualTo: startTimestamp)
        .where('dueDate', isLessThan: endTimestamp)
        .orderBy('dueDate')
        .snapshots()
        .map((snapshot) {
      try {
        return snapshot.docs
            .map((doc) => TaskModel.fromFirestore(doc))
            .toList();
      } catch (e, st) {
        debugPrint("Parse Error tasks (dueDate - Today Stream): $e\n$st");
        return <TaskModel>[];
      }
    }).handleError((error, stackTrace) {
      debugPrint(
          "Erro no stream de tasks (dueDate - Today): $error\n$stackTrace");
      return <TaskModel>[];
    });

    final streamCreatedAt = tasksRef
        .where('dueDate', isEqualTo: null)
        .where('createdAt', isGreaterThanOrEqualTo: startTimestamp)
        .where('createdAt', isLessThan: endTimestamp)
        .orderBy('createdAt')
        .snapshots()
        .map((snapshot) {
      try {
        return snapshot.docs
            .map((doc) => TaskModel.fromFirestore(doc))
            .toList();
      } catch (e, st) {
        debugPrint("Parse Error tasks (createdAt - Today Stream): $e\n$st");
        return <TaskModel>[];
      }
    }).handleError((error, stackTrace) {
      debugPrint(
          "Erro no stream de tasks (createdAt - Today): $error\n$stackTrace");
      return <TaskModel>[];
    });

    return Rx.combineLatest2<List<TaskModel>, List<TaskModel>, List<TaskModel>>(
      streamDueDate,
      streamCreatedAt,
      (dueDateTasks, createdAtTasks) {
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
          ..sort((a, b) => (a.dueDate ?? a.createdAt)
              .toUtc()
              .compareTo((b.dueDate ?? b.createdAt).toUtc()));
        return combinedList;
      },
    );
  }

  // --- FUNÇÃO getTasksForFocusDay (Seu código original, mantido) ---
  Future<List<TaskModel>> getTasksForFocusDay(
      String userId, DateTime day) async {
    // Recebe dia LOCAL
    try {
      final startOfDayUtc = DateTime.utc(day.year, day.month, day.day);
      final endOfDayUtc = startOfDayUtc.add(const Duration(days: 1));
      final startTimestamp = Timestamp.fromDate(startOfDayUtc);
      final endTimestamp = Timestamp.fromDate(endOfDayUtc);
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
        try {
          tasksMap[doc.id] = TaskModel.fromFirestore(doc);
        } catch (e) {
          debugPrint("Parse Error Task (dueDate - Focus Day) ID ${doc.id}: $e");
        }
      }
      for (var doc in createdAtSnapshot.docs) {
        if (!tasksMap.containsKey(doc.id)) {
          try {
            tasksMap[doc.id] = TaskModel.fromFirestore(doc);
          } catch (e) {
            debugPrint(
                "Parse Error Task (createdAt - Focus Day) ID ${doc.id}: $e");
          }
        }
      }
      final sortedTasks = tasksMap.values.toList()
        ..sort((a, b) => (a.dueDate ?? a.createdAt)
            .toUtc()
            .compareTo((b.dueDate ?? b.createdAt).toUtc()));
      return sortedTasks;
    } catch (e, stackTrace) {
      debugPrint("Erro ao buscar tarefas para o Foco do Dia: $e\n$stackTrace");
      return [];
    }
  }

  // --- Trecho Corrigido do Método createGoal ---
  Future<Goal> createGoal(String userId, String title) async {
    try {
      // O título sanitizado NÃO é passado para o construtor do Goal.
      // O método 'addGoal' cuidará de adicioná-lo ao Map antes de salvar.
      // final sanitizedTitle = StringSanitizer.toSimpleTag(title); // Não precisa calcular aqui

      final newGoal = Goal(
        // Mantido Goal
        id: '', // Será gerado pelo addGoal/Firestore
        userId: userId,
        title: title, // Título original
        createdAt: DateTime.now().toUtc(),
        description: '', // Demais campos padrão do seu Model
        progress: 0,
        subTasks: [],
        // status: 'active', // Assumido padrão no model
        // Removido -> sanitizedTitle: sanitizedTitle,
      );

      // Chama seu método 'addGoal' original, que espera um Map.
      // O 'addGoal' vai adicionar o 'sanitizedTitle' ao Map.
      final docRef = await addGoal(
          userId, newGoal.toFirestore()); // Assume que Goal tem toFirestore()

      // Retorna o objeto Goal com o ID correto
      return newGoal.copyWith(id: docRef.id); // Assume que Goal tem copyWith()
    } catch (e) {
      debugPrint("Erro ao criar Goal no Firestore: $e");
      rethrow;
    }
  }
// --- Fim do Trecho Corrigido ---

  Future<List<String>> getTags(String userId) async {
    try {
      final snapshot = await _db
          .collection('users')
          .doc(userId)
          .collection('tags')
          .orderBy('name') // Ordena alfabeticamente
          .get();

      List<String> tags = [];
      for (var doc in snapshot.docs) {
        final data = doc.data();
        if (data['name'] is String) {
          // Verifica se 'name' existe e é String
          tags.add(data['name']);
        } else {
          debugPrint("Tag document ${doc.id} missing or invalid 'name'.");
        }
      }
      return tags;
    } catch (e) {
      debugPrint('Erro ao buscar Tags: $e');
      return [];
    }
  }

  Future<String> createTag(String userId, String tagName) async {
    try {
      final tagId =
          StringSanitizer.toSimpleTag(tagName); // Usa nome sanitizado como ID

      final tagRef =
          _db.collection('users').doc(userId).collection('tags').doc(tagId);

      // Cria ou atualiza
      await tagRef.set({
        'name': tagName, // Nome original
        'userId': userId,
        'createdAt': Timestamp.now(),
        'id': tagId, // Adiciona ID ao documento
      }, SetOptions(merge: true));

      return tagName; // Retorna nome original
    } catch (e) {
      debugPrint('Erro ao criar Tag "$tagName" no Firestore: $e');
      rethrow;
    }
  }

  // ---
  // --- MÉTODO addRecurringTasks (ADICIONADO) ---
  // ---
  Future<void> addRecurringTasks(String userId, ParsedTask baseParsedTask,
      List<DateTime> dates, String recurrenceId) async {
    final batch = _db.batch();
    final tasksCollection =
        _db.collection('users').doc(userId).collection('tasks');

    for (final date in dates) {
      // Garante que dueDate seja apenas Data (dia/mês/ano) em UTC
      DateTime? finalDueDateUtc = DateTime.utc(date.year, date.month, date.day);

      final task = TaskModel(
        id: '', // Firestore vai gerar
        text: baseParsedTask.cleanText,
        createdAt: DateTime.now().toUtc(), // Hora da criação original
        dueDate:
            finalDueDateUtc, // A data específica desta instância (UTC, sem hora)
        tags: baseParsedTask.tags,
        journeyId: baseParsedTask.journeyId,
        journeyTitle: baseParsedTask.journeyTitle,
        reminderTime: baseParsedTask.reminderTime,
        recurrenceType: baseParsedTask.recurrenceRule.type,
        // --- CONFIRMADO: Passa a List<int> ---
        recurrenceDaysOfWeek: baseParsedTask.recurrenceRule.daysOfWeek,
        recurrenceEndDate: baseParsedTask.recurrenceRule.endDate?.toUtc(),
        recurrenceId: recurrenceId, // ID que agrupa todas as instâncias
        // TODO: Calcular personalDay aqui?
        // personalDay: calculatePersonalDay(finalDueDateUtc),
      );

      // Adiciona a operação de criação ao batch
      final docRef = tasksCollection.doc();
      batch.set(docRef, task.toFirestore());

      // --- INÍCIO DA MUDANÇA: Garantir que o ID seja salvo ---
      // Adiciona uma operação de update para salvar o ID no próprio documento
      batch.update(docRef, {'id': docRef.id});
      // --- FIM DA MUDANÇA ---
    }

    // Executa o batch
    try {
      await batch.commit();
    } catch (e) {
      debugPrint("Erro ao salvar tarefas recorrentes em lote: $e");
      throw Exception('Não foi possível salvar as tarefas recorrentes.');
    }
  }
  // --- FIM DO MÉTODO addRecurringTasks ---
} // Fim da classe FirestoreService
