import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:sincro_app_flutter/common/constants/app_colors.dart';
import 'package:sincro_app_flutter/features/assistant/models/assistant_models.dart';

class ActionProposalBubble extends StatefulWidget {
  final AssistantAction action;
  final Function(DateTime) onConfirm;
  final VoidCallback onCancel;

  const ActionProposalBubble({
    super.key,
    required this.action,
    required this.onConfirm,
    required this.onCancel,
  });

  @override
  State<ActionProposalBubble> createState() => _ActionProposalBubbleState();
}

class _ActionProposalBubbleState extends State<ActionProposalBubble> {
  DateTime? _selectedDate;
  bool _isCancelled = false;

  @override
  void initState() {
    super.initState();
    // Initialize with primary date ONLY if provided by action (Intent to schedule specific date)
    // If it's a suggestion list, start empty to avoid "Data Escolhida" confusion.
    _selectedDate = widget.action.date;
  }

  void _handleConfirm() {
    if (_selectedDate != null) {
      widget.onConfirm(_selectedDate!);
    }
  }

  void _handleCancel() {
    setState(() {
      _isCancelled = true;
    });
    widget.onCancel();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );

    if (pickedDate != null && mounted) {
      final pickedTime = await showTimePicker(
        context: context,
        initialTime: _selectedDate != null 
            ? TimeOfDay.fromDateTime(_selectedDate!) 
            : const TimeOfDay(hour: 9, minute: 0),
      );

      if (pickedTime != null && mounted) {
        setState(() {
          _selectedDate = DateTime(
            pickedDate.year,
            pickedDate.month,
            pickedDate.day,
            pickedTime.hour,
            pickedTime.minute,
          );
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isCancelled) {
      return _buildCancelledState();
    }

    if (widget.action.isExecuted) {
      return _buildExecutedState();
    }

    // Extract payload safely
    final payload = widget.action.data['payload'] as Map<String, dynamic>? ?? {};
    final title = widget.action.title ?? payload['title'] ?? 'Nova Ação';
    // Tags from payload
    final tags = (payload['tags'] as List?)?.map((e) => e.toString()).toList() ?? [];
    
    // Suggestions
    final suggestions = widget.action.suggestedDates;

    // Requested Date (Original)
    final requestedDate = widget.action.date;
    
    // Helper to get feedback for ANY date
    Map<String, dynamic> getFeedbackForDate(DateTime date) {
      // 1. Is it the Requested Date? Use backend analysis.
      if (requestedDate != null && date.year == requestedDate.year && date.month == requestedDate.month && date.day == requestedDate.day) {
           final analysis = widget.action.data['analysis'] as Map<String, dynamic>?;
           if (analysis != null) {
               final String status = analysis['status']?.toString() ?? "Neutro";
               if (status == "Dia de Sorte") return {'text': "Dia de Sorte 🍀", 'color': AppColors.success, 'icon': Icons.auto_awesome};
               if (status == "Favorável") return {'text': "Boa energia ✨", 'color': AppColors.success, 'icon': Icons.thumb_up_alt_rounded};
               if (status == "Neutro") return {'text': "Energia Neutra ⚖️", 'color': Colors.blueGrey, 'icon': Icons.balance};
               return {'text': "Data desafiadora ⚠️", 'color': Colors.orangeAccent, 'icon': Icons.warning_rounded};
           }
           // Fallback if no analysis but matches suggestions
           if (suggestions.any((s) => s.year == date.year && s.month == date.month && s.day == date.day)) {
               return {'text': "Boa energia ✨", 'color': AppColors.success, 'icon': Icons.thumb_up_alt_rounded};
           }
           // Default fallback for requested date
           return {'text': "Data solicitada", 'color': AppColors.secondaryText, 'icon': Icons.calendar_today};
      }

      // 2. Is it a Suggestion? (Always Good if it came from suggestions list)
      if (suggestions.any((s) => s.year == date.year && s.month == date.month && s.day == date.day)) {
           return {'text': "Boa energia ✨", 'color': AppColors.success, 'icon': Icons.thumb_up_alt_rounded};
      }

      // 3. Manual/Other
      return {'text': "Data Selecionada", 'color': AppColors.secondaryText, 'icon': Icons.edit_calendar};
    }

    // Determine Feedback for CURRENT SELECTION
    String feedbackText = "";
    Color feedbackColor = AppColors.secondaryText;
    IconData feedbackIcon = Icons.calendar_today;
    bool isGood = false;

    if (_selectedDate != null) {
        final fb = getFeedbackForDate(_selectedDate!);
        feedbackText = fb['text'];
        feedbackColor = fb['color'];
        feedbackIcon = fb['icon'];
        isGood = feedbackColor == AppColors.success;
    }

    // [FIX] Extract timeSpecified considering fallback
    bool _isTimeExplicitlySpecified() {
      // 1. Check Params
      if (widget.action.data['params'] != null && widget.action.data['params'].containsKey('time_specified')) {
        return widget.action.data['params']['time_specified'] == true;
      }
      // 2. Check Payload
      if (widget.action.data['payload'] != null && widget.action.data['payload'].containsKey('time_specified')) {
         return widget.action.data['payload']['time_specified'] == true;
      }
      // 3. Fallback: If time is 00:00, assume NOT specified. Otherwise, assume specified.
      if (_selectedDate != null && _selectedDate!.hour == 0 && _selectedDate!.minute == 0) {
        return false;
      }
      return true; // Default
    }

    final bool timeSpecified = _isTimeExplicitlySpecified();


    return Container(
      margin: const EdgeInsets.only(top: 12, bottom: 12, left: 24, right: 8),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primaryAccent.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 12,
            offset: const Offset(0, 6),
          )
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // HEADER GRADIENT
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.primaryAccent, AppColors.secondaryAccent],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.auto_awesome, size: 20, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      fontFamily: 'Poppins',
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                
                // 1. ORIGINAL REQUESTED DATE (Unless overridden, show standard. If overridden, keep visible but maybe dimmed? User said: "no espaço da data deveria aparecer a data que eu pedi")
                // Actually user said: "No espaço da data deveria aparecer a data que eu pedi... ao lado escrito se é boa... e abaixo duas etiquetas... que qdo clicar vai valer a que selecionei"
                // So the MAIN display should always show the REQUESTED date status, and the SELECTION logic happens below.
                // Wait. If I select a new date, does the main text change? The user says: "quando eu clicar... vai valer a que eu selecionei".
                // I will show the CURRENTLY VALID SELECTION prominently.
                // But the Requested Date needs to be shown too for comparison?
                // Let's interpret: "No espaço da data" = The field label. 
                // Let's keep one main "Selected Date" area, but pre-filled with Requested.
                // And below, the "Alternative Options".
                
                // Let's split: Top is "Requested Date Info". Bottom is "Alternatives".
                // If I select an alternative, it becomes the Active Date.
                
                // 1. HEADER DATE SELECTION (Visible only if a date is selected or was pre-set)
                if (_selectedDate != null) ...[
                  Text(
                    "Data Escolhida",
                    style: TextStyle(
                      color: AppColors.tertiaryText,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min, // Keep tight
                      children: [
                        Icon(Icons.calendar_month, color: (isGood ? feedbackColor : AppColors.primaryAccent), size: 20),
                        const SizedBox(width: 8),
                         Expanded(
                           child: Column(
                             crossAxisAlignment: CrossAxisAlignment.start,
                             children: [
                               Text(
                                  // Check if time was specified. If not (params['time_specified'] == false), show only Date
                                  timeSpecified
                                      // If specified (or null/default), show Date + Time
                                      ? DateFormat("EEEE, d 'de' MMMM • HH:mm", 'pt_BR').format(_selectedDate!)
                                      // If NOT specified, show only Date
                                      : DateFormat("EEEE, d 'de' MMMM", 'pt_BR').format(_selectedDate!),
                                 style: const TextStyle(
                                   color: Colors.white,
                                   fontSize: 16,
                                   fontWeight: FontWeight.w600,
                                 ),
                                 softWrap: true,
                               ),
                                 Text(
                                   feedbackText,
                                   style: TextStyle(color: feedbackColor, fontSize: 11, fontWeight: FontWeight.bold),
                                   softWrap: true,
                                 ),
                             ],
                           ),
                         ),
                      ],
                    ),
                  ),
                   const SizedBox(height: 16),
                ],

                // 2. SUGGESTIONS / SELECTION AREA
                if (suggestions.isNotEmpty) ...[
                  const Text(
                    "Sugestões Favoráveis (Numerologia)",
                    style: TextStyle(
                      color: AppColors.tertiaryText,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: suggestions.map((date) {
                      final isSelected = _selectedDate != null && 
                                         _selectedDate!.year == date.year && 
                                         _selectedDate!.month == date.month && 
                                         _selectedDate!.day == date.day;
                      // Don't show requested date in suggestions to avoid duplication if it was good
                      if (requestedDate != null && date.year == requestedDate.year && date.month == requestedDate.month && date.day == requestedDate.day) {
                         return const SizedBox.shrink(); 
                      }

                      return _buildPill(
                        // Sugestões de numerologia são dias, então mostramos apenas a data
                        // para evitar horários quebrados como "03:18"
                        label: DateFormat("d/MM").format(date),
                        icon: Icons.star_rounded, // Star for suggestions
                        color: isSelected ? AppColors.primaryAccent : AppColors.secondaryText,
                        isSelected: isSelected,
                        onTap: () {
                          setState(() {
                             if (isSelected) {
                               // Deselect: Revert to requested date
                               _selectedDate = requestedDate;
                             } else {
                               // Select this suggestion BUT PRESERVE THE TIME from current selection or requested date
                               final baseTime = _selectedDate ?? requestedDate ?? DateTime.now();
                               _selectedDate = DateTime(
                                 date.year,
                                 date.month,
                                 date.day,
                                 baseTime.hour,
                                 baseTime.minute,
                               );
                             }
                          });
                        },
                      );
                    }).toList(),
                  ),
                   const SizedBox(height: 24),
                ],

                // 3. MANUAL EDIT & CONFIRM
                Row(
                  children: [
                    // Manual Edit Button (Icon Only) if needed, or just keep the Date Picker logic on the main text if strictly needed. 
                    // User didn't explicitly ask for manual edit in this new flow, but it's safe to keep.
                    // For now, let's stick to the requested UI: Cancel | Confirm
                     Expanded(
                      child: TextButton(
                        onPressed: _handleCancel,
                        style: TextButton.styleFrom(foregroundColor: Colors.white60),
                        child: const Text("Cancelar"),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        // Confirm is enabled if we have a selection (Suggestion OR Original)
                        onPressed: _selectedDate != null ? _handleConfirm : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.success,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        child: Text(_selectedDate == requestedDate ? "Confirmar Data Pedida" : "Confirmar Nova Data"),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Custom Pill Widget matching TaskInputModal
  Widget _buildPill({
    required String label,
    required IconData icon,
    required Color color,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.2) : AppColors.background.withOpacity(0.5),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? color : Colors.white10,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? Icons.check_circle : icon, // Show Check if selected
              size: 14,
              color: isSelected ? color : Colors.white60,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white70,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                fontSize: 13,
              ),
            ),
            if (isSelected) ...[
               const SizedBox(width: 6),
               const Icon(Icons.close, size: 14, color: Colors.white54), // X to deselect
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildExecutedState() {
    return Container(
      margin: const EdgeInsets.only(top: 12, bottom: 12, left: 32, right: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.success.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.success.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: AppColors.success, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.action.title ?? "Ação Realizada",
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    decoration: TextDecoration.lineThrough,
                  ),
                ),
                if (_selectedDate != null)
                   Text(
                    "Agendado para: ${DateFormat('d/MM HH:mm').format(_selectedDate!)}",
                    style: const TextStyle(color: Colors.white60, fontSize: 12),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCancelledState() {
    return Container(
      margin: const EdgeInsets.only(top: 12, bottom: 12, left: 32, right: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.redAccent.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.cancel_outlined, color: Colors.redAccent.withOpacity(0.8), size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.action.title ?? "Ação Cancelada",
                  style: const TextStyle(
                    color: Colors.white60,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    decoration: TextDecoration.lineThrough,
                  ),
                ),
                Text(
                  widget.action.date != null ? "Agendamento descartado" : "Sugestão descartada",
                  style: const TextStyle(color: Colors.white38, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
