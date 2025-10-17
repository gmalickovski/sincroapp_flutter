// lib/features/goals/presentation/goal_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:sincro_app_flutter/common/constants/app_colors.dart';
import 'package:sincro_app_flutter/common/widgets/custom_loading_spinner.dart';
import 'package:sincro_app_flutter/features/goals/models/goal_model.dart';
import 'package:sincro_app_flutter/features/tasks/models/task_model.dart';
import 'package:sincro_app_flutter/features/tasks/presentation/widgets/task_input_modal.dart';
import 'package:sincro_app_flutter/features/tasks/presentation/widgets/task_item.dart';
import 'package:sincro_app_flutter/models/user_model.dart';
import 'package:sincro_app_flutter/services/firestore_service.dart';

class GoalDetailScreen extends StatefulWidget {
  final Goal initialGoal;
  final UserModel userData;

  const GoalDetailScreen({
    super.key,
    required this.initialGoal,
    required this.userData,
  });

  @override
  State<GoalDetailScreen> createState() => _GoalDetailScreenState();
}

class _GoalDetailScreenState extends State<GoalDetailScreen> {
  final FirestoreService _firestoreService = FirestoreService();

  void _addMilestone() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return TaskInputModal(
          userData: widget.userData,
          preselectedGoal: widget.initialGoal,
        );
      },
    );
  }

  void _editMilestone(TaskModel task) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => TaskInputModal(
        userData: widget.userData,
        taskToEdit: task,
      ),
    );
  }

  void _showAiSuggestions() {
    print('Abrir sugestões da IA');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: StreamBuilder<List<TaskModel>>(
        stream: _firestoreService.getTasksForGoalStream(
            widget.userData.uid, widget.initialGoal.id),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CustomLoadingSpinner());
          }
          if (snapshot.hasError) {
            return Center(
                child: Text('Erro ao carregar marcos: ${snapshot.error}',
                    style: TextStyle(color: Colors.red.shade300)));
          }

          final milestones = snapshot.data ?? [];
          final int progress = milestones.isEmpty
              ? 0
              : (milestones.where((m) => m.completed).length /
                      milestones.length *
                      100)
                  .round();

          return SafeArea(
            child: CustomScrollView(
              slivers: [
                SliverAppBar(
                  backgroundColor: AppColors.background,
                  elevation: 0,
                  leading: const BackButton(color: AppColors.primary),
                  title: const Text('Detalhes da Jornada',
                      style: TextStyle(color: Colors.white, fontSize: 18)),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12.0),
                    child: _GoalInfoCard(
                        goal: widget.initialGoal, progress: progress),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12.0, 32.0, 12.0, 16.0),
                    child: _buildMilestonesHeader(),
                  ),
                ),
                _buildMilestonesList(milestones: milestones),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addMilestone,
        label: const Text('Novo Marco'),
        icon: const Icon(Icons.add),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildMilestonesHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Expanded(
          child: Text(
            'Marcos da Jornada',
            style: TextStyle(
                color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ),
        TextButton.icon(
          onPressed: _showAiSuggestions,
          icon: const Icon(Icons.auto_awesome,
              color: AppColors.primary, size: 18),
          label: const Text('Sugerir com IA',
              style: TextStyle(color: AppColors.primary)),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 8),
          ),
        ),
      ],
    );
  }

  Widget _buildMilestonesList({required List<TaskModel> milestones}) {
    if (milestones.isEmpty) {
      return const SliverToBoxAdapter(
        child: Center(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 48.0),
            child: Text('Nenhum marco adicionado ainda.',
                style: TextStyle(color: AppColors.secondaryText)),
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final task = milestones[index];
            return TaskItem(
              task: task,
              showJourney: false,
              onToggle: (isCompleted) {
                _firestoreService.updateTaskCompletion(
                  widget.userData.uid,
                  task.id,
                  completed: isCompleted,
                );
                _firestoreService.updateGoalProgress(
                    widget.userData.uid, widget.initialGoal.id);
              },
              onEdit: () => _editMilestone(task),
              onDelete: () async {
                await _firestoreService.deleteTask(
                    widget.userData.uid, task.id);
                _firestoreService.updateGoalProgress(
                    widget.userData.uid, widget.initialGoal.id);
              },
              onDuplicate: () {
                final duplicatedTask = task.copyWith(
                  id: '',
                  text: '${task.text} (cópia)',
                  createdAt: DateTime.now(),
                );
                _firestoreService.addTask(widget.userData.uid, duplicatedTask);
              },
            );
          },
          childCount: milestones.length,
        ),
      ),
    );
  }
}

class _GoalInfoCard extends StatelessWidget {
  final Goal goal;
  final int progress;
  const _GoalInfoCard({required this.goal, required this.progress});

  @override
  Widget build(BuildContext context) {
    String formattedDate = goal.targetDate != null
        ? DateFormat('dd/MM/yyyy').format(goal.targetDate!)
        : 'Sem prazo';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(goal.title,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          if (goal.description.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Text(goal.description,
                  style: const TextStyle(
                      color: AppColors.secondaryText,
                      fontSize: 16,
                      height: 1.5)),
            ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Progresso',
                  style: TextStyle(color: AppColors.secondaryText)),
              Text('$progress%',
                  style: const TextStyle(
                      color: AppColors.primary, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: progress / 100.0,
            backgroundColor: AppColors.background,
            color: AppColors.primary,
            minHeight: 8,
            borderRadius: BorderRadius.circular(4),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              const Icon(Icons.calendar_today,
                  size: 14, color: AppColors.tertiaryText),
              const SizedBox(width: 6),
              Text("Alvo: $formattedDate",
                  style: const TextStyle(
                      color: AppColors.tertiaryText, fontSize: 14)),
            ],
          )
        ],
      ),
    );
  }
}
