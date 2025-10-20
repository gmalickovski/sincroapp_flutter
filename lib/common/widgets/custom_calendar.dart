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
  final int? personalDayNumber; // Necessário para _DayCell
  final Map<DateTime, List<CalendarEvent>> events; // Espera chaves UTC

  const CustomCalendar({
    super.key,
    required this.focusedDay,
    this.selectedDay,
    required this.onDaySelected,
    required this.onPageChanged,
    this.isDesktop = false,
    this.calendarWidth,
    this.personalDayNumber, // Recebe
    required this.events, // Espera chaves UTC
  });

  // Usa chave UTC (como no código antigo que funcionava)
  List<CalendarEvent> _getEventsForDay(DateTime day) {
    final key = DateTime.utc(day.year, day.month, day.day);
    return events[key] ?? [];
  }

  @override
  Widget build(BuildContext context) {
    final rowHeight =
        isDesktop && calendarWidth != null ? (calendarWidth! / 7) - 4 : 52.0;
    // Removido borderRadius daqui, pois o container agora é transparente

    return Container(
      // --- INÍCIO DA CORREÇÃO DE LAYOUT ---
      // Tornar o container externo transparente ou remover a cor
      decoration: BoxDecoration(
        color: Colors.transparent, // Remove o fundo cinza indesejado
        borderRadius:
            BorderRadius.circular(8.0), // Mantém o arredondamento se necessário
      ),
      // --- FIM DA CORREÇÃO DE LAYOUT ---
      padding: const EdgeInsets.only(bottom: 8), // Mantém padding inferior
      child: TableCalendar<CalendarEvent>(
        locale: 'pt_BR',
        firstDay: DateTime.utc(2010, 1, 1),
        lastDay: DateTime.utc(2100, 12, 31), // Aumentado limite final
        focusedDay: focusedDay,
        calendarFormat: CalendarFormat.month,
        startingDayOfWeek: StartingDayOfWeek.sunday,
        availableGestures: AvailableGestures.horizontalSwipe,
        headerVisible:
            false, // Cabeçalho INTERNO desabilitado (externo cuida disso)
        calendarStyle: const CalendarStyle(
          outsideDaysVisible: false,
          // Decorações transparentes (mantidas)
          todayDecoration: BoxDecoration(color: Colors.transparent),
          selectedDecoration: BoxDecoration(color: Colors.transparent),
          defaultDecoration: BoxDecoration(color: Colors.transparent),
          weekendDecoration: BoxDecoration(color: Colors.transparent),
          // Estilos de texto (ajuste cores se necessário)
          weekendTextStyle: TextStyle(
              color: AppColors.secondaryText), // Cor para Fim de Semana
          defaultTextStyle:
              TextStyle(color: AppColors.primaryText), // Cor para Dias Normais
          markerDecoration: BoxDecoration(), // Remove marcador padrão
        ),
        // --- INÍCIO DA CORREÇÃO DE LAYOUT ---
        daysOfWeekVisible:
            false, // Esconde o cabeçalho de dias padrão (Dom, Seg...)
        // --- FIM DA CORREÇÃO DE LAYOUT ---
        daysOfWeekStyle:
            const DaysOfWeekStyle(/* Estilos não são mais visíveis */),
        rowHeight: rowHeight,
        daysOfWeekHeight: 0, // Altura zero, pois está invisível
        selectedDayPredicate: (day) => isSameDay(selectedDay, day),
        eventLoader: _getEventsForDay, // Usa a função com chave UTC
        onDaySelected: onDaySelected,
        onPageChanged: onPageChanged,

        // Usa builders de célula (_DayCell desenha marcadores)
        calendarBuilders: CalendarBuilders(
          // REMOVIDO markerBuilder
          defaultBuilder: (context, day, focusedDay) {
            return _DayCell(
              day: day, isDesktop: isDesktop,
              events: _getEventsForDay(day), // Passa eventos
            );
          },
          selectedBuilder: (context, day, focusedDay) {
            return _DayCell(
              day: day, isDesktop: isDesktop, isSelected: true,
              personalDayNumber: personalDayNumber, // Passa
              events: _getEventsForDay(day), // Passa eventos
            );
          },
          todayBuilder: (context, day, focusedDay) {
            return _DayCell(
              day: day, isDesktop: isDesktop, isToday: true,
              isSelected: isSameDay(day, selectedDay),
              personalDayNumber:
                  isSameDay(day, selectedDay) ? personalDayNumber : null,
              events: _getEventsForDay(day), // Passa eventos
            );
          },
          outsideBuilder: (context, day, focusedDay) {
            return Container(
              // Mantém célula esmaecida
              margin: const EdgeInsets.all(2.0), alignment: Alignment.center,
              child: Text(
                '${day.day}',
                style:
                    TextStyle(color: AppColors.tertiaryText.withOpacity(0.3)),
              ),
            );
          },
        ),
      ),
    );
  }

  // Removidas funções _buildEventsMarker, _buildMarker, _buildMoreMarker
} // Fim da classe CustomCalendar

// --- WIDGET _DayCell (Desenha marcadores - sem alterações nesta etapa) ---
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
        return AppColors.taskMarker ?? Colors.blue;
      case EventType.goalTask:
        return AppColors.goalTaskMarker ?? Colors.purple;
      case EventType.journal:
        return AppColors.journalMarker ?? Colors.green;
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
    Color backgroundColor =
        Colors.white.withOpacity(0.03); // Fundo padrão sutil
    if (widget.isToday && !widget.isSelected) {
      backgroundColor = AppColors.cardBackground.withOpacity(0.8);
    }
    if (_isHovered && !widget.isSelected && widget.isDesktop) {
      backgroundColor = AppColors.cardBackground.withOpacity(0.6);
    }

    Color borderColor = AppColors.border.withOpacity(0.5); // Borda padrão
    if (widget.isSelected) {
      borderColor = _getPersonalDayColor();
    } else if (widget.isToday) {
      borderColor = AppColors.primary.withOpacity(0.7);
    }

    Color textColor = AppColors.secondaryText; // Cor padrão texto
    if (widget.isToday && !widget.isSelected) {
      textColor = AppColors.primary;
    }
    if (widget.isSelected) {
      textColor = Colors.white;
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
          color: backgroundColor, // Fundo da célula
          borderRadius: BorderRadius.circular(8.0),
          border: Border.all(
            color: borderColor, // Borda da célula
            width: widget.isSelected ? 2.0 : (widget.isToday ? 1.0 : 0.5),
          ),
        ),
        child: Stack(
          children: [
            // Número do dia
            Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.all(6.0),
                child: Text(
                  '${widget.day.day}',
                  style: TextStyle(
                    color: textColor, // Cor do número
                    fontWeight: widget.isSelected || widget.isToday
                        ? FontWeight.bold
                        : FontWeight.normal,
                    fontSize: widget.isDesktop ? 14 : 12,
                  ),
                ),
              ),
            ),

            // Marcadores (desenhados pelo _DayCell)
            if (widget.events.isNotEmpty)
              Positioned(
                bottom: widget.isDesktop ? 8 : 4,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: widget.events
                      .map((e) => e.type)
                      .toSet() // Tipos únicos
                      .map((type) {
                        final markerSize =
                            widget.isDesktop ? 6.0 : 5.0; // Ajustado
                        return Container(
                          width: markerSize,
                          height: markerSize,
                          margin: const EdgeInsets.symmetric(horizontal: 1.5),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _getColorForEventType(type),
                          ),
                        );
                      })
                      .take(widget.isDesktop ? 5 : 3) // Limita
                      .toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
