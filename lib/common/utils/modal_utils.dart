// Exemplo (coloque em um local apropriado, como lib/common/utils/modal_utils.dart)
import 'package:flutter/material.dart';
import 'package:sincro_app_flutter/features/tasks/models/task_model.dart';
import 'package:sincro_app_flutter/features/tasks/presentation/widgets/task_detail_modal.dart';
import 'package:sincro_app_flutter/models/user_model.dart';

void showTaskDetailModal(
    BuildContext context, TaskModel task, UserModel userData) {
  showDialog(
    context: context,
    // barrierDismissible: true, // Permite fechar clicando fora (opcional)
    builder: (BuildContext dialogContext) {
      return TaskDetailModal(
        task: task,
        userData: userData,
      );
    },
  );
}
