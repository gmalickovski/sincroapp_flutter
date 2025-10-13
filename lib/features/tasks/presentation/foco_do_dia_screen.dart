import 'package:flutter/material.dart';
import 'package:sincro_app_flutter/common/constants/app_colors.dart';
import 'package:sincro_app_flutter/common/widgets/custom_loading_spinner.dart';
import 'package:sincro_app_flutter/features/authentication/data/auth_repository.dart';
import 'package:sincro_app_flutter/features/tasks/models/task_model.dart';
import 'package:sincro_app_flutter/models/user_model.dart';
import 'package:sincro_app_flutter/services/firestore_service.dart';
import 'package:sincro_app_flutter/services/numerology_engine.dart';
import 'widgets/task_item.dart';
import 'widgets/task_input_modal.dart';
import 'package:sincro_app_flutter/features/tasks/utils/task_parser.dart';

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
      builder: (context) {
        return TaskInputModal(
          userData: widget.userData,
          onAddTask: (parsedTask, dueDate) {
            final dateForVibration = dueDate;
            final engine = NumerologyEngine(
              nomeCompleto: widget.userData!.nomeAnalise,
              dataNascimento: widget.userData!.dataNasc,
            );
            final personalDay =
                engine.calculatePersonalDayForDate(dateForVibration);
            final newTask = TaskModel(
              id: '',
              text: parsedTask.cleanText,
              completed: false,
              createdAt: DateTime.now(),
              dueDate: dueDate,
              tags: parsedTask.tags,
              personalDay: personalDay,
            );
            _firestoreService.addTask(_userId, newTask);
          },
        );
      },
    );
  }

  void _openEditTaskModal(TaskModel taskToEdit) {
    // No futuro, esta função abrirá o TaskInputModal com os dados da tarefa
    print("Abrindo modal para editar a tarefa: ${taskToEdit.text}");
    // Implementaremos a lógica completa na próxima etapa.
  }

  void _duplicateTask(TaskModel originalTask) {
    final duplicatedTask = TaskModel(
      id: '', // O ID será gerado pelo Firestore
      text: originalTask.text,
      completed: false, // A cópia começa como não concluída
      createdAt: DateTime.now(), // Nova data de criação
      dueDate: originalTask.dueDate, // Mantém a mesma data de vencimento
      tags: originalTask.tags,
      personalDay: originalTask.personalDay,
      journeyId: originalTask.journeyId,
    );
    _firestoreService.addTask(_userId, duplicatedTask);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                Expanded(
                  child: StreamBuilder<List<TaskModel>>(
                    stream: _firestoreService.getTasksStream(_userId,
                        todayOnly: _showTodayTasks),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting &&
                          !snapshot.hasData) {
                        return const Center(child: CustomLoadingSpinner());
                      }
                      if (!snapshot.hasData || snapshot.data!.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.check_circle_outline,
                                  color: AppColors.tertiaryText, size: 48),
                              const SizedBox(height: 16),
                              const Text('Tudo limpo por aqui!',
                                  style: TextStyle(
                                      color: AppColors.secondaryText,
                                      fontSize: 18)),
                              const SizedBox(height: 8),
                              Text(
                                _showTodayTasks
                                    ? 'Você não tem tarefas para hoje.'
                                    : 'Seu histórico de tarefas está vazio.',
                                style: const TextStyle(
                                    color: AppColors.tertiaryText),
                              ),
                            ],
                          ),
                        );
                      }
                      final tasks = snapshot.data!;
                      return ListView.builder(
                        padding: const EdgeInsets.only(top: 8, bottom: 80),
                        itemCount: tasks.length,
                        itemBuilder: (context, index) {
                          final task = tasks[index];
                          return TaskItem(
                            task: task,
                            onToggle: (completed) {
                              _firestoreService.updateTask(_userId, task.id,
                                  completed: completed);
                            },
                            onDelete: () {
                              _firestoreService.deleteTask(_userId, task.id);
                            },
                            onEdit: () => _openEditTaskModal(task),
                            onDuplicate: () => _duplicateTask(task),
                          );
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
      floatingActionButton: FloatingActionButton(
        onPressed: widget.userData != null ? _openAddTaskModal : null,
        backgroundColor:
            widget.userData != null ? AppColors.primary : Colors.grey,
        tooltip: 'Adicionar Tarefa',
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 40),
        const Text('Tarefas',
            style: TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 24),
        Row(
          children: [
            FilterChip(
              label: const Text('Foco do Dia'),
              selected: _showTodayTasks,
              onSelected: (selected) => setState(() => _showTodayTasks = true),
              backgroundColor: AppColors.cardBackground,
              selectedColor: AppColors.primary,
              labelStyle: TextStyle(
                  color:
                      _showTodayTasks ? Colors.white : AppColors.secondaryText,
                  fontWeight: FontWeight.bold),
              showCheckmark: false,
              side: BorderSide.none,
            ),
            const SizedBox(width: 8),
            FilterChip(
              label: const Text('Todas'),
              selected: !_showTodayTasks,
              onSelected: (selected) => setState(() => _showTodayTasks = false),
              backgroundColor: AppColors.cardBackground,
              selectedColor: AppColors.primary,
              labelStyle: TextStyle(
                  color:
                      !_showTodayTasks ? Colors.white : AppColors.secondaryText,
                  fontWeight: FontWeight.bold),
              showCheckmark: false,
              side: BorderSide.none,
            ),
          ],
        ),
        const SizedBox(height: 16),
        const Divider(color: AppColors.border, height: 1),
      ],
    );
  }
}
