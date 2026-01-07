import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:sincro_app_flutter/common/constants/app_colors.dart';
import 'package:sincro_app_flutter/common/widgets/vibration_pill.dart';
import 'package:sincro_app_flutter/features/notifications/models/notification_model.dart';
import 'package:sincro_app_flutter/features/authentication/data/content_data.dart';
import 'package:sincro_app_flutter/services/supabase_service.dart';
import 'package:sincro_app_flutter/services/numerology_engine.dart';
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
  int? _personalDayNumber;
  String? _personalDayTitle;  // Ex: "Estrutura e Trabalho"
  String? _personalDayText;   // Descrição completa
  String? _senderUsername;
  String? _taskText;
  DateTime? _targetDate;
  
  @override
  void initState() {
    super.initState();
    _parseNotificationData();
    if (widget.notification.type == NotificationType.taskInvite) {
      _loadPersonalDayContext();
    }
  }

  void _parseNotificationData() {
    final meta = widget.notification.metadata;
    _senderUsername = meta['sender_username'] as String?;
    _taskText = meta['task_text'] as String?;
    final dateStr = meta['target_date'] as String?;
    if (dateStr != null) {
      _targetDate = DateTime.tryParse(dateStr);
    }
  }

  Future<void> _loadPersonalDayContext() async {
    if (_targetDate == null) return;
    
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      final userData = await _supabaseService.getUserData(user.id);
      if (userData != null && userData.dataNasc.isNotEmpty) {
         try {
           final personalDayNum = NumerologyEngine.calculatePersonalDay(_targetDate!, userData.dataNasc);
           
           // Buscar conteúdo do dia pessoal
           final vibrationContent = ContentData.vibracoes['diaPessoal']?[personalDayNum];
           
           setState(() {
             _personalDayNumber = personalDayNum;
             _personalDayTitle = vibrationContent?.titulo ?? 'Dia $personalDayNum';
             // Usar descrição completa para o card
             _personalDayText = vibrationContent?.descricaoCompleta ?? 
                 vibrationContent?.descricaoCurta ??
                 ContentData.textosDiasFavoraveis[personalDayNum] ??
                 'Energia numerológica do dia.';
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
        final taskId = meta['task_id'] as String?;
        final ownerId = meta['owner_id'] as String?;
        final taskText = meta['task_text'] as String?;
        final targetDateStr = meta['target_date'] as String?;
        final userData = await _supabaseService.getUserData(currentUid);
        
        // Passar os dados da tarefa diretamente (evita problema de RLS)
        await _supabaseService.respondToInvitation(
          taskId: taskId ?? '',
          ownerId: ownerId ?? '',
          responderUid: currentUid,
          responderName: userData?.username ?? 'Alguém',
          accepted: accept,
          // Dados da tarefa vindos do metadata (bypass RLS)
          taskText: taskText,
          targetDate: targetDateStr,
        );
      }
      
      await _supabaseService.markNotificationAsRead(widget.notification.id);
      
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
          
          // Title with calendar icon
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.event, color: Colors.amber, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Convite de Agendamento',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Body - formatted with colored username and date
          _buildFormattedBody(),
          const SizedBox(height: 24),
          
          // Personal Day Card
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
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30), side: const BorderSide(color: AppColors.border)),
                minimumSize: const Size(double.infinity, 50),
              ),
              child: const Text('Fechar', style: TextStyle(color: Colors.white)),
            ),
        ],
      ),
    );
  }
  
  Widget _buildFormattedBody() {
    final username = _senderUsername ?? 'Alguém';
    final taskText = _taskText ?? widget.notification.body;
    final dateFormatted = _targetDate != null 
        ? DateFormat('dd/MM').format(_targetDate!) 
        : '';
    
    return Column(
      children: [
        // Linha 1: @username convidou você para:
        RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
            style: const TextStyle(color: AppColors.secondaryText, fontSize: 14),
            children: [
              TextSpan(
                text: '@$username',
                style: const TextStyle(
                  color: Colors.lightBlueAccent,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const TextSpan(text: ' convidou você para:'),
            ],
          ),
        ),
        
        // Espaçamento
        const SizedBox(height: 12),
        
        // Linha 2: Texto da tarefa (destaque maior)
        Text(
          taskText,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        
        // Linha 3: Data em âmbar
        if (dateFormatted.isNotEmpty) ...[
          const SizedBox(height: 8),
          RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              style: const TextStyle(color: AppColors.secondaryText, fontSize: 14),
              children: [
                const TextSpan(text: 'Data: '),
                TextSpan(
                  text: dateFormatted,
                  style: const TextStyle(
                    color: Colors.amber,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
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
        iconData = Icons.calendar_today;
        color = Colors.amber;
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
        border: Border.all(color: color.withOpacity(0.3), width: 2),
      ),
      child: Icon(iconData, color: color, size: 32),
    );
  }
  
  Widget _buildPersonalDayCard() {
    // Formato: ☀️ Dia Pessoal X: Título
    final headerText = 'Dia Pessoal ${_personalDayNumber ?? ''}: ${_personalDayTitle ?? ''}';
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: ☀️ Dia Pessoal X: Título (em verde)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.wb_sunny, size: 20, color: Colors.amber),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  headerText,
                  style: const TextStyle(
                    color: Color(0xFF7ED321), // Verde como na imagem
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          ),
          
          // Descrição do dia pessoal
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.only(left: 30), // Alinhado com o texto do header
            child: Text(
              _personalDayText ?? '',
              style: const TextStyle(
                color: AppColors.secondaryText,
                fontSize: 13,
                height: 1.4,
              ),
            ),
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)), // Pill style
              minimumSize: const Size(0, 50),
            ),
            child: const Text('Recusar', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: ElevatedButton(
            onPressed: _isLoading ? null : () => _handleAction(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)), // Pill style
              minimumSize: const Size(0, 50),
            ),
            child: _isLoading 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text('Aceitar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }
}
