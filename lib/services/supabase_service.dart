import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart'; // Para TimeOfDay
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sincro_app_flutter/models/user_model.dart';
import 'package:sincro_app_flutter/models/contact_model.dart'; // NOVO
import 'package:sincro_app_flutter/models/subscription_model.dart';
import 'package:sincro_app_flutter/features/tasks/models/task_model.dart';
import 'package:sincro_app_flutter/models/recurrence_rule.dart';
import 'package:postgrest/postgrest.dart';
import 'package:sincro_app_flutter/features/goals/models/goal_model.dart';
import 'package:sincro_app_flutter/features/journal/models/journal_entry_model.dart';
import 'package:sincro_app_flutter/features/assistant/models/assistant_models.dart';
import 'package:sincro_app_flutter/common/utils/username_validator.dart';
import 'package:sincro_app_flutter/services/numerology_engine.dart';
import 'package:sincro_app_flutter/services/harmony_service.dart';
import 'package:intl/intl.dart';
import 'package:sincro_app_flutter/features/notifications/models/notification_model.dart';
import 'package:uuid/uuid.dart';


class SupabaseService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final _harmonyService = HarmonyService();

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
        'username': user.username, // NOVO: Username único
        'first_name': user.primeiroNome,
        'last_name': user.sobrenome,
        'analysis_name': user.nomeAnalise,
        'birth_date': user.dataNasc,
        'gender': user.gender, // NOVO
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
      
      // debugPrint('✅ [SupabaseService] Dados do usuário salvos com sucesso.');
    } catch (e) {
      // debugPrint('❌ [SupabaseService] Erro ao salvar dados do usuário: $e');
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
        // debugPrint('⚠️ [SupabaseService] Usuário não encontrado no Supabase: $uid');
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
        username: data['username'], // NOVO: pode ser null se usuário ainda não criou
        primeiroNome: data['primeiro_nome'] ?? data['first_name'] ?? '', // Fallback para compatibility
        sobrenome: data['sobrenome'] ?? data['last_name'] ?? '',
        plano: 'essencial', // Default legacy plan name
        nomeAnalise: data['nome_analise'] ?? data['analysis_name'] ?? '',
        dataNasc: data['birth_date'] ?? '',
        gender: data['gender'], // NOVO
        isAdmin: data['is_admin'] ?? false,
        dashboardCardOrder: List<String>.from(data['dashboard_card_order'] ?? UserModel.defaultCardOrder),
        dashboardHiddenCards: List<String>.from(data['dashboard_hidden_cards'] ?? []),
        subscription: data['subscription_data'] != null 
            ? SubscriptionModel.fromFirestore(data['subscription_data']) 
            : SubscriptionModel.free(),
      );
    } catch (e) {
      // debugPrint('❌ [SupabaseService] Erro ao buscar usuário: $e');
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
          case 'username': mappedData['username'] = value; break; // NOVO: Username
          case 'primeiroNome': mappedData['first_name'] = value; break;
          case 'sobrenome': mappedData['last_name'] = value; break;
          case 'nomeAnalise': mappedData['analysis_name'] = value; break;
          case 'dataNasc': mappedData['birth_date'] = value; break;
          case 'gender': mappedData['gender'] = value; break; // NOVO
          case 'dashboardCardOrder': mappedData['dashboard_card_order'] = value; break;
          case 'dashboardHiddenCards': mappedData['dashboard_hidden_cards'] = value; break;
          case 'subscription': mappedData['subscription_data'] = value; break; // Se vier o mapa
          default: mappedData[key] = value; // Fallback
        }
      });
      
      mappedData['updated_at'] = DateTime.now().toIso8601String();

      final response = await _supabase
          .schema('sincroapp')
          .from('users')
          .update(mappedData)
          .eq('uid', uid)
          .select();
      
      if (response.isEmpty) {
        throw Exception('Nenhum registro atualizado. Verifique se o UID está correto ou se você tem permissão (RLS).');
      }
    } catch (e) {
      debugPrint('❌ [SupabaseService] Erro ao atualizar usuário: $e');
      rethrow;
    }
  }

  // --- USERNAME METHODS ---

  /// Verifica se um username está disponível (não está em uso)
  /// 
  /// Retorna true se disponível, false se já existe
  Future<bool> isUsernameAvailable(String username) async {
    try {
      final sanitized = username.toLowerCase().trim();
      
      final response = await _supabase
          .schema('sincroapp')
          .from('users')
          .select('username')
          .eq('username', sanitized)
          .maybeSingle();
      
      return response == null; // null = disponível, != null = já existe
    } catch (e) {
      debugPrint('❌ [SupabaseService] Erro ao verificar username: $e');
      return false; // Em caso de erro, assumir indisponível por segurança
    }
  }

  /// Busca usuário por username
  /// 
  /// Retorna UserModel se encontrado, null se não existir
  Future<UserModel?> getUserByUsername(String username) async {
    try {
      final sanitized = username.toLowerCase().trim();
      
      final response = await _supabase
          .schema('sincroapp')
          .from('users')
          .select()
          .eq('username', sanitized)
          .maybeSingle();
      
      if (response == null) return null;
      
      // Reutilizar a mesma lógica de mapeamento do getUserData
      final data = response;
      return UserModel(
        uid: data['uid'],
        email: data['email'] ?? '',
        photoUrl: data['photo_url'],
        username: data['username'],
        primeiroNome: data['primeiro_nome'] ?? data['first_name'] ?? '',
        sobrenome: data['sobrenome'] ?? data['last_name'] ?? '',
        plano: 'essencial',
        nomeAnalise: data['nome_analise'] ?? data['analysis_name'] ?? '',
        dataNasc: data['birth_date'] ?? '',
        gender: data['gender'], // NOVO
        isAdmin: data['is_admin'] ?? false,
        dashboardCardOrder: List<String>.from(data['dashboard_card_order'] ?? UserModel.defaultCardOrder),
        dashboardHiddenCards: List<String>.from(data['dashboard_hidden_cards'] ?? []),
        subscription: data['subscription_data'] != null 
            ? SubscriptionModel.fromFirestore(data['subscription_data']) 
            : SubscriptionModel.free(),
      );
    } catch (e) {
      debugPrint('❌ [SupabaseService] Erro ao buscar usuário por username: $e');
      return null;
    }
  }

  /// Busca usuários por username (autocomplete)
  /// 
  /// Retorna lista de UserModel que correspondem à busca
  /// - query: termo de busca (parcial OK)
  /// - limit: número máximo de resultados (padrão: 10)
  Future<List<UserModel>> searchUsersByUsername(String query, {int limit = 10}) async {
    try {
      if (query.isEmpty) return [];
      
      final sanitized = query.toLowerCase().trim();
      
      // Busca usando ILIKE para match parcial (case-insensitive)
      final response = await _supabase
          .schema('sincroapp')
          .from('users')
          .select()
          .ilike('username', '%$sanitized%')
          .limit(limit);
      
      final List<dynamic> data = response;
      
      return data.map((item) {
        return UserModel(
          uid: item['uid'],
          email: item['email'] ?? '',
          photoUrl: item['photo_url'],
          username: item['username'],
          primeiroNome: item['primeiro_nome'] ?? item['first_name'] ?? '',
          sobrenome: item['sobrenome'] ?? item['last_name'] ?? '',
          plano: 'essencial',
          nomeAnalise: item['nome_analise'] ?? item['analysis_name'] ?? '',
          dataNasc: item['birth_date'] ?? '',
          gender: item['gender'], // NOVO
          isAdmin: item['is_admin'] ?? false,
          dashboardCardOrder: List<String>.from(item['dashboard_card_order'] ?? UserModel.defaultCardOrder),
          dashboardHiddenCards: List<String>.from(item['dashboard_hidden_cards'] ?? []),
          subscription: item['subscription_data'] != null 
              ? SubscriptionModel.fromFirestore(item['subscription_data']) 
              : SubscriptionModel.free(),
        );
      }).toList();
    } catch (e) {
      debugPrint('❌ [SupabaseService] Erro ao buscar usuários por username: $e');
      return [];
    }
  }

  // --- NOTIFICAÇÕES (NOVO) ---

  Stream<List<NotificationModel>> getNotificationsStream(String uid) {
    return _supabase
        .schema('sincroapp')
        .from('notifications')
        .stream(primaryKey: ['id'])
        .eq('user_id', uid)
        .order('created_at', ascending: false)
        .map((data) => data.map((json) => NotificationModel.fromFirestore(json)).toList());
  }
  
  Stream<int> getUnreadNotificationsCountStream(String uid) {
     return _supabase
        .schema('sincroapp')
        .from('notifications')
        .stream(primaryKey: ['id'])
        .eq('user_id', uid)
        .map((data) => data.where((json) => json['is_read'] == false).length);
  }

  Future<void> markNotificationAsRead(String notificationId) async {
    try {
      await _supabase
          .schema('sincroapp')
          .from('notifications')
          .update({'is_read': true})
          .eq('id', notificationId);
    } catch (e) {
      debugPrint('❌ [SupabaseService] Erro ao marcar notificação como lida: $e');
    }
  }
  
  Future<void> markAllNotificationsAsRead(String uid) async {
    try {
      await _supabase
          .schema('sincroapp')
          .from('notifications')
          .update({'is_read': true})
          .eq('user_id', uid)
          .eq('is_read', false);
    } catch (e) {
      debugPrint('❌ [SupabaseService] Erro ao marcar todas como lidas: $e');
    }
  }

  Future<void> deleteNotifications(List<String> ids) async {
    if (ids.isEmpty) return;
    try {
      // Format: (id1,id2,id3) for IN operator
      final idsString = '(${ids.join(',')})';
      await _supabase.schema('sincroapp').from('notifications').delete().filter('id', 'in', idsString);
      debugPrint('✅ [SupabaseService] ${ids.length} notificações deletadas');
    } catch (e) {
      debugPrint('❌ [SupabaseService] Erro ao deletar notificações: $e');
      rethrow; // Propagar erro para UI mostrar feedback
    }
  }

  Future<void> markNotificationsAsRead(List<String> ids) async {
    if (ids.isEmpty) return;
    try {
      final idsString = '(${ids.join(',')})';
      await _supabase
          .schema('sincroapp')
          .from('notifications')
          .update({'is_read': true})
          .filter('id', 'in', idsString);
      debugPrint('✅ [SupabaseService] ${ids.length} notificações marcadas como lidas');
    } catch (e) {
      debugPrint('❌ [SupabaseService] Erro ao marcar notificações como lidas: $e');
      rethrow;
    }
  }

  /// Método helper para criar notificação (Uso interno no app ao compartilhar/mencionar)
  /// Em um cenário ideal, isso seria feito via Database Trigger ou Edge Function,
  /// mas para o MVP faremos direto no client.
  Future<void> sendNotification({
    required String toUserId,
    required NotificationType type,
    required String title,
    required String body,
    String? relatedItemId,
    String? relatedItemType,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final notifData = {
        'user_id': toUserId,
        'type': NotificationModel.typeToString(type),
        'title': title,
        'body': body,
        'related_item_id': relatedItemId,
        'related_item_type': relatedItemType,
        'is_read': false,
        'created_at': DateTime.now().toIso8601String(),
        'metadata': metadata ?? {},
      };
      
      await _supabase.schema('sincroapp').from('notifications').insert(notifData);
    } catch (e) {
        debugPrint('❌ [SupabaseService] Erro ao enviar notificação: $e');
    }
  }

  // --- EVENTS (Calendar) ---

  /// Busca a lista de contatos do usuário (Retorna UserModel para features avançadas)
  Future<List<UserModel>> getUserContacts(String uid) async {
    try {
      final response = await _supabase
          .schema('sincroapp')
          .from('user_contacts')
          .select('contact_user_id, status, users!contact_user_id(*)') 
          .eq('user_id', uid)
          .eq('status', 'active')
          .order('created_at');

      final List<UserModel> contacts = [];

      for (final item in response) {
        final userData = item['users'];
        if (userData != null) {
          contacts.add(UserModel(
            uid: userData['uid'],
            email: userData['email'] ?? '',
            photoUrl: userData['photo_url'],
            username: userData['username'],
            primeiroNome: userData['primeiro_nome'] ?? userData['first_name'] ?? '',
            sobrenome: userData['sobrenome'] ?? userData['last_name'] ?? '',
            nomeAnalise: userData['nome_analise'] ?? userData['analysis_name'] ?? '',
            dataNasc: userData['birth_date'] ?? '',
            isAdmin: userData['is_admin'] ?? false,
            plano: 'essencial', // Default for contact view
            dashboardCardOrder: [], // Default empty for contacts
            // Mock or Default for subscription since it's just a contact view
            subscription: SubscriptionModel.free(),
          ));
        }
      }
      return contacts;
    } catch (e) {
      debugPrint('❌ [SupabaseService] Erro ao buscar contatos (UserModel): $e');
      return [];
    }
  }

  /// Busca a lista de contatos do usuário (Retorna ContactModel para compatibilidade legacy)
  Future<List<ContactModel>> getContacts(String uid) async {
    try {
      final response = await _supabase
          .schema('sincroapp')
          .from('user_contacts')
          .select('contact_user_id, status, users!contact_user_id(uid, username, first_name, last_name, email, photo_url)')
          .eq('user_id', uid)
          .order('created_at');

      final List<dynamic> data = response;

      return data.map((item) {
        final userData = item['users'] as Map<String, dynamic>;
        final status = item['status'] as String;
        
        final firstName = (userData['first_name'] ?? '').toString().trim();
        final lastName = (userData['last_name'] ?? '').toString().trim();
        
        // Logic fixed: Prevent duplication if firstName already contains lastName
        String displayName;
        if (firstName.isNotEmpty) {
           if (firstName.toLowerCase().endsWith(lastName.toLowerCase())) {
             displayName = firstName;
           } else {
             displayName = '$firstName $lastName'.trim();
           }
        } else {
           displayName = userData['email'] ?? '';
        }

        return ContactModel(
          userId: item['contact_user_id'],
          username: userData['username'] ?? '',
          displayName: displayName,
          photoUrl: userData['photo_url'],
          status: status,
        );
      }).toList();
    } catch (e) {
      debugPrint('❌ [SupabaseService] Erro ao buscar contatos (ContactModel): $e');
      return [];
    }
  }

  /// Adiciona um usuário aos contatos (Status inicial: PENDING)
  Future<void> addContact(String uid, String contactUid) async {
    try {
      // Cria registro para o solicitante (user -> contact) como 'pending_outgoing'
      await _supabase.schema('sincroapp').from('user_contacts').upsert({
        'user_id': uid,
        'contact_user_id': contactUid,
        'status': 'pending', // Waiting for acceptance
      }, onConflict: 'user_id, contact_user_id');

    } catch (e) {
      debugPrint('❌ [SupabaseService] Erro ao adicionar contato: $e');
      rethrow;
    }
  }

  /// Responde a uma solicitação de contato
  Future<void> respondToContactRequest({
    required String uid, 
    required String contactUid, 
    required bool accept,
  }) async {
    try {
      // Chama função RPC no schema public
      await _supabase.rpc('respond_to_contact_request', params: {
        'p_responder_uid': uid,
        'p_requester_uid': contactUid,
        'p_accept': accept,
      });
      
      if (accept) {
        // Enviar notificação de confirmação para quem solicitou
        final responderData = await getUserData(uid);
        final responderName = responderData?.username ?? 'Alguém';
        await sendNotification(
          toUserId: contactUid,
          type: NotificationType.contactAccepted,
          title: '✅ Sincronia Aceita!',
          body: '@$responderName aceitou seu pedido de sincronia.',
          metadata: {'responder_uid': uid, 'responder_name': responderName},
        );
        debugPrint('✅ [SupabaseService] Contato aceito: $uid <-> $contactUid');
      } else {
        debugPrint('✅ [SupabaseService] Contato recusado: $uid <-> $contactUid');
      }
    } catch (e) {
      debugPrint('❌ [SupabaseService] Erro ao responder contato: $e');
      rethrow;
    }
  }

  /// Remove um usuário dos contatos
  Future<void> removeContact(String uid, String contactUid) async {
    try {
      await _supabase
          .schema('sincroapp')
          .from('user_contacts')
          .delete()
          .match({'user_id': uid, 'contact_user_id': contactUid});
          
      // Opcional: remover o reverso também para consistência
    } catch (e) {
      debugPrint('❌ [SupabaseService] Erro ao remover contato: $e');
      rethrow;
    }
  }

  /// Bloqueia um contato
  Future<void> blockContact(String uid, String contactUid) async {
    try {
      // Upsert para garantir que crie se não existir, ou atualize se já existir
      await _supabase.schema('sincroapp').from('user_contacts').upsert({
        'user_id': uid,
        'contact_user_id': contactUid,
        'status': 'blocked',
      }, onConflict: 'user_id, contact_user_id');
    } catch (e) {
      debugPrint('❌ [SupabaseService] Erro ao bloquear contato: $e');
      rethrow;
    }
  }

  /// Desbloqueia um contato (volta para active)
  Future<void> unblockContact(String uid, String contactUid) async {
    try {
      await _supabase
          .schema('sincroapp')
          .from('user_contacts')
          .update({'status': 'active'})
          .match({'user_id': uid, 'contact_user_id': contactUid});
    } catch (e) {
      debugPrint('❌ [SupabaseService] Erro ao desbloquear contato: $e');
      rethrow;
    }
  }
  
  // --- COMPATIBILITY HELPER ---
  
  /// Calcula score de compatibilidade e sugere datas
  Future<Map<String, dynamic>> checkCompatibility({
    required List<String> contactIds, 
    required DateTime date,
    required String currentUserId,
  }) async {
    if (contactIds.isEmpty) return {'score': 1.0, 'status': 'good'};
    
    // Pegar data nasc do owner
    final ownerData = await _supabase.schema('sincroapp').from('users').select('birth_date').eq('uid', currentUserId).maybeSingle();
    
    if (ownerData == null || ownerData['birth_date'] == null) {
       return {'score': 1.0, 'status': 'unknown_owner_birth'};
    }
    final ownerBirth = DateFormat('dd/MM/yyyy').parse(ownerData['birth_date']);
    
    // Pegar datas nasc dos contatos
     final contactsResponse = await _supabase.schema('sincroapp').from('users').select('uid, birth_date').inFilter('uid', contactIds);
     final List<dynamic> contactsData = contactsResponse;
     
     if (contactsData.isEmpty) return {'score': 1.0, 'status': 'good'};
    
    double totalScore = 0;
    int count = 0;
    
    for (var c in contactsData) {
       if (c['birth_date'] == null) continue;
       final cBirth = DateFormat('dd/MM/yyyy').parse(c['birth_date']);
       final score = _harmonyService.calculateCompatibilityScore(
          date: date,
          birthDateA: ownerBirth,
          birthDateB: cBirth,
       );
       totalScore += score;
       count++;
    }
    
    final avgScore = count > 0 ? totalScore / count : 1.0;
    
    // Se score ruim (< 0.6), buscar 3 próximas datas boas
    List<DateTime> suggestions = [];
    if (avgScore < 0.6) {
       DateTime candidate = date.add(const Duration(days: 1));
       int found = 0;
       int attempts = 0;
       while (found < 3 && attempts < 30) {
           double candTotal = 0;
           int candCount = 0;
           for (var c in contactsData) {
             if (c['birth_date'] == null) continue;
             final cBirth = DateFormat('dd/MM/yyyy').parse(c['birth_date']);
             final score = _harmonyService.calculateCompatibilityScore(
                date: candidate,
                birthDateA: ownerBirth,
                birthDateB: cBirth,
             );
             candTotal += score;
             candCount++;
          }
          final candAvg = candCount > 0 ? candTotal / candCount : 0.0;
          if (candAvg >= 0.75) { // Threshold de compatibilidade boa
             suggestions.add(candidate);
             found++;
          }
          candidate = candidate.add(const Duration(days: 1));
          attempts++;
       }
    }
    
    return {
      'score': avgScore,
      'status': avgScore >= 0.6 ? 'good' : 'bad',
      'suggestions': suggestions,
    };
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
        'shared_with': [
          ...task.sharedWith, 
          ...UsernameValidator.extractMentionsFromText(task.text)
        ].toSet().toList(), // NOVO: Parse mentions + explicit shared
        'task_type': (task.reminderTime != null || 
                     (task.dueDate != null && (task.dueDate!.hour != 0 || task.dueDate!.minute != 0)))
                     ? 'appointment' 
                     : 'task',
        'duration_minutes': task.durationMinutes,
      };
      
      final response = await _supabase.schema('sincroapp').from('tasks').insert(taskData).select().single();
      final newTaskId = response['id']; // Get the generated ID

      // --- SINCRO MATCH LOGIC (INTERNAL) ---
      final newSharedUsers = [
          ...task.sharedWith, 
          ...UsernameValidator.extractMentionsFromText(task.text)
      ].toSet().toList();
      
      if (newSharedUsers.isNotEmpty && task.dueDate != null) {
        _handleSincroMatchLogic(uid, newTaskId, task.text, task.dueDate!, newSharedUsers);
      }
      // -------------------------------------
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
      // 1. Fetch current task state to compare
      final currentTaskRes = await _supabase.schema('sincroapp').from('tasks').select().eq('id', task.id).single();
      final currentTask = _mapTaskFromSupabase(currentTaskRes);

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
        'shared_with': [
          ...task.sharedWith, 
          ...UsernameValidator.extractMentionsFromText(task.text)
        ].toSet().toList(),
        'task_type': (task.reminderTime != null || 
                     (task.dueDate != null && (task.dueDate!.hour != 0 || task.dueDate!.minute != 0)))
                     ? 'appointment' 
                     : 'task',
        'duration_minutes': task.durationMinutes,
      };
      
      await _supabase
          .schema('sincroapp')
          .from('tasks')
          .update(taskData)
          .eq('id', task.id);

      // --- SINCRO SHARE UPDATE LOGIC ---
      final usersToNotify = [
          ...task.sharedWith, 
          ...UsernameValidator.extractMentionsFromText(task.text)
      ].toSet().toList();

      if (usersToNotify.isNotEmpty) {
          // Check for diffs
          final List<String> changes = [];
          if (currentTask.text != task.text) changes.add('Título');
          if (currentTask.dueDate != task.dueDate) changes.add('Data');
          if (currentTask.reminderTime != task.reminderTime) changes.add('Horário do lembrete');
          
          if (changes.isNotEmpty) {
             final ownerData = await _supabase.schema('sincroapp').from('users').select('username').eq('uid', uid).single();
             final ownerName = ownerData['username'] ?? 'Alguém';
             
             for (final username in usersToNotify) {
                final userData = await _supabase.schema('sincroapp').from('users').select('uid').eq('username', username).maybeSingle();
                if (userData == null) continue;
                
                final contactUid = userData['uid'];
                if (contactUid == uid) continue;

                final sanitizedTitle = task.text.replaceAll(RegExp(r'@[\w.]+'), '').trim();

                await sendNotification(
                  toUserId: contactUid,
                  type: NotificationType.taskUpdate,
                  title: '📝 Tarefa Atualizada',
                  body: '@$ownerName alterou "$sanitizedTitle": ${changes.join(", ")}',
                  relatedItemId: task.id,
                  relatedItemType: 'task',
                  metadata: {
                    'changes': changes,
                    'task_title': sanitizedTitle,
                    'updated_by': ownerName,
                  }
                );
             }
          }
      }

      // --- SINCRO MATCH LOGIC (For New Invites) ---
      // Check for newly added people
      final oldShared = currentTask.sharedWith.toSet();
      final newShared = usersToNotify.toSet();
      final addedUsers = newShared.difference(oldShared);
      
      if (addedUsers.isNotEmpty && task.dueDate != null) {
         // Send invites (Sincro Alert) only to new people
        _handleSincroMatchLogic(uid, task.id, task.text, task.dueDate!, addedUsers.toList());
      }
      // -------------------------------------

    } catch (e) {
      debugPrint('❌ [SupabaseService] Erro ao atualizar tarefa: $e');
      rethrow;
    }
  }

  /// Lógica Interna de Sincro Match (Substitui N8N para alertas)
  Future<void> _handleSincroMatchLogic(String ownerId, String taskId, String taskTitle, DateTime dueDate, List<String> sharedUsernames) async {
    try {
      // 1. Buscar dados do Owner (User A)
      final ownerData = await _supabase.schema('sincroapp').from('users').select('uid, username, birth_date').eq('uid', ownerId).single();
      final ownerBirthStr = ownerData['birth_date'];

      if (ownerBirthStr == null) return; // Se não tem data nasc, não calcula
      
      final ownerBirth = DateFormat('dd/MM/yyyy').parse(ownerBirthStr);

      // 2. Para cada usuário compartilhado (User B)
      for (final username in sharedUsernames) {
        // Busca User B pelo username
        final userData = await _supabase.schema('sincroapp').from('users').select('uid, username, birth_date').eq('username', username).maybeSingle();
        
        if (userData == null || userData['birth_date'] == null) continue;

        final contactId = userData['uid'];
        if (contactId == ownerId) continue; // Não comparar consigo mesmo

        final contactBirth = DateFormat('dd/MM/yyyy').parse(userData['birth_date']);

        // 3. Calcular Compatibilidade
        final score = _harmonyService.calculateCompatibilityScore(
          date: dueDate,
          birthDateA: ownerBirth,
          birthDateB: contactBirth,
        );

        // 4. Se for compatibilidade baixa/média, criar notificação Sincro Alert
        // AGORA: Sempre envia para permitir o fluxo de "Aceitar/Recusar"
        if (score < 0.9 || true) { // <--- Sempre enviar para testar o fluxo
           
           final sanitizedTitle = taskTitle.replaceAll(RegExp(r'@[\w.]+'), '').trim();

           await sendNotification(
             toUserId: contactId, // Avisar o destinatário (User B)
             type: NotificationType.taskInvite,
             title: '📅 Convite de Agendamento',
             body: '@${ownerData['username']} te convidou para: "$sanitizedTitle" em ${DateFormat('dd/MM').format(dueDate)}.',
             metadata: {
               'sender_username': ownerData['username'],  // Para destaque azul no modal
               'task_text': sanitizedTitle,                // Texto da tarefa
               'target_date': dueDate.toIso8601String(),
               'compatibility_score': score,
               'task_id': taskId,      // Needed for response
               'owner_id': ownerId,    // Needed for response
               'userA_birth': ownerBirth.toIso8601String(),
               'userB_birth': contactBirth.toIso8601String(),
             }
           );
        }
      }
    } catch (e) {
      // debugPrint('⚠️ [SincroMatch] Erro ao processar compatibilidade: $e');
    }
  }
  /// Responde a um convite de tarefa (Aceitar/Recusar)
  /// Responde a um convite de tarefa (Aceitar/Recusar)
  Future<void> respondToInvitation({
    required String taskId,
    required String ownerId,
    required String responderUid,
    required String responderName,
    required bool accepted,
    // Dados da tarefa vindos do metadata (para bypass de RLS)
    String? taskText,
    String? targetDate,
    String? senderUsername, // Username de quem compartilhou
    String? notificationId, // ID da notificação (para marcar como respondida)
    Map<String, dynamic>? currentMetadata, // Metadata atual (para preservar)
  }) async {
    try {
      // 1. Notificar o dono da tarefa
      if (accepted) {
        await sendNotification(
          toUserId: ownerId,
          type: NotificationType.contactAccepted, // Reutilizando para confirmações positivas
          title: '✅ Convite Aceito!',
          body: '@$responderName aceitou participar da sua tarefa.',
          relatedItemId: taskId,
          metadata: {
            'action': 'accepted',
            'responder_name': responderName,
          }
        );
        
        
        // 2. CRITICAL: Criar uma cópia da tarefa para o usuário que aceitou
        // debugPrint('🔍 [SupabaseService] Tentando buscar tarefa $taskId...');
        
        
        // Tentar buscar tarefa original (pode falhar por RLS)
        Map<String, dynamic>? taskResponse;
        try {
          taskResponse = await _supabase.schema('sincroapp').from('tasks')
              .select()
              .eq('id', taskId)
              .maybeSingle();
        } catch (e) {
          // debugPrint('⚠️ [SupabaseService] Erro ao buscar tarefa (RLS?): $e');
        }
        
        // 3. Calcular o dia pessoal do USUÁRIO QUE ACEITA (não do dono)
        int? personalDay;
        DateTime? dueDate;
        
        final dateStr = taskResponse?['due_date'] ?? targetDate;
        if (dateStr != null) {
          dueDate = DateTime.tryParse(dateStr is String ? dateStr : dateStr.toString());
        }
        
        if (dueDate != null) {
          // Buscar data de nascimento do usuário que está aceitando
          try {
            final responderData = await _supabase.schema('sincroapp').from('users')
                .select('birth_date')
                .eq('uid', responderUid)
                .maybeSingle();
            
            if (responderData != null && responderData['birth_date'] != null) {
              final birthDateStr = responderData['birth_date'] as String;
              personalDay = NumerologyEngine.calculatePersonalDay(dueDate, birthDateStr);
              // debugPrint('✅ [SupabaseService] Dia pessoal calculado: $personalDay');
            }
          } catch (e) {
            // debugPrint('⚠️ [SupabaseService] Erro ao calcular dia pessoal: $e');
          }
        }
        
        // 4. Preparar texto da tarefa com @mention do sender
        String finalText = taskResponse?['text'] ?? taskText ?? 'Tarefa compartilhada';
        final sender = senderUsername ?? '';
        if (sender.isNotEmpty && !finalText.contains('@$sender')) {
          // Adicionar @sender no final se ainda não estiver presente
          finalText = '$finalText @$sender';
        }
        
        // 5. Criar nova tarefa para o usuário que aceitou
        final String newTaskId = Uuid().v4();
        
        final Map<String, dynamic> newTaskData = {
          'id': newTaskId,
          'user_id': responderUid, // Nova tarefa pertence ao usuário que aceitou
          'text': finalText,
          'due_date': taskResponse?['due_date'] ?? targetDate,
          'tags': taskResponse?['tags'] ?? [],
          'shared_with': [],
          'created_at': DateTime.now().toUtc().toIso8601String(),
        };
        
        // Adicionar personalDay se calculado
        if (personalDay != null && personalDay > 0) {
          newTaskData['personal_day'] = personalDay;
        }
        
        // Adicionar campos opcionais apenas se existirem
        if (taskResponse != null) {
          if (taskResponse['reminder_time'] != null) newTaskData['reminder_time'] = taskResponse['reminder_time'];
          if (taskResponse['recurrence_type'] != null) newTaskData['recurrence_type'] = taskResponse['recurrence_type'];
          if (taskResponse['recurrence_days_of_week'] != null) newTaskData['recurrence_days_of_week'] = taskResponse['recurrence_days_of_week'];
          if (taskResponse['recurrence_end_date'] != null) newTaskData['recurrence_end_date'] = taskResponse['recurrence_end_date'];
          if (taskResponse['journey_id'] != null) newTaskData['journey_id'] = taskResponse['journey_id'];
        }
        
        try {
          await _supabase.schema('sincroapp').from('tasks').insert(newTaskData);
          // debugPrint('✅ [SupabaseService] Tarefa $newTaskId criada para usuário $responderUid com personalDay=$personalDay');
        } catch (insertError) {
          // debugPrint('❌ [SupabaseService] Erro ao inserir tarefa: $insertError');
        }
        
      } else {
        await sendNotification(
          toUserId: ownerId,
          type: NotificationType.system,
          title: '❌ Convite Recusado',
          body: '@$responderName não poderá participar da tarefa.',
          relatedItemId: taskId,
          metadata: {
            'action': 'declined',
            'responder_name': responderName,
          }
        );
        
        // Se recusou, remover da lista shared_with
        final taskResponse = await _supabase.schema('sincroapp').from('tasks').select('shared_with, text').eq('id', taskId).single();
        final List<dynamic> currentShared = taskResponse['shared_with'] ?? [];
        
        // Tentamos remover pelo username 
        final userResponse = await _supabase.schema('sincroapp').from('users').select('username').eq('uid', responderUid).single();
        final String username = userResponse['username'];

        if (currentShared.contains(username)) {
          final newShared = List<String>.from(currentShared)..remove(username);
          await _supabase.schema('sincroapp').from('tasks').update({'shared_with': newShared}).eq('id', taskId);
        }
      }
      
      // Atualizar metadata da notificação para marcar como respondida
      if (notificationId != null) {
        final newMeta = Map<String, dynamic>.from(currentMetadata ?? {});
        newMeta['action_taken'] = true;
        
        try {
          await _supabase.schema('sincroapp').from('notifications')
              .update({'metadata': newMeta, 'is_read': true}) // Também marca como lida
              .eq('id', notificationId);
        } catch (e) {
          // debugPrint('⚠️ [SupabaseService] Erro ao atualizar status da notificação: $e');
        }
      }

    } catch (e) {
      // debugPrint('❌ [SupabaseService] Erro ao responder convite: $e');
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
      // debugPrint('❌ [SupabaseService] Erro ao deletar tarefa: $e');
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
      taskType: data['task_type'], // Carrega o tipo do banco
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
      durationMinutes: data['duration_minutes'],
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

         await _supabase.schema('sincroapp').from('journal_entries').update(mapped).eq('user_id', uid).eq('id', entryId);
      } catch (e) {
          debugPrint('❌ [SupabaseService] Erro ao atualizar diário: $e');
          rethrow;
      }
  }

  // --- JOURNAL ---

  Future<void> deleteJournalEntry(String uid, String entryId) async {
     await _supabase.schema('sincroapp').from('journal_entries').delete().eq('id', entryId);
  }

  // --- USAGE LOGGING ---



  // --- USAGE LOGGING ---

  Future<void> logUsage({
    required String requestType,
    required int totalTokens,
    String? modelName,
  }) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      // Tenta gravar no schema 'sincroapp' onde a tabela foi criada
      await _supabase.schema('sincroapp').from('usage_logs').insert({
        'user_id': user.id,
        'request_type': requestType,
        'tokens_total': totalTokens,
        'model_name': modelName ?? 'gpt-4o-mini',
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('❌ [SupabaseService] Erro ao logar uso: $e');
    }
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
       
       double grossMrr = 0.0;
       
       int totalAiUsed = 0;
       
       // Demographics
       final Map<String, int> ageBuckets = {
         '18-24': 0, '25-34': 0, '35-44': 0, '45-54': 0, '55+': 0, 'N/A': 0
       };
       final Map<String, int> sexDistribution = {
         'Masculino': 0, 'Feminino': 0, 'Outro': 0, 'N/A': 0
       };
       
       final now = DateTime.now();

       for (final user in users) {
          // 1. Plan & Financials logic
          final plan = user.subscription.plan;
          
          if (user.subscription.isActive) {
             activeCount++;
             switch (plan) {
               case SubscriptionPlan.free:
                 freeCount++; 
                 break;
               case SubscriptionPlan.plus:
                 plusCount++;
                 grossMrr += 19.90;
                 break;
               case SubscriptionPlan.premium:
                 premiumCount++;
                 grossMrr += 39.90;
                 break;
             }
          } else {
             // Conta usuários expirados baseado no último plano conhecido ou fallback
             switch (plan) {
               case SubscriptionPlan.free: freeCount++; break;
               case SubscriptionPlan.plus: plusCount++; break;
               case SubscriptionPlan.premium: premiumCount++; break;
             }
             expiredCount++;
          }
          
          // 2. AI Usage
          totalAiUsed += user.subscription.aiSuggestionsUsed;

          // 3. Demographics - Age
          if (user.dataNasc.isNotEmpty) {
             try {
               // Formato esperado DD/MM/YYYY
               final parts = user.dataNasc.split('/');
               if (parts.length == 3) {
                 final birthDate = DateTime(int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
                 final age = now.year - birthDate.year;
                 
                 if (age >= 18 && age <= 24) ageBuckets['18-24'] = (ageBuckets['18-24'] ?? 0) + 1;
                 else if (age >= 25 && age <= 34) ageBuckets['25-34'] = (ageBuckets['25-34'] ?? 0) + 1;
                 else if (age >= 35 && age <= 44) ageBuckets['35-44'] = (ageBuckets['35-44'] ?? 0) + 1;
                 else if (age >= 45 && age <= 54) ageBuckets['45-54'] = (ageBuckets['45-54'] ?? 0) + 1;
                 else if (age >= 55) ageBuckets['55+'] = (ageBuckets['55+'] ?? 0) + 1;
                 else ageBuckets['N/A'] = (ageBuckets['N/A'] ?? 0) + 1; // Menor de 18 ou erro
               } else {
                 ageBuckets['N/A'] = (ageBuckets['N/A'] ?? 0) + 1;
               }
             } catch (e) {
               ageBuckets['N/A'] = (ageBuckets['N/A'] ?? 0) + 1;
             }
          } else {
            ageBuckets['N/A'] = (ageBuckets['N/A'] ?? 0) + 1;
          }

          // 3. Demographics - Sex
          // Supõe-se campo 'genre' ou similar no futuro, por enquanto usando lógica básica se existir ou N/A
          // Se não houver campo sexo no UserModel, deixamos N/A ou Mock por enquanto para o User preencher
          sexDistribution['N/A'] = (sexDistribution['N/A'] ?? 0) + 1;
       }
       
        // 4. Calculate Total Token Usage & Cost (Approximation)
        // Fetch all usage logs (warning: heavy query, should be RPC in prod)
        int totalTokens = 0;
        int totalRequests = 0;
        
        try {
          // Buscando apenas a coluna tokens_total para reduzir tráfego
          // Nota: RPC 'get_total_token_usage' seria ideal
          final usageResponse = await _supabase.schema('sincroapp').from('usage_logs').select('tokens_total');
          final List<dynamic> usageList = usageResponse;
          
          totalRequests = usageList.length;
          totalTokens = usageList.fold<int>(0, (sum, item) => sum + (item['tokens_total'] as int? ?? 0));
        } catch (e) {
          debugPrint('⚠️ Erro ao buscar usage_logs: $e');
          // Fallback to subscription stats
          totalRequests = totalAiUsed; 
        }

        // Custo estimado: ~R$0.05 por requisição (Legacy) OU Baseado em Tokens
        // GPT-4o-mini: ~$0.20 per 1M tokens (Blended)
        double aiCost = 0.0;
        if (totalTokens > 0) {
            aiCost = (totalTokens / 1000000) * 0.20 * 6.0; // USD to BRL (~6.0)
        } else {
            aiCost = totalAiUsed * 0.05; // Fallback Legacy
        }
        
        final double netProfit = grossMrr - aiCost;
        
        return {
          'totalUsers': users.length,
          'freeUsers': freeCount,
          'plusUsers': plusCount,
          'premiumUsers': premiumCount,
          'activeSubscriptions': activeCount,
          'expiredSubscriptions': expiredCount,
          
          'estimatedMRR': grossMrr,
          'totalAiUsed': totalRequests, // Total Requests (Real or Legacy)
          'totalAiTokens': totalTokens, // New Metric
          'totalAiCost': aiCost,
          'netProfit': netProfit,
          
          'demographics': {
             'age': ageBuckets,
             'sex': sexDistribution,
          },
          
          'lastUpdated': DateTime.now().toUtc(),
        };
    } catch (e) {
       debugPrint('❌ [SupabaseService] Erro ao calcular stats: $e');
       return {
          'totalUsers': 0, 'estimatedMRR': 0.0,
       };
    }
  }

  Future<Map<String, int>> getUserTokenUsageMap() async {
     try {
        final response = await _supabase.schema('sincroapp').from('usage_logs').select('user_id, tokens_total');
        final Map<String, int> usageMap = {};
        for (var item in response) {
           final uid = item['user_id'] as String;
           final tokens = item['tokens_total'] as int? ?? 0;
           usageMap[uid] = (usageMap[uid] ?? 0) + tokens;
        }
        return usageMap;
     } catch (e) {
        debugPrint('Error fetching user token usage: $e');
        return {};
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
          
          final now = DateTime.now(); // Local time
          final startOfDay = DateTime(now.year, now.month, now.day);
          final endOfDay = startOfDay.add(const Duration(days: 1));
          
          return tasks.where((task) {
             if (task.dueDate != null) {
                // dueDate já é convertido para local no _mapTaskFromSupabase?
                // Se _parseDateAsLocal retorna local, então 'd' já está ok.
                // Mas para garantir, usamos .toLocal()
                final d = task.dueDate!.toLocal();
                return !d.isBefore(startOfDay) && d.isBefore(endOfDay);
             }
             
             final c = task.createdAt.toLocal();
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
    final now = DateTime.now(); // Local Time
    final startOfDay = DateTime(now.year, now.month, now.day);
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
        final d = task.dueDate!.toLocal();
        return !d.isBefore(startOfDay) && d.isBefore(endOfDay);
      }
      final c = task.createdAt.toLocal();
      return !c.isBefore(startOfDay) && c.isBefore(endOfDay);
    }).toList();
  }
  }

  /// Fetches release notes for a specific version from Supabase
  Future<Map<String, dynamic>?> getAppVersionDetails(String version) async {
    try {
      final response = await _supabase
          .schema('sincroapp')
          .from('app_versions')
          .select()
          .eq('version', version)
          .maybeSingle();
      return response;
    } catch (e) {
      debugPrint('Error fetching app version details: $e');
      return null;
    }
  }
}
