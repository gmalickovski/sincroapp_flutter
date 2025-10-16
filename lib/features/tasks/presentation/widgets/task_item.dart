// lib/features/tasks/presentation/widgets/task_item.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:sincro_app_flutter/common/constants/app_colors.dart';
import 'package:sincro_app_flutter/common/widgets/vibration_pill.dart';
import 'package:sincro_app_flutter/features/tasks/models/task_model.dart';

class TaskItem extends StatelessWidget {
  final TaskModel task;
  final void Function(bool) onToggle;
  final VoidCallback onDelete;
  final VoidCallback onEdit;
  final VoidCallback onDuplicate;

  const TaskItem({
    super.key,
    required this.task,
    required this.onToggle,
    required this.onDelete,
    required this.onEdit,
    required this.onDuplicate,
  });

  bool _isNotToday(DateTime? date) {
    if (date == null) return false;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final targetDate = DateTime(date.year, date.month, date.day);
    return !today.isAtSameMomentAs(targetDate);
  }

  @override
  Widget build(BuildContext context) {
    final showDateIndicator = _isNotToday(task.dueDate);
    final currentYear = DateTime.now().year;

    final String dateFormat = (task.dueDate?.year ?? currentYear) != currentYear
        ? 'dd/MMM/yy'
        : 'dd/MMM';

    return InkWell(
      onTap: () {},
      borderRadius: BorderRadius.circular(8),
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: () => onToggle(!task.completed),
              child: Container(
                padding: const EdgeInsets.fromLTRB(4, 6, 4, 4),
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: task.completed
                        ? Colors.green.shade500
                        : Colors.transparent,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: task.completed
                          ? Colors.green.shade500
                          : AppColors.tertiaryText,
                      width: 2,
                    ),
                  ),
                  child: task.completed
                      ? const Icon(Icons.check, size: 14, color: Colors.white)
                      : null,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            task.text,
                            style: TextStyle(
                              color: task.completed
                                  ? AppColors.tertiaryText
                                  : AppColors.secondaryText,
                              decoration: task.completed
                                  ? TextDecoration.lineThrough
                                  : TextDecoration.none,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        if (task.personalDay != null && task.personalDay! > 0)
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 8.0),
                            child: VibrationPill(
                              vibrationNumber: task.personalDay!,
                              type: VibrationPillType.compact,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (showDateIndicator || task.tags.isNotEmpty)
                    const SizedBox(height: 4),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (showDateIndicator)
                        _IndicatorIcon(
                          icon: Icons.calendar_today_outlined,
                          text: DateFormat(dateFormat, 'pt_BR')
                              .format(task.dueDate!),
                          color: AppColors.tertiaryText,
                        ),
                      ...task.tags.map((tag) => _TagChip(tag: tag)).toList(),
                    ],
                  )
                ],
              ),
            ),
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'edit') {
                  onEdit();
                } else if (value == 'delete') {
                  onDelete();
                } else if (value == 'duplicate') {
                  onDuplicate();
                }
              },
              // ATUALIZAÇÃO DE UI/UX: Cor do menu ajustada.
              color: const Color(0xFF2a2141), // Um roxo escuro, mais sutil
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
              icon: const Icon(Icons.more_vert, color: AppColors.tertiaryText),
              itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                const PopupMenuItem<String>(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit_outlined,
                          size: 20, color: AppColors.secondaryText),
                      SizedBox(width: 12),
                      Text('Editar Tarefa'),
                    ],
                  ),
                ),
                const PopupMenuItem<String>(
                  value: 'duplicate',
                  child: Row(
                    children: [
                      Icon(Icons.copy_outlined,
                          size: 20, color: AppColors.secondaryText),
                      SizedBox(width: 12),
                      Text('Duplicar Tarefa'),
                    ],
                  ),
                ),
                const PopupMenuDivider(),
                const PopupMenuItem<String>(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline,
                          size: 20, color: Colors.redAccent),
                      SizedBox(width: 12),
                      Text('Excluir Tarefa',
                          style: TextStyle(color: Colors.redAccent)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// Widgets auxiliares (sem alterações)
class _IndicatorIcon extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;
  const _IndicatorIcon(
      {required this.icon, required this.text, required this.color});
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 14),
        const SizedBox(width: 4),
        Text(text,
            style: TextStyle(
                color: color, fontSize: 12, fontWeight: FontWeight.w500)),
      ],
    );
  }
}

class _TagChip extends StatelessWidget {
  final String tag;
  const _TagChip({required this.tag});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.purple.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text('#$tag',
          style: TextStyle(
              color: Colors.purple.shade200,
              fontSize: 12,
              fontWeight: FontWeight.w500)),
    );
  }
}
