// lib/features/dashboard/presentation/widgets/focus_day_card.dart

import 'package:flutter/material.dart';
import 'package:sincro_app_flutter/common/constants/app_colors.dart';
import 'package:sincro_app_flutter/features/tasks/models/task_model.dart';
import 'package:sincro_app_flutter/features/tasks/presentation/widgets/task_item.dart'; // Import atualizado
import 'package:sincro_app_flutter/models/user_model.dart';
// Import do TaskInputModal ainda é usado para o botão '+' no header
// Numerology engine to compute personal day when needed
import 'package:sincro_app_flutter/services/numerology_engine.dart';

class FocusDayCard extends StatelessWidget {
  final List<TaskModel> tasks;
  final VoidCallback onViewAll;
  final Function(TaskModel task, bool isCompleted) onTaskStatusChanged;
  final UserModel userData;
  // --- INÍCIO DA MUDANÇA ---
  final Function(TaskModel task)? onTaskTap; // Callback para abrir detalhes
  // REMOVIDO: final Function(TaskModel task) onTaskDeleted;
  // REMOVIDO: final Function(TaskModel task) onTaskEdited;
  // REMOVIDO: final Function(TaskModel task) onTaskDuplicated;
  // --- FIM DA MUDANÇA ---
  final VoidCallback onAddTask; // Callback para o botão '+' no header
  final Widget? dragHandle;
  final bool isEditMode;

  const FocusDayCard({
    super.key,
    required this.tasks,
    required this.onViewAll,
    required this.onTaskStatusChanged,
    required this.userData,
    // --- INÍCIO DA MUDANÇA ---
    this.onTaskTap, // Adicionado como opcional
    // REMOVIDO: required this.onTaskDeleted,
    // REMOVIDO: required this.onTaskEdited,
    // REMOVIDO: required this.onTaskDuplicated,
    // --- FIM DA MUDANÇA ---
    required this.onAddTask,
    this.dragHandle,
    this.isEditMode = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBackground.withOpacity(0.8),
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(color: AppColors.border.withOpacity(0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 5),
          )
        ],
      ),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildHeader(context),
                const SizedBox(height: 16),
                _buildTaskList(context), // Passa o context
              ],
            ),
          ),
          if (isEditMode && dragHandle != null)
            Positioned(
              top: 8,
              right: 8,
              child: dragHandle!,
            ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(right: isEditMode ? 32 : 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Ícone e Título
          const Flexible(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_box_outlined,
                    color: AppColors.primary, size: 24),
                SizedBox(width: 12),
                Flexible(
                  child: Text(
                    'Foco do Dia',
                    style: TextStyle(
                      color: AppColors.primaryText,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          // Botões de Ação
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Botão Adicionar Tarefa
              if (!isEditMode)
                IconButton(
                  icon: const Icon(Icons.add_circle_outline,
                      color: AppColors.primary),
                  tooltip: 'Adicionar Tarefa',
                  iconSize: 22,
                  padding: const EdgeInsets.all(4),
                  constraints: const BoxConstraints(),
                  splashRadius: 20,
                  onPressed: onAddTask,
                ),
              // Botão "Ver tudo"
              Padding(
                padding: const EdgeInsets.only(left: 4.0),
                child: TextButton(
                  onPressed: isEditMode ? null : onViewAll,
                  style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 2),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      foregroundColor: AppColors.secondaryText,
                      textStyle: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w500)),
                  child: const Text('Ver tudo'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 24.0),
      child: Center(
        child: Text(
          'Nenhuma tarefa para hoje.\nAdicione novas tarefas ou marcos!',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.secondaryText, height: 1.5),
        ),
      ),
    );
  }

  Widget _buildTaskList(BuildContext context) {
    // Show tasks that belong to TODAY (LOCAL date comparison) and also
    // match today's personal day. Use dueDate when present, otherwise
    // fall back to createdAt. Exclude completed tasks.
    final nowLocal = DateTime.now().toLocal();
    final todayLocal = DateTime(nowLocal.year, nowLocal.month, nowLocal.day);

    // Prepare numerology engine to compute personal day for today and
    // to compute per-task personal day if the task doesn't have it saved.
    final engine = NumerologyEngine(
      nomeCompleto: userData.nomeAnalise,
      dataNascimento: userData.dataNasc,
    );
    final int todayPersonalDay = engine.calculatePersonalDayForDate(todayLocal);

    DateTime? _localDateOnly(DateTime? d) {
      if (d == null) return null;
      final dl = d.toLocal();
      return DateTime(dl.year, dl.month, dl.day);
    }

    final filtered = tasks.where((task) {
      if (task.completed) return false;

      final DateTime? taskDate = task.dueDate ?? task.createdAt;
      final taskDateOnly = _localDateOnly(taskDate);
      if (taskDateOnly == null) return false;

      // Must be the same LOCAL day
      if (!(taskDateOnly.year == todayLocal.year &&
          taskDateOnly.month == todayLocal.month &&
          taskDateOnly.day == todayLocal.day)) {
        return false;
      }

      // Determine the task's personal day (use saved value if present)
      final int taskPersonalDay =
          task.personalDay ?? engine.calculatePersonalDayForDate(taskDateOnly);

      return taskPersonalDay == todayPersonalDay;
    }).toList();

    final tasksToShow = filtered.take(3).toList();

    if (tasksToShow.isEmpty) {
      return _buildEmptyState();
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: tasksToShow.map((task) {
        return TaskItem(
          key: ValueKey(task.id),
          task: task,
          // Flags de exibição (mantidas da correção anterior)
          showGoalIconFlag: true,
          showTagsIconFlag: true,
          showVibrationPillFlag:
              true, // Mostrar pílula no card do dashboard? Sim.
          // Callbacks
          onToggle: (isCompleted) => onTaskStatusChanged(task, isCompleted),
          onTap: onTaskTap != null
              ? () => onTaskTap!(task)
              : null, // Passa o onTap
          // Callbacks de menu removidos
          verticalPaddingOverride: 6.0,
        );
      }).toList(),
    );
  }
}
