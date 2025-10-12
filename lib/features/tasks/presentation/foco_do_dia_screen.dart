// ... (mantenha as importações como estão)

import 'package:flutter/material.dart';
import 'package:sincro_app_flutter/common/constants/app_colors.dart';
import 'package:sincro_app_flutter/common/widgets/custom_loading_spinner.dart';
import 'package:sincro_app_flutter/features/authentication/data/auth_repository.dart';
import 'package:sincro_app_flutter/features/tasks/models/task_model.dart';
import 'package:sincro_app_flutter/models/user_model.dart';
import 'package:sincro_app_flutter/services/firestore_service.dart';
import 'widgets/task_item.dart';
import 'widgets/task_input_modal.dart';

class FocoDoDiaScreen extends StatefulWidget {
  const FocoDoDiaScreen({super.key});

  @override
  State<FocoDoDiaScreen> createState() => _FocoDoDiaScreenState();
}

class _FocoDoDiaScreenState extends State<FocoDoDiaScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final String _userId = AuthRepository().getCurrentUser()!.uid;
  bool _showTodayTasks = true;
  UserModel? _userData;

  @override
  void initState() {
    super.initState();
    _firestoreService.getUserData(_userId).then((user) {
      if (mounted) {
        setState(() => _userData = user);
      }
    });
  }

  void _openAddTaskModal() {
    if (_userData == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return TaskInputModal(
          userData: _userData,
          onAddTask: (text) {
            // No futuro, aqui faremos o parse do texto para extrair #, @ e /
            final newTask = TaskModel(
              id: '',
              text: text,
              completed: false,
              createdAt: DateTime.now(),
              dueDate: DateTime.now(),
            );
            _firestoreService.addTask(_userId, newTask);
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // ... (o resto do build da FocoDoDiaScreen permanece o mesmo)
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
                        return const Center(
                          child: Text(
                            'Nenhuma tarefa para o filtro selecionado.',
                            style: TextStyle(color: AppColors.tertiaryText),
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
        onPressed: _userData != null ? _openAddTaskModal : null,
        backgroundColor: _userData != null ? AppColors.primary : Colors.grey,
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
        const Text(
          'Tarefas',
          style: TextStyle(
            color: Colors.white,
            fontSize: 32,
            fontWeight: FontWeight.bold,
          ),
        ),
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
