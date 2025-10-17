// lib/features/calendar/presentation/widgets/day_detail_panel.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:sincro_app_flutter/common/constants/app_colors.dart';
import 'package:sincro_app_flutter/common/widgets/vibration_pill.dart';
import 'package:sincro_app_flutter/features/journal/models/journal_entry_model.dart';
import 'package:sincro_app_flutter/features/tasks/models/task_model.dart';
import 'package:sincro_app_flutter/features/tasks/presentation/widgets/task_item.dart';

class DayDetailPanel extends StatelessWidget {
  final DateTime? selectedDay;
  final int? personalDayNumber;
  final List<dynamic> events;
  final bool isDesktop;
  final VoidCallback onAddTask;
  final Function(TaskModel) onEditTask;
  final Function(TaskModel) onDeleteTask;
  final Function(TaskModel) onDuplicateTask;
  final Function(TaskModel, bool) onToggleTask;

  const DayDetailPanel({
    super.key,
    this.selectedDay,
    this.personalDayNumber,
    required this.events,
    this.isDesktop = false,
    required this.onAddTask,
    required this.onEditTask,
    required this.onDeleteTask,
    required this.onDuplicateTask,
    required this.onToggleTask,
  });

  @override
  Widget build(BuildContext context) {
    if (selectedDay == null) {
      return isDesktop ? _buildEmptyStateDesktop() : const SizedBox.shrink();
    }

    final formattedDate = toBeginningOfSentenceCase(
        DateFormat("EEEE, 'dia' d", 'pt_BR').format(selectedDay!));

    return Container(
      decoration: BoxDecoration(
        color: isDesktop ? AppColors.cardBackground : Colors.transparent,
        borderRadius: isDesktop ? BorderRadius.circular(12) : null,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            child: Row(
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
          ),
          const Divider(height: 32, color: AppColors.border),
          if (events.isEmpty)
            _buildEmptyStateMobile()
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: events.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final event = events[index];
                if (event is TaskModel) {
                  return TaskItem(
                    task: event,
                    showJourney: true,
                    onToggle: (isCompleted) => onToggleTask(event, isCompleted),
                    onEdit: () => onEditTask(event),
                    onDelete: () => onDeleteTask(event),
                    onDuplicate: () => onDuplicateTask(event),
                  );
                }
                if (event is JournalEntry) {
                  return _JournalListItem(entry: event);
                }
                return const SizedBox.shrink();
              },
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyStateDesktop() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Center(
        child: Text("Selecione um dia para ver os detalhes.",
            style: TextStyle(color: AppColors.secondaryText)),
      ),
    );
  }

  Widget _buildEmptyStateMobile() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 32.0),
        child: Column(
          children: [
            Icon(Icons.inbox_outlined, color: AppColors.tertiaryText, size: 32),
            SizedBox(height: 8),
            Text(
              "Nenhum item para este dia.",
              style: TextStyle(color: AppColors.tertiaryText),
            ),
          ],
        ),
      ),
    );
  }
}

class _JournalListItem extends StatelessWidget {
  final JournalEntry entry;

  const _JournalListItem({required this.entry});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.cardBackground.withOpacity(0.5),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: () {
          // TODO: Implementar navegação para a tela de detalhes do diário
          print('Visualizar anotação: ${entry.id}');
        },
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 2.0),
                child: Icon(Icons.book_outlined,
                    color: AppColors.journalMarker, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  entry.content,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: AppColors.secondaryText, height: 1.5),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
