// lib/features/notifications/presentation/notification_center_screen.dart

import 'package:flutter/material.dart';
import 'package:sincro_app_flutter/common/constants/app_colors.dart';
import 'package:sincro_app_flutter/features/notifications/models/notification_model.dart';
import 'package:sincro_app_flutter/services/supabase_service.dart';
import 'package:intl/intl.dart';
import 'package:sincro_app_flutter/features/notifications/presentation/widgets/compatibility_suggestion_modal.dart';

class NotificationCenterScreen extends StatelessWidget {
  final String userId;
  final SupabaseService _supabaseService = SupabaseService();

  NotificationCenterScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    // Layout adaptativo: se for desktop, usamos Dialog style. Se mobile, Scaffold full screen.
    final bool isDesktop = MediaQuery.of(context).size.width >= 720;
    
    final content = Column(
      children: [
        _buildHeader(context),
        Expanded(
          child: StreamBuilder<List<NotificationModel>>(
            stream: _supabaseService.getNotificationsStream(userId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              
              if (snapshot.hasError) {
                return Center(child: Text('Erro: ${snapshot.error}', style: const TextStyle(color: Colors.red)));
              }
              
              final notifications = snapshot.data ?? [];
              
              if (notifications.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.notifications_off_outlined, size: 64, color: AppColors.tertiaryText.withOpacity(0.5)),
                      const SizedBox(height: 16),
                      const Text(
                        'Sem novas notificações',
                        style: TextStyle(color: AppColors.tertiaryText, fontSize: 16),
                      ),
                    ],
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: notifications.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  return _NotificationTile(
                    notification: notifications[index],
                    onTap: () {
                      _handleNotificationTap(context, notifications[index]);
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );

    if (isDesktop) {
       return Dialog(
         backgroundColor: AppColors.cardBackground,
         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
         child: SizedBox(
           width: 450,
           height: 600,
           child: content,
         ),
       );
    }
    
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(child: content),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.close, color: AppColors.secondaryText),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 8),
          const Text(
            'Notificações',
            style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const Spacer(),
          TextButton.icon(
            icon: const Icon(Icons.done_all, size: 18),
            label: const Text('Ler tudo'),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primary,
            ),
            onPressed: () {
               _supabaseService.markAllNotificationsAsRead(userId);
            },
          ),
        ],
      ),
    );
  }

  void _handleNotificationTap(BuildContext context, NotificationModel notification) {
    // 1. Marcar como lida
    if (!notification.isRead) {
      _supabaseService.markNotificationAsRead(notification.id);
    }
    
    // 2. Ação baseada no tipo (Fase F vai expandir isso)
    if (notification.type == NotificationType.sincroAlert) {
      final meta = notification.metadata;
      // Validação básica dos dados necessários
      if (meta['userA_birth'] != null && meta['userB_birth'] != null) {
        showDialog(
          context: context,
          builder: (ctx) => CompatibilitySuggestionModal(
            targetDate: meta['target_date'] != null 
                ? DateTime.parse(meta['target_date']) 
                : DateTime.now(),
            userAName: meta['userA_name'] ?? 'Você',
            userABirth: DateTime.parse(meta['userA_birth']),
            userBName: meta['userB_name'] ?? 'Contato',
            userBBirth: DateTime.parse(meta['userB_birth']),
            taskTitle: meta['task_title'] ?? 'Tarefa Compartilhada', // Pass task title
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Dados de compatibilidade indisponíveis.')),
        );
      }
    }
  }
}

class _NotificationTile extends StatelessWidget {
  final NotificationModel notification;
  final VoidCallback onTap;

  const _NotificationTile({required this.notification, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = _getThemeForType(notification.type);
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: notification.isRead 
              ? Colors.transparent 
              : AppColors.cardBackground.withOpacity(0.5), // Destaque se não lida
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
             color: notification.isRead ? Colors.transparent : theme.color.withOpacity(0.3),
             width: 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Ícone lateral
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: theme.color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(theme.icon, color: theme.color, size: 20),
            ),
            const SizedBox(width: 12),
            // Conteúdo
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    notification.title,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: notification.isRead ? FontWeight.normal : FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    notification.body,
                    style: const TextStyle(color: AppColors.secondaryText, fontSize: 12),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatTime(notification.createdAt),
                    style: const TextStyle(color: AppColors.tertiaryText, fontSize: 10),
                  ),
                ],
              ),
            ),
             // Indicador de não lido (bolinha azul)
             if (!notification.isRead)
               Container(
                 margin: const EdgeInsets.only(top: 8, left: 8),
                 width: 8,
                 height: 8,
                 decoration: const BoxDecoration(
                   color: AppColors.primary,
                   shape: BoxShape.circle,
                 ),
               ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    
    if (diff.inMinutes < 60) return '${diff.inMinutes}m atrás';
    if (diff.inHours < 24) return '${diff.inHours}h atrás';
    return DateFormat('dd/MM').format(time);
  }
  
  _NotificationTheme _getThemeForType(NotificationType type) {
    switch (type) {
      case NotificationType.mention:
        return _NotificationTheme(Icons.alternate_email, AppColors.contact);
      case NotificationType.share:
        return _NotificationTheme(Icons.share, Colors.purpleAccent);
      case NotificationType.sincroAlert:
        // Ex: warning se vibration mismatch, check se ok.
        // Aqui assumimos genérico, mas pode ser dinâmico via metadata
        return _NotificationTheme(Icons.auto_awesome, Colors.amber);
      case NotificationType.reminder:
        return _NotificationTheme(Icons.alarm, Colors.orangeAccent);
      case NotificationType.system:
      default:
        return _NotificationTheme(Icons.info_outline, Colors.blueGrey);
    }
  }
}

class _NotificationTheme {
  final IconData icon;
  final Color color;
  _NotificationTheme(this.icon, this.color);
}
