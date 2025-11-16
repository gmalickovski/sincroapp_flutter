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
  // Já temos a instância do FirestoreService aqui!
  final FirestoreService _firestoreService = FirestoreService();
  bool _isLoading = false;
  static const double kDesktopBreakpoint = 768.0;
  static const double kMaxContentWidth = 800.0;

  // Função para adicionar novo marco (Atualizada na Turn 14 para usar nova assinatura)
  void _addMilestone() {
    if (widget.userData.uid.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erro: ID do usuário não encontrado.')));
      return;
    }

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
              ScaffoldMessenger.of(context).showSnackBar(
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

  // Função _openAiSuggestions (Sua original)
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

  // Build principal (Sua lógica original, sem alterações estruturais)
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<TaskModel>>(
      stream: _firestoreService.getTasksForGoalStream(
          widget.userData.uid, widget.initialGoal.id),
      builder: (context, snapshot) {
        // ... (resto do seu build, _buildMilestonesHeader, _buildMilestonesListWidget, _buildMilestonesListSliver, _GoalInfoCard permanecem inalterados) ...
        // --- (Código omitido para brevidade, pois não foi alterado) ---
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
                                        child: _GoalInfoCard(
                                            goal: widget.initialGoal,
                                            progress: progress)))
                                : _GoalInfoCard(
                                    goal: widget.initialGoal,
                                    progress: progress),
                          ),
                        ),
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.fromLTRB(horizontalPadding,
                                24.0, horizontalPadding, 16.0),
                            child: isDesktop
                                ? Center(
                                    child: ConstrainedBox(
                                        constraints: const BoxConstraints(
                                            maxWidth: kMaxContentWidth),
                                        child: _buildMilestonesHeader()))
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
                                        horizontalPadding: 0),
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
                    color: Colors.black.withValues(alpha: 0.6),
                    child: const Center(child: CustomLoadingSpinner())),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: _addMilestone, // Chama a função atualizada
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
          return TaskItem(
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
                debugPrint("Erro ao atualizar conclusão do marco: $e");
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text('Erro ao atualizar marco: $e'),
                        backgroundColor: Colors.red),
                  );
                }
              }
            },
            onTap: () => _handleMilestoneTap(task),
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
              showGoalIconFlag: false,
              showTagsIconFlag: true,
              showVibrationPillFlag: true,
              onToggle: (isCompleted) async {
                try {
                  await _firestoreService.updateTaskCompletion(
                      widget.userData.uid, task.id,
                      completed: isCompleted);
                } catch (e) {
                  debugPrint("Erro ao atualizar conclusão do marco: $e");
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: Text('Erro ao atualizar marco: $e'),
                          backgroundColor: Colors.red),
                    );
                  }
                }
              },
              onTap: () => _handleMilestoneTap(task),
            );
          },
          childCount: milestones.length,
        ),
      ),
    );
  }
}

// Widget _GoalInfoCard (Seu original)
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
            color: Colors.black.withValues(alpha: 0.15),
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
