// lib/features/tasks/presentation/widgets/tasks_list_view.dart
import 'package:flutter/material.dart';
import 'package:sincro_app_flutter/common/constants/app_colors.dart';
import 'package:sincro_app_flutter/features/tasks/models/task_model.dart';
import 'package:sincro_app_flutter/features/tasks/presentation/widgets/task_item.dart';
import 'package:sincro_app_flutter/models/user_model.dart';

class TasksListView extends StatelessWidget {
  final List<TaskModel> tasks;
  final UserModel? userData; // Pode ser necessário para a tela de detalhes
  // Removido showJourney pois TaskItem não usa mais diretamente para texto
  // final bool showJourney;
  final String emptyListMessage;
  final String emptyListSubMessage;
  final Function(TaskModel, bool) onToggle;
  // --- INÍCIO DA MUDANÇA ---
  final Function(TaskModel)? onTaskTap; // Callback para abrir detalhes

  // (Solicitação 1) Novos parâmetros de seleção (AGORA OPCIONAIS)
  final bool selectionMode;
  final Set<String> selectedTaskIds;
  final Function(String, bool)? onTaskSelected; // Tornou-se opcional
  // --- FIM DA MUDANÇA ---

  const TasksListView({
    super.key,
    required this.tasks,
    required this.userData,
    // this.showJourney = true, // Removido
    this.emptyListMessage = 'Tudo limpo por aqui!',
    this.emptyListSubMessage = 'Nenhuma tarefa encontrada.',
    required this.onToggle,
    // --- INÍCIO DA MUDANÇA ---
    this.onTaskTap, // Adicionado como opcional

    // (Solicitação 1) Adiciona ao construtor (COM VALORES PADRÃO / OPCIONAIS)
    this.selectionMode = false,
    this.selectedTaskIds = const {},
    this.onTaskSelected, // Não é mais 'required'
    // --- FIM DA MUDANÇA ---
  });

  @override
  Widget build(BuildContext context) {
    if (tasks.isEmpty) {
      // --- MANTIDO: O seu UI de lista vazia original ---
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle_outline,
                color: AppColors.tertiaryText, size: 48),
            const SizedBox(height: 16),
            Text(emptyListMessage,
                style: const TextStyle(
                    color: AppColors.secondaryText, fontSize: 18)),
            const SizedBox(height: 8),
            Text(
              emptyListSubMessage,
              style: const TextStyle(color: AppColors.tertiaryText),
            ),
          ],
        ),
      );
      // --- FIM DO CÓDIGO MANTIDO ---
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(
          8, 8, 16, 80), // Added right padding for scrollbar
      itemCount: tasks.length,
      itemBuilder: (context, index) {
        final task = tasks[index];
        return TaskItem(
          key: ValueKey(task.id),
          task: task,
          // Core callbacks
          onToggle: (isCompleted) => onToggle(task, isCompleted),
          onTap: onTaskTap != null ? () => onTaskTap!(task) : null,
          // Selection mode props
          selectionMode: selectionMode,
          selectedTaskIds: selectedTaskIds,
          onTaskSelected: onTaskSelected,
          // Layout flags com valores default
          showGoalIconFlag: true,
          showTagsIconFlag: true,
          showVibrationPillFlag: true,
        );
      },
    );
  }
}
