// lib/features/goals/presentation/widgets/milestone_list_item.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:sincro_app_flutter/common/constants/app_colors.dart';
import 'package:sincro_app_flutter/features/tasks/models/task_model.dart';

class MilestoneListItem extends StatelessWidget {
  final TaskModel milestone;
  final Function(bool) onStatusChanged;
  final VoidCallback onDelete;
  // *** CORREÇÃO: Adiciona o parâmetro que faltava ***
  final VoidCallback onEdit;

  const MilestoneListItem({
    super.key,
    required this.milestone,
    required this.onStatusChanged,
    required this.onDelete,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      leading: Checkbox(
        value: milestone.completed,
        onChanged: (value) {
          if (value != null) {
            onStatusChanged(value);
          }
        },
        activeColor: AppColors.primary,
        checkColor: Colors.black,
        side: BorderSide(color: AppColors.secondaryText, width: 2),
      ),
      title: Text(
        milestone.text,
        style: TextStyle(
          color: milestone.completed
              ? AppColors.tertiaryText
              : AppColors.primaryText,
          decoration: milestone.completed
              ? TextDecoration.lineThrough
              : TextDecoration.none,
        ),
      ),
      subtitle: milestone.dueDate != null
          ? Text(
              DateFormat('dd/MM/yyyy').format(milestone.dueDate!),
              style:
                  const TextStyle(color: AppColors.tertiaryText, fontSize: 12),
            )
          : null,
      trailing: PopupMenuButton<String>(
        onSelected: (value) {
          if (value == 'edit') {
            onEdit();
          } else if (value == 'delete') {
            onDelete();
          }
        },
        icon: const Icon(Icons.more_vert, color: AppColors.secondaryText),
        color: AppColors.cardBackground,
        itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
          const PopupMenuItem<String>(
            value: 'edit',
            child: Text('Editar', style: TextStyle(color: Colors.white)),
          ),
          PopupMenuItem<String>(
            value: 'delete',
            child:
                Text('Excluir', style: TextStyle(color: Colors.red.shade400)),
          ),
        ],
      ),
    );
  }
}
