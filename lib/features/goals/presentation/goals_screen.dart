import 'package:flutter/material.dart';
import 'package:sincro_app_flutter/common/constants/app_colors.dart';
import 'package:sincro_app_flutter/common/widgets/custom_loading_spinner.dart';
import 'package:sincro_app_flutter/features/authentication/data/auth_repository.dart';
import 'package:sincro_app_flutter/features/goals/models/goal_model.dart';
import 'package:sincro_app_flutter/features/goals/presentation/create_goal_screen.dart';
import 'package:sincro_app_flutter/features/goals/presentation/goal_detail_screen.dart';
// IMPORT ADICIONADO
import 'package:sincro_app_flutter/features/goals/presentation/widgets/create_goal_dialog.dart';
import 'package:sincro_app_flutter/features/goals/presentation/widgets/goal_card.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:sincro_app_flutter/models/user_model.dart';
import 'package:sincro_app_flutter/services/firestore_service.dart';
import 'package:sincro_app_flutter/features/assistant/widgets/expanding_assistant_fab.dart';
import 'package:sincro_app_flutter/features/assistant/presentation/assistant_panel.dart';
import 'package:sincro_app_flutter/models/subscription_model.dart';

class GoalsScreen extends StatefulWidget {
  final UserModel userData;
  const GoalsScreen({super.key, required this.userData});

  @override
  State<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends State<GoalsScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final String _userId = AuthRepository().getCurrentUser()?.uid ?? '';

  static const double kDesktopBreakpoint = 768.0;

  @override
  void initState() {
    super.initState();
    if (_userId.isEmpty) {
      debugPrint("GoalsScreen: Erro crítico - UID do usuário não encontrado!");
    }
  }

  // *** MÉTODO ATUALIZADO PARA LIDAR COM DESKTOP/MOBILE ***
  void _navigateToCreateGoal([Goal? goalToEdit]) {
    if (!mounted) return;

    final bool isDesktop =
        MediaQuery.of(context).size.width >= kDesktopBreakpoint;

    if (isDesktop) {
      final messenger = ScaffoldMessenger.of(context);
      // --- VERSÃO DESKTOP: CHAMA O DIÁLOGO ---
      showDialog(
        context: context,
        barrierDismissible: false, // Impede fechar clicando fora
        builder: (BuildContext dialogContext) {
          return CreateGoalDialog(
            userData: widget.userData,
            goalToEdit: goalToEdit,
          );
        },
      ).then((result) {
        if (result == true) {
          if (!mounted) return;
          // Meta salva com sucesso, opcionalmente mostrar um SnackBar
          messenger.showSnackBar(
            SnackBar(
              content: Text(goalToEdit != null
                  ? "Jornada atualizada com sucesso!"
                  : "Nova jornada criada com sucesso!"),
              backgroundColor: AppColors.primary,
            ),
          );
        }
      });
    } else {
      // --- VERSÃO MOBILE: CHAMA A TELA CHEIA ---
      Navigator.of(context).push(MaterialPageRoute(
        builder: (context) => CreateGoalScreen(
          userData: widget.userData,
          goalToEdit: goalToEdit,
        ),
        fullscreenDialog: true,
      ));
    }
  }

  void _navigateToGoalDetail(Goal goal) {
    if (!mounted) return;
    try {
      Navigator.of(context).push(MaterialPageRoute(
        builder: (context) => GoalDetailScreen(
          initialGoal: goal,
          userData: widget.userData,
        ),
      ));
    } catch (e, s) {
      debugPrint("GoalsScreen: ERRO durante Navigator.push: $e");
      debugPrint("GoalsScreen: StackTrace: $s");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Erro ao abrir detalhes da meta: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // *** NOVO MÉTODO PARA DELETAR JORNADA ***
  Future<void> _handleDeleteGoal(BuildContext context, Goal goal) async {
    final messenger = ScaffoldMessenger.of(context);
    // 1. Mostrar diálogo de confirmação
    final bool? confirmDelete = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.cardBackground,
          title: const Text('Confirmar Exclusão',
              style: TextStyle(color: AppColors.primaryText)),
          content: Text(
              'Tem certeza que deseja excluir a jornada "${goal.title}"? Esta ação não pode ser desfeita.',
              style: const TextStyle(color: AppColors.secondaryText)),
          actions: [
            TextButton(
              child: const Text('Cancelar',
                  style: TextStyle(color: AppColors.secondaryText)),
              onPressed: () => Navigator.of(dialogContext).pop(false),
            ),
            TextButton(
              child:
                  Text('Excluir', style: TextStyle(color: Colors.red.shade400)),
              onPressed: () => Navigator.of(dialogContext).pop(true),
            ),
          ],
        );
      },
    );

    // 2. Se confirmado, deletar do Firestore
    if (confirmDelete == true) {
      try {
        await _firestoreService.deleteGoal(_userId, goal.id);
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Jornada excluída com sucesso.'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        debugPrint("Erro ao deletar meta: $e");
        messenger.showSnackBar(
          SnackBar(
            content: Text('Erro ao excluir jornada: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_userId.isEmpty) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
            child: Text("Erro: Usuário não identificado.",
                style: TextStyle(color: Colors.red))),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final bool isDesktop = constraints.maxWidth >= kDesktopBreakpoint;
            final double horizontalPadding = isDesktop ? 24.0 : 12.0;

            return Padding(
              padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  Expanded(
                    child: StreamBuilder<List<Goal>>(
                      stream: _firestoreService.getGoalsStream(_userId),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
      body: ScreenInteractionListener(
        controller: _fabOpacityController,
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final bool isDesktop = constraints.maxWidth >= kDesktopBreakpoint;
              final double horizontalPadding = isDesktop ? 24.0 : 12.0;

              return Padding(
                padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(),
                    Expanded(
                      child: StreamBuilder<List<Goal>>(
                        stream: _firestoreService.getGoalsStream(_userId),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                                  ConnectionState.waiting &&
                              !snapshot.hasData) {
                            return const Center(child: CustomLoadingSpinner());
                          }
                          if (snapshot.hasError) {
                            debugPrint(
                                "GoalsScreen: Erro no Stream de Metas: ${snapshot.error}");
                            return Center(
                                child: Text(
                                    'Erro ao carregar jornadas: ${snapshot.error}',
                                    style: const TextStyle(color: Colors.red)));
                          }
                          if (!snapshot.hasData || snapshot.data!.isEmpty) {
                            return _buildEmptyState();
                          }

                          final goals = snapshot.data!;

                          // Desktop: Masonry grid no estilo do Diário e Dashboard
                          if (isDesktop) {
                            // 2 colunas para 900-1400px, 3 para telas maiores
                            final int columns =
                                constraints.maxWidth >= 1200 ? 3 : 2;
                            return MasonryGridView.count(
                              padding: const EdgeInsets.only(top: 8, bottom: 100),
                              crossAxisCount: columns,
                              mainAxisSpacing: 16,
                              crossAxisSpacing: 16,
                              itemCount: goals.length,
                              itemBuilder: (context, index) {
                                final goal = goals[index];
                                return GoalCard(
                                  goal: goal,
                                  userId: _userId,
                                  onTap: () => _navigateToGoalDetail(goal),
                                  onDelete: () =>
                                      _handleDeleteGoal(context, goal),
                                  onEdit: () => _navigateToCreateGoal(goal),
                                );
                              },
                            );
                          }
                          // Mobile: lista vertical simples
                          else {
                            return ListView.builder(
                              padding: const EdgeInsets.only(top: 8, bottom: 100),
                              itemCount: goals.length,
                              itemBuilder: (context, index) {
                                final goal = goals[index];
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 12.0),
                                  child: GoalCard(
                                    goal: goal,
                                    userId: _userId,
                                    onTap: () => _navigateToGoalDetail(goal),
                                    onDelete: () =>
                                        _handleDeleteGoal(context, goal),
                                    onEdit: () => _navigateToCreateGoal(goal),
                                  ),
                                );
                              },
                            );
                          }
                        },
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
      floatingActionButton: TransparentFabWrapper(
        controller: _fabOpacityController,
        child: (widget.userData.subscription.isActive &&
                widget.userData.subscription.plan == SubscriptionPlan.premium)
            ? ExpandingAssistantFab(
                onPrimary:
                    _navigateToCreateGoal, // Chama screen ou dialog conforme plataforma
                primaryIcon: Icons.flag_outlined, // Ícone de meta
                primaryTooltip: 'Nova Jornada',
                onOpenAssistant: () {
                  AssistantPanel.show(context, widget.userData);
                },
              )
            : FloatingActionButton(
                onPressed: _navigateToCreateGoal,
                backgroundColor: AppColors.primary,
                tooltip: 'Nova Jornada',
                heroTag: 'fab_goals_screen',
                child: const Icon(Icons.add, color: Colors.white),
              ),
      ),
    );
  }

  Widget _buildHeader() {
    return const Padding(
      padding: EdgeInsets.only(top: 16, bottom: 16),
      child: Text(
        // --- INÍCIO DA CORREÇÃO (Título) ---
        'Metas', // Alterado de 'Meta' para 'Metas'
        // --- FIM DA CORREÇÃO ---
        style: TextStyle(
          color: Colors.white,
          fontSize: 28,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.flag_outlined,
              color: AppColors.tertiaryText,
              size: 48,
            ),
            SizedBox(height: 16),
            Text(
              'Nenhuma jornada iniciada',
              style: TextStyle(
                color: AppColors.secondaryText,
                fontSize: 18,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Crie sua primeira jornada para começar a evoluir.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.tertiaryText),
            ),
          ],
        ),
      ),
    );
  }
}
