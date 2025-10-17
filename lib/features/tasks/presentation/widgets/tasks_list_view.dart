// lib/features/tasks/presentation/widgets/tasks_list_view.dart
import 'package:flutter/material.dart';
import 'package:sincro_app_flutter/common/constants/app_colors.dart';
import 'package:sincro_app_flutter/features/tasks/models/task_model.dart';
import 'package:sincro_app_flutter/features/tasks/presentation/widgets/task_item.dart';
import 'package:sincro_app_flutter/models/user_model.dart';

class TasksListView extends StatelessWidget {
  final List<TaskModel> tasks;
  final UserModel? userData;
  final bool showJourney;
  final String emptyListMessage;
  final String emptyListSubMessage;
  final Function(TaskModel, bool) onToggle;
  final Function(TaskModel) onTaskDeleted;
  final Function(TaskModel) onTaskEdited;
  final Function(TaskModel) onTaskDuplicated;

  const TasksListView({
    super.key,
    required this.tasks,
    required this.userData,
    this.showJourney = true,
    this.emptyListMessage = 'Tudo limpo por aqui!',
    this.emptyListSubMessage = 'Nenhuma tarefa encontrada.',
    required this.onToggle,
    required this.onTaskDeleted,
    required this.onTaskEdited,
    required this.onTaskDuplicated,
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
      // *** PADDING HORIZONTAL REMOVIDO PARA SER CONTROLADO PELA TELA PAI ***
      padding: const EdgeInsets.only(top: 8, bottom: 80),
      itemCount: tasks.length,
      itemBuilder: (context, index) {
        final task = tasks[index];
        return TaskItem(
          task: task,
          showJourney: showJourney,
          onToggle: (isCompleted) => onToggle(task, isCompleted),
          onEdit: () => onTaskEdited(task),
          onDelete: () => onTaskDeleted(task),
          onDuplicate: () => onTaskDuplicated(task),
        );
      },
    );
  }
}
