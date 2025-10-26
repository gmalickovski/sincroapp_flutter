// -----------------------------------------------------------------
// ARQUIVO ATUALIZADO: custom_date_picker_modal.dart
// -----------------------------------------------------------------
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:sincro_app_flutter/common/constants/app_colors.dart';
import 'package:sincro_app_flutter/common/widgets/vibration_pill.dart';
import 'package:sincro_app_flutter/models/user_model.dart';
import 'package:sincro_app_flutter/services/numerology_engine.dart';
import 'package:table_calendar/table_calendar.dart';

// Importa os dois seletores personalizados
import 'custom_time_picker_modal.dart';
import 'custom_month_year_picker.dart'; // <-- NOVA IMPORTAÇÃO

class _DateWithVibration {
  final DateTime date;
  final int personalDay;
  _DateWithVibration(this.date, this.personalDay);
}

class CustomDatePickerModal extends StatefulWidget {
  final DateTime initialDate;
  final UserModel userData;

  const CustomDatePickerModal({
    super.key,
    required this.initialDate,
    required this.userData,
  });

  @override
  State<CustomDatePickerModal> createState() => _CustomDatePickerModalState();
}

class _CustomDatePickerModalState extends State<CustomDatePickerModal> {
  bool _isExpanded = false;
  late DateTime _selectedDate;
  late DateTime _calendarFocusedDay;
  TimeOfDay? _selectedTime;
  late NumerologyEngine _engine;
  final List<_DateWithVibration> _dateList = [];
  final ScrollController _scrollController = ScrollController();
  final double _datePillWidth = 68.0;
  bool _isScrollingProgrammatically = false;
  late DateTime _todayMidnight;

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime(
      widget.initialDate.year,
      widget.initialDate.month,
      widget.initialDate.day,
    );

    final now = DateTime.now();
    _todayMidnight = DateTime(now.year, now.month, now.day);

    _calendarFocusedDay =
        DateTime(_todayMidnight.year, _todayMidnight.month, 1);

    // Campo de horário começa em branco
    // (O 'if' que lia initialDate.hour foi removido)

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

    _regenerateDateListForCurrentMonth(doSetState: false);
  }

  void _regenerateDateListForCurrentMonth({bool doSetState = true}) {
    _dateList.clear();
    final int year = _calendarFocusedDay.year;
    final int month = _calendarFocusedDay.month;
    final int daysInMonth = DateTime(year, month + 1, 0).day;

    int targetScrollIndex = 0;
    if (_todayMidnight.year == year && _todayMidnight.month == month) {
      targetScrollIndex = (_todayMidnight.day - 1).clamp(0, daysInMonth - 1);
    } else if (_selectedDate.year == year && _selectedDate.month == month) {
      targetScrollIndex = (_selectedDate.day - 1).clamp(0, daysInMonth - 1);
    }

    for (int day = 1; day <= daysInMonth; day++) {
      final date = DateTime(year, month, day);
      final personalDay = _engine.calculatePersonalDayForDate(date);
      _dateList.add(_DateWithVibration(date, personalDay));
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToIndexInCurrentMonth(targetScrollIndex, animated: false);
    });

    if (doSetState && mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _toggleExpand() {
    setState(() {
      _isExpanded = !_isExpanded;
    });
  }

  void _selectAndPop(DateTime date) {
    if (date.isBefore(_todayMidnight) && !_isSameDay(date, _todayMidnight)) {
      return;
    }

    DateTime finalDateTime = date;
    if (_selectedTime != null) {
      finalDateTime = DateTime(
        date.year,
        date.month,
        date.day,
        _selectedTime!.hour,
        _selectedTime!.minute,
      );
    }
    setState(() {
      _selectedDate = date;
      _calendarFocusedDay = DateTime(date.year, date.month, 1);
    });
    Navigator.of(context).pop(finalDateTime);
  }

  // Função que chama o modal de HORÁRIO personalizado
  Future<void> _showCustomTimePicker(BuildContext context) async {
    final TimeOfDay? picked = await showModalBottomSheet<TimeOfDay>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (BuildContext builderContext) {
        return CustomTimePickerModal(
          initialTime: _selectedTime ?? TimeOfDay.now(),
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  bool _isSameMonth(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month;
  }

  // <-- FUNÇÃO SUBSTITUÍDA: Agora chama o NOVO modal de Mês/Ano -->
  Future<void> _showCustomMonthYearPicker(BuildContext context) async {
    HapticFeedback.lightImpact();
    final DateTime? picked = await showModalBottomSheet<DateTime>(
      context: context,
      backgroundColor: Colors.transparent, // Fundo do sheet transparente
      isScrollControlled: true, // Permite que o modal cresça se necessário
      builder: (BuildContext builderContext) {
        return CustomMonthYearPicker(
          initialDate: _calendarFocusedDay, // Usa o mês/ano focado atualmente
          firstDate: DateTime(2020), // Defina seu limite inferior
          lastDate: DateTime(2101), // Defina seu limite superior
        );
      },
    );

    // Se o usuário selecionou OK e retornou uma data
    if (picked != null) {
      setState(() {
        // Atualiza o foco do calendário para o novo mês/ano selecionado
        _calendarFocusedDay = DateTime(picked.year, picked.month, 1);
        // Regenera a lista de dias para o novo mês
        _regenerateDateListForCurrentMonth();
      });
    }
  }
  // <-- Fim da função substituída -->

  void _previousMonth() {
    HapticFeedback.lightImpact();
    setState(() {
      _calendarFocusedDay = DateTime(
        _calendarFocusedDay.year,
        _calendarFocusedDay.month - 1,
        1,
      );
      _regenerateDateListForCurrentMonth();
    });
  }

  void _nextMonth() {
    HapticFeedback.lightImpact();
    setState(() {
      _calendarFocusedDay = DateTime(
        _calendarFocusedDay.year,
        _calendarFocusedDay.month + 1,
        1,
      );
      _regenerateDateListForCurrentMonth();
    });
  }

  void _scrollToIndexInCurrentMonth(int index, {bool animated = true}) {
    if (mounted &&
        _scrollController.hasClients &&
        index >= 0 &&
        index < _dateList.length) {
      _isScrollingProgrammatically = true;

      final screenWidth = MediaQuery.of(context).size.width;
      final scrollOffset =
          (index * _datePillWidth) - (screenWidth / 2) + (_datePillWidth / 2);

      final maxScroll = _scrollController.position.maxScrollExtent;
      final targetOffset =
          scrollOffset.clamp(0.0, maxScroll > 0 ? maxScroll : 0.0);

      final resetFlag = () => Future.delayed(
            const Duration(milliseconds: 100),
            () {
              if (mounted) {
                _isScrollingProgrammatically = false;
              }
            },
          );

      if (animated) {
        _scrollController
            .animateTo(
              targetOffset,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
            )
            .whenComplete(resetFlag);
      } else {
        _scrollController.jumpTo(targetOffset);
        resetFlag();
      }
    } else {
      if (mounted) {
        _isScrollingProgrammatically = false;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      child: Container(
        padding: const EdgeInsets.only(top: 8.0, bottom: 16.0),
        decoration: const BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24.0),
            topRight: Radius.circular(24.0),
          ),
        ),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDragHandle(),
            _buildQuickActions(context),
            AnimatedCrossFade(
              duration: const Duration(milliseconds: 300),
              crossFadeState: _isExpanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              firstChild: _buildCompactView(),
              secondChild: _buildExpandedView(),
            ),
            const Divider(
                color: AppColors.border, height: 24, indent: 16, endIndent: 16),
            _buildTimePickerButton(context),
            _buildRecurrenceSection(context),
          ],
        ),
      ),
    );
  }

  Widget _buildDragHandle() {
    return GestureDetector(
      onTap: _toggleExpand,
      onVerticalDragUpdate: (details) {
        if (details.primaryDelta! < -4) {
          if (!_isExpanded) _toggleExpand();
        } else if (details.primaryDelta! > 4) {
          if (_isExpanded) _toggleExpand();
        }
      },
      child: Container(
        color: Colors.transparent,
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Center(
          child: Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.tertiaryText,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTitle(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 8.0),
      child: Text(
        "Definir data",
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: AppColors.primaryText, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return const SizedBox.shrink();
  }

  Widget _buildCompactView() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildCompactHeader(context),
        _buildDateScroller(context),
      ],
    );
  }

  Widget _buildCompactHeader(BuildContext context) {
    final titleText = DateFormat.yMMMM('pt_BR').format(_calendarFocusedDay);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildCompactNavButton(Icons.chevron_left, _previousMonth),
          InkWell(
            // <-- ATUALIZADO: Chama o novo picker
            onTap: () => _showCustomMonthYearPicker(context),
            borderRadius: BorderRadius.circular(4),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    titleText,
                    style: const TextStyle(
                      color: AppColors.primaryText,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 2),
                  const Icon(
                    Icons.arrow_drop_down,
                    color: AppColors.secondaryText,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
          _buildCompactNavButton(Icons.chevron_right, _nextMonth),
        ],
      ),
    );
  }

  Widget _buildCompactNavButton(IconData icon, VoidCallback onPressed) {
    return IconButton(
      icon: Icon(icon, color: AppColors.primaryText),
      iconSize: 20,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(),
      splashRadius: 20,
      onPressed: onPressed,
    );
  }

  Widget _buildDateScroller(BuildContext context) {
    return SizedBox(
      height: 100,
      child: ListView.builder(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        itemCount: _dateList.length,
        itemBuilder: (context, index) {
          if (index < 0 || index >= _dateList.length) {
            return const SizedBox.shrink();
          }
          final data = _dateList[index];
          final bool isSelected = _isSameDay(data.date, _selectedDate);
          final bool isToday = _isSameDay(data.date, _todayMidnight);
          final bool isPastDay = data.date.isBefore(_todayMidnight);

          String dayOfWeek;
          if (isToday) {
            dayOfWeek = "Hoje";
          } else if (_isSameDay(
              data.date, _todayMidnight.add(const Duration(days: 1)))) {
            dayOfWeek = "Amanhã";
          } else {
            dayOfWeek = toBeginningOfSentenceCase(
                    DateFormat.E('pt_BR').format(data.date)) ??
                '';
          }

          return _DatePill(
            dayOfWeek: dayOfWeek,
            dayOfMonth: data.date.day.toString(),
            personalDay: data.personalDay,
            isSelected: isSelected,
            isToday: isToday,
            width: _datePillWidth,
            isPastDay: isPastDay,
            onTap: (isPastDay && !isToday)
                ? null
                : () {
                    setState(() {
                      _selectedDate = data.date;
                      _calendarFocusedDay =
                          DateTime(data.date.year, data.date.month, 1);
                      _scrollToIndexInCurrentMonth(data.date.day - 1);
                    });
                    _selectAndPop(data.date);
                  },
          );
        },
      ),
    );
  }

  Widget _buildExpandedView() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTitle(context),
        _buildFullCalendarView(context),
      ],
    );
  }

  Widget _buildFullCalendarView(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: TableCalendar(
        locale: 'pt_BR',
        focusedDay: _calendarFocusedDay,
        firstDay: DateTime(2020),
        lastDay: DateTime(2101),
        selectedDayPredicate: (day) => _isSameDay(day, _selectedDate),
        enabledDayPredicate: (day) =>
            day.isAfter(_todayMidnight) || _isSameDay(day, _todayMidnight),
        onDaySelected: (selectedDay, focusedDay) {
          if (selectedDay.isBefore(_todayMidnight) &&
              !_isSameDay(selectedDay, _todayMidnight)) return;

          setState(() {
            _selectedDate = selectedDay;
            _calendarFocusedDay =
                DateTime(selectedDay.year, selectedDay.month, 1);
            _regenerateDateListForCurrentMonth();
          });
        },
        onPageChanged: (focusedDay) {
          setState(() {
            _calendarFocusedDay =
                DateTime(focusedDay.year, focusedDay.month, 1);
            _regenerateDateListForCurrentMonth();
          });
        },
        headerStyle: HeaderStyle(
          titleCentered: false,
          formatButtonVisible: false,
          titleTextStyle: const TextStyle(height: 0, fontSize: 0),
          leftChevronPadding: EdgeInsets.zero,
          rightChevronPadding: EdgeInsets.zero,
          leftChevronMargin: const EdgeInsets.symmetric(horizontal: 4),
          rightChevronMargin: const EdgeInsets.symmetric(horizontal: 4),
          leftChevronIcon: const Icon(Icons.chevron_left,
              color: AppColors.primaryText, size: 24),
          rightChevronIcon: const Icon(Icons.chevron_right,
              color: AppColors.primaryText, size: 24),
        ),
        daysOfWeekStyle: const DaysOfWeekStyle(
          weekdayStyle: TextStyle(color: AppColors.secondaryText, fontSize: 12),
          weekendStyle: TextStyle(color: AppColors.secondaryText, fontSize: 12),
        ),
        rowHeight: 54,
        calendarStyle: const CalendarStyle(
          defaultDecoration: BoxDecoration(),
          weekendDecoration: BoxDecoration(),
          outsideDecoration: BoxDecoration(),
          selectedDecoration: BoxDecoration(),
          todayDecoration: BoxDecoration(),
          disabledTextStyle: TextStyle(
              color: AppColors.tertiaryText, fontStyle: FontStyle.italic),
        ),
        calendarBuilders: CalendarBuilders(
          headerTitleBuilder: (context, day) {
            final titleText = DateFormat.yMMMM('pt_BR').format(day);
            return Row(
              children: [
                Expanded(
                  child: InkWell(
                    // <-- ATUALIZADO: Chama o novo picker
                    onTap: () => _showCustomMonthYearPicker(context),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          vertical: 8.0, horizontal: 4.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
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
                          const Icon(
                            Icons.arrow_drop_down,
                            color: AppColors.secondaryText,
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    final now = DateTime.now();
                    final today = DateTime(now.year, now.month, now.day);

                    if (_isSameDay(_selectedDate, today)) {
                      _selectAndPop(today);
                    } else {
                      setState(() {
                        _selectedDate = today;
                        _calendarFocusedDay =
                            DateTime(today.year, today.month, 1);
                        _regenerateDateListForCurrentMonth();
                      });
                      _selectAndPop(today);
                    }
                  },
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    visualDensity: VisualDensity.compact,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text(
                    "Hoje",
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
              ],
            );
          },
          defaultBuilder: (context, day, focusedDay) {
            final personalDay = _engine.calculatePersonalDayForDate(day);
            final isEnabled = !day.isBefore(_todayMidnight) ||
                _isSameDay(day, _todayMidnight);
            final bool isToday = _isSameDay(day, _todayMidnight);
            return _buildCalendarDayCell(
              day: day,
              personalDay: personalDay,
              isSelected: false,
              isToday: isToday,
              isOutside: false,
              isEnabled: isEnabled,
            );
          },
          outsideBuilder: (context, day, focusedDay) {
            final personalDay = _engine.calculatePersonalDayForDate(day);
            final isEnabled = !day.isBefore(_todayMidnight) ||
                _isSameDay(day, _todayMidnight);
            final bool isToday = _isSameDay(day, _todayMidnight);
            return _buildCalendarDayCell(
              day: day,
              personalDay: personalDay,
              isSelected: false,
              isToday: isToday,
              isOutside: true,
              isEnabled: isEnabled,
            );
          },
          selectedBuilder: (context, day, focusedDay) {
            final personalDay = _engine.calculatePersonalDayForDate(day);
            final bool isToday = _isSameDay(day, _todayMidnight);
            return _buildCalendarDayCell(
              day: day,
              personalDay: personalDay,
              isSelected: true,
              isToday: isToday,
              isOutside: false,
              isEnabled: true,
            );
          },
          disabledBuilder: (context, day, focusedDay) {
            final personalDay = _engine.calculatePersonalDayForDate(day);
            final bool isToday = _isSameDay(day, _todayMidnight);
            return _buildCalendarDayCell(
              day: day,
              personalDay: personalDay,
              isSelected: false,
              isToday: isToday,
              isOutside: !_isSameMonth(day, _calendarFocusedDay),
              isEnabled: false,
            );
          },
        ),
      ),
    );
  }

  Widget _buildCalendarDayCell({
    required DateTime day,
    required int personalDay,
    required bool isSelected,
    required bool isToday,
    required bool isOutside,
    required bool isEnabled,
  }) {
    Color borderColor = AppColors.border;
    Color cellFillColor = Colors.transparent;
    double borderWidth = 0.8;

    if (isToday && isEnabled) {
      cellFillColor = AppColors.primary;
      borderColor = AppColors.primary;
      borderWidth = 1.5;
    }

    if (isSelected && isEnabled) {
      borderColor = AppColors.primary;
      borderWidth = 2.0;

      if (isToday) {
        cellFillColor = AppColors.primary;
      } else {
        cellFillColor = Colors.transparent;
      }
    }

    if (!isEnabled) {
      borderColor = AppColors.border.withOpacity(0.3);
      borderWidth = 0.5;
      cellFillColor = Colors.transparent;
    }

    Color baseDayTextColor;
    if (isToday && isEnabled) {
      baseDayTextColor = Colors.white;
    } else if (isSelected && !isToday && isEnabled) {
      baseDayTextColor = AppColors.primary;
    } else if (isOutside) {
      baseDayTextColor = AppColors.tertiaryText;
    } else {
      baseDayTextColor = AppColors.secondaryText;
    }

    Color dayTextColor =
        isEnabled ? baseDayTextColor : baseDayTextColor.withOpacity(0.4);

    FontWeight dayFontWeight = FontWeight.normal;
    if ((isToday || isSelected) && isEnabled) {
      dayFontWeight = FontWeight.bold;
    }

    Widget dayNumberWidget = Text(
      day.day.toString(),
      style: TextStyle(
        color: dayTextColor,
        fontWeight: dayFontWeight,
        fontSize: 11,
      ),
    );

    Widget vibrationWidget = Opacity(
      opacity: isEnabled ? 1.0 : 0.4,
      child: (personalDay > 0)
          ? VibrationPill(
              vibrationNumber: personalDay,
              type: VibrationPillType.micro,
              forceInvertedColors: (isToday && isEnabled),
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
            Align(
              alignment: Alignment.topLeft,
              child: dayNumberWidget,
            ),
            Align(
              alignment: Alignment.bottomRight,
              child: vibrationWidget,
            ),
          ],
        ),
      ),
    );
  }

  // Botão "Adicionar horário" atualizado para ter o "X"
  Widget _buildTimePickerButton(BuildContext context) {
    final String timeText = _selectedTime != null
        ? _selectedTime!.format(context)
        : "Adicionar horário";

    final Color textColor =
        _selectedTime != null ? AppColors.primary : AppColors.primaryText;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: () => _showCustomTimePicker(context),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12.0),
                child: Row(
                  children: [
                    Icon(Icons.access_time,
                        color: _selectedTime != null
                            ? AppColors.primary
                            : AppColors.tertiaryText,
                        size: 20),
                    const SizedBox(width: 16),
                    Text(
                      timeText,
                      style: TextStyle(
                          color: textColor,
                          fontSize: 16,
                          fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_selectedTime != null)
            IconButton(
              icon: const Icon(Icons.close,
                  color: AppColors.tertiaryText, size: 20),
              splashRadius: 20,
              onPressed: () {
                setState(() {
                  _selectedTime = null;
                });
              },
            ),
        ],
      ),
    );
  }

  Widget _buildRecurrenceSection(BuildContext context) {
    final bool isRecurrenceEnabled = false;

    return Opacity(
      opacity: isRecurrenceEnabled ? 1.0 : 0.4,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: InkWell(
          onTap: isRecurrenceEnabled ? () {} : null,
          borderRadius: BorderRadius.circular(8),
          child: const Padding(
            padding: EdgeInsets.symmetric(vertical: 12.0),
            child: Row(
              children: [
                Icon(Icons.repeat, color: AppColors.tertiaryText, size: 20),
                SizedBox(width: 16),
                Text(
                  "Repetir",
                  style: TextStyle(
                      color: AppColors.primaryText,
                      fontSize: 16,
                      fontWeight: FontWeight.w500),
                ),
                Spacer(),
                Text(
                  "Nunca",
                  style: TextStyle(
                      color: AppColors.secondaryText,
                      fontSize: 16,
                      fontWeight: FontWeight.w400),
                ),
                SizedBox(width: 4),
                Icon(Icons.chevron_right,
                    color: AppColors.tertiaryText, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Widgets auxiliares (_QuickActionButton, _DatePill) permanecem os mesmos
// (Copie e cole os widgets _QuickActionButton e _DatePill da versão anterior aqui)

class _QuickActionButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _QuickActionButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 12),
        side: const BorderSide(color: AppColors.border),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8.0),
        ),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.primaryText,
          fontWeight: FontWeight.w500,
          fontSize: 14,
        ),
        textAlign: TextAlign.center,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

class _DatePill extends StatelessWidget {
  final String dayOfWeek;
  final String dayOfMonth;
  final int personalDay;
  final bool isSelected;
  final bool isToday;
  final VoidCallback? onTap;
  final double width;
  final bool isPastDay;

  const _DatePill({
    required this.dayOfWeek,
    required this.dayOfMonth,
    required this.personalDay,
    required this.isSelected,
    required this.isToday,
    required this.onTap,
    required this.width,
    required this.isPastDay,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final double opacity = (isPastDay && !isToday && !isSelected) ? 0.4 : 1.0;

    Color bgColor = Colors.transparent;
    Color baseTextColor = AppColors.secondaryText;
    Color baseDayNumColor = AppColors.primaryText;
    Color baseBorderColor = AppColors.border;
    double borderWidth = 1.0;

    if (isToday) {
      bgColor = AppColors.primary;
      baseTextColor = Colors.white;
      baseDayNumColor = Colors.white;
      baseBorderColor = AppColors.primary;
      borderWidth = 1.5;
    }

    if (isSelected) {
      baseBorderColor = AppColors.primary;
      borderWidth = 2.0;

      if (isToday) {
        bgColor = AppColors.primary;
        baseTextColor = Colors.white;
        baseDayNumColor = Colors.white;
      } else {
        bgColor = Colors.transparent;
        baseTextColor = AppColors.primary;
        baseDayNumColor = AppColors.primary;
      }
    }

    final Color textColor = baseTextColor.withOpacity(opacity);
    final Color dayNumColor = baseDayNumColor.withOpacity(opacity);
    final Color borderColor = baseBorderColor.withOpacity(opacity);

    return Opacity(
      opacity: opacity,
      child: Container(
        width: width,
        margin: const EdgeInsets.symmetric(horizontal: 4.0),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: borderColor,
                width: borderWidth,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  dayOfWeek.toUpperCase(),
                  style: TextStyle(
                    color: textColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  dayOfMonth,
                  style: TextStyle(
                    color: dayNumColor,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                SizedBox(
                  height: 24,
                  child: (personalDay > 0)
                      ? VibrationPill(
                          vibrationNumber: personalDay,
                          type: VibrationPillType.compact,
                          forceInvertedColors: isToday,
                        )
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
