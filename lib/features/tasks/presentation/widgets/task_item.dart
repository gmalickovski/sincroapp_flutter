import 'package:flutter/material.dart';
import 'package:sincro_app_flutter/common/constants/app_colors.dart';
import 'package:sincro_app_flutter/features/tasks/models/task_model.dart';

class TaskItem extends StatelessWidget {
  final TaskModel task;
  final void Function(bool) onToggle; // Tipo corrigido para maior clareza
  final VoidCallback onDelete;

  const TaskItem({
    super.key,
    required this.task,
    required this.onToggle, // Propriedade agora corresponde à chamada
    required this.onDelete, // Propriedade agora corresponde à chamada
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onToggle(!task.completed),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: () => onToggle(!task.completed),
              child: Container(
                margin: const EdgeInsets.only(top: 2),
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
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
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
                  if (task.tags.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: task.tags
                            .map((tag) => Chip(
                                  label: Text('#$tag'),
                                  labelStyle: TextStyle(
                                      color: Colors.blue.shade200,
                                      fontSize: 12),
                                  backgroundColor: Colors.blue.withOpacity(0.2),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 4, vertical: 0),
                                  side: BorderSide.none,
                                ))
                            .toList(),
                      ),
                    ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline,
                  color: AppColors.tertiaryText, size: 20),
              onPressed: onDelete,
              splashRadius: 20,
            ),
          ],
        ),
      ),
    );
  }
}
