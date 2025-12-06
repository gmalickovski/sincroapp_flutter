// lib/features/goals/presentation/goal_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:sincro_app_flutter/common/constants/app_colors.dart';
import 'package:sincro_app_flutter/common/widgets/custom_loading_spinner.dart';
import 'package:sincro_app_flutter/features/goals/models/goal_model.dart';
import 'package:sincro_app_flutter/features/tasks/models/task_model.dart';
import 'package:sincro_app_flutter/features/tasks/utils/task_parser.dart';
import 'package:sincro_app_flutter/features/tasks/presentation/widgets/task_input_modal.dart';
import 'package:sincro_app_flutter/features/tasks/presentation/widgets/task_item.dart';
import 'package:sincro_app_flutter/features/tasks/presentation/widgets/task_detail_modal.dart';
import 'package:sincro_app_flutter/features/goals/presentation/widgets/ai_suggestion_modal.dart';
import 'package:sincro_app_flutter/models/user_model.dart';
import 'package:sincro_app_flutter/models/subscription_model.dart';
import 'package:sincro_app_flutter/services/firestore_service.dart';
import 'package:sincro_app_flutter/services/numerology_engine.dart';
import 'package:sincro_app_flutter/features/goals/presentation/widgets/goal_onboarding_modal.dart';
import 'package:sincro_app_flutter/features/goals/presentation/create_goal_screen.dart';
import 'package:sincro_app_flutter/features/goals/presentation/widgets/create_goal_dialog.dart';
import 'package:sincro_app_flutter/features/tasks/services/task_action_service.dart';
import 'package:sincro_app_flutter/features/goals/presentation/widgets/goal_image_card.dart'; // Add
import 'package:sincro_app_flutter/features/goals/presentation/widgets/image_upload_dialog.dart'; // Add

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
  final TaskActionService _taskActionService = TaskActionService();
  bool _isLoading = false;
  // NEW STATE: Controls the visibility of the top carousel
  bool _isMilestonesExpanded = false; 

  static const double kDesktopBreakpoint = 768.0;
  static const double kMaxContentWidth = 1200.0;
  late Goal _currentGoal;

  @override
  void initState() {
    super.initState();
    _currentGoal = widget.initialGoal;
  }

  // Handle goal editing
  void _handleEditGoal() {
    final bool isDesktop = MediaQuery.of(context).size.width >= kDesktopBreakpoint;

    if (isDesktop) {
      // Desktop: Show dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext dialogContext) {
          return CreateGoalDialog(
            userData: widget.userData,
            goalToEdit: widget.initialGoal,
          );
        },
      ).then((result) {
        if (result == true && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Jornada atualizada com sucesso!'),
              backgroundColor: AppColors.primary,
            ),
          );
        }
      });
    } else {
      // Mobile: Navigate to full screen
      Navigator.of(context).push(MaterialPageRoute(
        builder: (context) => CreateGoalScreen(
          userData: widget.userData,
          goalToEdit: widget.initialGoal,
        ),
        fullscreenDialog: true,
      ));
    }
  }

  // Handle goal deletion
  Future<void> _handleDeleteGoal() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        title: const Text('Excluir Jornada?',
            style: TextStyle(color: Colors.white)),
        content: const Text(
            'Tem certeza que deseja excluir esta jornada? Esta ação não pode ser desfeita.',
            style: TextStyle(color: AppColors.secondaryText)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar',
                style: TextStyle(color: AppColors.secondaryText)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Excluir',
                style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _firestoreService.deleteGoal(
            widget.userData.uid, widget.initialGoal.id);
        if (mounted) {
          Navigator.of(context).pop(); // Return to previous screen
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Jornada excluída com sucesso'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erro ao excluir jornada: $e'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    }
  }

  // Função para adicionar novo marco
  void _addMilestone() {
    if (widget.userData.uid.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erro: ID do usuário não encontrado.')));
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return TaskInputModal(
          userData: widget.userData,
          userId: widget.userData.uid,
          preselectedGoal: widget.initialGoal, 
          initialDueDate: DateTime.now(), 
          onAddTask: (ParsedTask parsedTask) {
            DateTime? finalDueDateUtc = parsedTask.dueDate?.toUtc();
            DateTime dateForPersonalDay;

            if (finalDueDateUtc != null) {
              dateForPersonalDay = finalDueDateUtc;
            } else {
              final now = DateTime.now().toLocal();
              dateForPersonalDay = DateTime.utc(now.year, now.month, now.day);
            }

            final int? finalPersonalDay =
                _calculatePersonalDay(dateForPersonalDay);

            final newTask = TaskModel(
              id: '',
              text: parsedTask.cleanText,
              createdAt: DateTime.now().toUtc(),
              dueDate: finalDueDateUtc, 
              journeyId: widget.initialGoal.id, 
              journeyTitle: widget.initialGoal.title, 
              tags: parsedTask.tags,
              personalDay: finalPersonalDay, 
            );

            _firestoreService
                .addTask(widget.userData.uid, newTask)
                .catchError((error) {
              if (!mounted) return;
              messenger.showSnackBar(
                SnackBar(
                    content: Text('Erro ao salvar marco: $error'),
                    backgroundColor: Colors.red),
              );
            });
          },
        );
      },
    );
  }

  void _handleMilestoneTap(TaskModel task) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return TaskDetailModal(
          task: task,
          userData: widget.userData,
        );
      },
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

  void _handleImageTap() {
    final bool isDesktop = MediaQuery.of(context).size.width >= kDesktopBreakpoint;

    if (isDesktop) {
      showDialog(
        context: context,
        builder: (context) => Dialog(
          backgroundColor: Colors.transparent,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: ImageUploadDialog(
              userData: widget.userData,
              goal: widget.initialGoal,
            ),
          ),
        ),
      ).then((_) {
        _refreshGoal();
      });
    } else {
      Navigator.of(context).push(MaterialPageRoute(
        builder: (context) => ImageUploadDialog(
          userData: widget.userData,
          goal: widget.initialGoal,
        ),
        fullscreenDialog: true,
      )).then((_) => _refreshGoal());
    }
  }

  void _refreshGoal() async {
    final doc = await _firestoreService.getGoalById(widget.userData.uid, widget.initialGoal.id);
    if (doc != null && mounted) {
       setState(() {
         _currentGoal = doc;
       });
    }
  }

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
    
    NumerologyEngine? engine;
    if (widget.userData.dataNasc.isNotEmpty &&
        widget.userData.nomeAnalise.isNotEmpty) {
      engine = NumerologyEngine(
        nomeCompleto: widget.userData.nomeAnalise,
        dataNascimento: widget.userData.dataNasc,
      );
    }

    List<TaskModel> tasksToAdd = [];

    for (final sug in suggestions) {
      DateTime? deadline;
      try {
        if (sug['date'] != null && sug['date']!.isNotEmpty) {
          deadline = DateTime.tryParse(sug['date']!);
        }
      } catch (e) {
        deadline = null;
      }

      int? personalDay;
      if (engine != null) {
        final dateForCalc = deadline ?? DateTime.now();
        personalDay = engine.calculatePersonalDayForDate(dateForCalc);
      }

      final newTask = TaskModel(
        id: '', 
        text: sug['title'] ?? 'Marco sem título',
        completed: false,
        createdAt: DateTime.now().toUtc(), 
        dueDate: deadline?.toUtc(), 
        tags: [],
        journeyId: widget.initialGoal.id, 
        journeyTitle: widget.initialGoal.title,
        personalDay: personalDay,
      );
      tasksToAdd.add(newTask);
    }

    try {
      for (var task in tasksToAdd) {
        await _firestoreService.addTask(widget.userData.uid, task);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text("Marcos adicionados com sucesso!"),
              backgroundColor: Colors.green),
        );
      }
    } catch (e, s) {
      debugPrint("GoalDetailScreen: ERRO ao salvar os marcos sugeridos: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text("Erro ao salvar os marcos: $e"),
              backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  int? _calculatePersonalDay(DateTime? date) {
    if (widget.userData.dataNasc.isEmpty ||
        widget.userData.nomeAnalise.isEmpty ||
        date == null) {
      return null;
    }

    final engine = NumerologyEngine(
      nomeCompleto: widget.userData.nomeAnalise,
      dataNascimento: widget.userData.dataNasc,
    );

    try {
      final dateUtc = date.toUtc();
      final day = engine.calculatePersonalDayForDate(dateUtc);
      return (day > 0) ? day : null;
    } catch (e) {
      return null;
    }
  }

  Future<bool?> _handleSwipeLeft(TaskModel task) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        title: const Text('Excluir Marco?',
            style: TextStyle(color: Colors.white)),
        content: const Text(
            'Tem certeza que deseja excluir este marco? Esta ação não pode ser desfeita.',
            style: TextStyle(color: AppColors.secondaryText)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar',
                style: TextStyle(color: AppColors.secondaryText)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Excluir',
                style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _firestoreService.deleteTask(widget.userData.uid, task.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Marco excluído com sucesso'),
              backgroundColor: AppColors.success,
            ),
          );
        }
        return true; 
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erro ao excluir marco: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return false;
      }
    }
    return false;
  }

  Future<bool?> _handleSwipeRight(TaskModel task) async {
    await _taskActionService.rescheduleTask(
      context,
      task,
      widget.userData,
    );
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<TaskModel>>(
      stream: _firestoreService.getTasksForGoalStream(
          widget.userData.uid, _currentGoal.id),
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
                  final double listHorizontalPadding = isDesktop ? 24.0 : 12.0;

                  return SafeArea(
                    child: CustomScrollView(
                      physics: _isMilestonesExpanded 
                          ? const ClampingScrollPhysics() 
                          : const AlwaysScrollableScrollPhysics(),
                      slivers: [
                        SliverAppBar(
                          backgroundColor: AppColors.background,
                          elevation: 0,
                          pinned: true,
                          leading: const BackButton(color: AppColors.primary),
                          title: Text(widget.initialGoal.title,
                              style:
                                  const TextStyle(color: Colors.white, fontSize: 18)),
                        ),
                        if (isDesktop)
                          SliverToBoxAdapter(
                            child: Center(
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                    maxWidth: kMaxContentWidth),
                                child: Padding(
                                  padding: EdgeInsets.symmetric(
                                      horizontal: horizontalPadding,
                                      vertical: 24.0),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      ConstrainedBox(
                                        constraints: const BoxConstraints(
                                            maxWidth: 350),
                                        child: Column(
                                          children: [
                                            _CircularGoalInfoCard(
                                              goal: _currentGoal,
                                              progress: progress,
                                              onEdit: _handleEditGoal,
                                              onDelete: _handleDeleteGoal,
                                            ),
                                            const SizedBox(height: 24),
                                            GoalImageCard(
                                              goal: _currentGoal,
                                              onTap: _handleImageTap,
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 24),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            _buildMilestonesHeader(),
                                            const SizedBox(height: 16),
                                            _buildMilestonesListWidget(
                                                milestones: milestones,
                                                horizontalPadding: 0),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          )
                        else ...[
                          // Mobile Layout
                          // Collapsible Header (Carousel)
                          SliverToBoxAdapter(
                            child: AnimatedCrossFade(
                              firstChild: SizedBox(
                                height: 380, // Height for the carousel
                                child: PageView(
                                  padEnds: false,
                                  controller: PageController(viewportFraction: 1.0), // Full width
                                  children: [
                                    Padding(
                                      padding: EdgeInsets.symmetric(
                                          horizontal: horizontalPadding, vertical: 8.0),
                                      child: _CollapsibleGoalInfoCard(
                                        goal: _currentGoal,
                                        progress: progress,
                                        onEdit: _handleEditGoal,
                                        onDelete: _handleDeleteGoal,
                                      ),
                                    ),
                                    Padding(
                                      padding: EdgeInsets.symmetric(
                                          horizontal: horizontalPadding, vertical: 8.0),
                                      child: GoalImageCard(
                                        goal: _currentGoal,
                                        onTap: _handleImageTap,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              secondChild: const SizedBox.shrink(),
                              crossFadeState: _isMilestonesExpanded
                                  ? CrossFadeState.showSecond
                                  : CrossFadeState.showFirst,
                              duration: const Duration(milliseconds: 300),
                              sizeCurve: Curves.easeInOut,
                            ),
                          ),
                          
                          // Header for Milestones
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: EdgeInsets.fromLTRB(horizontalPadding,
                                  8.0, horizontalPadding, 16.0),
                              child: _buildMilestonesHeader(),
                            ),
                          ),
                          
                          _buildMilestonesListSliver(
                              milestones: milestones,
                              horizontalPadding: listHorizontalPadding),
                        ],
                        const SliverToBoxAdapter(child: SizedBox(height: 80)),
                      ],
                    ),
                  );
                },
              ),

              if (milestones.isEmpty && !_isLoading)
                GoalOnboardingModal(
                  onAddMilestone: (String title, String? dateStr) {
                    DateTime? dueDate;
                    if (dateStr != null) {
                      try {
                        final parts = dateStr.split('/');
                        if (parts.length == 3) {
                          dueDate = DateTime(
                            int.parse(parts[2]), // ano
                            int.parse(parts[1]), // mês
                            int.parse(parts[0]), // dia
                          ).toUtc();
                        }
                      } catch (e) {
                        debugPrint('Erro ao converter data: $e');
                      }
                    }

                    final dateForPersonalDay = dueDate ?? DateTime.now().toUtc();
                    final int? personalDay = _calculatePersonalDay(dateForPersonalDay);

                    final newTask = TaskModel(
                      id: '',
                      text: title,
                      createdAt: DateTime.now().toUtc(),
                      dueDate: dueDate,
                      journeyId: widget.initialGoal.id,
                      journeyTitle: widget.initialGoal.title,
                      tags: [],
                      personalDay: personalDay,
                    );

                    _firestoreService.addTask(widget.userData.uid, newTask).catchError((error) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Erro ao salvar marco: $error'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    });
                  },
                  onClose: () {},
                  userData: widget.userData,
                  onSuggestWithAI: widget.userData.subscription.plan ==
                          SubscriptionPlan.premium
                      ? _openAiSuggestions
                      : null,
                ),

              if (_isLoading)
                Container(
                    color: Colors.black.withValues(alpha: 0.6),
                    child: const Center(child: CustomLoadingSpinner())),
            ],
          ),
          floatingActionButton: milestones.isNotEmpty
              ? FloatingActionButton.extended(
                  onPressed: _addMilestone,
                  label: const Text('Novo Marco'),
                  icon: const Icon(Icons.add),
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  heroTag: 'fab_goal_detail',
                )
              : null,
        );
      },
    );
  }

  // Header do marcos (com botão de expandir e IA simplificado)
  Widget _buildMilestonesHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'Marcos da Jornada',
          style: TextStyle(
              color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // AI Suggestion Button (Icon Only)
            if (widget.userData.subscription.plan == SubscriptionPlan.premium)
              IconButton(
                onPressed: _openAiSuggestions,
                icon: const Icon(Icons.auto_awesome, color: AppColors.primary),
                tooltip: 'Sugerir com IA',
              ),
            
            // Expand/Collapse Button
            IconButton(
              onPressed: () {
                setState(() {
                  _isMilestonesExpanded = !_isMilestonesExpanded;
                });
              },
              icon: AnimatedRotation(
                turns: _isMilestonesExpanded ? 0.5 : 0.0, 
                duration: const Duration(milliseconds: 300),
                child: const Icon(
                  Icons.keyboard_arrow_up,
                  color: AppColors.secondaryText,
                ),
              ),
            ),
          ],
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
            'Nenhum marco adicionado ainda.\nUse o botão ✨ ou o "+" para começar!',
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
          return Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: TaskItem(
            key: ValueKey(task.id),
            task: task,
            showGoalIconFlag: false,
            showTagsIconFlag: true,
            showVibrationPillFlag: true,
            onToggle: (isCompleted) async {
              final messenger = ScaffoldMessenger.of(context);
              try {
                await _firestoreService.updateTaskCompletion(
                    widget.userData.uid, task.id,
                    completed: isCompleted);
              } catch (e) {
                if (mounted) {
                  messenger.showSnackBar(
                    SnackBar(
                        content: Text('Erro ao atualizar marco: $e'),
                        backgroundColor: Colors.red),
                  );
                }
              }
            },
            onDelete: () => _handleSwipeLeft(task),
            onTap: () => _handleMilestoneTap(task),
            ),
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
              'Nenhum marco adicionado ainda.\nUse o botão ✨ ou o "+" para começar!',
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
            return Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Dismissible(
                key: Key(task.id),
                direction: DismissDirection.horizontal,
                confirmDismiss: (direction) async {
                  if (direction == DismissDirection.endToStart) {
                    return await _handleSwipeLeft(task);
                  } else {
                    return await _handleSwipeRight(task); 
                  }
                },
                background: Container(
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.only(left: 20.0),
                  decoration: BoxDecoration(
                    color: Colors.orangeAccent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.schedule, color: Colors.white),
                ),
                secondaryBackground: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20.0),
                  decoration: BoxDecoration(
                    color: Colors.redAccent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.delete, color: Colors.white),
                ),
                child: TaskItem(
                  key: ValueKey(task.id),
                  task: task,
                  showGoalIconFlag: false,
                  showTagsIconFlag: true,
                  showVibrationPillFlag: true, 
                  onToggle: (isCompleted) async {
                    try {
                      await _firestoreService.updateTaskCompletion(
                          widget.userData.uid, task.id,
                          completed: isCompleted);
                    } catch (e) {
                       // handled
                    }
                  },
                  onTap: () => _handleMilestoneTap(task),
                  onDelete: null, // handled by dismissible
                ),
              ),
            );
          },
          childCount: milestones.length,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Card Circular (Desktop e Mobile) - Refatorado para remover botões de ação interna
class _CircularGoalInfoCard extends StatelessWidget {
  final Goal goal;
  final int progress;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _CircularGoalInfoCard({
    required this.goal,
    required this.progress,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header: Title and Options
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  goal.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: AppColors.secondaryText),
                color: AppColors.cardBackground,
                onSelected: (value) {
                  if (value == 'edit') onEdit();
                  if (value == 'delete') onDelete();
                },
                itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                  const PopupMenuItem<String>(
                    value: 'edit',
                    child: ListTile(
                      leading: Icon(Icons.edit, color: Colors.white),
                      title: Text('Editar', style: TextStyle(color: Colors.white)),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  const PopupMenuItem<String>(
                    value: 'delete',
                    child: ListTile(
                      leading: Icon(Icons.delete, color: Colors.redAccent),
                      title: Text('Excluir', style: TextStyle(color: Colors.redAccent)),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Circular Progress
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 120,
                height: 120,
                child: CircularProgressIndicator(
                  value: progress / 100,
                  strokeWidth: 10,
                  backgroundColor: AppColors.background,
                  valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$progress%',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Text(
                    'Concluído',
                    style: TextStyle(color: AppColors.secondaryText, fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Details
          if (goal.description != null && goal.description!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: Text(
                goal.description!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.secondaryText),
              ),
            ),
          
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.flag, color: AppColors.primary, size: 16),
                const SizedBox(width: 8),
                Text(
                  goal.targetDate != null
                      ? DateFormat('dd/MM/yyyy').format(goal.targetDate!)
                      : 'Sem data',
                  style: const TextStyle(color: Colors.white),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Card Retangular Colapsável (Mobile)
class _CollapsibleGoalInfoCard extends StatelessWidget {
  final Goal goal;
  final int progress;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _CollapsibleGoalInfoCard({
    required this.goal,
    required this.progress,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20), // Padding ajustado para visual mais limpo
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
         boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
           // Header: Title and Options
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  goal.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20, // Aumentado um pouco
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              PopupMenuButton<String>(
                padding: EdgeInsets.zero,
                icon: const Icon(Icons.more_vert, color: AppColors.secondaryText),
                color: AppColors.cardBackground,
                onSelected: (value) {
                  if (value == 'edit') onEdit();
                  if (value == 'delete') onDelete();
                },
                itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                  const PopupMenuItem<String>(
                    value: 'edit',
                    child: ListTile(
                      leading: Icon(Icons.edit, color: Colors.white),
                      title: Text('Editar', style: TextStyle(color: Colors.white)),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  const PopupMenuItem<String>(
                    value: 'delete',
                    child: ListTile(
                      leading: Icon(Icons.delete, color: Colors.redAccent),
                      title: Text('Excluir', style: TextStyle(color: Colors.redAccent)),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Description (Flexible height)
          Expanded(
            child: SingleChildScrollView(
              child: Text(
                goal.description ?? 'Sem descrição.',
                style: const TextStyle(
                  color: AppColors.secondaryText, 
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
            ),
          ),
          
          const SizedBox(height: 16),

          // Linear Progress Bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Progresso", style: TextStyle(color: AppColors.secondaryText)),
              Text("$progress%", style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress / 100,
              backgroundColor: AppColors.background,
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
              minHeight: 8,
            ),
          ),

           const SizedBox(height: 16),

           // Target Date
           Align(
             alignment: Alignment.centerRight,
             child: Row(
               mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.calendar_today_outlined, size: 14, color: AppColors.secondaryText),
                  const SizedBox(width: 6),
                  Text(
                    "Alvo: ${goal.targetDate != null ? DateFormat('dd/MM/yyyy').format(goal.targetDate!) : '...'}",
                    style: const TextStyle(color: AppColors.secondaryText, fontSize: 13),
                  ),
                ],
             ),
           ),
        ],
      ),
    );
  }
}
