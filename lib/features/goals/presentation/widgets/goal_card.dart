import 'package:flutter/material.dart';
import 'package:sincro_app_flutter/common/constants/app_colors.dart';
import 'package:sincro_app_flutter/services/firestore_service.dart';
import 'package:sincro_app_flutter/features/tasks/models/task_model.dart';
import 'package:sincro_app_flutter/features/goals/models/goal_model.dart';

// CONVERTIDO PARA STATEFULWIDGET para gerenciar o estado de hover
class GoalCard extends StatefulWidget {
  final Goal goal;
  final String userId; // usado para calcular progresso igual ao GoalDetail
  final VoidCallback onTap;
  final VoidCallback? onDelete;
  final VoidCallback? onEdit;

  const GoalCard({
    super.key,
    required this.goal,
    required this.onTap,
    required this.userId,
    this.onDelete,
    this.onEdit,
  });

  @override
  State<GoalCard> createState() => _GoalCardState();
}

class _GoalCardState extends State<GoalCard> {
  bool _isHovered = false; // Estado para controlar o hover

  @override
  Widget build(BuildContext context) {
    final firestore = FirestoreService();

    // *** LÓGICA DA BORDA DE HOVER ***
    final Color borderColor;
    final double borderWidth;

    if (_isHovered) {
      borderColor = AppColors.primary.withValues(alpha: 0.8);
      borderWidth = 1.5;
    } else {
      borderColor = AppColors.border.withValues(alpha: 0.7);
      borderWidth = 1.0;
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: borderColor,
            width: borderWidth,
          ),
          boxShadow: _isHovered
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  )
                ]
              : [],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(16),
            splashColor: AppColors.primary.withValues(alpha: 0.1),
            highlightColor: AppColors.primary.withValues(alpha: 0.1),
            hoverColor: Colors.transparent,
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: StreamBuilder<List<TaskModel>>(
                stream: widget.userId.isNotEmpty
                    ? firestore.getTasksForGoalStream(
                        widget.userId, widget.goal.id)
                    : null,
                builder: (context, snapshot) {
                  final tasks = snapshot.data ?? const <TaskModel>[];
                  final int total = tasks.isNotEmpty
                      ? tasks.length
                      : widget.goal.subTasks.length;
                  final int done = tasks.isNotEmpty
                      ? tasks.where((t) => t.completed).length
                      : widget.goal.subTasks.where((t) => t.isCompleted).length;
                  final double percent = total > 0
                      ? (done / total).clamp(0.0, 1.0)
                      : (widget.goal.progress / 100).clamp(0.0, 1.0);

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header: Title + Menu
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.goal.title,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                if (widget.goal.description.isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    widget.goal.description,
                                    style: const TextStyle(
                                      color: AppColors.secondaryText,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          if (widget.onDelete != null || widget.onEdit != null)
                            PopupMenuButton<String>(
                              icon: const Icon(
                                Icons.more_vert,
                                color: AppColors.secondaryText,
                                size: 20,
                              ),
                              tooltip: 'Opções',
                              color: AppColors.cardBackground,
                              position: PopupMenuPosition.under,
                              itemBuilder: (context) {
                                final items = <PopupMenuEntry<String>>[];
                                if (widget.onEdit != null) {
                                  items.add(const PopupMenuItem<String>(
                                    value: 'edit',
                                    child: Row(
                                      children: [
                                        Icon(Icons.edit_outlined,
                                            color: Colors.white, size: 18),
                                        SizedBox(width: 8),
                                        Text('Editar',
                                            style:
                                                TextStyle(color: Colors.white)),
                                      ],
                                    ),
                                  ));
                                }
                                if (widget.onDelete != null) {
                                  items.add(const PopupMenuItem<String>(
                                    value: 'delete',
                                    child: Row(
                                      children: [
                                        Icon(Icons.delete_outline,
                                            color: Colors.redAccent, size: 18),
                                        SizedBox(width: 8),
                                        Text('Excluir',
                                            style:
                                                TextStyle(color: Colors.white)),
                                      ],
                                    ),
                                  ));
                                }
                                return items;
                              },
                              onSelected: (value) {
                                if (value == 'edit' && widget.onEdit != null) {
                                  widget.onEdit!();
                                } else if (value == 'delete' &&
                                    widget.onDelete != null) {
                                  widget.onDelete!();
                                }
                              },
                            ),
                        ],
                      ),
                      
                      const SizedBox(height: 24),

                      // Footer: Date + Percent + Progress Bar
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          if (widget.goal.targetDate != null)
                            _buildDateBadge(widget.goal.targetDate!)
                          else
                            const SizedBox(),
                          Text(
                            '${(percent * 100).round()}%',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: percent,
                          backgroundColor: AppColors.border.withValues(alpha: 0.3),
                          color: AppColors.primary,
                          minHeight: 6,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDateBadge(DateTime date) {
    final months = [
      'Jan', 'Fev', 'Mar', 'Abr', 'Mai', 'Jun',
      'Jul', 'Ago', 'Set', 'Out', 'Nov', 'Dez'
    ];
    final formattedDate =
        '${date.day.toString().padLeft(2, '0')} ${months[date.month - 1]} ${date.year}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.calendar_today_outlined,
              color: AppColors.primary, size: 12),
          const SizedBox(width: 6),
          Text(
            formattedDate,
            style: const TextStyle(
              color: AppColors.primary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
