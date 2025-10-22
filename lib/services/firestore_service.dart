// lib/services/firestore_service.dart
// (Arquivo existente, código completo 100% atualizado)

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:rxdart/rxdart.dart';
import 'package:sincro_app_flutter/common/utils/string_sanitizer.dart';
// ATUALIZADO: Importa UserModel do local correto
import 'package:sincro_app_flutter/models/user_model.dart';
import 'package:sincro_app_flutter/features/tasks/models/task_model.dart';
import 'package:sincro_app_flutter/features/journal/models/journal_entry_model.dart';
// ATUALIZADO: Importa Goal do local correto
import 'package:sincro_app_flutter/features/goals/models/goal_model.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // --- MÉTODOS DE USUÁRIO (sem alterações) ---
  Future<void> saveUserData(UserModel user) async {
    try {
      // --- CORREÇÃO no UserModel ---
      // Seu UserModel não tem um método toFirestore(). Vamos criar um mapa manualmente.
      // Ou, idealmente, adicione `toFirestore()` ao seu UserModel.
      // Por agora, faremos manualmente:
      await _db.collection('users').doc(user.uid).set({
        'email': user.email,
        'photoUrl': user.photoUrl,
        'primeiroNome': user.primeiroNome,
        'sobrenome': user.sobrenome,
        'nomeAnalise': user.nomeAnalise,
        'dataNasc': user.dataNasc, // Assumindo que é String 'dd/MM/yyyy'
        'plano': user.plano,
        'isAdmin': user.isAdmin,
        'dashboardCardOrder': user.dashboardCardOrder,
      });
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
        // --- CORREÇÃO no UserModel ---
        // Seu UserModel não tem um método fromFirestore(). Vamos criar um manualmente.
        // Ou, idealmente, adicione `fromFirestore()` ao seu UserModel.
        // Por agora, faremos manualmente:
        final data = doc.data() as Map<String, dynamic>;
        return UserModel(
          uid: doc.id,
          email: data['email'] ?? '',
          photoUrl: data['photoUrl'] as String?,
          primeiroNome: data['primeiroNome'] ?? '',
          sobrenome: data['sobrenome'] ?? '',
          nomeAnalise: data['nomeAnalise'] ?? '',
          dataNasc: data['dataNasc'] ?? '', // Assumindo String
          plano: data['plano'] ?? 'gratuito',
          isAdmin: data['isAdmin'] ?? false,
          // Carrega a ordem dos cards ou usa o padrão
          dashboardCardOrder: List<String>.from(
              data['dashboardCardOrder'] ?? UserModel.defaultCardOrder),
        );
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

  // --- NOVO MÉTODO ADICIONADO ---
  /// Busca as [limit] tarefas mais recentes do usuário.
  Future<List<TaskModel>> getRecentTasks(String userId,
      {int limit = 20}) async {
    try {
      final querySnapshot = await _db
          .collection('users')
          .doc(userId)
          .collection('tasks')
          .orderBy('createdAt', descending: true) // Ordena pelas mais recentes
          .limit(limit) // Limita a quantidade
          .get();

      return querySnapshot.docs
          .map((doc) => TaskModel.fromFirestore(doc))
          .toList();
    } catch (e, stackTrace) {
      print("Erro ao buscar tarefas recentes: $e\n$stackTrace");
      return []; // Retorna lista vazia em caso de erro
    }
  }
  // --- FIM DO NOVO MÉTODO ---

  Future<List<TaskModel>> getTasksForToday(String userId) async {
    // (Seu método original - mantido)
    try {
      final now = DateTime.now();
      final startOfDayLocal = DateTime(now.year, now.month, now.day);
      final endOfDayLocal = startOfDayLocal.add(const Duration(days: 1));
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
    return _db
        .collection('users')
        .doc(userId)
        .collection('tasks')
        .where('journeyId',
            isEqualTo: goalId) // Assume que 'journeyId' é o campo correto
        .orderBy('createdAt', descending: true) // Ordena pela data de criação
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => TaskModel.fromFirestore(doc)).toList())
        .handleError((error, stackTrace) {
      print("Erro no stream de Tasks para Goal $goalId: $error\n$stackTrace");
      return <TaskModel>[]; // Retorna lista vazia em caso de erro
    });
  }

  Future<void> addTask(String userId, TaskModel task) async {
    // (Seu método original - sem alterações)
    final data = task.toFirestore();
    // Garante que as datas sejam Timestamps
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
    // Garante que as datas sejam Timestamps ou null
    if (data.containsKey('createdAt') && data['createdAt'] is DateTime) {
      data['createdAt'] = Timestamp.fromDate(data['createdAt']);
    }
    if (data.containsKey('dueDate') && data['dueDate'] is DateTime) {
      data['dueDate'] = Timestamp.fromDate(data['dueDate']);
    } else if (data.containsKey('dueDate') && data['dueDate'] == null) {
      data['dueDate'] = null; // Garante que seja null se for o caso
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
    // Filtro por data (dia específico)
    if (date != null) {
      final utcDate = DateTime.utc(date.year, date.month, date.day);
      final startOfDay = Timestamp.fromDate(utcDate);
      final endOfDay = Timestamp.fromDate(utcDate.add(const Duration(days: 1)));
      query = query
          .where('createdAt', isGreaterThanOrEqualTo: startOfDay)
          .where('createdAt', isLessThan: endOfDay);
    }
    // Filtro por humor
    if (mood != null) {
      query = query.where('mood', isEqualTo: mood);
    }
    // Filtro por vibração (dia pessoal)
    if (vibration != null) {
      query = query.where('personalDay', isEqualTo: vibration);
    }
    // Ordena sempre pela data mais recente
    query = query.orderBy('createdAt', descending: true);

    return query.snapshots().map((snapshot) {
      if (snapshot.docs.isEmpty) {
        return <JournalEntry>[];
      }
      List<JournalEntry> entries = [];
      for (var doc in snapshot.docs) {
        try {
          entries.add(JournalEntry.fromFirestore(doc));
        } catch (e, stackTrace) {
          print(
              "Erro ao converter Journal Entry ID ${doc.id}: $e\n$stackTrace");
          // Continua o loop para não quebrar o stream por um doc inválido
        }
      }
      return entries;
    }).handleError((error, stackTrace) {
      print("Erro geral no stream de Journal Entries: $error\n$stackTrace");
      return <JournalEntry>[]; // Retorna lista vazia em caso de erro
    });
  }

  Future<List<JournalEntry>> getJournalEntriesForMonth(
      String userId, DateTime month) async {
    // (Seu método original - sem alterações)
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
    // Garante que createdAt seja um Timestamp UTC
    if (data['createdAt'] is DateTime) {
      data['createdAt'] =
          Timestamp.fromDate((data['createdAt'] as DateTime).toUtc());
    } else if (data['createdAt'] == null) {
      data['createdAt'] = Timestamp.now(); // Usa now() se for nulo
    }
    // Garante que personalDay e mood sejam inteiros
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
    // Garante que createdAt seja um Timestamp UTC se presente
    if (data.containsKey('createdAt') && data['createdAt'] is DateTime) {
      data['createdAt'] =
          Timestamp.fromDate((data['createdAt'] as DateTime).toUtc());
    }
    // Garante que personalDay e mood sejam inteiros se presentes
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

  // --- MÉTODOS PARA AS METAS (JORNADAS) ---

  // ATUALIZADO: Método `updateGoal` agora aceita um objeto Goal
  Future<void> updateGoal(Goal goal) async {
    try {
      final data = goal.toFirestore(); // Usa o método do modelo Goal
      await _db
          .collection('users')
          .doc(goal.userId) // Pega o userId do próprio objeto Goal
          .collection('goals')
          .doc(goal.id)
          .update(data);
    } catch (e) {
      print("Erro ao atualizar a meta ${goal.id}: $e");
      rethrow;
    }
  }

  Stream<List<Goal>> getGoalsStream(String userId) {
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
      return <Goal>[]; // Retorna lista vazia em caso de erro
    });
  }

  Future<List<Goal>> getActiveGoals(String userId) async {
    // (Seu método original - sem alterações)
    try {
      final querySnapshot = await _db
          .collection('users')
          .doc(userId)
          .collection('goals')
          // .where('status', isEqualTo: 'active') // Exemplo: Se houver um campo status
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
    // Garante que createdAt seja Timestamp UTC
    if (data['createdAt'] is DateTime) {
      data['createdAt'] =
          Timestamp.fromDate((data['createdAt'] as DateTime).toUtc());
    } else if (data['createdAt'] == null) {
      data['createdAt'] = Timestamp.now();
    }
    // Garante que targetDate seja Timestamp UTC ou null
    if (data['targetDate'] is DateTime) {
      data['targetDate'] =
          Timestamp.fromDate((data['targetDate'] as DateTime).toUtc());
    } else {
      data['targetDate'] = null; // Garante que seja null se não for DateTime
    }
    // Inicializa progresso e subtarefas se não existirem
    data['progress'] = data['progress'] ?? 0;
    data['subTasks'] = data['subTasks'] ?? []; // Inicializa como lista vazia
    data['userId'] = userId; // Garante que o userId esteja presente

    return await _db
        .collection('users')
        .doc(userId)
        .collection('goals')
        .add(data);
  }

  // Removido o método antigo updateGoal(userId, goalId, data)
  // pois foi substituído por updateGoal(Goal goal)

  Future<void> updateGoalProgress(String userId, String goalId) async {
    // (Seu método original - sem alterações)
    // Este método agora pode ser substituído calculando o progresso
    // diretamente no frontend a partir da lista de subTasks do objeto Goal.
    // Mas vamos mantê-lo por enquanto, caso seja usado em outro lugar.
    try {
      final goalRef =
          _db.collection('users').doc(userId).collection('goals').doc(goalId);
      final goalDoc = await goalRef.get();
      if (!goalDoc.exists) {
        print("Tentativa de atualizar progresso de meta inexistente: $goalId");
        return;
      }

      // --- ATENÇÃO: O cálculo de progresso idealmente seria feito
      // --- a partir das 'subTasks' dentro do documento da meta.
      // --- Esta query busca em 'tasks', o que pode ser diferente.
      // --- Se as subtarefas SÃO as 'tasks' com 'journeyId', está ok.
      final tasksSnapshot = await _db
          .collection('users')
          .doc(userId)
          .collection('tasks')
          .where('journeyId', isEqualTo: goalId)
          .get();

      final totalTasks = tasksSnapshot.docs.length;
      final completedTasks = tasksSnapshot.docs.where((doc) {
        final taskData = doc.data();
        // Verifica se 'completed' existe e é true
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

      // Opcional: Deletar tarefas associadas (subtasks)
      // Se as subtarefas estiverem DENTRO do doc da meta, elas já foram deletadas.
      // Se forem tarefas na coleção 'tasks', a query abaixo é necessária.
      final tasksQuery = _db
          .collection('users')
          .doc(userId)
          .collection('tasks')
          .where('journeyId',
              isEqualTo: goalId); // Assume que 'journeyId' liga à meta

      final tasksSnapshot = await tasksQuery.get();
      for (final doc in tasksSnapshot.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
    } catch (e, stackTrace) {
      print("Erro ao deletar meta $goalId e/ou suas tarefas: $e\n$stackTrace");
      rethrow; // Propaga o erro para a UI poder reagir
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
          // Compara os títulos sanitizados em minúsculas
          if (StringSanitizer.toSimpleTag(goal.title).toLowerCase() ==
              sanitizedTitle.toLowerCase()) {
            return goal;
          }
        } catch (e) {
          print(
              "Erro ao processar meta ${doc.id} em findGoalBySanitizedTitle: $e");
          // Continua para a próxima meta
        }
      }
      return null; // Nenhuma meta encontrada com esse título
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
        .orderBy('dueDate'); // Ordena pela data de vencimento
    return query.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => TaskModel.fromFirestore(doc)).toList();
    }).handleError((error, stackTrace) {
      print(
          "Erro no stream de tasks (dueDate - Calendar): $error\n$stackTrace");
      return <TaskModel>[]; // Retorna lista vazia em caso de erro
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
        .where('dueDate', isEqualTo: null) // Tarefas sem data de vencimento
        .where('createdAt', // Mas criadas no mês visualizado
            isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth))
        .where('createdAt', isLessThan: Timestamp.fromDate(endOfMonth))
        .orderBy('createdAt'); // Ordena pela data de criação
    return query.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => TaskModel.fromFirestore(doc)).toList();
    }).handleError((error, stackTrace) {
      print(
          "Erro no stream de tasks (createdAt - Calendar): $error\n$stackTrace");
      return <TaskModel>[]; // Retorna lista vazia em caso de erro
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
        .orderBy('createdAt', descending: true); // Mais recentes primeiro
    return query.snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => JournalEntry.fromFirestore(doc))
          .toList();
    }).handleError((error, stackTrace) {
      print(
          "Erro no stream de Journal Entries (Calendar): $error\n$stackTrace");
      return <JournalEntry>[]; // Retorna lista vazia em caso de erro
    });
  }

  // --- STREAM PARA O FOCO DO DIA (sem alterações) ---
  Stream<List<TaskModel>> getTasksStreamForToday(String userId) {
    final now = DateTime.now();
    final startOfDayLocal = DateTime(now.year, now.month, now.day);
    final endOfDayLocal = startOfDayLocal.add(const Duration(days: 1));
    final startTimestamp = Timestamp.fromDate(startOfDayLocal.toUtc());
    final endTimestamp = Timestamp.fromDate(endOfDayLocal.toUtc());
    final tasksRef = _db.collection('users').doc(userId).collection('tasks');

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
          ..sort((a, b) =>
              (a.dueDate ?? a.createdAt).compareTo(b.dueDate ?? b.createdAt));
        return combinedList;
      },
    );
  }

  // --- FUNÇÃO getTasksForFocusDay (sem alterações) ---
  Future<List<TaskModel>> getTasksForFocusDay(
      String userId, DateTime day) async {
    try {
      final startOfDayLocal = DateTime(day.year, day.month, day.day);
      final endOfDayLocal = startOfDayLocal.add(const Duration(days: 1));
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
