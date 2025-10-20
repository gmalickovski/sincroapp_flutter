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

  // --- MUDANÇA: Constante para breakpoint ---
  static const double kDesktopBreakpoint = 768.0;
  // --- MUDANÇA: Constante para largura máxima do conteúdo ---
  static const double kMaxContentWidth = 800.0;

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
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Funcionalidade de sugestão IA em breve!')),
    );
  }

  Future<void> _deleteAndUpdateProgress(String taskId) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: AppColors.cardBackground,
          title: const Text('Confirmar Exclusão',
              style: TextStyle(color: AppColors.primaryText)),
          content: const Text('Tem certeza que deseja excluir este marco?',
              style: TextStyle(color: AppColors.secondaryText)),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancelar',
                  style: TextStyle(color: AppColors.secondaryText)),
              onPressed: () {
                Navigator.of(context).pop(false);
              },
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
              child: const Text('Excluir'),
              onPressed: () {
                Navigator.of(context).pop(true);
              },
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      try {
        await _firestoreService.deleteTask(widget.userData.uid, taskId);
        await _firestoreService.updateGoalProgress(
            widget.userData.uid, widget.initialGoal.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Marco excluído.'),
                backgroundColor: Colors.green),
          );
        }
      } catch (e) {
        print("Erro ao excluir marco: $e");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Erro ao excluir marco: $e'),
                backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: StreamBuilder<List<TaskModel>>(
        stream: _firestoreService.getTasksForGoalStream(
            widget.userData.uid, widget.initialGoal.id),
        builder: (context, snapshot) {
          // Tratamento de loading e erro (sem alterações)
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CustomLoadingSpinner());
          }
          if (snapshot.hasError) {
            print("Erro no Stream de Tarefas da Meta: ${snapshot.error}");
            return Center(/* ... Mensagem de erro ... */);
          }

          final milestones = snapshot.data ?? [];
          final int progress = milestones.isEmpty
              ? 0
              : (milestones.where((m) => m.completed).length /
                      milestones.length *
                      100)
                  .round();

          // --- MUDANÇA: Usar LayoutBuilder aqui ---
          return LayoutBuilder(
            builder: (context, constraints) {
              final bool isDesktop = constraints.maxWidth >= kDesktopBreakpoint;
              // Ajusta o padding horizontal baseado no layout
              final double horizontalPadding = isDesktop ? 24.0 : 12.0;
              // Define o padding para a lista de marcos
              final double listHorizontalPadding =
                  isDesktop ? 0 : 12.0; // Sem padding extra na lista em desktop

              return SafeArea(
                child: CustomScrollView(
                  slivers: [
                    SliverAppBar(
                      backgroundColor: AppColors.background,
                      elevation: 0,
                      pinned: true,
                      leading: const BackButton(color: AppColors.primary),
                      title: const Text('Detalhes da Jornada',
                          style: TextStyle(color: Colors.white, fontSize: 18)),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        // Padding externo geral
                        padding: EdgeInsets.symmetric(
                            horizontal: horizontalPadding, vertical: 8.0),
                        child: isDesktop
                            ? Center(
                                // Centraliza o card em desktop
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(
                                      maxWidth: kMaxContentWidth),
                                  child: _GoalInfoCard(
                                      goal: widget.initialGoal,
                                      progress: progress),
                                ),
                              )
                            : _GoalInfoCard(
                                // Card normal em mobile
                                goal: widget.initialGoal,
                                progress: progress),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        // Padding externo geral
                        padding: EdgeInsets.fromLTRB(
                            horizontalPadding +
                                4, // Alinha com o conteúdo da lista
                            24.0,
                            horizontalPadding,
                            16.0),
                        child: isDesktop
                            ? Center(
                                // Centraliza o header em desktop
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(
                                      maxWidth: kMaxContentWidth),
                                  child: _buildMilestonesHeader(),
                                ),
                              )
                            : _buildMilestonesHeader(), // Header normal em mobile
                      ),
                    ),
                    // --- MUDANÇA: Condicional para centralizar a lista ---
                    isDesktop
                        ? SliverToBoxAdapter(
                            // Usamos SliverToBoxAdapter para poder centralizar
                            child: Center(
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                    maxWidth: kMaxContentWidth),
                                // Chama a função que agora retorna um Widget (Column/Padding)
                                child: _buildMilestonesListWidget(
                                    milestones: milestones,
                                    horizontalPadding: listHorizontalPadding),
                              ),
                            ),
                          )
                        : _buildMilestonesListSliver(
                            milestones: milestones,
                            horizontalPadding:
                                listHorizontalPadding), // Mantém SliverList para mobile

                    const SliverToBoxAdapter(child: SizedBox(height: 80)),
                  ],
                ),
              );
            },
          );
          // --- FIM DA MUDANÇA ---
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addMilestone,
        label: const Text('Novo Marco'),
        icon: const Icon(Icons.add),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        heroTag: null,
      ),
    );
  }

  Widget _buildMilestonesHeader() {
    // (Sem alterações no conteúdo, apenas será centralizado via ConstrainedBox no build)
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'Marcos da Jornada',
          style: TextStyle(
              color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
        ),
        TextButton.icon(
          onPressed: _showAiSuggestions,
          icon: const Icon(Icons.auto_awesome,
              color: AppColors.primary, size: 18),
          label: const Text('Sugerir com IA',
              style: TextStyle(color: AppColors.primary)),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
      ],
    );
  }

  // --- MUDANÇA: Função separada para o conteúdo da lista (retorna Widget) ---
  /// Retorna um Widget (Column ou Center) contendo a lista de marcos.
  Widget _buildMilestonesListWidget(
      {required List<TaskModel> milestones,
      required double horizontalPadding}) {
    if (milestones.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 48.0),
          child: Text('Nenhum marco adicionado ainda.',
              style: TextStyle(color: AppColors.secondaryText)),
        ),
      );
    }

    // Para desktop, usamos Column dentro do ConstrainedBox
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
      child: Column(
        // Era SliverList, agora é Column
        children: List.generate(milestones.length, (index) {
          final task = milestones[index];
          return TaskItem(
            key: ValueKey(task.id),
            task: task,
            showJourney: false,
            onToggle: (isCompleted) async {
              try {
                await _firestoreService.updateTaskCompletion(
                    widget.userData.uid, task.id,
                    completed: isCompleted);
                await _firestoreService.updateGoalProgress(
                    widget.userData.uid, widget.initialGoal.id);
              } catch (e) {/* ... tratamento de erro ... */}
            },
            onEdit: () => _editMilestone(task),
            onDelete: () => _deleteAndUpdateProgress(task.id),
            onDuplicate: () async {
              final duplicatedTask = task.copyWith(
                id: '',
                createdAt: DateTime.now(),
                completed: false,
              );
              try {
                await _firestoreService.addTask(
                    widget.userData.uid, duplicatedTask);
                await _firestoreService.updateGoalProgress(
                    widget.userData.uid, widget.initialGoal.id);
              } catch (e) {/* ... tratamento de erro ... */}
            },
          );
        }),
      ),
    );
  }

  // --- MUDANÇA: Função original renomeada para _buildMilestonesListSliver (retorna Sliver) ---
  /// Retorna um Sliver (SliverPadding com SliverList) para layout mobile.
  Widget _buildMilestonesListSliver(
      {required List<TaskModel> milestones,
      required double horizontalPadding}) {
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

    // Layout original para mobile
    return SliverPadding(
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final task = milestones[index];
            return TaskItem(
              key: ValueKey(task.id),
              task: task,
              showJourney: false,
              onToggle: (isCompleted) async {
                try {
                  await _firestoreService.updateTaskCompletion(
                      widget.userData.uid, task.id,
                      completed: isCompleted);
                  await _firestoreService.updateGoalProgress(
                      widget.userData.uid, widget.initialGoal.id);
                } catch (e) {/* ... tratamento de erro ... */}
              },
              onEdit: () => _editMilestone(task),
              onDelete: () => _deleteAndUpdateProgress(task.id),
              onDuplicate: () async {
                final duplicatedTask = task.copyWith(
                  id: '',
                  createdAt: DateTime.now(),
                  completed: false,
                );
                try {
                  await _firestoreService.addTask(
                      widget.userData.uid, duplicatedTask);
                  await _firestoreService.updateGoalProgress(
                      widget.userData.uid, widget.initialGoal.id);
                } catch (e) {/* ... tratamento de erro ... */}
              },
            );
          },
          childCount: milestones.length,
        ),
      ),
    );
  }
} // Fim _GoalDetailScreenState

// _GoalInfoCard (sem alterações)
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
