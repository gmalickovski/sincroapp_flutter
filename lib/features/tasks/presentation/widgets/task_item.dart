// lib/features/tasks/presentation/widgets/task_item.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:sincro_app_flutter/common/constants/app_colors.dart';
import 'package:sincro_app_flutter/common/utils/string_sanitizer.dart';
import 'package:sincro_app_flutter/common/widgets/vibration_pill.dart';
import 'package:sincro_app_flutter/features/tasks/models/task_model.dart';

class TaskItem extends StatelessWidget {
  final TaskModel task;
  final void Function(bool) onToggle;
  final VoidCallback onDelete;
  final VoidCallback onEdit;
  final VoidCallback onDuplicate;
  final bool showJourney;

  const TaskItem({
    super.key,
    required this.task,
    required this.onToggle,
    required this.onDelete,
    required this.onEdit,
    required this.onDuplicate,
    this.showJourney = true,
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
    // CORRIGIDO: Usa a propriedade 'journeyTitle' do TaskModel atualizado
    final bool hasJourney =
        task.journeyTitle != null && task.journeyTitle!.isNotEmpty;
    final showDateIndicator = _isNotToday(task.dueDate);
    final currentYear = DateTime.now().year;

    final String dateFormat = (task.dueDate?.year ?? currentYear) != currentYear
        ? 'dd/MMM/yy'
        : 'dd/MMM';

    return InkWell(
      onTap: onEdit,
      borderRadius: BorderRadius.circular(8),
      splashColor: AppColors.primary.withOpacity(0.1),
      highlightColor: AppColors.primary.withOpacity(0.1),
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
                  if (showDateIndicator ||
                      task.tags.isNotEmpty ||
                      (showJourney && hasJourney))
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
                      if (showJourney && hasJourney)
                        _IndicatorIcon(
                          icon: Icons.flag_outlined,
                          // CORRIGIDO: Usa 'journeyTitle' e o sanitizador
                          text:
                              '@${StringSanitizer.toSimpleTag(task.journeyTitle!)}',
                          color: AppColors.primary.withOpacity(0.8),
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
              color: const Color(0xFF2a2141),
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
                PopupMenuItem<String>(
                  value: 'delete',
                  child: Row(
                    children: [
                      const Icon(Icons.delete_outline,
                          size: 20, color: Colors.redAccent),
                      const SizedBox(width: 12),
                      Text('Excluir Tarefa',
                          style: TextStyle(color: Colors.redAccent.shade100)),
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
