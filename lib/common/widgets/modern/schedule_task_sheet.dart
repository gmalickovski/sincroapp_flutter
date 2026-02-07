import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:sincro_app_flutter/common/constants/app_colors.dart';
import 'package:sincro_app_flutter/models/recurrence_rule.dart';
import 'package:sincro_app_flutter/common/widgets/modern/custom_time_picker_dialog.dart';
import 'package:sincro_app_flutter/models/date_picker_result.dart';
import 'package:sincro_app_flutter/common/widgets/custom_date_picker_modal.dart';
import 'package:sincro_app_flutter/common/widgets/custom_month_year_picker.dart';
import 'package:sincro_app_flutter/common/widgets/vibration_pill.dart';
import 'package:sincro_app_flutter/models/user_model.dart';
import 'package:sincro_app_flutter/services/numerology_engine.dart';
import 'package:sincro_app_flutter/common/widgets/scrollable_chips_row.dart';

class ScheduleTaskSheet extends StatefulWidget {
  final DateTime? initialDate;
  final TimeOfDay? initialTime;
  final RecurrenceRule? initialRecurrence;
  final Duration? initialReminderOffset; // Novo par├ómetro
  final DateTime? goalDeadline; // Prazo final da meta (se houver)
  final UserModel userData;

  const ScheduleTaskSheet({
    super.key,
    this.initialDate,
    this.initialTime,
    this.initialRecurrence,
    this.initialReminderOffset, // Recebe no construtor
    this.goalDeadline, // Novo parâmetro para limitar opções
    required this.userData,
  });

  @override
  State<ScheduleTaskSheet> createState() => _ScheduleTaskSheetState();
}

class _ScheduleTaskSheetState extends State<ScheduleTaskSheet> {
  late DateTime _focusedDay;
  late DateTime _selectedDay;
  late DateTime _todayMidnight;
  TimeOfDay? _selectedTime;
  late RecurrenceRule _recurrenceRule;
  late NumerologyEngine _engine;
  
  // UI State
  bool _isAllDay = false;
  
  // Reminder State
  bool _showReminder = false; // Controls visibility of reminder options
  Duration? _selectedReminderOffset;
  
  // Recurrence State
  bool _showRecurrence = false; // Controls visibility of recurrence options
  
  // Duration State
  int? _selectedDuration;

  // REMOVED ScrollControllers (managed internally by ScrollableChipsRow)

  @override
  void dispose() {
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _selectedReminderOffset = widget.initialReminderOffset; // Inicializa
    final now = DateTime.now();
    _todayMidnight = DateTime(now.year, now.month, now.day);
    
    _focusedDay = widget.initialDate ?? now;
    _selectedDay = widget.initialDate ?? now;
    _selectedDay = widget.initialDate ?? now;
    _selectedTime = widget.initialTime;
    _recurrenceRule = widget.initialRecurrence ?? RecurrenceRule();
    _showRecurrence = _recurrenceRule.type != RecurrenceType.none;
    _showReminder = _selectedReminderOffset != null;
    
    _isAllDay = _selectedTime == null;

    // Configura motor de numerologia
    if (widget.userData.nomeAnalise.isNotEmpty &&
        widget.userData.dataNasc.isNotEmpty) {
      _engine = NumerologyEngine(
        nomeCompleto: widget.userData.nomeAnalise,
        dataNascimento: widget.userData.dataNasc,
      );
    } else {
      _engine = NumerologyEngine(
        nomeCompleto: "Sincro App",
        dataNascimento: "01/01/2000",
      );
    }
  }

  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    setState(() {
      _selectedDay = selectedDay;
      _focusedDay = focusedDay;
    });
  }
  
  void _toggleAllDay(bool value) {
    setState(() {
      _isAllDay = value;
      if (value) {
        _selectedTime = null; 
      } else {
        // If turning on time, immediately pick a time
        _pickTime();
      }
    });
  }

  Future<void> _pickTime() async {
    final now = TimeOfDay.now();
    final initial = _selectedTime ?? TimeOfDay(hour: now.hour + 1, minute: 0);

    final dynamic picked = await showDialog(
      context: context,
      builder: (context) => CustomTimePickerDialog(initialTime: initial),
    );

    if (picked != null) {
      if (picked is TimePickerResult) {
         setState(() {
           _selectedTime = picked.time;
           _selectedDuration = picked.durationMinutes;
           _isAllDay = false;
         });
      } else if (picked is TimeOfDay) {
         // Fallback just in case
         setState(() {
           _selectedTime = picked;
           _isAllDay = false;
         });
      }
    } else {
        // user cancelled picker
        if (_selectedTime == null) {
            // Revert to all day if they cancelled initial pick
            setState(() => _isAllDay = true); 
        }
    }
  }

  Future<void> _pickReminderTime() async {
    final now = TimeOfDay.now();
    final TimeOfDay? picked = await showDialog<TimeOfDay>(
      context: context,
      builder: (context) => CustomTimePickerDialog(initialTime: now),
    );

    if (picked != null) {
      setState(() {
         // Calculate offset from base time
         final baseHour = _selectedTime?.hour ?? 0;
         final baseMinute = _selectedTime?.minute ?? 0;
         final baseDt = DateTime(2024, 1, 1, baseHour, baseMinute);
         
         var targetDt = DateTime(2024, 1, 1, picked.hour, picked.minute);
         
         // If target is after base, assume it's for the previous day
         if (targetDt.isAfter(baseDt)) {
            targetDt = targetDt.subtract(const Duration(days: 1));
         }
         
         _selectedReminderOffset = baseDt.difference(targetDt);
      });
    }
  }

  void _onSave() {
     // Calculate reminder time if applicable
     TimeOfDay? reminderTime;
     if (_selectedReminderOffset != null) {
       final hour = _selectedTime?.hour ?? 0; // Default to midnight if All Day
       final minute = _selectedTime?.minute ?? 0;
       final dt = DateTime(2024, 1, 1, hour, minute);
       final reminded = dt.subtract(_selectedReminderOffset!);
       reminderTime = TimeOfDay(hour: reminded.hour, minute: reminded.minute);
     }

     // Use a data selecionada base (meia noite)
     DateTime finalDateTime = DateTime(
       _selectedDay.year,
       _selectedDay.month,
       _selectedDay.day,
     );
     
     // Combina com a hora se n├úo for dia inteiro
     if (!_isAllDay && _selectedTime != null) {
       finalDateTime = DateTime(
         _selectedDay.year,
         _selectedDay.month,
         _selectedDay.day,
         _selectedTime!.hour,
         _selectedTime!.minute,
       );
     }

     final result = DatePickerResult(
       finalDateTime,
       _recurrenceRule,
       reminderTime: reminderTime,
       reminderOffset: _selectedReminderOffset,
       hasTime: !_isAllDay && _selectedTime != null,
       durationMinutes: _selectedDuration,
     );
     
     Navigator.pop(context, result);
  }

  Future<void> _showMonthYearPicker() async {
    final DateTime? pickedDate = await showDialog<DateTime>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: CustomMonthYearPicker(
            initialDate: _focusedDay,
            firstDate: DateTime(2020),
            lastDate: DateTime(2101),
          ),
        );
      },
    );

    if (pickedDate != null && mounted) {
      setState(() {
        _focusedDay = pickedDate;
      });
    }
  }

  String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
  
  bool _isSameMonth(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month;
  }

  @override
  Widget build(BuildContext context) {
    final double maxSheetHeight = MediaQuery.of(context).size.height * 0.9;

    return Container(
      constraints: BoxConstraints(maxHeight: maxSheetHeight),
      decoration: const BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 1. Header (Minimalist Icons)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: AppColors.secondaryText, size: 24),
                  tooltip: 'Cancelar',
                ),
                Expanded(
                  child: Text(
                    "Agendar Tarefa",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.primaryText,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _onSave,
                  icon: const Icon(Icons.check, color: AppColors.primary, size: 28),
                  tooltip: 'Salvar',
                ),
              ],
            ),
          ),
          
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 24),
              child: Column(
                children: [
                   // 2. Calendar
                   _buildCalendar(),
                   const SizedBox(height: 16), // Spacing requested
                   
                   const Divider(color: AppColors.border, height: 1),
                   
                   // 3. Time Row (Hor├írio)
                   _buildTimeRow(),
                    

                   
                   const Divider(color: AppColors.border, height: 1),
                   
                   // 5. Recurrence Row (Repetir)
                   _buildRecurrenceRow(),

                   const Divider(color: AppColors.border, height: 1),

                   // 6. Reminder Row (Lembrete)
                   _buildReminderRow(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- Helpers ---
  
  bool get _isFreePlan {
    final plan = widget.userData.subscription.plan.name.toLowerCase();
    return plan == 'essencial' || plan == 'gratuito' || plan == 'free';
  }

  bool get _canUseRecurrence {
    // Only Desperta and Sinergia
    return !_isFreePlan;
  }

  bool get _canUseReminders {
    // Only Desperta and Sinergia
    return !_isFreePlan;
  }

  void _showUpgradeDialog(String feature) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Visualizar recurso: $feature"),
        content: const Text(
          "Este recurso está disponível apenas nos planos Desperta e Sinergia.\n\n"
          "Faça o upgrade para desbloquear recorrência, lembretes e muito mais!",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Agora não"),
          ),
          FilledButton(
            onPressed: () {
               Navigator.pop(context);
               // TODO: Navigate to subscription page
            },
            child: const Text("Ver Planos"),
          ),
        ],
      ),
    );
  }

  // --- Widget Builders ---

  Widget _buildTimeRow() {
    String timeText = _isAllDay ? "Dia inteiro" : (_selectedTime?.format(context) ?? "Definir");
    if (!_isAllDay && _selectedDuration != null) {
       if (_selectedDuration! >= 60) {
          final h = _selectedDuration! ~/ 60;
          final m = _selectedDuration! % 60;
          if (m > 0) {
            timeText += " • ${h}h ${m}min";
          } else {
            timeText += " • ${h}h";
          }
       } else {
          timeText += " • ${_selectedDuration} min";
       }
    }

    return InkWell(
      onTap: _isAllDay ? null : _pickTime,
      hoverColor: AppColors.primary.withOpacity(0.05),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: const [
                Icon(Icons.access_time, color: AppColors.secondaryText),
                SizedBox(width: 12),
                Text("Horário", style: TextStyle(color: AppColors.primaryText, fontSize: 16)),
              ],
            ),
            Row(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Text(
                    timeText,
                    style: TextStyle(
                      color: _isAllDay ? AppColors.secondaryText : AppColors.primary,
                      fontSize: 14,
                      fontWeight: _isAllDay ? FontWeight.normal : FontWeight.w600,
                    ),
                  ),
                ),
                Switch(
                  value: !_isAllDay, 
                  activeColor: AppColors.primary,
                  overlayColor: WidgetStateProperty.all(Colors.transparent),
                  onChanged: (val) => _toggleAllDay(!val),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecurrenceRow() {
    final bool isRepeating = _recurrenceRule.type != RecurrenceType.none;
    final String summary = isRepeating ? _recurrenceRule.getSummaryText() : "Nunca";

    return Column(
      children: [
        InkWell(
           onTap: () {
             if (!_canUseRecurrence) {
               _showUpgradeDialog("Recorrência");
               return;
             }
             // Toggle switch logic here if tap row
             setState(() {
                if (isRepeating) {
                   _recurrenceRule = RecurrenceRule(type: RecurrenceType.none);
                } else {
                   _recurrenceRule = RecurrenceRule(
                      type: RecurrenceType.daily,
                      endDate: null, 
                   ); 
                }
             });
           },
           hoverColor: AppColors.primary.withOpacity(0.05),
           child: Padding(
             padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
             child: Row(
               children: [
                  const Icon(Icons.repeat, color: AppColors.secondaryText),
                  const SizedBox(width: 12),
                  const Text("Repetir", style: TextStyle(color: AppColors.primaryText, fontSize: 16)),
                  if (!_canUseRecurrence) ...[
                    const SizedBox(width: 8),
                    const Icon(Icons.lock_outline, size: 16, color: AppColors.secondaryText),
                  ],
                  const Spacer(),
                  Text(
                    summary,
                    style: const TextStyle(color: AppColors.secondaryText, fontSize: 14),
                  ),
                  const SizedBox(width: 12),
                  Switch(
                    value: _showRecurrence,
                    activeColor: AppColors.primary,
                    overlayColor: WidgetStateProperty.all(Colors.transparent),
                    onChanged: !_canUseRecurrence ? null : (val) {
                      setState(() {
                        _showRecurrence = val;
                        if (!val) {
                          _recurrenceRule = RecurrenceRule(type: RecurrenceType.none);
                        } else {
                          // Allow "No Selection" state - implicit RecurrenceType.none until user picks
                          // OR default to Daily as user convenience?
                          // User requested "sem seleção". So we keep it as none until they pick.
                          if (_recurrenceRule.type == RecurrenceType.none) {
                              // Ensure it's none.
                          }
                        }
                      });
                    },
                  ),
               ],
             ),
           ),
        ),
        
        // Inline Recurrence Options
        AnimatedSize(
           duration: const Duration(milliseconds: 300),
           curve: Curves.easeInOut,
           child: _showRecurrence // Use decoupled state 
             ? Padding(
                 padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                 child: Column(
                   crossAxisAlignment: CrossAxisAlignment.start,
                   children: [
                     // Frequency Chips
                     ScrollableChipsRow(
                       children: [
                           _buildRecurrenceChip("Diariamente", RecurrenceType.daily),
                           const SizedBox(width: 8),
                           _buildRecurrenceChip("Semanalmente", RecurrenceType.weekly),
                           const SizedBox(width: 8),
                           _buildRecurrenceChip("Mensalmente", RecurrenceType.monthly),
                       ],
                     ),
                     
                      // Weekly Days Selection (if Weekly)
                      if (_recurrenceRule.type == RecurrenceType.weekly)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16.0),
                          child: _buildWeeklyDaysSelector(),
                        ),
                        
                      const SizedBox(height: 16),
                      // Removed Termina em label

                      // Duration / End Date Chips
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                             // Removed "Nunca" to enforce finite recurrence
                             // _buildDurationChip("1 Mês", const Duration(days: 30)),
                             const SizedBox(width: 8),
                             // _buildDurationChip("6 Meses", const Duration(days: 180)),
                             const SizedBox(width: 8),
                             // _buildDurationChip("1 Ano", const Duration(days: 365)),
                             const SizedBox(width: 8),
                             /* ActionChip( label: Text(_recurrenceRule.endDate != null && 
                                 _recurrenceRule.endDate!.difference(_selectedDay).inDays != 30 && // Rough check to differentiate from presets
                                 _recurrenceRule.endDate!.difference(_selectedDay).inDays != 365
                                  ? DateFormat('dd/MM/yy').format(_recurrenceRule.endDate!)
                                  : "Definir Data",
                                ),
                                onPressed: _pickRecurrenceEndDate,
                                backgroundColor: AppColors.background,
                                labelStyle: TextStyle(
                                  color: (_recurrenceRule.endDate != null && 
                                          _recurrenceRule.endDate!.difference(_selectedDay).inDays != 30 &&
                                          _recurrenceRule.endDate!.difference(_selectedDay).inDays != 365)
                                      ? Colors.white 
                                      : AppColors.primary,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                  side: BorderSide(
                                    color: (_recurrenceRule.endDate != null && 
                                            _recurrenceRule.endDate!.difference(_selectedDay).inDays != 30 &&
                                            _recurrenceRule.endDate!.difference(_selectedDay).inDays != 365)
                                        ? AppColors.primary 
                                        : AppColors.primary.withOpacity(0.5),
                                  ),
                                ),
                                // Fill if custom date selected
                                elevation: 0,
                                visualDensity: VisualDensity.compact, ), */
                          ],
                        ),
                      ),
                   ],
                 ),
               )
             : const SizedBox.shrink(),
        ),
      ],
    );
  }

  Widget _buildRecurrenceChip(String label, RecurrenceType type) {
    // Validação de Prazo da Meta
    bool isDisabled = false;
    String? disabledReason;

    if (widget.goalDeadline != null) {
      final daysUntilDeadline = widget.goalDeadline!.difference(_selectedDay).inDays;
      
      if (type == RecurrenceType.weekly && daysUntilDeadline < 7) {
        isDisabled = true;
        disabledReason = "Meta acaba em menos de uma semana";
      } else if (type == RecurrenceType.monthly && daysUntilDeadline < 28) { // 28 dias margem segura
        isDisabled = true;
        disabledReason = "Meta acaba em menos de um mês";
      }
    }

    final isSelected = _recurrenceRule.type == type;
    
    // Se a opção selecionada se tornou inválida (ex: mudou dia), reseta
    if (isSelected && isDisabled) {
       // O ideal seria forçar reset no estado, mas build loop perigo.
       // Deixa visualmente desativado ou selecionado com erro?
       // Vamos permitir desmarcar, mas visualmente mostrar erro.
    }

    Widget chip = ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: isDisabled ? null : (val) {
        if (val) {
          setState(() {
            _recurrenceRule = _recurrenceRule.copyWith(type: type);
            // Initialize days if switching to weekly and empty
             if (type == RecurrenceType.weekly && _recurrenceRule.daysOfWeek.isEmpty) {
                 _recurrenceRule = _recurrenceRule.copyWith(daysOfWeek: [_selectedDay.weekday]);
             }
          });
        }
      },
      // Cores desabilitadas
      disabledColor: AppColors.background.withOpacity(0.5),
      
      selectedColor: isDisabled ? AppColors.secondaryText : AppColors.primary, // Cinza se invalido
      backgroundColor: AppColors.background,
      labelStyle: TextStyle(
        color: isDisabled 
            ? AppColors.secondaryText.withOpacity(0.5) 
            : (isSelected ? Colors.white : AppColors.secondaryText),
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isDisabled 
              ? AppColors.border.withOpacity(0.3)
              : (isSelected ? AppColors.primary : AppColors.border)
        ),
      ),
    );

    if (isDisabled && disabledReason != null) {
      return Tooltip(
        message: disabledReason,
        triggerMode: TooltipTriggerMode.tap,
        child: Opacity(opacity: 0.5, child: chip),
      );
    }
    
    return chip;
  }

  Widget _buildWeeklyDaysSelector() {
    final List<int> orderedDays = [1, 2, 3, 4, 5, 6, 7]; // Mon-Sun
    final Map<int, String> dayLabels = {
      1: 'S', 2: 'T', 3: 'Q', 4: 'Q', 5: 'S', 6: 'S', 7: 'D'
    };

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: orderedDays.map((day) {
        final isSelected = _recurrenceRule.daysOfWeek.contains(day);
        return InkWell(
          onTap: () {
            setState(() {
              final currentDays = List<int>.from(_recurrenceRule.daysOfWeek);
              if (isSelected) {
                if (currentDays.length > 1) currentDays.remove(day);
              } else {
                currentDays.add(day);
              }
              _recurrenceRule = _recurrenceRule.copyWith(daysOfWeek: currentDays);
            });
          },
          customBorder: const CircleBorder(),
          // Reverted hover colors as per user clarification
          child: Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isSelected ? AppColors.primary : Colors.transparent,
              shape: BoxShape.circle,
              border: Border.all(color: isSelected ? AppColors.primary : AppColors.border),
            ),
            child: Text(
              dayLabels[day]!,
              style: TextStyle(
                color: isSelected ? Colors.white : AppColors.secondaryText,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildReminderRow() {
    final bool hasReminder = _selectedReminderOffset != null;
    final String summary = _getReminderSummary();

    final bool canRemind = _canUseReminders && !_isAllDay;
    // Opacity logic: If AllDay, reduce opacity of Icon/Title.
    final double contentOpacity = _isAllDay ? 0.5 : 1.0;

    return Column(
      children: [
        InkWell(
          onTap: () {
            if (!_canUseReminders) {
               _showUpgradeDialog("Lembretes");
               return;
            }
            if (_isAllDay) return;

            setState(() {
               _showReminder = !_showReminder; // Toggle the visibility state
               if (!_showReminder) {
                 _selectedReminderOffset = null;
               } else {
                 // If turning on, and no reminder is set, default to "Na hora"
                 if (_selectedReminderOffset == null) {
                   _selectedReminderOffset = Duration.zero;
                 }
               }
            });
          },
          hoverColor: AppColors.primary.withOpacity(0.05),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: Row(
              children: [
                 // Opacity wrapper for Icon and Title
                 Opacity(
                   opacity: contentOpacity,
                   child: Row(
                     mainAxisSize: MainAxisSize.min,
                     children: const [
                       Icon(Icons.notifications_none_rounded, color: AppColors.secondaryText),
                       SizedBox(width: 12),
                       Text("Lembrete", style: TextStyle(color: AppColors.primaryText, fontSize: 16)),
                     ],
                   ),
                 ),
                 
                 if (!_canUseReminders && !_isAllDay) ...[
                    const SizedBox(width: 8),
                    const Icon(Icons.lock_outline, size: 16, color: AppColors.secondaryText),
                 ],
                 
                 const Spacer(),
                 
                 // Trailing Content Logic
                 if (_isAllDay)
                    Text(
                      "Defina um horário",
                      style: TextStyle(color: AppColors.secondaryText.withOpacity(0.6), fontSize: 14),
                    )
                 else ...[
                    // Normal or Premium-locked State
                    if (!_canUseReminders)
                       Text(
                         "Recurso Premium",
                         style: TextStyle(color: AppColors.secondaryText.withOpacity(0.6), fontSize: 12),
                       )
                    else
                       Text(
                         summary,
                         style: const TextStyle(color: AppColors.secondaryText, fontSize: 14),
                       ),
                    
                    const SizedBox(width: 12),
                     Switch(
                        value: _showReminder,
                        activeColor: AppColors.primary,
                        overlayColor: WidgetStateProperty.all(Colors.transparent),
                        onChanged: !_canUseReminders ? null : (val) {
                          setState(() {
                            _showReminder = val;
                            if (!val) {
                              _selectedReminderOffset = null;
                            } else {
                              // If turning on, and no reminder is set, default to "Na hora"
                              if (_selectedReminderOffset == null) {
                                _selectedReminderOffset = Duration.zero;
                              }
                            }
                          });
                        },
                     ),
                 ]
              ],
            ),
          ),
        ),
        
        // Reminder Options (Expandable)
        AnimatedSize(
           duration: const Duration(milliseconds: 300),
           curve: Curves.easeInOut,
           child: _showReminder && !_isAllDay // Use decoupled state
             ? Padding(
                 padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                 child: ScrollableChipsRow(
                   children: [
                       _buildReminderChip("Na hora", Duration.zero),
                       const SizedBox(width: 8),
                       _buildReminderChip("10 min antes", const Duration(minutes: 10)),
                       const SizedBox(width: 8),
                       _buildReminderChip("30 min antes", const Duration(minutes: 30)),
                       const SizedBox(width: 8),
                       _buildReminderChip("1 h antes", const Duration(hours: 1)),
                       const SizedBox(width: 8),
                       _buildReminderChip("1 dia antes", const Duration(days: 1)),
                       const SizedBox(width: 8),
                       ActionChip(
                         label: const Text("Definir horário"),
                         onPressed: _pickReminderTime,
                         backgroundColor: AppColors.background,
                         labelStyle: const TextStyle(color: AppColors.primary),
                         shape: RoundedRectangleBorder(
                           borderRadius: BorderRadius.circular(20),
                           side: const BorderSide(color: AppColors.primary),
                         ),
                       ),
                   ],
                 ),
               )
             : const SizedBox.shrink(),
        ),
      ],
    );
  }

  String _getReminderSummary() {
    if (_selectedReminderOffset == null) return "Sem lembrete";
    if (_selectedReminderOffset == Duration.zero) return "Na hora";
    final minutes = _selectedReminderOffset!.inMinutes;
    if (minutes < 60) return "$minutes min antes";
    final hours = _selectedReminderOffset!.inHours;
    if (hours < 24) return "$hours h antes";
    return "${_selectedReminderOffset!.inDays} dia(s) antes";
  }

  Widget _buildDurationChip(String label, Duration? duration) {
    // Check if selected:
    // If duration is null (Nunca) -> endDate must be null
    // If duration is set -> endDate must match _selectedDay + duration (approx)
    bool isSelected = false;
    
    if (duration == null) {
      isSelected = _recurrenceRule.endDate == null;
    } else {
      if (_recurrenceRule.endDate != null) {
         final diff = _recurrenceRule.endDate!.difference(_selectedDay).inDays;
         // Allow slight flexibility or exact match? Exact match is safer for now.
         // 30 days vs 1 Month logic might be tricky, so sticking to fixed days (30/365)
         isSelected = diff == duration.inDays;
      }
    }

    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (val) {
        if (val) {
          setState(() {
             if (duration == null) {
               _recurrenceRule = _recurrenceRule.copyWith(clearEndDate: true);
             } else {
               _recurrenceRule = _recurrenceRule.copyWith(
                 endDate: _selectedDay.add(duration),
               );
             }
          });
        }
      },
      selectedColor: AppColors.primary,
      backgroundColor: AppColors.background,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : AppColors.secondaryText,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: isSelected ? AppColors.primary : AppColors.border),
      ),
    );
  }

  Future<void> _pickRecurrenceEndDate() async {
    final DateTime? picked = await showDialog<DateTime>(
      context: context,
      builder: (context) => Dialog(
         backgroundColor: Colors.transparent,
         insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
         child: CustomMonthYearPicker( // Reuse or standard picker? User images showed standard calendar, but we have CustomDatePickerModal too.
           initialDate: _recurrenceRule.endDate ?? _selectedDay.add(const Duration(days: 7)),
           firstDate: _selectedDay, // Cannot end before start
           lastDate: DateTime(2101),
         ),
      ),
    );

    if (picked != null) {
      // If picked via CustomMonthYearPicker it selects a whole day/month focus. 
      // Maybe simpler to use standard showDatePicker for exact date or CustomDatePickerModal if needed.
      // Given the flow, let's stick to standard internal logic or reusing existing.
      // But CustomMonthYearPicker is for... month/year.
      // I should use showDatePicker for specific day.
      setState(() {
        _recurrenceRule = _recurrenceRule.copyWith(endDate: picked);
      });
    }
  }

  Widget _buildReminderChip(String label, Duration? offset) {
    final isSelected = _selectedReminderOffset == offset;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (val) {
        setState(() => _selectedReminderOffset = offset);
      },
      selectedColor: AppColors.primary,
      backgroundColor: AppColors.background,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : AppColors.secondaryText,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: isSelected ? AppColors.primary : AppColors.border),
      ),
    );
  }

  Widget _buildCalendar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: TableCalendar(
        locale: 'pt_BR',
        firstDay: DateTime.utc(2020, 1, 1),
        lastDay: DateTime.utc(2101, 12, 31),
        focusedDay: _focusedDay,
        currentDay: DateTime.now(),
        selectedDayPredicate: (day) => _isSameDay(_selectedDay, day),
        onDaySelected: _onDaySelected,
        onPageChanged: (focused) => _focusedDay = focused,
        calendarFormat: CalendarFormat.month,
        
        // --- Styles ---
        headerStyle: const HeaderStyle(
          titleCentered: true,
          formatButtonVisible: false,
          titleTextStyle: TextStyle(height: 0, fontSize: 0), // Oculta titulo padrao
          leftChevronIcon: Icon(Icons.chevron_left, color: AppColors.primaryText),
          rightChevronIcon: Icon(Icons.chevron_right, color: AppColors.primaryText),
          leftChevronMargin: EdgeInsets.symmetric(horizontal: 4),
          rightChevronMargin: EdgeInsets.symmetric(horizontal: 4),
        ),
        daysOfWeekStyle: const DaysOfWeekStyle(
          weekdayStyle: TextStyle(color: AppColors.secondaryText, fontSize: 12),
          weekendStyle: TextStyle(color: AppColors.secondaryText, fontSize: 12),
        ),
        rowHeight: 54,
        calendarStyle: const CalendarStyle(
           defaultDecoration: BoxDecoration(),
           selectedDecoration: BoxDecoration(),
           todayDecoration: BoxDecoration(),
           outsideDecoration: BoxDecoration(),
        ),

        // --- Custom Builders (Restoring Visuals) ---
        calendarBuilders: CalendarBuilders(
          headerTitleBuilder: (context, day) {
              final titleText = _capitalize(DateFormat.yMMMM('pt_BR').format(day));
              return Center(
                child: InkWell(
                  onTap: _showMonthYearPicker,
                  borderRadius: BorderRadius.circular(8.0),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 12.0),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          titleText,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: AppColors.primaryText,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.unfold_more_rounded, color: AppColors.secondaryText, size: 20),
                      ],
                    ),
                  ),
                ),
              );
          },
          defaultBuilder: (context, day, focusedDay) {
            return _buildCalendarDayCell(
              day: day,
              isEnabled: true,
              isSelected: false,
              isToday: _isSameDay(day, _todayMidnight),
              isOutside: false,
            );
          },
          selectedBuilder: (context, day, focusedDay) {
            return _buildCalendarDayCell(
              day: day,
              isEnabled: true,
              isSelected: true,
              isToday: _isSameDay(day, _todayMidnight),
              isOutside: false,
            );
          },
          todayBuilder: (context, day, focusedDay) {
             return _buildCalendarDayCell(
              day: day,
              isEnabled: true,
              isSelected: _isSameDay(day, _selectedDay),
              isToday: true,
              isOutside: false,
            );
          },
          outsideBuilder: (context, day, focusedDay) {
             return _buildCalendarDayCell(
              day: day,
              isEnabled: false,
              isSelected: false,
              isToday: _isSameDay(day, _todayMidnight),
              isOutside: true,
            );
          },
          disabledBuilder: (context, day, focusedDay) {
             return _buildCalendarDayCell(
              day: day,
              isEnabled: false,
              isSelected: false,
              isToday: _isSameDay(day, _todayMidnight),
              isOutside: !_isSameMonth(day, _focusedDay),
            );
          },
        ),
      ),
    );
  }

  Widget _buildCalendarDayCell({
    required DateTime day,
    required bool isSelected,
    required bool isToday,
    required bool isOutside,
    required bool isEnabled,
  }) {
    final personalDay = _engine.calculatePersonalDayForDate(day);

    Color borderColor = Colors.transparent;
    Color cellFillColor = Colors.white.withValues(alpha: 0.05);
    double borderWidth = 0;

    if (isSelected && isEnabled) {
      cellFillColor = AppColors.primary;
      borderColor = AppColors.primary;
      borderWidth = 2.0;
    } else if (isToday && isEnabled) {
      cellFillColor = AppColors.primary.withValues(alpha: 0.25);
    } else if (!isEnabled) {
      cellFillColor = Colors.white.withValues(alpha: 0.02);
    }

    Color baseDayTextColor = AppColors.secondaryText;
    if (isSelected && isEnabled) {
      baseDayTextColor = Colors.white;
    } else if (isToday && isEnabled) {
      baseDayTextColor = AppColors.primary;
    } else if (isOutside) {
      baseDayTextColor = AppColors.tertiaryText;
    }

    Widget dayNumberWidget = Text(
      day.day.toString(),
      style: TextStyle(
        color: isEnabled ? baseDayTextColor : baseDayTextColor.withValues(alpha: 0.4),
        fontWeight: (isToday || isSelected) ? FontWeight.bold : FontWeight.normal,
        fontSize: 11,
      ),
    );

    Widget vibrationWidget = Opacity(
      opacity: isEnabled ? 1.0 : 0.4,
      child: (personalDay > 0)
          ? VibrationPill(
              vibrationNumber: personalDay,
              type: VibrationPillType.micro,
              forceInvertedColors: (isSelected && isEnabled),
            )
          : const SizedBox(height: 16, width: 16),
    );

    return Container(
      margin: const EdgeInsets.all(2.5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6.0),
        border: Border.all(color: borderColor, width: borderWidth),
        color: cellFillColor,
      ),
      child: Padding(
        padding: const EdgeInsets.all(3.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(alignment: Alignment.topLeft, child: dayNumberWidget),
            Align(alignment: Alignment.bottomRight, child: vibrationWidget),
          ],
        ),
      ),
    );
  }

}
