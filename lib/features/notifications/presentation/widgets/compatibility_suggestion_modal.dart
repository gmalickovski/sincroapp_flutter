import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:sincro_app_flutter/common/constants/app_colors.dart';
import 'package:sincro_app_flutter/services/numerology_engine.dart';
import 'package:sincro_app_flutter/services/supabase_service.dart';

class CompatibilitySuggestionModal extends StatefulWidget {
  final DateTime targetDate;
  final String userAName;
  final DateTime userABirth;
  final String userBName;
  final DateTime userBBirth;
  final String taskTitle;

  const CompatibilitySuggestionModal({
    super.key,
    required this.targetDate,
    required this.userAName,
    required this.userABirth,
    required this.userBName,
    required this.userBBirth,
    required this.taskTitle,
  });

  @override
  State<CompatibilitySuggestionModal> createState() => _CompatibilitySuggestionModalState();
}

class _CompatibilitySuggestionModalState extends State<CompatibilitySuggestionModal> {
  late double compatibilityScore;
  late List<DateTime> suggestions;
  bool isLoading = true;
  bool hasAccepted = false; // Controls the 2-step flow

  @override
  void initState() {
    super.initState();
    _calculateLogic();
  }

  void _calculateLogic() async {
    // Simulate slight delay for smooth UX transition if needed
    await Future.delayed(const Duration(milliseconds: 300));

    if (!mounted) return;

    final score = NumerologyEngine.calculateCompatibilityScore(
      date: widget.targetDate,
      birthDateA: widget.userABirth,
      birthDateB: widget.userBBirth,
    );

    final nextDates = NumerologyEngine.findNextCompatibleDates(
      startDate: DateTime.now(),
      birthDateA: widget.userABirth,
      birthDateB: widget.userBBirth,
      limit: 3,
    );

    setState(() {
      compatibilityScore = score;
      suggestions = nextDates;
      isLoading = false;
    });
  }

  void _acceptInvitation() {
    setState(() {
      hasAccepted = true;
    });
    // In a real scenario, this would trigger an API call to update status
    // SupabaseService().acceptShare(...)
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.cardBackground,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        padding: const EdgeInsets.all(24),
        constraints: const BoxConstraints(maxWidth: 400),
        child: AnimatedSwitcher(
           duration: const Duration(milliseconds: 300),
           child: hasAccepted ? _buildDetailsView() : _buildInvitationView(),
        ),
      ),
    );
  }

  // --- VIEW 1: INVITATION ---
  Widget _buildInvitationView() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.event_available, color: AppColors.primary, size: 48),
        const SizedBox(height: 16),
        Text(
          'Um Evento foi Sincronizado contigo!',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
            style: const TextStyle(color: AppColors.secondaryText, fontSize: 16),
            children: [
              const TextSpan(text: 'De '),
              TextSpan(
                text: widget.userAName, 
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)
              ),
              const TextSpan(text: '\nVocê deseja aceitar?'),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context), // "Não" just closes
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.redAccent,
                  side: const BorderSide(color: Colors.redAccent),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Não'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: _acceptInvitation,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Sim'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // --- VIEW 2: DETAILS & SYNERGY ---
  Widget _buildDetailsView() {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }

    final isGoodSynergy = compatibilityScore > 0.4; // 0.9 = Great, >0.4 = OK

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header (Close button)
        Align(
          alignment: Alignment.centerRight,
          child: IconButton(
            icon: const Icon(Icons.close, color: AppColors.secondaryText),
            onPressed: () => Navigator.pop(context),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ),
        
        // Event Details
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              Text(
                DateFormat('dd/MM/yyyy (EEEE)', 'pt_BR').format(widget.targetDate).toUpperCase(),
                style: const TextStyle(
                  color: AppColors.secondaryText,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                widget.taskTitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 24),
        
        // Synergy Section
        Text(
          'Sinergia da Data',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.tertiaryText,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        
        // Synergy Indicator
        Center(
           child: Container(
             padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
             decoration: BoxDecoration(
               color: isGoodSynergy ? Colors.green.withOpacity(0.2) : Colors.red.withOpacity(0.2),
               borderRadius: BorderRadius.circular(20),
               border: Border.all(color: isGoodSynergy ? Colors.green : Colors.red),
             ),
             child: Row(
               mainAxisSize: MainAxisSize.min,
               children: [
                 Icon(
                   isGoodSynergy ? Icons.check_circle : Icons.warning_amber_rounded,
                   color: isGoodSynergy ? Colors.green : Colors.red,
                   size: 20,
                 ),
                 const SizedBox(width: 8),
                 Text(
                   isGoodSynergy ? 'Compatibilidade Boa' : 'Baixa Sinergia',
                   style: TextStyle(
                     color: isGoodSynergy ? Colors.green : Colors.red,
                     fontWeight: FontWeight.bold,
                   ),
                 ),
               ],
             ),
           ),
        ),

        const SizedBox(height: 24),

        // Suggestions (Only if bad synergy or user wants to change)
        if (!isGoodSynergy || true) ...[ // Always showing suggestions based on user request ("aparecer duas opção")
             if (!isGoodSynergy)
               const Padding(
                 padding: EdgeInsets.only(bottom: 12.0),
                 child: Text(
                   'Datas sugeridas para ambos:',
                   textAlign: TextAlign.center,
                   style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                 ),
               ),
             
             // Horizontal Scrollable Suggestions ("Pill Style")
             SingleChildScrollView(
               scrollDirection: Axis.horizontal,
               child: Row(
                 mainAxisAlignment: MainAxisAlignment.center,
                 children: suggestions.map((date) {
                   return Padding(
                     padding: const EdgeInsets.only(right: 8.0),
                     child: ActionChip(
                       backgroundColor: AppColors.background,
                       label: Text(
                         DateFormat('dd/MM', 'pt_BR').format(date),
                         style: const TextStyle(color: AppColors.primary),
                       ),
                       avatar: const Icon(Icons.calendar_month, size: 16, color: AppColors.primary),
                       onPressed: () {
                         // Suggest new date
                         // Would notify sender logic here
                         Navigator.pop(context, date); 
                         ScaffoldMessenger.of(context).showSnackBar(
                           SnackBar(content: Text('Sugestão enviada para ${widget.userAName}!')),
                         );
                       },
                       side: const BorderSide(color: AppColors.primary),
                       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                     ),
                   );
                 }).toList(),
               ),
             ),
        ],
        
        const SizedBox(height: 16),
        
        // "Entendido" / Close Button
        TextButton(
          onPressed: () => Navigator.pop(context, widget.targetDate), // Returns confirmed date
          child: const Text('Manter data atual', style: TextStyle(color: AppColors.secondaryText)),
        ),
      ],
    );
  }
}
