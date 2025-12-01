// lib/services/firestore_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:rxdart/rxdart.dart';
import 'package:sincro_app_flutter/common/utils/string_sanitizer.dart';
import 'package:sincro_app_flutter/models/user_model.dart';
import 'package:sincro_app_flutter/models/subscription_model.dart';
import 'package:sincro_app_flutter/features/tasks/models/task_model.dart';
import 'package:sincro_app_flutter/features/journal/models/journal_entry_model.dart';
import 'package:sincro_app_flutter/features/goals/models/goal_model.dart'; // Mantido como Goal
import 'package:sincro_app_flutter/features/tasks/utils/task_parser.dart';
import 'package:flutter/material.dart'; // Para TimeOfDay
import 'package:sincro_app_flutter/features/assistant/models/assistant_models.dart';

// --- INÍCIO DA NOVA IMPORTAÇÃO ---
import 'package:sincro_app_flutter/services/notification_service.dart';
// --- FIM DA NOVA IMPORTAÇÃO ---

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  // --- INÍCIO DA NOVA INSTÂNCIA ---
  // Obtém a instância do nosso serviço singleton
  final NotificationService _notificationService = NotificationService.instance;
  // --- FIM DA NOVA INSTÂNCIA ---

  // Getter público para acessar a instância do Firestore
  FirebaseFirestore get db => _db;

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
        'isAdmin': user.isAdmin,
        'dashboardCardOrder': user.dashboardCardOrder,
        'dashboardHiddenCards': user.dashboardHiddenCards,
        'subscription': user.subscription.toFirestore(),
        // Remove o campo legado 'plano' para evitar duplicidade de fonte
        'plano': FieldValue.delete(),
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
    debugPrint('[FirestoreService] ========== getUserData INICIADO ==========');
    debugPrint('[FirestoreService] uid solicitado: $uid');

    try {
      debugPrint('[FirestoreService] Buscando documento users/$uid...');
      DocumentSnapshot doc = await _db.collection('users').doc(uid).get();

      debugPrint('[FirestoreService] Documento existe: ${doc.exists}');

      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        debugPrint('[FirestoreService] Dados brutos: ${data.keys.toList()}');
        debugPrint(
            '[FirestoreService] nomeAnalise: "${data['nomeAnalise'] ?? 'VAZIO'}"');
        debugPrint(
            '[FirestoreService] dataNasc: "${data['dataNasc'] ?? 'VAZIO'}"');

        // Tratamento robusto para lista (caso null ou tipo errado)
        List<String> cardOrder = UserModel.defaultCardOrder;
        if (data['dashboardCardOrder'] is List) {
          try {
            cardOrder = List<String>.from(data['dashboardCardOrder']);
          } catch (e) {
            debugPrint(
              "Erro ao converter dashboardCardOrder: $e. Usando padrão.",
            );
          }
        }
        // Lê lista de cartões ocultos
        List<String> hiddenCards = <String>[];
        if (data['dashboardHiddenCards'] is List) {
          try {
            hiddenCards = List<String>.from(data['dashboardHiddenCards']);
          } catch (e) {
            debugPrint(
              "Erro ao converter dashboardHiddenCards: $e. Usando lista vazia.",
            );
          }
        }

        // Lê dados de subscription
        SubscriptionModel subscription;
        if (data['subscription'] != null && data['subscription'] is Map) {
          subscription = SubscriptionModel.fromFirestore(
            Map<String, dynamic>.from(data['subscription']),
          );
        } else {
          // Cria subscription free padrão para usuários antigos
          subscription = SubscriptionModel.free();
        }

        // Determina string legada do plano apenas para compatibilidade com telas antigas
        String legacyPlano;
        if (data.containsKey('plano') && data['plano'] is String) {
          legacyPlano = data['plano'];
        } else {
          switch (subscription.plan) {
            case SubscriptionPlan.free:
              legacyPlano = 'essencial';
              break;
            case SubscriptionPlan.plus:
              legacyPlano = 'desperta';
              break;
            case SubscriptionPlan.premium:
              legacyPlano = 'sinergia';
              break;
          }
        }

        final userModel = UserModel(
          uid: doc.id,
          email: data['email'] ?? '',
          photoUrl: data['photoUrl'] as String?,
          primeiroNome: data['primeiroNome'] ?? '',
          sobrenome: data['sobrenome'] ?? '',
          nomeAnalise: data['nomeAnalise'] ?? '',
          dataNasc: data['dataNasc'] ?? '',
          plano: legacyPlano,
          isAdmin: data['isAdmin'] ?? false,
          dashboardCardOrder: cardOrder,
          dashboardHiddenCards: hiddenCards,
          subscription: subscription,
        );

        debugPrint('[FirestoreService] UserModel criado com sucesso');
        debugPrint('[FirestoreService] - uid: ${userModel.uid}');
        debugPrint('[FirestoreService] - email: ${userModel.email}');
        debugPrint(
            '[FirestoreService] - nomeAnalise: "${userModel.nomeAnalise}"');
        debugPrint(
            '[FirestoreService] ==================================================');

        return userModel;
      }
      debugPrint('[FirestoreService] Documento não existe -> retornando null');
      debugPrint(
          '[FirestoreService] ==================================================');
      return null;
    } catch (e) {
      debugPrint("[FirestoreService] ❌ ERRO ao buscar dados do usuário: $e");
      debugPrint(
          '[FirestoreService] ==================================================');
      return null;
    }
  }

  Future<void> updateUserDashboardOrder(String uid, List<String> order) async {
    try {
      await _db.collection('users').doc(uid).update({
        'dashboardCardOrder': order,
      });
    } catch (e) {
      debugPrint("Erro ao atualizar a ordem dos cards: $e");
      rethrow;
    }
  }

  Future<void> updateUserDashboardHiddenCards(
      String uid, List<String> hidden) async {
    try {
      await _db.collection('users').doc(uid).update({
        'dashboardHiddenCards': hidden,
      });
    } catch (e) {
      debugPrint("Erro ao atualizar cartões ocultos: $e");
      rethrow;
    }
  }

  // --- MÉTODOS DE TAREFAS (Seu código original, mantido) ---
  Future<List<TaskModel>> getRecentTasks(
    String userId, {
    int limit = 20,
  }) async {
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

      final results = await Future.wait([
        queryDueDate.get(),
        queryCreatedAt.get(),
      ]);
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
        ..sort(
          (a, b) =>
              (a.dueDate ?? a.createdAt).compareTo(b.dueDate ?? b.createdAt),
        );
      return sortedTasks;
    } catch (e, stackTrace) {
      debugPrint("Erro ao buscar tarefas de hoje (Future): $e\n$stackTrace");
      return [];
    }
  }

  Future<List<TaskModel>> getTasksForCalendar(
    String userId,
    DateTime month,
  ) async {
    final startOfMonth = DateTime.utc(month.year, month.month, 1);
    final endOfMonth = DateTime.utc(month.year, month.month + 1, 1);
    final tasksRef = _db.collection('users').doc(userId).collection('tasks');

    final queryDueDate = tasksRef
        .where(
          'dueDate',
          isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth),
        )
        .where('dueDate', isLessThan: Timestamp.fromDate(endOfMonth));
    final queryCreatedAt = tasksRef
        .where('dueDate', isEqualTo: null)
        .where(
          'createdAt',
          isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth),
        )
        .where('createdAt', isLessThan: Timestamp.fromDate(endOfMonth));

    try {
      final results = await Future.wait([
        queryDueDate.get(),
        queryCreatedAt.get(),
      ]);
      final dueDateDocs = results[0].docs;
      final createdAtDocs = results[1].docs;
      final tasksMap = <String, TaskModel>{};
      for (var doc in dueDateDocs) {
        try {
          tasksMap[doc.id] = TaskModel.fromFirestore(doc);
        } catch (e) {
          debugPrint(
            "Erro ao converter tarefa (dueDate query - Cal) ID ${doc.id}: $e",
          );
        }
      }
      for (var doc in createdAtDocs) {
        if (!tasksMap.containsKey(doc.id)) {
          try {
            tasksMap[doc.id] = TaskModel.fromFirestore(doc);
          } catch (e) {
            debugPrint(
              "Erro ao converter tarefa (createdAt query - Cal) ID ${doc.id}: $e",
            );
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

  Stream<List<TaskModel>> getTasksStreamForRange(
      String userId, DateTime start, DateTime end) {
    final startTimestamp = Timestamp.fromDate(start);
    final endTimestamp = Timestamp.fromDate(end);

    return _db
        .collection('users')
        .doc(userId)
        .collection('tasks')
        .where('dueDate', isGreaterThanOrEqualTo: startTimestamp)
        .where('dueDate', isLessThan: endTimestamp)
        .snapshots()
        .map((snapshot) {
      try {
        return snapshot.docs
            .map((doc) => TaskModel.fromFirestore(doc))
            .toList();
      } catch (e, st) {
        debugPrint("Parse Error in Tasks Stream Range: $e\n$st");
        return <TaskModel>[];
      }
    }).handleError((error, stackTrace) {
      debugPrint("Erro no stream de Tasks Range: $error\n$stackTrace");
      return <TaskModel>[];
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
        debugPrint(
          "Parse Error in Tasks Goal Stream (Goal $goalId): $e\n$st",
        );
        return <TaskModel>[];
      }
    }).handleError((error, stackTrace) {
      debugPrint(
        "Erro no stream de Tasks para Goal $goalId: $error\n$stackTrace",
      );
      return <TaskModel>[];
    });
  }

  Future<void> addTask(String userId, TaskModel task) async {
    try {
      final docRef = await _db
          .collection('users')
          .doc(userId)
          .collection('tasks')
          .add(task.toFirestore());

      // Atualiza o documento com seu próprio ID
      await docRef.update({'id': docRef.id});

      // --- INÍCIO DA MUDANÇA (FEATURE #3) ---
      // Agenda a notificação se necessário (com tratamento de erro)
      try {
        final taskWithId = task.copyWith(id: docRef.id);
        await _notificationService.scheduleTaskReminder(taskWithId);
      } catch (e) {
        debugPrint("Erro ao agendar notificação (não bloqueante): $e");
      }
      // --- FIM DA MUDANÇA ---
    } catch (e) {
      debugPrint("Erro ao adicionar tarefa no Firestore: $e");
      rethrow;
    }
  }

  Future<void> updateTask(String userId, TaskModel task) async {
    try {
      await _db
          .collection('users')
          .doc(userId)
          .collection('tasks')
          .doc(task.id)
          .update(task.toFirestore());

      // --- INÍCIO DA MUDANÇA (FEATURE #3) ---
      // Reagenda a notificação (o método cuida de cancelar/atualizar)
      try {
        await _notificationService.scheduleTaskReminder(task);
      } catch (e) {
        debugPrint("Erro ao atualizar notificação (não bloqueante): $e");
      }
      // --- FIM DA MUDANÇA ---
    } catch (e) {
      debugPrint("Erro ao atualizar tarefa completa ID ${task.id}: $e");
      rethrow;
    }
  }

  Future<void> updateTaskFields(
    String userId,
    String taskId,
    Map<String, dynamic> updates,
  ) async {
    try {
      final Map<String, dynamic> finalUpdates = Map.from(updates);

      if (finalUpdates.containsKey('createdAt') &&
          finalUpdates['createdAt'] is DateTime) {
        finalUpdates['createdAt'] = Timestamp.fromDate(
          (finalUpdates['createdAt'] as DateTime).toUtc(),
        );
      }
      if (finalUpdates.containsKey('dueDate')) {
        if (finalUpdates['dueDate'] is DateTime) {
          // Garante que só a data (sem hora) em UTC seja salva
          final localDate = (finalUpdates['dueDate'] as DateTime).toLocal();
          final dateOnlyUtc = DateTime.utc(
            localDate.year,
            localDate.month,
            localDate.day,
          );
          finalUpdates['dueDate'] = Timestamp.fromDate(dateOnlyUtc);
        } else {
          finalUpdates['dueDate'] = null; // Garante null se não for DateTime
        }
      }
      if (finalUpdates.containsKey('recurrenceEndDate')) {
        if (finalUpdates['recurrenceEndDate'] is DateTime) {
          finalUpdates['recurrenceEndDate'] = Timestamp.fromDate(
            (finalUpdates['recurrenceEndDate'] as DateTime).toUtc(),
          );
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

      // --- INÍCIO DA MUDANÇA (FEATURE #3) ---
      // Se estamos atualizando campos, precisamos re-sincronizar o lembrete.
      try {
        final doc = await _db
            .collection('users')
            .doc(userId)
            .collection('tasks')
            .doc(taskId)
            .get();
        if (doc.exists) {
          final updatedTask = TaskModel.fromFirestore(doc);
          await _notificationService.scheduleTaskReminder(updatedTask);
        }
      } catch (e) {
        debugPrint("Erro ao atualizar notificação por campos (não bloqueante): $e");
      }
      // --- FIM DA MUDANÇA ---
    } catch (e) {
      debugPrint("Erro ao atualizar campos da tarefa ID $taskId: $e");
      rethrow;
    }
  }

  Future<void> updateTaskCompletion(
    String userId,
    String taskId, {
    required bool completed,
  }) async {
    try {
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

      // --- INÍCIO DA MUDANÇA (FEATURE #3) ---
      try {
        // Se a tarefa for marcada como concluída, cancela o lembrete
        if (completed) {
          await _notificationService.cancelTaskReminderByTaskId(taskId);
        }
        // Se for "desmarcada", o lembrete precisa ser reagendado
        else {
          final doc = await _db
              .collection('users')
              .doc(userId)
              .collection('tasks')
              .doc(taskId)
              .get();
          if (doc.exists) {
            final updatedTask = TaskModel.fromFirestore(doc);
            await _notificationService.scheduleTaskReminder(updatedTask);
          }
        }
      } catch (e) {
        debugPrint("Erro ao atualizar notificação por status (não bloqueante): $e");
      }
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

      // --- INÍCIO DA MUDANÇA (FEATURE #3) ---
      // Cancela qualquer lembrete associado
      try {
        await _notificationService.cancelTaskReminderByTaskId(taskId);
      } catch (e) {
        debugPrint("Erro ao cancelar notificação na deleção (não bloqueante): $e");
      }
      // --- FIM DA MUDANÇA ---
    } catch (e) {
      debugPrint("Erro ao deletar tarefa ID $taskId: $e");
      rethrow;
    }
  }

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

          // --- INÍCIO DA MUDANÇA (FEATURE #3) ---
          // Dispara o cancelamento. Não usamos 'await' dentro do loop
          // para não atrasar o batch.
          _notificationService.cancelTaskReminderByTaskId(taskId);
          // --- FIM DA MUDANÇA ---
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
          .where(
            'createdAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDayUtc),
          )
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
            "Erro ao converter Journal Entry ID ${doc.id}: $e\n$stackTrace",
          );
        }
      }
      return entries;
    }).handleError((error, stackTrace) {
      debugPrint(
        "Erro geral no stream de Journal Entries: $error\n$stackTrace",
      );
      return <JournalEntry>[];
    });
  }

  Future<List<JournalEntry>> getJournalEntriesForMonth(
    String userId,
    DateTime month,
  ) async {
    try {
      final startOfMonth = DateTime.utc(month.year, month.month, 1);
      final endOfMonth = DateTime.utc(month.year, month.month + 1, 1);
      final querySnapshot = await _db
          .collection('users')
          .doc(userId)
          .collection('journalEntries')
          .where(
            'createdAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth),
          )
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
            "Erro ao converter Journal Entry (Month) ID ${doc.id}: $e",
          );
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
        finalData['createdAt'] = Timestamp.fromDate(
          (finalData['createdAt'] as DateTime).toUtc(),
        );
      } else {
        finalData['createdAt'] = Timestamp.now();
      }
      // Garante int ou null
      finalData['personalDay'] = int.tryParse(
        finalData['personalDay']?.toString() ?? '',
      );
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
    String userId,
    String entryId,
    Map<String, dynamic> data,
  ) async {
    try {
      final Map<String, dynamic> finalUpdates = Map.from(data);
      // Garante Timestamp UTC se presente
      if (finalUpdates.containsKey('createdAt') &&
          finalUpdates['createdAt'] is DateTime) {
        finalUpdates['createdAt'] = Timestamp.fromDate(
          (finalUpdates['createdAt'] as DateTime).toUtc(),
        );
      }
      // Garante int ou null se presentes
      if (finalUpdates.containsKey('personalDay')) {
        finalUpdates['personalDay'] = int.tryParse(
          finalUpdates['personalDay']?.toString() ?? '',
        );
      }
      if (finalUpdates.containsKey('mood')) {
        finalUpdates['mood'] = int.tryParse(
          finalUpdates['mood']?.toString() ?? '',
        );
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
        data['createdAt'] = Timestamp.fromDate(
          (data['createdAt'] as DateTime).toUtc(),
        );
      }

      // Corrigido: aceita tanto DateTime quanto Timestamp
      if (data.containsKey('targetDate')) {
        if (data['targetDate'] is DateTime) {
          data['targetDate'] = Timestamp.fromDate(
            (data['targetDate'] as DateTime).toUtc(),
          );
        } else if (data['targetDate'] is! Timestamp) {
          // Só define como null se não for DateTime nem Timestamp
          data['targetDate'] = null;
        }
        // Se já for Timestamp, mantém como está
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
          .orderBy('createdAt', descending: true)
          .get();

      return querySnapshot.docs.map((doc) => Goal.fromFirestore(doc)).toList();
    } catch (e) {
      debugPrint("Erro ao buscar metas ativas: $e");
      return [];
    }
  }



  // --- MÉTODOS DE CONFIGURAÇÃO DO SITE (ADMIN) ---

  /// Obtém o stream das configurações do site (status, senha, etc)
  Stream<Map<String, dynamic>> getSiteSettingsStream() {
    return _db
        .collection('config')
        .doc('site_settings')
        .snapshots()
        .map((snapshot) {
      if (snapshot.exists && snapshot.data() != null) {
        return snapshot.data()!;
      }
      return {
        'status': 'active', // active, maintenance, construction
        'bypassPassword': '',
      };
    });
  }

  /// Atualiza as configurações do site
  Future<void> updateSiteSettings({
    required String status,
    required String bypassPassword,
  }) async {
    try {
      await _db.collection('config').doc('site_settings').set({
        'status': status,
        'bypassPassword': bypassPassword,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint("Erro ao atualizar configurações do site: $e");
      rethrow;
    }
  }

  Future<DocumentReference> addGoal(
    String userId,
    Map<String, dynamic> data,
  ) async {
    // Seu método original já está aqui e parece correto
    try {
      final Map<String, dynamic> finalData = Map.from(data);
      if (finalData['createdAt'] is DateTime) {
        finalData['createdAt'] = Timestamp.fromDate(
          (finalData['createdAt'] as DateTime).toUtc(),
        );
      } else if (finalData['createdAt'] is! Timestamp) {
        finalData['createdAt'] = Timestamp.now();
      }

      // Corrigido: aceita tanto DateTime quanto Timestamp
      if (finalData['targetDate'] is DateTime) {
        finalData['targetDate'] = Timestamp.fromDate(
          (finalData['targetDate'] as DateTime).toUtc(),
        );
      } else if (finalData['targetDate'] is! Timestamp) {
        // Só define como null se não for DateTime nem Timestamp
        finalData['targetDate'] = null;
      }
      // Se já for Timestamp, mantém como está

      finalData['progress'] = finalData['progress'] ?? 0;
      finalData['subTasks'] = finalData['subTasks'] ?? [];
      finalData['userId'] = userId; // Garante userId
      // Garante sanitizedTitle
      if (!finalData.containsKey('sanitizedTitle') &&
          finalData.containsKey('title') &&
          finalData['title'] is String) {
        finalData['sanitizedTitle'] = StringSanitizer.toSimpleTag(
          finalData['title'],
        );
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
        "Erro ao atualizar progresso da meta $goalId: $e\n$stackTrace",
      );
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
    String sanitizedTitle,
  ) async {
    // Seu método original já está aqui e parece correto
    // Apenas adicionado toLowerCase para garantir case-insensitivity
    final lowerSanitizedTitle = sanitizedTitle.toLowerCase();
    try {
      // Query mais eficiente usando where e limit(1)
      final querySnapshot = await _db
          .collection('users')
          .doc(userId)
          .collection('goals')
          .where(
            'sanitizedTitle',
            isEqualTo: lowerSanitizedTitle,
          ) // Assume que 'sanitizedTitle' está salvo em minúsculas
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        try {
          return Goal.fromFirestore(
            querySnapshot.docs.first,
          ); // <-- Mantido Goal
        } catch (e) {
          debugPrint(
            "Parse Error Goal (sanitized title) ID ${querySnapshot.docs.first.id}: $e",
          );
          return null;
        }
      }
      return null; // Nenhum encontrado
    } catch (e) {
      debugPrint(
        "Erro ao buscar meta pelo título simplificado '$lowerSanitizedTitle': $e",
      );
      return null;
    }
  }

  // --- MÉTODOS DE STREAM PARA O CALENDÁRIO (Seu código original, mantido) ---
  Stream<List<TaskModel>> getTasksDueDateStreamForMonth(
    String userId,
    DateTime month,
  ) {
    final startOfMonth = DateTime.utc(month.year, month.month, 1);
    final endOfMonth = DateTime.utc(month.year, month.month + 1, 1);
    final query = _db
        .collection('users')
        .doc(userId)
        .collection('tasks')
        .where(
          'dueDate',
          isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth),
        )
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
        "Erro no stream de tasks (dueDate - Calendar): $error\n$stackTrace",
      );
      return <TaskModel>[];
    });
  }

  Stream<List<TaskModel>> getTasksCreatedAtStreamForMonth(
    String userId,
    DateTime month,
  ) {
    final startOfMonth = DateTime.utc(month.year, month.month, 1);
    final endOfMonth = DateTime.utc(month.year, month.month + 1, 1);
    final query = _db
        .collection('users')
        .doc(userId)
        .collection('tasks')
        .where('dueDate', isEqualTo: null)
        .where(
          'createdAt',
          isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth),
        )
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
        "Erro no stream de tasks (createdAt - Calendar): $error\n$stackTrace",
      );
      return <TaskModel>[];
    });
  }

  Stream<List<JournalEntry>> getJournalEntriesStreamForMonth(
    String userId,
    DateTime month,
  ) {
    final startOfMonth = DateTime.utc(month.year, month.month, 1);
    final endOfMonth = DateTime.utc(month.year, month.month + 1, 1);
    final query = _db
        .collection('users')
        .doc(userId)
        .collection('journalEntries')
        .where(
          'createdAt',
          isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth),
        )
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
        "Erro no stream de Journal Entries (Calendar): $error\n$stackTrace",
      );
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
        "Erro no stream de tasks (dueDate - Today): $error\n$stackTrace",
      );
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
        "Erro no stream de tasks (createdAt - Today): $error\n$stackTrace",
      );
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
          ..sort(
            (a, b) => (a.dueDate ?? a.createdAt).toUtc().compareTo(
                  (b.dueDate ?? b.createdAt).toUtc(),
                ),
          );
        return combinedList;
      },
    );
  }

  // --- FUNÇÃO getTasksForFocusDay (Seu código original, mantido) ---
  Future<List<TaskModel>> getTasksForFocusDay(
    String userId,
    DateTime day,
  ) async {
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
              "Parse Error Task (createdAt - Focus Day) ID ${doc.id}: $e",
            );
          }
        }
      }
      final sortedTasks = tasksMap.values.toList()
        ..sort(
          (a, b) => (a.dueDate ?? a.createdAt).toUtc().compareTo(
                (b.dueDate ?? b.createdAt).toUtc(),
              ),
        );
      return sortedTasks;
    } catch (e, stackTrace) {
      debugPrint("Erro ao buscar tarefas para o Foco do Dia: $e\n$stackTrace");
      return [];
    }
  }

  // --- Trecho Corrigido do Método createGoal ---
  Future<Goal> createGoal(String userId, String title) async {
    try {
      final newGoal = Goal(
        id: '', // Será gerado pelo addGoal/Firestore
        userId: userId,
        title: title, // Título original
        createdAt: DateTime.now().toUtc(),
        description: '', // Demais campos padrão do seu Model
        progress: 0,
        subTasks: const [],
      );

      final docRef = await addGoal(
        userId,
        newGoal.toFirestore(),
      ); // Assume que Goal tem toFirestore()

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

      final List<String> tags = [];
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
      final tagId = StringSanitizer.toSimpleTag(
        tagName,
      ); // Usa nome sanitizado como ID

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
  // --- MÉTODO addRecurringTasks (MODIFICADO) ---
  // ---
  Future<void> addRecurringTasks(
    String userId,
    ParsedTask baseParsedTask,
    List<DateTime> dates,
    String recurrenceId,
  ) async {
    final batch = _db.batch();
    final tasksCollection =
        _db.collection('users').doc(userId).collection('tasks');

    // --- NOVA LISTA ---
    final List<TaskModel> tasksToSchedule = [];

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
        recurrenceDaysOfWeek: baseParsedTask.recurrenceRule.daysOfWeek,
        recurrenceEndDate: baseParsedTask.recurrenceRule.endDate?.toUtc(),
        recurrenceId: recurrenceId, // ID que agrupa todas as instâncias
      );

      // Adiciona a operação de criação ao batch
      final docRef = tasksCollection.doc();
      batch.set(docRef, task.toFirestore());

      // Adiciona uma operação de update para salvar o ID no próprio documento
      batch.update(docRef, {'id': docRef.id});

      // --- INÍCIO DA MUDANÇA (FEATURE #3) ---
      // Adiciona à lista para agendamento pós-commit
      tasksToSchedule.add(task.copyWith(id: docRef.id));
      // --- FIM DA MUDANÇA ---
    }

    // Executa o batch
    try {
      await batch.commit();

      // --- INÍCIO DA MUDANÇA (FEATURE #3) ---
      // Agora, agenda as notificações para as tarefas recém-criadas
      for (final task in tasksToSchedule) {
        // Não precisa de await no loop, pode disparar em paralelo
        _notificationService.scheduleTaskReminder(task);
      }
      debugPrint(
        "✅ Tarefas recorrentes salvas e ${tasksToSchedule.length} lembretes agendados.",
      );
      // --- FIM DA MUDANÇA ---
    } catch (e) {
      debugPrint("Erro ao salvar tarefas recorrentes em lote: $e");
      throw Exception('Não foi possível salvar as tarefas recorrentes.');
    }
  }

  // --- FIM DO MÉTODO addRecurringTasks ---

  // ========================================================================
  // === MÉTODOS ADMIN ===
  // ========================================================================

  /// Obtém todos os usuários (apenas admin)
  Future<List<UserModel>> getAllUsers() async {
    try {
      final querySnapshot = await _db.collection('users').get();
      return querySnapshot.docs
          .map((doc) => UserModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint("Erro ao buscar todos os usuários: $e");
      rethrow;
    }
  }

  /// Obtém usuários com paginação
  Future<List<UserModel>> getUsersPaginated({
    int limit = 50,
    DocumentSnapshot? startAfter,
  }) async {
    try {
      Query query = _db.collection('users').limit(limit);

      if (startAfter != null) {
        query = query.startAfterDocument(startAfter);
      }

      final querySnapshot = await query.get();
      return querySnapshot.docs
          .map((doc) => UserModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint("Erro ao buscar usuários paginados: $e");
      rethrow;
    }
  }

  /// Busca usuários por email ou nome
  Future<List<UserModel>> searchUsers(String searchTerm) async {
    try {
      if (searchTerm.isEmpty) return [];

      final searchLower = searchTerm.toLowerCase();

      // Busca por email
      final emailQuery = await _db
          .collection('users')
          .where('email', isGreaterThanOrEqualTo: searchLower)
          .where('email', isLessThan: '${searchLower}z')
          .limit(20)
          .get();

      // Busca por primeiro nome
      final nameQuery = await _db
          .collection('users')
          .where('primeiroNome', isGreaterThanOrEqualTo: searchLower)
          .where('primeiroNome', isLessThan: '${searchLower}z')
          .limit(20)
          .get();

      final users = <UserModel>{};
      users.addAll(emailQuery.docs.map((doc) => UserModel.fromFirestore(doc)));
      users.addAll(nameQuery.docs.map((doc) => UserModel.fromFirestore(doc)));

      return users.toList();
    } catch (e) {
      debugPrint("Erro ao buscar usuários: $e");
      rethrow;
    }
  }

  /// Atualiza a assinatura de um usuário (admin)
  Future<void> updateUserSubscription(
    String uid,
    Map<String, dynamic> subscriptionData,
  ) async {
    try {
      await _db.collection('users').doc(uid).update({
        'subscription': subscriptionData,
        // Remove campo legado para eliminar duplicidade
        'plano': FieldValue.delete(),
      });
    } catch (e) {
      debugPrint("Erro ao atualizar assinatura: $e");
      rethrow;
    }
  }

  /// Deleta um usuário e todos seus dados (GDPR compliance)
  Future<void> deleteUserData(String uid) async {
    try {
      final batch = _db.batch();

      // Deleta tarefas
      final tasksSnapshot =
          await _db.collection('users').doc(uid).collection('tasks').get();
      for (var doc in tasksSnapshot.docs) {
        batch.delete(doc.reference);
      }

      // Deleta metas
      final goalsSnapshot =
          await _db.collection('users').doc(uid).collection('goals').get();
      for (var doc in goalsSnapshot.docs) {
        batch.delete(doc.reference);
      }

      // Deleta journal
      final journalSnapshot = await _db
          .collection('users')
          .doc(uid)
          .collection('journalEntries')
          .get();
      for (var doc in journalSnapshot.docs) {
        batch.delete(doc.reference);
      }

      // Deleta tags
      final tagsSnapshot =
          await _db.collection('users').doc(uid).collection('tags').get();
      for (var doc in tagsSnapshot.docs) {
        batch.delete(doc.reference);
      }

      // Deleta o usuário por último
      batch.delete(_db.collection('users').doc(uid));

      await batch.commit();
    } catch (e) {
      debugPrint("Erro ao deletar usuário: $e");
      rethrow;
    }
  }

  /// Obtém estatísticas gerais para o admin
  Future<Map<String, dynamic>> getAdminStats() async {
    try {
      final usersSnapshot = await _db.collection('users').get();
      final users = usersSnapshot.docs
          .map((doc) => UserModel.fromFirestore(doc))
          .toList();

      int freeCount = 0;
      int plusCount = 0;
      int premiumCount = 0;
      int activeCount = 0;
      int expiredCount = 0;
      double mrr = 0.0;

      for (final user in users) {
        switch (user.subscription.plan.name) {
          case 'free':
            freeCount++;
            break;
          case 'plus':
            plusCount++;
            if (user.subscription.isActive) {
              mrr += 19.90; // Preço do plano plus
            }
            break;
          case 'premium':
            premiumCount++;
            if (user.subscription.isActive) {
              mrr += 39.90; // Preço do plano premium
            }
            break;
        }

        if (user.subscription.isActive) {
          activeCount++;
        } else {
          expiredCount++;
        }
      }

      return {
        'totalUsers': users.length,
        'freeUsers': freeCount,
        'plusUsers': plusCount,
        'premiumUsers': premiumCount,
        'activeSubscriptions': activeCount,
        'expiredSubscriptions': expiredCount,
        'estimatedMRR': mrr,
        'lastUpdated': DateTime.now().toUtc(),
      };
    } catch (e) {
      debugPrint("Erro ao obter estatísticas admin: $e");
      rethrow;
    }
  }

  /// Stream de estatísticas em tempo real (opcional)
  Stream<Map<String, dynamic>> getAdminStatsStream() {
    return _db.collection('users').snapshots().map((snapshot) {
      final users =
          snapshot.docs.map((doc) => UserModel.fromFirestore(doc)).toList();

      int freeCount = 0;
      int plusCount = 0;
      int premiumCount = 0;
      int activeCount = 0;
      int expiredCount = 0;
      double mrr = 0.0;
      
      // Contadores por fonte de receita (para usuários PAGANTES)
      int stripeCount = 0;
      int playStoreCount = 0;
      int appStoreCount = 0;

      for (final user in users) {
        final plan = user.subscription.plan;
        switch (plan) {
          case SubscriptionPlan.free:
            freeCount++;
            break;
          case SubscriptionPlan.plus:
            plusCount++;
            if (user.subscription.isActive) mrr += 19.90;
            break;
          case SubscriptionPlan.premium:
            premiumCount++;
            if (user.subscription.isActive) mrr += 39.90;
            break;
        }

        if (user.subscription.isActive) {
          activeCount++;
          
          // Se é pagante, tenta identificar a fonte
          if (plan != SubscriptionPlan.free) {
            if (user.subscription.stripeId != null) {
              stripeCount++;
            } else {
              // Se não tem stripeId mas é pagante, assumimos loja (Play Store/App Store)
              // Como não temos o campo 'provider' ainda, vamos estimar ou usar um padrão.
              // Por enquanto, vamos agrupar em 'playStore' como genérico para "Lojas"
              // ou dividir 50/50 se quiser simular.
              // O ideal é ter o campo provider no SubscriptionModel.
              playStoreCount++; 
            }
          }
        } else {
          expiredCount++;
        }
      }

      return {
        'totalUsers': users.length,
        'freeUsers': freeCount,
        'plusUsers': plusCount,
        'premiumUsers': premiumCount,
        'activeSubscriptions': activeCount,
        'expiredSubscriptions': expiredCount,
        'estimatedMRR': mrr,
        'stripeSubscribers': stripeCount,
        'storeSubscribers': playStoreCount + appStoreCount, // Agrupado por enquanto
        'lastUpdated': DateTime.now().toUtc(),
      };
    });
  }

  /// Obtém configurações financeiras do admin
  Stream<Map<String, dynamic>> getAdminFinancialSettingsStream() {
    return _db
        .collection('admin_settings')
        .doc('financial')
        .snapshots()
        .map((doc) {
      if (!doc.exists) {
        // Retorna valores padrão se não existir
        return {
          'stripeFeePercent': 3.99,
          'stripeFixedFee': 0.39,
          'storeFeePercent': 15.0, // Média Play/App Store (15% small business)
          'aiCostPerUser': 0.50, // Custo médio IA
          'cacPerUser': 5.00, // Custo aquisição
          'fixedCosts': 100.00, // Custos fixos servidor/firebase
          'taxRate': 6.0, // Impostos (Simples Nacional aprox)
        };
      }
      return doc.data() as Map<String, dynamic>;
    });
  }

  /// Atualiza configurações financeiras
  Future<void> updateAdminFinancialSettings(Map<String, dynamic> data) async {
    try {
      await _db
          .collection('admin_settings')
          .doc('financial')
          .set(data, SetOptions(merge: true));
    } catch (e) {
      debugPrint("Erro ao atualizar configurações financeiras: $e");
      rethrow;
    }
  }

  // ========================================================================
  // === ASSISTANT MESSAGES (Persistência de histórico de conversa) ===
  // ========================================================================

  /// Adiciona uma mensagem do assistente/usuário em users/{uid}/assistantMessages
  Future<void> addAssistantMessage(
    String userId,
    AssistantMessage message,
  ) async {
    try {
      final actions = message.actions
          .map((a) => {
                'type': a.type.name, // schedule | create_goal | create_task
                'title': a.title,
                'description': a.description,
                'date': a.date != null
                    ? Timestamp.fromDate(
                        DateTime.utc(a.date!.year, a.date!.month, a.date!.day),
                      )
                    : null,
                'startDate': a.startDate != null
                    ? Timestamp.fromDate(
                        DateTime.utc(a.startDate!.year, a.startDate!.month,
                            a.startDate!.day),
                      )
                    : null,
                'endDate': a.endDate != null
                    ? Timestamp.fromDate(
                        DateTime.utc(
                            a.endDate!.year, a.endDate!.month, a.endDate!.day),
                      )
                    : null,
                'subtasks': a.subtasks,
              })
          .toList();

      await _db
          .collection('users')
          .doc(userId)
          .collection('assistantMessages')
          .add({
        'role': message.role,
        'content': message.content,
        'time': Timestamp.fromDate(message.time.toUtc()),
        'actions': actions,
      });
    } catch (e) {
      debugPrint('Erro ao salvar mensagem do assistente: $e');
    }
  }

  /// Busca as últimas [limit] mensagens do assistente/usuário
  Future<List<AssistantMessage>> getRecentAssistantMessages(
    String userId, {
    int limit = 30,
  }) async {
    try {
      final snapshot = await _db
          .collection('users')
          .doc(userId)
          .collection('assistantMessages')
          .orderBy('time', descending: false)
          .limit(limit)
          .get();
      final list = <AssistantMessage>[];
      for (final doc in snapshot.docs) {
        try {
          final data = doc.data();
          final actionsData = (data['actions'] is List)
              ? List<Map<String, dynamic>>.from(
                  (data['actions'] as List)
                      .map((e) => Map<String, dynamic>.from(e as Map)),
                )
              : const <Map<String, dynamic>>[];

          // Converte Timestamp -> YYYY-MM-DD string para reuso no fromJson
          List<Map<String, dynamic>> normalizedActions = actionsData.map((a) {
            String? dateStr;
            String? startDateStr;
            String? endDateStr;
            if (a['date'] is Timestamp) {
              final d = (a['date'] as Timestamp).toDate();
              dateStr =
                  '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
            }
            if (a['startDate'] is Timestamp) {
              final d = (a['startDate'] as Timestamp).toDate();
              startDateStr =
                  '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
            }
            if (a['endDate'] is Timestamp) {
              final d = (a['endDate'] as Timestamp).toDate();
              endDateStr =
                  '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
            }
            return {
              'type': a['type'],
              'title': a['title'],
              'description': a['description'],
              'date': dateStr,
              'startDate': startDateStr,
              'endDate': endDateStr,
              'subtasks': a['subtasks'],
            };
          }).toList();

          final message = AssistantMessage(
            role: (data['role'] ?? '').toString(),
            content: (data['content'] ?? '').toString(),
            time: (data['time'] as Timestamp?)?.toDate() ?? DateTime.now(),
            actions: normalizedActions
                .map((a) => AssistantAction.fromJson(a))
                .toList(),
          );
          list.add(message);
        } catch (e) {
          debugPrint('Erro ao converter assistantMessage ${doc.id}: $e');
        }
      }
      return list;
    } catch (e) {
      debugPrint('Erro ao buscar histórico do assistente: $e');
      return [];
    }
  }
} // Fim da classe FirestoreService
