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
  bool _userSelectedSuggestion = false;
  bool _isCancelled = false;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.action.date;
    // Restaura estado persistido — se o usuário já cancelou/confirmou, mantém esse estado
    _isCancelled = widget.action.isCancelled;
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

  @override
  Widget build(BuildContext context) {
    if (_isCancelled) {
      return _buildCancelledState();
    }

    if (widget.action.isExecuted) {
      return _buildExecutedState();
    }

    // Extract payload safely
    final payload =
        widget.action.data['payload'] as Map<String, dynamic>? ?? {};
    final title = widget.action.title ?? payload['title'] ?? 'Nova Ação';

    // Suggestions
    final suggestions = widget.action.suggestedDates;

    // Requested Date (Original)
    final requestedDate = widget.action.date;

    // Helper to get feedback for ANY date
    Map<String, dynamic> getFeedbackForDate(DateTime date) {
      // 1. Is it the Requested Date? Use backend analysis.
      if (requestedDate != null &&
          date.year == requestedDate.year &&
          date.month == requestedDate.month &&
          date.day == requestedDate.day) {
        final analysis =
            widget.action.data['analysis'] as Map<String, dynamic>?;
        if (analysis != null) {
          final String status = analysis['status']?.toString() ?? "Neutro";
          if (status == "Dia de Sorte") {
            return {
              'text': "Dia de Sorte 🍀",
              'color': AppColors.success,
              'icon': Icons.auto_awesome
            };
          }
          if (status == "Favorável") {
            return {
              'text': "Boa energia ✨",
              'color': AppColors.success,
              'icon': Icons.thumb_up_alt_rounded
            };
          }
          if (status == "Neutro") {
            return {
              'text': "Energia Neutra ⚖️",
              'color': Colors.blueGrey,
              'icon': Icons.balance
            };
          }
          return {
            'text': "Data desafiadora ⚠️",
            'color': Colors.orangeAccent,
            'icon': Icons.warning_rounded
          };
        }
        // Fallback if no analysis but matches suggestions
        if (suggestions.any((s) =>
            s.year == date.year &&
            s.month == date.month &&
            s.day == date.day)) {
          return {
            'text': "Boa energia ✨",
            'color': AppColors.success,
            'icon': Icons.thumb_up_alt_rounded
          };
        }
        
        // Se não tem analysis, mas a IA mandou sugestões diferentes, 
        // significa que a data pedida não era boa!
        if (suggestions.isNotEmpty) {
           return {
            'text': "Data não favorável ⚠️",
            'color': Colors.redAccent,
            'icon': Icons.warning_rounded
          };
        }

        // Default fallback for requested date 
        // (quando IA não reclamou da data e não mandou alternativas)
        return {
          'text': "Data Favorável ✨",
          'color': AppColors.success,
          'icon': Icons.thumb_up_alt_rounded
        };
      }

      // 2. Is it a Suggestion? (Always Good if it came from suggestions list)
      if (suggestions.any((s) =>
          s.year == date.year && s.month == date.month && s.day == date.day)) {
        return {
          'text': "Boa energia ✨",
          'color': AppColors.success,
          'icon': Icons.thumb_up_alt_rounded
        };
      }

      // 3. Manual/Other
      return {
        'text': "Data Selecionada",
        'color': AppColors.secondaryText,
        'icon': Icons.edit_calendar
      };
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
    bool isTimeExplicitlySpecified() {
      // 1. Check Params
      if (widget.action.data['params'] != null &&
          widget.action.data['params'].containsKey('time_specified')) {
        return widget.action.data['params']['time_specified'] == true;
      }
      // 2. Check Payload
      if (widget.action.data['payload'] != null &&
          widget.action.data['payload'].containsKey('time_specified')) {
        return widget.action.data['payload']['time_specified'] == true;
      }
      // 3. Fallback: If time is 00:00, assume NOT specified. Otherwise, assume specified.
      if (_selectedDate != null &&
          _selectedDate!.hour == 0 &&
          _selectedDate!.minute == 0) {
        return false;
      }
      return true; // Default
    }

    final bool timeSpecified = isTimeExplicitlySpecified();
    final isMobile = MediaQuery.of(context).size.width < 500;

    return Container(
      margin: EdgeInsets.only(
        top: 12,
        bottom: 12,
        left: isMobile ? 8 : 24,
        right: 8,
      ),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(20),
        border:
            Border.all(color: AppColors.primaryAccent.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
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
                // 1. main selected date OR unselected requested date
                if (_selectedDate != null && (requestedDate != null || _userSelectedSuggestion)) ...[
                  const Text(
                    "Data Escolhida",
                    style: TextStyle(
                      color: AppColors.tertiaryText,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildMainDatePill(
                    date: _selectedDate!,
                    isGood: isGood,
                    feedbackText: feedbackText,
                    feedbackColor: feedbackColor,
                    feedbackIcon: feedbackIcon,
                    timeSpecified: timeSpecified,
                    isSelected: true,
                    // Só permite deselecionar se for ruim
                    allowDeselect: !isGood,
                    onTap: () {
                      if (!isGood) {
                        setState(() {
                          _selectedDate = null;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                ] else if (requestedDate != null) ...[
                  const Text(
                    "Data Solicitada",
                    style: TextStyle(
                      color: AppColors.tertiaryText,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildMainDatePill(
                    date: requestedDate,
                    isGood: getFeedbackForDate(requestedDate)['color'] ==
                        AppColors.success,
                    feedbackText: getFeedbackForDate(requestedDate)['text'],
                    feedbackColor: getFeedbackForDate(requestedDate)['color'],
                    feedbackIcon: getFeedbackForDate(requestedDate)['icon'],
                    timeSpecified: timeSpecified,
                    isSelected: false,
                    allowDeselect: false,
                    onTap: () {
                      setState(() {
                        _selectedDate = requestedDate;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                ],

                // 2. SUGGESTIONS
                if (suggestions.isNotEmpty && (!isGood || _selectedDate != requestedDate)) ...[
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
                      if (requestedDate != null &&
                          date.year == requestedDate.year &&
                          date.month == requestedDate.month &&
                          date.day == requestedDate.day) {
                        return const SizedBox.shrink();
                      }

                      return _buildPill(
                        label: DateFormat("d/MM").format(date),
                        icon: Icons.star_rounded,
                        color: isSelected
                            ? AppColors.primaryAccent
                            : AppColors.secondaryText,
                        isSelected: isSelected,
                        onTap: () {
                          setState(() {
                            if (isSelected) {
                              _selectedDate = requestedDate;
                              _userSelectedSuggestion = false;
                            } else {
                              final baseTime = _selectedDate ??
                                  requestedDate ??
                                  DateTime.now();
                              _selectedDate = DateTime(
                                date.year,
                                date.month,
                                date.day,
                                baseTime.hour,
                                baseTime.minute,
                              );
                              _userSelectedSuggestion = true;
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
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _handleCancel,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white60,
                          side: const BorderSide(color: Colors.white24),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text(
                          "Cancelar",
                          style: TextStyle(fontSize: 14),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed:
                            _selectedDate != null ? _handleConfirm : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.success,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        child: const Text(
                          "Confirmar",
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
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
          color: isSelected
              ? color.withValues(alpha: 0.2)
              : AppColors.background.withValues(alpha: 0.5),
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
              const Icon(Icons.close,
                  size: 14, color: Colors.white54), // X to deselect
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
        color: AppColors.success.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
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
        color: Colors.redAccent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.cancel_outlined,
              color: Colors.redAccent.withValues(alpha: 0.8), size: 24),
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
                  widget.action.date != null
                      ? "Agendamento descartado"
                      : "Sugestão descartada",
                  style: const TextStyle(color: Colors.white38, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainDatePill({
    required DateTime date,
    required bool isGood,
    required String feedbackText,
    required Color feedbackColor,
    required IconData feedbackIcon,
    required bool timeSpecified,
    required bool isSelected,
    required bool allowDeselect,
    required VoidCallback onTap,
  }) {
    final formattedDate = timeSpecified
        ? DateFormat("EEEE, d 'de' MMMM • HH:mm", 'pt_BR').format(date)
        : DateFormat("EEEE, d 'de' MMMM", 'pt_BR').format(date);

    return InkWell(
      onTap: allowDeselect || !isSelected ? onTap : null,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? feedbackColor.withValues(alpha: 0.15)
              : AppColors.background.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? feedbackColor : Colors.white10,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(
              isSelected && isGood ? Icons.check_circle : feedbackIcon,
              size: 18,
              color: isSelected ? feedbackColor : Colors.white60,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    formattedDate,
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.white70,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.normal,
                      fontSize: 14,
                    ),
                    softWrap: true,
                  ),
                  Text(
                    feedbackText,
                    style: TextStyle(
                      color: feedbackColor,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                    softWrap: true,
                  ),
                ],
              ),
            ),
            if (isSelected && allowDeselect) ...[
              const SizedBox(width: 12),
              const Icon(Icons.close, size: 16, color: Colors.white54),
            ],
          ],
        ),
      ),
    );
  }
}
