// lib/features/dashboard/presentation/widgets/focus_day_card.dart

import 'package:flutter/material.dart';
import 'package:sincro_app_flutter/common/constants/app_colors.dart';
import 'package:sincro_app_flutter/features/tasks/models/task_model.dart';
import 'package:sincro_app_flutter/features/tasks/presentation/widgets/task_item.dart';
import 'package:sincro_app_flutter/models/user_model.dart';
import 'package:sincro_app_flutter/services/numerology_engine.dart';

class FocusDayCard extends StatefulWidget {
  final List<TaskModel> tasks;
  final VoidCallback onViewAll;
  final Function(TaskModel task, bool isCompleted) onTaskStatusChanged;
  final UserModel userData;
  final Function(TaskModel task)? onTaskTap;
  final VoidCallback onAddTask;
  final Widget? dragHandle;
  final bool isEditMode;

  const FocusDayCard({
    super.key,
    required this.tasks,
    required this.onViewAll,
    required this.onTaskStatusChanged,
    required this.userData,
    this.onTaskTap,
    required this.onAddTask,
    this.dragHandle,
    this.isEditMode = false,
    // Callbacks de Swipe
    this.onDeleteTask,
    this.onRescheduleTask,
  });

  final Future<bool?> Function(TaskModel)? onDeleteTask;
  final Future<bool?> Function(TaskModel)? onRescheduleTask;

  @override
  State<FocusDayCard> createState() => _FocusDayCardState();
}

class _FocusDayCardState extends State<FocusDayCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final Color borderColor = _isHovered
        ? AppColors.primary.withValues(alpha: 0.8)
        : AppColors.border.withValues(alpha: 0.7);
    final double borderWidth = _isHovered ? 1.5 : 1.0;

    // --- Lógica de Filtro Movida para o Build ---
    final nowLocal = DateTime.now().toLocal();
    final todayLocal = DateTime(nowLocal.year, nowLocal.month, nowLocal.day);

    final engine = NumerologyEngine(
      nomeCompleto: widget.userData.nomeAnalise,
      dataNascimento: widget.userData.dataNasc,
    );
    final int todayPersonalDay = engine.calculatePersonalDayForDate(todayLocal);

    DateTime? localDateOnly(DateTime? d) {
      if (d == null) return null;
      final dl = d.toLocal();
      return DateTime(dl.year, dl.month, dl.day);
    }

    // Filtra TODAS as tarefas do Foco do Dia (concluídas ou não)
    final allFocusDayTasks = widget.tasks.where((task) {
      final DateTime taskDate = task.dueDate ?? task.createdAt;
      final taskDateOnly = localDateOnly(taskDate);
      if (taskDateOnly == null) return false;

      if (!(taskDateOnly.year == todayLocal.year &&
          taskDateOnly.month == todayLocal.month &&
          taskDateOnly.day == todayLocal.day)) {
        return false;
      }

      final int taskPersonalDay =
          task.personalDay ?? engine.calculatePersonalDayForDate(taskDateOnly);

      return taskPersonalDay == todayPersonalDay;
    }).toList();

    final int totalTasks = allFocusDayTasks.length;
    final int completedTasks =
        allFocusDayTasks.where((t) => t.completed).length;

    // Para a lista visual, mostramos apenas as não concluídas (ou todas, se preferir, mas o padrão era não-concluídas)
    // O pedido não especificou mudar a lógica da lista, apenas mover botões.
    // Mas geralmente "Foco do Dia" mostra o que falta fazer.
    // Vou manter a lógica de exibir as pendentes para a lista principal.
    final tasksToDisplay =
        allFocusDayTasks.where((t) => !t.completed).take(3).toList();

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: AppColors.cardBackground.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(16.0),
          border: Border.all(color: borderColor, width: borderWidth),
          boxShadow: _isHovered
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.05),
                    blurRadius: 8,
                  )
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  )
                ],
        ),
        child: Stack(
          children: [
            Padding(
              // Reduced bottom padding to bring footer buttons closer to edge
              padding: const EdgeInsets.fromLTRB(20.0, 20.0, 20.0, 12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildHeader(context, completedTasks, totalTasks),
                  const SizedBox(height: 16),
                  tasksToDisplay.isEmpty
                      ? _buildEmptyState()
                      : _buildTaskList(context, tasksToDisplay),
                  const SizedBox(height: 16),
                  // --- Novo Footer com Botões ---
                  _buildFooter(context),
                ],
              ),
            ),
            if (widget.isEditMode && widget.dragHandle != null)
              Positioned(
                top: 8,
                right: 8,
                child: widget.dragHandle!,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, int completed, int total) {
    return Container(
      padding: EdgeInsets.only(right: widget.isEditMode ? 32 : 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
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
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          // --- Contador no Header ---
          Text(
            '$completed/$total',
            style: const TextStyle(
              color: AppColors.secondaryText,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
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
          'Nenhuma tarefa pendente.\nAdicione novas tarefas ou marcos!',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.secondaryText, height: 1.5),
        ),
      ),
    );
  }

  Widget _buildTaskList(BuildContext context, List<TaskModel> tasks) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: tasks.map((task) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: TaskItem(
            key: ValueKey(task.id),
            task: task,
            showGoalIconFlag: true,
            showTagsIconFlag: true,
            showVibrationPillFlag: true,
            onToggle: (isCompleted) =>
                widget.onTaskStatusChanged(task, isCompleted),
            onTap:
                widget.onTaskTap != null ? () => widget.onTaskTap!(task) : null,
            verticalPaddingOverride: 6.0,
            // Callbacks de Swipe
            onSwipeLeft: widget.onDeleteTask,
            onSwipeRight: widget.onRescheduleTask,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildFooter(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (!widget.isEditMode)
           IconButton(
             onPressed: widget.onAddTask,
             icon: const Icon(Icons.add_circle_outline, color: AppColors.primary),
             tooltip: 'Adicionar Tarefa',
             padding: EdgeInsets.zero,
             constraints: const BoxConstraints(),
           ),
        const SizedBox(width: 12), // Espaço entre os botões
        TextButton(
          onPressed: widget.isEditMode ? null : widget.onViewAll,
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            foregroundColor: AppColors.secondaryText,
            textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          ),
          child: const Text('Ver tudo'),
        ),
      ],
    );
  }
}
