// lib/features/tasks/presentation/widgets/goal_selection_modal.dart
import 'package:flutter/material.dart';
import 'package:sincro_app_flutter/common/constants/app_colors.dart';
import 'package:sincro_app_flutter/features/goals/models/goal_model.dart';
import 'package:sincro_app_flutter/services/supabase_service.dart';
// REMOVIDO: Sanitizer não é mais necessário aqui
// REMOVIDO: Tela de criação não é mais chamada daqui

class GoalSelectionModal extends StatefulWidget {
  final String userId;

  // --- INÍCIO DA MUDANÇA ---
  // onGoalSelected foi removido. O modal retornará o valor via pop().
  // --- FIM DA MUDANÇA ---

  const GoalSelectionModal({
    super.key,
    required this.userId,
    // required this.onGoalSelected, // Removido
  });

  @override
  State<GoalSelectionModal> createState() => _GoalSelectionModalState();
}

class _GoalSelectionModalState extends State<GoalSelectionModal> {
  late Future<List<Goal>> _goalsFuture;
  final SupabaseService _supabaseService = SupabaseService();

  // --- REMOVIDO: Toda a lógica de criação de meta foi removida daqui ---
  // bool _isCreatingNewGoal = false;
  // ... etc ...

  @override
  void initState() {
    super.initState();
    _loadGoals();
  }

  void _loadGoals() {
    _goalsFuture = _supabaseService.getActiveGoals(widget.userId);
  }

  // --- REMOVIDO: dispose, _handleCreateGoal ---

  Widget _buildGoalList() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // --- Item para Criar Nova Jornada (Atualizado) ---
        Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              splashColor: AppColors.primary.withValues(alpha: 0.2),
              hoverColor: AppColors.primary.withValues(alpha: 0.1),
              onTap: () {
                // --- INÍCIO DA MUDANÇA ---
                // Retorna uma string especial para sinalizar a criação
                Navigator.of(context).pop('_CREATE_NEW_GOAL_');
                // --- FIM DA MUDANÇA ---
              },
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Icon(Icons.add_circle_outline, color: AppColors.primary),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Criar nova Jornada',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        // --- Lista de Jornadas Existentes ---
        FutureBuilder<List<Goal>>(
          future: _goalsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                  child: CircularProgressIndicator(color: AppColors.primary));
            }
            if (snapshot.hasError ||
                !snapshot.hasData ||
                snapshot.data!.isEmpty) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    'Nenhuma jornada encontrada. Crie sua primeira!',
                    style: TextStyle(color: AppColors.secondaryText),
                  ),
                ),
              );
            }

            final goals = snapshot.data!;
            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              itemCount: goals.length,
              separatorBuilder: (context, index) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final goal = goals[index];
                return Container(
                  decoration: BoxDecoration(
                    color: AppColors.background.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      splashColor: AppColors.primary.withValues(alpha: 0.2),
                      hoverColor: AppColors.primary.withValues(alpha: 0.1),
                      onTap: () {
                        // --- INÍCIO DA MUDANÇA ---
                        // Retorna o objeto Goal completo
                        Navigator.of(context).pop(goal);
                        // --- FIM DA MUDANÇA ---
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        child: Row(
                          children: [
                            const Icon(Icons.flag_outlined,
                                color: AppColors.secondaryText),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                goal.title, // Exibe o título original
                                style: const TextStyle(
                                  color: AppColors.primaryText,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }

  // --- REMOVIDO: _buildCreateGoalForm ---

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      padding: EdgeInsets.fromLTRB(
          16, 8, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
      decoration: const BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24.0),
          topRight: Radius.circular(24.0),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Header (Standardized)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close,
                      color: AppColors.secondaryText, size: 24),
                  tooltip: 'Cancelar',
                ),
                const Expanded(
                  child: Text(
                    'Selecionar Jornada',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.primaryText,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                // Empty icon for balance
                const SizedBox(width: 48),
              ],
            ),
          ),
          // Conteúdo rolável
          Flexible(
            child: SingleChildScrollView(
              // --- REMOVIDO: AnimatedSwitcher ---
              child: _buildGoalList(),
            ),
          ),
        ],
      ),
    );
  }
}
