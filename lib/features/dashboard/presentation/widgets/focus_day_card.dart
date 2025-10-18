// lib/features/dashboard/presentation/widgets/focus_day_card.dart

import 'package:flutter/material.dart';
import 'package:sincro_app_flutter/common/constants/app_colors.dart';
import 'package:sincro_app_flutter/features/tasks/models/task_model.dart';
import 'package:sincro_app_flutter/features/tasks/presentation/widgets/task_item.dart';
import 'package:sincro_app_flutter/models/user_model.dart';
import 'package:sincro_app_flutter/features/tasks/presentation/widgets/task_input_modal.dart';

class FocusDayCard extends StatelessWidget {
  final List<TaskModel> tasks;
  final VoidCallback onViewAll;
  final Function(TaskModel task, bool isCompleted) onTaskStatusChanged;
  final UserModel userData;
  final Function(TaskModel task) onTaskDeleted;
  final Function(TaskModel task) onTaskEdited;
  final Function(TaskModel task) onTaskDuplicated;
  final Widget? dragHandle;
  final bool isEditMode;

  const FocusDayCard({
    super.key,
    required this.tasks,
    required this.onViewAll,
    required this.onTaskStatusChanged,
    required this.userData,
    required this.onTaskDeleted,
    required this.onTaskEdited,
    required this.onTaskDuplicated,
    this.dragHandle,
    this.isEditMode = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(color: AppColors.border),
      ),
      // *** CORREÇÃO: Envolve com Stack ***
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                const SizedBox(height: 16),
                tasks.isEmpty ? _buildEmptyState() : _buildTaskList(context),
              ],
            ),
          ),
          // *** CORREÇÃO: Posiciona o dragHandle no canto superior direito ***
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

  Widget _buildHeader() {
    // *** CORREÇÃO: Remove o dragHandle daqui ***
    return Container(
      // Adiciona padding direito para o texto não ficar embaixo do handle posicionado
      padding: EdgeInsets.only(right: isEditMode ? 32 : 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Flexible(
            // Para o título não estourar
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisSize: MainAxisSize.min, // Ocupa espaço mínimo
              children: [
                Icon(Icons.check_box_outlined,
                    color: AppColors.primary, size: 20),
                SizedBox(width: 8),
                Flexible(
                  // Para o texto
                  child: Text(
                    'Foco do Dia',
                    style: TextStyle(
                      color: AppColors.primaryText,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 8.0), // Garante espaço
            child: TextButton(
              // Desativa o botão se estiver editando, para evitar clique acidental
              onPressed: isEditMode ? null : onViewAll,
              child: const Text('Ver tudo'),
            ),
          ),
        ],
      ),
    );
  }

  // --- O restante do código (_buildEmptyState, _buildTaskList) permanece o mesmo ---
  Widget _buildEmptyState() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 24.0),
      child: Center(
        child: Text(
          'Nenhuma tarefa para hoje.\nAdicione novas metas e marcos!',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.secondaryText),
        ),
      ),
    );
  }

  Widget _buildTaskList(BuildContext context) {
    return Column(
      children: tasks.map((task) {
        return TaskItem(
          task: task,
          showJourney: false,
          isCompact: true, // Continua usando o modo compacto
          onToggle: (isCompleted) => onTaskStatusChanged(task, isCompleted),
          onEdit: () => onTaskEdited(task),
          onDelete: () => onTaskDeleted(task),
          onDuplicate: () => onTaskDuplicated(task),
        );
      }).toList(),
    );
  }
}
