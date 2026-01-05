import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart'; // Para TimeOfDay
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sincro_app_flutter/models/user_model.dart';
import 'package:sincro_app_flutter/models/subscription_model.dart';
import 'package:sincro_app_flutter/features/tasks/models/task_model.dart';
import 'package:sincro_app_flutter/models/recurrence_rule.dart';
import 'package:postgrest/postgrest.dart';
import 'package:sincro_app_flutter/features/goals/models/goal_model.dart';
import 'package:sincro_app_flutter/features/journal/models/journal_entry_model.dart';
import 'package:sincro_app_flutter/features/assistant/models/assistant_models.dart';

class SupabaseService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Singleton instance
  static final SupabaseService _instance = SupabaseService._internal();
  factory SupabaseService() => _instance;
  SupabaseService._internal();

  /// Salva ou atualiza os dados do usuário no Supabase
  /// Mapeia o UserModel para as colunas da tabela 'profiles' (ou 'users')
  Future<void> saveUserData(UserModel user) async {
    try {
      final userData = {
        'uid': user.uid, // PK (Texto, vindo do Firebase Auth)
        'email': user.email,
        'photo_url': user.photoUrl,
        'first_name': user.primeiroNome,
        'last_name': user.sobrenome,
        'analysis_name': user.nomeAnalise,
        'birth_date': user.dataNasc,
        'is_admin': user.isAdmin,
        'dashboard_card_order': user.dashboardCardOrder,
        'dashboard_hidden_cards': user.dashboardHiddenCards,
        // Serializa Subscription para JSONB ou colunas separadas
        // Aqui assumindo JSONB na coluna 'subscription_data'
        'subscription_data': user.subscription.toFirestore(), 
        'updated_at': DateTime.now().toIso8601String(),
      };

      // Upsert: Insere se não existir, atualiza se existir (baseado na PK user_id)
      await _supabase.schema('sincroapp').from('users').upsert(userData, onConflict: 'uid');
      
      debugPrint('✅ [SupabaseService] Dados do usuário salvos com sucesso.');
    } catch (e) {
      debugPrint('❌ [SupabaseService] Erro ao salvar dados do usuário: $e');
      rethrow;
    }
  }

  /// Recupera os dados do usuário
  Future<UserModel?> getUserData(String uid) async {
    try {
      final response = await _supabase
          .schema('sincroapp')
          .from('users')
          .select()
          .eq('uid', uid)
          .maybeSingle();

      if (response == null) {
        debugPrint('⚠️ [SupabaseService] Usuário não encontrado no Supabase: $uid');
        return null;
      }

      final data = response;
      
      // Converte de volta para UserModel
      // Nota: Precisamos ajustar o UserModel.fromMap se os nomes das colunas mudaram
      // OU mapear manualmente aqui. Vou mapear manualmente para manter compatibilidade.
      
      return UserModel(
        uid: data['uid'],
        email: data['email'] ?? '',
        photoUrl: data['photo_url'],
        primeiroNome: data['primeiro_nome'] ?? data['first_name'] ?? '', // Fallback para compatibility
        sobrenome: data['sobrenome'] ?? data['last_name'] ?? '',
        plano: 'essencial', // Default legacy plan name
        nomeAnalise: data['nome_analise'] ?? data['analysis_name'] ?? '',
        dataNasc: data['birth_date'] ?? '',
        isAdmin: data['is_admin'] ?? false,
        dashboardCardOrder: List<String>.from(data['dashboard_card_order'] ?? UserModel.defaultCardOrder),
        dashboardHiddenCards: List<String>.from(data['dashboard_hidden_cards'] ?? []),
        subscription: data['subscription_data'] != null 
            ? SubscriptionModel.fromFirestore(data['subscription_data']) 
            : SubscriptionModel.free(),
      );
    } catch (e) {
      debugPrint('❌ [SupabaseService] Erro ao buscar usuário: $e');
      rethrow;
    }
  }

  /// Atualiza campos específicos
  Future<void> updateUserData(String uid, Map<String, dynamic> data) async {
    try {
      // Mapeamento de chaves do Flutter (CamelCase) para Supabase (snake_case)
      final mappedData = <String, dynamic>{};
      data.forEach((key, value) {
        switch (key) {
          case 'primeiroNome': mappedData['first_name'] = value; break;
          case 'sobrenome': mappedData['last_name'] = value; break;
          case 'nomeAnalise': mappedData['analysis_name'] = value; break;
          case 'dataNasc': mappedData['birth_date'] = value; break;
          case 'dashboardCardOrder': mappedData['dashboard_card_order'] = value; break;
          case 'dashboardHiddenCards': mappedData['dashboard_hidden_cards'] = value; break;
          case 'subscription': mappedData['subscription_data'] = value; break; // Se vier o mapa
          default: mappedData[key] = value; // Fallback
        }
      });
      
      mappedData['updated_at'] = DateTime.now().toIso8601String();

      await _supabase.schema('sincroapp').from('users').update(mappedData).eq('uid', uid);
    } catch (e) {
      debugPrint('❌ [SupabaseService] Erro ao atualizar usuário: $e');
      rethrow;
    }
  }

  // --- TASKS ---

  // --- TASKS ---

  Future<void> addTask(String uid, TaskModel task) async {
    try {
      final taskData = {
        'user_id': uid,
        'text': task.text,
        'completed': task.completed,
        'created_at': task.createdAt.toIso8601String(),
        'due_date': task.dueDate?.toIso8601String(),
        'tags': task.tags, // Supabase suporta array de strings
        'journey_id': task.journeyId,
        'journey_title': task.journeyTitle,
        'personal_day': task.personalDay,
        'recurrence_type': task.recurrenceType.toString(),
        'recurrence_days_of_week': task.recurrenceDaysOfWeek,
        'recurrence_end_date': task.recurrenceEndDate?.toIso8601String(),
        'reminder_hour': task.reminderTime?.hour,
        'reminder_minute': task.reminderTime?.minute,
        'reminder_at': task.reminderAt?.toIso8601String(),
        'recurrence_id': task.recurrenceId,
        'goal_id': task.goalId,
        'completed_at': task.completedAt?.toIso8601String(),
      };
      
      await _supabase.schema('sincroapp').from('tasks').insert(taskData);
    } catch (e) {
      debugPrint('❌ [SupabaseService] Erro ao adicionar tarefa: $e');
      rethrow;
    }
  }

  Future<List<TaskModel>> getRecentTasks(String uid, {int limit = 30}) async {
    try {
      final response = await _supabase
          .schema('sincroapp')
          .from('tasks')
          .select()
          .eq('user_id', uid)
          .order('created_at', ascending: false)
          .limit(limit);

      final List<dynamic> data = response;
      return data.map((item) => _mapTaskFromSupabase(item)).toList();
    } catch (e) {
      debugPrint('❌ [SupabaseService] Erro ao buscar tarefas recentes: $e');
      return [];
    }
  }

  Stream<List<TaskModel>> getTasksStream(String uid) {
    // Client-side filtering as fallback for stream errors
    return _supabase
        .schema('sincroapp')
        .from('tasks')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .map((data) {
           return data
               .where((item) => item['user_id'] == uid)
               .map((item) => _mapTaskFromSupabase(item))
               .toList();
        });
  }

  Future<void> updateTask(String uid, TaskModel task) async {
    try {
      final taskData = {
        'text': task.text,
        'completed': task.completed,
        'due_date': task.dueDate?.toIso8601String(),
        'tags': task.tags,
        'recurrence_type': task.recurrenceType.toString(),
        'recurrence_days_of_week': task.recurrenceDaysOfWeek,
        'recurrence_end_date': task.recurrenceEndDate?.toIso8601String(),
        'reminder_hour': task.reminderTime?.hour,
        'reminder_minute': task.reminderTime?.minute,
        'reminder_at': task.reminderAt?.toIso8601String(),
        'personal_day': task.personalDay,
        'completed_at': task.completedAt?.toIso8601String(),
      };
      await _supabase
          .schema('sincroapp')
          .from('tasks')
          .update(taskData)
          .eq('id', task.id);
    } catch (e) {
      debugPrint('❌ [SupabaseService] Erro ao atualizar tarefa: $e');
      rethrow;
    }
  }

  Future<void> deleteTask(String uid, String taskId) async {
    try {
      await _supabase
          .schema('sincroapp')
          .from('tasks')
          .delete()
          .eq('id', taskId);
    } catch (e) {
      debugPrint('❌ [SupabaseService] Erro ao deletar tarefa: $e');
      rethrow;
    }
  }
  
  Future<void> updateTaskFields(String uid, String taskId, Map<String, dynamic> updates) async {
    try {
       // Map fields from camelCase (Flutter) to snake_case (Supabase)
       final mappedUpdates = <String, dynamic>{};
       updates.forEach((key, value) {
         if (value is DateTime) value = value.toIso8601String();
         
         switch (key) {
           case 'dueDate': mappedUpdates['due_date'] = value; break;
           case 'createdAt': mappedUpdates['created_at'] = value; break;
           case 'completedAt': mappedUpdates['completed_at'] = value; break;
           case 'journeyId': mappedUpdates['journey_id'] = value; break;
           case 'journeyTitle': mappedUpdates['journey_title'] = value; break;
           case 'recurrenceType': mappedUpdates['recurrence_type'] = value.toString(); break;
           case 'recurrenceDaysOfWeek': mappedUpdates['recurrence_days_of_week'] = value; break;
           case 'recurrenceEndDate': mappedUpdates['recurrence_end_date'] = value; break;
           case 'reminderAt': mappedUpdates['reminder_at'] = value; break;
           case 'personalDay': mappedUpdates['personal_day'] = value; break;
           default: mappedUpdates[key] = value; 
         }
       });
       
       await _supabase.schema('sincroapp').from('tasks').update(mappedUpdates).eq('id', taskId);
    } catch (e) {
       debugPrint('❌ [SupabaseService] Erro ao atualizar campos da tarefa: $e');
       rethrow;
    }
  }

  Future<void> updateTaskCompletion(String uid, String taskId, {required bool completed}) async {
    await updateTaskFields(uid, taskId, {
      'completed': completed,
      'completedAt': completed ? DateTime.now() : null,
    });
  }
  
  // Batch delete logic (optional but useful)
  Future<void> deleteTasks(String uid, List<String> taskIds) async {
      if (taskIds.isEmpty) return;
      try {
        await _supabase.schema('sincroapp').from('tasks').delete().filter('id', 'in', taskIds);
      } catch (e) {
        debugPrint('❌ [SupabaseService] Erro ao deletar tarefas em lote: $e');
      }
  }

  // Removido getTasksForGoalStream duplicado e implementado getGoalsStream e getGoalById
  Stream<List<Goal>> getGoalsStream(String uid) {
    return _supabase
        .schema('sincroapp')
        .from('goals')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .map((data) {
           return data
              .where((item) => item['user_id'] == uid)
              .map((item) => _mapGoalFromSupabase(item))
              .toList();
        });
  }

  Future<Goal?> getGoalById(String uid, String goalId) async {
    try {
      final response = await _supabase
          .schema('sincroapp')
          .from('goals')
          .select()
          .eq('user_id', uid)
          .eq('id', goalId)
          .maybeSingle();

      if (response == null) return null;
      return _mapGoalFromSupabase(response);
    } catch (e) {
      debugPrint('Error getting goal by id: $e');
      return null;
    }
  }

  /// Helper para garantir que a data seja interpretada como DATA LOCAL (Dia/Mês/Ano)
  /// ignorando o deslocamento de fuso horário que pode vir do banco (UTC).
  /// Ex: 2023-01-03T00:00:00Z -> Parse -> 2023-01-02 21:00 (Local) -> Fix -> 2023-01-03 00:00 (Local)
  DateTime? _parseDateAsLocal(String? dateString) {
    if (dateString == null) return null;
    try {
      // Parse original (pode vir com fuso Z)
      final parsed = DateTime.parse(dateString);
      
      // Se a string original tinha "T", tentamos pegar a data antes dele para garantir o dia.
      // Mas o DateTime.parse já ajusta para UTC se tiver Z.
      // O problema é q queremos o ANO-MES-DIA literal da string ou ajustado?
      // O Supabase salva como UTC 00:00.
      // Se salvamos 03/01, vai ser 03/01 00:00 UTC.
      // Ao ler aqui (Brasil -3), DateTime.parse("...Z").toLocal() vira 02/01 21:00.
      // O widget de calendário vê 02/01.
      
      // O que queremos: Se o banco diz 03/01 (UTC), queremos 03/01 (Local).
      // Então pegamos os componentes do UTC e criamos um Local.
      
      // Se o parse resultar em UTC (isUtc=true), usamos seus componentes para criar um Local.
      if (parsed.isUtc) {
         return DateTime(parsed.year, parsed.month, parsed.day);
      } else {
         return DateTime(parsed.year, parsed.month, parsed.day);
      }
    } catch (e) {
      return null;
    }
  }

  Goal _mapGoalFromSupabase(Map<String, dynamic> data) {
    return Goal(
      id: data['id'],
      userId: data['user_id'],
      title: data['title'],
      description: data['description'] ?? '',
      targetDate: _parseDateAsLocal(data['target_date']), // FIX
      progress: (data['progress'] as num?)?.toDouble().toInt() ?? 0,
      category: data['category'] ?? '',
      imageUrl: data['image_url'],
      subTasks: (data['sub_tasks'] as List?)?.map((e) => SubTask.fromMap(e as Map<String,dynamic>,'')).toList() ?? [],
      createdAt: DateTime.tryParse(data['created_at'] ?? '') ?? DateTime.now(), // CreatedAt pode manter o horário real
    );
  }

  TaskModel _mapTaskFromSupabase(Map<String, dynamic> data) {
    // Helper para mapear JSON do Supabase para TaskModel
    RecurrenceType recType = RecurrenceType.none;
    if (data['recurrence_type'] != null) {
      recType = RecurrenceType.values.firstWhere(
        (e) => e.toString() == data['recurrence_type'],
        orElse: () => RecurrenceType.none,
      );
    }

    TimeOfDay? reminder;
    if (data['reminder_hour'] != null && data['reminder_minute'] != null) {
      reminder = TimeOfDay(hour: data['reminder_hour'], minute: data['reminder_minute']);
    }

    return TaskModel(
      id: data['id'], // UUID do Supabase
      text: data['text'] ?? '',
      completed: data['completed'] ?? false,
      createdAt: DateTime.tryParse(data['created_at'] ?? '') ?? DateTime.now(),
      dueDate: _parseDateAsLocal(data['due_date']), // FIX
      tags: List<String>.from(data['tags'] ?? []),
      journeyId: data['journey_id'],
      journeyTitle: data['journey_title'],
      personalDay: data['personal_day'],
      recurrenceType: recType,
      recurrenceDaysOfWeek: List<int>.from(data['recurrence_days_of_week'] ?? []),
      recurrenceEndDate: _parseDateAsLocal(data['recurrence_end_date']), // FIX
      reminderTime: reminder,
      reminderAt: data['reminder_at'] != null ? DateTime.tryParse(data['reminder_at']) : null,
      recurrenceId: data['recurrence_id'],
      goalId: data['goal_id'],
      completedAt: data['completed_at'] != null ? DateTime.tryParse(data['completed_at']) : null,
    );
  }

  // --- GOALS ---

  Future<void> addGoal(String uid, Goal goal) async {
    try {
      final goalData = {
        'user_id': uid,
        'title': goal.title,
        'description': goal.description,
        'target_date': goal.targetDate?.toIso8601String(),
        'progress': goal.progress,
        'category': goal.category,
        'image_url': goal.imageUrl,
        'sub_tasks': goal.subTasks.map((t) => t.toMap()).toList(), // Serializa lista de SubTasks
        'created_at': goal.createdAt.toIso8601String(),
      };
      
      // Se o ID for vazio, deixa o banco gerar. Se vier preenchido, tenta usar.
      if (goal.id.isNotEmpty) {
        goalData['id'] = goal.id;
      }

      await _supabase.schema('sincroapp').from('goals').insert(goalData);
    } catch (e) {
      debugPrint('❌ [SupabaseService] Erro ao adicionar meta: $e');
      rethrow;
    }
  }

  Future<List<Goal>> getActiveGoals(String uid) async {
    try {
      final response = await _supabase
          .schema('sincroapp')
          .from('goals')
          .select()
          .eq('user_id', uid)
          .lt('progress', 100) // Assumindo active = progress < 100
          .order('created_at', ascending: false);

      final List<dynamic> data = response;
      return data.map((item) => _mapGoalFromSupabase(item)).toList();
    } catch (e) {
      debugPrint('❌ [SupabaseService] Erro ao buscar metas ativas: $e');
      return [];
    }
  }

  Stream<List<Goal>> getGoalStream(String uid) {
    return _supabase
        .schema('sincroapp')
        .from('goals')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .map((data) {
           return data
              .where((item) => item['user_id'] == uid)
              .map((item) => _mapGoalFromSupabase(item))
              .toList();
        });
  }

  Stream<Goal> getSingleGoalStream(String uid, String goalId) {
    return _supabase
        .schema('sincroapp')
        .from('goals')
        .stream(primaryKey: ['id'])
        .order('created_at') // Optional
        .map((data) {
           return data
               .where((item) => item['user_id'] == uid && item['id'] == goalId)
               .map((item) => _mapGoalFromSupabase(item))
               .single;
        });
  }

  Future<void> updateGoal(Goal goal) async {
    try {
      final goalData = {
        'title': goal.title,
        'description': goal.description,
        'target_date': goal.targetDate?.toIso8601String(),
        'progress': goal.progress,
        'category': goal.category,
        'image_url': goal.imageUrl,
        'sub_tasks': goal.subTasks.map((t) => t.toMap()).toList(),
      };
      await _supabase
          .schema('sincroapp')
          .from('goals')
          .update(goalData)
          .eq('id', goal.id);
    } catch (e) {
      debugPrint('❌ [SupabaseService] Erro ao atualizar meta: $e');
      rethrow;
    }
  }

  Future<void> deleteGoal(String uid, String goalId) async {
    try {
      await _supabase.schema('sincroapp').from('goals').delete().eq('id', goalId);
    } catch (e) {
      debugPrint('❌ [SupabaseService] Erro ao deletar meta: $e');
      rethrow;
    }
  }

  Future<String?> uploadGoalImage(String uid, String goalId, File imageFile) async {
    try {
      final fileExt = imageFile.path.split('.').last;
      final fileName = '${DateTime.now().toIso8601String()}_$goalId.$fileExt';
      final filePath = '$uid/$fileName';

      await _supabase.storage.from('goal_images').upload(
        filePath,
        imageFile,
        fileOptions: const FileOptions(cacheControl: '3600', upsert: false),
      );

      final imageUrl = _supabase.storage.from('goal_images').getPublicUrl(filePath);
      return imageUrl;
    } catch (e) {
      debugPrint('❌ [SupabaseService] Erro ao fazer upload da imagem: $e');
      return null;
    }
  }

  Future<String?> uploadGoalImageBytes(String uid, String goalId, Uint8List bytes, String fileName) async {
    try {
      final fileExt = fileName.split('.').last;
      final uniqueName = '${DateTime.now().toIso8601String()}_$goalId.$fileExt';
      final filePath = '$uid/$uniqueName';

      await _supabase.storage.from('goal_images').uploadBinary(
        filePath,
        bytes,
        fileOptions: const FileOptions(cacheControl: '3600', upsert: false),
      );

      final imageUrl = _supabase.storage.from('goal_images').getPublicUrl(filePath);
      return imageUrl;
    } catch (e) {
      debugPrint('❌ [SupabaseService] Erro ao fazer upload da imagem (bytes): $e');
      return null;
    }
  }

  Future<void> updateGoalProgress(String uid, String goalId) async {
    try {
      final response = await _supabase
          .schema('sincroapp')
          .from('tasks')
          .select('completed')
          .eq('user_id', uid)
          .eq('journey_id', goalId);

      final List<dynamic> tasks = response;
      int progress = 0;
      
      if (tasks.isNotEmpty) {
        final totalTasks = tasks.length;
        final completedTasks = tasks.where((t) => t['completed'] == true).length;
        progress = (completedTasks / totalTasks * 100).round();
      }

      await _supabase
          .schema('sincroapp')
          .from('goals')
          .update({'progress': progress})
          .eq('id', goalId);
          
    } catch (e) {
      debugPrint('❌ [SupabaseService] Erro ao atualizar progresso da meta $goalId: $e');
    }
  }


  // --- JOURNAL ---

  // --- JOURNAL ---

  Future<List<JournalEntry>> getJournalEntriesForMonth(String uid, DateTime month) async {
    try {
      final startOfMonth = DateTime(month.year, month.month, 1);
      final endOfMonth = DateTime(month.year, month.month + 1, 0); // Último dia

      final response = await _supabase
          .schema('sincroapp')
          .from('journal_entries')
          .select()
          .eq('user_id', uid)
          .gte('entry_date', startOfMonth.toIso8601String())
          .lte('entry_date', endOfMonth.toIso8601String())
          .order('entry_date', ascending: false);

      final List<dynamic> data = response;
      return data.map((item) => JournalEntry.fromMap(item)).toList();
    } catch (e) {
      debugPrint('❌ [SupabaseService] Erro ao buscar diário (mês): $e');
      return [];
    }
  }

  Stream<List<JournalEntry>> getJournalEntriesStream(
    String uid, {
    DateTime? date,
    int? mood,
    int? vibration,
  }) {
    var query = _supabase
        .schema('sincroapp')
        .from('journal_entries')
        .stream(primaryKey: ['id'])
        .eq('user_id', uid)
        .order('entry_date', ascending: false);
    
    return query.map((data) {
      var entries = data.map((item) => JournalEntry.fromMap(item)).toList();
      
      // Client-side filtering
      if (date != null) {
        entries = entries.where((e) => 
          e.createdAt.year == date.year && 
          e.createdAt.month == date.month && 
          e.createdAt.day == date.day
        ).toList();
      }
      
      if (mood != null) {
        entries = entries.where((e) => e.mood == mood).toList();
      }
      
      if (vibration != null) {
        entries = entries.where((e) => e.personalDay == vibration).toList();
      }
      
      return entries;
    });
  }

  Future<void> addJournalEntry(String uid, Map<String, dynamic> data) async {
    try {
      final Map<String, dynamic> entryData = {
        'user_id': uid,
        'content': data['content'],
        'mood': data['mood']?.toString(), // Enum/Int to String
        'tags': data['tags'] ?? [], 
        'entry_date': data['created_at'] is DateTime 
             ? (data['created_at'] as DateTime).toIso8601String() 
             : data['created_at'] ?? DateTime.now().toIso8601String(),
        'personal_day': data['personal_day'] ?? data['personalDay'], 
        'updated_at': DateTime.now().toIso8601String(),
        'created_at': DateTime.now().toIso8601String(),
      };
      
      entryData.removeWhere((key, value) => value == null);

      await _supabase.schema('sincroapp').from('journal_entries').insert(entryData);
    } catch (e) {
       debugPrint('❌ [SupabaseService] Erro ao adicionar diário: $e');
       rethrow;
    }
  }

  Future<void> updateJournalEntry(String uid, String entryId, Map<String, dynamic> data) async {
      try {
         final mapped = <String, dynamic>{};
         data.forEach((k, v) {
            if (v is DateTime) v = v.toIso8601String();
            
            switch (k) {
               case 'entryDate': mapped['entry_date'] = v; break;
               case 'createdAt': mapped['created_at'] = v; break;
               case 'updatedAt': mapped['updated_at'] = v; break;
               case 'personalDay': mapped['personal_day'] = v; break;
               case 'mood': mapped['mood'] = v?.toString(); break;
               default: mapped[k] = v;
            }
         });
         
         if (!mapped.containsKey('updated_at')) {
           mapped['updated_at'] = DateTime.now().toIso8601String();
         }

         await _supabase.schema('sincroapp').from('journal_entries').update(mapped).eq('id', entryId);
      } catch (e) {
         debugPrint('❌ [SupabaseService] Erro ao atualizar diário: $e');
         rethrow;
      }
  }

  Future<void> deleteJournalEntry(String uid, String entryId) async {
     await _supabase.schema('sincroapp').from('journal_entries').delete().eq('id', entryId);
  }

  // ========================================================================
  // === ADMIN PANEL METHODS ===
  // ========================================================================

  /// Busca todos os usuários (apenas para Admin)
  Future<List<UserModel>> getAllUsers() async {
    try {
      // Nota: RLS deve permitir isso apenas se o usuário logado for admin.
      // Ou, se o RLS estiver bloqueando, será necessário uma Edge Function 'admin-get-users'.
      // Vamos tentar direto primeiro.
      final response = await _supabase
          .schema('sincroapp')
          .from('users')
          .select()
          .order('created_at', ascending: false);

      final List<dynamic> data = response;
      return data.map((item) => _mapUserFromSupabase(item)).toList();
    } catch (e) {
      debugPrint('❌ [SupabaseService] Erro ao buscar todos os usuários: $e');
      return []; // Retorna lista vazia para não quebrar UI
    }
  }

  /// Calcula estatísticas do Admin (Client-side aggregation para precisão com complexidade de planos)
  Future<Map<String, dynamic>> getAdminStats() async {
    try {
       final users = await getAllUsers();
       
       int freeCount = 0;
       int plusCount = 0;
       int premiumCount = 0;
       int activeCount = 0;
       int expiredCount = 0;
       double mrr = 0.0;
       
       // Logica copiada e adaptada do FirestoreService
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
       debugPrint('❌ [SupabaseService] Erro ao calcular stats: $e');
       // Retorna zerado
       return {
          'totalUsers': 0, 'estimatedMRR': 0.0,
       };
    }
  }

  /// Helper para mapear usuário vindo do Supabase
  UserModel _mapUserFromSupabase(Map<String, dynamic> data) {
      return UserModel(
        uid: data['uid'],
        email: data['email'] ?? '',
        photoUrl: data['photo_url'],
        primeiroNome: data['primeiro_nome'] ?? data['first_name'] ?? '',
        sobrenome: data['sobrenome'] ?? data['last_name'] ?? '',
        plano: 'essencial', // Legacy
        nomeAnalise: data['nome_analise'] ?? data['analysis_name'] ?? '',
        dataNasc: data['birth_date'] ?? '',
        isAdmin: data['is_admin'] ?? false,
        dashboardCardOrder: List<String>.from(data['dashboard_card_order'] ?? UserModel.defaultCardOrder),
        dashboardHiddenCards: List<String>.from(data['dashboard_hidden_cards'] ?? []),
        subscription: data['subscription_data'] != null 
            ? SubscriptionModel.fromFirestore(data['subscription_data']) 
            : SubscriptionModel.free(),
      );
  }

  /// Busca configurações do site (Manutenção/Senha)
  /// Usa a tabela `site_settings` (criei hipoteticamente ou usa fallback)
  Stream<Map<String, dynamic>> getSiteSettingsStream() {
      return _supabase.schema('sincroapp').from('site_settings').stream(primaryKey: ['key']).map((event) {
         // Converte lista de key-values para Map único
         final Map<String, dynamic> settings = {};
         for (var item in event) {
            if (item['key'] == 'global_config') {
               return item['value'] as Map<String, dynamic>;
            }
         }
         return {
            'status': 'active', 'bypassPassword': ''
         };
      }).handleError((e) {
         // Fallback se tabela não existir
         return {'status': 'active', 'bypassPassword': ''};
      });
  }
  
  // Versão Future se Stream falhar ou for complexo demais criar tabela agora
  Future<Map<String, dynamic>> getSiteSettings() async {
     try {
       final response = await _supabase.schema('sincroapp').from('site_settings').select().eq('key', 'global_config').maybeSingle();
       if (response != null && response['value'] != null) {
          return response['value'];
       }
     } catch (e) {
        // ignore
     }
     return {'status': 'active', 'bypassPassword': ''};
  }

  Future<void> updateSiteSettings({required String status, required String bypassPassword}) async {
     try {
        final val = {
           'status': status,
           'bypassPassword': bypassPassword,
        };
        // Upsert row with key='global_config'
        await _supabase.schema('sincroapp').from('site_settings').upsert({
           'key': 'global_config',
           'value': val,
           'updated_at': DateTime.now().toIso8601String(),
        }, onConflict: 'key');
     } catch (e) {
        debugPrint('❌ [SupabaseService] Erro ao atualizar site settings: $e');
        rethrow;
     }
  }

  // --- FINANCIAL SETTINGS (Admin) ---

  Stream<Map<String, dynamic>> getAdminFinancialSettingsStream() {
      return _supabase.schema('sincroapp').from('site_settings').stream(primaryKey: ['key']).map((event) {
         for (var item in event) {
            if (item['key'] == 'financial_config') {
               return item['value'] as Map<String, dynamic>;
            }
         }
         return <String, dynamic>{}; // Retorna vazio se não existir
      }).handleError((e) {
         return <String, dynamic>{};
      });
  }

  Future<void> updateAdminFinancialSettings(Map<String, dynamic> settings) async {
     try {
        await _supabase.schema('sincroapp').from('site_settings').upsert({
           'key': 'financial_config',
           'value': settings,
           'updated_at': DateTime.now().toIso8601String(),
        }, onConflict: 'key');
     } catch (e) {
        debugPrint('❌ [SupabaseService] Erro ao atualizar financial settings: $e');
        rethrow;
     }
  }

  Future<void> deleteUserData(String uid) async {
     // Chama a function no Node Server (que vamos migrar para usar Supabase Admin)
     // OU chama diretamente Supabase Edge Function se tivermos.
     // Por enquanto, deletamos da tabela pública, e vamos assumir que o Admin limpará Auth manulamente ou via trigger.
     
     try {
        await _supabase.schema('sincroapp').from('users').delete().eq('uid', uid);
     } catch (e) {
        debugPrint('❌ [SupabaseService] Erro ao deletar dados do usuário: $e');
        rethrow;
     }
  }

  // --- ASSISTANT ---

  Future<void> addAssistantMessage(String uid, AssistantMessage msg) async {
    try {
      await _supabase.schema('sincroapp').from('assistant_messages').insert({
        'user_id': uid,
        'role': msg.role,
        'content': msg.content,
        // Serializar ações para JSON
        'actions': msg.actions.map((a) => a.toJson()).toList(), 
        'created_at': msg.time.toIso8601String(),
      });
    } catch (e) {
      debugPrint('❌ [SupabaseService] Erro ao salvar mensagem do assistente: $e');
    }
  }
  Stream<List<TaskModel>> getTodayTasksStream(String uid) {
    return _supabase
        .schema('sincroapp')
        .from('tasks')
        .stream(primaryKey: ['id'])
        .eq('user_id', uid)
        .order('created_at', ascending: false)
        .map((data) {
          final tasks = data.map((item) => _mapTaskFromSupabase(item)).toList();
          
          final now = DateTime.now().toUtc();
          final startOfDay = DateTime.utc(now.year, now.month, now.day);
          final endOfDay = startOfDay.add(const Duration(days: 1));
          
          return tasks.where((task) {
             if (task.dueDate != null) {
                final d = task.dueDate!.toUtc();
                // Check if d is >= startOfDay and < endOfDay
                return !d.isBefore(startOfDay) && d.isBefore(endOfDay);
             }
             
             final c = task.createdAt.toUtc();
             return !c.isBefore(startOfDay) && c.isBefore(endOfDay);
          }).toList()
            ..sort((a, b) => (a.dueDate ?? a.createdAt).compareTo(b.dueDate ?? b.createdAt));
        });
  }

  Stream<List<TaskModel>> getTasksForGoalStream(String uid, String goalId) {
    return _supabase
        .schema('sincroapp')
        .from('tasks')
        .stream(primaryKey: ['id'])
        .order('created_at')
        .map((data) => data
            .where((item) => item['user_id'] == uid && item['journey_id'] == goalId)
            .map((item) => _mapTaskFromSupabase(item))
            .toList());
  }

  Stream<List<TaskModel>> getTasksStreamForRange(String uid, DateTime start, DateTime end) {
    return _supabase
        .schema('sincroapp')
        .from('tasks')
        .stream(primaryKey: ['id'])
        .order('created_at') 
        .map((data) {
           return data
              .where((item) => item['user_id'] == uid)
              .map((item) => _mapTaskFromSupabase(item))
              .where((task) {
                  if (task.dueDate == null) return false;
                  final d = task.dueDate!.toUtc();
                  return !d.isBefore(start.toUtc()) && !d.isAfter(end.toUtc());
              })
              .toList();
        });
  }

  Future<List<TaskModel>> getTasksForToday(String uid) async {
    final now = DateTime.now().toUtc();
    final startOfDay = DateTime.utc(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    final response = await _supabase
        .schema('sincroapp')
        .from('tasks')
        .select()
        .eq('user_id', uid)
        .order('created_at', ascending: false);

    final List<dynamic> data = response;
    final tasks = data.map((item) => _mapTaskFromSupabase(item)).toList();

    return tasks.where((task) {
      if (task.dueDate != null) {
        final d = task.dueDate!.toUtc();
        return !d.isBefore(startOfDay) && d.isBefore(endOfDay);
      }
      final c = task.createdAt.toUtc();
      return !c.isBefore(startOfDay) && c.isBefore(endOfDay);
    }).toList();
  }
}
