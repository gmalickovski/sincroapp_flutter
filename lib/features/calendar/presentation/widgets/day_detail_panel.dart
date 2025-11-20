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

  const DayDetailPanel({
    super.key,
    // --- INÍCIO DA CORREÇÃO (Refatoração) ---
    // 'selectedDay' agora é obrigatório (required) e não-nulo.
    required this.selectedDay,
    // --- FIM DA CORREÇÃO ---
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
    // --- INÍCIO DA CORREÇÃO (Refatoração) ---
    // A verificação "if (selectedDay == null)" foi REMOVIDA.
    // O widget agora pressupõe que 'selectedDay' é válido.
    // --- FIM DA CORREÇÃO ---
    final formattedDate = toBeginningOfSentenceCase(
        DateFormat("EEEE, 'dia' d", 'pt_BR').format(selectedDay));

    // --- INÍCIO DA MUDANÇA: Adiciona Container para o "Sheet" ---
    // Envolvemos o conteúdo em um Container para dar a ele uma aparência
    // de "gaveta" com cantos arredondados no topo.
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black38,
            blurRadius: 10,
            offset: Offset(0, -5),
          ),
        ],
      ),
      // --- INÍCIO DA MUDANÇA: CustomScrollView para permitir arrastar pelo cabeçalho ---
      // Usamos CustomScrollView para que o cabeçalho faça parte da área rolável,
      // permitindo que o DraggableScrollableSheet responda ao arrasto no cabeçalho.
      child: CustomScrollView(
        controller: scrollController,
        slivers: [
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- INÍCIO DA MUDANÇA: Adiciona o "Drag Handle" com área maior ---
                // Este é o traço visual que indica que o painel é arrastável.
                // Envolvemos em um GestureDetector para aumentar a área de toque.
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12.0),
                    child: Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppColors.border.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ),
                ),
                // --- FIM DA MUDANÇA ---
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                      16, 0, 16, 0), // Padding superior removido
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        // Garante que a data não estoure
                        child: Text(
                          formattedDate, // Removido '!' desnecessário
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold),
                          overflow: TextOverflow
                              .ellipsis, // Evita quebra se muito longo
                        ),
                      ),
                      if (personalDayNumber != null && personalDayNumber! > 0)
                        Padding(
                          // Adiciona padding para não colar no botão add
                          padding: const EdgeInsets.symmetric(horizontal: 8.0),
                          child: VibrationPill(
                              vibrationNumber: personalDayNumber!),
                        ),
                    ],
                  ),
                ),
                const Divider(height: 32, color: AppColors.border),
              ],
            ),
          ),
          if (events.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: _buildEmptyStateMobile(),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final event = events[index];
                  if (event is TaskModel) {
                    return TaskItem(
                      key: ValueKey('task_${event.id}'),
                      task: event,
                      onToggle: (isCompleted) =>
                          onToggleTask(event, isCompleted),
                      onTap: () =>
                          onTaskTap(event), // Chama o callback principal
                      showGoalIconFlag: true,
                      showTagsIconFlag: true,
                      showVibrationPillFlag: true,
                      verticalPaddingOverride: 4.0,
                    );
                  }
                  return const SizedBox.shrink();
                },
                childCount: events.length,
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
