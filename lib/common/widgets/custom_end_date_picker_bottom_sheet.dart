import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:sincro_app_flutter/common/constants/app_colors.dart';
import 'package:sincro_app_flutter/common/widgets/vibration_pill.dart';
import 'package:sincro_app_flutter/models/user_model.dart';
import 'package:sincro_app_flutter/services/numerology_engine.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:sincro_app_flutter/common/widgets/modern/inline_month_year_selector.dart';

class CustomEndDatePickerBottomSheet extends StatefulWidget {
  final DateTime? initialDate;
  final DateTime firstDate;
  final DateTime lastDate;
  final UserModel userData;
  final bool isDesktop;

  const CustomEndDatePickerBottomSheet({
    super.key,
    this.initialDate,
    required this.firstDate,
    required this.lastDate,
    required this.userData,
    this.isDesktop = false,
  });

  @override
  State<CustomEndDatePickerBottomSheet> createState() =>
      _CustomEndDatePickerBottomSheetState();
}

class _CustomEndDatePickerBottomSheetState
    extends State<CustomEndDatePickerBottomSheet> {
  DateTime? _selectedDate;
  late DateTime _focusedDay;
  late DateTime _todayMidnight;
  late NumerologyEngine _engine;

  bool _isSelectingYearMonth = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _todayMidnight = DateTime(now.year, now.month, now.day);

    _selectedDate = widget.initialDate != null
        ? DateTime(
            widget.initialDate!.year,
            widget.initialDate!.month,
            widget.initialDate!.day,
          )
        : null;

    final baseDate = widget.initialDate ?? now;
    _focusedDay = DateTime(
      baseDate.year,
      baseDate.month,
      baseDate.day,
    );

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

  bool _isSameDay(DateTime a, DateTime? b) {
    if (b == null) return false;
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  bool _isSameMonth(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: widget.isDesktop 
            ? BorderRadius.circular(16.0) 
            : const BorderRadius.vertical(top: Radius.circular(24.0)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min, // Ocupar o tamanho mínimo necessário
        children: [
          // Title
          const Padding(
            padding: EdgeInsets.only(
                top: 16.0, left: 16.0, right: 16.0, bottom: 8.0),
            child: Text(
              "Selecionar Data",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.primaryText,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                fontFamily: 'Poppins',
              ),
            ),
          ),

          // Custom Header (Mes/Ano com Setas)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: _buildCustomHeader(),
          ),

          // Conteúdo animado (TableCalendar VS _MonthYearSelector)
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 150),
            firstChild: _buildTableCalendar(),
            secondChild: _buildMonthYearSelector(),
            crossFadeState: _isSelectingYearMonth
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
          ),

          // Botão Fixado no Rodapé
          _buildFooterButton(),
        ],
      ),
    );
  }

  Widget _buildCustomHeader() {
    final headerText = DateFormat('MMMM yyyy', 'pt_BR').format(_focusedDay);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 8.0),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (!_isSelectingYearMonth)
                IconButton(
                  icon: const Icon(Icons.chevron_left, color: Colors.white),
                  onPressed: () => setState(() => _focusedDay =
                      DateTime(_focusedDay.year, _focusedDay.month - 1)),
                )
              else
                const SizedBox(width: 48),
              if (!_isSelectingYearMonth)
                IconButton(
                  icon: const Icon(Icons.chevron_right, color: Colors.white),
                  onPressed: () => setState(() => _focusedDay =
                      DateTime(_focusedDay.year, _focusedDay.month + 1)),
                )
              else
                const SizedBox(width: 48),
            ],
          ),
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
                  headerText.toUpperCase(),
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Poppins'),
                ),
                const SizedBox(width: 4),
                Icon(
                  _isSelectingYearMonth
                      ? Icons.arrow_drop_up
                      : Icons.arrow_drop_down,
                  color: AppColors.primary,
                  size: 24,
                ),
                if (!_isSelectingYearMonth) ...[
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        final now = DateTime.now();
                        _focusedDay = now;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        "Hoje",
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white70,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthYearSelector() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: InlineMonthYearSelector(
        focusedDay: _focusedDay,
        onDateChanged: (newDate) {
          setState(() {
            _focusedDay = newDate;
          });
        },
      ),
    );
  }

  Widget _buildTableCalendar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: TableCalendar(
        locale: 'pt_BR',
        focusedDay: _focusedDay,
        firstDay: widget.firstDate,
        lastDay: widget.lastDate,
        currentDay: _todayMidnight,
        selectedDayPredicate: (day) => _isSameDay(day, _selectedDate),
        enabledDayPredicate: (day) =>
            day.isAfter(widget.firstDate) || _isSameDay(day, widget.firstDate),
        onDaySelected: (selectedDay, focusedDay) {
          if (_isSelectingYearMonth) return;

          setState(() {
            if (_isSameDay(selectedDay, _selectedDate)) {
              _selectedDate = null;
            } else {
              _selectedDate = selectedDay;
            }
            _focusedDay = focusedDay;
          });
        },
        headerVisible: false,
        daysOfWeekHeight: 24.0,
        daysOfWeekStyle: const DaysOfWeekStyle(
          weekdayStyle: TextStyle(
              color: AppColors.secondaryText,
              fontSize: 12,
              fontFamily: 'Poppins'),
          weekendStyle: TextStyle(
              color: AppColors.secondaryText,
              fontSize: 12,
              fontFamily: 'Poppins'),
        ),
        rowHeight: 54,
        calendarStyle: const CalendarStyle(
          outsideDaysVisible: true,
          defaultTextStyle:
              TextStyle(color: Colors.white, fontFamily: 'Poppins'),
          weekendTextStyle:
              TextStyle(color: AppColors.secondaryText, fontFamily: 'Poppins'),
        ),
        calendarBuilders: CalendarBuilders(
          defaultBuilder: (context, day, focusedDay) {
            final personalDay = _engine.calculatePersonalDayForDate(day);
            return _buildCalendarDayCell(
              day: day,
              personalDay: personalDay,
              isSelected: false,
              isToday: _isSameDay(day, _todayMidnight),
              isOutside: !_isSameMonth(day, _focusedDay),
              isEnabled: true,
            );
          },
          selectedBuilder: (context, day, focusedDay) {
            final personalDay = _engine.calculatePersonalDayForDate(day);
            return _buildCalendarDayCell(
              day: day,
              personalDay: personalDay,
              isSelected: true,
              isToday: _isSameDay(day, _todayMidnight),
              isOutside: !_isSameMonth(day, _focusedDay),
              isEnabled: true,
            );
          },
          todayBuilder: (context, day, focusedDay) {
            final personalDay = _engine.calculatePersonalDayForDate(day);
            return _buildCalendarDayCell(
              day: day,
              personalDay: personalDay,
              isSelected: false,
              isToday: true,
              isOutside: !_isSameMonth(day, _focusedDay),
              isEnabled: true,
            );
          },
          outsideBuilder: (context, day, focusedDay) {
            final personalDay = _engine.calculatePersonalDayForDate(day);
            return _buildCalendarDayCell(
              day: day,
              personalDay: personalDay,
              isSelected: _isSameDay(day, _selectedDate),
              isToday: _isSameDay(day, _todayMidnight),
              isOutside: true,
              isEnabled: false, // Fora do escopo ou desabilitado
            );
          },
          disabledBuilder: (context, day, focusedDay) {
            final personalDay = _engine.calculatePersonalDayForDate(day);
            return _buildCalendarDayCell(
              day: day,
              personalDay: personalDay,
              isSelected: false,
              isToday: _isSameDay(day, _todayMidnight),
              isOutside: !_isSameMonth(day, _focusedDay),
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
    Color borderColor = Colors.transparent;
    Color cellFillColor;
    double borderWidth = 0;

    if (isSelected && isEnabled) {
      cellFillColor = AppColors.primary;
      borderColor = AppColors.primary;
      borderWidth = 2.0;
    } else if (isToday && isEnabled) {
      cellFillColor = AppColors.primary.withValues(alpha: 0.25);
    } else if (!isEnabled || isOutside) {
      // Consider outside as practically disabled visually here
      cellFillColor = Colors.white.withValues(alpha: 0.02);
    } else {
      cellFillColor = Colors.white.withValues(alpha: 0.05);
    }

    Color baseDayTextColor;
    if (isSelected && isEnabled) {
      baseDayTextColor = Colors.white;
    } else if (isToday && isEnabled) {
      baseDayTextColor = AppColors.primary;
    } else if (isOutside) {
      baseDayTextColor = AppColors.tertiaryText;
    } else {
      baseDayTextColor = AppColors.secondaryText;
    }

    Color dayTextColor = isEnabled && !isOutside
        ? baseDayTextColor
        : baseDayTextColor.withValues(alpha: 0.4);

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
      opacity: (isEnabled && !isOutside) ? 1.0 : 0.4,
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

  Widget _buildFooterButton() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 150),
        transitionBuilder: (Widget child, Animation<double> animation) {
          return FadeTransition(
              opacity: animation,
              child: ScaleTransition(scale: animation, child: child));
        },
        child: _isSelectingYearMonth
            ? Row(
                key: const ValueKey('SelectorButtons'),
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: OutlinedButton(
                        onPressed: () {
                          setState(() {
                            // Cancelar: voltar ao calendário sem salvar
                            _isSelectingYearMonth = false;
                          });
                        },
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          side: const BorderSide(color: AppColors.border),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text("Voltar",
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
                        onPressed: () {
                          // Confirmar a visualização Mês/Ano e voltar ao calendário
                          setState(() {
                            _isSelectingYearMonth = false;
                          });
                        },
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
                        child: const Text("Confirmar",
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Poppins')),
                      ),
                    ),
                  ),
                ],
              )
            : _selectedDate != null
                ? Row(
                    key: const ValueKey('ActionButtons'),
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 48,
                          child: OutlinedButton(
                            onPressed: () {
                              setState(() {
                                _selectedDate = null;
                              });
                            },
                            style: OutlinedButton.styleFrom(
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
                            onPressed: () {
                              Navigator.of(context).pop(_selectedDate);
                            },
                            style: ButtonStyle(
                              backgroundColor: WidgetStateProperty.resolveWith<Color>(
                                  (states) => AppColors.primary),
                              foregroundColor: WidgetStateProperty.resolveWith<Color>(
                                  (states) => Colors.white),
                              elevation:
                                  WidgetStateProperty.resolveWith<double>((states) => 0),
                              padding:
                                  WidgetStateProperty.resolveWith<EdgeInsetsGeometry>(
                                      (states) => const EdgeInsets.symmetric(vertical: 12)),
                              shape: WidgetStateProperty.resolveWith<OutlinedBorder>(
                                  (states) {
                                if (states.contains(WidgetState.hovered)) {
                                  return RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    side: const BorderSide(color: Colors.white, width: 2),
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
                                    fontWeight: FontWeight.bold, fontFamily: 'Poppins')),
                          ),
                        ),
                      ),
                    ],
                  )
                : SizedBox(
                    width: double.infinity,
                    height: 48,
                    key: const ValueKey('CloseButton'),
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      style: OutlinedButton.styleFrom(
                        backgroundColor: AppColors.cardBackground,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: const BorderSide(color: AppColors.border),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text("Fechar",
                          style: TextStyle(
                              color: AppColors.secondaryText, fontFamily: 'Poppins')),
                    ),
                  ),
      ),
    );
  }
}
