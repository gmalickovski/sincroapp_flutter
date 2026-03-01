// lib/features/tasks/presentation/widgets/goal_selection_modal.dart
import 'package:flutter/material.dart';
import 'package:sincro_app_flutter/common/constants/app_colors.dart';
import 'package:sincro_app_flutter/features/goals/models/goal_model.dart';
import 'package:sincro_app_flutter/services/supabase_service.dart';

class GoalSelectionModal extends StatefulWidget {
  final String userId;

  const GoalSelectionModal({
    super.key,
    required this.userId,
  });

  @override
  State<GoalSelectionModal> createState() => _GoalSelectionModalState();
}

class _GoalSelectionModalState extends State<GoalSelectionModal> {
  late Future<List<Goal>> _goalsFuture;
  final SupabaseService _supabaseService = SupabaseService();

  Goal? _tempSelectedGoal;
  bool _createNewSelected = false;

  @override
  void initState() {
    super.initState();
    _loadGoals();
  }

  void _loadGoals() {
    _goalsFuture = _supabaseService.getActiveGoals(widget.userId);
  }

  Widget _buildGoalList() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // --- Item para Criar Nova Jornada ---
        Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: _createNewSelected
                ? AppColors.goalTaskMarker.withValues(alpha: 0.2)
                : AppColors.goalTaskMarker.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
            border: _createNewSelected
                ? Border.all(color: AppColors.goalTaskMarker, width: 2)
                : Border.all(color: Colors.transparent, width: 2),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              splashColor: AppColors.goalTaskMarker.withValues(alpha: 0.2),
              hoverColor: AppColors.goalTaskMarker.withValues(alpha: 0.1),
              onTap: () {
                setState(() {
                  _createNewSelected = true;
                  _tempSelectedGoal = null;
                });
              },
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Icon(Icons.add_circle_outline, color: AppColors.goalTaskMarker),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Criar nova Jornada',
                        style: TextStyle(
                          color: AppColors.goalTaskMarker,
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
                final isSelected = _tempSelectedGoal?.id == goal.id;

                return Container(
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.goalTaskMarker.withValues(alpha: 0.2)
                        : AppColors.background.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12),
                    border: isSelected
                        ? Border.all(color: AppColors.goalTaskMarker, width: 2)
                        : Border.all(color: Colors.transparent, width: 2),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      splashColor: AppColors.primary.withValues(alpha: 0.2),
                      hoverColor: AppColors.primary.withValues(alpha: 0.1),
                      onTap: () {
                        setState(() {
                          if (_tempSelectedGoal?.id == goal.id) {
                            _tempSelectedGoal = null;
                          } else {
                            _tempSelectedGoal = goal;
                          }
                          _createNewSelected = false;
                        });
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        child: Row(
                          children: [
                            Icon(Icons.flag_outlined,
                                color: isSelected ? AppColors.goalTaskMarker : AppColors.secondaryText),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                goal.title, // Exibe o título original
                                style: TextStyle(
                                  color: isSelected ? AppColors.goalTaskMarker : AppColors.primaryText,
                                  fontSize: 16,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
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

  Widget _buildFooter() {
    if (_tempSelectedGoal != null || _createNewSelected) {
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 48,
                child: OutlinedButton(
                  onPressed: () {
                    setState(() {
                      _tempSelectedGoal = null;
                      _createNewSelected = false;
                    });
                    Navigator.of(context).pop(null);
                  },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    side: const BorderSide(color: AppColors.border),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text("Limpar",
                      style: TextStyle(
                          color: AppColors.secondaryText,
                          fontFamily: 'Poppins')),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: (_tempSelectedGoal != null || _createNewSelected)
                      ? () {
                          if (_createNewSelected) {
                            Navigator.of(context).pop('_CREATE_NEW_GOAL_');
                          } else {
                            Navigator.of(context).pop(_tempSelectedGoal);
                          }
                        }
                      : null,
                  style: ButtonStyle(
                    backgroundColor: WidgetStateProperty.resolveWith<Color>((states) {
                      if (states.contains(WidgetState.disabled)) {
                        return AppColors.border;
                      }
                      return AppColors.goalTaskMarker;
                    }),
                    foregroundColor: WidgetStateProperty.resolveWith<Color>((states) {
                      if (states.contains(WidgetState.disabled)) {
                        return AppColors.secondaryText;
                      }
                      return Colors.white;
                    }),
                    elevation: WidgetStateProperty.resolveWith<double>((states) => 0),
                    padding: WidgetStateProperty.resolveWith<EdgeInsetsGeometry>(
                        (states) => const EdgeInsets.symmetric(vertical: 12)),
                    shape: WidgetStateProperty.resolveWith<OutlinedBorder>((states) {
                      return RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      );
                    }),
                  ),
                  child: const Text("Confirmar",
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontFamily: 'Poppins')),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Default "Fechar" state
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: SizedBox(
        width: double.infinity,
        height: 48,
        child: OutlinedButton(
          onPressed: () => Navigator.pop(context),
          style: OutlinedButton.styleFrom(
            backgroundColor: AppColors.cardBackground,
            padding: const EdgeInsets.symmetric(vertical: 12),
            side: const BorderSide(color: AppColors.border),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
          child: const Text("Fechar",
              style: TextStyle(
                  color: AppColors.secondaryText, fontFamily: 'Poppins')),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
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
          const Padding(
            padding: EdgeInsets.only(
                top: 16.0, left: 16.0, right: 16.0, bottom: 8.0),
            child: Center(
              child: Text(
                'Selecionar Jornada',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.primaryText,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Poppins',
                ),
              ),
            ),
          ),
          // Conteúdo rolável
          Flexible(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: SingleChildScrollView(
                child: _buildGoalList(),
              ),
            ),
          ),
          // Footer dinamico
          _buildFooter(),
        ],
      ),
    );
  }
}

