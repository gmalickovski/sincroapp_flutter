// lib/features/calendar/presentation/widgets/custom_calendar.dart

import 'package:flutter/material.dart';
import 'package:sincro_app_flutter/common/constants/app_colors.dart';
import 'package:sincro_app_flutter/features/calendar/models/event_model.dart';
import 'package:table_calendar/table_calendar.dart';

class CustomCalendar extends StatelessWidget {
  final DateTime focusedDay;
  final DateTime? selectedDay;
  final Function(DateTime, DateTime) onDaySelected;
  final Function(DateTime) onPageChanged;
  final bool isDesktop;
  final double? calendarWidth;
  final int? personalDayNumber;
  final Map<DateTime, List<CalendarEvent>> events;

  const CustomCalendar({
    super.key,
    required this.focusedDay,
    this.selectedDay,
    required this.onDaySelected,
    required this.onPageChanged,
    required this.isDesktop,
    this.calendarWidth,
    this.personalDayNumber,
    required this.events,
  });

  @override
  Widget build(BuildContext context) {
    final rowHeight =
        isDesktop && calendarWidth != null ? (calendarWidth! / 7) - 4 : 52.0;

    return TableCalendar(
      locale: 'pt_BR',
      firstDay: DateTime.utc(2020, 1, 1),
      lastDay: DateTime.utc(2030, 12, 31),
      focusedDay: focusedDay,
      selectedDayPredicate: (day) => isSameDay(selectedDay, day),
      onDaySelected: onDaySelected,
      onPageChanged: onPageChanged,
      calendarFormat: CalendarFormat.month,
      headerVisible: false,
      rowHeight: rowHeight,

      // --- ALTERAÇÃO 1: Esconde os dias da semana do widget ---
      daysOfWeekVisible: false,

      calendarStyle: const CalendarStyle(
        outsideDaysVisible: false,
      ),
      calendarBuilders: CalendarBuilders(
        defaultBuilder: (context, day, focusedDay) {
          return _buildDayCell(
            day: day,
            isSelected: false,
            isToday: false,
          );
        },
        todayBuilder: (context, day, focusedDay) {
          return _buildDayCell(
            day: day,
            isSelected: isSameDay(day, selectedDay),
            isToday: true,
          );
        },
        selectedBuilder: (context, day, focusedDay) {
          return _buildDayCell(
            day: day,
            isSelected: true,
            isToday: isSameDay(day, DateTime.now()),
          );
        },
        markerBuilder: (context, day, events) {
          return null;
        },
      ),
    );
  }

  Widget _buildDayCell(
      {required DateTime day,
      required bool isSelected,
      required bool isToday}) {
    Color borderColor = AppColors.border.withOpacity(0.5);
    if (isSelected) {
      borderColor = _getPersonalDayColor(day);
    } else if (isToday) {
      borderColor = AppColors.primary.withOpacity(0.7);
    }

    return Container(
      margin: const EdgeInsets.all(2.0),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(
          color: borderColor,
          width: isSelected ? 2.0 : 1.0,
        ),
      ),
      child: Align(
        alignment: Alignment.topLeft,
        child: Padding(
          padding: const EdgeInsets.all(6.0),
          child: Text(
            '${day.day}',
            style: TextStyle(
              color: isToday && !isSelected
                  ? AppColors.primary
                  : AppColors.secondaryText,
              fontWeight: FontWeight.bold,
              fontSize: isDesktop ? 14 : 12,
            ),
          ),
        ),
      ),
    );
  }

  Color _getPersonalDayColor(DateTime day) {
    if (!isSameDay(day, selectedDay)) return Colors.transparent;
    switch (personalDayNumber) {
      case 1:
        return Colors.red.shade400;
      case 2:
        return Colors.orange.shade400;
      case 3:
        return Colors.yellow.shade400;
      case 4:
        return Colors.lime.shade400;
      case 5:
        return Colors.cyan.shade400;
      case 6:
        return Colors.blue.shade400;
      case 7:
        return Colors.purple.shade400;
      case 8:
        return Colors.pink.shade400;
      case 9:
        return Colors.teal.shade400;
      case 11:
        return Colors.purple.shade300;
      case 22:
        return Colors.indigo.shade300;
      default:
        return AppColors.primary;
    }
  }
}
