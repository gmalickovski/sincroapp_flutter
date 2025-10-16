// lib/features/goals/presentation/goals_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:sincro_app_flutter/common/constants/app_colors.dart';
import 'package:sincro_app_flutter/common/widgets/custom_loading_spinner.dart';
import 'package:sincro_app_flutter/features/goals/models/goal_model.dart';
import 'package:sincro_app_flutter/models/user_model.dart';
import 'package:sincro_app_flutter/services/firestore_service.dart';
// ATUALIZAÇÃO: Importa o novo diálogo e a tela de detalhes
import 'widgets/create_goal_dialog.dart';
import 'goal_detail_screen.dart';

class GoalsScreen extends StatefulWidget {
  final UserModel userData;
  const GoalsScreen({super.key, required this.userData});

  @override
  State<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends State<GoalsScreen> {
  final FirestoreService _firestoreService = FirestoreService();

  void _handleDeleteGoal(Goal goal) {
    showDialog(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          backgroundColor: AppColors.cardBackground,
          title: const Text('Confirmar Exclusão',
              style: TextStyle(color: Colors.white)),
          content: const Text(
              'Tem certeza que deseja excluir esta jornada? Todas as tarefas e marcos associados serão perdidos para sempre.',
              style: TextStyle(color: AppColors.secondaryText)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child:
                  const Text('Cancelar', style: TextStyle(color: Colors.white)),
            ),
            TextButton(
              onPressed: () {
                _firestoreService.deleteGoal(widget.userData.uid, goal.id);
                Navigator.of(ctx).pop();
              },
              child:
                  Text('Excluir', style: TextStyle(color: Colors.red.shade400)),
            ),
          ],
        );
      },
    );
  }

  // ATUALIZAÇÃO: Abre o novo diálogo flutuante
  void _openCreateGoalDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return CreateGoalDialog(userData: widget.userData);
      },
    );
  }

  // ATUALIZAÇÃO: Implementa a navegação
  void _navigateToGoalDetails(Goal goal) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => GoalDetailScreen(
          initialGoal: goal,
          userData: widget.userData,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isDesktop = MediaQuery.of(context).size.width > 800;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Jornadas",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<List<Goal>>(
              stream: _firestoreService.getGoalsStream(widget.userData.uid),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CustomLoadingSpinner());
                }
                if (snapshot.hasError) {
                  return const Center(
                      child: Text("Erro ao carregar as jornadas.",
                          style: TextStyle(color: Colors.red)));
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return _buildEmptyState();
                }

                final goals = snapshot.data!;

                // ATUALIZAÇÃO: Layout com ConstrainedBox para limitar a largura no desktop
                return Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                        maxWidth: 1200), // Limita a largura máxima da grade
                    child: GridView.builder(
                      padding: const EdgeInsets.all(24).copyWith(bottom: 100),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: isDesktop ? 2 : 1,
                        crossAxisSpacing: 24,
                        mainAxisSpacing: 24,
                        mainAxisExtent: 260, // Altura fixa para os cards
                      ),
                      itemCount: goals.length,
                      itemBuilder: (context, index) {
                        final goal = goals[index];
                        return _GoalCard(
                          goal: goal,
                          isDesktop: isDesktop,
                          onTap: () => _navigateToGoalDetails(goal),
                          onDelete: () => _handleDeleteGoal(goal),
                        );
                      },
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreateGoalDialog, // Conecta a nova função
        label: const Text("Nova Jornada"),
        icon: const Icon(Icons.add),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
            color: AppColors.cardBackground.withOpacity(0.5),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border, width: 2)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.flag_outlined, color: AppColors.primary, size: 64),
            const SizedBox(height: 16),
            const Text(
              "Defina sua primeira Jornada",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              "Metas são o primeiro passo para transformar o invisível em visível.",
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.secondaryText, fontSize: 16),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _openCreateGoalDialog, // Conecta a nova função
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: const Text(
                "Criar minha primeira Jornada",
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GoalCard extends StatefulWidget {
  final Goal goal;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final bool isDesktop;

  const _GoalCard({
    required this.goal,
    required this.onTap,
    required this.onDelete,
    required this.isDesktop,
  });

  @override
  State<_GoalCard> createState() => _GoalCardState();
}

class _GoalCardState extends State<_GoalCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    String formattedDate = widget.goal.targetDate != null
        ? DateFormat('dd/MM/yyyy').format(widget.goal.targetDate!)
        : 'Sem prazo';

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _isHovered && widget.isDesktop
                  ? AppColors.primary
                  : AppColors.border,
              width: _isHovered && widget.isDesktop ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.flag_outlined,
                      color: AppColors.primary, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.goal.title,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  AnimatedOpacity(
                    opacity: _isHovered || !widget.isDesktop ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    child: IconButton(
                      icon: const Icon(Icons.delete_outline,
                          color: AppColors.secondaryText, size: 22),
                      onPressed: widget.onDelete,
                      tooltip: "Excluir Jornada",
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Text(
                  widget.goal.description,
                  style: const TextStyle(
                      color: AppColors.secondaryText, height: 1.5),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Progresso',
                          style: TextStyle(color: AppColors.secondaryText)),
                      Text('${widget.goal.progress}%',
                          style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: widget.goal.progress / 100.0,
                    backgroundColor: AppColors.border,
                    color: AppColors.primary,
                    minHeight: 6,
                    borderRadius: BorderRadius.circular(3),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      const Icon(Icons.calendar_today,
                          size: 12, color: AppColors.tertiaryText),
                      const SizedBox(width: 4),
                      Text("Alvo: $formattedDate",
                          style: const TextStyle(
                              color: AppColors.tertiaryText, fontSize: 12)),
                    ],
                  )
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
