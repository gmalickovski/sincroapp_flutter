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
    
    // Determine Feedback for Requested Date
    bool isRequestedDateGood = false;
    String feedbackText = "Data solicitada";
    Color feedbackColor = AppColors.secondaryText;
    IconData feedbackIcon = Icons.calendar_today;

    if (requestedDate != null && suggestions.isNotEmpty) {
       // Check if requested date is roughly in the suggestions (ignoring time if needed, but let's match closely)
       // Use a tolerance or strict match? Let's assume day match for now.
       final isMatch = suggestions.any((s) => s.year == requestedDate.year && s.month == requestedDate.month && s.day == requestedDate.day);
       
       if (isMatch) {
         isRequestedDateGood = true;
         feedbackText = "Boa energia ✨";
         feedbackColor = AppColors.success;
         feedbackIcon = Icons.thumb_up_alt_rounded;
       } else {
         feedbackText = "Data desafiadora ⚠️";
         feedbackColor = Colors.orangeAccent;
         feedbackIcon = Icons.warning_rounded;
       }
    } else if (requestedDate != null) {
        // No suggestions provided by AI implied the requested date is GOOD (as per prompt instructions)
         isRequestedDateGood = true;
         feedbackText = "Boa energia ✨";
         feedbackColor = AppColors.success;
         feedbackIcon = Icons.thumb_up_alt_rounded;
    }

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
                      fontFamily: 'Inter',
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
                  InkWell(
                    onTap: _pickDate,
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min, // Keep tight
                        children: [
                          Icon(Icons.calendar_month, color: (isRequestedDateGood ? feedbackColor : AppColors.primaryAccent), size: 20),
                          const SizedBox(width: 8),
                           Column(
                             crossAxisAlignment: CrossAxisAlignment.start,
                             children: [
                               Text(
                                 _selectedDate!.hour == 0 && _selectedDate!.minute == 0 
                                      ? DateFormat("EEEE, d 'de' MMMM", 'pt_BR').format(_selectedDate!) 
                                      : DateFormat("EEEE, d 'de' MMMM • HH:mm", 'pt_BR').format(_selectedDate!),
                                 style: const TextStyle(
                                   color: Colors.white,
                                   fontSize: 16,
                                   fontWeight: FontWeight.w600,
                                 ),
                               ),
                               if (_selectedDate == requestedDate)
                                 Text(
                                   feedbackText,
                                   style: TextStyle(color: feedbackColor, fontSize: 11, fontWeight: FontWeight.bold),
                                 ),
                             ],
                           ),
                          const SizedBox(width: 8),
                          const Icon(Icons.edit, color: Colors.white30, size: 14), 
                        ],
                      ),
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
                      final isSelected = _selectedDate == date;
                      // Don't show requested date in suggestions to avoid duplication if it was good
                      if (requestedDate != null && date.year == requestedDate.year && date.month == requestedDate.month && date.day == requestedDate.day && date.hour == requestedDate.hour && date.minute == requestedDate.minute) {
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
                        onPressed: widget.onCancel,
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
}
