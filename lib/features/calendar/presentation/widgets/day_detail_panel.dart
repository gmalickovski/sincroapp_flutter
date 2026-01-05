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
  // --- INÍCIO DA CORREÇÃO (Refatoração) ---
  // Alterado de 'DateTime?' para 'DateTime' pois agora garantimos
  // que um dia sempre estará selecionado na tela principal.
  final DateTime selectedDay;
  // --- FIM DA CORREÇÃO ---
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

  final Future<bool?> Function(TaskModel)? onDeleteTask;
  final Future<bool?> Function(TaskModel)? onRescheduleTask;
  final VoidCallback? onToggleCalendar; 
  final bool isCalendarExpanded;

  const DayDetailPanel({
    super.key,
    required this.selectedDay,
    this.personalDayNumber,
    required this.events,
    this.isDesktop = false,
    required this.onAddTask,
    required this.onToggleTask,
    required this.onTaskTap,
    this.scrollController,
    this.onDeleteTask,
    this.onRescheduleTask,
    this.onToggleCalendar,
    this.isCalendarExpanded = true,
  });

  @override
  Widget build(BuildContext context) {
    final formattedDate = toBeginningOfSentenceCase(
        DateFormat("EEEE, 'dia' d", 'pt_BR').format(selectedDay));

    return Container(
      // Removido decoração de sombra/bordas arredondadas (User request: "sem sobreado", "mesma cor")
      color: AppColors.background, 
      child: Column(
        children: [
           // Cabeçalho da Lista
           Container(
             padding: EdgeInsets.fromLTRB(16, isDesktop ? 16 : 8, 16, 0),
             child: Column(
               children: [
                 Row(
                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
                   crossAxisAlignment: CrossAxisAlignment.start, // Alinha ao topo para wrap
                   children: [
                     Expanded(
                       child: Text(
                         formattedDate,
                         style: TextStyle(
                             color: Colors.white,
                             fontSize: isDesktop ? 24.0 : 16.0,
                             fontWeight: FontWeight.bold),
                         // Permite quebra de linha
                         maxLines: 2,
                         overflow: TextOverflow.ellipsis,
                       ),
                     ),
                     // Pill de vibração + Botão de expandir em uma Row compacta
                     Row(
                       mainAxisSize: MainAxisSize.min,
                       children: [
                         if (personalDayNumber != null && personalDayNumber! > 0)
                           Padding(
                             padding: const EdgeInsets.only(left: 4.0), // Reduzido
                             child: VibrationPill(vibrationNumber: personalDayNumber!),
                           ),
                         // Ícone de expandir/recolher calendário (Apenas mobile)
                         if (!isDesktop && onToggleCalendar != null)
                           IconButton(
                             icon: Icon(
                               isCalendarExpanded 
                                 ? Icons.keyboard_arrow_up 
                                 : Icons.keyboard_arrow_down,
                               color: AppColors.secondaryText,
                             ),
                             onPressed: onToggleCalendar,
                             padding: const EdgeInsets.all(4), // Padding mínimo
                             constraints: const BoxConstraints(), // Remove constraints padrão
                             visualDensity: VisualDensity.compact,
                           ),
                       ],
                     ),
                  ],
                 ),
                 const Divider(height: 24, color: AppColors.border),
               ],
             ),
           ),
           
           // Lista de Tarefas (Sliver ou ListView)
           // Como removemos o DraggableScrollableSheet, podemos usar Expanded + ListView
           // OU manter CustomScrollView se o pai for um Column/Expanded
           Expanded(
            child: events.isEmpty 
              ? _buildEmptyStateMobile()
              : ListView.builder(
                  controller: scrollController, // Pode ser nulo agora
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: events.length,
                  itemBuilder: (context, index) {
                    final event = events[index];
                    if (event is TaskModel) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: TaskItem(
                          key: ValueKey('task_${event.id}'),
                          task: event,
                          onToggle: (isCompleted) => onToggleTask(event, isCompleted),
                          onTap: () => onTaskTap(event),
                          showGoalIconFlag: true,
                          showTagsIconFlag: true,
                          showVibrationPillFlag: false, // Oculta pois já aparece no header
                          verticalPaddingOverride: 4.0,
                          onSwipeLeft: onDeleteTask,
                          onSwipeRight: onRescheduleTask,
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
           ),
        ],
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
