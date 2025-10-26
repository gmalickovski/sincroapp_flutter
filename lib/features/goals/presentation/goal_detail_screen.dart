// lib/features/goals/presentation/goal_detail_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:sincro_app_flutter/common/constants/app_colors.dart';
import 'package:sincro_app_flutter/common/widgets/custom_loading_spinner.dart';
import 'package:sincro_app_flutter/features/goals/models/goal_model.dart';
import 'package:sincro_app_flutter/features/tasks/models/task_model.dart';
import 'package:sincro_app_flutter/features/tasks/presentation/widgets/task_input_modal.dart';
import 'package:sincro_app_flutter/features/tasks/presentation/widgets/task_item.dart';
// --- Import necessário para abrir o modal de detalhes ---
import 'package:sincro_app_flutter/features/tasks/presentation/widgets/task_detail_modal.dart';
// --- Fim Import ---
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

  // Função para adicionar novo marco (inalterada)
  void _addMilestone() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return TaskInputModal(
          userData: widget.userData,
          preselectedGoal: widget.initialGoal, // Pré-seleciona a jornada atual
        );
      },
    );
  }

  // --- Função para abrir o modal de detalhes da tarefa/marco ---
  void _handleMilestoneTap(TaskModel task) {
    print("Marco/Tarefa tocado: ${task.id} - ${task.text}");
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return TaskDetailModal(
          task: task,
          userData: widget.userData, // Passa os dados do usuário
        );
      },
    );
  }
  // --- Fim Função ---

  // Abrir sugestões IA (inalterada)
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

  // Adicionar sugestões como Tasks (inalterada)
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

    // Só calcula dia pessoal se tiver dados de nascimento
    NumerologyEngine? engine;
    if (widget.userData.dataNasc.isNotEmpty &&
        widget.userData.nomeAnalise.isNotEmpty) {
      engine = NumerologyEngine(
        nomeCompleto: widget.userData.nomeAnalise,
        dataNascimento: widget.userData.dataNasc,
      );
    }

    try {
      final batch = FirebaseFirestore.instance.batch();
      final tasksCollection = FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userData.uid)
          .collection('tasks'); // Coleção correta de tarefas

      for (final sug in suggestions) {
        DateTime? deadline;
        try {
          // Tenta fazer parse da data, aceitando formatos diferentes
          if (sug['date'] != null && sug['date']!.isNotEmpty) {
            // Exemplo: Se a IA retornar "YYYY-MM-DD"
            deadline = DateTime.tryParse(sug['date']!);
            // Adicione mais blocos `else if` se a IA retornar outros formatos
          }
        } catch (e) {
          debugPrint(
              "GoalDetailScreen: Erro ao fazer parse da data da IA: ${sug['date']} - $e");
          deadline = null; // Define como nulo se houver erro
        }

        int? personalDay;
        if (engine != null) {
          final dateForCalc = deadline ?? DateTime.now();
          personalDay = engine.calculatePersonalDayForDate(dateForCalc);
        }

        final newDocRef =
            tasksCollection.doc(); // Gera nova referência de documento

        final newTask = TaskModel(
          id: newDocRef.id, // Usa o ID gerado
          text: sug['title'] ?? 'Marco sem título',
          completed: false,
          createdAt: DateTime.now(),
          dueDate: deadline,
          tags: [], // Começa sem tags
          journeyId: widget.initialGoal.id, // Vincula à jornada atual
          journeyTitle: widget.initialGoal.title,
          personalDay: personalDay,
        );

        // Usa o método toFirestore() do TaskModel
        batch.set(newDocRef, newTask.toFirestore());
      }

      await batch.commit();
      debugPrint(
          "GoalDetailScreen: Batch de ${suggestions.length} tasks commitado.");

      // O progresso será atualizado pelo StreamBuilder que escuta as tarefas

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
      // Garante que o loading termine mesmo se houver erro
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<TaskModel>>(
      // Escuta o stream de tarefas filtradas por esta meta
      stream: _firestoreService.getTasksForGoalStream(
          widget.userData.uid, widget.initialGoal.id),
      builder: (context, snapshot) {
        // Tratamento de Loading e Erro (essencialmente inalterado)
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          // Mostra loading apenas na primeira carga
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

        // Obtém a lista de marcos (tarefas) do snapshot
        final milestones = snapshot.data ?? [];

        // Calcula o progresso baseado nas tarefas carregadas
        final int progress = milestones.isEmpty
            ? 0
            : (milestones.where((m) => m.completed).length /
                    milestones.length *
                    100)
                .round();

        return Scaffold(
          backgroundColor: AppColors.background,
          body: Stack(
            // Stack para o overlay de loading
            children: [
              LayoutBuilder(
                // Para responsividade Desktop/Mobile
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
                          pinned: true, // Mantém a AppBar visível
                          leading: const BackButton(color: AppColors.primary),
                          title: const Text('Detalhes da Jornada',
                              style:
                                  TextStyle(color: Colors.white, fontSize: 18)),
                        ),
                        // Card com informações da Jornada
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                                horizontal: horizontalPadding, vertical: 8.0),
                            // Centraliza e limita largura no Desktop
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
                        // Header da lista de Marcos
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.fromLTRB(horizontalPadding,
                                24.0, horizontalPadding, 16.0),
                            // Centraliza e limita largura no Desktop
                            child: isDesktop
                                ? Center(
                                    child: ConstrainedBox(
                                        constraints: const BoxConstraints(
                                            maxWidth: kMaxContentWidth),
                                        child: _buildMilestonesHeader()))
                                : _buildMilestonesHeader(),
                          ),
                        ),
                        // Lista de Marcos (Tarefas)
                        // Usa SliverList no Mobile e SliverToBoxAdapter com Column no Desktop
                        isDesktop
                            ? SliverToBoxAdapter(
                                child: Center(
                                  child: ConstrainedBox(
                                    constraints: const BoxConstraints(
                                        maxWidth: kMaxContentWidth),
                                    child: _buildMilestonesListWidget(
                                        // Chama a versão Widget
                                        milestones: milestones,
                                        horizontalPadding:
                                            0 // Padding já aplicado acima
                                        ),
                                  ),
                                ),
                              )
                            : _buildMilestonesListSliver(
                                // Chama a versão Sliver
                                milestones: milestones,
                                horizontalPadding: listHorizontalPadding),

                        // Espaço extra no final para o FloatingActionButton não cobrir o último item
                        const SliverToBoxAdapter(child: SizedBox(height: 80)),
                      ],
                    ),
                  );
                },
              ),
              // Overlay de Loading
              if (_isLoading)
                Container(
                    color: Colors.black.withOpacity(0.6),
                    child: const Center(child: CustomLoadingSpinner())),
            ],
          ),
          // Botão Flutuante para adicionar novo marco
          floatingActionButton: FloatingActionButton.extended(
            onPressed: _addMilestone,
            label: const Text('Novo Marco'),
            icon: const Icon(Icons.add),
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            heroTag: 'fab_goal_detail', // Tag única para Hero animation
          ),
        );
      },
    );
  }

  // Helper para construir o header da lista de marcos
  Widget _buildMilestonesHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'Marcos da Jornada',
          style: TextStyle(
              color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
        ),
        // Botão para Sugestões da IA
        TextButton.icon(
          onPressed: _openAiSuggestions,
          icon: const Icon(Icons.auto_awesome, // Ícone de "brilho"
              color: AppColors.primary,
              size: 20),
          label: const Text('Sugerir com IA',
              style: TextStyle(color: AppColors.primary, fontSize: 14)),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            tapTargetSize:
                MaterialTapTargetSize.shrinkWrap, // Reduz área de toque
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          ),
        ),
      ],
    );
  }

  // Helper para construir a lista de marcos como um Widget (para Desktop)
  Widget _buildMilestonesListWidget(
      {required List<TaskModel> milestones,
      required double horizontalPadding}) {
    if (milestones.isEmpty) {
      // Mensagem de estado vazio
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

    // Constrói a lista usando Column e List.generate
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
      child: Column(
        children: List.generate(milestones.length, (index) {
          final task = milestones[index];
          // --- MUDANÇA: Passa onTap e remove outros callbacks ---
          return TaskItem(
            key: ValueKey(task.id), // Key para performance
            task: task,
            showGoalIconFlag: false, // Não precisa mostrar o ícone da meta aqui
            showTagsIconFlag: true, // Mostra se tem tags
            showVibrationPillFlag: true, // Mostra dia pessoal
            onToggle: (isCompleted) async {
              try {
                await _firestoreService.updateTaskCompletion(
                    widget.userData.uid, task.id,
                    completed: isCompleted);
                // O StreamBuilder vai reconstruir e atualizar o progresso
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
            onTap: () =>
                _handleMilestoneTap(task), // Chama a função de abrir detalhes
          );
          // --- FIM MUDANÇA ---
        }),
      ),
    );
  }

  // Helper para construir a lista de marcos como um Sliver (para Mobile)
  Widget _buildMilestonesListSliver(
      {required List<TaskModel> milestones,
      required double horizontalPadding}) {
    if (milestones.isEmpty) {
      // Mensagem de estado vazio (como Sliver)
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

    // Constrói a lista usando SliverList
    return SliverPadding(
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final task = milestones[index];
            // --- MUDANÇA: Passa onTap e remove outros callbacks ---
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
              onTap: () =>
                  _handleMilestoneTap(task), // Chama a função de abrir detalhes
            );
            // --- FIM MUDANÇA ---
          },
          childCount: milestones.length,
        ),
      ),
    );
  }
} // Fim _GoalDetailScreenState

// Widget _GoalInfoCard (inalterado)
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
