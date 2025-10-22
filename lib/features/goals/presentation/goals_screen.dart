// lib/features/goals/presentation/goals_screen.dart

import 'package:flutter/foundation.dart'; // NECESSÁRIO PARA debugPrint
import 'package:flutter/material.dart';
import 'package:sincro_app_flutter/common/constants/app_colors.dart';
import 'package:sincro_app_flutter/common/widgets/custom_loading_spinner.dart';
import 'package:sincro_app_flutter/features/authentication/data/auth_repository.dart'; // Necessário para obter UID
import 'package:sincro_app_flutter/features/goals/models/goal_model.dart';
import 'package:sincro_app_flutter/features/goals/presentation/create_goal_screen.dart'; // Tela de criação
import 'package:sincro_app_flutter/features/goals/presentation/goal_detail_screen.dart'; // Tela de detalhe
import 'package:sincro_app_flutter/features/goals/presentation/widgets/goal_card.dart'; // Widget do Card
import 'package:sincro_app_flutter/models/user_model.dart';
import 'package:sincro_app_flutter/services/firestore_service.dart';

class GoalsScreen extends StatefulWidget {
  final UserModel userData;
  const GoalsScreen({super.key, required this.userData});

  @override
  State<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends State<GoalsScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  // Obtém o UID do usuário logado de forma segura
  final String _userId = AuthRepository().getCurrentUser()?.uid ?? '';

  static const double kDesktopBreakpoint = 768.0;

  @override
  void initState() {
    super.initState();
    // Verifica se o _userId é válido no início
    if (_userId.isEmpty) {
      // TODO: Tratar caso onde o usuário não está logado ou UID é inválido
      // Ex: Redirecionar para login ou mostrar mensagem de erro.
      debugPrint("GoalsScreen: Erro crítico - UID do usuário não encontrado!");
    }
  }

  void _navigateToCreateGoal() {
    // Verifica se o contexto ainda é válido
    if (!mounted) return;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (context) => CreateGoalScreen(userData: widget.userData),
      fullscreenDialog: true, // Abre como um modal
    ));
  }

  void _navigateToGoalDetail(Goal goal) {
    if (!mounted) return;
    // --- LOG ANTES DA NAVEGAÇÃO ---
    debugPrint(
        "GoalsScreen: Navegando para GoalDetailScreen com Goal ID: ${goal.id}");
    debugPrint("GoalsScreen: Título da Meta: ${goal.title}");
    debugPrint("GoalsScreen: UserData UID: ${widget.userData.uid}");
    try {
      Navigator.of(context).push(MaterialPageRoute(
        builder: (context) => GoalDetailScreen(
          initialGoal: goal,
          userData: widget.userData, // Passando userData
        ),
      ));
      // --- LOG DEPOIS DA NAVEGAÇÃO (só aparecerá se a navegação em si não crashar) ---
      debugPrint(
          "GoalsScreen: Navegação para GoalDetailScreen iniciada com sucesso.");
    } catch (e, s) {
      debugPrint("GoalsScreen: ERRO durante Navigator.push: $e");
      debugPrint("GoalsScreen: StackTrace: $s");
      // Mostra um erro para o usuário se a navegação falhar
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Erro ao abrir detalhes da meta: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Se userId for inválido, mostra um estado de erro ou vazio
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
              // Padding geral da tela
              padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(), // Título "Jornadas"
                  Expanded(
                    // StreamBuilder para ouvir as metas do Firestore
                    child: StreamBuilder<List<Goal>>(
                      // Usa o _userId validado
                      stream: _firestoreService.getGoalsStream(_userId),
                      builder: (context, snapshot) {
                        // Estado de carregamento inicial
                        if (snapshot.connectionState ==
                                ConnectionState.waiting &&
                            !snapshot.hasData) {
                          return const Center(child: CustomLoadingSpinner());
                        }
                        // Estado de erro no stream
                        if (snapshot.hasError) {
                          debugPrint(
                              "GoalsScreen: Erro no Stream de Metas: ${snapshot.error}");
                          return Center(
                              child: Text(
                                  'Erro ao carregar jornadas: ${snapshot.error}',
                                  style: const TextStyle(color: Colors.red)));
                        }
                        // Estado sem dados ou lista vazia
                        if (!snapshot.hasData || snapshot.data!.isEmpty) {
                          return _buildEmptyState(); // Mostra mensagem "Nenhuma jornada"
                        }

                        // Dados recebidos com sucesso
                        final goals = snapshot.data!;
                        debugPrint(
                            "GoalsScreen: StreamBuilder reconstruído com ${goals.length} metas.");

                        // Layout em Grid para Desktop
                        if (isDesktop) {
                          // Calcula quantas colunas cabem, no mínimo 1, no máximo 4
                          int crossAxisCount =
                              (constraints.maxWidth / 350).floor().clamp(1, 4);
                          return GridView.builder(
                            padding: const EdgeInsets.only(
                                top: 8, bottom: 80), // Espaço para FAB
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: crossAxisCount,
                              crossAxisSpacing: 16,
                              mainAxisSpacing: 16,
                              childAspectRatio:
                                  1.9, // Ajusta altura relativa do card
                            ),
                            itemCount: goals.length,
                            itemBuilder: (context, index) {
                              final goal = goals[index];
                              debugPrint(
                                  "GoalsScreen: Construindo GoalCard (Grid) para ID: ${goal.id}");
                              return GoalCard(
                                goal: goal,
                                onTap: () => _navigateToGoalDetail(
                                    goal), // Navega ao clicar
                              );
                            },
                          );
                        }
                        // Layout em Lista para Mobile
                        else {
                          return ListView.builder(
                            padding: const EdgeInsets.only(
                                top: 8, bottom: 80), // Espaço para FAB
                            itemCount: goals.length,
                            itemBuilder: (context, index) {
                              final goal = goals[index];
                              debugPrint(
                                  "GoalsScreen: Construindo GoalCard (List) para ID: ${goal.id}");
                              return Padding(
                                // Adiciona padding entre os cards na lista
                                padding: const EdgeInsets.only(bottom: 12.0),
                                child: GoalCard(
                                  goal: goal,
                                  onTap: () => _navigateToGoalDetail(
                                      goal), // Navega ao clicar
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
      // Botão Flutuante para criar nova meta
      floatingActionButton: FloatingActionButton(
        onPressed: _navigateToCreateGoal,
        backgroundColor: AppColors.primary,
        tooltip: 'Nova Jornada',
        // Tag única para este FAB para evitar conflito de Hero
        heroTag: 'fab_goals_screen',
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  // Widget para o título "Jornadas"
  Widget _buildHeader() {
    return const Padding(
      padding: EdgeInsets.only(top: 16, bottom: 16), // Espaçamento vertical
      child: Text(
        'Jornadas',
        style: TextStyle(
          color: Colors.white,
          fontSize: 28, // Tamanho maior
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  // Widget para estado vazio (sem metas)
  Widget _buildEmptyState() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400), // Limita largura
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.flag_outlined,
              color: AppColors.tertiaryText,
              size: 48,
            ),
            const SizedBox(height: 16),
            const Text(
              'Nenhuma jornada iniciada',
              style: TextStyle(
                color: AppColors.secondaryText,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Crie sua primeira jornada para começar a evoluir.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.tertiaryText),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _navigateToCreateGoal, // Botão para criar
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text(
                'Criar Jornada',
                style:
                    TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}
