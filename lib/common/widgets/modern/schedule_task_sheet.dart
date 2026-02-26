import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:sincro_app_flutter/common/constants/app_colors.dart';
import 'package:sincro_app_flutter/models/recurrence_rule.dart';
import 'package:sincro_app_flutter/common/widgets/modern/custom_time_picker_dialog.dart';
import 'package:sincro_app_flutter/models/date_picker_result.dart';
import 'package:sincro_app_flutter/common/widgets/custom_month_year_picker.dart';
import 'package:sincro_app_flutter/common/widgets/vibration_pill.dart';
import 'package:sincro_app_flutter/models/user_model.dart';
import 'package:sincro_app_flutter/services/numerology_engine.dart';
import 'package:sincro_app_flutter/common/widgets/scrollable_chips_row.dart';
import 'package:sincro_app_flutter/common/widgets/modern/inline_month_year_selector.dart';

class ScheduleTaskSheet extends StatefulWidget {
  final DateTime? initialDate;
  final TimeOfDay? initialTime;
  final RecurrenceRule? initialRecurrence;
  final DateTime? initialReminder;
  final List<int>? initialReminderOffsets; // Modificado para lista de minutos
  final DateTime? goalDeadline; // Prazo final da meta (se houver)
  final UserModel userData;
  final bool isDesktop;

  const ScheduleTaskSheet({
    super.key,
    this.initialDate,
    this.initialTime,
    this.initialRecurrence,
    this.initialReminder,
    this.initialReminderOffsets, // Recebe no construtor
    this.goalDeadline, // Novo parâmetro para limitar opções
    required this.userData,
    this.isDesktop = false,
  });

  @override
  State<ScheduleTaskSheet> createState() => _ScheduleTaskSheetState();
}

class _ScheduleTaskSheetState extends State<ScheduleTaskSheet> {
  late DateTime _focusedDay;
  DateTime? _selectedDay;
  late DateTime _todayMidnight;
  TimeOfDay? _selectedTime;
  late RecurrenceRule _recurrenceRule;
  late NumerologyEngine _engine;

  // UI State
  bool _isAllDay = true;
  bool _isSelectingTime = false;

  // Reminder State
  bool _showReminder = false; // Controls visibility of reminder options
  Set<int> _selectedReminderOffsets = {};

  // Recurrence State
  bool _showRecurrence = false; // Controls visibility of recurrence options

  // Duration State
  int? _selectedDuration;

  bool _isSelectingYearMonth = false;

  // REMOVED ScrollControllers (managed internally by ScrollableChipsRow)

  @override
  void dispose() {
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    if (widget.initialReminderOffsets != null) {
      _selectedReminderOffsets = widget.initialReminderOffsets!.toSet();
    }
    final now = DateTime.now();
    _todayMidnight = DateTime(now.year, now.month, now.day);

    _focusedDay = widget.initialDate ?? now;
    _selectedDay = widget.initialDate;
    _selectedTime = widget.initialTime;
    _recurrenceRule = widget.initialRecurrence ?? RecurrenceRule();
    _showRecurrence = _recurrenceRule.type != RecurrenceType.none;
    _showReminder = _selectedReminderOffsets.isNotEmpty;

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
      if (_selectedDay != null && _isSameDay(_selectedDay!, selectedDay)) {
        _selectedDay = null; // Toggle off if clicked again
      } else {
        _selectedDay = selectedDay;
      }
      _focusedDay = focusedDay;
    });
  }

  void _toggleAllDay(bool value) {
    setState(() {
      _isAllDay = value;
      if (value) {
        _selectedTime = null;
      } else {
        // If turning on time, slide into time picker view
        _isSelectingTime = true;
      }
    });
  }

  void _pickTime() {
    setState(() {
      _isSelectingTime = true;
    });
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

        final diffMinutes = baseDt.difference(targetDt).inMinutes;
        if (diffMinutes >= 0) {
          _selectedReminderOffsets.add(diffMinutes);
        }
      });
    }
  }

  void _onSave() {
    // If no day is selected but we are saving, maybe we just return nulls or whatever was there.
    // Use a data selecionada base (meia noite)
    DateTime? finalDateTime;

    if (_selectedDay != null) {
      finalDateTime = DateTime(
        _selectedDay!.year,
        _selectedDay!.month,
        _selectedDay!.day,
      );

      // Combina com a hora se n├úo for dia inteiro
      if (!_isAllDay && _selectedTime != null) {
        finalDateTime = DateTime(
          _selectedDay!.year,
          _selectedDay!.month,
          _selectedDay!.day,
          _selectedTime!.hour,
          _selectedTime!.minute,
        );
      }
    }

    // Calculate reminder time if applicable
    TimeOfDay? reminderTime;
    // reminder time computation is mostly obsolete here, handling offsets individually
    if (_selectedReminderOffsets.isNotEmpty &&
        finalDateTime != null &&
        !_isAllDay &&
        _selectedTime != null) {
      final firstOffset = _selectedReminderOffsets.first;
      final reminded = finalDateTime.subtract(Duration(minutes: firstOffset));
      reminderTime = TimeOfDay(hour: reminded.hour, minute: reminded.minute);
    }

    final result = DatePickerResult(
      finalDateTime,
      _recurrenceRule,
      reminderTime: reminderTime,
      reminderOffsets: _selectedReminderOffsets.toList(),
      hasTime: !_isAllDay && _selectedTime != null,
      durationMinutes: _selectedDuration,
    );

    Navigator.pop(context, result);
  }

  void _onClear() {
    setState(() {
      _selectedDay = null;
      _selectedTime = null;
      _isAllDay = true;
      _recurrenceRule = RecurrenceRule(type: RecurrenceType.none);
      _showRecurrence = false;
      _selectedReminderOffsets.clear();
      _showReminder = false;
      _selectedDuration = null;
    });
  }

  Widget _buildCustomHeader() {
    final headerText = DateFormat('MMMM yyyy', 'pt_BR').format(_focusedDay);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (!_isSelectingYearMonth)
            IconButton(
              icon: const Icon(Icons.chevron_left, color: AppColors.primaryText),
              onPressed: () => setState(() => _focusedDay =
                  DateTime(_focusedDay.year, _focusedDay.month - 1)),
            )
          else
            const SizedBox(width: 48),

          GestureDetector(
            onTap: () {
              setState(() {
                _isSelectingYearMonth = !_isSelectingYearMonth;
              });
            },
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _capitalize(headerText),
                  style: const TextStyle(
                      color: AppColors.primaryText,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Poppins'),
                ),
                const SizedBox(width: 4),
                Icon(
                  _isSelectingYearMonth
                      ? Icons.keyboard_arrow_up
                      : Icons.unfold_more_rounded,
                  color: AppColors.secondaryText,
                  size: 20,
                ),
              ],
            ),
          ),

          if (!_isSelectingYearMonth)
            IconButton(
              icon: const Icon(Icons.chevron_right, color: AppColors.primaryText),
              onPressed: () => setState(() => _focusedDay =
                  DateTime(_focusedDay.year, _focusedDay.month + 1)),
            )
          else
            const SizedBox(width: 48),
        ],
      ),
    );
  }

  String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }

  bool _isSameDay(DateTime? a, DateTime? b) {
    if (a == null || b == null) return false;
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  bool _isSameMonth(DateTime? a, DateTime? b) {
    if (a == null || b == null) return false;
    return a.year == b.year && a.month == b.month;
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        textTheme: Theme.of(context).textTheme.apply(fontFamily: 'Poppins'),
      ),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: widget.isDesktop
              ? double.infinity
              : MediaQuery.of(context).size.height * 0.9,
        ),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: widget.isDesktop
              ? BorderRadius.circular(16)
              : const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, animation) {
            return SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(1.0, 0.0), // Slide in from right
                end: Offset.zero,
              ).animate(animation),
              child: child,
            );
          },
          child: _isSelectingTime
              ? _buildTimeSelectionView()
              : _buildMainScheduleView(),
        ),
      ),
    );
  }

  Widget _buildTimeSelectionView() {
    final now = TimeOfDay.now();
    final initial = _selectedTime ?? TimeOfDay(hour: now.hour + 1, minute: 0);

    return Column(
      key: const ValueKey('TimeSelectionView'),
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: SingleChildScrollView(
            child: CustomTimePickerWidget(
              initialTime: initial,
              onCancel: () {
                setState(() {
                  _isSelectingTime = false;
                  if (_selectedTime == null) {
                    _isAllDay = true;
                  }
                });
              },
              onConfirm: (result) {
                setState(() {
                  _selectedTime = result.time;
                  _selectedDuration = result.durationMinutes;
                  _isAllDay = false;
                  _isSelectingTime = false;
                });
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMainScheduleView() {
    return Column(
      key: const ValueKey('MainScheduleView'),
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildHeader(),
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 24),
            child: Column(
              children: [
                // 2. Calendar
                _buildCalendar(),
                const SizedBox(height: 16), // Spacing requested

                const Divider(color: AppColors.border, height: 1),

                // 3. Time Row (Horário)
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
        _buildFooter(),
      ],
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.only(
          top: 16.0, left: 16.0, right: 16.0, bottom: 8.0),
      child: Stack(
        alignment: Alignment.center,
        children: [
          const Text(
            "Agendar Tarefa",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.primaryText,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              fontFamily: 'Poppins',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    bool hasAnySelection = _selectedDay != null ||
        _selectedTime != null ||
        _recurrenceRule.type != RecurrenceType.none;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 150),
        transitionBuilder: (Widget child, Animation<double> animation) {
          return FadeTransition(
              opacity: animation,
              child: ScaleTransition(scale: animation, child: child));
        },
        child: hasAnySelection
            ? Row(
                key: const ValueKey('ClearSaveButtons'),
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: OutlinedButton(
                        onPressed: _onClear,
                        style: OutlinedButton.styleFrom(
                          backgroundColor: AppColors.cardBackground,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          side: const BorderSide(color: AppColors.border),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text("Limpar",
                            style: TextStyle(
                                color: AppColors.secondaryText,
                                fontFamily: 'Poppins')),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _onSave,
                        style: ButtonStyle(
                          backgroundColor:
                              WidgetStateProperty.resolveWith<Color>(
                                  (states) => AppColors.primary),
                          foregroundColor:
                              WidgetStateProperty.resolveWith<Color>(
                                  (states) => Colors.white),
                          elevation: WidgetStateProperty.resolveWith<double>(
                              (states) => 0),
                          padding: WidgetStateProperty
                              .resolveWith<EdgeInsetsGeometry>((states) =>
                                  const EdgeInsets.symmetric(vertical: 12)),
                          shape:
                              WidgetStateProperty.resolveWith<OutlinedBorder>(
                                  (states) {
                            if (states.contains(WidgetState.hovered)) {
                              return RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: const BorderSide(
                                    color: Colors.white, width: 2),
                              );
                            }
                            return RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: const BorderSide(
                                  color: AppColors.primary, width: 2),
                            );
                          }),
                        ),
                        child: const Text("Aplicar",
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Poppins')),
                      ),
                    ),
                  ),
                ],
              )
            : SizedBox(
                key: const ValueKey('CloseButton'),
                height: 48,
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: AppColors.cardBackground,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    side: const BorderSide(color: AppColors.border),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text("Fechar",
                      style: TextStyle(
                          color: AppColors.secondaryText,
                          fontFamily: 'Poppins')),
                ),
              ),
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
    String timeText = _isAllDay
        ? "Dia inteiro"
        : (_selectedTime?.format(context) ?? "Definir");
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
        timeText += " • $_selectedDuration min";
      }
    }

    return InkWell(
      onTap: _isAllDay ? null : _pickTime,
      hoverColor: AppColors.primary.withValues(alpha: 0.05),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Row(
              children: [
                Icon(Icons.access_time, color: AppColors.secondaryText),
                SizedBox(width: 12),
                Text("Horário",
                    style:
                        TextStyle(color: AppColors.primaryText, fontSize: 16)),
              ],
            ),
            Row(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Text(
                    timeText,
                    style: TextStyle(
                      color: _isAllDay
                          ? AppColors.secondaryText
                          : AppColors.primary,
                      fontSize: 14,
                      fontWeight:
                          _isAllDay ? FontWeight.normal : FontWeight.w600,
                    ),
                  ),
                ),
                Switch(
                  value: !_isAllDay,
                  activeThumbColor: AppColors.primary,
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
    final String summary =
        isRepeating ? _recurrenceRule.getSummaryText() : "Nunca";

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
          hoverColor: AppColors.primary.withValues(alpha: 0.05),
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: Row(
              children: [
                const Icon(Icons.repeat, color: AppColors.secondaryText),
                const SizedBox(width: 12),
                const Text("Repetir",
                    style:
                        TextStyle(color: AppColors.primaryText, fontSize: 16)),
                if (!_canUseRecurrence) ...[
                  const SizedBox(width: 8),
                  const Icon(Icons.lock_outline,
                      size: 16, color: AppColors.secondaryText),
                ],
                const Spacer(),
                Text(
                  summary,
                  style: const TextStyle(
                      color: AppColors.secondaryText, fontSize: 14),
                ),
                const SizedBox(width: 12),
                Switch(
                  value: _showRecurrence,
                  activeThumbColor: AppColors.primary,
                  overlayColor: WidgetStateProperty.all(Colors.transparent),
                  onChanged: !_canUseRecurrence
                      ? null
                      : (val) {
                          setState(() {
                            _showRecurrence = val;
                            if (!val) {
                              _recurrenceRule =
                                  RecurrenceRule(type: RecurrenceType.none);
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
                          _buildRecurrenceChip(
                              "Diariamente", RecurrenceType.daily),
                          const SizedBox(width: 8),
                          _buildRecurrenceChip(
                              "Semanalmente", RecurrenceType.weekly),
                          const SizedBox(width: 8),
                          _buildRecurrenceChip(
                              "Mensalmente", RecurrenceType.monthly),
                        ],
                      ),

                      // Weekly Days Selection (if Weekly)
                      if (_recurrenceRule.type == RecurrenceType.weekly)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16.0),
                          child: _buildWeeklyDaysSelector(),
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

    if (widget.goalDeadline != null && _selectedDay != null) {
      final daysUntilDeadline =
          widget.goalDeadline!.difference(_selectedDay!).inDays;

      if (type == RecurrenceType.weekly && daysUntilDeadline < 7) {
        isDisabled = true;
        disabledReason = "Meta acaba em menos de uma semana";
      } else if (type == RecurrenceType.monthly && daysUntilDeadline < 28) {
        // 28 dias margem segura
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
      onSelected: isDisabled
          ? null
          : (val) {
              setState(() {
                if (!val) {
                  // Deselect
                  _recurrenceRule = RecurrenceRule(type: RecurrenceType.none);
                  if (type == RecurrenceType.none) {
                    _showRecurrence =
                        false; // Hide if selected 'none' or deselected all
                  }
                } else {
                  // Select
                  _recurrenceRule = _recurrenceRule.copyWith(type: type);
                  // Initialize days if switching to weekly and empty
                  if (type == RecurrenceType.weekly &&
                      _recurrenceRule.daysOfWeek.isEmpty &&
                      _selectedDay != null) {
                    _recurrenceRule = _recurrenceRule
                        .copyWith(daysOfWeek: [_selectedDay!.weekday]);
                  }
                }
              });
            },
      // Cores desabilitadas
      disabledColor: AppColors.background.withValues(alpha: 0.5),

      selectedColor: isDisabled
          ? AppColors.secondaryText
          : AppColors.primary, // Cinza se invalido
      backgroundColor: AppColors.background,
      labelStyle: TextStyle(
        color: isDisabled
            ? AppColors.secondaryText.withValues(alpha: 0.5)
            : (isSelected ? Colors.white : AppColors.secondaryText),
        fontFamily: 'Poppins',
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
            color: isDisabled
                ? AppColors.border.withValues(alpha: 0.3)
                : (isSelected ? AppColors.primary : AppColors.border)),
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
      1: 'S',
      2: 'T',
      3: 'Q',
      4: 'Q',
      5: 'S',
      6: 'S',
      7: 'D'
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
              _recurrenceRule =
                  _recurrenceRule.copyWith(daysOfWeek: currentDays);
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
              border: Border.all(
                  color: isSelected ? AppColors.primary : AppColors.border),
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
    if (_isAllDay || _selectedTime == null) {
      return const SizedBox.shrink(); // Hide entirely if no time
    }

    final String summary = _getReminderSummary();

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
                _selectedReminderOffsets.clear();
              } else {
                // If turning on, and no reminder is set, default to "Na hora"
                if (_selectedReminderOffsets.isEmpty) _selectedReminderOffsets.add(0);
              }
            });
          },
          hoverColor: AppColors.primary.withValues(alpha: 0.05),
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: Row(
              children: [
                // Opacity wrapper for Icon and Title
                Opacity(
                  opacity: contentOpacity,
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.notifications_none_rounded,
                          color: AppColors.secondaryText),
                      SizedBox(width: 12),
                      Text("Lembrete",
                          style: TextStyle(
                              color: AppColors.primaryText, fontSize: 16)),
                    ],
                  ),
                ),

                if (!_canUseReminders && !_isAllDay) ...[
                  const SizedBox(width: 8),
                  const Icon(Icons.lock_outline,
                      size: 16, color: AppColors.secondaryText),
                ],

                const Spacer(),

                // Trailing Content Logic
                if (_isAllDay)
                  Text(
                    "Defina um horário",
                    style: TextStyle(
                        color: AppColors.secondaryText.withValues(alpha: 0.6),
                        fontSize: 14),
                  )
                else ...[
                  // Normal or Premium-locked State
                  if (!_canUseReminders)
                    Text(
                      "Recurso Premium",
                      style: TextStyle(
                          color: AppColors.secondaryText.withValues(alpha: 0.6),
                          fontSize: 12),
                    )
                  else
                    Text(
                      summary,
                      style: const TextStyle(
                          color: AppColors.secondaryText, fontSize: 14),
                    ),

                  const SizedBox(width: 12),
                  Switch(
                    value: _showReminder,
                    activeThumbColor: AppColors.primary,
                    overlayColor: WidgetStateProperty.all(Colors.transparent),
                    onChanged: !_canUseReminders
                        ? null
                        : (val) {
                            setState(() {
                              _showReminder = val;
                              if (!val) {
                                _selectedReminderOffsets.clear();
                              } else {
                                // If turning on, and no reminder is set, default to "Na hora"
                                if (_selectedReminderOffsets.isEmpty) _selectedReminderOffsets.add(0);
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
                      _buildReminderChip("Na hora", 0),
                      const SizedBox(width: 8),
                      _buildReminderChip(
                          "10 min antes", 10),
                      const SizedBox(width: 8),
                      _buildReminderChip(
                          "30 min antes", 30),
                      const SizedBox(width: 8),
                      _buildReminderChip("1 h antes", 60),
                      const SizedBox(width: 8),
                      _buildReminderChip(
                          "1 dia antes", 24 * 60),
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
    if (_selectedReminderOffsets.isEmpty) return "Sem lembrete";
    if (_selectedReminderOffsets.length > 1) return "${_selectedReminderOffsets.length} lembretes";
    
    final minutes = _selectedReminderOffsets.first;
    if (minutes == 0) return "Na hora";
    if (minutes < 60) return "$minutes min antes";
    final hours = minutes ~/ 60;
    if (hours < 24) return "$hours h antes";
    return "${hours ~/ 24} dia(s) antes";
  }

  Widget _buildReminderChip(String label, int offsetMinutes) {
    final isSelected = _selectedReminderOffsets.contains(offsetMinutes);
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (val) {
        setState(() {
          if (val) {
             _selectedReminderOffsets.add(offsetMinutes);
          } else {
             _selectedReminderOffsets.remove(offsetMinutes);
          }
        });
      },
      selectedColor: AppColors.primary,
      backgroundColor: AppColors.background,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : AppColors.secondaryText,
        fontFamily: 'Poppins',
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
            color: isSelected ? AppColors.primary : AppColors.border),
      ),
    );
  }

  Widget _buildCalendar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildCustomHeader(),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 150),
            crossFadeState: _isSelectingYearMonth
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: TableCalendar(
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
              headerVisible: false, // Hide native header
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
            secondChild: Padding(
              padding: const EdgeInsets.only(top: 8.0, bottom: 16.0),
              child: InlineMonthYearSelector(
                focusedDay: _focusedDay,
                onDateChanged: (newDate) {
                  setState(() {
                    _focusedDay = newDate;
                  });
                },
              ),
            ),
          ),
        ],
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
        color: isEnabled
            ? baseDayTextColor
            : baseDayTextColor.withValues(alpha: 0.4),
        fontWeight:
            (isToday || isSelected) ? FontWeight.bold : FontWeight.normal,
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
