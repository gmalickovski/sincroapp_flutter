// Exemplo (coloque em um local apropriado, como lib/common/utils/modal_utils.dart)
import 'package:flutter/material.dart';
import 'package:sincro_app_flutter/features/tasks/models/task_model.dart';
import 'package:sincro_app_flutter/features/tasks/presentation/widgets/task_detail_modal.dart';
import 'package:sincro_app_flutter/models/user_model.dart';

// import 'package:sincro_app_flutter/common/widgets/responsive_widget.dart';

void showTaskDetailModal(
    BuildContext context, TaskModel task, UserModel userData) {
  if (MediaQuery.of(context).size.width < 600) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (BuildContext dialogContext) {
        return TaskDetailModal(
          task: task,
          userData: userData,
        );
      },
    );
  } else {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return TaskDetailModal(
          task: task,
          userData: userData,
        );
      },
    );
  }
}
