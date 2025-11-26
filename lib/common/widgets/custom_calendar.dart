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
    // Calcula a altura da linha baseado no espaço disponível na tela
    final screenHeight = MediaQuery.of(context).size.height;
    final availableHeight = isDesktop
        ? screenHeight * 0.65
        : screenHeight * 0.45; // 65% da altura na versão desktop
    final rowHeight = isDesktop
        ? (availableHeight / 6) - 8 // 6 linhas do calendário, com margem
        : 52.0; // Altura fixa para mobile

    return Container(
      // Mantém o calendário alinhado ao topo e dá uma altura controlada no desktop
      alignment: Alignment.topCenter,
      height: isDesktop ? availableHeight : null,
      // --- INÍCIO DA CORREÇÃO DE LAYOUT ---
      // Tornar o container externo transparente ou remover a cor
      decoration: BoxDecoration(
        color: Colors.transparent, // Remove o fundo cinza indesejado
        borderRadius:
            BorderRadius.circular(8.0), // Mantém o arredondamento se necessário
      ),
      // --- FIM DA CORREÇÃO DE LAYOUT ---
      padding: const EdgeInsets.only(bottom: 8, top: 8), // Mantém padding
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
        enabledDayPredicate: (day) {
          // Desabilita a seleção de dias passados
          final now = DateTime.now();
          final today = DateTime(now.year, now.month, now.day);
          final checkDay = DateTime(day.year, day.month, day.day);
          return !checkDay.isBefore(today);
        },
        calendarBuilders: CalendarBuilders(
          // --- INÍCIO DA CORREÇÃO (Refatoração) ---
          // Lógica 'isPastDay' removida pois 'enabledDayPredicate' garante
          // que este builder só rode para dias futuros (ou hoje).
          defaultBuilder: (context, day, focusedDay) {
            return _DayCell(
              day: day,
              isDesktop: isDesktop,
              isSelected: false,
              events: _getEventsForDay(day),
              isPastDayOverride: false, // Explícito que não é passado
              personalDayNumber:
                  null, // Necessário para manter consistência visual
            );
          },
          // --- FIM DA CORREÇÃO ---

          selectedBuilder: (context, day, focusedDay) {
            final now = DateTime.now();
            final today = DateTime(now.year, now.month, now.day);
            final checkDay = DateTime(day.year, day.month, day.day);
            final isPastDay = checkDay.isBefore(today);

            return _DayCell(
              day: day,
              isDesktop: isDesktop,
              isSelected: !isPastDay, // Só permite seleção de dias futuros
              personalDayNumber: isPastDay ? null : personalDayNumber,
              events: _getEventsForDay(day),
              isPastDayOverride: isPastDay,
            );
          },
          todayBuilder: (context, day, focusedDay) {
            return _DayCell(
              day: day,
              isDesktop: isDesktop,
              isToday: true,
              isSelected: isSameDay(day, selectedDay),
              personalDayNumber:
                  isSameDay(day, selectedDay) ? personalDayNumber : null,
              events: _getEventsForDay(day),
              isPastDayOverride: false, // Hoje nunca é considerado passado
            );
          },

          // --- INÍCIO DA CORREÇÃO (PROBLEMA 1) ---
          // Adicionado 'disabledBuilder' para customizar dias passados
          disabledBuilder: (context, day, focusedDay) {
            return _DayCell(
              day: day,
              isDesktop: isDesktop,
              isSelected: false,
              events: _getEventsForDay(day),
              isPastDayOverride: true, // Força o estilo de dia passado
              personalDayNumber: null,
            );
          },
          // --- FIM DA CORREÇÃO ---

          outsideBuilder: (context, day, focusedDay) {
            return Container(
              // Mantém célula esmaecida
              margin: const EdgeInsets.all(2.0), alignment: Alignment.center,
              child: Text(
                '${day.day}',
                style: TextStyle(
                    color: AppColors.tertiaryText.withValues(alpha: 0.3)),
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
  final bool? isPastDayOverride;

  const _DayCell({
    required this.day,
    required this.isDesktop,
    this.isSelected = false,
    this.isToday = false,
    this.personalDayNumber,
    this.events = const [],
    this.isPastDayOverride,
  });

  @override
  State<_DayCell> createState() => _DayCellState();
}

class _DayCellState extends State<_DayCell> {
  bool _isHovered = false;

  Color _getColorForEventType(EventType type) {
    if (type == EventType.task) return AppColors.primary; // Roxo/Magenta (Normal)
    if (type == EventType.goalTask) return Colors.cyanAccent; // Ciano (Metas)
    if (type == EventType.scheduledTask) return Colors.orangeAccent; // Laranja (Agendado)
    if (type == EventType.journal) return AppColors.journalMarker;
    throw StateError('Unhandled EventType: $type');
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

  bool _isPastDay() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final cellDay = DateTime(widget.day.year, widget.day.month, widget.day.day);
    return cellDay.isBefore(today);
  }

  // --- INÍCIO DA CORREÇÃO (Request 2) ---
  /// Constrói os marcadores de evento (círculos) para a visualização mobile.
  Widget _buildMobileMarkers() {
    final isPast = widget.isPastDayOverride ?? _isPastDay();
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: widget.events
          .map((e) => e.type)
          .toSet() // Tipos únicos
          .map((type) {
            const markerSize = 5.0;
            final markerColor = _getColorForEventType(type)
                .withValues(alpha: isPast ? 0.9 : 1.0);
            return Container(
              width: markerSize,
              height: markerSize,
              margin: const EdgeInsets.symmetric(horizontal: 1.5),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: markerColor,
              ),
            );
          })
          .take(3) // Limita a 3 marcadores no mobile
          .toList(),
    );
  }

  /// Constrói os marcadores de evento (barras) para a visualização desktop.
  Widget _buildDesktopMarkers() {
    final isPast = widget.isPastDayOverride ?? _isPastDay();
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: widget.events
          .map((e) => e.type)
          .toSet() // Tipos únicos
          .map((type) {
            final markerColor = _getColorForEventType(type)
                .withValues(alpha: isPast ? 0.9 : 1.0);
            return Container(
              height: 4, // Altura da barra
              margin: const EdgeInsets.only(top: 2), // Espaçamento entre barras
              decoration: BoxDecoration(
                color: markerColor,
                borderRadius: BorderRadius.circular(2),
              ),
            );
          })
          .take(3) // Limita a 3 barras para não estourar a célula
          .toList(),
    );
  }
  // --- FIM DA CORREÇÃO (Request 2) ---

  @override
  Widget build(BuildContext context) {
    final isPast = widget.isPastDayOverride ?? _isPastDay();

    // --- INÍCIO DA CORREÇÃO (Ajuste Fino de UI) ---
    // Lógica de cores baseada na sua versão anterior (dias passados visíveis)
    // + ajuste de dias futuros (mais destaque)

    Color backgroundColor;
    Color borderColor;
    Color textColor;

    // 1. DIAS PASSADOS (Opacos, como você gostava)
    if (isPast) {
      backgroundColor =
          AppColors.cardBackground.withValues(alpha: 0.15); // Base
      borderColor = AppColors.border.withValues(alpha: 0.4); // Base
      textColor = AppColors.tertiaryText.withValues(alpha: 0.85); // Texto opaco
    }
    // 2. DIAS FUTUROS (Mais destaque)
    else {
      // Começa com os valores de destaque pedidos
      backgroundColor =
          AppColors.cardBackground.withValues(alpha: 0.3); // MAIS DESTAQUE
      borderColor = AppColors.border.withValues(alpha: 0.7); // MAIS DESTAQUE
      textColor = AppColors.secondaryText; // Texto normal

      // Sobrescreve para HOVER
      if (_isHovered && widget.isDesktop) {
        backgroundColor = AppColors.cardBackground.withValues(alpha: 0.6);
      }

      // Sobrescreve para HOJE (não selecionado)
      if (widget.isToday && !widget.isSelected) {
        backgroundColor = AppColors.cardBackground.withValues(alpha: 0.8);
        borderColor = AppColors.primary.withValues(alpha: 0.7);
        textColor = AppColors.primary;
      }

      // --- INÍCIO DA CORREÇÃO (Request 1) ---
      // Sobrescreve para SELECIONADO (borda colorida, fundo neutro)
      if (widget.isSelected) {
        backgroundColor =
            AppColors.cardBackground.withValues(alpha: 0.8); // Fundo neutro
        borderColor = _getPersonalDayColor(); // Borda na cor do dia
        textColor =
            AppColors.primary; // Texto com cor de destaque (ficará bold)
      }
      // --- FIM DA CORREÇÃO (Request 1) ---
    }
    // --- FIM DA CORREÇÃO ---

    return MouseRegion(
      onEnter: (_) {
        if (widget.isDesktop && !isPast) setState(() => _isHovered = true);
      },
      onExit: (_) {
        if (widget.isDesktop && !isPast) setState(() => _isHovered = false);
      },
      cursor: isPast ? SystemMouseCursors.basic : SystemMouseCursors.click,
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

            // --- INÍCIO DA CORREÇÃO (Request 2) ---
            // Marcadores (condicionais desktop/mobile)
            if (widget.events.isNotEmpty)
              Positioned(
                bottom: widget.isDesktop ? 8 : 4,
                left: widget.isDesktop ? 8 : 0, // Padding para barras desktop
                right: widget.isDesktop ? 8 : 0, // Padding para barras desktop
                child: widget.isDesktop
                    ? _buildDesktopMarkers()
                    : _buildMobileMarkers(),
              ),
            // --- FIM DA CORREÇÃO (Request 2) ---
          ],
        ),
      ),
    );
  }
}
