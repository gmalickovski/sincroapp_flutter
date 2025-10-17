// lib/features/tasks/presentation/foco_do_dia_screen.dart
import 'package:flutter/material.dart';
import 'package:sincro_app_flutter/common/constants/app_colors.dart';
import 'package:sincro_app_flutter/common/widgets/custom_loading_spinner.dart';
import 'package:sincro_app_flutter/features/authentication/data/auth_repository.dart';
import 'package:sincro_app_flutter/features/tasks/models/task_model.dart';
import 'package:sincro_app_flutter/models/user_model.dart';
import 'package:sincro_app_flutter/services/firestore_service.dart';
import 'package:sincro_app_flutter/features/tasks/presentation/widgets/tasks_list_view.dart';
import 'widgets/task_input_modal.dart';

class FocoDoDiaScreen extends StatefulWidget {
  final UserModel? userData;
  const FocoDoDiaScreen({super.key, required this.userData});
  @override
  State<FocoDoDiaScreen> createState() => _FocoDoDiaScreenState();
}

class _FocoDoDiaScreenState extends State<FocoDoDiaScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final String _userId = AuthRepository().getCurrentUser()!.uid;
  bool _showTodayTasks = true;

  void _openAddTaskModal() {
    if (widget.userData == null) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => TaskInputModal(
        userData: widget.userData,
      ),
    );
  }

  void _openEditTaskModal(TaskModel taskToEdit) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => TaskInputModal(
        userData: widget.userData,
        taskToEdit: taskToEdit,
      ),
    );
  }

  void _duplicateTask(TaskModel originalTask) {
    final duplicatedTask = originalTask.copyWith(
      id: '',
      completed: false,
      createdAt: DateTime.now(),
    );
    _firestoreService.addTask(_userId, duplicatedTask);
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final bool isMobile = screenWidth < 600;

    return Scaffold(
      backgroundColor: AppColors.background,
      // *** ADICIONADO SAFEAREA PARA GERENCIAR ESPAÇO SUPERIOR AUTOMATICAMENTE ***
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Padding(
              // *** PADDING HORIZONTAL REDUZIDO PARA APROXIMAR DAS BORDAS ***
              padding: EdgeInsets.symmetric(horizontal: isMobile ? 12.0 : 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(isMobile: isMobile),
                  Expanded(
                    child: StreamBuilder<List<TaskModel>>(
                      stream: _firestoreService.getTasksStream(_userId),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                                ConnectionState.waiting &&
                            !snapshot.hasData) {
                          return const Center(child: CustomLoadingSpinner());
                        }
                        if (snapshot.hasError) {
                          return Center(child: Text('Erro: ${snapshot.error}'));
                        }

                        final allTasks = snapshot.data ?? [];

                        final List<TaskModel> filteredTasks;
                        if (_showTodayTasks) {
                          final now = DateTime.now();
                          final todayStart =
                              DateTime(now.year, now.month, now.day);
                          filteredTasks = allTasks.where((task) {
                            if (task.dueDate == null) return true;
                            return task.dueDate!.isAtSameMomentAs(todayStart) ||
                                (task.dueDate!.isAfter(todayStart) &&
                                    task.dueDate!.isBefore(todayStart
                                        .add(const Duration(days: 1))));
                          }).toList();
                        } else {
                          filteredTasks = allTasks;
                        }

                        return TasksListView(
                          tasks: filteredTasks,
                          userData: widget.userData,
                          showJourney: true,
                          emptyListMessage: 'Tudo limpo por aqui!',
                          emptyListSubMessage: _showTodayTasks
                              ? 'Você não tem tarefas para hoje.'
                              : 'Seu histórico de tarefas está vazio.',
                          onToggle: (task, isCompleted) {
                            _firestoreService.updateTaskCompletion(
                              _userId,
                              task.id,
                              completed: isCompleted,
                            );
                          },
                          onTaskDeleted: (task) {
                            _firestoreService.deleteTask(_userId, task.id);
                          },
                          onTaskEdited: (task) {
                            _openEditTaskModal(task);
                          },
                          onTaskDuplicated: (task) {
                            _duplicateTask(task);
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: widget.userData != null ? _openAddTaskModal : null,
        backgroundColor:
            widget.userData != null ? AppColors.primary : Colors.grey,
        tooltip: 'Adicionar Tarefa',
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildHeader({required bool isMobile}) {
    final double titleFontSize = isMobile ? 28 : 32;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // *** ESPAÇAMENTO SUPERIOR REDUZIDO APÓS USO DO SAFEAREA ***
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text('Tarefas',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: titleFontSize,
                    fontWeight: FontWeight.bold)),
            Row(
              children: [
                FilterChip(
                  label: const Text('Foco do Dia'),
                  selected: _showTodayTasks,
                  onSelected: (selected) =>
                      setState(() => _showTodayTasks = true),
                  backgroundColor: AppColors.cardBackground,
                  selectedColor: AppColors.primary,
                  labelStyle: TextStyle(
                      color: _showTodayTasks
                          ? Colors.white
                          : AppColors.secondaryText,
                      fontWeight: FontWeight.bold),
                  showCheckmark: false,
                  side: BorderSide.none,
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('Todas'),
                  selected: !_showTodayTasks,
                  onSelected: (selected) =>
                      setState(() => _showTodayTasks = false),
                  backgroundColor: AppColors.cardBackground,
                  selectedColor: AppColors.primary,
                  labelStyle: TextStyle(
                      color: !_showTodayTasks
                          ? Colors.white
                          : AppColors.secondaryText,
                      fontWeight: FontWeight.bold),
                  showCheckmark: false,
                  side: BorderSide.none,
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),
        const Divider(),
      ],
    );
  }
}
