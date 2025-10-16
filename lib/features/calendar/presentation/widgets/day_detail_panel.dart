// lib/features/calendar/presentation/widgets/day_detail_panel.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:sincro_app_flutter/common/constants/app_colors.dart';
import 'package:sincro_app_flutter/common/widgets/vibration_pill.dart';
import 'package:sincro_app_flutter/features/calendar/models/event_model.dart';

class DayDetailPanel extends StatelessWidget {
  final DateTime? selectedDay;
  final int? personalDayNumber;
  final List<CalendarEvent> events;
  final bool isDesktop;
  final VoidCallback onAddTask;

  const DayDetailPanel({
    super.key,
    this.selectedDay,
    this.personalDayNumber,
    required this.events,
    this.isDesktop = false,
    required this.onAddTask,
  });

  Color _getColorForEventType(EventType type) {
    switch (type) {
      case EventType.task:
        return AppColors.taskMarker;
      case EventType.goalTask:
        return AppColors.goalTaskMarker;
      case EventType.journal:
        return AppColors.journalMarker;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (selectedDay == null && isDesktop) {
      return Container(
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.calendar_today_outlined,
                  size: 48, color: AppColors.tertiaryText),
              SizedBox(height: 16),
              Text(
                "Selecione um dia",
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.secondaryText),
              ),
              Text(
                "Escolha uma data para ver os detalhes.",
                style: TextStyle(color: AppColors.tertiaryText),
              ),
            ],
          ),
        ),
      );
    }

    if (selectedDay == null) {
      return const SizedBox.shrink();
    }

    final formattedDate = toBeginningOfSentenceCase(
        DateFormat("EEEE, 'dia' d", 'pt_BR').format(selectedDay!));

    return Container(
      decoration: BoxDecoration(
        color: isDesktop ? AppColors.cardBackground : Colors.transparent,
        borderRadius: isDesktop ? BorderRadius.circular(12) : null,
        border: isDesktop
            ? null
            : Border(top: BorderSide(color: Colors.grey.shade800)),
      ),
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        // *** INÍCIO DA CORREÇÃO (Layout Mobile) ***
        // O MainAxisSize.min garante que a coluna não tente se expandir infinitamente
        // quando não está dentro de um Expanded (importante para o layout mobile).
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                formattedDate!,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold),
              ),
              if (personalDayNumber != null)
                VibrationPill(vibrationNumber: personalDayNumber!),
            ],
          ),
          const SizedBox(height: 16),
          if (events.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 32.0),
                child: Text(
                  "Nenhum item para este dia.",
                  style: TextStyle(color: AppColors.tertiaryText),
                ),
              ),
            )
          else
            // Removemos o `Expanded` e configuramos o `ListView`
            // para funcionar dentro de um `SingleChildScrollView`.
            ListView.builder(
              shrinkWrap:
                  true, // Permite que a lista tenha o tamanho do seu conteúdo.
              physics:
                  const NeverScrollableScrollPhysics(), // Desativa o scroll da lista interna.
              itemCount: events.length,
              itemBuilder: (context, index) {
                final event = events[index];
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.circle,
                      color: _getColorForEventType(event.type), size: 12),
                  title: Text(event.title,
                      style: const TextStyle(color: AppColors.primaryText)),
                );
              },
            ),

          // No modo desktop, esta Column está dentro de um Expanded,
          // então o Spacer funciona como esperado.
          if (isDesktop) const Spacer(),

          if (isDesktop) ...[
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onAddTask,
              icon: const Icon(Icons.add),
              label: const Text("Adicionar Tarefa"),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 48),
              ),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.add_comment_outlined),
              label: const Text("Nova Anotação"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.cyan.shade600,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 48),
              ),
            )
          ]
        ],
        // *** FIM DA CORREÇÃO ***
      ),
    );
  }
}
