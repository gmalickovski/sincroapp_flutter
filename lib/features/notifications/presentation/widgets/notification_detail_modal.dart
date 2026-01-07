import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:sincro_app_flutter/common/constants/app_colors.dart';
import 'package:sincro_app_flutter/features/notifications/models/notification_model.dart';
import 'package:sincro_app_flutter/services/supabase_service.dart';
import 'package:sincro_app_flutter/services/numerology_engine.dart'; // Para Personal Day
import 'package:supabase_flutter/supabase_flutter.dart';

class NotificationDetailModal extends StatefulWidget {
  final NotificationModel notification;
  final VoidCallback? onDismiss;

  const NotificationDetailModal({
    super.key,
    required this.notification,
    this.onDismiss,
  });

  @override
  State<NotificationDetailModal> createState() => _NotificationDetailModalState();
}

class _NotificationDetailModalState extends State<NotificationDetailModal> {
  final SupabaseService _supabaseService = SupabaseService();
  bool _isLoading = false;
  String? _personalDayText;
  
  @override
  void initState() {
    super.initState();
    if (widget.notification.type == NotificationType.taskInvite) {
      _loadPersonalDayContext();
    }
  }

  Future<void> _loadPersonalDayContext() async {
    final meta = widget.notification.metadata;
    final dateStr = meta['target_date'] as String?;
    if (dateStr == null) return;
    
    final date = DateTime.parse(dateStr);
    
    // Calcular dia pessoal (Simulado ou Real se tiver user data)
    // Precisaria da data de nasc do usuario LOGADO
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      final userData = await _supabaseService.getUserData(user.id);
      if (userData != null && userData.dataNasc.isNotEmpty) {
         try {
           final personalDayNum = NumerologyEngine.calculatePersonalDay(date, userData.dataNasc);
           
           // TODO: Pegar texto do dia pessoal. Como não temos fácil acesso ao texto completo aqui,
           // vamos usar uma descrição genérica ou chamar um método se existir.
           // Se não tiver o texto, mostramos apenas o número.
           setState(() {
             _personalDayText = "Dia Pessoal $personalDayNum: Momento para focar nas energias deste número.";
           });
         } catch (e) {
           debugPrint("Erro calc dia pessoal: $e");
         }
      }
    }
  }

  Future<void> _handleAction(bool accept) async {
    setState(() => _isLoading = true);
    try {
      final type = widget.notification.type;
      final meta = widget.notification.metadata;
      final currentUid = Supabase.instance.client.auth.currentUser!.id;

      if (type == NotificationType.contactRequest) {
        final fromUid = meta['from_uid'];
        await _supabaseService.respondToContactRequest(
          uid: currentUid, 
          contactUid: fromUid, 
          accept: accept
        );
      } else if (type == NotificationType.taskInvite) {
        final taskId = meta['task_id'];
        final ownerId = meta['owner_id'];
        // Assumindo que current user é quem responde
        final userData = await _supabaseService.getUserData(currentUid);
        
        await _supabaseService.respondToInvitation(
          taskId: taskId,
          ownerId: ownerId,
          responderUid: currentUid,
          responderName: userData?.username ?? 'Alguém',
          accepted: accept,
        );
      }
      
      // Update notification status locally? or assume stream updates parent list
      await _supabaseService.markNotificationAsRead(widget.notification.id); // Mark read on action taken
      
      if (mounted) Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Icon
          _buildIcon(),
          const SizedBox(height: 16),
          
          // Title
          Text(
            widget.notification.title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          
          // Body
          Text(
            widget.notification.body,
            style: const TextStyle(color: AppColors.secondaryText),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          
          // Contextual Content
          if (widget.notification.type == NotificationType.taskInvite && _personalDayText != null)
            _buildPersonalDayCard(),
            
          const SizedBox(height: 24),

          // Actions
          if (widget.notification.type == NotificationType.contactRequest || 
              widget.notification.type == NotificationType.taskInvite)
            _buildActionButtons()
          else
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.cardBackground,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: AppColors.border)),
                minimumSize: const Size(double.infinity, 50),
              ),
              child: const Text('Fechar', style: TextStyle(color: Colors.white)),
            ),
        ],
      ),
    );
  }
  
  Widget _buildIcon() {
    IconData iconData;
    Color color;
    
    switch (widget.notification.type) {
      case NotificationType.contactRequest:
        iconData = Icons.person_add;
        color = AppColors.primary;
        break;
      case NotificationType.taskInvite:
        iconData = Icons.event;
        color = Colors.orange;
        break;
      case NotificationType.taskUpdate:
        iconData = Icons.update;
        color = Colors.blue;
        break;
      case NotificationType.sincroAlert:
        iconData = Icons.auto_awesome;
        color = Colors.purple;
        break;
      default:
        iconData = Icons.notifications;
        color = AppColors.tertiaryText;
    }
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(iconData, color: color, size: 32),
    );
  }
  
  Widget _buildPersonalDayCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.wb_sunny, size: 16, color: Colors.orange),
              const SizedBox(width: 8),
              Text(
                'Seu dia nesta data',
                style: TextStyle(color: Colors.white.withOpacity(0.9), fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _personalDayText ?? '',
            style: const TextStyle(color: AppColors.secondaryText, fontSize: 13),
             textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: _isLoading ? null : () => _handleAction(false),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.redAccent),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              minimumSize: const Size(0, 50),
            ),
            child: const Text('Recusar', style: TextStyle(color: Colors.redAccent)),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: ElevatedButton(
            onPressed: _isLoading ? null : () => _handleAction(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              minimumSize: const Size(0, 50),
            ),
            child: _isLoading 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text('Aceitar', style: TextStyle(color: Colors.white)),
          ),
        ),
      ],
    );
  }
}
