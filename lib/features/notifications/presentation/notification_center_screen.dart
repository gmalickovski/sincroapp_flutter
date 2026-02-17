// lib/features/notifications/presentation/notification_center_screen.dart

import 'package:flutter/material.dart';
import 'package:sincro_app_flutter/common/constants/app_colors.dart';
import 'package:sincro_app_flutter/features/notifications/models/notification_model.dart';
import 'package:sincro_app_flutter/services/supabase_service.dart';
import 'package:intl/intl.dart';
import 'package:sincro_app_flutter/features/notifications/presentation/widgets/notification_detail_modal.dart';
import 'package:sincro_app_flutter/features/notifications/presentation/widgets/update_detail_modal.dart'; // NOVO import
import 'package:package_info_plus/package_info_plus.dart'; // NOVO
import 'package:http/http.dart' as http; // NOVO
import 'dart:convert'; // NOVO
import 'package:flutter_dotenv/flutter_dotenv.dart'; // NOVO

class NotificationCenterScreen extends StatefulWidget {
  final String userId;

  const NotificationCenterScreen({super.key, required this.userId});

  @override
  State<NotificationCenterScreen> createState() =>
      _NotificationCenterScreenState();
}

class _NotificationCenterScreenState extends State<NotificationCenterScreen> {
  final SupabaseService _supabaseService = SupabaseService();

  // State
  String _selectedFilter = 'all'; // all, invites, tasks, system
  final Set<String> _selectedIds = {};
  bool _isSelectionMode = false;

  // Update State
  bool _updateAvailable = false;
  String? _remoteVersion;
  String? _changelog;

  @override
  void initState() {
    super.initState();
    _checkForUpdate();
  }

  Future<void> _checkForUpdate() async {
    try {
      // 1. Get Local Version
      final packageInfo = await PackageInfo.fromPlatform();
      final localVersion = packageInfo.version;

      // 2. Get Remote Version
      final baseUrl = dotenv.env['API_BASE_URL'] ??
          'http://localhost:3000'; // Fallback for dev
      // Adjust for Android Emulator if needed
      final apiUrl = Uri.parse('$baseUrl/api/version');

      final response = await http.get(apiUrl);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final remoteVersion = data['version'] as String;
        final notes = data['notes'] as String;

        // Simple semantic version comparison logic
        if (_isNewerVersion(localVersion, remoteVersion)) {
          if (mounted) {
            setState(() {
              _updateAvailable = true;
              _remoteVersion = remoteVersion;
              _changelog = notes;
            });
          }
        }
      }
    } catch (e) {
      debugPrint('Error checking for updates: $e');
    }
  }

  bool _isNewerVersion(String local, String remote) {
    try {
      List<int> lParts = local.split('.').map(int.parse).toList();
      List<int> rParts = remote.split('.').map(int.parse).toList();

      for (int i = 0; i < 3; i++) {
        int l = i < lParts.length ? lParts[i] : 0;
        int r = i < rParts.length ? rParts[i] : 0;
        if (r > l) return true;
        if (r < l) return false;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

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

  void _deleteNotification(String id) async {
    await _supabaseService.deleteNotifications([id]);
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
            if (_updateAvailable) _buildUpdateBanner(), // NOVO BANNER
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
                        debugPrint(
                            '⚠️ [NotificationCenter] Erro de conexão silencioso: $errorMsg');
                      } else {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.wifi_off_rounded,
                                  size: 48, color: AppColors.tertiaryText),
                              const SizedBox(height: 16),
                              const Text('Tentando reconectar...',
                                  style: TextStyle(
                                      color: AppColors.secondaryText)),
                              TextButton(
                                  onPressed: () => setState(() {}),
                                  child: const Text('Tentar agora',
                                      style:
                                          TextStyle(color: AppColors.primary))),
                            ],
                          ),
                        );
                      }
                    } else {
                      return Center(
                          child: Text('Erro: ${snapshot.error}',
                              style: const TextStyle(color: Colors.red)));
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

                      // Auto-marcar como lida se for notificação simples (sem ação de aceite)
                      if (!notif.isRead && _isSimpleNotification(notif.type)) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted) {
                            _supabaseService.markNotificationAsRead(notif.id);
                          }
                        });
                      }

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
                        onDelete: () =>
                            _deleteNotification(notif.id), // New callback
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
      color: _isSelectionMode
          ? AppColors.primary.withOpacity(0.1)
          : Colors.transparent,
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
            _isSelectionMode
                ? '${_selectedIds.length} selecionadas'
                : 'Notificações',
            style: const TextStyle(
                color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const Spacer(),
          if (!_isSelectionMode)
            IconButton(
              icon: const Icon(Icons.checklist_rounded,
                  color: AppColors.secondaryText),
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
              child: const Text('Cancelar',
                  style: TextStyle(color: Colors.white70)),
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
            label: const Text('Marcar Lida',
                style: TextStyle(color: Colors.white)),
            onPressed: _selectedIds.isEmpty ? null : _markSelectedAsRead,
          ),
          TextButton.icon(
            icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
            label: const Text('Excluir',
                style: TextStyle(color: Colors.redAccent)),
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
          Icon(Icons.notifications_off_outlined,
              size: 64, color: AppColors.tertiaryText.withOpacity(0.5)),
          const SizedBox(height: 16),
          const Text(
            'Nenhuma notificação encontrada',
            style: TextStyle(color: AppColors.tertiaryText, fontSize: 16),
          ),
        ],
      ),
    );
  }

  List<NotificationModel> _filterNotifications(
      List<NotificationModel> notifications) {
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

  void _handleNotificationTap(
      BuildContext context, NotificationModel notification) {
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
        builder: (context) =>
            NotificationDetailModal(notification: notification),
      );
    }
  }

  bool _isSimpleNotification(NotificationType type) {
    return type == NotificationType.system ||
        type == NotificationType.mention ||
        type == NotificationType.share ||
        type == NotificationType.contactAccepted ||
        type == NotificationType.reminder ||
        type == NotificationType.taskUpdate;
  }

  Widget _buildUpdateBanner() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.primary.withOpacity(0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.4),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            if (_remoteVersion != null && _changelog != null) {
              UpdateDetailModal.show(context,
                  version: _remoteVersion!, changelog: _changelog!);
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.system_update,
                      color: Colors.white, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Nova Atualização Disponível!',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Versão $_remoteVersion - Toque para detalhes',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios_rounded,
                    color: Colors.white, size: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final NotificationModel notification;
  final bool isSelected;
  final bool isSelectionMode;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onDelete; // New param

  const _NotificationTile({
    required this.notification,
    required this.isSelected,
    required this.isSelectionMode,
    required this.onTap,
    required this.onLongPress,
    required this.onDelete, // New param
  });

  @override
  Widget build(BuildContext context) {
    final theme = _getThemeForType(notification.type);

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
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
          boxShadow: notification.isRead || isSelected
              ? []
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  )
                ],
        ),
        child: Stack(
          children: [
            // Main content with padding
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isSelectionMode)
                    Padding(
                      padding: const EdgeInsets.only(right: 12, top: 2),
                      child: Icon(
                        isSelected
                            ? Icons.check_circle
                            : Icons.radio_button_unchecked,
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.tertiaryText,
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
                              child: Padding(
                                padding: const EdgeInsets.only(
                                    right: 24), // Space for delete icon
                                child: Text(
                                  notification.title,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: notification.isRead
                                        ? FontWeight.w500
                                        : FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            ),
                            if (!notification.isRead)
                              Container(
                                margin:
                                    const EdgeInsets.only(left: 8, right: 24),
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
                        RichText(
                          text: _buildHighlightedNotificationText(
                              notification.body),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _formatTime(notification.createdAt),
                          style: const TextStyle(
                              color: AppColors.tertiaryText, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Delete button at top-right
            if (!isSelectionMode)
              Positioned(
                top: 4,
                right: 4,
                child: IconButton(
                  icon: const Icon(Icons.delete_outline_rounded,
                      size: 20, color: AppColors.tertiaryText),
                  tooltip: 'Excluir',
                  splashRadius: 20,
                  onPressed: onDelete,
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints(minWidth: 32, minHeight: 32),
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
        return _NotificationTheme(
            Icons.edit_calendar_rounded, Colors.blueAccent);
      case NotificationType.mention:
        return _NotificationTheme(
            Icons.alternate_email_rounded, AppColors.contact);
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

  /// Helper para criar TextSpan com destaque de @menções em azul e datas em âmbar
  TextSpan _buildHighlightedNotificationText(String text) {
    const baseStyle = TextStyle(
      color: AppColors.secondaryText,
      fontSize: 14,
      height: 1.5, // Fix tight spacing
    );
    const mentionStyle = TextStyle(
      color: Colors.lightBlueAccent,
      fontWeight: FontWeight.bold,
      fontSize: 14,
      height: 1.5,
    );
    const dateStyle = TextStyle(
      color: Colors.amber,
      fontWeight: FontWeight.bold,
      fontSize: 14,
      height: 1.5,
    );

    // Regex combinado para @username e datas (dd/MM, dd de mês, etc.)
    final combinedRegex = RegExp(
      r'(@[\w.]+)|(\d{1,2}/\d{1,2}(?:/\d{2,4})?)|(\d{1,2}\s+de\s+\w+)',
      caseSensitive: false,
    );

    final matches = combinedRegex.allMatches(text);

    if (matches.isEmpty) {
      return TextSpan(text: text, style: baseStyle);
    }

    final spans = <TextSpan>[];
    int lastEnd = 0;

    for (final match in matches) {
      // Texto antes do match
      if (match.start > lastEnd) {
        spans.add(TextSpan(
          text: text.substring(lastEnd, match.start),
          style: baseStyle,
        ));
      }

      // Determinar qual grupo foi matched
      final matchedText = match.group(0)!;
      final isMention = match.group(1) != null;

      spans.add(TextSpan(
        text: matchedText,
        style: isMention ? mentionStyle : dateStyle,
      ));

      lastEnd = match.end;
    }

    // Texto após o último match
    if (lastEnd < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastEnd),
        style: baseStyle,
      ));
    }

    return TextSpan(children: spans);
  }
}

class _NotificationTheme {
  final IconData icon;
  final Color color;
  _NotificationTheme(this.icon, this.color);
}
