// lib/features/notifications/models/notification_model.dart

enum NotificationType {
  system,
  mention,
  share,
  sincroAlert, // Alerta de compatibilidade
  reminder,
  contactRequest, // Solicitação de amizade/contato
  taskInvite,     // Convite para tarefa
  taskUpdate,     // Atualização em tarefa compartilhada
}

class NotificationModel {
  final String id;
  final String userId;
  final NotificationType type;
  final String title;
  final String body;
  final String? relatedItemId;
  final String? relatedItemType; // 'task', 'goal'
  final bool isRead;
  final DateTime createdAt;
  final Map<String, dynamic> metadata;

  NotificationModel({
    required this.id,
    required this.userId,
    required this.type,
    required this.title,
    required this.body,
    this.relatedItemId,
    this.relatedItemType,
    this.isRead = false,
    required this.createdAt,
    this.metadata = const {},
  });

  factory NotificationModel.fromFirestore(Map<String, dynamic> data) {
    return NotificationModel(
      id: data['id'] ?? '',
      userId: data['user_id'] ?? '',
      type: _parseType(data['type']),
      title: data['title'] ?? '',
      body: data['body'] ?? '',
      relatedItemId: data['related_item_id'],
      relatedItemType: data['related_item_type'],
      isRead: data['is_read'] ?? false,
      createdAt: data['created_at'] != null 
          ? DateTime.parse(data['created_at']).toLocal() 
          : DateTime.now(),
      metadata: data['metadata'] ?? {},
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'user_id': userId,
      'type': type.toString().split('.').last, // 'system', 'mention'...
      'title': title,
      'body': body,
      'related_item_id': relatedItemId,
      'related_item_type': relatedItemType,
      'is_read': isRead,
      'created_at': createdAt.toIso8601String(),
      'metadata': metadata,
    };
  }
  
  // Helper para conversão de string para enum
  static NotificationType _parseType(String? value) {
    if (value == null) return NotificationType.system;
    
    // Mapeamento para os valores do ENUM do banco (snake_case)
    switch (value) {
      case 'mention': return NotificationType.mention;
      case 'share': return NotificationType.share;
      case 'sincro_alert': return NotificationType.sincroAlert;
      case 'reminder': return NotificationType.reminder;
      case 'contact_request': return NotificationType.contactRequest;
      case 'task_invite': return NotificationType.taskInvite;
      case 'task_update': return NotificationType.taskUpdate;
      case 'system': 
      default: return NotificationType.system;
    }
  }

  // Helper para converter enum para snake_case (para salvar no banco)
  static String typeToString(NotificationType type) {
    switch (type) {
      case NotificationType.sincroAlert: return 'sincro_alert';
      case NotificationType.contactRequest: return 'contact_request';
      case NotificationType.taskInvite: return 'task_invite';
      case NotificationType.taskUpdate: return 'task_update';
      default: return type.name;
    }
  }
}
