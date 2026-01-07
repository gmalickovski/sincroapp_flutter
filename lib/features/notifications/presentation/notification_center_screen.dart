// lib/features/notifications/presentation/notification_center_screen.dart

import 'package:flutter/material.dart';
import 'package:sincro_app_flutter/common/constants/app_colors.dart';
import 'package:sincro_app_flutter/features/notifications/models/notification_model.dart';
import 'package:sincro_app_flutter/services/supabase_service.dart';
import 'package:intl/intl.dart';
import 'package:sincro_app_flutter/features/notifications/presentation/widgets/compatibility_suggestion_modal.dart';
import 'package:sincro_app_flutter/features/notifications/presentation/widgets/notification_detail_modal.dart';

class NotificationCenterScreen extends StatefulWidget {
  final String userId;

  const NotificationCenterScreen({super.key, required this.userId});

  @override
  State<NotificationCenterScreen> createState() => _NotificationCenterScreenState();
}

class _NotificationCenterScreenState extends State<NotificationCenterScreen> {
  final SupabaseService _supabaseService = SupabaseService();
  
  // State
  String _selectedFilter = 'all'; // all, invites, tasks, system
  Set<String> _selectedIds = {};
  bool _isSelectionMode = false;

  void _toggleSelectionMode(String? initialId) {
    setState(() {
      _isSelectionMode = !_isSelectionMode;
      _selectedIds.clear();
      if (_isSelectionMode && initialId != null) {
        _selectedIds.add(initialId);
      }
    });
  }

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
        if (_selectedIds.isEmpty) _isSelectionMode = false;
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _selectAll(List<String> allIds) {
    setState(() {
      if (_selectedIds.length == allIds.length) {
        _selectedIds.clear();
      } else {
        _selectedIds.addAll(allIds);
      }
    });
  }

  void _deleteSelected() async {
    final ids = _selectedIds.toList();
    await _supabaseService.deleteNotifications(ids);
    setState(() {
      _isSelectionMode = false;
      _selectedIds.clear();
    });
  }

  void _markSelectedAsRead() async {
    final ids = _selectedIds.toList();
    await _supabaseService.markNotificationsAsRead(ids);
    setState(() {
      _isSelectionMode = false;
      _selectedIds.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool isDesktop = MediaQuery.of(context).size.width >= 720;
    
    final content = Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            if (!_isSelectionMode) _buildFilterBar(),
            Expanded(
              child: StreamBuilder<List<NotificationModel>>(
                stream: _supabaseService.getNotificationsStream(widget.userId),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    // Ignorar erros de conexão temporários (resume do app)
                    final errorMsg = snapshot.error.toString();
                    if (errorMsg.contains('RealtimeSubscribeException') || 
                        errorMsg.contains('WebSocket') || 
                        errorMsg.contains('Channel')) {
                       // Se tiver dados anteriores, mantém. Se não, mostra "Conectando..."
                       if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                          // Mantém o fluxo normal, talvez mostrar um SnackBar aviso?
                          // Por enquanto, apenas logar e não quebrar a UI
                          debugPrint('⚠️ [NotificationCenter] Erro de conexão silencioso: $errorMsg');
                       } else {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.wifi_off_rounded, size: 48, color: AppColors.tertiaryText),
                                const SizedBox(height: 16),
                                const Text('Tentando reconectar...', style: TextStyle(color: AppColors.secondaryText)),
                                TextButton(
                                  onPressed: () => setState(() {}), 
                                  child: const Text('Tentar agora', style: TextStyle(color: AppColors.primary))
                                ),
                              ],
                            ),
                          );
                       }
                    } else {
                       return Center(child: Text('Erro: ${snapshot.error}', style: const TextStyle(color: Colors.red)));
                    }
                  }
                  
                  final allNotifications = snapshot.data ?? [];
                  final filtered = _filterNotifications(allNotifications);
                  
                  if (filtered.isEmpty) {
                    return _buildEmptyState();
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final notif = filtered[index];
                      return _NotificationTile(
                        notification: notif,
                        isSelected: _selectedIds.contains(notif.id),
                        isSelectionMode: _isSelectionMode,
                        onTap: () {
                          if (_isSelectionMode) {
                            _toggleSelection(notif.id);
                          } else {
                            _handleNotificationTap(context, notif);
                          }
                        },
                        onLongPress: () => _toggleSelectionMode(notif.id),
                      );
                    },
                  );
                },
              ),
            ),
            if (_isSelectionMode) _buildBottomActionBar(),
          ],
        ),
      ),
    );

    if (isDesktop) {
       return Dialog(
         backgroundColor: AppColors.cardBackground,
         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
         child: SizedBox(
           width: 500,
           height: 700,
           child: ClipRRect(
             borderRadius: BorderRadius.circular(16),
             child: content,
           ),
         ),
       );
    }
    
    return content;
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      color: _isSelectionMode ? AppColors.primary.withOpacity(0.1) : Colors.transparent,
      child: Row(
        children: [
          if (_isSelectionMode)
             IconButton(
               icon: const Icon(Icons.close, color: Colors.white),
               onPressed: () => setState(() {
                 _isSelectionMode = false;
                 _selectedIds.clear();
               }),
             )
          else
            IconButton(
              icon: const Icon(Icons.close, color: AppColors.tertiaryText),
              onPressed: () => Navigator.pop(context),
            ),
          const SizedBox(width: 8),
          Text(
            _isSelectionMode ? '${_selectedIds.length} selecionadas' : 'Notificações',
            style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const Spacer(),
          if (!_isSelectionMode)
            IconButton(
              icon: const Icon(Icons.checklist_rounded, color: AppColors.secondaryText),
              tooltip: 'Selecionar',
              onPressed: () => _toggleSelectionMode(null),
            )
          else
            TextButton(
              onPressed: () {
                // Get all notification ids from current stream (would need to pass them)
                // For now, this just toggles off
                setState(() {
                  _isSelectionMode = false;
                  _selectedIds.clear();
                });
              },
              child: const Text('Cancelar', style: TextStyle(color: Colors.white70)),
            ),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          _buildFilterChip('all', 'Todas'),
          const SizedBox(width: 8),
          _buildFilterChip('invites', 'Convites'),
          const SizedBox(width: 8),
          _buildFilterChip('tasks', 'Tarefas'),
          const SizedBox(width: 8),
          _buildFilterChip('system', 'Sistema'),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String key, String label) {
    final isSelected = _selectedFilter == key;
    return FilterChip(
      selected: isSelected,
      label: Text(label),
      onSelected: (bool selected) {
        setState(() {
          _selectedFilter = key;
        });
      },
      backgroundColor: AppColors.cardBackground,
      selectedColor: AppColors.primary.withOpacity(0.2),
      checkmarkColor: AppColors.primary,
      labelStyle: TextStyle(
        color: isSelected ? AppColors.primary : AppColors.secondaryText,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isSelected ? AppColors.primary : AppColors.border,
        ),
      ),
    );
  }

  Widget _buildBottomActionBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: AppColors.cardBackground,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          TextButton.icon(
            icon: const Icon(Icons.mark_email_read, color: Colors.white),
            label: const Text('Marcar Lida', style: TextStyle(color: Colors.white)),
            onPressed: _selectedIds.isEmpty ? null : _markSelectedAsRead,
          ),
          TextButton.icon(
            icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
            label: const Text('Excluir', style: TextStyle(color: Colors.redAccent)),
            onPressed: _selectedIds.isEmpty ? null : _deleteSelected,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notifications_off_outlined, size: 64, color: AppColors.tertiaryText.withOpacity(0.5)),
          const SizedBox(height: 16),
          const Text(
            'Nenhuma notificação encontrada',
            style: TextStyle(color: AppColors.tertiaryText, fontSize: 16),
          ),
        ],
      ),
    );
  }

  List<NotificationModel> _filterNotifications(List<NotificationModel> notifications) {
    if (_selectedFilter == 'all') return notifications;
    
    return notifications.where((n) {
      if (_selectedFilter == 'invites') {
        return n.type == NotificationType.contactRequest || 
               n.type == NotificationType.taskInvite || 
               n.type == NotificationType.sincroAlert;
      }
      if (_selectedFilter == 'tasks') {
        return n.type == NotificationType.taskUpdate || 
               n.type == NotificationType.reminder;
      }
      if (_selectedFilter == 'system') {
        return n.type == NotificationType.system || 
               n.type == NotificationType.mention ||
               n.type == NotificationType.share ||
               n.type == NotificationType.contactAccepted; // Confirmações
      }
      return true;
    }).toList();
  }

  void _handleNotificationTap(BuildContext context, NotificationModel notification) {
    if (!notification.isRead) {
      _supabaseService.markNotificationAsRead(notification.id);
    }
    
    // Notificações informativas (não clicáveis) - apenas marcar como lida
    if (notification.type == NotificationType.contactAccepted ||
        notification.type == NotificationType.system) {
      return; // Não abrir modal
    }
    
    // Notificações com ação
    if (notification.type == NotificationType.contactRequest || 
        notification.type == NotificationType.taskInvite ||
        notification.type == NotificationType.taskUpdate ||
        notification.type == NotificationType.sincroAlert) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => NotificationDetailModal(notification: notification),
      );
    }
  }
}

class _NotificationTile extends StatelessWidget {
  final NotificationModel notification;
  final bool isSelected;
  final bool isSelectionMode;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _NotificationTile({
    required this.notification,
    required this.isSelected,
    required this.isSelectionMode,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final theme = _getThemeForType(notification.type);
    
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: isSelected 
              ? AppColors.primary.withOpacity(0.15)
              : (notification.isRead 
                  ? AppColors.cardBackground.withOpacity(0.3) 
                  : AppColors.cardBackground),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
             color: isSelected ? AppColors.primary : Colors.transparent,
             width: 1.5,
          ),
          boxShadow: notification.isRead || isSelected ? [] : [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isSelectionMode)
              Padding(
                padding: const EdgeInsets.only(right: 12, top: 2),
                child: Icon(
                  isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
                  color: isSelected ? AppColors.primary : AppColors.tertiaryText,
                  size: 24,
                ),
              )
            else
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: theme.color.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(theme.icon, color: theme.color, size: 24),
              ),
              
            const SizedBox(width: 16),
            
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          notification.title,
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: notification.isRead ? FontWeight.w500 : FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      if (!notification.isRead)
                        Container(
                          margin: const EdgeInsets.only(left: 8),
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    notification.body,
                    style: const TextStyle(color: AppColors.secondaryText, fontSize: 14),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _formatTime(notification.createdAt),
                    style: const TextStyle(color: AppColors.tertiaryText, fontSize: 12),
                  ),
                ],
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
    if (diff.inDays < 7) return '${diff.inDays}d atrás';
    return DateFormat('dd/MM').format(time);
  }
  
  _NotificationTheme _getThemeForType(NotificationType type) {
    switch (type) {
      case NotificationType.contactRequest:
        return _NotificationTheme(Icons.person_add_rounded, AppColors.primary);
      case NotificationType.contactAccepted:
        return _NotificationTheme(Icons.check_circle_rounded, Colors.green);
      case NotificationType.taskInvite:
        return _NotificationTheme(Icons.event_available_rounded, Colors.orange);
      case NotificationType.taskUpdate:
        return _NotificationTheme(Icons.edit_calendar_rounded, Colors.blueAccent);
      case NotificationType.mention:
        return _NotificationTheme(Icons.alternate_email_rounded, AppColors.contact);
      case NotificationType.share:
        return _NotificationTheme(Icons.share_rounded, Colors.purpleAccent);
      case NotificationType.sincroAlert:
        return _NotificationTheme(Icons.auto_awesome_rounded, Colors.amber);
      case NotificationType.reminder:
        return _NotificationTheme(Icons.alarm_rounded, Colors.orangeAccent);
      case NotificationType.system:
      default:
        return _NotificationTheme(Icons.info_outline_rounded, Colors.blueGrey);
    }
  }
}

class _NotificationTheme {
  final IconData icon;
  final Color color;
  _NotificationTheme(this.icon, this.color);
}
