import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:sincro_app_flutter/common/constants/app_colors.dart';
import 'package:sincro_app_flutter/common/widgets/vibration_pill.dart';
// --- MUDANÇA (TAREFA 3): Import removido ---
// import 'package:sincro_app_flutter/features/journal/models/journal_entry_model.dart';
// --- FIM MUDANÇA ---
import 'package:sincro_app_flutter/features/tasks/models/task_model.dart';
import 'package:sincro_app_flutter/features/tasks/presentation/widgets/task_item.dart';

class DayDetailPanel extends StatelessWidget {
  final DateTime? selectedDay;
  final int? personalDayNumber;
  final List<dynamic> events;
  final bool isDesktop;
  final VoidCallback onAddTask;
  final Function(TaskModel, bool) onToggleTask;
  // --- MUDANÇA: onTaskTap agora é o único callback para clique em tarefa ---
  final Function(TaskModel) onTaskTap;
  // --- FIM MUDANÇA ---
  // --- MUDANÇA (TAREFA 3): Callback removido ---
  // final Function(JournalEntry) onJournalTap;
  // --- FIM MUDANÇA ---
  final ScrollController? scrollController;

  const DayDetailPanel({
    super.key,
    this.selectedDay,
    this.personalDayNumber,
    required this.events,
    this.isDesktop = false,
    required this.onAddTask,
    required this.onToggleTask,
    // --- MUDANÇA: Tornou-se o callback principal ---
    required this.onTaskTap,
    // --- FIM MUDANÇA ---
    // --- MUDANÇA (TAREFA 3): Callback removido ---
    // required this.onJournalTap,
    // --- FIM MUDANÇA ---
    this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    if (selectedDay == null) {
      return isDesktop ? _buildEmptyStateDesktop() : const SizedBox.shrink();
    }

    final formattedDate = toBeginningOfSentenceCase(
        DateFormat("EEEE, 'dia' d", 'pt_BR').format(selectedDay!));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                // Garante que a data não estoure
                child: Text(
                  formattedDate!,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold),
                  overflow:
                      TextOverflow.ellipsis, // Evita quebra se muito longo
                ),
              ),
              if (personalDayNumber != null && personalDayNumber! > 0)
                Padding(
                  // Adiciona padding para não colar no botão add
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: VibrationPill(vibrationNumber: personalDayNumber!),
                ),
              // --- MUDANÇA (TAREFA 1): Botão de adicionar tarefa removido ---
              // IconButton(
              //   icon: const Icon(Icons.add_circle_outline,
              //       color: AppColors.primary),
              //   tooltip:
              //       'Adicionar Tarefa para ${DateFormat('dd/MM').format(selectedDay!)}',
              //   onPressed: onAddTask,
              // ),
              // --- FIM MUDANÇA ---
            ],
          ),
        ),
        const Divider(height: 32, color: AppColors.border),
        Expanded(
          child: events.isEmpty
              ? _buildEmptyStateMobile()
              : ListView.separated(
                  controller: scrollController,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                  shrinkWrap: true,
                  itemCount: events.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: 0), // TaskItem controla o padding
                  itemBuilder: (context, index) {
                    final event = events[index];
                    if (event is TaskModel) {
                      // --- MUDANÇA: Usar onTaskTap e remover callbacks antigos ---
                      return TaskItem(
                        key: ValueKey('task_${event.id}'),
                        task: event,
                        onToggle: (isCompleted) =>
                            onToggleTask(event, isCompleted),
                        onTap: () =>
                            onTaskTap(event), // Chama o callback principal
                        // Flags de exibição (mantidos)
                        showGoalIconFlag: true,
                        showTagsIconFlag: true,
                        showVibrationPillFlag: true,
                        // Padding customizado (mantido)
                        verticalPaddingOverride: 4.0,
                      );
                      // --- FIM MUDANÇA ---
                    }
                    // --- MUDANÇA (TAREFA 3): Bloco do JournalEntry removido ---
                    // if (event is JournalEntry) {
                    //   return _JournalListItem(
                    //     key: ValueKey('journal_${event.id}'),
                    //     entry: event,
                    //     onTap: () => onJournalTap(event),
                    //   );
                    // }
                    // --- FIM MUDANÇA ---
                    return const SizedBox.shrink();
                  },
                ),
        ),
      ],
    );
  }

  // Estados vazios (inalterados)
  Widget _buildEmptyStateDesktop() {
    // Implementação do estado vazio para desktop (inalterada)
    return const Center(
      child: Text(
        'Selecione um dia',
        style: TextStyle(color: AppColors.secondaryText, fontSize: 16),
      ),
    );
  }

  Widget _buildEmptyStateMobile() {
    // Implementação do estado vazio para mobile (inalterada)
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.calendar_today_outlined,
              color: AppColors.secondaryText, size: 48),
          SizedBox(height: 16),
          Text(
            'Nenhum evento para este dia.',
            style: TextStyle(color: AppColors.secondaryText, fontSize: 16),
          ),
        ],
      ),
    );
  }
}

// --- MUDANÇA (TAREFA 3): Widget _JournalListItem removido ---
// class _JournalListItem extends StatelessWidget {
// ...
// }
// --- FIM MUDANÇA ---
