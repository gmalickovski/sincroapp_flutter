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
  // REMOVIDO: final Function(TaskModel) onTaskDeleted;
  // REMOVIDO: final Function(TaskModel) onTaskEdited;
  // REMOVIDO: final Function(TaskModel) onTaskDuplicated;
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
    // REMOVIDO: required this.onTaskDeleted,
    // REMOVIDO: required this.onTaskEdited,
    // REMOVIDO: required this.onTaskDuplicated,
    // --- FIM DA MUDANÇA ---
  });

  @override
  Widget build(BuildContext context) {
    if (tasks.isEmpty) {
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
    }

    return ListView.builder(
      padding: const EdgeInsets.only(top: 8, bottom: 80),
      itemCount: tasks.length,
      itemBuilder: (context, index) {
        final task = tasks[index];
        return TaskItem(
          key: ValueKey(task.id), // Boa prática adicionar key
          task: task,
          // showJourney não é mais um parâmetro direto relevante para TaskItem como antes
          // showGoalIconFlag, showTagsIconFlag, showVibrationPillFlag podem ser passados aqui se necessário
          // controlar a exibição desses ícones de forma diferente em listas diferentes.
          // Por enquanto, usaremos os defaults do TaskItem.
          onToggle: (isCompleted) => onToggle(task, isCompleted),
          // --- INÍCIO DA MUDANÇA ---
          onTap: onTaskTap != null
              ? () => onTaskTap!(task)
              : null, // Passa o onTap
          // REMOVIDO: onEdit: () => onTaskEdited(task),
          // REMOVIDO: onDelete: () => onTaskDeleted(task),
          // REMOVIDO: onDuplicate: () => onTaskDuplicated(task),
          // --- FIM DA MUDANÇA ---
        );
      },
    );
  }
}
