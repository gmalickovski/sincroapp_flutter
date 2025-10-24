// lib/features/goals/presentation/goal_detail_screen.dart
// (ARQUIVO MESCLADO E CORRIGIDO COM toFirestore() E REFERÊNCIA DE COLEÇÃO CORRETAS)

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:sincro_app_flutter/common/constants/app_colors.dart';
import 'package:sincro_app_flutter/common/widgets/custom_loading_spinner.dart';
import 'package:sincro_app_flutter/features/goals/models/goal_model.dart';
import 'package:sincro_app_flutter/features/tasks/models/task_model.dart';
import 'package:sincro_app_flutter/features/tasks/presentation/widgets/task_input_modal.dart';
import 'package:sincro_app_flutter/features/tasks/presentation/widgets/task_item.dart';
import 'package:sincro_app_flutter/features/goals/presentation/widgets/ai_suggestion_modal.dart';
import 'package:sincro_app_flutter/models/user_model.dart';
import 'package:sincro_app_flutter/services/firestore_service.dart';
import 'package:sincro_app_flutter/services/numerology_engine.dart';

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

  bool _isLoading = false;
  static const double kDesktopBreakpoint = 768.0;
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

  void _openAiSuggestions() {
    if (_isLoading) return;
    debugPrint("GoalDetailScreen: Abrindo modal de sugestões da IA...");

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return AiSuggestionModal(
          goal: widget.initialGoal,
          onAddSuggestions: (suggestions) {
            debugPrint(
                "GoalDetailScreen: Recebeu ${suggestions.length} sugestões do modal.");
            _addSuggestionsAsTasks(suggestions);
          },
        );
      },
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
        debugPrint("Erro ao excluir marco: $e");
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

  // --- FUNÇÃO CORRIGIDA FINAL ---
  // Usa toFirestore() e a referência correta da coleção
  Future<void> _addSuggestionsAsTasks(
      List<Map<String, String>> suggestions) async {
    if (suggestions.isEmpty) {
      debugPrint(
          "GoalDetailScreen: Nenhuma sugestão selecionada para adicionar.");
      return;
    }

    setState(() {
      _isLoading = true;
    });
    debugPrint(
        "GoalDetailScreen: Adicionando ${suggestions.length} marcos (Tasks) sugeridos...");

    final engine = NumerologyEngine(
      nomeCompleto: widget.userData.nomeAnalise,
      dataNascimento: widget.userData.dataNasc,
    );

    try {
      final batch = FirebaseFirestore.instance.batch();
      final tasksCollection = FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userData.uid)
          .collection('tasks');

      for (final sug in suggestions) {
        DateTime? deadline;
        try {
          deadline = DateTime.parse(sug['date']!);
        } catch (e) {
          debugPrint(
              "GoalDetailScreen: Erro ao fazer parse da data da IA: ${sug['date']} - $e");
          deadline = null;
        }

        final dateForCalc = deadline ?? DateTime.now();
        final personalDay = engine.calculatePersonalDayForDate(dateForCalc);

        final newDocRef = tasksCollection.doc();

        final newTask = TaskModel(
          id: newDocRef.id,
          text: sug['title'] ?? 'Marco sem título',
          completed: false,
          createdAt: DateTime.now(),
          dueDate: deadline,
          tags: [],
          journeyId: widget.initialGoal.id,
          journeyTitle: widget.initialGoal.title,
          personalDay: personalDay,
        );

        // --- CORREÇÃO AQUI ---
        // Usa o método toFirestore() que existe no TaskModel
        batch.set(newDocRef, newTask.toFirestore());
        // --- FIM DA CORREÇÃO ---
      }

      await batch.commit();
      debugPrint(
          "GoalDetailScreen: Batch de ${suggestions.length} tasks commitado.");

      // Não precisa mais chamar _firestoreService.updateGoalProgress aqui,
      // pois o StreamBuilder da tela vai recalcular o progresso
      // quando as novas tarefas aparecerem no stream.

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text("Marcos adicionados com sucesso!"),
              backgroundColor: Colors.green),
        );
      }
    } catch (e, s) {
      debugPrint("GoalDetailScreen: ERRO ao salvar os marcos sugeridos: $e");
      debugPrint("GoalDetailScreen: StackTrace: $s");
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text("Erro ao salvar os marcos: $e"),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<TaskModel>>(
      stream: _firestoreService.getTasksForGoalStream(
          widget.userData.uid, widget.initialGoal.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Scaffold(
              backgroundColor: AppColors.background,
              body: Center(child: CustomLoadingSpinner()));
        }
        if (snapshot.hasError) {
          debugPrint("Erro no Stream de Tarefas da Meta: ${snapshot.error}");
          return Scaffold(
              backgroundColor: AppColors.background,
              body: Center(
                  child: Text("Erro ao carregar marcos: ${snapshot.error}",
                      style: const TextStyle(color: Colors.red))));
        }

        final milestones = snapshot.data ?? [];

        // Calcula o progresso aqui, baseado nos dados do Stream
        final int progress = milestones.isEmpty
            ? 0
            : (milestones.where((m) => m.completed).length /
                    milestones.length *
                    100)
                .round();

        return Scaffold(
          backgroundColor: AppColors.background,
          body: Stack(
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final bool isDesktop =
                      constraints.maxWidth >= kDesktopBreakpoint;
                  final double horizontalPadding = isDesktop ? 24.0 : 12.0;
                  final double listHorizontalPadding = isDesktop ? 0 : 12.0;

                  return SafeArea(
                    child: CustomScrollView(
                      slivers: [
                        SliverAppBar(
                          backgroundColor: AppColors.background,
                          elevation: 0,
                          pinned: true,
                          leading: const BackButton(color: AppColors.primary),
                          title: const Text('Detalhes da Jornada',
                              style:
                                  TextStyle(color: Colors.white, fontSize: 18)),
                        ),
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                                horizontal: horizontalPadding, vertical: 8.0),
                            child: isDesktop
                                ? Center(
                                    child: ConstrainedBox(
                                      constraints: const BoxConstraints(
                                          maxWidth: kMaxContentWidth),
                                      // Passa o progresso calculado para o Card
                                      child: _GoalInfoCard(
                                          goal: widget.initialGoal,
                                          progress: progress),
                                    ),
                                  )
                                // Passa o progresso calculado para o Card
                                : _GoalInfoCard(
                                    goal: widget.initialGoal,
                                    progress: progress),
                          ),
                        ),
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.fromLTRB(
                                horizontalPadding + (isDesktop ? 0 : 4),
                                24.0,
                                horizontalPadding,
                                16.0),
                            child: isDesktop
                                ? Center(
                                    child: ConstrainedBox(
                                      constraints: const BoxConstraints(
                                          maxWidth: kMaxContentWidth),
                                      child: _buildMilestonesHeader(),
                                    ),
                                  )
                                : _buildMilestonesHeader(),
                          ),
                        ),
                        isDesktop
                            ? SliverToBoxAdapter(
                                child: Center(
                                  child: ConstrainedBox(
                                    constraints: const BoxConstraints(
                                        maxWidth: kMaxContentWidth),
                                    child: _buildMilestonesListWidget(
                                        milestones: milestones,
                                        horizontalPadding:
                                            listHorizontalPadding),
                                  ),
                                ),
                              )
                            : _buildMilestonesListSliver(
                                milestones: milestones,
                                horizontalPadding: listHorizontalPadding),
                        const SliverToBoxAdapter(child: SizedBox(height: 80)),
                      ],
                    ),
                  );
                },
              ),
              if (_isLoading)
                Container(
                  color: Colors.black.withOpacity(0.6),
                  child: const Center(
                    child: CustomLoadingSpinner(),
                  ),
                ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: _addMilestone,
            label: const Text('Novo Marco'),
            icon: const Icon(Icons.add),
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            heroTag: 'fab_goal_detail',
          ),
        );
      },
    );
  }

  Widget _buildMilestonesHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'Marcos da Jornada',
          style: TextStyle(
              color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
        ),
        TextButton.icon(
          onPressed: _openAiSuggestions,
          icon: const Icon(Icons.auto_awesome,
              color: AppColors.primary, size: 20),
          label: const Text('Sugerir com IA',
              style: TextStyle(color: AppColors.primary, fontSize: 14)),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          ),
        ),
      ],
    );
  }

  Widget _buildMilestonesListWidget(
      {required List<TaskModel> milestones,
      required double horizontalPadding}) {
    if (milestones.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 64.0, horizontal: 20),
          child: Text(
            'Nenhum marco adicionado ainda.\nUse o botão ✨ "Sugerir com IA" ou o "+" para começar!',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: AppColors.secondaryText, fontSize: 16, height: 1.5),
          ),
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
      child: Column(
        children: List.generate(milestones.length, (index) {
          final task = milestones[index];
          return TaskItem(
            key: ValueKey(task.id),
            task: task,
            showJourney: false,
            onToggle: (isCompleted) async {
              try {
                // Ao marcar/desmarcar, atualiza a tarefa...
                await _firestoreService.updateTaskCompletion(
                    widget.userData.uid, task.id,
                    completed: isCompleted);
                // E também recalcula o progresso da meta
                // (Embora o StreamBuilder também vá fazer isso,
                // pode ser bom ter a atualização explícita aqui para garantir)
                await _firestoreService.updateGoalProgress(
                    widget.userData.uid, widget.initialGoal.id);
              } catch (e) {
                debugPrint("Erro ao atualizar task: $e");
                // TODO: Mostrar SnackBar de erro
              }
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
                // Atualiza progresso após duplicar também
                await _firestoreService.updateGoalProgress(
                    widget.userData.uid, widget.initialGoal.id);
              } catch (e) {
                debugPrint("Erro ao duplicar task: $e");
                // TODO: Mostrar SnackBar de erro
              }
            },
          );
        }),
      ),
    );
  }

  Widget _buildMilestonesListSliver(
      {required List<TaskModel> milestones,
      required double horizontalPadding}) {
    if (milestones.isEmpty) {
      return const SliverToBoxAdapter(
        child: Center(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 64.0, horizontal: 20),
            child: Text(
              'Nenhum marco adicionado ainda.\nUse o botão ✨ "Sugerir com IA" ou o "+" para começar!',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: AppColors.secondaryText, fontSize: 16, height: 1.5),
            ),
          ),
        ),
      );
    }

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
                } catch (e) {
                  debugPrint("Erro ao atualizar task: $e");
                }
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
                } catch (e) {
                  debugPrint("Erro ao duplicar task: $e");
                }
              },
            );
          },
          childCount: milestones.length,
        ),
      ),
    );
  }
} // Fim _GoalDetailScreenState

class _GoalInfoCard extends StatelessWidget {
  final Goal goal;
  final int progress;

  const _GoalInfoCard({required this.goal, required this.progress});

  @override
  Widget build(BuildContext context) {
    String formattedDate = goal.targetDate != null
        ? DateFormat('dd/MM/yyyy', 'pt_BR').format(goal.targetDate!)
        : 'Sem prazo';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
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
              padding: const EdgeInsets.only(top: 4.0, bottom: 8.0),
              child: Text(goal.description,
                  style: const TextStyle(
                      color: AppColors.secondaryText,
                      fontSize: 15,
                      height: 1.4)),
            ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Progresso',
                  style:
                      TextStyle(color: AppColors.secondaryText, fontSize: 14)),
              Text('$progress%', // Usa o progresso recebido como parâmetro
                  style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 14)),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: progress / 100.0, // Usa o progresso recebido
            backgroundColor: AppColors.background.withOpacity(0.7),
            color: AppColors.primary,
            minHeight: 10,
            borderRadius: BorderRadius.circular(5),
          ),
          const SizedBox(height: 16),
          if (goal.targetDate != null)
            Align(
              alignment: Alignment.centerRight,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.calendar_today_outlined,
                      size: 14, color: AppColors.tertiaryText),
                  const SizedBox(width: 6),
                  Text("Alvo: $formattedDate",
                      style: const TextStyle(
                          color: AppColors.tertiaryText, fontSize: 13)),
                ],
              ),
            )
        ],
      ),
    );
  }
}
