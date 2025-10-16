// lib/features/goals/presentation/goal_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:sincro_app_flutter/common/constants/app_colors.dart';
import 'package:sincro_app_flutter/common/widgets/custom_loading_spinner.dart';
import 'package:sincro_app_flutter/features/goals/models/goal_model.dart';
import 'package:sincro_app_flutter/features/tasks/models/task_model.dart';
import 'package:sincro_app_flutter/models/user_model.dart';
import 'package:sincro_app_flutter/services/firestore_service.dart';
import 'widgets/milestone_list_item.dart';

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

  Stream<List<TaskModel>> _getMilestonesStream() {
    return _firestoreService.getTasksStream(widget.userData.uid).map((tasks) =>
        tasks
            .where((task) => task.journeyId == widget.initialGoal.id)
            .toList());
  }

  void _addMilestone() {
    print('Adicionar novo marco para ${widget.initialGoal.title}');
  }

  void _showAiSuggestions() {
    print('Abrir sugestões da IA');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: BackButton(color: AppColors.primary),
        title: const Text('Detalhes da Jornada',
            style: TextStyle(color: Colors.white, fontSize: 18)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24.0),
        children: [
          _GoalInfoCard(goal: widget.initialGoal),
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Marcos da Jornada',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold),
              ),
              TextButton.icon(
                onPressed: _showAiSuggestions,
                icon: const Icon(Icons.auto_awesome,
                    color: AppColors.primary, size: 18),
                label: const Text('Sugerir com IA',
                    style: TextStyle(color: AppColors.primary)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          StreamBuilder<List<TaskModel>>(
            stream: _getMilestonesStream(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CustomLoadingSpinner());
              }
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text('Nenhum marco adicionado ainda.',
                        style: TextStyle(color: AppColors.secondaryText)),
                  ),
                );
              }
              final milestones = snapshot.data!;
              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: milestones.length,
                itemBuilder: (context, index) {
                  final milestone = milestones[index];
                  return MilestoneListItem(
                    milestone: milestone,
                    onStatusChanged: (isCompleted) {
                      _firestoreService.updateTaskCompletion(
                          widget.userData.uid, milestone.id,
                          completed: isCompleted);
                    },
                    onEdit: () {/* Lógica de edição a ser implementada */},
                    onDelete: () {
                      _firestoreService.deleteTask(
                          widget.userData.uid, milestone.id);
                    },
                  );
                },
              );
            },
          ),
        ],
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
}

class _GoalInfoCard extends StatelessWidget {
  final Goal goal;
  const _GoalInfoCard({required this.goal});

  @override
  Widget build(BuildContext context) {
    String formattedDate = goal.targetDate != null
        ? DateFormat('dd/MM/yyyy').format(goal.targetDate!)
        : 'Sem prazo';

    return Container(
      padding: const EdgeInsets.all(20),
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
          Text(goal.description,
              style: const TextStyle(
                  color: AppColors.secondaryText, fontSize: 16, height: 1.5)),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Progresso',
                  style: TextStyle(color: AppColors.secondaryText)),
              Text('${goal.progress}%',
                  style: const TextStyle(
                      color: AppColors.primary, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: goal.progress / 100.0,
            backgroundColor: AppColors.border,
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
