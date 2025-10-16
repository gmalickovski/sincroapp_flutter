// lib/common/widgets/custom_calendar.dart

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

  List<CalendarEvent> _getEventsForDay(DateTime day) {
    return events[DateTime.utc(day.year, day.month, day.day)] ?? [];
  }

  @override
  Widget build(BuildContext context) {
    final rowHeight =
        isDesktop && calendarWidth != null ? (calendarWidth! / 7) - 4 : 52.0;

    return TableCalendar<CalendarEvent>(
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
      daysOfWeekVisible: false,
      eventLoader: _getEventsForDay,
      calendarStyle: const CalendarStyle(
        outsideDaysVisible: false,
        // Manter estas decorações transparentes é uma boa prática
        // para garantir que nenhum estilo padrão interfira.
        todayDecoration: BoxDecoration(color: Colors.transparent),
        selectedDecoration: BoxDecoration(color: Colors.transparent),
        defaultDecoration: BoxDecoration(color: Colors.transparent),
        weekendDecoration: BoxDecoration(color: Colors.transparent),
      ),
      calendarBuilders: CalendarBuilders(
        // *** INÍCIO DA CORREÇÃO (Círculos Escuros) ***
        // Adicionamos este builder. Ele sobrescreve o desenho
        // padrão dos marcadores de evento (os círculos escuros).
        // Ao retornar um widget vazio, nós efetivamente os removemos.
        markerBuilder: (context, day, events) {
          return const SizedBox.shrink();
        },
        // *** FIM DA CORREÇÃO ***
        defaultBuilder: (context, day, focusedDay) {
          return _DayCell(
            day: day,
            isDesktop: isDesktop,
            events: _getEventsForDay(day),
          );
        },
        selectedBuilder: (context, day, focusedDay) {
          return _DayCell(
            day: day,
            isDesktop: isDesktop,
            isSelected: true,
            personalDayNumber: personalDayNumber,
            events: _getEventsForDay(day),
          );
        },
        todayBuilder: (context, day, focusedDay) {
          return _DayCell(
            day: day,
            isDesktop: isDesktop,
            isToday: true,
            isSelected: isSameDay(day, selectedDay),
            personalDayNumber: personalDayNumber,
            events: _getEventsForDay(day),
          );
        },
        outsideBuilder: (context, day, focusedDay) {
          return Container(
            margin: const EdgeInsets.all(2.0),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.01),
              borderRadius: BorderRadius.circular(8.0),
            ),
          );
        },
      ),
    );
  }
}

// O widget _DayCell permanece o mesmo
class _DayCell extends StatefulWidget {
  final DateTime day;
  final bool isDesktop;
  final bool isSelected;
  final bool isToday;
  final int? personalDayNumber;
  final List<CalendarEvent> events;

  const _DayCell({
    required this.day,
    required this.isDesktop,
    this.isSelected = false,
    this.isToday = false,
    this.personalDayNumber,
    this.events = const [],
  });

  @override
  State<_DayCell> createState() => _DayCellState();
}

class _DayCellState extends State<_DayCell> {
  bool _isHovered = false;

  Color _getColorForEventType(EventType type) {
    switch (type) {
      case EventType.task:
        return AppColors.taskMarker;
      case EventType.goalTask:
        return AppColors.goalTaskMarker;
      case EventType.journal:
        return AppColors.journalMarker;
      default:
        return Colors.transparent;
    }
  }

  Color _getPersonalDayColor() {
    if (!widget.isSelected) return Colors.transparent;
    switch (widget.personalDayNumber) {
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

  @override
  Widget build(BuildContext context) {
    Color backgroundColor = Colors.white.withOpacity(0.03);
    if (widget.isToday && !widget.isSelected) {
      backgroundColor = AppColors.cardBackground.withOpacity(0.8);
    }
    if (_isHovered && !widget.isSelected && widget.isDesktop) {
      backgroundColor = AppColors.cardBackground.withOpacity(0.6);
    }

    Color borderColor = AppColors.border.withOpacity(0.5);
    if (widget.isSelected) {
      borderColor = _getPersonalDayColor();
    } else if (widget.isToday) {
      borderColor = AppColors.primary.withOpacity(0.7);
    }

    return MouseRegion(
      onEnter: (_) {
        if (widget.isDesktop) setState(() => _isHovered = true);
      },
      onExit: (_) {
        if (widget.isDesktop) setState(() => _isHovered = false);
      },
      cursor: SystemMouseCursors.click,
      child: Container(
        margin: const EdgeInsets.all(2.0),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(8.0),
          border: Border.all(
            color: borderColor,
            width: widget.isSelected ? 2.0 : 1.0,
          ),
        ),
        child: Stack(
          children: [
            Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.all(6.0),
                child: Text(
                  '${widget.day.day}',
                  style: TextStyle(
                    color: widget.isToday && !widget.isSelected
                        ? AppColors.primary
                        : AppColors.secondaryText,
                    fontWeight: FontWeight.bold,
                    fontSize: widget.isDesktop ? 14 : 12,
                  ),
                ),
              ),
            ),
            if (widget.events.isNotEmpty)
              Positioned(
                bottom: widget.isDesktop ? 8 : 4,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children:
                      widget.events.map((e) => e.type).toSet().map((type) {
                    return Container(
                      width: widget.isDesktop ? 8 : 6,
                      height: widget.isDesktop ? 8 : 6,
                      margin: const EdgeInsets.symmetric(horizontal: 1.5),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _getColorForEventType(type),
                      ),
                    );
                  }).toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
