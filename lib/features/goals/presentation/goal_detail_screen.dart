// lib/features/goals/presentation/goal_detail_screen.dart
// REMOVIDO: import 'package:cloud_firestore/cloud_firestore.dart';
// (Não precisamos mais dele diretamente aqui)
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:sincro_app_flutter/common/constants/app_colors.dart';
import 'package:sincro_app_flutter/common/widgets/custom_loading_spinner.dart';
import 'package:sincro_app_flutter/features/goals/models/goal_model.dart';
import 'package:sincro_app_flutter/features/tasks/models/task_model.dart';
// ATUALIZADO: Importa ParsedTask (necessário para o TaskInputModal)
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
  // Já temos a instância do FirestoreService aqui!
  final FirestoreService _firestoreService = FirestoreService();
  final TaskActionService _taskActionService = TaskActionService();
  bool _isLoading = false;
  static const double kDesktopBreakpoint = 768.0;
  static const double kMaxContentWidth = 1200.0;

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

  // Função para adicionar novo marco (Atualizada na Turn 14 para usar nova assinatura)
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

          // --- INÍCIO DA CORREÇÃO (Problema 1 e 2) ---
          preselectedGoal: widget.initialGoal, // Passa a meta atual
          initialDueDate: DateTime.now(), // Passa a data de hoje para a pílula
          // --- FIM DA CORREÇÃO ---

          // Usa a nova assinatura com ParsedTask
          onAddTask: (ParsedTask parsedTask) {
            // --- INÍCIO DA CORREÇÃO (Refatoração Dia Pessoal) ---
            DateTime? finalDueDateUtc = parsedTask.dueDate?.toUtc();
            DateTime dateForPersonalDay;

            if (finalDueDateUtc != null) {
              dateForPersonalDay = finalDueDateUtc;
            } else {
              // Se não tem data, usa a data atual para calcular o dia pessoal
              final now = DateTime.now().toLocal();
              dateForPersonalDay = DateTime.utc(now.year, now.month, now.day);
            }

            // Calcula o dia pessoal usando a data determinada
            final int? finalPersonalDay =
                _calculatePersonalDay(dateForPersonalDay);
            // --- FIM DA CORREÇÃO ---

            final newTask = TaskModel(
              id: '',
              text: parsedTask.cleanText,
              createdAt: DateTime.now().toUtc(),
              dueDate: finalDueDateUtc, // Usa a data do picker (pode ser nula)
              journeyId: widget.initialGoal.id, // Garante associação
              journeyTitle: widget.initialGoal.title, // Garante associação
              tags: parsedTask.tags,
              // --- INÍCIO DA CORREÇÃO (Refatoração Dia Pessoal) ---
              personalDay: finalPersonalDay, // Salva o dia pessoal calculado
              // --- FIM DA CORREÇÃO ---
            );

            // Usa o _firestoreService existente
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

  // Função _handleMilestoneTap (Sua original)
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
        // Refresh logic handled by StreamBuilder, but we might need to force rebuild if data isn't streaming for Goal itself?
        // Actually GoalDetailScreen takes initialGoal. The stream is for tasks.
        // We need to listen to Goal changes too or update the state manually?
        // The StreamBuilder only listens to TASKS.
        // We need to reload the goal or wrap the Screen in a Goal Stream.
        // For now, let's update state manually if we can fetch it, or just setState.
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

  // Reload goal data to update image
  void _refreshGoal() async {
    final doc = await _firestoreService.getGoalById(widget.userData.uid, widget.initialGoal.id);
    if (doc != null && mounted) {
       // We can't update 'widget.initialGoal' directly, so we might need a local state variable for the goal.
       // Refactoring to use local _currentGoal.
       setState(() {
         _currentGoal = doc;
       });
    }
  }

  late Goal _currentGoal;

  @override
  void initState() {
    super.initState();
    _currentGoal = widget.initialGoal;
  }

  // ---
  // --- ATUALIZAÇÃO NESTA FUNÇÃO ---
  // ---
  // Adicionar sugestões como Tasks (Atualizada para usar _firestoreService)
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

    NumerologyEngine? engine;
    if (widget.userData.dataNasc.isNotEmpty &&
        widget.userData.nomeAnalise.isNotEmpty) {
      engine = NumerologyEngine(
        nomeCompleto: widget.userData.nomeAnalise,
        dataNascimento: widget.userData.dataNasc,
      );
    }

    // Usa uma lista para rastrear as tarefas a serem adicionadas
    List<TaskModel> tasksToAdd = [];

    for (final sug in suggestions) {
      DateTime? deadline;
      try {
        if (sug['date'] != null && sug['date']!.isNotEmpty) {
          deadline = DateTime.tryParse(sug['date']!);
        }
      } catch (e) {
        debugPrint(
            "GoalDetailScreen: Erro ao fazer parse da data da IA: ${sug['date']} - $e");
        deadline = null;
      }

      int? personalDay;
      if (engine != null) {
        final dateForCalc = deadline ?? DateTime.now();
        personalDay = engine.calculatePersonalDayForDate(dateForCalc);
      }

      // Cria o objeto TaskModel (sem ID ainda)
      final newTask = TaskModel(
        id: '', // O ID será gerado pelo FirestoreService.addTask
        text: sug['title'] ?? 'Marco sem título',
        completed: false,
        createdAt: DateTime.now().toUtc(), // Usa UTC
        dueDate: deadline?.toUtc(), // Usa UTC
        tags: [],
        journeyId: widget.initialGoal.id, // Vincula à jornada atual
        journeyTitle: widget.initialGoal.title,
        personalDay: personalDay,
      );
      tasksToAdd.add(newTask);
    }

    // Adiciona as tarefas uma por uma usando o FirestoreService
    try {
      for (var task in tasksToAdd) {
        // Usa o método addTask do serviço
        await _firestoreService.addTask(widget.userData.uid, task);
      }
      debugPrint(
          "GoalDetailScreen: ${tasksToAdd.length} tasks adicionadas via FirestoreService.");

      if (mounted) {
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
  // --- FIM DA ATUALIZAÇÃO ---
  // ---

  // --- INÍCIO DA CORREÇÃO (Refatoração Dia Pessoal) ---
  /// Calcula o Dia Pessoal para uma data específica.
  /// Retorna null se os dados do usuário não estiverem disponíveis ou a data for nula.
  int? _calculatePersonalDay(DateTime? date) {
    if (widget.userData.dataNasc.isEmpty ||
        widget.userData.nomeAnalise.isEmpty ||
        date == null) {
      return null; // Retorna nulo se não pode calcular
    }

    final engine = NumerologyEngine(
      nomeCompleto: widget.userData.nomeAnalise,
      dataNascimento: widget.userData.dataNasc,
    );

    try {
      // Garante que estamos usando UTC
      final dateUtc = date.toUtc();
      final day = engine.calculatePersonalDayForDate(dateUtc);
      return (day > 0) ? day : null;
    } catch (e) {
      return null;
    }
  }
  // --- FIM DA CORREÇÃO ---

  // --- INÍCIO DA MUDANÇA (Swipe Actions) ---
  // Swipe Left: Excluir Tarefa
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
        return true; // Confirma a exclusão visual
      } catch (e) {
        debugPrint("Erro ao excluir marco: $e");
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

  // Swipe Right: Reagendar (Usando TaskActionService)
  Future<bool?> _handleSwipeRight(TaskModel task) async {
    await _taskActionService.rescheduleTask(
      context,
      task,
      widget.userData,
    );

    // Na tela de detalhes da meta, mostramos todos os marcos.
    // Reagendar apenas muda a data, não remove da lista.
    return false;
  }
  // --- FIM DA MUDANÇA ---

  // Build principal (Sua lógica original, sem alterações estruturais)
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
                                      // Left Column: Goal Info (Circular for Desktop)
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
                                      // Right Column: Milestones
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
                          SliverToBoxAdapter(
                            child: SizedBox(
                              height: 380, // Height for the carousel
                              child: PageView(
                                padEnds: false,
                                controller: PageController(viewportFraction: 0.92),
                                children: [
                                  Padding(
                                    padding: EdgeInsets.symmetric(
                                        horizontal: 6.0, vertical: 8.0),
                                    child: _CollapsibleGoalInfoCard(
                                      goal: _currentGoal,
                                      progress: progress,
                                      onEdit: _handleEditGoal,
                                      onDelete: _handleDeleteGoal,
                                    ),
                                  ),
                                  Padding(
                                    padding: EdgeInsets.symmetric(
                                        horizontal: 6.0, vertical: 8.0),
                                    child: GoalImageCard(
                                      goal: _currentGoal,
                                      onTap: _handleImageTap,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
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

              // Modal de Onboarding (se não houver marcos)
              if (milestones.isEmpty && !_isLoading)
                GoalOnboardingModal(
                  onAddMilestone: (String title, String? dateStr) {
                    // Converte a data string para DateTime se fornecida
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

                    // Calcula o dia pessoal
                    final dateForPersonalDay = dueDate ?? DateTime.now().toUtc();
                    final int? personalDay = _calculatePersonalDay(dateForPersonalDay);

                    // Cria o marco
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

                    // Salva no Firestore
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
                  onClose: () {
                    // O modal se fecha sozinho, não precisa fazer nada
                  },
                  userData: widget.userData,
                  // Só mostra botão de IA se o usuário tiver plano premium (Sinergia)
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

  // --- Widgets de Build (Seus originais, sem alterações) ---
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
                debugPrint("Erro ao atualizar conclusão do marco: $e");
                if (mounted) {
                  messenger.showSnackBar(
                    SnackBar(
                        content: Text('Erro ao atualizar marco: $e'),
                        backgroundColor: Colors.red),
                  );
                }
              }
            },
            onTap: () => _handleMilestoneTap(task),
            // Callbacks de Swipe
            onSwipeLeft: _handleSwipeLeft,
            onSwipeRight: _handleSwipeRight,
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
                  debugPrint("Erro ao atualizar conclusão do marco: $e");
                  if (mounted) {
                    messenger.showSnackBar(
                      SnackBar(
                          content: Text('Erro ao atualizar marco: $e'),
                          backgroundColor: Colors.red),
                    );
                  }
                }
              },
              onTap: () => _handleMilestoneTap(task),
              // Callbacks de Swipe
              onSwipeLeft: _handleSwipeLeft,
              onSwipeRight: _handleSwipeRight,
            ),
            );
          },
          childCount: milestones.length,
        ),
      ),
    );
  }
}

class _CollapsibleGoalInfoCard extends StatefulWidget {
  final Goal goal;
  final int progress;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const _CollapsibleGoalInfoCard({
    required this.goal,
    required this.progress,
    this.onEdit,
    this.onDelete,
  });

  @override
  State<_CollapsibleGoalInfoCard> createState() =>
      _CollapsibleGoalInfoCardState();
}

class _CollapsibleGoalInfoCardState extends State<_CollapsibleGoalInfoCard>
    with SingleTickerProviderStateMixin {
  bool _isExpanded = true;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          onTap: () {
            setState(() {
              _isExpanded = !_isExpanded;
            });
          },
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: EdgeInsets.symmetric(
              vertical: _isExpanded ? 8.0 : 0,
              horizontal: 4.0,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _isExpanded ? 'Ocultar Detalhes' : 'Ver Detalhes',
                  style: const TextStyle(
                      color: AppColors.primary, fontWeight: FontWeight.bold),
                ),
                Icon(
                  _isExpanded
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  color: AppColors.primary,
                ),
              ],
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          child: _isExpanded
              ? _GoalInfoCard(
                  goal: widget.goal,
                  progress: widget.progress,
                  onEdit: widget.onEdit,
                  onDelete: widget.onDelete,
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}

// Widget _GoalInfoCard (Retangular - Mobile)
class _GoalInfoCard extends StatelessWidget {
  final Goal goal;
  final int progress;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const _GoalInfoCard({
    required this.goal,
    required this.progress,
    this.onEdit,
    this.onDelete,
  });

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
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Title + Menu
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(goal.title,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold)),
              ),
              if (onEdit != null || onDelete != null)
                PopupMenuButton<String>(
                  icon: const Icon(
                    Icons.more_vert,
                    color: AppColors.secondaryText,
                    size: 20,
                  ),
                  tooltip: 'Opções',
                  color: AppColors.cardBackground,
                  position: PopupMenuPosition.under,
                  itemBuilder: (context) {
                    final items = <PopupMenuEntry<String>>[];
                    if (onEdit != null) {
                      items.add(const PopupMenuItem<String>(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit_outlined, size: 18, color: Colors.white),
                            SizedBox(width: 8),
                            Text('Editar',
                                style: TextStyle(color: Colors.white)),
                          ],
                        ),
                      ));
                    }
                    if (onDelete != null) {
                      items.add(const PopupMenuItem<String>(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                            SizedBox(width: 8),
                            Text('Excluir',
                                style: TextStyle(color: Colors.white)),
                          ],
                        ),
                      ));
                    }
                    return items;
                  },
                  onSelected: (value) {
                    if (value == 'edit' && onEdit != null) {
                      onEdit!();
                    } else if (value == 'delete' && onDelete != null) {
                      onDelete!();
                    }
                  },
                ),
            ],
          ),
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
              Text('$progress%',
                  style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 14)),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: progress / 100.0,
            backgroundColor: AppColors.background.withValues(alpha: 0.7),
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

// Widget _CircularGoalInfoCard (Circular - Desktop)
class _CircularGoalInfoCard extends StatelessWidget {
  final Goal goal;
  final int progress;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const _CircularGoalInfoCard({
    required this.goal,
    required this.progress,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    String formattedDate = goal.targetDate != null
        ? DateFormat('dd MMM yyyy', 'pt_BR').format(goal.targetDate!)
        : 'Sem prazo';

    return Container(
      width: double.infinity, // Garante largura total disponível
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 32), // Padding ajustado
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Content
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12), // Espaçamento menor no topo
              // Circular Progress
              SizedBox(
                height: 180,
                width: 180,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CircularProgressIndicator(
                      value: progress / 100.0,
                      strokeWidth: 12,
                      backgroundColor: AppColors.background,
                      color: AppColors.primary,
                      strokeCap: StrokeCap.round,
                    ),
                    Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '$progress%',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          if (goal.targetDate != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.calendar_today,
                                      size: 12, color: AppColors.primary),
                                  const SizedBox(width: 4),
                                  Text(
                                    formattedDate,
                                    style: const TextStyle(
                                      color: AppColors.primary,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Text(
                  goal.title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (goal.description.isNotEmpty) ...[
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Text(
                    goal.description,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.secondaryText,
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ],
          ),
          
          // Menu Button (Absolute Position top-right)
          if (onEdit != null || onDelete != null)
            Positioned(
              top: 0,
              right: 0,
              child: PopupMenuButton<String>(
                icon: const Icon(
                  Icons.more_vert,
                  color: AppColors.secondaryText,
                  size: 20,
                ),
                tooltip: 'Opções',
                color: AppColors.cardBackground,
                position: PopupMenuPosition.under,
                itemBuilder: (context) {
                  final items = <PopupMenuEntry<String>>[];
                  if (onEdit != null) {
                    items.add(const PopupMenuItem<String>(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit_outlined,
                              size: 18, color: Colors.white),
                          SizedBox(width: 8),
                          Text('Editar',
                              style: TextStyle(color: Colors.white)),
                        ],
                      ),
                    ));
                  }
                  if (onDelete != null) {
                    items.add(const PopupMenuItem<String>(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline,
                              size: 18, color: Colors.redAccent),
                          SizedBox(width: 8),
                          Text('Excluir',
                              style: TextStyle(color: Colors.white)),
                        ],
                      ),
                    ));
                  }
                  return items;
                },
                onSelected: (value) {
                  if (value == 'edit' && onEdit != null) {
                    onEdit!();
                  } else if (value == 'delete' && onDelete != null) {
                    onDelete!();
                  }
                },
              ),
            ),
        ],
      ),
    );
  }
}
